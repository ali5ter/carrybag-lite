#!/usr/bin/env bash
#
# statusline-command.sh - Custom status line for Claude Code
#
# Displays hostname, directory, git status, model, context usage, session cost,
# and token usage in a Starship-inspired format.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 2.1.0
# Date: 2026-08-03
# License: MIT
#
# Usage: Piped from Claude Code statusline hook — receives JSON on stdin.
#   Outputs a two-line statusline string to stdout.
#
# Dependencies: bash 4.0+, jq, git
#
# Exit codes:
#   0 - Always (display errors are non-fatal)

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

# Get agent name if one is loaded
agent_info=""
agent=$(echo "$input" | jq -r '.agent.name // empty')
if [ -n "$agent" ]; then
    agent_info=" | agent:$agent"
fi

# Session cost in USD
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_info=""
if [ -n "$cost" ]; then
    cost_info=$(printf " | \$%.2f" "$cost")
fi

# Total tokens used this session, abbreviated (e.g. 15.5k, 1.2M)
tokens=$(echo "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))')
tokens_info=""
if [ -n "$tokens" ] && [ "$tokens" -gt 0 ] 2>/dev/null; then
    tokens_fmt=$(awk -v n="$tokens" 'BEGIN {
        if (n >= 1000000) printf "%.1fM", n / 1000000;
        else if (n >= 1000) printf "%.1fk", n / 1000;
        else printf "%d", n;
    }')
    tokens_info=" | ${tokens_fmt} tok"
fi

# Output format: hostname in directory [on git:branch]
#                model [| agent:name] | usage [| cost] [| tokens]
printf "%s in %s%s\n%s%s | Usage: %d%%%s%s" \
    "$hostname" "$display_path" "$git_info" "$model" "$agent_info" "$used" "$cost_info" "$tokens_info"