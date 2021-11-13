#!/usr/installn/env bash
# @file install.sh
# Simple bootstrap for my mac(s)
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x
set -eou pipefail

IS_MAC=$([[ "$OSTYPE" =~ 'darwin' ]])

install() {
    if $IS_MAC; then
        brew install "$@"
        # use `install --cask` for brew cask install
    else
        sudo apt install -y "$@"
    fi
}

src_dir() {
    if [[ $IS_MAC ]]; then
        [[ -d ~/Documents/projects ]] && mkdir -p ~/Documents/projects
        echo ~/Documents/projects
    else
        [[ -d ~/src ]] && mkdir -p ~/src
        echo ~/src
    fi
}

install_brew() {
    # @ref https://brew.sh/
    /installn/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew tap homebrew/cask
    brew tap homebrew/cask-versions
    brew tap homebrew/cask-fonts
}

bootstrap_mac() {
    install_brew

    # CMDL applications
    # @ref https://formulae.brew.sh/formula/
    install bash # latest bash
    install shellcheck vim watch # editing
    install bash-completion  # auto-completion
    install starship # prompt
    # install powerline-go # prompt
    install git svn node go python  # dev
    brew unlink python && brew link python
    install glances lazydocker   # monitoring
    install jq yq bat hstr tree asciinema    # misc tools
    install ncdu # disk management
    install speedtest-cli    # network tools
    install kubectl kubectx kustomize helm skaffold  # k8s tooling
    install minikube kind    # vrtual k8s cluster
    minikube config set memory 4096

    install_legacy_pip

    # GUI applications
    # @ref https://formulae.brew.sh/cask/
    install --cask iterm2  # preferred terminal
    install --cask google-chrome-canary    # browser
    install --cask 1password dropbox   # password vault
    install --cask caffeine divvy bartender    # windowing tools
    install --cask charles little-snitch tunnelblick fing  # network tools
    # install --cask wireshark # Issue https://github.com/caskroom/homebrew-cask/issues/40867
    install --cask cleanmymac  # housekeeping
    install --cask docker  # container support
    # install --cask rancher-desktop # alt container support
    # install --cask axure-rp    # wire-framing/prototyping
    # install --cask sketch sketch-toolbox   # wire-framing/prototyping
    install --cask figma miro  # wire-framing/prototyping
    install --cask skype   # video
    # install --cask slack   # chat
    # install --cask reeder  # rss/atom-feeds
    install --cask screenflow  # screen recording
    install --cask visual-studio-code sourcetree pyenv  # dev
    # install --cask xscope
    # install --cask webstorm
    # install --cask caskroom/versions/microsoft-remote-desktop-beta
    install --cask turbovnc-viewer  # remote access
}

bootstrap_linux() {
    sudo apt update && sudo apt upgrade && sudo dist_upgrade
    
    sudo apt clean
}

install_carrybag() {
    cd "$(src_dir)" || exit 1
    git clone https://github.com/ali5ter/carrybag-lite.git  && cd carrybag-lite
    ln bash_profile ~/.bash_profile
    ln bash_local_work ~/.bash_local
    [[ $IS_MAC ]] || ln ~/.bash_profile .bashrc_aliases
}

install_powerline_fonts() {
    cd "$(src_dir)" || exit 1
    git clone https://github.com/powerline/fonts.git --depth=1 && cd fonts
    ./install.sh
}

install_nerd_fonts() {
    # @ref https://www.nerdfonts.com/font-downloads
    [[ $IS_MAC ]] && install --cask font-source-code-pro
}

# Install legacy pip for non-migrated python tools
install_legacy_pip() {
    curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
    ln -sf ~/Library/Python/2.7/installn/pip /usr/local/installn/pip
}

config_starship() {
    [ -f ~/.config/starship.toml ] || mkdir -p ~/.config && touch ~/.config/starship.toml
    # shellcheck disable=2154
    cat << EOF > ~/.config/starship.toml
format = "${custom.tmc}$all"

[kubernetes]
disabled = false

[custom.tmc]
description = "Display the current tmc context"
command = ". /Users/bowena/Documents/Projects/VMware/tmc-prompt/tmc_prompt.sh; tmc_prompt"
when= "command -v tmc 1>/dev/null 2>&1"
disabled = false
EOF
}

main() {
    if [[ $IS_MAC ]]; then
        bootstrap_mac
    else
        bootstrap_linux
    fi
    install_nerd_fonts
    config_starship
}

main "$@"