#!/usr/bin/env bash
#
# register-hindsight-mcp.sh - Register a Hindsight memory server with Claude Code
#
# Hindsight is a self-hosted agent memory service exposing a standard HTTP MCP endpoint, so any
# MCP-capable agent can use it for long-term recall and reflection. This registers it in the user
# scope, which makes it available to every project on this machine rather than one repo.
#
# The API key is never stored in this repo. It is read from the environment, from 1Password if the
# op CLI is available, from a gitignored credentials file, or by prompting. Registration writes the
# key into ~/.claude.json, which is outside this repo and must not be committed anywhere.
#
# Idempotent. An existing registration under the same name is replaced, so this is safe to re-run
# after a key rotation or an address change.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-10-10
# License: MIT
#
# Usage: ./claude/register-hindsight-mcp.sh [--url URL] [--bank ID] [--name NAME] [--remove]
#
#   --url URL    Base URL of the Hindsight API (default: $HINDSIGHT_URL, else loopback:8888)
#   --bank ID    Memory bank to scope the connection to (default: $HINDSIGHT_BANK_ID, else health)
#   --name NAME  Name to register under (default: hindsight-<bank>)
#   --remove     Remove the registration instead of adding it
#
# Dependencies: bash 4.0+, pfb, curl, claude; optionally op (1Password CLI)
#
# Exit codes:
#   0 - Registered, or removed with --remove
#   1 - Missing dependency, or no API key could be obtained
#   2 - The endpoint is unreachable or rejected the key
#   3 - Claude Code refused the registration

set -uo pipefail

# Where a key may be kept outside any repo. Owner-readable only.
readonly CREDENTIALS_FILE="${HOME}/.config/hindsight/credentials"

# 1Password item and vault to read when the op CLI is available. Both are overridable because
# vault names differ between accounts; "Private" is only the common default.
readonly OP_ITEM="${HINDSIGHT_OP_ITEM:-Hindsight API key}"
readonly OP_VAULT="${HINDSIGHT_OP_VAULT:-Private}"

URL="${HINDSIGHT_URL:-http://127.0.0.1:8888}"
BANK="${HINDSIGHT_BANK_ID:-health}"
SERVER_NAME=""
DO_REMOVE=0
API_KEY=""

# Abort with a message naming both the fault and the remedy.
# @param $1  Exit code
# @param $2  What went wrong
# @param $3  What to do about it
# @return Does not return
die() {
    pfb error "$2"
    pfb suggestion "$3"
    exit "$1"
}

# Verify every external command this script calls is present.
# @return 0 when all dependencies resolve
# @side_effects Exits 1 on the first missing dependency
require_dependencies() {
    command -v pfb >/dev/null 2>&1 || {
        printf 'error: pfb is required but not installed\n' >&2
        printf 'Install it with: brew install ali5ter/tap/pfb\n' >&2
        exit 1
    }
    command -v curl >/dev/null 2>&1 || die 1 "curl not found" "Install curl"
    command -v claude >/dev/null 2>&1 || die 1 "The claude CLI is not on PATH" \
        "Install Claude Code first"
    return 0
}

# Find the API key without ever putting it in this repo. Tries the cheapest source first and
# prompts only as a last resort, so the script stays usable unattended.
# @return 0 when a key was obtained; the key is left in API_KEY
# @side_effects May read CREDENTIALS_FILE or invoke op; exits 1 when no key is found
resolve_api_key() {
    if [[ -n "${HINDSIGHT_API_TENANT_API_KEY:-}" ]]; then
        API_KEY="${HINDSIGHT_API_TENANT_API_KEY}"
        pfb subheading "key from the environment"
        return 0
    fi

    if command -v op >/dev/null 2>&1; then
        API_KEY="$(op read "op://${OP_VAULT}/${OP_ITEM}/credential" 2>/dev/null)"
        if [[ -n "${API_KEY}" ]]; then
            pfb subheading "key from 1Password (op://${OP_VAULT}/${OP_ITEM})"
            return 0
        fi
        pfb subheading "op is installed but op://${OP_VAULT}/${OP_ITEM} did not resolve; trying other sources"
    fi

    if [[ -r "${CREDENTIALS_FILE}" ]]; then
        # Accept either a bare key or a KEY=value line, so the file can be sourced too.
        API_KEY="$(sed -n 's/^HINDSIGHT_API_TENANT_API_KEY=//p;' "${CREDENTIALS_FILE}" | head -1)"
        [[ -z "${API_KEY}" ]] && API_KEY="$(grep -v '^[[:space:]]*#' "${CREDENTIALS_FILE}" | head -1 | tr -d '[:space:]')"
        if [[ -n "${API_KEY}" ]]; then
            pfb subheading "key from ${CREDENTIALS_FILE}"
            return 0
        fi
    fi

    if [[ -t 0 ]]; then
        pfb subheading "no key found in the environment, 1Password, or ${CREDENTIALS_FILE}"
        API_KEY="$(pfb input "Hindsight API key" "")"
        [[ -n "${API_KEY}" ]] && return 0
    fi

    die 1 "No Hindsight API key available" \
        "Set HINDSIGHT_API_TENANT_API_KEY, or write it to ${CREDENTIALS_FILE} with chmod 600"
}

# The bank is part of the path, so each connection is scoped to exactly one bank and the tools
# need no bank argument.
# @return 0; endpoint URL written to stdout
mcp_endpoint() {
    printf '%s/mcp/%s/\n' "${URL%/}" "${BANK}"
}

# Confirm the endpoint answers, refuses anonymous callers, and accepts this key, before writing
# any configuration. A registration pointing at an unreachable or open service is worse than none.
# @return 0 when the endpoint is reachable and correctly authenticated
# @side_effects Exits 2 on an unreachable or misconfigured endpoint
probe_endpoint() {
    local endpoint
    endpoint="$(mcp_endpoint)"
    pfb subheading "endpoint ${endpoint}"

    local anon
    anon="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -X POST "${endpoint}" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' 2>/dev/null)"

    [[ "${anon}" == "000" ]] && die 2 "No response from ${endpoint}" \
        "Confirm the service is running, and that this machine can reach ${URL}"

    case "${anon}" in
        401|403) pfb success "Unauthenticated requests are refused (HTTP ${anon})" ;;
        *) pfb warn "An unauthenticated request returned HTTP ${anon}, not 401 — the endpoint may be open" ;;
    esac

    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -X POST "${endpoint}" \
        -H "Authorization: Bearer ${API_KEY}" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"carrybag","version":"1"}}}' 2>/dev/null)"

    case "${code}" in
        2*) pfb success "The key was accepted" ;;
        401|403) die 2 "The service refused this key (HTTP ${code})" \
                     "Check the key against the service's HINDSIGHT_API_TENANT_API_KEY" ;;
        *) die 2 "Unexpected HTTP ${code} from the MCP endpoint" \
               "Check the service log on the host running Hindsight" ;;
    esac
    return 0
}

# Register the endpoint, replacing any existing entry of the same name.
# @return 0 when Claude Code accepted it
# @side_effects Writes the server and its bearer token into ~/.claude.json
register() {
    local endpoint
    endpoint="$(mcp_endpoint)"

    if claude mcp get "${SERVER_NAME}" >/dev/null 2>&1; then
        pfb subheading "replacing the existing ${SERVER_NAME} registration"
        claude mcp remove --scope user "${SERVER_NAME}" >/dev/null 2>&1 \
            || pfb warn "Could not remove the existing registration; continuing"
    fi

    claude mcp add --scope user --transport http "${SERVER_NAME}" "${endpoint}" \
        --header "Authorization: Bearer ${API_KEY}" \
        || die 3 "Claude Code refused the registration" \
               "Try it by hand to see the error, then check: claude mcp list"

    pfb success "Registered ${SERVER_NAME} in the user scope"
    pfb subheading "the key now lives in ~/.claude.json — never commit that file"
    return 0
}

# Remove the registration, tolerating it not being present.
# @return 0
# @side_effects Removes the server from ~/.claude.json
remove() {
    if claude mcp remove --scope user "${SERVER_NAME}" 2>/dev/null; then
        pfb success "Removed ${SERVER_NAME}"
    else
        pfb subheading "${SERVER_NAME} was not registered"
    fi
    return 0
}

main() {
    require_dependencies

    while (( $# )); do
        case "$1" in
            --url) URL="${2:?--url needs a value}"; shift 2 ;;
            --bank) BANK="${2:?--bank needs a value}"; shift 2 ;;
            --name) SERVER_NAME="${2:?--name needs a value}"; shift 2 ;;
            --remove) DO_REMOVE=1; shift ;;
            -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) die 1 "Unknown argument: $1" "Run with --help to see usage" ;;
        esac
    done

    SERVER_NAME="${SERVER_NAME:-hindsight-${BANK}}"

    pfb heading "Hindsight MCP registration" "🧠"

    if (( DO_REMOVE )); then
        remove
        exit 0
    fi

    resolve_api_key

    pfb heading "Probing" "🩺"
    probe_endpoint

    pfb heading "Registering" "📝"
    register

    pfb heading "Next" "👉"
    pfb subheading "Confirm with: claude mcp list"
    pfb subheading "Tools are exposed as mcp__${SERVER_NAME}__<tool>, e.g. mcp__${SERVER_NAME}__recall"
    exit 0
}

main "$@"
