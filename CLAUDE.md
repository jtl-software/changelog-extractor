# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A PHP CLI tool that parses `CHANGELOG.md` files (CommonMark format) into structured JSON, distributed as a PHAR release asset. Also contains the reusable GitHub Actions workflow that consumer repos invoke on release to feed data into `jtl-software/changelog-page`.

Two deliverables:
1. **PHP CLI** (`src/`, `bin/changelog-extractor`, `extractor.php`) — built into `changelog-extractor.phar` via `buildPhar.php`
2. **Reusable workflow** (`.github/workflows/update-changelog.yaml`) — end-to-end: app token, checkout, extract, open PR, auto-merge

## Common commands

```bash
# Install all dependencies (incl. dev tools)
composer install

# Run PHPCS (blocking by phpcs.xml.dist config, but exits 0 by design — legacy behaviour)
vendor/bin/phpcs

# Run PHPStan (informational, non-blocking)
vendor/bin/phpstan analyse --level=5 src/

# Build PHAR locally (requires phar.readonly=0)
php --define phar.readonly=0 buildPhar.php

# Run fixture self-test against the built PHAR
bash .github/scripts/verify-fixture.sh changelog-extractor.phar workspace

# Run negative test (missing context must exit non-zero)
bash .github/scripts/verify-missing-context-fails.sh changelog-extractor.phar workspace

# Run extractor directly without PHAR
php extractor.php --file path/to/CHANGELOG.md --output out.json
php extractor.php --file CHANGELOG.md --context storage/systems/myapp.json --output storage/systems/myapp.json
```

CLI options: `--file` / `-f` (default: `CHANGELOG.md`), `--output` / `-o` (default: `CHANGELOG.json`), `--context` / `-c`, `--ticket-link` / `-t` (default: `https://issues.jtl-software.de/issues/%s`).

## Code architecture

```
extractor.php          Bootstrap — instantiates Extractor, calls run()
src/
  Extractor.php        Creates Symfony Console Application, registers ExtractCommand as default
  Command/
    ExtractCommand.php Parses CLI args, wires CommonParser, writes JSON output
  Parser/
    CommonParser.php   Core logic: walks the league/commonmark AST, extracts versions/changes
bin/changelog-extractor  Thin shell wrapper
buildPhar.php          Bundles vendor/ + src/ + extractor.php into changelog-extractor.phar
tests/fixtures/        CHANGELOG.md + context.json + expected.json (human reference, not a golden file)
.github/
  workflows/
    check.yaml         CI: PHPCS + PHPStan + fixture self-test + negative test
    release.yaml       Tag push → build PHAR → GitHub Release + update rolling v2 tag/release
    update-changelog.yaml  The reusable workflow consumed by connector repos
    lint-actions.yaml  actionlint on workflow files
  scripts/
    verify-fixture.sh          Runs PHAR against fixtures, asserts structure via jq
    verify-missing-context-fails.sh  Asserts non-zero exit when --context file is absent
    run-extractor.sh           Used inside update-changelog.yaml
```

### Parsing logic (`CommonParser`)

The parser walks the CommonMark AST node-by-node. H2 headings become version entries (text = version string, `*bold*` = `security: true`, `*italic*` = `date`). List blocks under a heading become the `changes` array; each item extracts the first `<a>` link URL and strips link markup from the display text. If a list item has no explicit link, the parser regex-extracts a Jira-style ticket ID (`[A-Z][A-Z0-9]+-[0-9]+`) and formats a link via `--ticket-link`. `Unreleased` sections are silently dropped.

### Context file merge

When `--context` is provided, the extractor reads the existing JSON, injects the parsed `changelog` key, and writes the result back to `--output`. If `--context` points to a non-existent file, the extractor exits non-zero (E2.3).

## Key architectural constraints

- **PHP 8.3 hard-pinned** everywhere (CI, PHAR, `composer.json`). If upgrading, change: `update-changelog.yaml`, `check.yaml`, `release.yaml`, `composer.json`. Then `composer update` and commit `composer.lock`.
- **PHPCS exits 0 by design** — `phpcs.xml.dist` sets `ignore_errors_on_exit` and `ignore_warnings_on_exit` to preserve legacy GitLab CI behaviour.
- **PHPStan is non-blocking** (`continue-on-error: true` in `check.yaml`) for the same reason.
- **Fixture self-test gates the release** — `release.yaml` runs `verify-fixture.sh` before publishing. If it fails, no release is created.
- **Rolling `v2` tag and release** — `release.yaml` moves both the git tag and the GitHub Release named `v2` on every `v2.x.y` publish. The reusable workflow downloads from the `v2` release asset URL.
