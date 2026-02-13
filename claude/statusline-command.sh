#!/usr/bin/env bash
#
# statusline-command.sh - Custom status line for Claude Code
#
# Displays hostname, directory, and git status in a Starship-inspired format.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 2.0.0
# Date: 2026-02-08

# Read JSON input from stdin
input=$(cat)

# Get hostname with alias mapping (matching Starship config)
hostname=$(hostname -s)
case "$hostname" in
    "Alisters-iMac") hostname="imac" ;;
esac

# Get current directory (use workspace info from JSON)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
if [ -z "$cwd" ]; then
    cwd="$PWD"
fi

# Replace home directory with ~
display_path="${cwd/#$HOME/\~}"

# Get git branch if in a git repository
git_info=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            git_info=" on git:$branch*"
        else
            git_info=" on git:$branch"
        fi
    fi
fi

# Fetch current model and usage data
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Output format: hostname in directory [on git:branch]
printf "%s in %s%s | %s | Usage: %d%%" "$hostname" "$display_path" "$git_info" "$model" "$used"