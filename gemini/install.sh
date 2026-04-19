#!/usr/bin/env bash
#
# install.sh - Install Gemini CLI configuration
#
# Symlinks CLAUDE.md from the carrybag-lite claude/ directory to ~/.gemini/GEMINI.md,
# making the shared development principles available to Google Gemini CLI.
# Part of the Carrybag-lite environment setup.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-04-19
# License: MIT
#
# Usage: ./gemini/install.sh
#   Creates symlink from ~/.gemini/GEMINI.md to carrybag-lite/claude/CLAUDE.md
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
GEMINI_DIR="$HOME/.gemini"
SOURCE="$REPO_DIR/claude/CLAUDE.md"
DEST="$GEMINI_DIR/GEMINI.md"

# Source pfb if available for better output
if [[ -f "$HOME/.pfb.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.pfb.sh"
elif type pfb >/dev/null 2>&1; then
    :
else
    pfb() { echo "$2"; }
fi

pfb heading "Installing Gemini CLI configuration" "🤖"
echo

if [[ ! -f "$SOURCE" ]]; then
    pfb error "Source not found: $SOURCE"
    exit 1
fi

mkdir -p "$GEMINI_DIR"

if [[ -f "$DEST" && ! -L "$DEST" ]]; then
    backup="${DEST}.backup.$(date +"%Y%m%d%H%M%S")"
    pfb info "  Backing up existing GEMINI.md to $(basename "$backup")"
    mv "$DEST" "$backup"
fi

ln -sf "$SOURCE" "$DEST"
pfb success "  Linked GEMINI.md"

echo
pfb success "Gemini CLI configuration installed!"
pfb info "  Config location: $GEMINI_DIR"
pfb info "  Source location: $SOURCE"
echo

if [[ -L "$DEST" ]]; then
    pfb info "Symlinked file:"
    ls -lh "$DEST"
fi
