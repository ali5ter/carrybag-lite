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

# Source pfb if available for better output
if [[ -f "$HOME/.pfb.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.pfb.sh"
elif type pfb >/dev/null 2>&1; then
    # pfb is already in PATH
    :
else
    # Define fallback functions if pfb is not available
    pfb() { echo "$2"; }
fi

# Create ~/.claude if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Backup existing files if they're not already symlinks
#
# @param $1 File path to check and backup
backup_if_exists() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
        local backup="${file}.backup-$(date +%Y%m%d%H%M%S)"
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
        pfb warning "  Skipping $file (not found in repo)"
    fi
done

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
