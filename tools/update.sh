#!/usr/bin/env bash
# @file update.sh
# @description Update all git repositories in the current (or specified) directory
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 2.7.0
# @usage update.sh [-q|--quiet] [-f|--fetch-only] [-s|--stash] [-p|--parallel] [-h|--help] [directory]
# @dependencies pfb (pretty feedback for bash)
# @exit 0 Always exits successfully; individual repo failures are reported

[[ -n ${DEBUG:-} ]] && {
    export PS4='+($(basename "${BASH_SOURCE[0]}"):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}

set -uo pipefail
shopt -s nullglob

# Fall back to a minimal stub if pfb is not installed
type pfb >/dev/null 2>&1 || {
    pfb() {
        local cmd="${1:-}"; shift || true
        case "$cmd" in
            heading)    printf '\n%s\n' "${2:+$2 }$1" ;;
            subheading) printf '  %s\n' "$1" ;;
            success)    printf '  ✓ %s\n' "$1" ;;
            warn)       printf '  ! %s\n' "$1" ;;
            err)        printf '  ✗ %s\n' "$1" ;;
            info)       printf '  → %s\n' "$1" ;;
            progress)   printf '\r  [%s/%s] %s' "$1" "$2" "${3:-Processing...}" >&2
                        [[ "$1" -ge "$2" ]] && printf '\n' >&2 ;;
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
# Usage
# ---------------------------------------------------------------------------

# @description Print usage information and exit
# @param $1 Optional exit code (default 0)
usage() {
    cat <<EOF

Usage: $(basename "$0") [OPTIONS] [directory]

Pull the latest changes for every git repository found in a directory.

Options:
  -q, --quiet       Only show repos with changes or problems
  -f, --fetch-only  Fetch only — report how far behind, do not pull
  -s, --stash       Auto-stash local changes, pull, then restore
  -p, --parallel    Run all repos concurrently (up to UPDATE_MAX_JOBS)
  -h, --help        Show this help and exit

Arguments:
  directory   Directory to scan for git repositories (default: \$PWD)

Environment:
  GIT_PULL_TIMEOUT   Seconds before a git operation is killed (default: 60)
  UPDATE_MAX_JOBS    Max parallel workers when using --parallel (default: 8)

Examples:
  $(basename "$0")
  $(basename "$0") --quiet
  $(basename "$0") --fetch-only
  $(basename "$0") --stash
  $(basename "$0") --parallel
  $(basename "$0") ~/Documents/projects
  GIT_PULL_TIMEOUT=15 $(basename "$0")
EOF
    exit "${1:-0}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

QUIET=false
FETCH_ONLY=false
STASH=false
PARALLEL=false
UPDATE_MAX_JOBS="${UPDATE_MAX_JOBS:-8}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -q|--quiet)      QUIET=true; shift ;;
        -f|--fetch-only) FETCH_ONLY=true; shift ;;
        -s|--stash)      STASH=true; shift ;;
        -p|--parallel)   PARALLEL=true; shift ;;
        -h|--help)       usage 0 ;;
        -*) pfb err "Unknown option: $1"; exit 1 ;;
        *)  break ;;
    esac
done

# ---------------------------------------------------------------------------
# Per-repo worker — called in a subshell when running in parallel.
# Writes a result record to a temp file with this structure:
#   Line 1: STATUS (updated|current|skipped|failed)
#   Line 2: primary message
#   Line 3: stash outcome (stash-restored|stash-pop-failed), if --stash used
#   Line 4: stash detail message, if applicable
# ---------------------------------------------------------------------------

# @description Process a single git repository and write result to a file
# @param $1 Path to the repository directory
# @param $2 Path to the output file for the result record
# @side_effects Writes result record to $2; performs git fetch/pull
process_repo() {
    local dir="$1"
    local outfile="$2"

    pushd "$dir" > /dev/null || return

    local diff_exit=0
    git_with_timeout diff --quiet > /dev/null || diff_exit=$?
    if [[ $diff_exit -eq 0 ]]; then
        git_with_timeout diff --cached --quiet > /dev/null || diff_exit=$?
    fi

    local stashed=false
    if [[ $diff_exit -eq 124 ]]; then
        printf 'skipped\ngit diff timed out — skipping\n' > "$outfile"
        popd > /dev/null || return
        return
    elif [[ $diff_exit -ne 0 ]]; then
        if $STASH; then
            local stash_out
            stash_out=$(git stash push -m "update.sh auto-stash" 2>&1)
            # shellcheck disable=SC2181
            if [[ $? -ne 0 ]]; then
                printf 'skipped\nStash failed — skipping\n\n%s\n' "$stash_out" > "$outfile"
                popd > /dev/null || return
                return
            fi
            stashed=true
        else
            printf 'skipped\nUncommitted local changes — skipping\n' > "$outfile"
            popd > /dev/null || return
            return
        fi
    fi

    if ! git_with_timeout ls-remote --exit-code origin > /dev/null 2>&1; then
        printf 'skipped\nRemote not reachable\n' > "$outfile"
        popd > /dev/null || return
        return
    fi

    if $FETCH_ONLY; then
        git_with_timeout fetch origin > /dev/null
        local fetch_exit=$?
        local behind
        behind=$(git rev-list --count HEAD..origin/HEAD 2>/dev/null || echo 0)
        if [[ $fetch_exit -eq 124 ]]; then
            printf 'failed\nFetch timed out after %ss\n' "$GIT_PULL_TIMEOUT" > "$outfile"
        elif [[ $fetch_exit -ne 0 ]]; then
            printf 'failed\nFetch failed\n' > "$outfile"
        elif [[ "$behind" -gt 0 ]]; then
            printf 'skipped\n%s commit(s) behind origin\n' "$behind" > "$outfile"
        else
            printf 'current\nUp to date\n' > "$outfile"
        fi
    else
        local output
        output=$(git_with_timeout pull --ff-only)
        local pull_exit=$?

        if [[ $pull_exit -eq 124 ]]; then
            printf 'failed\nPull timed out after %ss\n' "$GIT_PULL_TIMEOUT" > "$outfile"
        elif [[ $pull_exit -ne 0 ]]; then
            printf 'failed\nPull failed\n%s\n' "$output" > "$outfile"
        elif [[ "$output" == *"Already up to date"* ]]; then
            printf 'current\nAlready up to date\n' > "$outfile"
        else
            printf 'updated\nUpdated\n' > "$outfile"
        fi
    fi

    if $stashed; then
        local pop_out
        pop_out=$(git stash pop 2>&1)
        # shellcheck disable=SC2181
        if [[ $? -ne 0 ]]; then
            printf 'stash-pop-failed\n%s\n' "$pop_out" >> "$outfile"
        else
            printf 'stash-restored\n' >> "$outfile"
        fi
    fi

    popd > /dev/null || true
}

# ---------------------------------------------------------------------------
# Display a single repo result from a result file
# @param $1 Repository name
# @param $2 Path to result file written by process_repo
# @side_effects Increments count_* variables; removes outfile
# ---------------------------------------------------------------------------
display_result() {
    local repo="$1"
    local outfile="$2"

    local status message stash_status stash_msg
    status=$(sed -n '1p' "$outfile")
    message=$(sed -n '2p' "$outfile")
    stash_status=$(sed -n '3p' "$outfile")
    stash_msg=$(sed -n '4p' "$outfile")
    rm -f "$outfile"

    case "$status" in
        updated)
            pfb heading "$repo" "📦"
            pfb success "$message"
            count_updated=$(( count_updated + 1 ))
            ;;
        current)
            $QUIET || { pfb heading "$repo" "📦"; pfb info "$message"; }
            count_current=$(( count_current + 1 ))
            ;;
        skipped)
            pfb heading "$repo" "📦"
            pfb warn "$message"
            [[ -n "${stash_msg:-}" ]] && pfb subheading "$stash_msg"
            count_skipped=$(( count_skipped + 1 ))
            ;;
        failed)
            pfb heading "$repo" "📦"
            pfb err "$message"
            count_failed=$(( count_failed + 1 ))
            ;;
    esac

    # Stash restore outcome (only present when --stash was used)
    if [[ "${stash_status:-}" == "stash-pop-failed" ]]; then
        pfb err "Stash pop failed — resolve manually (git stash list)"
        [[ -n "${stash_msg:-}" ]] && pfb subheading "$stash_msg"
    elif [[ "${stash_status:-}" == "stash-restored" ]]; then
        pfb info "Local changes restored"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

SCAN_DIR="${1:-$PWD}"
count_updated=0
count_current=0
count_skipped=0
count_failed=0

if $FETCH_ONLY; then
    pfb heading "Fetching git repositories in ${SCAN_DIR}" "🔍"
else
    pfb heading "Updating git repositories in ${SCAN_DIR}" "🔄"
fi

if $PARALLEL; then
    # ------------------------------------------------------------------
    # Parallel mode: launch a background worker per repo, cap concurrency
    # at UPDATE_MAX_JOBS, collect results in original directory order.
    # ------------------------------------------------------------------

    # Pre-scan so we know the total for the progress bar
    declare -a repo_dirs=()
    for dir in "${SCAN_DIR}"/*/; do
        [[ -d "${dir}.git" ]] || continue
        repo_dirs+=( "$dir" )
    done
    total_repos=${#repo_dirs[@]}

    pfb info "Running up to ${UPDATE_MAX_JOBS} jobs in parallel across ${total_repos} repositories"

    declare -a repo_order=()
    declare -A job_files=()
    completed=0

    for dir in "${repo_dirs[@]}"; do
        repo="${dir%/}"
        repo="${repo##*/}"

        local_outfile="$(mktemp)"
        repo_order+=( "$repo" )
        job_files["$repo"]="$local_outfile"

        # Throttle: wait for a slot when at the concurrency limit
        while [[ $(jobs -r | wc -l) -ge $UPDATE_MAX_JOBS ]]; do
            wait -n 2>/dev/null || true
            completed=$(( completed + 1 ))
            pfb progress "$completed" "$total_repos" "Repositories processed"
        done

        process_repo "$dir" "$local_outfile" &
    done

    # Drain remaining workers, updating progress as each completes
    while [[ $(jobs -r | wc -l) -gt 0 ]]; do
        wait -n 2>/dev/null || true
        completed=$(( completed + 1 ))
        pfb progress "$completed" "$total_repos" "Repositories processed"
    done
    # Replace the completed progress bar with a success message.
    # Real pfb: _progress at 100% already printed \n, so cursor_up returns to the bar
    # line and erase_line clears it before pfb success overwrites in place.
    # Fallback pfb: cursor_up is absent; the stub already emitted \n, so success
    # just appears on the next line.
    if type cursor_up &>/dev/null; then
        cursor_up >&2
        erase_line >&2
    fi
    pfb success "All ${total_repos} repositories processed"

    # Display results in original directory order
    for repo in "${repo_order[@]}"; do
        display_result "$repo" "${job_files[$repo]}"
    done
else
    # ------------------------------------------------------------------
    # Sequential mode (original behaviour)
    # ------------------------------------------------------------------
    for dir in "${SCAN_DIR}"/*/; do
        [[ -d "${dir}.git" ]] || continue
        repo="${dir%/}"
        repo="${repo##*/}"

        local_outfile="$(mktemp)"
        process_repo "$dir" "$local_outfile"
        display_result "$repo" "$local_outfile"
    done
fi

pfb heading "Summary" "📊"
[[ $count_updated -gt 0 ]] && pfb success "$count_updated updated"
[[ $count_current -gt 0 ]] && pfb info    "$count_current already current"
[[ $count_skipped -gt 0 ]] && pfb warn    "$count_skipped skipped"
[[ $count_failed  -gt 0 ]] && pfb err     "$count_failed failed"

exit 0
