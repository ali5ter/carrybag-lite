#!/usr/bin/env bash
#
# guard-secrets.sh - PreToolUse hook: redact token-shaped secrets from Bash commands
#
# claude/CLAUDE.md forbids committing secrets, but a command can leak one into the transcript
# or shell history before it ever reaches version control (e.g. a stray curl with a live API
# key). Rather than blocking the whole command, this hook rewrites it in place via updatedInput
# and lets the work continue with the secret replaced by a placeholder.
#
# updatedInput replaces the *whole* tool_input object, so every field is echoed back — only
# .command is changed.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-08-06
# License: MIT
#
# Usage: Registered as a PreToolUse hook on Bash in claude/settings.json.
#   Not intended to be run standalone, but can be exercised with:
#     echo '{"tool_input":{"command":"curl -H \"Auth: sk_live_abc\" x"}}' | ./guard-secrets.sh
#
# Dependencies: bash 4.0+, jq
#
# Exit codes:
#   0 - Always; the redaction, if any, is communicated via stdout JSON, not the exit code

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
command_str="$(jq -r '.tool_input.command // empty' <<<"$input")"
[[ -n "$command_str" ]] || exit 0

# Token-shaped literal patterns, each paired with a placeholder that keeps the command runnable
# where the literal is only ever passed through, not parsed for structure.
patterns=(
    'sk-ant-[A-Za-z0-9_-]{20,}|<REDACTED_ANTHROPIC_KEY>'
    'sk_live_[A-Za-z0-9]{10,}|<REDACTED_STRIPE_KEY>'
    'ghp_[A-Za-z0-9]{30,}|<REDACTED_GITHUB_TOKEN>'
    'github_pat_[A-Za-z0-9_]{30,}|<REDACTED_GITHUB_TOKEN>'
    'AKIA[0-9A-Z]{16}|<REDACTED_AWS_KEY>'
    'xox[baprs]-[A-Za-z0-9-]{10,}|<REDACTED_SLACK_TOKEN>'
)

redacted="$command_str"
found=0
for entry in "${patterns[@]}"; do
    pattern="${entry%%|*}"
    placeholder="${entry##*|}"
    if grep -qE "$pattern" <<<"$redacted"; then
        redacted="$(sed -E "s/${pattern}/${placeholder}/g" <<<"$redacted")"
        found=1
    fi
done

[[ "$found" -eq 1 ]] || exit 0

jq -n --argjson orig "$(jq '.tool_input' <<<"$input")" --arg cmd "$redacted" \
    '{
        systemMessage: "guard-secrets: redacted a token-shaped literal from this Bash command before it ran.",
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            permissionDecisionReason: "Secret redacted; command still runs with a placeholder.",
            updatedInput: ($orig | .command = $cmd)
        }
    }'
