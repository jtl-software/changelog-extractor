#!/usr/bin/env bash
#
# Fetches a file from the caller repository at the current workflow SHA
# via the GitHub Contents API (no full checkout required). Fails if the
# response is empty.
#
# Usage:
#   fetch-changelog.sh <changelog-file> <output-file>
#
# Example:
#   fetch-changelog.sh CHANGELOG.md /tmp/CHANGELOG.md
#
# Required environment variables (set automatically by the GitHub Actions
# runner): GH_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <changelog-file> <output-file>" >&2
  exit 2
fi

CHANGELOG_FILE="$1"
OUTPUT_FILE="$2"

gh api "repos/${GITHUB_REPOSITORY}/contents/${CHANGELOG_FILE}?ref=${GITHUB_SHA}" \
  --jq '.content' | base64 -d > "${OUTPUT_FILE}"

test -s "${OUTPUT_FILE}"
echo "Fetched $(wc -l < "${OUTPUT_FILE}") lines from ${CHANGELOG_FILE}@${GITHUB_SHA}"
