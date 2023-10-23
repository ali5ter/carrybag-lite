#!/usr/bin/env bash
# @file sync.sh
# Simple watch file changes and sync to remote server/drive
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && {
    export PS4='+($(basename ${BASH_SOURCE[0]}):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}
set -eou pipefail

if ! which brew &> /dev/null; then
    echo "Homebrew not installed"
    exit 1
fi

# Defaults assume sync of home directory to external Lacie drive
SOURCE_DIR="${1:-HOME}"
TARGET_DIR="${2:-/Volumes/Lacie/$(hostname)/}"

install_lsyncd() {
    # Install lsyncd
    # @ref https://lsyncd.github.io/lsyncd/
    if ! which lsynd &> /dev/null; then
        brew update && brew install lsyncd
    fi
}

sync_local() {
    [ -d "$TARGET_DIR" ] || mkdir -p "$TARGET_DIR"]
    lsyncd -rsync "$SOURCE_DIR" "$TARGET_DIR"
}

sync_remote() {
    lsyncd -rsyncssh /path/directory1 user@host /path/directory2
}

install_lsyncd
sync_local