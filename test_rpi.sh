#!/usr/bin/env bash
# @file test_rpi.sh
# Using Docker to simulate Raspberry Pi OS environment for testing.
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="debian:stable"
PLATFORM="linux/arm64"

# Path INSIDE the container that simulates the real Pi environment
CONTAINER_HOME="/root"
CONTAINER_SRC="$CONTAINER_HOME/src"
CONTAINER_REPO="$CONTAINER_SRC/carrybag-lite"
INSTALL_SCRIPT="$CONTAINER_REPO/bootstrap/install.sh"

echo "==> Simulating Raspberry Pi environment"
echo "==> Image: $IMAGE ($PLATFORM)"
echo "==> Host repo: $SCRIPT_DIR"
echo "==> Inside container repo will live at: $CONTAINER_REPO"
echo

docker run --rm -it \
  --platform "$PLATFORM" \
  -v "$SCRIPT_DIR":$CONTAINER_REPO \
  "$IMAGE" \
  bash -c "
    echo '==> Updating package index...'
    apt-get update -y >/dev/null

    echo '==> Installing minimal dependencies...'
    apt-get install -y bash curl git sudo >/dev/null

    echo '==> Ensuring directory structure exists...'
    mkdir -p $CONTAINER_SRC

    echo '==> Verifying install script at $INSTALL_SCRIPT'
    if [ ! -f $INSTALL_SCRIPT ]; then
        echo 'ERROR: install.sh not found at expected location!'
        exit 1
    fi

    echo '==> Running install script...'
    bash $INSTALL_SCRIPT

    echo
    echo '==> Listing repo contents after install...'
    ls -al $CONTAINER_REPO
  "

echo
echo "==> Raspberry Pi test complete."