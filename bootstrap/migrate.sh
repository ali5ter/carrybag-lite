#!/usr/bin/env bash
# @file migrate.sh
# migrate.sh <username> <FQDN_or_IP>
# Script to migrate from old laptop to new
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

USER="${1-null}"
IP="${2-null}"

transfer_using_cpio() {
    # cpio method
	local dir="$1"
	if [ "$2" == 'force' ]; then rm -fR "$dir"; fi
    local oIFS=$IFS
    IFS=$(echo -en "\n\b")
	ssh "$USER"@"$IP" 'find '"$dir"' -xdev -print | cpio -o' | cpio -vid
    IFS=$oIFS
}

transfer_using_rsync() {
    # rsync method
    local dir="$1"
    local force="${2-existing}"
    local oDir="$PWD"
    cd ~ || exit
    if [ -e "$dir" ]; then mkdir "$dir"
    rsync -ax --"$force" -e ssh "$USER"@"$IP":"$dir" .
    cd "$oDir" || exit
}

promptForNull() {
    local value="$1"; shift
    local msg="$@"
    if [[ "$value" == 'null' ]]; then
        read -p "✋ $msg " -r
        echo
        value="$REPLY"
    fi 
    echo "$value"
}

promptMigration() {
    local path="$1"
    local force="${2-}"
    read -p "✋ Do you want to migrate $path? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then transfer_using_cpio "$path" "$force"; fi
}

USER=$(promptForNull "$USER" "You forgot to give me the username for the remote system?")
IP=$(promptForNull "$IP" "You forgot to give me the FQDN or IP for the remote system?")

cd ~ || exit
promptMigration ./bin force
promptMigration ./Documents/Projects/Personal force
promptMigration ./Documents/Projects/VMware force
promptMigration ./Documents/Resources force
promptMigration ./Pictures/headshots force
