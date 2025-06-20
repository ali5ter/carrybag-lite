#!/usr/bin/env bash
# @file install.sh
# Simple bootstrap for my mac(s)
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

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

install() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        type brew >/dev/null 2>/dev/null || install_brew
        brew install "$@"
        # use `install --cask` for brew cask install
    else
        sudo apt install -y "$@"
    fi
}

install_pyenv() {
    # @ref https://github.com/pyenv/pyenv-installer
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install pyenv
    else
        # @ref https://bgasparotto.com/install-pyenv-ubuntu-debian
        install make build-essential libssl-dev zlib1g-dev libbz2-dev \
            libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
            xz-utils tk-dev libffi-dev liblzma-dev
        curl https://pyenv.run | bash
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
    fi
    eval "$(pyenv init -)"
    # Lastest version of python at time of commit
    # Use `pyenv install --list` for latest
    # @ref https://opensource.com/article/20/4/pyenv
    pyenv install 3.10.0
    pyenv install 2.7.18 # last version of 2
    pyenv global 3.10.0
    pyenv versions # confirm current version is set

    # can set a local version of python for particular projects using
    # pyenv local <version>
}

bootstrap_mac() {
    brew update && brew upgrade && brew cleanup;

    # CMDL applications
    # @ref https://formulae.brew.sh/formula/
    install bash # latest bash
    # ref: https://support.apple.com/en-us/HT208050
    export BASH_SILENCE_DEPRECATION_WARNING=1
    install git # souce control
    install_pyenv # do python install right
    install shellcheck vim watch # editing
    install bash-completion@2 # auto-completion
    install node go # dev
    install jq yq bat tree fzf # misc tools
    install ncdu # disk management
    install nmap # network tools

    # GUI applications
    # @ref https://formulae.brew.sh/cask/
    install --cask iterm2 # preferred terminal
    install --cask 1password # password vault
    install --cask dropbox # file storage
    #install --cask caffeine divvy bartender # windowing tools (optional)
    install --cask cleanmymac  # housekeeping
    install --cask figma # wire-framing/prototyping
    install --cask microsoft-teams whatsapp # messaging
    install --cask visual-studio-code # dev
    #install --cask chatgpt # chatgpt (only works on metal)
}

bootstrap_linux() {
    ## Assumes Debian/Ubuntu based distro with `apt` package manager and sudo access
    sudo apt update
    if [[ -f /etc/rpi-issue ]]; then
        sudo apt full-upgrade # for Raspberry Pi OS
    else
        sudo apt upgrade
    fi

    install curl wget gnupg git # download & certs
    install_pyenv # do python install right
    # install nodejs npm golang # dev
    install jq yq bat tree fzf # misc tools
    install shellcheck vim watch # editing
    install fontconfig # font tools

    sudo apt autoremove && sudo apt clean
}

install_carrybag() {
    # @ref https://github.com/ali5ter/carrybag-lite
    cd "$(src_dir)" || exit 1
    git clone https://github.com/ali5ter/carrybag-lite.git  && cd carrybag-lite
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ln -sf "$(src_dir)/carrybag-lite/bash_profile" ~/.bash_profile
    else
        ln -sf "$(src_dir)/carrybag-lite/bashrc" ~/.bashrc
        ln -sf ~/.bashrc ~/.bash_profile
    fi
}

install_nerd_fonts() {
    # @ref https://www.nerdfonts.com/font-downloads
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install --cask font-source-code-pro
    else
        [[ -d ~/.fonts ]] || mkdir -p ~/.fonts
        cd ~/.fonts || exit
        curl -fLo "Source Code Pro Nerd Font Complete.ttf" \
            https://github.com/ryanoasis/nerd-fonts/tree/db46f01c7a69befc5b656abbaec079d717c2e505/patched-fonts/SourceCodePro/SauceCodeProNerdFontMono-Regular.ttf
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
        sudo usermod -aG docker "$(whoami)"
    fi
}

install_starship() {
    # @ref https://starship.rs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install starship
    else
        curl -0 https://starship.rs/install.sh
        chmod +x install.sh
        ./install.sh -y 
        rm -f install.sh
    fi
    [ -f ~/.config/starship.toml ] || mkdir -p ~/.config && touch ~/.config/starship.toml
    cat > ~/.config/starship.toml <<'END_OF_STARSHIP_CONFIG'
[battery]
disabled = true
END_OF_STARSHIP_CONFIG
}

install_hstr() {
    # @ref https://github.com/dvorka/hstr
    install hstr
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
    install_nerd_fonts
    install_starship
    install_hstr
    #install_docker # uncomment to install docker
}

# Run the script if it is being executed directly
[ "${BASH_SOURCE[0]}" -ef "$0" ] && main "$@"
