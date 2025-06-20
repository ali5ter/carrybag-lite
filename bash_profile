#!/usr/bin/env bash
# ~/.bash_profile
# This file is sourced by bash when it is started as a login shell.
# It is used to set environment variables, aliases, and other configurations.
# @ref https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html

# Paths
export PATH="/usr/local/sbin:$PATH"
export PATH="/opt/homebrew/bin:$PATH" # For Apple Silicon Macs
export PATH="/usr/local/Homebrew/bin:$PATH" # For Intel Macs

# Options
# @ref https://www.computerhope.com/unix/bash/shopt.htm
shopt -s checkwinsize   # check the window size after each command
shopt -s dotglob        # include file names beginning with a '.' in pathnames
shopt -s histappend     # append history instead of overwriting it
shopt -s cdspell        # corrected minor spelling errors during cd
# @ref https://www.linuxjournal.com/content/using-bash-history-more-efficiently-histcontrol
HISTCONTROL=ignoreboth
CDATE=$(date '+%Y%m%d')
# Enable ls colors
export CLICOLOR=1

# OS specific settings
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Turn on Touch ID for sudo auth
    # @ref https://sixcolors.com/post/2020/11/quick-tip-enable-touch-id-for-sudo/
    if ! grep -q 'pam_tid.so' /etc/pam.d/sudo; then
        echo 'auth sufficient pam_tid.so' | sudo tee -a /etc/pam.d/sudo > /dev/null
    fi
    # Fix for Apple Camera Assistant
    # @ref https://www.macrumors.com/2020/11/17/apple-camera-assistant-bug-fix/
    # fixcamera() {
    #     sudo killall AppleCameraAssistant
    #     sudo killall VDCAssistant
    # }
fi

# Bookmarking
# @ref https://github.com/rupa/z
[ -f ~/.z.sh ] || curl -s -o ~/.z.sh https://raw.githubusercontent.com/rupa/z/master/z.sh
# shellcheck disable=SC1091
source "$HOME/.z.sh"
# shellcheck disable=SC2034
_Z_CMD=jump

# Node version management
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Safe Python version management using pyenv
if [[ "$OSTYPE" == "darwin"* ]]; then
    type pyenv >/dev/null 2>&1 && {
        # @ref https://opensource.com/article/19/5/python-3-default-mac
        eval "$(pyenv init --path)"
        eval "$(pyenv init -)"
    }
else
    [[ -f "$HOME/.pyenv/bin/pyenv" ]] && {
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init --path)"
        eval "$(pyenv init -)"
    }
fi

# Editors
set -o vi
export EDITOR='vim'
export GIT_EDITOR="$EDITOR"

# Aliases
alias source_=". ~/.bash_profile"
alias uuidgen="\uuidgen | tr [:upper:] [:lower:] | tee >(pbcopy)"
alias suuidgen="uuidgen | cut -d- -f1 | tee >(pbcopy)"
alias datestamp="date '+%F %T %z %Z' | tee >(pbcopy)"
alias gs="git status"
type bat >/dev/null 2>&1 && {
    alias more=bat
    alias less=bat
}

# Completion
# @ref https://github.com/scop/bash-completion
export BASH_COMPLETION_COMPAT_DIR=/usr/local/etc/bash_completion.d 2>/dev/null
# shellcheck disable=SC1091
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

# Prompts
# @ref https://starship.rs/
[ -f ~/.config/starship.toml ] || mkdir -p ~/.config && touch ~/.config/starship.toml
type starship >/dev/null 2>&1 && {
    eval "$(starship init bash)"
}
# @ref https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/
# shellcheck disable=SC2154
PS2="${cyan}…${normal} "            # continuation
PS4="${cyan}$0.$LINENO ⨠${normal} " # tracing

# Package manager
if [[ "$OSTYPE" == 'darwin'* ]] then
    # Homebrew environment
    # @ref https://brew.sh/
    if [[ -f "$HOME/.config/homebrew_github_api_token" ]]; then
        # shellcheck disable=SC2155
        # shellcheck disable=SC2086
        export HOMEBREW_GITHUB_API_TOKEN=$(cat $HOME/.config/homebrew_github_api_token)
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
    brew_update() {
        # Additional homebrew housekeeping
        brew update && brew upgrade && brew autoremove && brew cleanup; 
    }
    # Remove annoying Apple msg
    # https://support.apple.com/en-us/HT208050
    export BASH_SILENCE_DEPRECATION_WARNING=1
    # Automate homebrew update
    LAST_BREW_UPDATE="$HOME/.last_brew_update"
    [ -f "$LAST_BREW_UPDATE" ] || echo "00" > "$LAST_BREW_UPDATE"
    if [ "$CDATE" != "$(head -n 1 "$LAST_BREW_UPDATE")" ]; then
        echo "$CDATE" > "$LAST_BREW_UPDATE"
        # shellcheck disable=SC2154
        echo -e "Checking homebrew..."
        brew_update
    fi

else
    apt_update() {
        sudo apt update
        if [[ -f /etc/rpi-issue ]]; then
            sudo apt full-upgrade # for Raspberry Pi OS
        else
            sudo apt upgrade
        fi
        sudo apt autoremove -y && sudo apt clean;
    }
    # Automate apt update
    LAST_APT_UPDATE="$HOME/.last_apt_update"
    [ -f "$LAST_APT_UPDATE" ] || echo "00" > "$LAST_APT_UPDATE"
    if [ "$CDATE" != "$(head -n 1 "$LAST_APT_UPDATE")" ]; then
        echo "$CDATE" > "$LAST_APT_UPDATE"
        # shellcheck disable=SC2154
        echo -e "Checking apt..."
        apt_update
    fi
fi

# History manager
# @ref https://github.com/dvorka/hstr/blob/master/CONFIGURATION.md
type hstr >/dev/null 2>&1 && {
    alias hh=hstr                    # hh to be alias for hstr
    export HSTR_CONFIG=hicolor       # get more colors
    shopt -s histappend              # append new history items to .bash_history
    export HISTCONTROL=ignorespace   # leading space hides commands from history
    export HISTFILESIZE=10000        # increase history file size (default is 500)
    export HISTSIZE=${HISTFILESIZE}  # increase history size (default is 500)
    # ensure synchronization between bash memory and history file
    export PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
    # if this is interactive shell, then bind hstr to Ctrl-r (for Vi mode check doc)
    if [[ $- =~ .*i.* ]]; then bind '"\C-r": "\C-a hstr -- \C-j"'; fi
    # if this is interactive shell, then bind 'kill last command' to Ctrl-x k
    if [[ $- =~ .*i.* ]]; then bind '"\C-xk": "\C-a hstr -k \C-j"'; fi
}

# Functions

ostype() {
    # Echo the flavor of OS
    if [[ "$OSTYPE" == 'darwin'* ]]; then
        sw_vers
    else
        lsb_release -a
    fi
}

cwc() {
    # Open a crossword clue in DanWord
    local clue="$*"
    local url=''
    clue=$(echo "$clue" | tr ' ' '_')
    url="https://www.danword.com/crossword/$clue"
    echo "Opening $url"
    open "$url"
}

# Additional configurations/overrides
# shellcheck disable=SC1091
[ -r ~/.bashrc_local ] && source "$HOME/.bashrc_local"