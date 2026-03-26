#!/usr/bin/env bash
# @file sync.sh
# @description Sync a source directory to a local or remote target using rsync.
#              Auto-detects remote targets from user@host:/path format.
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 2.4.0
# @usage sync.sh [--dry-run] [--exclude pattern] [--no-default-excludes] [--max-retries N] [--bwlimit KBPS] [source [target]]
# @dependencies rsync, pfb
# @exit 0 Success
# @exit 1 Invalid arguments or sync failure

[[ -n ${DEBUG:-} ]] && {
    export PS4='+($(basename "${BASH_SOURCE[0]}"):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}

set -uo pipefail

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
# Argument parsing
# ---------------------------------------------------------------------------

DRY_RUN=false
USE_DEFAULT_EXCLUDES=true
EXTRA_EXCLUDES=()
MAX_RETRIES="${SYNC_MAX_RETRIES:-0}"  # 0 = unlimited retries for remote syncs
BWLIMIT="${SYNC_BWLIMIT:-0}"          # 0 = unlimited bandwidth (KB/s)

# Default patterns that are never worth syncing
DEFAULT_EXCLUDES=(
    '.DS_Store'
    '.Trash/'
    'node_modules/'
    '.cache/'
    '__pycache__/'
    '*.pyc'
    '.venv/'
    'dist/'
    'build/'
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)             DRY_RUN=true; shift ;;
        --no-default-excludes)    USE_DEFAULT_EXCLUDES=false; shift ;;
        --exclude)                EXTRA_EXCLUDES+=( "$2" ); shift 2 ;;
        --exclude=*)              EXTRA_EXCLUDES+=( "${1#--exclude=}" ); shift ;;
        --max-retries)            MAX_RETRIES="$2"; shift 2 ;;
        --max-retries=*)          MAX_RETRIES="${1#--max-retries=}"; shift ;;
        --bwlimit)                BWLIMIT="$2"; shift 2 ;;
        --bwlimit=*)              BWLIMIT="${1#--bwlimit=}"; shift ;;
        -*) pfb err "Unknown option: $1"; exit 1 ;;
        *)  break ;;
    esac
done

SOURCE_DIR="${1:-$HOME/}"
TARGET_DIR="${2:-/Volumes/Lacie/$HOSTNAME/}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# @description Returns true if path is a remote rsync target (contains ':')
# @param $1 Path to test
# @return 0 if remote, 1 if local
is_remote() { [[ "$1" == *:* ]]; }

# ---------------------------------------------------------------------------
# Sync modes
# ---------------------------------------------------------------------------

# @description Build the rsync --exclude flags from defaults and user extras
# @side_effects Populates the EXCLUDE_FLAGS array
build_exclude_flags() {
    EXCLUDE_FLAGS=()
    local pattern
    if $USE_DEFAULT_EXCLUDES; then
        for pattern in "${DEFAULT_EXCLUDES[@]}"; do
            EXCLUDE_FLAGS+=( --exclude="$pattern" )
        done
    fi
    for pattern in "${EXTRA_EXCLUDES[@]}"; do
        EXCLUDE_FLAGS+=( --exclude="$pattern" )
    done
}

# @description Sync to a local target (external drive, mounted volume)
# @side_effects Creates TARGET_DIR if it does not exist
sync_local() {
    # Flags: preserve group/symlinks/owner/permissions/times, recursive,
    #        skip files newer on receiver, delete extraneous destination files
    local flags=( -gloptru --delete --progress )
    $DRY_RUN && flags+=( --dry-run )
    [[ $BWLIMIT -gt 0 ]] && flags+=( --bwlimit="$BWLIMIT" )
    build_exclude_flags

    pfb heading "Local sync" "💾"
    pfb subheading "From: $SOURCE_DIR"
    pfb subheading "  To: $TARGET_DIR"
    $DRY_RUN && pfb warn "Dry run — no files will be transferred"

    [[ -d "$TARGET_DIR" ]] || mkdir -p "$TARGET_DIR"

    rsync "${flags[@]}" "${EXCLUDE_FLAGS[@]}" "$SOURCE_DIR" "$TARGET_DIR"
}

# @description Sync to or from a remote host over SSH, with optional retry
# @side_effects Transfers files over the network
sync_remote() {
    local con_alive=1800  # SSH keepalive interval in seconds
    local flags=( -az --partial --delete --progress --timeout="$con_alive"
                  -e "ssh -o ServerAliveInterval=$con_alive" )
    $DRY_RUN && flags+=( --dry-run )
    [[ $BWLIMIT -gt 0 ]] && flags+=( --bwlimit="$BWLIMIT" )
    build_exclude_flags

    pfb heading "Remote sync" "🌐"
    pfb subheading "From: $SOURCE_DIR"
    pfb subheading "  To: $TARGET_DIR"
    [[ $BWLIMIT -gt 0 ]] && pfb info "Bandwidth capped at ${BWLIMIT} KB/s"
    $DRY_RUN && pfb warn "Dry run — no files will be transferred"

    local attempt=0
    while true; do
        attempt=$(( attempt + 1 ))
        rsync "${flags[@]}" "${EXCLUDE_FLAGS[@]}" "$SOURCE_DIR" "$TARGET_DIR" && return 0
        [[ $MAX_RETRIES -gt 0 && $attempt -ge $MAX_RETRIES ]] && return 1
        pfb warn "Retrying (attempt $attempt)..."
        sleep 10
    done
}

# ---------------------------------------------------------------------------
# Validate and run
# ---------------------------------------------------------------------------

if ! is_remote "$SOURCE_DIR" && [[ ! -d "$SOURCE_DIR" ]]; then
    pfb err "Source directory not found: $SOURCE_DIR"
    exit 1
fi

if is_remote "$SOURCE_DIR" || is_remote "$TARGET_DIR"; then
    sync_remote
else
    sync_local
fi && pfb success "Sync complete" || {
    pfb err "Sync failed"
    exit 1
}
