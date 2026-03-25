#!/usr/bin/env bash
# @file sync.sh
# @description Sync a source directory to a local or remote target using rsync.
#              Auto-detects remote targets from user@host:/path format.
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 2.0.0
# @usage sync.sh [--dry-run] [source [target]]
# @dependencies rsync, pfb
# @exit 0 Success
# @exit 1 Invalid arguments or sync failure

[[ -n ${DEBUG:-} ]] && {
    export PS4='+($(basename "${BASH_SOURCE[0]}"):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}

set -uo pipefail

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

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=true; shift ;;
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

# @description Sync to a local target (external drive, mounted volume)
# @side_effects Creates TARGET_DIR if it does not exist
sync_local() {
    # Flags: preserve group/symlinks/owner/permissions/times, recursive,
    #        skip files newer on receiver, delete extraneous destination files
    local flags=( -gloptru --delete --progress )
    $DRY_RUN && flags+=( --dry-run )

    pfb heading "Local sync" "💾"
    pfb subheading "From: $SOURCE_DIR"
    pfb subheading "  To: $TARGET_DIR"
    $DRY_RUN && pfb warn "Dry run — no files will be transferred"

    [[ -d "$TARGET_DIR" ]] || mkdir -p "$TARGET_DIR"

    rsync "${flags[@]}" "$SOURCE_DIR" "$TARGET_DIR"
}

# @description Sync to or from a remote host over SSH
# @side_effects Transfers files over the network
sync_remote() {
    local con_alive=1800  # SSH keepalive interval in seconds
    local flags=( -az --delete --progress --timeout="$con_alive"
                  -e "ssh -o ServerAliveInterval=$con_alive" )
    $DRY_RUN && flags+=( --dry-run )

    pfb heading "Remote sync" "🌐"
    pfb subheading "From: $SOURCE_DIR"
    pfb subheading "  To: $TARGET_DIR"
    $DRY_RUN && pfb warn "Dry run — no files will be transferred"

    rsync "${flags[@]}" "$SOURCE_DIR" "$TARGET_DIR"
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
