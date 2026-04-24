#!/usr/bin/env bash
# @file test_rpi.sh
# Using Docker to simulate Raspberry Pi OS environment for testing.
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -euo pipefail

# Host-side repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Docker details
IMAGE="debian:stable"
PLATFORM="linux/arm64"
CONTAINER_NAME="carrybag-test"

# Path inside the container
CONTAINER_HOME="/root"
CONTAINER_SRC="$CONTAINER_HOME/src"
CONTAINER_REPO="$CONTAINER_SRC/carrybag-lite"

INSTALL_SCRIPT="$CONTAINER_REPO/bootstrap/install.sh"


pfb heading "Raspberry Pi OS Simulation Environment for bootstrap/install.sh testing" 🚀
pfb subheading "Using Docker image '$IMAGE' on platform '$PLATFORM'"
pfb subheading "for container named '$CONTAINER_NAME',"
pfb subheading "and mounting repo from '$CONTAINER_REPO'"
echo

# Remove any previous container so we start clean
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker run -it \
  --platform "$PLATFORM" \
  --name "$CONTAINER_NAME" \
  -v "$SCRIPT_DIR":$CONTAINER_REPO \
  $IMAGE \
  bash -c "
    apt-get update -y >/dev/null
    apt-get install -y bash curl git sudo iproute2 >/dev/null

    cd $CONTAINER_REPO

    curl -sL https://raw.githubusercontent.com/ali5ter/pfb/main/install.sh | bash

    echo
    pfb success 'Package index and dependency installation complete for test environment'
    echo

    pfb heading 'Ensuring directory structure exists…' 📁
    mkdir -p $CONTAINER_SRC
    echo

    pfb heading 'Simulating Raspberry Pi network interfaces…' 🌐
    ip link add wlan0 type dummy
    ip addr add 192.168.10.50/24 dev wlan0
    ip link set wlan0 up
    ip link add eth1 type dummy
    ip addr add 10.0.0.50/24 dev eth1
    ip link set eth1 up
    echo

    pfb heading 'Running install script…' 🚀
    pfb subheading 'This is the start of the install.sh output.'
    pfb subheading 'When the test is complete, the container will remain alive for inspection.'
    pfb subheading 'Instructions to connect will be provided at the end.'
    pfb subheading '-----------------------------------------------------------------------------'
    echo
    bash $INSTALL_SCRIPT

    echo
    pfb success 'Test complete!'
    pfb subheading 'You can now inspect the container environment.'
    pfb subheading 'To connect to the container, run:'
    pfb subheading \"  docker exec -it $CONTAINER_NAME bash\"
    pfb subheading 'To tear down the container, run:'
    pfb subheading \"  docker rm -f $CONTAINER_NAME\"
    tail -f /dev/null
  "