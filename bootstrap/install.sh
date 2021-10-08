#!/usr/bin/env bash
# @file install.sh
# Simple bootstrap for my mac(s)
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

bi() { brew install "$@"; }
bci() { brew install "$@"; }

# Bootstrap brew and cask
# https://brew.sh/

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew tap homebrew/cask
brew tap homebrew/cask-versions

# CMDL applications
# https://formulae.brew.sh/formula/

bi bash # latest bash
bi shellcheck vim watch # editing
bi bash-completion  # auto-completion
bi git node go python  # dev
brew unlink python && brew link python
bi powerline-go
bi jq bat hstr  # misc tools
bi speedtest-cli    # network tools
bi kubectl kustomize helm kube-ps1 skaffold # k8s tooling
bi minikube kind    # vrtual k8s cluster
minikube config set memory 4096

# GUI applications
# https://formulae.brew.sh/cask/

bci iterm2  # preferred terminal
bci google-chrome-canary    # browser
bci 1password dropbox   # password vault
bci caffeine divvy bartender    # windowing tools
bci charles little-snitch tunnelblick fing  # network tools
# bci wireshark # Issue https://github.com/caskroom/homebrew-cask/issues/40867
bci cleanmymac  # housekeeping
bci docker  # container support
# bci rancher-desktop # alt container support
# bci axure-rp    # wire-framing/prototyping
# bci sketch sketch-toolbox   # wire-framing/prototyping
bci figma miro  # wire-framing/prototyping
bci skype   # video
# bci slack   # chat
# bci reeder  # rss/atom-feeds
bci screenflow  # screen recording
bci visual-studio-code sourcetree pyenv  # dev
# bci xscope
# bci webstorm
# bci caskroom/versions/microsoft-remote-desktop-beta
bci turbovnc-viewer  # remote access

# Tools from git
#[[ -d ~/Documents/projects ]] && mkdir ~/Documents/projects && cd ~/Documents/projects
#git clone https://github.com/ali5ter/carrybag-lite.git  && cd carrybag-lite
#ln bash_profile ~/.bash_profile
#ln bash_local_work ~/.bash_local

# Get powerline fonts
git clone https://github.com/powerline/fonts.git --depth=1
cd fonts
./install.sh
cd - || exit
rm -rf fonts

# Preferences
mkdir -p ~/.jump && cp ../preferences/jump.bookmarks ~/.jump/bookmarks
