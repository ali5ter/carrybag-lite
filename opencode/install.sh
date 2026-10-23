#!/usr/bin/env bash
#
# install.sh - Install OpenCode configuration
#
# Symlinks CLAUDE.md from the carrybag-lite claude/ directory into the OpenCode
# config directory, and writes ~/.opencode.json with a local Ollama provider
# when available. OpenCode discovers models at startup from LOCAL_ENDPOINT via
# the OpenAI-compatible /v1/models endpoint — no per-model config needed.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.1.0
# Date: 2026-10-23
# License: MIT
#
# Usage: ./opencode/install.sh
#   LOCAL_ENDPOINT=<url> ./opencode/install.sh   # custom Ollama endpoint
#   OPENCODE_LOCAL_MODEL=<name> ./opencode/install.sh  # force a specific model
#   Backs up any existing file before replacing it; running twice is idempotent.
#
# Dependencies: bash 4.0+, jq; optional: ollama, pfb
#
# Exit codes:
#   0 - Success
#   1 - Source file or jq not found

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(realpath "$SCRIPT_DIR" 2>/dev/null || printf '%s' "$SCRIPT_DIR")"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OPENCODE_DIR="$HOME/.opencode"
CLAUDE_PLUGIN_CACHE="$HOME/.claude/plugins/cache"
SOURCE="$REPO_DIR/claude/CLAUDE.md"
DEST="$OPENCODE_DIR/AGENTS.md"
CONFIG="$OPENCODE_DIR/.opencode.json"

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

backup_if_exists() {
    # Move an existing regular file aside to a timestamped copy. No-op for a missing
    # file or a symlink.
    # @param $1  Absolute path of the file to check and back up
    # @return 0
    # @example backup_if_exists "$HOME/.opencode/.opencode.json"
    # @side_effects Moves the file to <path>.backup.YYYYMMDDHHMMSS
    local file="$1" backup
    if [[ -f "$file" && ! -L "$file" ]]; then
        backup="${file}.backup.$(date +"%Y%m%d%H%M%S")"
        pfb info "  Backing up existing $(basename "$file") to $(basename "$backup")"
        mv "$file" "$backup"
    fi
}

local_endpoint() {
    # Print the Ollama endpoint: LOCAL_ENDPOINT env var, or derive from OLLAMA_HOST.
    # @return 0; prints nothing when no endpoint is available
    # @example endpoint="$(local_endpoint)"
    if [[ -n "${LOCAL_ENDPOINT:-}" ]]; then
        printf '%s' "$LOCAL_ENDPOINT"
    elif [[ -n "${OLLAMA_HOST:-}" ]]; then
        printf 'http://%s/v1' "$OLLAMA_HOST"
    fi
    return 0
}

first_model() {
    # Print the first Ollama model name: OPENCODE_LOCAL_MODEL, else the first model
    # listed by the remote endpoint. Prints nothing when no model is available.
    # @return 0; prints nothing when no model found
    # @example model="$(first_model)"
    if [[ -n "${OPENCODE_LOCAL_MODEL:-}" ]]; then
        echo "$OPENCODE_LOCAL_MODEL"
    elif [[ -n "${LOCAL_ENDPOINT:-}" ]]; then
        local models
        models="$(curl -s "${LOCAL_ENDPOINT%/v1}"'/v1/models' 2>/dev/null | jq -r '.data[].id' 2>/dev/null)"
        echo "$models" | head -1
    elif type ollama >/dev/null 2>&1; then
        ollama list 2>/dev/null | awk 'NR==2 {print $1}'
    fi
    return 0
}

build_config() {
    # Print the ~/.opencode.json content.
    # @param $1  Ollama model name (e.g. "qwen3.6:35b-a3b-coding"), or empty for baseline
    # @param $2  LOCAL_ENDPOINT to enable the local provider, or empty
    # @return 0; JSON on stdout
    # @example build_config "qwen3:8b" "http://192.168.1.63:11434/v1"
    local model="$1" endpoint="$2"
    local local_provider="" local_agents=""

    if [[ -n "$model" && -n "$endpoint" ]]; then
        local host="${endpoint%/v1}"
        local_provider=$(jq -n --arg host "$host" '{
            "local": {
                "apiKey": "dummy",
                "disabled": false
            }
        }')
        # Model ID prefix is "local." + the Ollama model name
        local model_id="local.${model}"
        local_agents=$(jq -n --arg mid "$model_id" '{
            "coder": { "model": $mid, "maxTokens": 131072 },
            "task":  { "model": $mid, "maxTokens": 4096 },
            "title": { "model": $mid, "maxTokens": 80 }
        }')
    fi

    jq -n \
        --argjson local_provider "${local_provider:-null}" \
        --argjson local_agents "${local_agents:-null}" \
        '{
            "autoCompact": true,
            "contextPaths": [
                ".github/copilot-instructions.md",
                "CLAUDE.md",
                "CLAUDE.local.md",
                "opencode.md",
                "opencode.local.md"
            ]
        }
        + (if $local_provider != null then { "providers": $local_provider } else {} end)
        + (if $local_agents  != null then $local_agents  else {} end)'
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
    # Write ~/.opencode.json, backing up the old file only when the content changes.
    # @return 0
    # @example write_config
    # @side_effects Creates or replaces ~/.opencode/.opencode.json
    local model endpoint new
    model="$(first_model)"
    endpoint="$(local_endpoint)"
    new="$(build_config "$model" "$endpoint")"
    if [[ -f "$CONFIG" && "$(cat "$CONFIG")" == "$new" ]]; then
        pfb info "  .opencode.json already up to date"
        return 0
    fi
    backup_if_exists "$CONFIG"
    echo "$new" > "$CONFIG"
    if [[ -n "$model" ]]; then
        pfb success "  Wrote .opencode.json (local: $model via $endpoint)"
    else
        pfb success "  Wrote .opencode.json (baseline; no local endpoint or model)"
    fi
}

main() {
    pfb heading "Installing OpenCode configuration" "🤖"
    echo

    if [[ ! -f "$SOURCE" ]]; then
        pfb error "Source not found: $SOURCE"
        exit 1
    fi
    if ! type jq >/dev/null 2>&1; then
        pfb error "jq is required to write .opencode.json. Install it (brew install jq / apt install jq) and rerun."
        exit 1
    fi

    mkdir -p "$OPENCODE_DIR"
    backup_if_exists "$DEST"
    ln -sfn "$SOURCE" "$DEST"
    pfb success "  Linked AGENTS.md"

    link_plugin_skills
    write_config

    echo
    pfb success "OpenCode configuration installed!"
    pfb info "  Config location: $OPENCODE_DIR"
    pfb info "  AGENTS.md location: $DEST"
    pfb info "  Source location: $SOURCE"
}

main "$@"
