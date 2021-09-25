#!/usr/bin/env bash
# @file install.sh
# Simple bootstrap for my mac(s)
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

# Bootstrap brew and cask
# https://brew.sh/

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew tap caskroom/cask

# CMDL applications
# https://formulae.brew.sh/formula/

alias bi='brew install'
bi bash # latest bash
bi shellcheck vim watch    # editing
bi bash-completion bash-completion@2    # auto-completion
bi git node # dev
bi jq bat hst   # misc tools
bi kubectl kustomize helm kube-ps1 kind skaffold    # k8s tooling
bi minikube
minikube config set memory 4096

# GUI applications
# https://formulae.brew.sh/cask/

alias bci='brew cask install'
bci iterm2  # preferred terminal
bci google-chrome-canary    # browser
bci 1password dropbox   # password vault
bci caffeine divvy bartender    # windowing tools
bci charles little-snitch tunnelblick   # network tools
# bci wireshark # Issue https://github.com/caskroom/homebrew-cask/issues/40867
bci cleanmymac  # housekeeping
bci docker  # container support
# bci axure-rp
# bci sketch sketch-toolbox
bci figma   # drawing
bci skype slack   # video/chat
# bci reeder
bci screenflow  # screen recording
bci visual-studio-code sourcetree pyenv  # dev
# bci xscope
# bci webstorm
# bci caskroom/versions/microsoft-remote-desktop-beta
bci turbovnc-viewer  # remote access

# Tools from git
[[ -d ~/Documents/projects ]] && mkdir ~/Documents/projects && cd ~/Documents/projects
git clone https://github.com/ali5ter/carrybag-lite.git  && cd carrybag-lite
ln bash_profile ~/.bash_profile
ln bash_local_work ~/.bash_local

# Get powerline fonts
git clone https://github.com/powerline/fonts.git --depth=1
cd fonts
./install.sh
cd ..
rm -rf fonts

# Install python based tools
pip install powerline-go