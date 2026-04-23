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

# Source pfb if available for better output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090,SC1091
for _pfb in \
    "$(brew --prefix 2>/dev/null)/lib/pfb/pfb.sh" \
    /usr/local/lib/pfb/pfb.sh \
    /usr/lib/pfb/pfb.sh \
    ~/.local/lib/pfb/pfb.sh; do
    [[ -f "$_pfb" ]] && { source "$_pfb"; break; }
done
unset _pfb
type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

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