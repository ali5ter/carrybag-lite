#!/usr/bin/env bash
#
# migrate.sh - Migrate configuration and files from an old machine to this one
#
# Transfers predefined home-directory paths from a remote machine via rsync
# (with infinite retry). Generates an SSH key if needed and copies it to the
# remote before transferring.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-04-20
# License: MIT
#
# Usage: ./bootstrap/migrate.sh <username> <FQDN_or_IP>
#   username     Remote SSH username
#   FQDN_or_IP   Remote hostname or IP address
#
# Dependencies: bash 4.0+, rsync, ssh, ssh-keygen, pfb
#
# Exit codes:
#   0 - Success
#   1 - rsync or SSH failure after retries

[[ -n $DEBUG ]] && set -x
set -eou pipefail

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

USER="${1-null}"
IP="${2-null}"
CON_ALIVE=1800  # Seconds to keep SSH connection alive

transfer_using_cpio() {
    # Transfer a directory from the remote machine using cpio over SSH.
    # @param $1  Remote path to migrate (e.g. ~/Documents)
    # @param $2  Optional: 'force' removes the local directory before transfer
    # @return 0 on success, non-zero on SSH or cpio failure
    # @example transfer_using_cpio ~/Documents/Projects force
	local dir="$1"
	if [ "$2" == 'force' ]; then rm -fR "$dir"; fi
    local oIFS=$IFS
    IFS=$(echo -en "\n\b")
    pfb heading "Migrating $dir" "🚛"
	ssh -o ServerAliveInterval="$CON_ALIVE" \
        "$USER"@"$IP" \
        'find '"$dir"' -xdev -print | cpio -o' | cpio -vid
    IFS=$oIFS
}

transfer_using_rsync() {
    # Transfer a directory from the remote machine using rsync over SSH with infinite retry.
    # @param $1  Remote path to migrate (e.g. ~/Documents)
    # @param $2  Optional rsync --existing variant: 'force' or 'existing' (default: existing)
    # @return 0 on success, non-zero on final rsync failure
    # @example transfer_using_rsync ~/bin force
    local dir="$1"
    local force="${2-existing}"
    local oDir="$PWD"
    #[ -e "$dir" ] || mkdir -p "$dir"
    pfb heading "Migrating $dir" "🚛"
    while true ; do
        rsync -avW --timeout="$CON_ALIVE" --progress --"$force" \
            -e "ssh -o ServerAliveInterval=$CON_ALIVE" \
            "$USER"@"$IP":"$dir" "$(dirname "$dir")" && break
        pfb warn "Retrying migration $dir..."
        sleep 10
    done
    cd "$oDir" || exit
}

promptForNull() {
    # Prompt the user for a value when the argument is the sentinel 'null'.
    # @param $1   Current value — passed through unchanged if not 'null'
    # @param $@   Prompt message to display when value is 'null'
    # @return 0; prints resolved value to stdout
    # @example local user; user="$(promptForNull "$USER" "Enter remote username:")"
    local value="$1"; shift
    # shellcheck disable=2124
    local msg="$@"
    if [[ "$value" == 'null' ]]; then
        read -r -p "$msg " value
    fi
    echo "$value"
}

promptMigration() {
    # Interactively ask whether to migrate a path; calls transfer_using_rsync if confirmed.
    # @param $1  Remote path to migrate
    # @param $2  Optional force flag passed to transfer_using_rsync (default: empty)
    # @return 0
    # @example promptMigration ~/Documents/Projects/Personal force
    local path="$1"
    local force="${2-}"
    read -r -p "Do you want to migrate $path? [y/N] " -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        transfer_using_rsync "$path" "$force"
    fi
}

USER=$(promptForNull "$USER" "You forgot to give me the username for the remote system?")
IP=$(promptForNull "$IP" "You forgot to give me the FQDN or IP for the remote system?")

[ -f ~/.ssh/id_rsa ] || {
    ssh-keygen -q -b 2048 -t rsa -N "" -f ~/.ssh/id_rsa
}
pfb heading "Copying ssh key file to remote system" "🔐"
ssh-copy-id "$USER@$IP"

cd ~ || exit

promptMigration ./bin force
promptMigration ./Documents/Projects/Personal force
promptMigration ./Documents/Resources force
promptMigration ./Pictures/headshots force
promptMigration ./Library/Fonts force
promptMigration ./tmp force