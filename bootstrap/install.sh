#!/usr/bin/env bash
# @file install.sh
# Simple bootstrap for my macOS and Linux machines.
# Assumes that carrybag-lite has already been cloned to the local machine.
#
# Generating a new SSH key and adding it to ssh-agent:
#   ssh-keygen -t ed25519 -C "your_email@example.com"
#   eval "$(ssh-agent -s)"
#   ssh-add -K ~/.ssh/id_ed25519  # macOS
#   ssh-add ~/.ssh/id_ed25519     # Linux
# Copy it and add to GitHub:
#   pbcopy < ~/.ssh/id_ed25519.pub # macOS
#   xclip -sel clip < ~/.ssh/id_ed25519.pub # Linux
#
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
        # Assumes Debian/Ubuntu based distro with `apt` package manager and sudo access
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
    # Latest version of python at time of commit
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
    install git # source control
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
    # install nodejs npm golang # dev
    install jq yq bat tree fzf figlet # misc tools
    install shellcheck vim watch # editing
    install fontconfig # font tools

    sudo apt autoremove && sudo apt clean
}

remote_management() {
     # Raspberry Pi remote management tool
    if [[ -f /etc/rpi-issue ]]; then
        install rpi-connect-lite
        rpi-connect on
        loginctl enable-linger
        # Signin will succeed or fail gracefully if already signed in
        rpi-connect signin 2>&1 | \
            grep -qE "(Signed in|Already signed in)" && return 0 || return 1
    fi
}

ethernet_over_wifi() {
    # Prioritize ethernet over wifi if ethernet is available
    if [[ -f /etc/rpi-issue ]]; then
        nmcli --fields autoconnect-priority,name connection
        sudo nmcli connection modify "Wired connection 1" connection.autoconnect-priority 999
        nmcli --fields autoconnect-priority,name connection
    fi
}

config_carrybag() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ln -sf "$(src_dir)/carrybag-lite/bash_profile" ~/.bash_profile
    else
        # shellcheck disable=SC2046
        cp ~/.bashrc ~/.bashrc.$(date +%Y%m%d%H%M%S)
        ln -sf "$(src_dir)/carrybag-lite/bash_profile" ~/.bashrc
        ln -sf ~/.bashrc ~/.bash_profile
    fi
}

install_pfb() {
    # @ref https://github.com/ali5ter/pfb
    cd "$(src_dir)" || exit 1

    if [[ ! -d pfb ]]; then
        git clone https://github.com/ali5ter/pfb.git
        cd pfb
    else
        cd pfb
        git pull
    fi

    source ./pfb.sh
}

install_banner() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        :
    else
        sudo cp "$(src_dir)/carrybag-lite/bootstrap/banner.sh" /etc/profile.d/banner.sh
    fi
}

install_nerd_fonts() {
    # @ref https://www.nerdfonts.com/font-downloads
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install --cask font-sauce-code-pro-nerd-font
        install --cask font-symbols-only-nerd-font
    else
        [[ -d ~/.fonts ]] || mkdir -p ~/.fonts
        cd ~/.fonts || exit
        curl -fLo "Source Code Pro Nerd Font Complete.ttf" \
            https://github.com/ryanoasis/nerd-fonts/tree/db46f01c7a69befc5b656abbaec079d717c2e505/patched-fonts/SourceCodePro/SauceCodeProNerdFontMono-Regular.ttf
        curl -fLo "Symbols Nerd Font-Regular.ttf" \
            https://github.com/ryanoasis/nerd-fonts/blob/e708dbae2dbc943dca073703f05a34645a5367c0/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFont-Regular.ttf
        curl -fLo "Symbols Nerd Font Mono-Regular.ttf" \
            https://github.com/ryanoasis/nerd-fonts/blob/e708dbae2dbc943dca073703f05a34645a5367c0/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFontMono-Regular.ttf
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

configure_firewall() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS firewall configuration
        # sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
        # sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
        # sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
        :
    else
        # Linux firewall configuration (using ufw)
        sudo apt install -y ufw
        sudo ufw enable
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh # allow SSH connections
        sudo ufw allow http # allow HTTP connections
        sudo ufw allow https # allow HTTPS connections
        sudo ufw allow 2375 # allow Docker API
        sudo ufw status verbose
    fi
}

install_starship() {
    # @ref https://starship.rs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install starship
    else
        curl -fsSL https://starship.rs/install.sh -o install.sh
        chmod +x install.sh
        ./install.sh -y 
        rm -f install.sh
    fi
    [ -f ~/.config/starship.toml ] || { mkdir -p ~/.config && touch ~/.config/starship.toml; }
    cat > ~/.config/starship.toml <<'END_OF_STARSHIP_CONFIG'
[aws]
disabled = true
[battery]
disabled = true
[buf]
disabled = true
[bun]
disabled = true
[c]
disabled = true
[cpp]
disabled = true
[cmake]
disabled = true
[cobol]
disabled = true
[cmd_duration]
disabled = true
[conda]
disabled = true
[crystal]
disabled = true
[daml]
disabled = true
[dart]
disabled = true
[deno]
disabled = true
[dotnet]
disabled = true
[elixir]
disabled = true
[elm]
disabled = true
[erlang]
disabled = true
[fennel]
disabled = true
[fortran]
disabled = true
[fossil_branch]
disabled = true
[fossil_metrics]
disabled = true
[gcloud]
disabled = true
[gleam]
disabled = true
[golang]
disabled = true
[guix_shell]
disabled = true
[gradle]
disabled = true
[haskell]
disabled = true
[haxe]
disabled = true
[helm]
disabled = true
[java]
disabled = true
[julia]
disabled = true
[kotlin]
disabled = true
[lua]
disabled = true
[meson]
disabled = true
[mise]
disabled = true
[mojo]
disabled = true
[nats]
disabled = true
[nim]
disabled = true
[nix_shell]
disabled = true
[ocaml]
disabled = true
[odin]
disabled = true
[opa]
disabled = true
[openstack]
disabled = true
[os]
disabled = true
[package]
disabled = true
[perl]
disabled = true
[php]
disabled = true
[pixi]
disabled = true
[purescript]
disabled = true
[quarto]
disabled = true
[rlang]
disabled = true
[raku]
disabled = true
[red]
disabled = true
[ruby]
disabled = true
[rust]
disabled = true
[scala]
disabled = true
[singularity]
disabled = true
[solidity]
disabled = true
[spack]
disabled = true
[swift]
disabled = true
[typst]
disabled = true
[vagrant]
disabled = true
[vlang]
disabled = true
[vcsh]
disabled = true
[xmake]
disabled = true
[zig]
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

    install_pfb

    if [[ "$OSTYPE" == "darwin"* ]]; then
        pfb heading "Bootstrapping your Mac" "🚀"
        bootstrap_mac
    else
        pfb heading "Bootstrapping your Linux machine" "🚀"
        bootstrap_linux
    fi
    install_banner
    pfb success "Bootstrap complete!"
    echo
    echo; local default='N'; read -r -p "Do you want to connect ethernet? [y/N]: " response
    pfb answer ${response:-$default}
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        ethernet_over_wifi
        pfb success "Network interfaces prioritized!"
    fi
    echo
    pfb info "Setting up remote management..."
    remote_management || pfb warning "Remote management setup failed"
    echo
    echo; local default='N'; read -r -p "Install pyenv? [y/N]: " response
    pfb answer ${response:-$default}
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        install_pyenv
        pfb success "pyenv installed!"
    fi
    echo
    pfb info "Configure carrybag-lite..."
    config_carrybag
    pfb success "carrybag-lite configured!"
    echo
    pfb info "Installing nerd fonts..."
    install_nerd_fonts
    pfb success "Nerd fonts installed!"
    echo
    pfb info "Installing starship prompt..."
    install_starship
    pfb success "Starship prompt installed!"
    echo
    pfb info "Installing hstr..."
    install_hstr
    pfb success "hstr installed!"
    echo
    echo; local default='N'; read -r -p "Install Docker? [y/N]: " response
    pfb answer ${response:-$default}
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        install_docker
        pfb success "Docker installed!"
    fi
    echo
    pfb info "Configuring firewall..."
    configure_firewall
    pfb success "Firewall configured!"
    echo
    pfb success "All done!"
    echo
    pfb info "You may need to restart your terminal or log out/in for all changes to take effect."
    echo; local default='N'; read -r -p "Reboot now? [y/N]: " response
    pfb answer ${response:-$default}
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        pfb info "Rebooting..."
        sudo reboot
    else
        pfb info "Remember to reboot later for all changes to take effect."
    fi
}

# Run the script if it is being executed directly
[ "${BASH_SOURCE[0]}" -ef "$0" ] && main "$@"
