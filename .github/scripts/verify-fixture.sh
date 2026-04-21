#!/usr/bin/env bash
#
# Runs the built PHAR against the committed fixture and verifies the
# resulting JSON structure. Self-contained: prepares a mutable workspace,
# runs the extractor with the same --context/--output semantics used by
# the production reusable workflow (overwrite-in-place), and asserts
# structural properties.
#
# Usage:
#   verify-fixture.sh [phar-path] [workspace-dir]
#
# Defaults:
#   phar-path:     changelog-extractor.phar  (produced by buildPhar.php)
#   workspace-dir: workspace                 (mutable scratch space)
#
# Fails (non-zero exit) on any failed assertion.

set -euo pipefail

PHAR="${1:-changelog-extractor.phar}"
WORKSPACE="${2:-workspace}"
RESULT="${WORKSPACE}/changelog-page/storage/systems/fixture.json"

mkdir -p "$(dirname "$RESULT")"
cp tests/fixtures/context.json "$RESULT"

php "$PHAR" \
  --file tests/fixtures/CHANGELOG.md \
  --context "$RESULT" \
  --output "$RESULT"

cat "$RESULT"
echo "---"

echo "Context keys must be preserved (name, label, description)"
test "$(jq -r '.name' "$RESULT")" = "fixture"
test "$(jq -r '.label' "$RESULT")" = "Fixture System"
test -n "$(jq -r '.description' "$RESULT")"

echo "changelog key must exist"
test "$(jq -r 'has("changelog")' "$RESULT")" = "true"

echo "Expected versions must be present"
test "$(jq -r '.changelog | has("1.1.0")' "$RESULT")" = "true"
test "$(jq -r '.changelog | has("1.0.0")' "$RESULT")" = "true"

echo "Unreleased must be absent"
test "$(jq -r '.changelog | has("Unreleased")' "$RESULT")" = "false"
test "$(jq -r '.changelog | has("unreleased")' "$RESULT")" = "false"

echo "1.1.0 must have 2 changes"
test "$(jq '.changelog["1.1.0"].changes | length' "$RESULT")" = "2"

echo "1.0.0 must be security and have description and 2 changes"
test "$(jq -r '.changelog["1.0.0"].security' "$RESULT")" = "true"
test -n "$(jq -r '.changelog["1.0.0"].description' "$RESULT")"
test "$(jq '.changelog["1.0.0"].changes | length' "$RESULT")" = "2"

echo "Ticket link default must be applied to non-link entries"
test "$(jq -r '.changelog["1.1.0"].changes[0].link' "$RESULT")" = "https://issues.jtl-software.de/issues/DP-100"

echo "Explicit link must be kept"
test "$(jq -r '.changelog["1.0.0"].changes[1].link' "$RESULT")" = "https://example.com/DP-002"

echo "All structural assertions passed."
