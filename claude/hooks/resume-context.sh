#!/usr/bin/env bash
#
# resume-context.sh - SessionStart hook: re-inject working state after a compaction
#
# A compaction drops a lot of conversational detail. Per the Claude Code course transcript on
# hooks, SessionStart with the compact matcher — not PostCompact — is the event whose output
# actually lands back in the conversation. This hook prints a short git snapshot (branch,
# uncommitted changes, recent commits) so Claude Code picks up where it left off instead of
# starting cold.
#
# SessionStart ignores blocking, so this never tries to fail the session — worst case it prints
# nothing.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-08-06
# License: MIT
#
# Usage: Registered as a SessionStart hook matched on "compact" in claude/settings.json.
#   Not intended to be run standalone, but can be exercised with:
#     echo '{"source":"compact","cwd":"'"$PWD"'"}' | ./resume-context.sh
#
# Dependencies: bash 4.0+, jq, git
#
# Exit codes:
#   0 - Always; nothing here should ever block a session start

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
source_kind="$(jq -r '.source // empty' <<<"$input")"
[[ "$source_kind" == "compact" ]] || exit 0

cwd="$(jq -r '.cwd // empty' <<<"$input")"
[[ -n "$cwd" ]] || cwd="$PWD"

git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"
status="$(git -C "$cwd" status --short 2>/dev/null || true)"
recent="$(git -C "$cwd" log -5 --oneline 2>/dev/null || true)"

{
    echo "Resumed after compaction. Working state in ${cwd}:"
    echo "- Branch: ${branch:-detached HEAD}"
    if [[ -n "$status" ]]; then
        echo "- Uncommitted changes:"
        echo "    ${status//$'\n'/$'\n    '}"
    else
        echo "- Working tree clean"
    fi
    if [[ -n "$recent" ]]; then
        echo "- Recent commits:"
        echo "    ${recent//$'\n'/$'\n    '}"
    fi
}
