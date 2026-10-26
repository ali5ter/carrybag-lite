#!/usr/bin/env bash
#
# banner.sh - Display a login banner with hostname and system info on Linux/RPi
#
# Plays a short animated ASCII splash (ascii-magic-art) when the session is
# interactive, then prints a cfonts/figlet hostname banner followed by OS
# version, network interface, IP address, and uptime. Installed to
# /etc/profile.d/ by install_banner() in bootstrap/install.sh.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.1.0
# Date: 2026-10-25
# License: MIT
#
# Usage: Sourced automatically from /etc/profile.d/banner.sh on login.
#   To install: sudo cp bootstrap/banner.sh /etc/profile.d/banner.sh
#   To choose the splash, write ~/.config/banner_piece containing a piece name
#   (see `ascii-magic-art --list`), "random" (default) or "none", optionally
#   followed by a duration in seconds, e.g. "matrix-rain 2". Any key skips it.
#
# Dependencies: bash 4.0+, figlet, iproute2 (ip), lsb-release (lsb_release)
#   Optional: cfonts, ascii-magic-art (both via npm, see bootstrap/install.sh)
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

export PATH="$HOME/.npm-global/bin:$PATH"

# Play a short animated ASCII splash before the banner. Runs only when
# ascii-magic-art is installed and both stdin and stdout are a terminal, so
# scripted logins and file transfers never see it. The piece plays in the
# alternate screen and the terminal is restored when it stops.
# @return 0 always; a missing player or unknown piece is not an error at login
# @example play_splash
play_splash() {
    local -a pieces=(
        matrix-rain boot-sequence terminal-session git-log-graph process-tree
        plasma tunnel pixel-fire game-of-life spinning-torus rule-30 synthwave-grid
    )
    local config="$HOME/.config/banner_piece"
    local piece="random" seconds=3

    [[ -t 0 && -t 1 ]] || return 0
    type ascii-magic-art >/dev/null 2>&1 || return 0

    [[ -r "$config" ]] && read -r piece seconds _ < "$config"
    [[ -n "$piece" ]] || piece="random"
    [[ "$seconds" =~ ^[0-9]+(\.[0-9]+)?$ ]] || seconds=3
    case "$piece" in
        none|off) return 0 ;;
        random) piece="${pieces[RANDOM % ${#pieces[@]}]}" ;;
    esac

    ascii-magic-art "$piece" --seconds="$seconds" 2>/dev/null || true
}

play_splash
unset -f play_splash

if type cfonts >/dev/null 2>&1 ; then
    echo -e "\e[1;32m$(cfonts "$HOSTNAME" -f tiny -g red,blue -b "#101010")\e[0m"
else
    echo -e "\e[1;32m$(figlet -f slant "$HOSTNAME")\e[0m"
fi
echo -e " 🖥️  \e[1;36mOperating System:\e[0m $OS_VER"
echo -e " 📡 \e[1;36mNetwork Interface:\e[0m $NET_IFACE"
echo -e " 🌐 \e[1;36mIP Address:       \e[0m $IP"
echo -e " ⏰ \e[1;36mUptime:           \e[0m $UPTIME"
echo ""
