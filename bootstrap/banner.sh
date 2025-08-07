#!/usr/bin/env bash
# @file banner.sh
# Simple banner script used for linux and RPi systems
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @note Move this into /etc/profile.d/banner.sh

HOSTNAME=$(hostname)
UPTIME=$(uptime -p)
ETH_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
WLAN_IP=$(ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

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
echo -e " 📡 \e[1;36mNetwork Interface:\e[0m $NET_IFACE"
echo -e " 🌐 \e[1;36mIP Address:       \e[0m $IP"
echo -e " ⏰ \e[1;36mUptime:           \e[0m $UPTIME"
echo "=========================================="
echo ""