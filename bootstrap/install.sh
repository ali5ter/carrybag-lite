#!/usr/bin/env bash
# @file install.sh
# Simple bootstrap for my mac(s)
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

install() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        type brew >/dev/null 2>/dev/null || install_brew
        brew install "$@"
        # use `install --cask` for brew cask install
    else
        sudo apt install -y "$@"
    fi
}

src_dir() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        [[ -d ~/Documents/projects ]] || mkdir -p ~/Documents/projects
        echo ~/Documents/projects
    else
        [[ -d ~/src ]] || mkdir -p ~/src
        echo ~/src
    fi
}

install_brew() {
    # @ref https://brew.sh/
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew tap homebrew/cask
    brew tap homebrew/cask-versions
    brew tap homebrew/cask-fonts
}

bootstrap_mac() {
    brew update && brew upgrade && brew cleanup;

    # CMDL applications
    # @ref https://formulae.brew.sh/formula/
    install bash # latest bash
    install shellcheck vim watch # editing
    install bash-completion@2  # auto-completion
    # install powerline-go # prompt
    install git svn node go python  # dev
    brew unlink python && brew link python
    install glances lazydocker   # monitoring
    install jq yq bat tree asciinema    # misc tools
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
    if ! type sudo >/dev/null 2>/dev/null; then
        apt upgrade && apt update
        apt install -y sudo
    fi
    sudo apt update && sudo apt upgrade

    install curl wget gnupg # download & certs
    install shellcheck vim watch    # editing
    install git python  # dev
    # install nodejs npm golang # more dev
    install speedtest-cli    # network tools
    install fontconfig  # font tools

    sudo apt autoremove && sudo apt clean
}

install_carrybag() {
    # @ref https://github.com/ali5ter/carrybag-lite
    cd "$(src_dir)" || exit 1
    git clone https://github.com/ali5ter/carrybag-lite.git  && cd carrybag-lite
    ln -sf "$(src_dir)/carrybag-lite/bash_profile" ~/.bash_profile
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ln -sf "$(src_dir)/carrybag-lite/bashrc_local_work" ~/.bashrc_local
    else 
        ln -sf ~/.bash_profile ~/.bash_aliases
    fi
}

install_powerline_fonts() {
    # @ref https://github.com/powerline/fonts
    cd "$(src_dir)" || exit 1
    git clone https://github.com/powerline/fonts.git --depth=1 && cd fonts
    ./install.sh
}

install_nerd_fonts() {
    # @ref https://www.nerdfonts.com/font-downloads
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install --cask font-source-code-pro
    else
        [[ -d ~/.fonts ]] || mkdir -p ~/.fonts
        cd ~/.fonts || exit
        curl -fLo "Source Code Pro Nerd Font Complete.ttf" \
            https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/SourceCodePro/Regular/complete/Sauce%20Code%20Pro%20Nerd%20Font%20Complete.ttf
        sudo fc-cache
    fi
}

install_docker() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install --cask docker  # container support
        # install --cask rancher-desktop # alt container support
    else
        # @ref https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script
        curl -fsSL https://get.docker.com -o get-docker.sh
        bash get-docker.sh && rm -f get-docker.sh
        usermod -aG docker "$(whoami)"
    fi
}

# Install legacy pip for non-migrated python tools
install_legacy_pip() {
    curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
    ln -sf ~/Library/Python/2.7/installn/pip /usr/local/installn/pip
}

install_starship() {
    # @ref https://starship.rs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install starship
    else
        bash -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y
    fi
    [ -f ~/.config/starship.toml ] || mkdir -p ~/.config && touch ~/.config/starship.toml
    cat > ~/.config/starship.toml <<'END_OF_STARSHIP_CONFIG'
format = "${custom.tmc}$all"

[kubernetes]
disabled = false

[custom.tmc]
description = "Display the current tmc context"
command = ". /Users/bowena/Documents/Projects/VMware/tmc-prompt/tmc_prompt.sh; tmc_prompt"
when= "command -v tmc 1>/dev/null 2>&1"
disabled = false
END_OF_STARSHIP_CONFIG
}

install_hstr() {
    # @ref https://github.com/dvorka/hstr
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install hstr
    else
        sudo echo -e "\ndeb https://www.mindforger.com/debian stretch main" | sudo tee -a /etc/apt/sources.list
        wget -qO - https://www.mindforger.com/gpgpubkey.txt | sudo apt-key add -
        sudo apt update
        sudo apt install hstr
    fi
}

install_pyenv() {
    # @ref https://github.com/pyenv/pyenv-installer
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install pyenv
    else
        curl https://pyenv.run | bash
    fi
}

main() {
    [[ -n $DEBUG ]] && set -x
    set -eou pipefail

    if [[ "$OSTYPE" == "darwin"* ]]; then
        bootstrap_mac
    else
        bootstrap_linux
    fi
    install_carrybag
    install_pyenv
    install_nerd_fonts
    install_starship
    install_hstr
    install_docker
}

# Run script is it is not sourced
[ "${BASH_SOURCE[0]}" -ef "$0" ] && main "$@"
