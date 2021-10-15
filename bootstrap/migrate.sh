#!/usr/bin/env bash
# @file migrate.sh
# migrate.sh <username> <FQDN_or_IP>
# Script to migrate from old laptop to new
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

USER="${1-null}"
IP="${2-null}"
CON_ALIVE=1800  # Seconds to keep SSH connection alive

transfer_using_cpio() {
	local dir="$1"
	if [ "$2" == 'force' ]; then rm -fR "$dir"; fi
    local oIFS=$IFS
    IFS=$(echo -en "\n\b")
    echo "🚛 Migrating $dir"
	ssh -o ServerAliveInterval="$CON_ALIVE" \
        "$USER"@"$IP" \
        'find '"$dir"' -xdev -print | cpio -o' | cpio -vid
    IFS=$oIFS
}

transfer_using_rsync() {
    local dir="$1"
    local force="${2-existing}"
    local oDir="$PWD"
    local err=''
    #[ -e "$dir" ] || mkdir -p "$dir"
    echo "🚛 Migrating $dir"
    while true ; do
        rsync -avW --timeout="$CON_ALIVE" --progress --"$force" \
            -e "ssh -o ServerAliveInterval=$CON_ALIVE" \
            "$USER"@"$IP":"$dir" $(dirname "$dir") && break
        echo "🎬 Retrying migration $dir..."
        sleep 10
    done
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
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        transfer_using_rsync "$path" "$force"
    fi
}

USER=$(promptForNull "$USER" "You forgot to give me the username for the remote system?")
IP=$(promptForNull "$IP" "You forgot to give me the FQDN or IP for the remote system?")

[ -f ~/.ssh/id_rsa ] || {
    ssh-keygen -q -b 2048 -t rsa -N "" -f ~/.ssh/id_rsa
}
echo "🔐 Copying ssh key file to remote system"
ssh-copy-id $USER@$IP

cd ~ || exit

promptMigration ./bin force
promptMigration ./Documents/Projects/Personal force
promptMigration ./Documents/Projects/VMware force
promptMigration ./Documents/Resources force
promptMigration ./Pictures/headshots force
promptMigration ./Library/Fonts force
promptMigration ./tmp force