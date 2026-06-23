#!/usr/bin/env bash
#
# install.sh - Install Codex CLI configuration
#
# Symlinks CLAUDE.md from the carrybag-lite claude/ directory to ~/.codex/AGENTS.md,
# making the shared development principles available to OpenAI Codex CLI. Also links
# Claude Code skills — both plugin-installed (~/.claude/plugins/cache/) and user-defined
# (~/.claude/skills/) — into ~/.codex/skills/. Part of the Carrybag-lite environment setup.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 2.1.0
# Date: 2026-06-23
# License: MIT
#
# Usage: ./codex/install.sh
#   Creates symlink from ~/.codex/AGENTS.md to carrybag-lite/claude/CLAUDE.md
#   Links plugin-installed and user-defined Claude Code skills into ~/.codex/skills/
#   Backs up any existing file before symlinking
#
# Dependencies: bash 4.0+
#
# Exit codes:
#   0 - Success
#   1 - Source file not found

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CODEX_DIR="$HOME/.codex"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_PLUGIN_CACHE="$HOME/.claude/plugins/cache"
SOURCE="$REPO_DIR/claude/CLAUDE.md"
DEST="$CODEX_DIR/AGENTS.md"

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

pfb heading "Installing Codex CLI configuration" "🤖"
echo

if [[ ! -f "$SOURCE" ]]; then
    pfb error "Source not found: $SOURCE"
    exit 1
fi

mkdir -p "$CODEX_DIR"

if [[ -f "$DEST" && ! -L "$DEST" ]]; then
    backup="${DEST}.backup.$(date +"%Y%m%d%H%M%S")"
    pfb info "  Backing up existing AGENTS.md to $(basename "$backup")"
    mv "$DEST" "$backup"
fi

ln -sf "$SOURCE" "$DEST"
pfb success "  Linked AGENTS.md"

# Link Claude Code skills into Codex's skills directory.
# Plugin skills (cache/<ns>/<plugin>/<ver>/skills/) are linked first;
# user skills (~/.claude/skills/) are linked second and take precedence.
SKILLS_DEST="$CODEX_DIR/skills"
mkdir -p "$SKILLS_DEST"
linked=0

if [[ -d "$CLAUDE_PLUGIN_CACHE" ]]; then
    while IFS= read -r -d '' skills_dir; do
        for skill in "$skills_dir"/*/; do
            [[ -d "$skill" ]] || continue
            skill_name="$(basename "$skill")"
            dest="$SKILLS_DEST/$skill_name"
            [[ -e "$dest" && ! -L "$dest" ]] && { pfb warn "  Skipping non-symlink: $skill_name"; continue; }
            ln -sf "$skill" "$dest"
            pfb success "  Linked skill: $skill_name"
            (( linked++ )) || true
        done
    done < <(find "$CLAUDE_PLUGIN_CACHE" -mindepth 4 -maxdepth 4 -type d -name "skills" -print0 2>/dev/null)
fi

for skill in "$CLAUDE_SKILLS_DIR"/*/; do
    [[ -d "$skill" ]] || continue
    skill_name="$(basename "$skill")"
    dest="$SKILLS_DEST/$skill_name"
    [[ -e "$dest" && ! -L "$dest" ]] && { pfb warn "  Skipping non-symlink: $skill_name"; continue; }
    ln -sf "$skill" "$dest"
    pfb success "  Linked skill: $skill_name (user)"
    (( linked++ )) || true
done

if [[ $linked -eq 0 ]]; then
    pfb info "  No skills found in ~/.claude/skills/ or plugin cache"
fi

echo
pfb success "Codex CLI configuration installed!"
pfb info "  Config location: $CODEX_DIR"
pfb info "  Source location: $SOURCE"
echo

if [[ -L "$DEST" ]]; then
    pfb info "Symlinked file:"
    ls -lh "$DEST"
fi
