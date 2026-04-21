# JTL Changelog Extractor

PHP tool and GitHub Actions bundle that parses a `CHANGELOG.md` in CommonMark
format into structured JSON and feeds the result into the central
[`jtl-software/changelog-page`](https://github.com/jtl-software/changelog-page)
repository.

This repo ships two things:

1. The **PHP CLI tool** (`src/`, `bin/changelog-extractor`, distributed as a PHAR)
2. A **reusable workflow** (`.github/workflows/update-changelog.yml`) for the
   end-to-end flow including cross-repo PR and auto-merge

## Purpose

Every release published by a consumer repo (e.g. `connector-shopify`) should
automatically produce a structured changelog entry in the central
`changelog-page`. The extractor parses the consumer's `CHANGELOG.md`, merges
the result into the system context file
(`changelog-page/storage/systems/<system-name>.json`), opens a pull request,
and lets auto-merge finish the job.

## Architecture decisions

The following decisions come from the DP-379 migration plan and are wired
into this repo:

### E2.1 PHP 8.3, hard-coded

The reusable workflow pins PHP 8.3. There is no `php-version` input. Reason:
consistency with the JTL production servers and self-hosted runners. When
the internal PHP target version changes, four places in this repo have to
be updated:

- `.github/workflows/update-changelog.yml` — `setup-php` step
- `.github/workflows/check.yml` — every `setup-php` step
- `.github/workflows/release.yml` — `setup-php` step
- `composer.json` — `require.php`

See the "PHP version upgrade" section below.

### E2.2 Distribution as PHAR (release asset)

The reusable workflow downloads the extractor as a PHAR from the GitHub
release asset on the rolling `v2` tag, not via `composer global require`.
This gives us:

- Reproducible builds (the tag pins an exact commit plus its resolved
  dependencies)
- Supply chain robustness (no remote package resolution at runtime)
- Faster cold runs (one `curl` instead of a Composer install)

### E2.3 Hard fail on missing context file

If `changelog-page/storage/systems/<system-name>.json` does not exist, the
workflow aborts with a clear error message. This matches the GitLab
behaviour. New systems have to be created manually in `changelog-page`
first (see "Onboarding new systems").

### E2.4 Versioning: `v2.0.0` + rolling `v2` tag

The reusable workflow is released via `v2.x.y` tags. Consumers pin to `@v2`
(rolling) and receive patches automatically. The legacy `1.0.x` tags from
the GitLab era remain as history but are no longer advanced.

## Using the reusable workflow

The regular case. The reusable workflow handles the end-to-end flow:
generating the app token, checking out the required repos, running the
extractor, opening a PR in `changelog-page`, and enabling auto-merge.

In the consumer repo as `.github/workflows/update-changelog.yml`:

```yaml
name: update-changelog

on:
  release:
    types: [published]

jobs:
  call:
    uses: jtl-software/changelog-extractor/.github/workflows/update-changelog.yml@v2
    with:
      system-name: shopify
      app-id: ${{ vars.GH_APP_ID }}
      # changelog-file: CHANGELOG.md  # optional, default
    secrets:
      APP_PRIVATE_KEY: ${{ secrets.GH_APP_PRIVATE_KEY }}
```

### Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `system-name` | yes | — | System name (see above) |
| `changelog-file` | no | `CHANGELOG.md` | Path to the changelog file |
| `app-id` | yes | — | App ID of the `jtl-release-bot` GitHub App. Public identifier, not a secret. Primary: org variable `GH_APP_ID`. Fallback: `JTL_RELEASE_BOT_APP_ID` |

### Secrets

| Secret | Description |
| --- | --- |
| `APP_PRIVATE_KEY` | Private key of the app. Primary: org secret `GH_APP_PRIVATE_KEY`. Fallback: `JTL_RELEASE_BOT_PRIVATE_KEY` |

The generated app token is restricted to `repositories: [changelog-page]`
(E3.2). The caller repo does not need any token access to `changelog-page`.

## Release process

Releases are automated via `.github/workflows/release.yml` when a `v*` tag
is pushed:

1. Create the tag:
   ```bash
   git tag v2.0.1
   git push origin v2.0.1
   ```
2. The release workflow:
   - Installs Composer dependencies (`--no-dev --prefer-dist`)
   - Builds `changelog-extractor.phar` via `buildPhar.php`
   - Runs the fixture self-test (`.github/scripts/verify-fixture.sh`)
   - Creates a GitHub release with `changelog-extractor.phar` as an asset
   - Moves the rolling `v2` tag to the tagged commit (only when the tag
     starts with `v2`)

If the fixture self-test fails, neither the release nor the tag update is
published.

### First release after migration

`v2.0.0` is created manually by Q after review of this PR. The workflow
handles every subsequent release automatically.

## PHP version upgrade

When the internal PHP target version changes (e.g. to 8.4), four places in
this repo need to be touched:

1. `.github/workflows/update-changelog.yml` — `setup-php` step
2. `.github/workflows/check.yml` — every `setup-php` step
3. `.github/workflows/release.yml` — `setup-php` step
4. `composer.json` — `require.php`

After the change run `composer update` locally and commit `composer.lock`.
Bump to a new major tag `v3.0.0` when consumers have to migrate as well,
otherwise do a minor bump on `v2`.

## Fallback: Composer install (no PHAR)

For local development or when the PHAR distribution is temporarily
unavailable:

```bash
git clone https://github.com/jtl-software/changelog-extractor.git
cd changelog-extractor
composer install
php extractor.php --file path/to/CHANGELOG.md --output out.json
# or: ./bin/changelog-extractor --file ...
```

CLI options:

| Option | Default | Description |
| --- | --- | --- |
| `--file`, `-f` | `CHANGELOG.md` | Input markdown |
| `--output`, `-o` | `CHANGELOG.json` | Output JSON |
| `--context`, `-c` | (empty) | Context JSON. When set, the result is merged into the `changelog` key of the context |
| `--ticket-link`, `-t` | `https://issues.jtl-software.de/issues/%s` | URL template for tickets without an explicit link |

## Onboarding new systems

The workflow hard-fails when
`changelog-page/storage/systems/<system-name>.json` does not exist (E2.3).
To add a new system:

1. Create a branch in
   [`jtl-software/changelog-page`](https://github.com/jtl-software/changelog-page).
2. Create `storage/systems/<system-name>.json`, minimal shape:
   ```json
   {
     "name": "<system-name>",
     "label": "<Display name>",
     "description": "<Short description of the system>"
   }
   ```
   (`changelog` is filled in by the extractor later; do not add it by
   hand.)
3. Merge the PR.
4. Invoke the reusable workflow from the consumer repo (see above). On the
   next release the file is automatically extended with the `changelog`
   key.

The exact set of required fields in the context file comes from the
template in `changelog-page` — please keep this doc in sync with changes
there.

## Tests

`.github/workflows/check.yml` runs on every push and PR:

- PHPCS (PSR12) against `src/`, `bin/`, `extractor.php`, `buildPhar.php`
- PHPStan (level 5) against `src/`
- Fixture self-test: builds the PHAR, runs it against `tests/fixtures/`
  and asserts structural properties of the result (see
  `tests/fixtures/README.md`)
- Negative test: missing context file must produce a non-zero exit code
  (E2.3)

## License / author

Original tool: Tim Platzke, JTL-Software GmbH.
