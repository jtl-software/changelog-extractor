#!/usr/bin/env bash
#
# Runs the built PHAR against the committed fixture and verifies the
# resulting JSON structure. Self-contained: prepares a mutable workspace,
# runs the extractor with the same --context/--output semantics used by
# the production reusable workflow (overwrite-in-place), and asserts
# structural properties.
#
# Usage:
#   verify-fixture.sh <phar-path> <workspace-dir>
#
# Example:
#   verify-fixture.sh changelog-extractor.phar workspace
#
# Fails (non-zero exit) on bad argument count or any failed assertion.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <phar-path> <workspace-dir>" >&2
  exit 2
fi

PHAR="$1"
WORKSPACE="$2"
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

echo "Ticket link default must be applied to DP-100 (match by link value, position-independent)"
test "$(jq '.changelog["1.1.0"].changes | any(.link == "https://issues.jtl-software.de/issues/DP-100")' "$RESULT")" = "true"

echo "Explicit link https://example.com/DP-002 must be kept (match by link value, position-independent)"
test "$(jq '.changelog["1.0.0"].changes | any(.link == "https://example.com/DP-002")' "$RESULT")" = "true"

echo "All structural assertions passed."
