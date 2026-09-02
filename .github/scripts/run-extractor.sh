#!/usr/bin/env bash
#
# Downloads the v2 PHAR (authenticated) and runs it against an existing context
# file in the locally checked-out target-repo tree. Merge-in-place semantics:
# the context JSON at storage/systems/<system-name>.json gets its `changelog`
# key overwritten with the parsed CHANGELOG.md content.
#
# Usage:
#   run-extractor.sh <system-name> <target-repo-dir> <changelog-file>
#
# Example:
#   run-extractor.sh shopify changelog-page /tmp/CHANGELOG.md
#
# Required environment variables:
#   EXTRACTOR_TOKEN  Any valid GitHub token (e.g. the default GITHUB_TOKEN).
#                    changelog-extractor is public, so no special scope is
#                    needed; a token just avoids the unauthenticated API rate
#                    limit.
#   EXTRACTOR_REPO   owner/repo of the extractor (default: jtl-software/changelog-extractor).
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

: "${EXTRACTOR_TOKEN:?EXTRACTOR_TOKEN must be set (any valid token, e.g. GITHUB_TOKEN — changelog-extractor is public)}"
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

# changelog-extractor is public, so no special scope is needed here — any
# valid token works (we still pass one to avoid the unauthenticated API rate
# limit). `gh release download` resolves the asset IDs and follows the
# signed-URL redirect correctly.
GH_TOKEN="${EXTRACTOR_TOKEN}" gh release download v2 \
  --repo "${EXTRACTOR_REPO}" \
  --pattern 'changelog-extractor.phar' \
  --pattern 'changelog-extractor.phar.sha256' \
  --dir "${DL_DIR}" \
  --clobber

PHAR="${DL_DIR}/changelog-extractor.phar"
SHA_FILE="${DL_DIR}/changelog-extractor.phar.sha256"

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
