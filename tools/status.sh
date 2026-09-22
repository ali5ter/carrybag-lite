#!/usr/bin/env bash
# @file status.sh
# @description Report local git status (branch, dirty state, ahead/behind, stashes) for every
#              repository in a directory, so you can catch up on what's going on across projects
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 1.3.0
# @usage status.sh [-v|--verbose] [-f|--fetch] [--serial] [--pager] [-h|--help] [directory]
# @dependencies pfb (pretty feedback for bash)
# @exit 0 Always exits successfully; individual repo problems are reported, not raised

[[ -n ${DEBUG:-} ]] && {
    export PS4='+($(basename "${BASH_SOURCE[0]}"):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}

set -uo pipefail
set -m  # Enable job control so `jobs -r` works correctly in --parallel mode
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
# Timeout support — only used for the optional `--fetch` network call.
# ---------------------------------------------------------------------------
GIT_FETCH_TIMEOUT="${GIT_FETCH_TIMEOUT:-30}"

# @description Run a git command with a timeout using bash job control
# @param $@ git subcommand and arguments
# @return Command exit code, or 124 if timed out
git_with_timeout() {
    local tmpout exit_code cmd_pid watchdog_pid
    tmpout="$(mktemp)"

    GIT_TERMINAL_PROMPT=0 git "$@" > "$tmpout" 2>&1 &
    cmd_pid=$!

    ( sleep "$GIT_FETCH_TIMEOUT" && kill "$cmd_pid" 2>/dev/null ) > /dev/null 2>&1 &
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

Report local git status for every repository found in a directory — branch,
dirty files, unpushed/unpulled commits, and stashes — so you can catch up on
what's going on across projects after switching machines or context.

Options:
  -v, --verbose     Show every repo, including those already clean and up to date
  -f, --fetch       Fetch from origin first, so ahead/behind counts are current
  --serial          Scan repos one at a time instead of concurrently
  --pager           Page output through \$STATUS_PAGER (default: less -FRX)
  -h, --help        Show this help and exit

Arguments:
  directory   Directory to scan for git repositories (default: \$PWD)

Environment:
  GIT_FETCH_TIMEOUT   Seconds before a --fetch operation is killed (default: 30)
  STATUS_MAX_JOBS     Max parallel workers (default: 8)
  STATUS_PAGER        Pager command used with --pager (default: less -FRX)

Note: only repos that need attention are shown by default. Use --verbose to see everything.
Repos are scanned concurrently by default; use --serial for one-at-a-time output order.

Examples:
  $(basename "$0")
  $(basename "$0") --verbose
  $(basename "$0") --fetch
  $(basename "$0") --serial
  $(basename "$0") --verbose --pager
  $(basename "$0") ~/Documents/projects
EOF
    exit "${1:-0}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

QUIET=true
FETCH=false
PARALLEL=true
PAGER=false
STATUS_MAX_JOBS="${STATUS_MAX_JOBS:-8}"
STATUS_PAGER="${STATUS_PAGER:-less -FRX}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -q|--quiet)    QUIET=true; shift ;;    # retained for compatibility; quiet is now the default
        -v|--verbose)  QUIET=false; shift ;;
        -f|--fetch)    FETCH=true; shift ;;
        -p|--parallel) PARALLEL=true; shift ;;   # retained for compatibility; parallel is now the default
        --serial)      PARALLEL=false; shift ;;
        --pager)       PAGER=true; shift ;;
        -h|--help)     usage 0 ;;
        -*) pfb err "Unknown option: $1"; exit 1 ;;
        *)  break ;;
    esac
done

# ---------------------------------------------------------------------------
# Per-repo worker — called in a subshell when running in parallel.
# Writes a result record to a temp file as key<US>value lines (US = 0x1F),
# so values (commit subjects etc.) can safely contain anything but a newline.
# ---------------------------------------------------------------------------

# @description Inspect a single git repository and write its status to a file
# @param $1 Path to the repository directory
# @param $2 Path to the output file for the result record
# @side_effects Writes result record to $2; runs `git fetch` if --fetch is set
process_repo() {
    local dir="$1"
    local outfile="$2"
    local US=$'\x1f'

    pushd "$dir" > /dev/null || return

    if $FETCH; then
        git_with_timeout fetch origin > /dev/null
    fi

    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ "$branch" == "HEAD" ]]; then
        branch="detached@$(git rev-parse --short HEAD 2>/dev/null)"
    fi

    local default_branch=""
    default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    default_branch="${default_branch#origin/}"

    local ahead=0 behind=0 has_upstream=no
    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' > /dev/null 2>&1; then
        has_upstream=yes
        local counts
        counts=$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
        behind="${counts%%[[:space:]]*}"
        ahead="${counts##*[[:space:]]}"
    fi

    local staged=0 unstaged=0 untracked=0
    local RS=$'\x1e'
    local dirty_files=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local x="${line:0:1}" y="${line:1:1}" name="${line:3}"
        if [[ "$x" == '?' ]]; then
            untracked=$(( untracked + 1 ))
        else
            [[ "$x" != ' ' ]] && staged=$(( staged + 1 ))
            [[ "$y" != ' ' ]] && unstaged=$(( unstaged + 1 ))
        fi
        dirty_files="${dirty_files:+$dirty_files$RS}$name"
    done < <(git status --porcelain=v1 2>/dev/null)

    local stash_count
    stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

    local last_commit
    last_commit=$(git log -1 --format='%ar — %s' 2>/dev/null)
    [[ -z "$last_commit" ]] && last_commit="no commits yet"

    {
        printf 'branch%s%s\n' "$US" "$branch"
        printf 'default_branch%s%s\n' "$US" "$default_branch"
        printf 'has_upstream%s%s\n' "$US" "$has_upstream"
        printf 'ahead%s%s\n' "$US" "$ahead"
        printf 'behind%s%s\n' "$US" "$behind"
        printf 'staged%s%s\n' "$US" "$staged"
        printf 'unstaged%s%s\n' "$US" "$unstaged"
        printf 'untracked%s%s\n' "$US" "$untracked"
        printf 'dirty_files%s%s\n' "$US" "$dirty_files"
        printf 'stash_count%s%s\n' "$US" "$stash_count"
        printf 'last_commit%s%s\n' "$US" "$last_commit"
    } > "$outfile"

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
    local US=$'\x1f' RS=$'\x1e'

    local branch="" default_branch="" has_upstream="" ahead=0 behind=0
    local staged=0 unstaged=0 untracked=0 dirty_files="" stash_count=0 last_commit=""

    while IFS="$US" read -r key val; do
        case "$key" in
            branch)         branch="$val" ;;
            default_branch) default_branch="$val" ;;
            has_upstream)   has_upstream="$val" ;;
            ahead)          ahead="$val" ;;
            behind)         behind="$val" ;;
            staged)         staged="$val" ;;
            unstaged)       unstaged="$val" ;;
            untracked)      untracked="$val" ;;
            dirty_files)    dirty_files="$val" ;;
            stash_count)    stash_count="$val" ;;
            last_commit)    last_commit="$val" ;;
        esac
    done < "$outfile"
    rm -f "$outfile"

    local dirty=$(( staged > 0 || unstaged > 0 || untracked > 0 ? 1 : 0 ))
    local needs_attention=0
    [[ $dirty -eq 1 ]] && needs_attention=1
    [[ "$ahead" -gt 0 || "$behind" -gt 0 ]] && needs_attention=1
    [[ "$stash_count" -gt 0 ]] && needs_attention=1
    [[ -n "$default_branch" && "$branch" != "$default_branch" ]] && needs_attention=1

    if [[ $needs_attention -eq 0 ]]; then
        count_clean=$(( count_clean + 1 ))
        $QUIET && return
        pfb heading "$repo" "📦"
        pfb success "Clean, up to date on $branch"
        return
    fi

    count_attention=$(( count_attention + 1 ))
    pfb heading "$repo" "📦"

    if [[ -n "$default_branch" && "$branch" != "$default_branch" ]]; then
        pfb warn "On branch $branch (default is $default_branch)"
    else
        pfb subheading "Branch: $branch"
    fi

    if [[ "$has_upstream" == "yes" ]]; then
        [[ "$ahead" -gt 0 && "$behind" -gt 0 ]] && pfb warn "$ahead ahead, $behind behind origin"
        [[ "$ahead" -gt 0 && "$behind" -eq 0 ]] && pfb warn "$ahead commit(s) unpushed"
        [[ "$ahead" -eq 0 && "$behind" -gt 0 ]] && pfb warn "$behind commit(s) behind origin"
    elif [[ -z "$default_branch" ]]; then
        pfb subheading "No upstream tracking branch"
    fi

    if [[ $dirty -eq 1 ]]; then
        local parts=()
        [[ "$staged" -gt 0 ]] && parts+=( "$staged staged" )
        [[ "$unstaged" -gt 0 ]] && parts+=( "$unstaged unstaged" )
        [[ "$untracked" -gt 0 ]] && parts+=( "$untracked untracked" )
        local joined="" part
        for part in "${parts[@]}"; do
            joined="${joined:+$joined, }$part"
        done
        pfb warn "$joined"

        # For a handful of dirty files, name them — more actionable than a bare count
        local -a files=()
        IFS="$RS" read -r -d '' -a files < <(printf '%s\0' "$dirty_files")
        if [[ ${#files[@]} -gt 0 && ${#files[@]} -le 3 ]]; then
            local f
            for f in "${files[@]}"; do
                pfb subheading "  $f"
            done
        fi
    fi

    [[ "$stash_count" -gt 0 ]] && pfb warn "$stash_count stash(es)"

    pfb subheading "Last commit: $last_commit"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# @description Scan every repo and print its status, plus a summary
# @side_effects Reads SCAN_DIR/FETCH/PARALLEL and friends from the enclosing scope
run_status() {
SCAN_DIR="${1:-$PWD}"
count_clean=0
count_attention=0

pfb heading "Checking git status in ${SCAN_DIR}" "🔍"

if $PARALLEL; then
    # ------------------------------------------------------------------
    # Parallel mode: launch a background worker per repo, cap concurrency
    # at STATUS_MAX_JOBS, collect results in original directory order.
    # ------------------------------------------------------------------

    declare -a repo_dirs=()
    for dir in "${SCAN_DIR}"/*/; do
        [[ -d "${dir}.git" ]] || continue
        repo_dirs+=( "$dir" )
    done
    total_repos=${#repo_dirs[@]}

    pfb info "Running up to ${STATUS_MAX_JOBS} jobs in parallel across ${total_repos} repositories"

    declare -a repo_order=()
    declare -A job_files=()
    completed=0

    for dir in "${repo_dirs[@]}"; do
        repo="${dir%/}"
        repo="${repo##*/}"

        local_outfile="$(mktemp)"
        repo_order+=( "$repo" )
        job_files["$repo"]="$local_outfile"

        while [[ $(jobs -r | wc -l) -ge $STATUS_MAX_JOBS ]]; do
            wait -n 2>/dev/null || true
            completed=$(( completed + 1 ))
            pfb progress "$completed" "$total_repos" "Repositories checked"
        done

        process_repo "$dir" "$local_outfile" &
    done

    while [[ $(jobs -r | wc -l) -gt 0 ]]; do
        wait -n 2>/dev/null || true
        completed=$(( completed + 1 ))
        pfb progress "$completed" "$total_repos" "Repositories checked"
    done
    if type cursor_up &>/dev/null; then
        cursor_up >&2
        erase_line >&2
    fi
    pfb success "All ${total_repos} repositories checked"

    for repo in "${repo_order[@]}"; do
        display_result "$repo" "${job_files[$repo]}"
    done
else
    # ------------------------------------------------------------------
    # Sequential mode
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
pfb success "$count_clean clean and up to date"
[[ $count_attention -gt 0 ]] && pfb warn "$count_attention need attention"
}

if $PAGER; then
    # pfb detects the pipe to the pager as a non-TTY and drops color by default;
    # force it back on so the paged output still highlights warnings/failures.
    PFB_FORCE_COLOR=1 run_status "$@" | $STATUS_PAGER
else
    run_status "$@"
fi

exit 0
