#!/usr/bin/env bash
#
# Negative test: invoking the extractor with a non-existent --context
# file must exit non-zero. Enforces the E2.3 hard-fail contract that
# consumers rely on when they haven't onboarded their system yet.
#
# Usage:
#   verify-missing-context-fails.sh [phar-path] [workspace-dir]
#
# Defaults:
#   phar-path:     changelog-extractor.phar
#   workspace-dir: workspace

set -euo pipefail

PHAR="${1:-changelog-extractor.phar}"
WORKSPACE="${2:-workspace}"
MISSING="${WORKSPACE}/changelog-page/storage/systems/does-not-exist.json"

mkdir -p "$(dirname "$MISSING")"

set +e
php "$PHAR" \
  --file tests/fixtures/CHANGELOG.md \
  --context "$MISSING" \
  --output "$MISSING"
RC=$?
set -e

if [ "$RC" = "0" ]; then
  echo "::error::Extractor must fail on missing context, but exited 0"
  exit 1
fi

echo "Missing context correctly produced non-zero exit code ($RC)."
