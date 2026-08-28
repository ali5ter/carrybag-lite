#!/usr/bin/env bash
#
# statusline-command.sh - Custom status line for Claude Code
#
# Displays hostname, directory, git status, model, color-coded context-window
# usage, session cost, and Claude plan rate-limit usage in a Starship-inspired
# two-line format.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 2.2.0
# Date: 2026-08-28
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

# Fetch current model
model=$(echo "$input" | jq -r '.model.display_name')

# Get agent name if one is loaded
agent_info=""
agent=$(echo "$input" | jq -r '.agent.name // empty')
if [ -n "$agent" ]; then
    agent_info=" | agent:$agent"
fi

# ANSI colors for the context-window gauge
RESET=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'

# Context window used, color-coded (green <40%, yellow 40-69%, red 70%+) as a
# visual cue for when to run /compact. This is the model's context window,
# not the account rate limit reported below.
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
ctx_info=""
if [ -n "$ctx_pct" ]; then
    if [ "$ctx_pct" -ge 70 ]; then
        ctx_color="$RED"
    elif [ "$ctx_pct" -ge 40 ]; then
        ctx_color="$YELLOW"
    else
        ctx_color="$GREEN"
    fi
    ctx_info=" | Context: ${ctx_color}${ctx_pct}%${RESET}"
fi

# Session cost in USD - resets to $0 on /clear; not a daily total
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_info=""
if [ -n "$cost" ]; then
    cost_info=$(printf " | sess:\$%.2f" "$cost")
fi

# Claude plan rate-limit usage (Pro/Max subscribers only; absent otherwise).
# This is the account-level limit - a different metric from context usage above.
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
limit_info=""
if [ -n "$five_h" ] || [ -n "$seven_d" ]; then
    limit_info=" |"
    [ -n "$five_h" ] && limit_info="${limit_info} 5h:$(printf '%.0f' "$five_h")%"
    [ -n "$seven_d" ] && limit_info="${limit_info} 7d:$(printf '%.0f' "$seven_d")%"
fi

# Output format: hostname in directory [on git:branch]
#                model [| agent:name] [| Context: NN%] [| sess:$cost] [| 5h:NN% 7d:NN%]
printf "%s in %s%s\n%s%s%s%s%s" \
    "$hostname" "$display_path" "$git_info" "$model" "$agent_info" "$ctx_info" "$cost_info" "$limit_info"