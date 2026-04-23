#!/usr/bin/env bash
#
# install.sh - Bootstrap macOS and Linux machines with carrybag-lite environment
#
# Assumes carrybag-lite has already been cloned to the local machine. Installs
# packages, links shell configuration, sets up AI tools, and configures SSH.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.8.5
# Date: 2026-04-20
# License: MIT
#
# Usage: ./bootstrap/install.sh
#   Run directly to perform full interactive bootstrap. Individual functions
#   may also be sourced and called in isolation for targeted setup:
#     source bootstrap/install.sh && install_starship
#
# Dependencies:
#   macOS  - Homebrew (auto-installed if absent), curl, git
#   Linux  - apt, curl, git, sudo
#   Both   - pfb (auto-installed via install_pfb)
#
# Exit codes:
#   0 - Success
#   1 - Fatal error (directory not found, required tool unavailable)
#
# Note: Generating a new SSH key and adding it to ssh-agent:
#   ssh-keygen -t ed25519 -C "your_email@example.com"
#   eval "$(ssh-agent -s)"
#   ssh-add --apple-use-keychain ~/.ssh/id_ed25519  # macOS
#   ssh-add ~/.ssh/id_ed25519                        # Linux
# Copy it and add to GitHub:
#   pbcopy < ~/.ssh/id_ed25519.pub  # macOS
#   xclip -sel clip < ~/.ssh/id_ed25519.pub  # Linux

src_dir() {
    # Return the platform-appropriate projects root directory, creating it if absent.
    # @return 0; prints directory path to stdout
    # @example local dir; dir="$(src_dir)"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        [[ -d ~/Documents/projects ]] || mkdir -p ~/Documents/projects
        echo ~/Documents/projects
    else
        [[ -d ~/src ]] || mkdir -p ~/src
        echo ~/src
    fi
}

install_brew() {
    # Install Homebrew and add standard taps.
    # @return 0 on success, non-zero if curl or brew fails
    # @example install_brew
    # @ref https://brew.sh/
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew tap homebrew/cask
    brew tap homebrew/cask-versions
    brew tap homebrew/cask-fonts
}

install() {
    # Install one or more packages using the platform package manager.
    # On macOS uses brew; on Linux uses apt. Homebrew is auto-installed if absent.
    # @param packages  One or more package names (or brew flags e.g. --cask)
    # @return 0 on success, non-zero on install failure
    # @example install git vim
    # @example install --cask iterm2
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
    # Install pyenv and set Python 3.10.0 as the global default.
    # On Linux installs required build dependencies via apt first.
    # @return 0 on success, non-zero if pyenv or python install fails
    # @example install_pyenv
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
    # Install all standard packages and GUI apps for macOS via Homebrew.
    # @return 0 on success, non-zero if any brew install fails
    # @example bootstrap_mac
    brew update && brew upgrade && brew cleanup;

    # CMDL applications
    # @ref https://formulae.brew.sh/formula/
    install bash # latest bash
    # ref: https://support.apple.com/en-us/HT208050
    export BASH_SILENCE_DEPRECATION_WARNING=1
    install git # source control
    install zoxide # cd replacement
    install_pyenv # do python install right
    install shellcheck vim watch # editing
    install bash-completion@2 # auto-completion
    install node go # dev
    install jq yq bat fd tree fzf # misc tools
    install btop # system monitoring
    install ncdu # disk management
    install nmap # network tools
    install wakeonlan # wake-on-lan
    install gemini-cli codex # AI tools (claude-code installed via install_claude_code)
    install figlet # banner generation

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
}

bootstrap_linux() {
    # Install all standard packages for Debian/Ubuntu-based Linux via apt.
    # Raspberry Pi OS uses full-upgrade instead of upgrade.
    # @return 0 on success, non-zero if any apt install fails
    # @example bootstrap_linux
    ## Assumes Debian/Ubuntu based distro with `apt` package manager and sudo access
    sudo apt update
    if [[ -f /etc/rpi-issue ]]; then
        sudo apt full-upgrade # for Raspberry Pi OS
    else
        sudo apt upgrade
    fi
    
    install curl wget gnupg git # download & certs
    install nodejs npm # required for gemini-cli and codex
    install jq yq bat tree fd-find fzf figlet # misc tools
    install zoxide # cd replacement
    install shellcheck vim watch # editing
    install btop ncdu # system monitoring and disk management
    install fontconfig # font tools
    install wakeonlan # wake-on-lan

    sudo apt autoremove && sudo apt clean
}

remote_management() {
    # Set up rpi-connect-lite for remote Raspberry Pi management. No-op on other platforms.
    # @return 0 on success or non-RPi platform, 1 if rpi-connect sign-in fails
    # @example remote_management || pfb warning "Remote management setup failed"
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
    # Prioritize ethernet over Wi-Fi on Raspberry Pi using nmcli connection priorities.
    # @return 0 on success or non-RPi platform
    # @example ethernet_over_wifi
    # Prioritize ethernet over wifi if ethernet is available
    if [[ -f /etc/rpi-issue ]]; then
        nmcli --fields autoconnect-priority,name connection
        sudo nmcli connection modify "Wired connection 1" connection.autoconnect-priority 999
        nmcli --fields autoconnect-priority,name connection
    fi
}

config_carrybag() {
    # Link bash_profile to the appropriate shell config location for the platform.
    # Idempotent: backs up ~/.bashrc only when it is a regular file (not already a symlink).
    # @return 0 on success
    # @example config_carrybag
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ln -sf "$(src_dir)/carrybag-lite/bash_profile" ~/.bash_profile
    else
        if [[ -f ~/.bashrc && ! -L ~/.bashrc ]]; then
            # shellcheck disable=SC2046
            cp ~/.bashrc ~/.bashrc.$(date +%Y%m%d%H%M%S)
        fi
        ln -sf "$(src_dir)/carrybag-lite/bash_profile" ~/.bashrc
        ln -sf ~/.bashrc ~/.bash_profile
    fi
}

install_pfb() {
    # Install pfb using the platform-appropriate installer and source it.
    # On macOS uses Homebrew (brew tap ali5ter/pfb); on Linux uses the official
    # curl installer which installs to /usr/bin/pfb.
    # @return 0 on success, non-zero if installation or sourcing fails
    # @example install_pfb
    # @ref https://github.com/ali5ter/pfb
    if [[ "$OSTYPE" == "darwin"* ]]; then
        type brew >/dev/null 2>/dev/null || install_brew
        brew tap ali5ter/pfb 2>/dev/null || true
        brew install pfb
    else
        curl -sL https://raw.githubusercontent.com/ali5ter/pfb/main/install.sh | bash
    fi

    # Source pfb from whichever location the installer used
    # shellcheck disable=SC1090
    for _pfb in \
        "$(brew --prefix 2>/dev/null)/bin/pfb" \
        /usr/bin/pfb \
        ~/.local/bin/pfb; do
        [[ -f "$_pfb" ]] && { source "$_pfb"; unset _pfb; break; }
    done
}

install_banner() {
    # Copy banner.sh to /etc/profile.d/ on Linux for login-time display. No-op on macOS.
    # @return 0 on success
    # @example install_banner
    if [[ "$OSTYPE" == "darwin"* ]]; then
        :
    else
        sudo cp "$(src_dir)/carrybag-lite/bootstrap/banner.sh" /etc/profile.d/banner.sh
    fi
}

install_nerd_fonts() {
    # Install Nerd Fonts for the Starship prompt. Uses brew cask on macOS;
    # downloads fonts to ~/.fonts and rebuilds the font cache on Linux.
    # @return 0 on success, non-zero if download or install fails
    # @example install_nerd_fonts
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
    # Install Docker Desktop (macOS) or Docker Engine via convenience script (Linux).
    # On Linux, adds the current user to the docker group.
    # @return 0 on success, non-zero if install fails
    # @example install_docker
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
    # Configure the system firewall. On Linux enables ufw with deny-incoming/allow-outgoing
    # defaults and allows SSH, HTTP, HTTPS, and Docker API ports. No-op on macOS.
    # @return 0 on success
    # @example configure_firewall
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
    # Install the Starship prompt and write a baseline starship.toml config.
    # Uses brew on macOS; downloads the install script on Linux.
    # @return 0 on success, non-zero if install or config write fails
    # @example install_starship
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
[hostname]
ssh_only = false
aliases = { "Alisters-iMac" = "imac", "Alisters-MacBook-Air" = "mb-air" }
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
[username]
show_always = true
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


config_ssh() {
    # Configure SSH keep-alive settings in ~/.ssh/config. Idempotent — skips the
    # Host * block if ServerAliveInterval is already present.
    # @return 0 on success
    # @example config_ssh
    [[ -f ~/.ssh/config ]] || {
        touch "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    }
    # Keep SSH connections alive (idempotent — skip if already configured)
    if ! grep -q 'ServerAliveInterval' ~/.ssh/config; then
        cat >> ~/.ssh/config <<EOT
Host *
    TCPKeepAlive=yes
    ServerAliveInterval 240
    ServerAliveCountMax 2
EOT
    fi
    # Also set up Wake-on-LAN
    # @ref https://www.ms8.com/using-wake-on-lan-from-the-command-line-on-macos/
    # wakeonlan "$(arp -a | grep -i 192.168.1.16 | awk '{print $4}')"
}

install_ai_tools() {
    # Install Claude Code, Gemini CLI, and Codex CLI. On macOS uses brew (gemini-cli
    # and codex) plus the Claude installer script; on Linux uses curl and npm.
    # @return 0 on success, non-zero if any installer fails
    # @example install_ai_tools
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install claude-code
        # gemini-cli and codex installed in bootstrap_mac via brew
    else
        curl -fsSL https://claude.ai/install.sh | bash
        # shellcheck disable=SC2016
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc_local"
        npm install -g @google/gemini-cli
        npm install -g @openai/codex
    fi
}

config_claude_code() {
    # Configure Claude Code by symlinking files from claude/ to ~/.claude/.
    # Delegates to claude/install.sh which handles backups and idempotency.
    # @return 0 on success, 0 with warning if claude/ directory is missing
    # @example config_claude_code
    local repo_dir
    repo_dir="$(src_dir)/carrybag-lite"
    if [[ -d "$repo_dir/claude" ]]; then
        "$repo_dir/claude/install.sh"
    else
        pfb warning "Claude Code configuration directory not found at $repo_dir/claude"
    fi
}

config_codex() {
    # Configure OpenAI Codex CLI by symlinking CLAUDE.md as AGENTS.md
    # @param None
    # @return 0 on success, 1 on failure
    # @example config_codex
    local repo_dir
    repo_dir="$(src_dir)/carrybag-lite"
    if [[ -d "$repo_dir/codex" ]]; then
        "$repo_dir/codex/install.sh"
    else
        pfb warning "Codex configuration directory not found at $repo_dir/codex"
    fi
}

config_gemini() {
    # Configure Google Gemini CLI by symlinking CLAUDE.md as GEMINI.md
    # @param None
    # @return 0 on success, 1 on failure
    # @example config_gemini
    local repo_dir
    repo_dir="$(src_dir)/carrybag-lite"
    if [[ -d "$repo_dir/gemini" ]]; then
        "$repo_dir/gemini/install.sh"
    else
        pfb warning "Gemini CLI configuration directory not found at $repo_dir/gemini"
    fi
}

main() {
    # Orchestrate the full interactive bootstrap sequence.
    # @param args  Unused; reserved for future flags
    # @return 0 on success, non-zero if a critical step fails
    # @example ./bootstrap/install.sh
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
    echo; local default='N'; read -r -p "Install Docker? [y/N]: " response
    pfb answer ${response:-$default}
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        install_docker
        pfb success "Docker installed!"
    fi
    echo
    pfb info "Installing AI tools..."
    install_ai_tools
    pfb success "AI tools installed!"
    echo
    pfb info "Configuring Claude Code..."
    config_claude_code
    pfb success "Claude Code configured!"
    echo
    pfb info "Configuring Codex..."
    config_codex
    pfb success "Codex configured!"
    echo
    pfb info "Configuring Gemini CLI..."
    config_gemini
    pfb success "Gemini CLI configured!"
    echo
    pfb info "Configuring SSH..."
    config_ssh
    pfb success "SSH configured!"
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
