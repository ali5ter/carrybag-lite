#!/usr/bin/env bash
#
# install.sh - Install Antigravity CLI configuration
#
# Symlinks CLAUDE.md from the carrybag-lite claude/ directory to
# ~/.gemini/config/AGENTS.md, making the shared development principles
# available to the Antigravity CLI (agy). Also links Claude Code skills —
# both plugin-installed (~/.claude/plugins/cache/) and user-defined
# (~/.claude/skills/) — into ~/.gemini/config/skills/. Part of the Carrybag-lite
# environment setup.
#
# Antigravity CLI (agy) uses ~/.gemini/config/ as its Global Customizations Root:
#   - ~/.gemini/config/AGENTS.md       → global rules read by agy on every run
#   - ~/.gemini/config/skills/<name>/  → global skills available in all sessions
#   - ~/.gemini/antigravity-cli/       → agy's own runtime/data directory
#
# Antigravity CLI (agy) is the successor to Gemini CLI.
# Install via: brew install --cask antigravity-cli
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 2.2.0
# Date: 2026-06-25
# License: MIT
#
# Usage: ./antigravity/install.sh
#   Creates symlink from ~/.gemini/config/AGENTS.md to carrybag-lite/claude/CLAUDE.md
#   Links plugin-installed and user-defined Claude Code skills into ~/.gemini/config/skills/
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
ANTIGRAVITY_DIR="$HOME/.gemini/config"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_PLUGIN_CACHE="$HOME/.claude/plugins/cache"
SOURCE="$REPO_DIR/claude/CLAUDE.md"
DEST="$ANTIGRAVITY_DIR/AGENTS.md"

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

pfb heading "Installing Antigravity CLI configuration" "🤖"
echo

if [[ ! -f "$SOURCE" ]]; then
    pfb error "Source not found: $SOURCE"
    exit 1
fi

mkdir -p "$ANTIGRAVITY_DIR"

if [[ -f "$DEST" && ! -L "$DEST" ]]; then
    backup="${DEST}.backup.$(date +"%Y%m%d%H%M%S")"
    pfb info "  Backing up existing AGENTS.md to $(basename "$backup")"
    mv "$DEST" "$backup"
fi

ln -sf "$SOURCE" "$DEST"
pfb success "  Linked AGENTS.md"

# Link Claude Code skills into Antigravity's global skills directory.
# Plugin skills (cache/<ns>/<plugin>/<ver>/skills/) are linked first;
# user skills (~/.claude/skills/) are linked second and take precedence.
SKILLS_DEST="$ANTIGRAVITY_DIR/skills"
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
pfb success "Antigravity CLI configuration installed!"
pfb info "  Config location: $ANTIGRAVITY_DIR"
pfb info "  Source location: $SOURCE"
echo

if [[ -L "$DEST" ]]; then
    pfb info "Symlinked file:"
    ls -lh "$DEST"
fi

# Migration notice: detect deprecated gemini-cli
if type brew >/dev/null 2>&1 && brew list gemini-cli >/dev/null 2>&1; then
    echo
    pfb warn "gemini-cli is still installed (deprecated 2026-12-18)" "⚠️"
    pfb info "  To remove: brew uninstall gemini-cli"
fi

# Clean up stale ~/.antigravity/ if it exists from prior carrybag-lite versions
if [[ -d "$HOME/.antigravity" ]]; then
    echo
    pfb warn "~/.antigravity/ is a stale directory from an older carrybag-lite install" "⚠️"
    pfb info "  agy uses ~/.gemini/config/ — safe to remove: rm -rf ~/.antigravity"
fi
