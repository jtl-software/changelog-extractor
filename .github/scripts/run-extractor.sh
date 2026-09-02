#!/usr/bin/env bash
#
# Downloads the PHAR for a specific release tag (anonymously) and runs it
# against an existing context file in the locally checked-out target-repo
# tree. Merge-in-place semantics: the context JSON at
# storage/systems/<system-name>.json gets its `changelog` key overwritten
# with the parsed CHANGELOG.md content.
#
# Usage:
#   run-extractor.sh <system-name> <target-repo-dir> <changelog-file>
#
# Example:
#   run-extractor.sh shopify changelog-page /tmp/CHANGELOG.md
#
# Required environment variables:
#   EXTRACTOR_REPO         owner/repo of the extractor (default: jtl-software/changelog-extractor).
#   EXTRACTOR_RELEASE_TAG  Release tag to download the PHAR from (e.g.
#                          v2.2.0). Callers pin `uses:` to an exact commit
#                          SHA, not a rolling tag, so this must be the release
#                          tag that matches that same commit for the pin to
#                          mean anything - see "Resolve PHAR release tag for
#                          this exact commit" in update-changelog.yaml.
#
# Deliberately anonymous, no token: changelog-extractor is public, and a
# caller-scoped GitHub Actions installation token (github.token from a
# DIFFERENT repo's job) gets rejected by the Releases-by-tag/asset REST
# endpoints even for a public target repo - confirmed empirically, this
# isn't a guess. A genuinely anonymous request (no Authorization header at
# all) succeeds where a foreign installation token 404s. `gh release
# download` also can't be used here: it refuses to run at all without some
# locally configured credential, unlike a plain unauthenticated curl.
#
# Fails (non-zero exit) if the target context file doesn't exist or if any
# command fails.

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <system-name> <target-repo-dir> <changelog-file>" >&2
  exit 2
fi

SYSTEM_NAME="$1"
TARGET_REPO_DIR="$2"
CHANGELOG="$3"

: "${EXTRACTOR_RELEASE_TAG:?EXTRACTOR_RELEASE_TAG must be set (the release tag whose PHAR to download)}"
EXTRACTOR_REPO="${EXTRACTOR_REPO:-jtl-software/changelog-extractor}"

# Reject system names that could escape storage/systems/ or contain shell
# metacharacters. The allowed character set matches what changelog-page
# accepts as a system identifier: alphanumerics, dash, underscore, dot.
if ! [[ "${SYSTEM_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "::error::Invalid system-name: '${SYSTEM_NAME}'. Must match ^[A-Za-z0-9][A-Za-z0-9._-]*$" >&2
  exit 2
fi

CONTEXT_FILE="${TARGET_REPO_DIR}/storage/systems/${SYSTEM_NAME}.json"

if [ ! -f "${CONTEXT_FILE}" ]; then
  echo "::error::Context file not found: ${CONTEXT_FILE}. Please create ${SYSTEM_NAME}.json under ${TARGET_REPO_DIR}/storage/systems/ first (see 'Onboarding new systems' in README.md)."
  exit 1
fi

DL_DIR="$(mktemp -d)"
trap 'rm -rf "${DL_DIR}"' EXIT

PHAR="${DL_DIR}/changelog-extractor.phar"
SHA_FILE="${DL_DIR}/changelog-extractor.phar.sha256"

# Look up asset IDs for the release, then download each anonymously. No
# Authorization header anywhere in this block, on purpose (see file header).
RELEASE_JSON="$(curl -sf "https://api.github.com/repos/${EXTRACTOR_REPO}/releases/tags/${EXTRACTOR_RELEASE_TAG}")"

for pair in "changelog-extractor.phar:${PHAR}" "changelog-extractor.phar.sha256:${SHA_FILE}"; do
  ASSET_NAME="${pair%%:*}"
  DEST="${pair#*:}"
  ASSET_ID="$(echo "${RELEASE_JSON}" | jq -r --arg name "${ASSET_NAME}" '.assets[] | select(.name == $name) | .id')"
  if [ -z "${ASSET_ID}" ]; then
    echo "::error::Release '${EXTRACTOR_RELEASE_TAG}' on ${EXTRACTOR_REPO} has no asset named '${ASSET_NAME}'." >&2
    exit 1
  fi
  curl -sfL -H "Accept: application/octet-stream" \
    -o "${DEST}" \
    "https://api.github.com/repos/${EXTRACTOR_REPO}/releases/assets/${ASSET_ID}"
done

EXPECTED_SHA="$(awk '{print $1}' "${SHA_FILE}")"
ACTUAL_SHA="$(sha256sum "${PHAR}" | awk '{print $1}')"
if [ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]; then
  echo "::error::PHAR checksum mismatch. expected=${EXPECTED_SHA} actual=${ACTUAL_SHA}" >&2
  exit 1
fi

php "${PHAR}" \
  --file "${CHANGELOG}" \
  --context "${CONTEXT_FILE}" \
  --output "${CONTEXT_FILE}"
