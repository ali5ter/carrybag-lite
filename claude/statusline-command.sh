#!/usr/bin/env bash
#
# statusline-command.sh - Custom status line for Claude Code
#
# Displays git branch and working directory status in the Claude Code status line.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-02-05

# Get git branch if in a git repository
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        status="*"
    else
        status=""
    fi
    echo "git:$branch$status"
else
    echo "$(basename "$PWD")"
fi
