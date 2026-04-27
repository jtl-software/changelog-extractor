#!/usr/bin/env bash
#
# Negative test: invoking the extractor with a non-existent --context
# file must exit non-zero. Enforces the hard-fail contract that
# consumers rely on when they haven't onboarded their system yet.
#
# Usage:
#   verify-missing-context-fails.sh <phar-path> <workspace-dir>
#
# Example:
#   verify-missing-context-fails.sh changelog-extractor.phar workspace

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <phar-path> <workspace-dir>" >&2
  exit 2
fi

PHAR="$1"
WORKSPACE="$2"
MISSING="${WORKSPACE}/changelog-page/storage/systems/does-not-exist.json"

mkdir -p "$(dirname "$MISSING")"

OUTPUT_FILE="$(mktemp)"
trap 'rm -f "${OUTPUT_FILE}"' EXIT

set +e
php "$PHAR" \
  --file tests/fixtures/CHANGELOG.md \
  --context "$MISSING" \
  --output "$MISSING" \
  > "${OUTPUT_FILE}" 2>&1
RC=$?
set -e

if [ "$RC" -eq 0 ]; then
  echo "::error::Extractor must fail on missing context, but exited 0"
  cat "${OUTPUT_FILE}" >&2
  exit 1
fi

if ! grep -qi "context file.*does not exist" "${OUTPUT_FILE}"; then
  echo "::error::Extractor exited non-zero but did not emit the expected missing-context error message"
  cat "${OUTPUT_FILE}" >&2
  exit 1
fi

echo "Missing context correctly produced non-zero exit code ($RC) and a clear error message."
