#!/usr/bin/env bash
#
# banner.sh - Display a login banner with hostname and system info on Linux/RPi
#
# Prints a figlet hostname banner followed by OS version, network interface,
# IP address, and uptime on each login. Installed to /etc/profile.d/ by
# install_banner() in bootstrap/install.sh.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-04-20
# License: MIT
#
# Usage: Sourced automatically from /etc/profile.d/banner.sh on login.
#   To install: sudo cp bootstrap/banner.sh /etc/profile.d/banner.sh
#
# Dependencies: bash 4.0+, figlet, iproute2 (ip), lsb-release (lsb_release)
#
# Exit codes:
#   0 - Always (display errors are non-fatal)

HOSTNAME=$(hostname)
UPTIME=$(uptime -p)
ETH_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
WLAN_IP=$(ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
OS_VER=$(lsb_release -d | awk -F"\t" '{print $2}')

# Choose active IP
if [ -n "$ETH_IP" ]; then
    IP="$ETH_IP"
    NET_IFACE="Ethernet (eth0)"
elif [ -n "$WLAN_IP" ]; then
    IP="$WLAN_IP"
    NET_IFACE="Wi-Fi (wlan0)"
else
    IP="Not connected"
    NET_IFACE="None"
fi

echo ""
echo -e "\e[1;32m$(figlet -f slant "$HOSTNAME")\e[0m"
echo "=========================================="
echo -e " 🖥️  \e[1;36mOperating System:\e[0m $OS_VER"
echo -e " 📡 \e[1;36mNetwork Interface:\e[0m $NET_IFACE"
echo -e " 🌐 \e[1;36mIP Address:       \e[0m $IP"
echo -e " ⏰ \e[1;36mUptime:           \e[0m $UPTIME"
echo "=========================================="
echo ""