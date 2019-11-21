#!/usr/bin/env bash
# @file install.sh
# Script to install macOS apps I want
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

# Bootstrap brew and cask
# https://brew.sh/

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew tap caskroom/cask

# CMDL applications
# https://formulae.brew.sh/formula/

alias bi='brew install'
bi bash shellcheck vim watch
bi git bash-completion bash-completion@2
bi node
bi jq bat
bi install kubernetes-cli kube-ps1 minikube
minikube config set memory 4096

# GUI applications
# https://formulae.brew.sh/cask/

alias bci='brew cask install'
bci google-chrome-canary
bci 1password dropbox
bci caffeine divvy bartender
bci charles little-snitch
# bci wireshark # Issue https://github.com/caskroom/homebrew-cask/issues/40867
bci cleanmymac
bci docker
# bci axure-rp
bci sketch sketch-toolbox
bci figma
bci skype
bci slack
bci reeder
bci sourcetree
bci screenflow
bci tunnelblick
bci visual-studio-code
# bci xscope
# bci webstorm
bci caskroom/versions/microsoft-remote-desktop-beta
bci minikube

# no cask for:
# MacAppBlocker
# TurboVNC
