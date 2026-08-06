#!/usr/bin/env bash
#
# install.sh - Install Claude Code configuration
#
# Symlinks Claude Code configuration files from Carrybag-lite repo to ~/.claude/
# Part of the Carrybag-lite environment setup.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-02-05
# License: MIT
#
# Usage: ./claude/install.sh
#   Creates symlinks from ~/.claude/ to carrybag-lite/claude/
#   Backs up any existing files before symlinking
#
# Dependencies: bash 4.0+
#
# Exit codes:
#   0 - Success
#   1 - Errors during installation

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

# Create ~/.claude if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Backup an existing regular file to a timestamped copy before symlinking.
# No-op if the file does not exist or is already a symlink.
# @param $1  Absolute path of the file to check and back up
# @return 0
# @example backup_if_exists "$HOME/.claude/CLAUDE.md"
backup_if_exists() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
        local backup
        backup="${file}.backup-$(date +%Y%m%d%H%M%S)"
        pfb info "  Backing up existing $(basename "$file") to $(basename "$backup")"
        mv "$file" "$backup"
    fi
}

pfb heading "Installing Claude Code configuration" "🤖"
echo

# Files to symlink
files=(
    "CLAUDE.md"
    "settings.json"
    "statusline-command.sh"
)

for file in "${files[@]}"; do
    target="$CLAUDE_DIR/$file"
    source="$SCRIPT_DIR/$file"

    if [[ -f "$source" ]]; then
        backup_if_exists "$target"
        ln -sf "$source" "$target"
        pfb success "  Linked $file"
    else
        pfb warn "  Skipping $file (not found in repo)"
    fi
done

# Skill directories to symlink into ~/.claude/skills/. Globbed rather than listed, so a new
# skill is picked up simply by adding its directory to claude/skills/.
skills_src="$SCRIPT_DIR/skills"
if [[ -d "$skills_src" ]]; then
    mkdir -p "$CLAUDE_DIR/skills"
    for skill in "$skills_src"/*/; do
        [[ -d "$skill" ]] || continue
        name="$(basename "$skill")"
        target="$CLAUDE_DIR/skills/$name"

        # Back up a real directory; a symlink from a previous run is simply replaced
        if [[ -d "$target" ]] && [[ ! -L "$target" ]]; then
            backup="${target}.backup-$(date +%Y%m%d%H%M%S)"
            pfb info "  Backing up existing skill $name to $(basename "$backup")"
            mv "$target" "$backup"
        fi

        # -n is required: without it, ln follows the existing symlink and nests
        # the new link inside the target directory instead of replacing it
        ln -sfn "${skill%/}" "$target"
        pfb success "  Linked skill $name"
    done
fi

echo
pfb success "Claude Code configuration installed!"
pfb info "  Config location: $CLAUDE_DIR"
pfb info "  Source location: $SCRIPT_DIR"
echo

if [[ -L "$CLAUDE_DIR/CLAUDE.md" ]] && \
   [[ -L "$CLAUDE_DIR/settings.json" ]] && \
   [[ -L "$CLAUDE_DIR/statusline-command.sh" ]]; then
    pfb info "Symlinked files:"
    ls -lh "$CLAUDE_DIR"/{CLAUDE.md,settings.json,statusline-command.sh} 2>/dev/null || true
fi
