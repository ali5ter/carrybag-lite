#!/usr/bin/env bash
#
# guard-gh-attribution.sh - PreToolUse hook: enforce the required attribution footer
#
# claude/CLAUDE.md requires every PR, issue, and comment to end with a "🤖 Generated with"
# footer. That rule is easy to forget because it is the last step of an action that already
# feels finished. This hook denies gh pr/issue create and comment/review commands whose body is
# missing the footer, and asks the user to decide when the body arrives via unreadable stdin
# (--body-file -).
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-08-06
# License: MIT
#
# Usage: Registered as a PreToolUse hook on Bash, narrowed with "if": "Bash(gh *)" in
#   claude/settings.json. Not intended to be run standalone, but can be exercised with:
#     echo '{"tool_input":{"command":"gh pr create --body \"...\""}}' | ./guard-gh-attribution.sh
#
# Dependencies: bash 4.0+, jq
#
# Exit codes:
#   0 - Always; the permission decision is communicated via stdout JSON, not the exit code

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
command_str="$(jq -r '.tool_input.command // empty' <<<"$input")"
[[ -n "$command_str" ]] || exit 0

# Only gh commands that publish a PR/issue body carry the attribution requirement.
echo "$command_str" | grep -qE 'gh +(pr|issue) +(create|comment|review)\b' || exit 0

FOOTER_PATTERN='Generated with'

# Emit a PreToolUse permission decision and exit.
# @param $1  permissionDecision value: allow, deny, or ask
# @param $2  Human-readable reason shown to Claude or the user
# @return never returns; exits 0 after printing JSON
decide() {
    local decision="$1" reason="$2"
    jq -n --arg d "$decision" --arg r "$reason" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
    exit 0
}

if echo "$command_str" | grep -qE -- '--body-file[= ]-(\s|$)'; then
    decide "ask" "Body is piped via --body-file - and can't be inspected here. Confirm it ends with the required 🤖 Generated with ... footer before allowing."
fi

deny_reason="Missing the required attribution footer. Every PR, issue, and comment must end with: 🤖 Generated with [SOURCE](URL) on behalf of [Alister](https://github.com/ali5ter) — see claude/CLAUDE.md."

# --body-file <path>: the body lives in a file, not in the command string itself.
if body_file="$(echo "$command_str" | grep -oE -- '--body-file[= ][^ ]+' | head -n1 | sed -E 's/--body-file[= ]//')" \
    && [[ -n "$body_file" ]]; then
    if [[ -f "$body_file" ]] && grep -qF "$FOOTER_PATTERN" "$body_file"; then
        exit 0
    fi
    decide "deny" "$deny_reason"
fi

# Inline --body: search the whole command string rather than extracting the quoted value, since
# the repo's own convention is a multi-line heredoc body, which a single-line regex can't span.
if grep -qF "$FOOTER_PATTERN" <<<"$command_str"; then
    exit 0
fi

decide "deny" "$deny_reason"
