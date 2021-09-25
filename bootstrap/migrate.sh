#!/usr/bin/env bash
# @file migrate.sh
# migrate.sh <username> <FQDN_or_IP>
# Script to migrate from old laptop to new
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

oIFS=$IFS
IFS=$(echo -en "\n\b")
USER="${1-null}"
IP="${2-null}"

transfer() {
	local dir="$1"
	[ "$2" == 'force' ] && rm -fR "$dir"
	ssh "$USER"@"$IP" 'find '"$dir"' -xdev -print | cpio -o' | cpio -vid
}

if [[ "$USER" == 'null' ]]; then
    read -p "✋ You forgot to give me the username for the remote system? " -r
    echo
    USER="$REPLY"
fi

if [[ "$IP" == 'null' ]]; then
    read -p "✋ You forgot to give me the FQDN or IP for the remote system? " -r
    echo
    IP="$REPLY"
fi

cd ~ || exit 1
transfer ./bin force
transfer ./Documents/Projects/Personal force
transfer ./Documents/Projects/VMware force
transfer ./Documents/Resources force
transfer ./Desktop
#transfer "./Documents/Virtual\ Machines.localized/win-7-32-ent-ws65"
transfer ./Pictures/headshots 

IFS=$oIFS
