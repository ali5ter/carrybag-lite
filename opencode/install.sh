#!/usr/bin/env bash
#
# install.sh - Install OpenCode configuration
#
# Symlinks CLAUDE.md from the carrybag-lite claude/ directory to ~/.config/opencode/AGENTS.md,
# making the shared development principles available to OpenCode (OpenCode 2.0.20 does not
# fall back to ~/.claude/CLAUDE.md). Links plugin-installed Claude Code skills into
# ~/.config/opencode/skills/ (user skills in ~/.claude/skills/ are discovered natively), and
# writes a baseline opencode.json. When ollama is installed the config also gets a local lane:
# an Ollama provider, a default model, and enabled_providers restricted to ollama.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-10-07
# License: MIT
#
# Usage: ./opencode/install.sh
#   OPENCODE_LOCAL_MODEL=<name> ./opencode/install.sh   # pick the Ollama model (default: first listed)
#   Backs up any existing file before replacing it; running twice changes nothing.
#
# Dependencies: bash 4.0+, jq; optional: ollama, pfb
#
# Exit codes:
#   0 - Success
#   1 - Source file or jq not found

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OPENCODE_DIR="$HOME/.config/opencode"
CLAUDE_PLUGIN_CACHE="$HOME/.claude/plugins/cache"
SOURCE="$REPO_DIR/claude/CLAUDE.md"
DEST="$OPENCODE_DIR/AGENTS.md"
CONFIG="$OPENCODE_DIR/opencode.json"

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

backup_if_exists() {
    # Move an existing regular file aside to a timestamped copy. No-op for a missing
    # file or a symlink.
    # @param $1  Absolute path of the file to check and back up
    # @return 0
    # @example backup_if_exists "$HOME/.config/opencode/AGENTS.md"
    # @side_effects Moves the file to <path>.backup.YYYYMMDDHHMMSS
    local file="$1" backup
    if [[ -f "$file" && ! -L "$file" ]]; then
        backup="${file}.backup.$(date +"%Y%m%d%H%M%S")"
        pfb info "  Backing up existing $(basename "$file") to $(basename "$backup")"
        mv "$file" "$backup"
    fi
}

local_model() {
    # Print the Ollama model to use: OPENCODE_LOCAL_MODEL, else the first model ollama lists.
    # @return 0; prints nothing when ollama is absent or has no models
    # @example model="$(local_model)"
    if [[ -n "${OPENCODE_LOCAL_MODEL:-}" ]]; then
        echo "$OPENCODE_LOCAL_MODEL"
    elif type ollama >/dev/null 2>&1; then
        ollama list 2>/dev/null | awk 'NR==2 {print $1}'
    fi
    return 0
}

build_config() {
    # Print the opencode.json content. Baseline always; Ollama lane only when a model exists.
    # @param $1  Ollama model name, or empty for the baseline only
    # @return 0; JSON on stdout
    # @example build_config "qwen3:8b"
    local model="$1"
    jq -n --arg model "$model" '
        {
            "$schema": "https://opencode.ai/config.json",
            "autoupdate": false,
            "share": "disabled"
        }
        + (if $model == "" then {} else {
            "model": ("ollama/" + $model),
            "enabled_providers": ["ollama"],
            "provider": {
                "ollama": {
                    "npm": "@ai-sdk/openai-compatible",
                    "name": "Ollama",
                    "options": {"baseURL": "http://localhost:11434/v1"},
                    "models": {($model): {"name": $model}}
                }
            }
        } end)'
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
    # Write opencode.json, backing up the old file only when the content changes.
    # @return 0
    # @example write_config
    # @side_effects Creates or replaces ~/.config/opencode/opencode.json
    local model new
    model="$(local_model)"
    new="$(build_config "$model")"
    if [[ -f "$CONFIG" && "$(cat "$CONFIG")" == "$new" ]]; then
        pfb info "  opencode.json already up to date"
        return 0
    fi
    backup_if_exists "$CONFIG"
    echo "$new" >"$CONFIG"
    if [[ -n "$model" ]]; then
        pfb success "  Wrote opencode.json (local lane: ollama/$model)"
    else
        pfb success "  Wrote opencode.json (baseline; no ollama model found)"
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
        pfb error "jq is required to write opencode.json. Install it (brew install jq / apt install jq) and rerun."
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
    pfb info "  Source location: $SOURCE"
}

main "$@"
