#!/usr/bin/env bash
# @file migrate.sh
# migrate.sh <username> <FQDN_or_IP>
# Script to migrate from old laptop to new
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

# Source pfb if available for better output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/pfb/pfb.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/pfb/pfb.sh"
elif [[ -f "$HOME/.pfb.sh" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.pfb.sh"
elif ! type pfb >/dev/null 2>&1; then
    pfb() { echo "$2"; }
fi

USER="${1-null}"
IP="${2-null}"
CON_ALIVE=1800  # Seconds to keep SSH connection alive

transfer_using_cpio() {
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
    local dir="$1"
    local force="${2-existing}"
    local oDir="$PWD"
    #[ -e "$dir" ] || mkdir -p "$dir"
    pfb heading "Migrating $dir" "🚛"
    while true ; do
        rsync -avW --timeout="$CON_ALIVE" --progress --"$force" \
            -e "ssh -o ServerAliveInterval=$CON_ALIVE" \
            "$USER"@"$IP":"$dir" "$(dirname "$dir")" && break
        pfb warning "Retrying migration $dir..."
        sleep 10
    done
    cd "$oDir" || exit
}

promptForNull() {
    local value="$1"; shift
    # shellcheck disable=2124
    local msg="$@"
    if [[ "$value" == 'null' ]]; then
        read -r -p "$msg " value
    fi
    echo "$value"
}

promptMigration() {
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