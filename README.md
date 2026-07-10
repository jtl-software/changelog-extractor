# JTL Changelog Extractor

PHP tool and GitHub Actions bundle that parses a `CHANGELOG.md` in CommonMark
format into structured JSON and feeds the result into the central
[`jtl-software/changelog-page`](https://github.com/jtl-software/changelog-page)
repository.

This repo ships two things:

1. The **PHP CLI tool** (`src/`, `bin/changelog-extractor`, distributed as a PHAR)
2. A **reusable workflow** (`.github/workflows/update-changelog.yaml`) for the
   end-to-end flow including cross-repo PR and auto-merge

## Purpose

Every release published by a consumer repo (e.g. `connector-shopify`) should
automatically produce a structured changelog entry in the central
`jtl-software/changelog-page` repository. The extractor parses the consumer's
`CHANGELOG.md`, merges the result into the system context file
(`storage/systems/<project>.json` inside `jtl-software/changelog-page`), opens
a pull request, and lets auto-merge finish the job.

`<project>` means the exact value of workflow input `system-name` and the
exact JSON filename in `jtl-software/changelog-page/storage/systems/`.

Example:

- `system-name: shopify`
- target file: `jtl-software/changelog-page/storage/systems/shopify.json`

## Architecture decisions

The following decisions come from the DP-379 migration plan and are wired
into this repo:

### E2.1 PHP 8.3, hard-coded

The reusable workflow pins PHP 8.3. There is no `php-version` input. Reason:
consistency with the JTL production servers and self-hosted runners. When
the internal PHP target version changes, four places in this repo have to
be updated:

- `.github/workflows/update-changelog.yaml` — `setup-php` step
- `.github/workflows/check.yaml` — every `setup-php` step
- `.github/workflows/release.yaml` — `setup-php` step
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

If `storage/systems/<project>.json` does not exist in
`jtl-software/changelog-page`, the workflow aborts with a clear error message.
This matches the GitLab behaviour. New systems have to be created manually in
`jtl-software/changelog-page` first (see "Onboarding new systems").

### E2.4 Versioning: `v2.0.0` + rolling `v2` tag

The reusable workflow is released via `v2.x.y` tags. Consumers pin to `@v2`
(rolling) and receive patches automatically. The legacy `1.0.x` tags from
the GitLab era remain as history but are no longer advanced.

## Using the reusable workflow

The regular case. The reusable workflow handles the end-to-end flow:
generating the app token, checking out the required repos, running the
extractor, opening a PR in `jtl-software/changelog-page`, and enabling
auto-merge.

In the consumer repo as `.github/workflows/update-changelog.yaml`:

```yaml
name: update-changelog

on:
  release:
    types: [published]

jobs:
  call:
    uses: jtl-software/changelog-extractor/.github/workflows/update-changelog.yaml@v2
    with:
      system-name: shopify
      jira-release-prefix: SFC
      app-id: ${{ vars.GH_APP_ID }}
      # changelog-file: CHANGELOG.md  # optional, default
    secrets:
      APP_PRIVATE_KEY: ${{ secrets.GH_APP_PRIVATE_KEY }}
      ATLASSIAN_EMAIL: ${{ secrets.ATLASSIAN_EMAIL }}
      ATLASSIAN_API_TOKEN: ${{ secrets.ATLASSIAN_API_TOKEN }}
```

### Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `system-name` | yes | — | System name (see above) |
| `changelog-file` | no | `CHANGELOG.md` | Path to the changelog file |
| `app-id` | yes | — | App ID of the `jtl-release-bot` GitHub App. Public identifier, not a secret. Primary: org variable `GH_APP_ID`. Fallback: `JTL_RELEASE_BOT_APP_ID` |
| `atlassian-site` | no | `https://jtl-software.atlassian.net` | Atlassian base URL for Jira API calls |
| `jira-project-key` | no | `CO` | Jira project key where release versions are created/updated |
| `jira-release-prefix` | no | (derived from `system-name`) | Optional Jira release prefix override (for example `SFC`, `SW6`, `WC`, `Core`) |

### Secrets

| Secret | Description |
| --- | --- |
| `APP_PRIVATE_KEY` | Private key of the app. Primary: org secret `GH_APP_PRIVATE_KEY`. Fallback: `JTL_RELEASE_BOT_PRIVATE_KEY` |
| `ATLASSIAN_EMAIL` | Atlassian account email for Jira API auth (optional) |
| `ATLASSIAN_API_TOKEN` | Atlassian API token for Jira API auth (optional) |

If both Atlassian secrets are present, the workflow additionally publishes the latest extracted release to Jira Versions and links detected tickets via `fixVersions`. This step is **warn-only** and does not fail the release pipeline.

The generated app token is restricted to `repositories: [changelog-page]`
(E3.2). This means access only to repo `jtl-software/changelog-page`.
The caller repo does not need any token access to `jtl-software/changelog-page`.

### Required setup checklist (GitHub + Jira)

Use this checklist to make the complete feature work end-to-end
(`jtl-software/changelog-page` + Jira Releases):

1. Configure GitHub App credentials (required for `jtl-software/changelog-page` update)
   - `GH_APP_ID` (Variable): Public App ID of `jtl-release-bot`.
   - `GH_APP_PRIVATE_KEY` (Secret): Private key of `jtl-release-bot`.
   - Where to set:
     - Preferred: org-level (`jtl-software`) variables/secrets with repository access for all connector repos.
     - Alternative: per-repo variables/secrets.
   - Purpose:
     - Generate a scoped installation token to create/update PRs in `jtl-software/changelog-page`.

2. Configure Atlassian credentials (required for Jira release publishing)
   - `ATLASSIAN_EMAIL` (Secret): Atlassian account email used for API auth.
   - `ATLASSIAN_API_TOKEN` (Secret): API token created in Atlassian account security settings.
   - Where to set:
     - Preferred: org-level secrets in GitHub, shared with all connector repos.
     - Alternative: per-repo secrets.
   - Purpose:
     - Create/update Jira Versions and assign `fixVersions` on detected tickets.

3. Configure repo-specific mapping values
   - `system-name` (workflow input): must match filename
     `storage/systems/<project>.json` in `jtl-software/changelog-page`.
   - `jira-release-prefix` (workflow input): release name prefix used in Jira.
   - Current prefix mapping:
     - Shopify: `SFC`
     - Shopware6 SaaS: `SW6`
     - WooCommerce: `WC`
     - Core: `Core`
     - Prestashop: `PRC`
   - Core only:
     - Set repo variable `CHANGELOG_SYSTEM_NAME` to the exact system key
       existing in `jtl-software/changelog-page`.

4. Ensure Jira permissions for the Atlassian bot user
   - Project permissions on `CO`:
     - Browse Projects
     - Manage Versions
     - Edit Issues
   - Field permissions:
     - Must be allowed to modify `Fix Versions` on target issue types.
   - Why:
     - Missing permissions cause partial updates (version created but issues not linked, or vice versa).

5. Keep release trigger and workflow reference consistent
   - Consumer workflows must run on `release: published`.
   - After feature-branch validation, pin reusable workflow ref back to stable (`@v2` or commit SHA on default branch).
   - Why:
     - Avoid production dependency on temporary feature branches.

6. Validate after setup
   - Release a test version in one connector repo.
   - Confirm all of the following:
     - A PR is created in `jtl-software/changelog-page` for `<project>`
       based on source file `CHANGELOG.md` (or custom `changelog-file`).
    - The latest version appears in `storage/systems/<project>.json`.
     - Jira Version `<PREFIX>-<version>` exists in project `CO`.
     - Included tickets are linked via `fixVersions`.

Notes:
- Atlassian publishing is intentionally warn-only by default. Missing/invalid Atlassian credentials do not block connector releases.
- If `jira-release-prefix` is not set and no known prefix mapping exists, Jira publishing is skipped with a warning.

## Release process

Releases are automated via `.github/workflows/release.yaml` when a `v*` tag
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

1. `.github/workflows/update-changelog.yaml` — `setup-php` step
2. `.github/workflows/check.yaml` — every `setup-php` step
3. `.github/workflows/release.yaml` — `setup-php` step
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
`storage/systems/<project>.json` does not exist in
`jtl-software/changelog-page` (E2.3).
To add a new system:

1. Create a branch in
   [`jtl-software/changelog-page`](https://github.com/jtl-software/changelog-page).
2. Create `storage/systems/<project>.json`, minimal shape:
   ```json
   {
     "name": "<project>",
     "label": "<Display name>",
     "description": "<Short description of the system>"
   }
   ```
   (`changelog` is filled in by the extractor later; do not add it by
   hand.)
3. Merge the PR.
4. Ensure the consumer repo keeps release notes in `CHANGELOG.md` (or set `changelog-file` accordingly), then invoke the reusable workflow (see above). On the
   next release the file is automatically extended with the `changelog`
   key.

The exact set of required fields in the context file comes from the
template in `jtl-software/changelog-page` — please keep this doc in sync with
changes there.

## Tests

`.github/workflows/check.yaml` runs on every PR (and on push to the
default branch):

- PHPCS against `src/`, `bin/`, `extractor.php`, `buildPhar.php` using
  the `ConnectorStandard` ruleset shipped in `phpcs.xml.dist` (PSR12
  base plus the JTL-connector sniffs from `slevomat/coding-standard`).
- PHPStan (level 5) against `src/`. Runs as an informational,
  non-blocking step (the legacy GitLab CI defaulted to
  `ENABLE_PHPSTAN=false` and never ran PHPStan at all; we keep the
  findings visible in the step log without gating the merge).
- Fixture self-test: builds the PHAR, runs it against `tests/fixtures/`
  and asserts structural properties of the result (see
  `tests/fixtures/README.md`).
- Negative test: missing context file must produce a non-zero exit code
  (E2.3).

PHPCS, PHPStan and their standards are declared in `composer.json`
under `require-dev` so `composer install` provisions the full toolchain
locally; CI invokes them via `vendor/bin/phpcs` and
`vendor/bin/phpstan`.

## License / author

Original tool: Tim Platzke, JTL-Software GmbH.
