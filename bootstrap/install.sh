#!/usr/bin/env bash
# @file install.sh
# Simple bootstrap for my mac(s)
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

bi() { brew install "$@"; }
bci() { brew install --cask "$@"; }

# Bootstrap brew and cask
# @ref https://brew.sh/

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew tap homebrew/cask
brew tap homebrew/cask-versions
brew tap homebrew/cask-fonts

# CMDL applications
# @ref https://formulae.brew.sh/formula/

bi bash # latest bash
bi shellcheck vim watch # editing
bi bash-completion  # auto-completion
bi starship # prompt
# bi powerline-go # prompt
bi git svn node go python  # dev
brew unlink python && brew link python
bi glances lazydocker   # monitoring
bi jq yq bat hstr tree # misc tools
bi ncdu # disk management
bi speedtest-cli    # network tools
bi kubectl kustomize helm kube-ps1 skaffold # k8s tooling
bi minikube kind    # vrtual k8s cluster
minikube config set memory 4096

# GUI applications
# @ref https://formulae.brew.sh/cask/

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

# Powerline fonts
# git clone https://github.com/powerline/fonts.git --depth=1
# cd fonts
# ./install.sh
# cd - || exit
# rm -rf fonts

# Nerd fonts
# @ref https://www.nerdfonts.com/font-downloads
bci font-source-code-pro

# Install legacy pip for non-migrated python tools
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
ln -sf ~/Library/Python/2.7/bin/pip /usr/local/bin/pip

# Preferences
# mkdir -p ~/.jump && cp ../preferences/jump.bookmarks ~/.jump/bookmarks
[ -f ~/.config/starship.toml ] || mkdir -p ~/.config && touch ~/.config/starship.toml
cat << EOF > ~/.config/starship.toml
format = "$all${custom.tmc}$character"

[kubernetes]
disabled = false

[custom.tmc]
description = "Display the current tmc context"
command = "tmc current | yq e '.full_name.name' -"
when= "command -v tmc 1>/dev/null 2>&1"
disabled = false
EOF
