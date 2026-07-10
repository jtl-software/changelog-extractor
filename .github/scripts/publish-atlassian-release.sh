#!/usr/bin/env bash
#
# Publishes the latest extracted changelog entry to Jira Releases (Versions)
# and links detected tickets via fixVersions.
#
# Required env vars:
#   SYSTEM_NAME, JIRA_SITE, JIRA_PROJECT_KEY, ATLASSIAN_EMAIL,
#   ATLASSIAN_API_TOKEN, CONTEXT_FILE
#
# Optional env vars:
#   JIRA_RELEASE_PREFIX (overrides built-in system->prefix mapping)

set -euo pipefail

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "::error::Missing required environment variable: ${name}" >&2
    exit 2
  fi
}

require_var SYSTEM_NAME
require_var JIRA_SITE
require_var JIRA_PROJECT_KEY
require_var ATLASSIAN_EMAIL
require_var ATLASSIAN_API_TOKEN
require_var CONTEXT_FILE

if [[ ! -f "${CONTEXT_FILE}" ]]; then
  echo "::error::Context file not found: ${CONTEXT_FILE}" >&2
  exit 1
fi

jira_prefix_from_system() {
  case "$1" in
    shopify) echo "SFC" ;;
    shopware6) echo "SW6" ;;
    woocommerce) echo "WC" ;;
    core) echo "Core" ;;
    *) echo "" ;;
  esac
}

JIRA_RELEASE_PREFIX="${JIRA_RELEASE_PREFIX:-}"
if [[ -z "${JIRA_RELEASE_PREFIX}" ]]; then
  JIRA_RELEASE_PREFIX="$(jira_prefix_from_system "${SYSTEM_NAME}")"
fi

if [[ -z "${JIRA_RELEASE_PREFIX}" ]]; then
  echo "::warning::No Jira release prefix known for system '${SYSTEM_NAME}'. Set input jira-release-prefix to enable Atlassian publishing."
  exit 0
fi

LATEST_VERSION="$(jq -r '.changelog | to_entries[0].key // empty' "${CONTEXT_FILE}")"
if [[ -z "${LATEST_VERSION}" ]]; then
  echo "::warning::Could not determine latest changelog version from ${CONTEXT_FILE}."
  exit 0
fi

RELEASE_NAME="${JIRA_RELEASE_PREFIX}-${LATEST_VERSION}"

DESCRIPTION="$(jq -r '
  .changelog
  | to_entries[0].value.changes
  | if type=="array" then
      map("- " + (.text // "")) | join("\n")
    else
      ""
    end
' "${CONTEXT_FILE}")"

# Resolve project id once for version create.
PROJECT_JSON="$(curl -fsS -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
  -H 'Accept: application/json' \
  "${JIRA_SITE}/rest/api/3/project/${JIRA_PROJECT_KEY}")"
PROJECT_ID="$(jq -r '.id // empty' <<<"${PROJECT_JSON}")"
if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Could not resolve Jira project id for key '${JIRA_PROJECT_KEY}'."
  exit 1
fi

VERSIONS_JSON="$(curl -fsS -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
  -H 'Accept: application/json' \
  "${JIRA_SITE}/rest/api/3/project/${JIRA_PROJECT_KEY}/versions")"

VERSION_EXISTS="$(jq -r --arg name "${RELEASE_NAME}" 'map(select(.name==$name)) | length' <<<"${VERSIONS_JSON}")"

if [[ "${VERSION_EXISTS}" == "0" ]]; then
  CREATE_PAYLOAD="$(jq -n \
    --arg name "${RELEASE_NAME}" \
    --arg projectId "${PROJECT_ID}" \
    --arg desc "${DESCRIPTION}" \
    '{name:$name, projectId:($projectId|tonumber), description:$desc}')"

  curl -fsS -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -X POST \
    --data "${CREATE_PAYLOAD}" \
    "${JIRA_SITE}/rest/api/3/version" >/dev/null

  echo "Created Jira release '${RELEASE_NAME}'."
else
  echo "Jira release '${RELEASE_NAME}' already exists."
fi

# Ticket extraction from text and link fields.
mapfile -t TICKETS < <(jq -r '
  .changelog
  | to_entries[0].value.changes
  | if type=="array" then .[] else empty end
  | [(.text // ""), (.link // "")]
  | join(" ")
' "${CONTEXT_FILE}" \
  | grep -Eo '[A-Z][A-Z0-9]+-[0-9]+' \
  | sort -u || true)

if [[ "${#TICKETS[@]}" -eq 0 ]]; then
  echo "::warning::No ticket keys found in latest changelog entry for '${RELEASE_NAME}'."
  exit 0
fi

for ticket in "${TICKETS[@]}"; do
  PAYLOAD="$(jq -n --arg rn "${RELEASE_NAME}" '{update:{fixVersions:[{add:{name:$rn}}]}}')"
  if curl -fsS -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/json' \
      -X PUT \
      --data "${PAYLOAD}" \
      "${JIRA_SITE}/rest/api/3/issue/${ticket}" >/dev/null; then
    echo "Linked ${ticket} -> ${RELEASE_NAME}"
  else
    echo "::warning::Failed to link ticket ${ticket} to release ${RELEASE_NAME}."
  fi
done
