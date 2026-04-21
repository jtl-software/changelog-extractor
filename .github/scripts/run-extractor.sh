#!/usr/bin/env bash
#
# Downloads the v2 PHAR and runs it against an existing context file in
# the locally checked-out target-repo tree. Merge-in-place semantics:
# the context JSON at storage/systems/<system-name>.json gets its
# `changelog` key overwritten with the parsed CHANGELOG.md content.
#
# Usage:
#   run-extractor.sh <system-name> <target-repo-dir> <changelog-file>
#
# Example:
#   run-extractor.sh shopify changelog-page /tmp/CHANGELOG.md
#
# Fails (non-zero exit) if the target context file doesn't exist (E2.3)
# or if any command fails.

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <system-name> <target-repo-dir> <changelog-file>" >&2
  exit 2
fi

SYSTEM_NAME="$1"
TARGET_REPO_DIR="$2"
CHANGELOG="$3"

CONTEXT_FILE="${TARGET_REPO_DIR}/storage/systems/${SYSTEM_NAME}.json"

if [ ! -f "${CONTEXT_FILE}" ]; then
  echo "::error::Context file not found: ${CONTEXT_FILE}. Please create ${SYSTEM_NAME}.json under ${TARGET_REPO_DIR}/storage/systems/ first (see 'Onboarding new systems' in README.md)."
  exit 1
fi

PHAR="$(mktemp)"
trap 'rm -f "${PHAR}"' EXIT

curl -fsSL -o "${PHAR}" \
  https://github.com/jtl-software/changelog-extractor/releases/download/v2/changelog-extractor.phar

php "${PHAR}" \
  --file "${CHANGELOG}" \
  --context "${CONTEXT_FILE}" \
  --output "${CONTEXT_FILE}"
