#!/usr/bin/env bash
# @file migrate.sh
# migrate.sh <username> <FQDN_or_IP>
# Script to migrate from old laptop to new
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

oIFS=$IFS
IFS=$(echo -en "\n\b")

transfer() {
	local dir="$1"
	[ "$2" == 'force' ] && rm -fR "$dir"
	ssh "$USER"@"$IP" 'find '"$dir"' -xdev -print | cpio -o' | cpio -vid
}

# Remote system
USER="$1"
IP="$2"

cd ~
transfer ./bin force
transfer ./Documents/Projects/Personal force
transfer ./Documents/Projects/VMware force
transfer ./Documents/Resources force
#transfer ./Desktop
#transfer "./Documents/Virtual\ Machines.localized/win-7-32-ent-ws65"

IFS=$oIFS
