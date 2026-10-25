#!/usr/bin/env bash
#
# install.sh - Install OpenCode configuration
#
# Symlinks CLAUDE.md from the carrybag-lite claude/ directory into
# ~/.config/opencode/AGENTS.md, links plugin-installed Claude Code skills into
# ~/.config/opencode/skills/, and merges a baseline into the global OpenCode
# config (~/.config/opencode/opencode.json). When an Ollama endpoint answers, the config also gains a local lane:
# a custom "ollama" provider listing every model the endpoint serves, with
# enabled_providers restricted to it so no cloud provider is reached by accident.
#
# Endpoint resolution order: LOCAL_ENDPOINT, OLLAMA_HOST, ~/.config/ollama_host,
# then http://localhost:11434/v1.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 2.0.0
# Date: 2026-10-23
# License: MIT
#
# Usage: ./opencode/install.sh
#   LOCAL_ENDPOINT=<url> ./opencode/install.sh          # explicit Ollama endpoint
#   OPENCODE_LOCAL_MODEL=<name> ./opencode/install.sh   # preferred default model
#   OPENCODE_CONTEXT_LIMIT=<tokens> OPENCODE_OUTPUT_LIMIT=<tokens> ./opencode/install.sh
#   Backs up any existing file before replacing it; running twice is idempotent.
#   Keys the script does not manage are preserved; comments are stripped before parsing.
#
# Dependencies: bash 4.0+, curl, jq; optional: pfb
#
# Exit codes:
#   0 - Success
#   1 - Source file, curl or jq not found
#   2 - Existing OpenCode config could not be parsed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(realpath "$SCRIPT_DIR" 2>/dev/null || printf '%s' "$SCRIPT_DIR")"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OPENCODE_DIR="$HOME/.config/opencode"
CLAUDE_PLUGIN_CACHE="$HOME/.claude/plugins/cache"
SOURCE="$REPO_DIR/claude/CLAUDE.md"
DEST="$OPENCODE_DIR/AGENTS.md"
CONFIG_JSON="$OPENCODE_DIR/opencode.json"
CONFIG_JSONC="$OPENCODE_DIR/opencode.jsonc"
OLLAMA_HOST_FILE="$HOME/.config/ollama_host"
PROVIDER="ollama"
# OpenCode needs at least a 64k context window; the shared Studio serves 128k.
CONTEXT_LIMIT="${OPENCODE_CONTEXT_LIMIT:-131072}"
OUTPUT_LIMIT="${OPENCODE_OUTPUT_LIMIT:-32768}"
CURL_TIMEOUT=5

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

backup_if_exists() {
    # Move an existing regular file aside to a timestamped copy. No-op for a missing
    # file or a symlink.
    # @param $1  Absolute path of the file to check and back up
    # @return 0
    # @example backup_if_exists "$HOME/.config/opencode/opencode.json"
    # @side_effects Moves the file to <path>.backup.YYYYMMDDHHMMSS
    local file="$1" backup
    if [[ -f "$file" && ! -L "$file" ]]; then
        backup="${file}.backup.$(date +"%Y%m%d%H%M%S")"
        pfb info "  Backing up existing $(basename "$file") to $(basename "$backup")"
        mv "$file" "$backup"
    fi
}

normalize_endpoint() {
    # Turn a host:port or URL into an OpenAI-compatible base URL ending in /v1.
    # @param $1  Endpoint as host:port, http://host:port or http://host:port/v1
    # @return 0; prints the normalized URL
    # @example normalize_endpoint 192.168.1.63:11434  # -> http://192.168.1.63:11434/v1
    local url="${1%/}"
    [[ "$url" == http://* || "$url" == https://* ]] || url="http://$url"
    [[ "$url" == */v1 ]] || url="$url/v1"
    printf '%s' "$url"
}

local_endpoint() {
    # Print the Ollama endpoint: LOCAL_ENDPOINT, then OLLAMA_HOST, then the
    # ~/.config/ollama_host file bash_profile reads, then localhost.
    # @return 0; prints the normalized endpoint URL
    # @example endpoint="$(local_endpoint)"
    local raw
    if [[ -n "${LOCAL_ENDPOINT:-}" ]]; then
        raw="$LOCAL_ENDPOINT"
    elif [[ -n "${OLLAMA_HOST:-}" ]]; then
        raw="$OLLAMA_HOST"
    elif [[ -r "$OLLAMA_HOST_FILE" && -s "$OLLAMA_HOST_FILE" ]]; then
        raw="$(<"$OLLAMA_HOST_FILE")"
    else
        raw="localhost:11434"
    fi
    normalize_endpoint "$raw"
}

list_models() {
    # Print the model ids an Ollama endpoint serves, one per line.
    # @param $1  Endpoint base URL ending in /v1
    # @return 0; prints nothing when the endpoint does not answer
    # @example list_models "http://192.168.1.63:11434/v1"
    curl -s --max-time "$CURL_TIMEOUT" "$1/models" 2>/dev/null \
        | jq -r '.data[]?.id // empty' 2>/dev/null || true
}

model_context_length() {
    # Print the architecture context length Ollama reports for a model, so the
    # configured limit never overstates what the model can take.
    # @param $1  Endpoint base URL ending in /v1
    # @param $2  Model id
    # @return 0; prints nothing when unavailable
    # @example model_context_length "http://localhost:11434/v1" "qwen3.8:27b"
    curl -s --max-time "$CURL_TIMEOUT" "${1%/v1}/api/show" -d "{\"model\":\"$2\"}" 2>/dev/null \
        | jq -r '.model_info | to_entries[] | select(.key | endswith(".context_length")) | .value' 2>/dev/null \
        | head -1 || true
}

build_provider() {
    # Print the provider block for the Ollama endpoint, one entry per model with
    # explicit context/output limits (both required by the OpenCode schema).
    # @param $1  Endpoint base URL ending in /v1
    # @param $@  Model ids (after $1)
    # @return 0; JSON on stdout
    # @example build_provider "http://localhost:11434/v1" qwen3.8:27b
    local endpoint="$1" host models="{}" model arch context
    shift
    host="${endpoint#http://}"; host="${host#https://}"; host="${host%/v1}"
    for model in "$@"; do
        context="$CONTEXT_LIMIT"
        arch="$(model_context_length "$endpoint" "$model")"
        if [[ "$arch" =~ ^[0-9]+$ && "$arch" -lt "$context" ]]; then
            context="$arch"
        fi
        models="$(jq -n --argjson m "$models" --arg id "$model" \
            --argjson ctx "$context" --argjson out "$OUTPUT_LIMIT" \
            '$m + { ($id): { name: $id, limit: { context: $ctx, output: $out } } }')"
    done
    jq -n --arg host "$host" --arg url "$endpoint" --argjson models "$models" '{
        npm: "@ai-sdk/openai-compatible",
        name: ("Ollama (" + $host + ")"),
        options: { baseURL: $url },
        models: $models
    }'
}

pick_default_model() {
    # Choose the default model: OPENCODE_LOCAL_MODEL when the endpoint serves it,
    # else the model the existing config already points at when still served, else
    # the first served id.
    # @param $1  Existing config JSON
    # @param $@  Served model ids (after $1)
    # @return 0; prints the model id
    # @example pick_default_model "$existing" qwen3.8:27b qwen3.6:35b-a3b-coding
    local existing="$1" current
    shift
    if [[ -n "${OPENCODE_LOCAL_MODEL:-}" ]]; then
        if printf '%s\n' "$@" | grep -qxF -- "$OPENCODE_LOCAL_MODEL"; then
            printf '%s' "$OPENCODE_LOCAL_MODEL"
            return 0
        fi
        pfb warn "  OPENCODE_LOCAL_MODEL=$OPENCODE_LOCAL_MODEL is not served by the endpoint; falling back." >&2
    fi
    current="$(jq -r --arg p "$PROVIDER/" '.model // "" | select(startswith($p)) | ltrimstr($p)' <<<"$existing")"
    if [[ -n "$current" ]] && printf '%s\n' "$@" | grep -qxF -- "$current"; then
        printf '%s' "$current"
    else
        printf '%s' "$1"
    fi
}

build_config() {
    # Merge the managed keys into an existing config. Unmanaged keys survive; the
    # ollama provider block is replaced wholesale so stale models never linger.
    # @param $1  Existing config JSON ("{}" when none)
    # @param $2  Provider block JSON, or empty when no endpoint answered
    # @param $3  Default model id, or empty
    # @return 0; JSON on stdout
    # @example build_config '{}' "$provider" qwen3.8:27b
    local existing="$1" provider="$2" model="$3"
    jq --arg p "$PROVIDER" --argjson prov "${provider:-null}" --arg model "$model" '
        . + { "$schema": "https://opencode.ai/config.json", autoupdate: false, share: "disabled" }
        | if $prov != null then
            .plugins[$p] = $prov
            | .enabled_providers = (((.enabled_providers // []) + [$p]) | unique)
            | .model = ($p + "/" + $model)
          else . end' <<<"$existing"
}

target_config() {
    # Print the config file to write: opencode.json by default. If an opencode.jsonc
    # exists but no opencode.json does (a leftover from a prior run), honour the
    # existing file to avoid racing OpenCode which loads both formats.
    # @return 0; prints the path
    # @example target="$(target_config)"
    if [[ -f "$CONFIG_JSONC" && ! -f "$CONFIG_JSON" ]]; then
        printf '%s' "$CONFIG_JSONC"
    else
        printf '%s' "$CONFIG_JSON"
    fi
}

read_existing() {
    # Print an existing config as plain JSON, dropping whole-line // comments so a
    # JSONC file parses. Inline comments and trailing commas are not handled.
    # @param $1  Config path
    # @return 0 with JSON on stdout; 1 when the file exists but does not parse
    # @example existing="$(read_existing "$CONFIG_JSONC")"
    local file="$1"
    [[ -f "$file" ]] || { printf '{}'; return 0; }
    sed -E 's#^[[:space:]]*//.*$##' "$file" | jq -e 'if type == "object" then . else error("not an object") end' 2>/dev/null
}

link_plugin_skills() {
    # Link plugin-installed Claude Code skills (cache/<ns>/<plugin>/<ver>/skills/*) into
    # OpenCode's skills directory. User skills need no linking: OpenCode reads ~/.claude/skills.
    # @return 0
    # @example link_plugin_skills
    # @side_effects Creates symlinks under ~/.config/opencode/skills/
    local skills_dest="$OPENCODE_DIR/skills" skills_dir skill skill_name dest linked=0
    mkdir -p "$skills_dest"
    if [[ -d "$CLAUDE_PLUGIN_CACHE" ]]; then
        while IFS= read -r -d '' skills_dir; do
            for skill in "$skills_dir"/*/; do
                [[ -d "$skill" ]] || continue
                skill_name="$(basename "$skill")"
                dest="$skills_dest/$skill_name"
                [[ -e "$dest" && ! -L "$dest" ]] && { pfb warn "  Skipping non-symlink: $skill_name"; continue; }
                ln -sfn "$skill" "$dest"
                pfb success "  Linked skill: $skill_name"
                (( linked++ )) || true
            done
        done < <(find "$CLAUDE_PLUGIN_CACHE" -mindepth 4 -maxdepth 4 -type d -name "skills" -print0 2>/dev/null)
    fi
    [[ $linked -gt 0 ]] || pfb info "  No plugin skills found in $CLAUDE_PLUGIN_CACHE"
    return 0
}

write_config() {
    # Write the global OpenCode config, backing up the old file only when the
    # content changes.
    # @return 0 on success, 2 when the existing config cannot be parsed
    # @example write_config
    # @side_effects Creates or replaces ~/.config/opencode/opencode.json[c]
    local target existing endpoint provider="" model="" new
    local -a models=()
    target="$(target_config)"
    if ! existing="$(read_existing "$target")"; then
        pfb error "Cannot parse $target as JSON. Whole-line // comments are fine; inline comments and trailing commas are not. Fix it or move it aside, then rerun."
        return 2
    fi

    endpoint="$(local_endpoint)"
    while IFS= read -r line; do [[ -n "$line" ]] && models+=("$line"); done < <(list_models "$endpoint")
    if [[ ${#models[@]} -gt 0 ]]; then
        model="$(pick_default_model "$existing" "${models[@]}")"
        provider="$(build_provider "$endpoint" "${models[@]}")"
    else
        pfb warn "  No Ollama models at $endpoint; writing baseline without a local provider."
        pfb warn "  Set LOCAL_ENDPOINT, OLLAMA_HOST or ~/.config/ollama_host and rerun to add one."
    fi

    new="$(build_config "$existing" "$provider" "$model")"
    if [[ -f "$target" && "$(cat "$target")" == "$new" ]]; then
        pfb info "  $(basename "$target") already up to date"
        return 0
    fi
    backup_if_exists "$target"
    printf '%s\n' "$new" > "$target"
    if [[ -n "$provider" ]]; then
        pfb success "  Wrote $(basename "$target") ($PROVIDER/$model default; ${#models[@]} model(s) via $endpoint)"
        pfb info "  Change the default with OPENCODE_LOCAL_MODEL=<id> $(basename "$0"), or /models inside opencode"
    else
        pfb success "  Wrote $(basename "$target") (baseline)"
    fi
}

main() {
    pfb heading "Installing OpenCode configuration" "🤖"
    echo

    if [[ ! -f "$SOURCE" ]]; then
        pfb error "Source not found: $SOURCE"
        exit 1
    fi
    local tool
    for tool in curl jq; do
        if ! type "$tool" >/dev/null 2>&1; then
            pfb error "$tool is required to write opencode.json. Install it (brew install $tool / apt install $tool) and rerun."
            exit 1
        fi
    done

    mkdir -p "$OPENCODE_DIR"
    backup_if_exists "$DEST"
    ln -sfn "$SOURCE" "$DEST"
    pfb success "  Linked AGENTS.md"

    link_plugin_skills
    write_config || exit $?

    echo
    pfb success "OpenCode configuration installed!"
    pfb info "  Config location: $OPENCODE_DIR"
    pfb info "  AGENTS.md location: $DEST"
    pfb info "  Source location: $SOURCE"
}

main "$@"
