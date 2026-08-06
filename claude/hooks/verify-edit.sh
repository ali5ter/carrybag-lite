#!/usr/bin/env bash
#
# verify-edit.sh - PostToolUse hook: lint/verify a file right after Claude edits it
#
# Reads the PostToolUse JSON payload on stdin, dispatches on the edited file's type, and runs
# the same "Verification before commit" check documented in the matching language skill
# (bash-standards, python-standards, go-standards) or in claude/CLAUDE.md (Markdown). Turns a
# rule Claude usually follows into one it cannot skip. Findings go to stderr and the hook exits
# 2 so Claude Code feeds them back as required fixes.
#
# This hook is user-level (~/.claude/settings.json) and therefore runs on every edit in every
# project, not just carrybag-lite. Markdown and Python checks only run when the target repo
# opts in via its own config file, so cloned third-party repos stay quiet. Shell and Go checks
# need no repo config and run everywhere.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-08-06
# License: MIT
#
# Usage: Registered as a PostToolUse hook on Edit|Write in claude/settings.json.
#   Not intended to be run standalone, but can be exercised with:
#     echo '{"tool_input":{"file_path":"/path/to/file.sh"}}' | ./verify-edit.sh
#
# Dependencies: bash 4.0+, jq
#   Optional per file type: shellcheck, markdownlint, ruff, gofmt
#
# Exit codes:
#   0 - Nothing to check, tool unavailable, gate unmet, or all checks passed
#   2 - Findings, printed to stderr, that Claude must address

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ -n "$file" && -f "$file" ]] || exit 0

findings=""

# Append a labelled finding block to the findings accumulator.
# @param $1  Label describing which check produced the output
# @param $2  Captured check output
# @return 0
# @side_effects Appends to the script-global findings variable
add_finding() {
    local label="$1" output="$2"
    findings+=$'\n'"--- ${label} ---"$'\n'"${output}"$'\n'
}

# Determine whether a file is a shell script by extension or shebang.
# @param $1  Path to the file to inspect
# @return 0 if the file is a shell script, 1 otherwise
is_shell_script() {
    local path="$1"
    case "$path" in
        *.sh | *.bash) return 0 ;;
    esac
    head -n1 "$path" 2>/dev/null | grep -qE '^#!.*/(env +)?(bash|sh)$'
}

# Find the git repository root containing a file, if any.
# @param $1  Path to a file inside the repo
# @return 0, prints the repo root path or nothing on stdout
repo_root_of() {
    git -C "$(dirname "$1")" rev-parse --show-toplevel 2>/dev/null || true
}

if is_shell_script "$file"; then
    if ! syntax_out="$(bash -n "$file" 2>&1)"; then
        add_finding "bash -n $file" "$syntax_out"
    elif command -v shellcheck >/dev/null 2>&1; then
        if ! lint_out="$(shellcheck "$file" 2>&1)"; then
            add_finding "shellcheck $file" "$lint_out"
        fi
    fi
elif [[ "$file" == *.md ]]; then
    root="$(repo_root_of "$file")"
    if [[ -n "$root" && -f "$root/.markdownlint.json" ]] && command -v markdownlint >/dev/null 2>&1; then
        if ! lint_out="$(markdownlint --config "$root/.markdownlint.json" "$file" 2>&1)"; then
            add_finding "markdownlint $file" "$lint_out"
        fi
    fi
elif [[ "$file" == *.py ]]; then
    root="$(repo_root_of "$file")"
    if [[ -n "$root" ]] && { [[ -f "$root/pyproject.toml" ]] || [[ -f "$root/ruff.toml" ]]; } \
        && command -v ruff >/dev/null 2>&1; then
        if ! fmt_out="$(ruff format --check "$file" 2>&1)"; then
            add_finding "ruff format --check $file" "$fmt_out"
        fi
        if ! lint_out="$(ruff check "$file" 2>&1)"; then
            add_finding "ruff check $file" "$lint_out"
        fi
    fi
elif [[ "$file" == *.go ]] && command -v gofmt >/dev/null 2>&1; then
    if fmt_out="$(gofmt -l "$file" 2>&1)" && [[ -n "$fmt_out" ]]; then
        add_finding "gofmt -l $file" "$fmt_out (not gofmt-formatted)"
    fi
fi

if [[ -n "$findings" ]]; then
    echo "verify-edit: fix the following before continuing:" >&2
    echo "$findings" >&2
    exit 2
fi

exit 0
