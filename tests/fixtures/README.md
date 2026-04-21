# Test fixtures

Minimal data set for the fixture self-test in `.github/workflows/check.yml`.

## Contents

- `CHANGELOG.md` — minimal changelog with three variants (unreleased
  section, dated release, security release with description and link)
- `context.json` — minimal system context as it would live in
  `changelog-page/storage/systems/<system>.json`
- `expected.json` — expected result after the extractor runs (context
  plus the `changelog` key)

## Maintenance

The automated self-test checks structural properties via `jq` assertions
(see `.github/workflows/check.yml`). `expected.json` is a human-readable
reference document, not a golden file.
