#!/usr/bin/env bash
# @file update.sh
# @description Update all git repositories in the current (or specified) directory
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 2.0.0
# @usage update.sh [directory]
# @dependencies pfb (pretty feedback for bash)
# @exit 0 Always exits successfully; individual repo failures are reported

[[ -n ${DEBUG:-} ]] && {
    export PS4='+($(basename "${BASH_SOURCE[0]}"):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}

set -uo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../bootstrap/pfb/pfb.sh
source "${SCRIPT_DIR}/../bootstrap/pfb/pfb.sh" 2>/dev/null || {
    pfb() {
        local cmd="${1:-}"; shift || true
        case "$cmd" in
            heading)    printf '\n%s\n' "$1" ;;
            subheading) printf '  %s\n' "$1" ;;
            success)    printf '  ✓ %s\n' "$1" ;;
            warn)       printf '  ! %s\n' "$1" ;;
            err)        printf '  ✗ %s\n' "$1" ;;
            info)       printf '  → %s\n' "$1" ;;
        esac
    }
}

SCAN_DIR="${1:-$PWD}"
count_updated=0
count_current=0
count_skipped=0
count_failed=0

pfb heading "Updating git repositories in ${SCAN_DIR}" "🔄"

for dir in "${SCAN_DIR}"/*/; do
    [[ -d "${dir}.git" ]] || continue
    repo="${dir%/}"
    repo="${repo##*/}"

    pfb heading "$repo" "📦"

    pushd "$dir" > /dev/null

    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        pfb warn "Uncommitted local changes — skipping"
        count_skipped=$(( count_skipped + 1 ))
        popd > /dev/null
        continue
    fi

    if ! git ls-remote --exit-code origin > /dev/null 2>&1; then
        pfb warn "Remote not reachable"
        count_skipped=$(( count_skipped + 1 ))
        popd > /dev/null
        continue
    fi

    output=$(git pull --ff-only 2>&1) && pull_ok=true || pull_ok=false

    if [[ "$pull_ok" == "true" ]]; then
        if [[ "$output" == *"Already up to date"* ]]; then
            pfb info "Already up to date"
            count_current=$(( count_current + 1 ))
        else
            pfb success "Updated"
            count_updated=$(( count_updated + 1 ))
        fi
    else
        pfb err "Pull failed"
        pfb subheading "$output"
        count_failed=$(( count_failed + 1 ))
    fi

    popd > /dev/null
done

pfb heading "Summary" "📊"
[[ $count_updated -gt 0 ]] && pfb success "$count_updated updated"
[[ $count_current -gt 0 ]] && pfb info    "$count_current already current"
[[ $count_skipped -gt 0 ]] && pfb warn    "$count_skipped skipped"
[[ $count_failed  -gt 0 ]] && pfb err     "$count_failed failed"

exit 0
