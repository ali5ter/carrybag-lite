#!/usr/bin/env bash
# @file update.sh
# @description Update all git repositories in the current (or specified) directory
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 2.4.0
# @usage update.sh [-q|--quiet] [-f|--fetch-only] [-s|--stash] [directory]
# @dependencies pfb (pretty feedback for bash)
# @exit 0 Always exits successfully; individual repo failures are reported

[[ -n ${DEBUG:-} ]] && {
    export PS4='+($(basename "${BASH_SOURCE[0]}"):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}

set -uo pipefail
shopt -s nullglob

# ---------------------------------------------------------------------------
# Resolve the real script location by following the symlink chain, so pfb
# can be found relative to the actual file rather than the symlink's location.
# ---------------------------------------------------------------------------
_script="${BASH_SOURCE[0]}"
while [[ -L "$_script" ]]; do
    _script_dir="$(cd "$(dirname "$_script")" && pwd)"
    _script="$(readlink "$_script")"
    [[ "$_script" == /* ]] || _script="${_script_dir}/${_script}"
done
SCRIPT_DIR="$(cd "$(dirname "$_script")" && pwd)"
unset _script _script_dir

# shellcheck source=../bootstrap/pfb/pfb.sh
source "${SCRIPT_DIR}/../bootstrap/pfb/pfb.sh" 2>/dev/null || {
    pfb() {
        local cmd="${1:-}"; shift || true
        case "$cmd" in
            heading)    printf '\n%s\n' "${2:+$2 }$1" ;;
            subheading) printf '  %s\n' "$1" ;;
            success)    printf '  ✓ %s\n' "$1" ;;
            warn)       printf '  ! %s\n' "$1" ;;
            err)        printf '  ✗ %s\n' "$1" ;;
            info)       printf '  → %s\n' "$1" ;;
        esac
    }
}

# ---------------------------------------------------------------------------
# Timeout support — pure bash, no external dependencies required.
# Output (stdout+stderr) is captured via a temp file and forwarded to stdout.
# The watchdog redirects to /dev/null to avoid holding the $() pipe open,
# which would cause command substitution to block for the full timeout duration.
# Override the default with GIT_PULL_TIMEOUT=N before running the script.
# ---------------------------------------------------------------------------
GIT_PULL_TIMEOUT="${GIT_PULL_TIMEOUT:-60}"

# @description Run a git command with a timeout using bash job control
# @param $@ git subcommand and arguments
# @return Command exit code, or 124 if timed out
git_with_timeout() {
    local tmpout exit_code cmd_pid watchdog_pid
    tmpout="$(mktemp)"

    GIT_TERMINAL_PROMPT=0 git "$@" > "$tmpout" 2>&1 &
    cmd_pid=$!

    ( sleep "$GIT_PULL_TIMEOUT" && kill "$cmd_pid" 2>/dev/null ) > /dev/null 2>&1 &
    watchdog_pid=$!

    wait "$cmd_pid" 2>/dev/null
    exit_code=$?

    { kill "$watchdog_pid" 2>/dev/null; wait "$watchdog_pid" 2>/dev/null; } 2>/dev/null

    cat "$tmpout"
    rm -f "$tmpout"

    [[ $exit_code -gt 128 ]] && return 124
    return $exit_code
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

QUIET=false
FETCH_ONLY=false
STASH=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -q|--quiet)      QUIET=true; shift ;;
        -f|--fetch-only) FETCH_ONLY=true; shift ;;
        -s|--stash)      STASH=true; shift ;;
        -*) pfb err "Unknown option: $1"; exit 1 ;;
        *)  break ;;
    esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

SCAN_DIR="${1:-$PWD}"
count_updated=0
count_current=0
count_skipped=0
count_failed=0

$FETCH_ONLY \
    && pfb heading "Fetching git repositories in ${SCAN_DIR}" "🔍" \
    || pfb heading "Updating git repositories in ${SCAN_DIR}" "🔄"

for dir in "${SCAN_DIR}"/*/; do
    [[ -d "${dir}.git" ]] || continue
    repo="${dir%/}"
    repo="${repo##*/}"

    pushd "$dir" > /dev/null

    diff_exit=0
    git_with_timeout diff --quiet > /dev/null || diff_exit=$?
    if [[ $diff_exit -eq 0 ]]; then
        git_with_timeout diff --cached --quiet > /dev/null || diff_exit=$?
    fi

    stashed=false
    if [[ $diff_exit -eq 124 ]]; then
        pfb heading "$repo" "📦"
        pfb warn "git diff timed out — skipping"
        count_skipped=$(( count_skipped + 1 ))
        popd > /dev/null
        continue
    elif [[ $diff_exit -ne 0 ]]; then
        if $STASH; then
            pfb heading "$repo" "📦"
            stash_out=$(git stash push -m "update.sh auto-stash" 2>&1)
            if [[ $? -ne 0 ]]; then
                pfb warn "Stash failed — skipping"
                pfb subheading "$stash_out"
                count_skipped=$(( count_skipped + 1 ))
                popd > /dev/null
                continue
            fi
            pfb info "Local changes stashed"
            stashed=true
        else
            pfb heading "$repo" "📦"
            pfb warn "Uncommitted local changes — skipping"
            count_skipped=$(( count_skipped + 1 ))
            popd > /dev/null
            continue
        fi
    fi

    if ! git_with_timeout ls-remote --exit-code origin > /dev/null 2>&1; then
        pfb heading "$repo" "📦"
        pfb warn "Remote not reachable"
        count_skipped=$(( count_skipped + 1 ))
        popd > /dev/null
        continue
    fi

    if $FETCH_ONLY; then
        git_with_timeout fetch origin > /dev/null
        fetch_exit=$?
        behind=$(git rev-list --count HEAD..origin/HEAD 2>/dev/null || echo 0)
        if [[ $fetch_exit -eq 124 ]]; then
            pfb heading "$repo" "📦"
            pfb err "Fetch timed out after ${GIT_PULL_TIMEOUT}s"
            count_failed=$(( count_failed + 1 ))
        elif [[ $fetch_exit -ne 0 ]]; then
            pfb heading "$repo" "📦"
            pfb err "Fetch failed"
            count_failed=$(( count_failed + 1 ))
        elif [[ "$behind" -gt 0 ]]; then
            pfb heading "$repo" "📦"
            pfb warn "$behind commit(s) behind origin"
            count_skipped=$(( count_skipped + 1 ))
        else
            $QUIET || { pfb heading "$repo" "📦"; pfb info "Up to date"; }
            count_current=$(( count_current + 1 ))
        fi
    else
        output=$(git_with_timeout pull --ff-only)
        pull_exit=$?

        if [[ $pull_exit -eq 124 ]]; then
            pfb heading "$repo" "📦"
            pfb err "Pull timed out after ${GIT_PULL_TIMEOUT}s"
            count_failed=$(( count_failed + 1 ))
        elif [[ $pull_exit -ne 0 ]]; then
            pfb heading "$repo" "📦"
            pfb err "Pull failed"
            pfb subheading "$output"
            count_failed=$(( count_failed + 1 ))
        elif [[ "$output" == *"Already up to date"* ]]; then
            $QUIET || { pfb heading "$repo" "📦"; pfb info "Already up to date"; }
            count_current=$(( count_current + 1 ))
        else
            pfb heading "$repo" "📦"
            pfb success "Updated"
            count_updated=$(( count_updated + 1 ))
        fi
    fi

    if $stashed; then
        pop_out=$(git stash pop 2>&1)
        if [[ $? -ne 0 ]]; then
            pfb err "Stash pop failed — resolve manually (git stash list)"
            pfb subheading "$pop_out"
        else
            pfb info "Local changes restored"
        fi
    fi

    popd > /dev/null
done

pfb heading "Summary" "📊"
[[ $count_updated -gt 0 ]] && pfb success "$count_updated updated"
[[ $count_current -gt 0 ]] && pfb info    "$count_current already current"
[[ $count_skipped -gt 0 ]] && pfb warn    "$count_skipped skipped"
[[ $count_failed  -gt 0 ]] && pfb err     "$count_failed failed"

exit 0
