#!/usr/bin/env bash

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

# OS specific settings (perhaps check for platform before applything)
# Turn on Touch ID for sudo auth
# @ref https://sixcolors.com/post/2020/11/quick-tip-enable-touch-id-for-sudo/
# sudo echo 'auth sufficient pam_tid.so' >> /etc/pam.d/sudo

# Colors
# shellcheck disable=SC1090
[ -f ~/.colors.bash ] || curl -s -o ~/.colors.bash https://raw.githubusercontent.com/Bash-it/bash-it/master/themes/colors.theme.bash
# shellcheck disable=SC1090
source ~/.colors.bash

# Bookmarking
# @ref https://github.com/rupa/z
[ -f ~/.z.sh ] || curl -s -o ~/.z.sh https://raw.githubusercontent.com/rupa/z/master/z.sh
[ -f ~/.config/starship.toml ] || mkdir -p ~/.config && touch ~/.config/starship.toml
# shellcheck disable=SC1091
source "$HOME/.z.sh"
# shellcheck disable=SC2034
_Z_CMD=jump

# Word string
[ -f ~/.generate_word_string.sh ] || curl -s -o ~/.generate_word_string.sh https://raw.githubusercontent.com/ali5ter/vmware_scripts/master/tools/generate_word_string
# shellcheck disable=SC1090
source ~/.generate_word_string.sh

# Node version management
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Safe Python version management using pyenv
# @ref https://opensource.com/article/19/5/python-3-default-mac
type pyenv >/dev/null 2>&1 && {
    PATH="$(pyenv root)/shims:$PATH"
    eval "$(pyenv init -)"
}

# Paths
export PATH="/usr/local/sbin:$PATH"

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
alias fixcamera="sudo killall AppleCameraAssistant;sudo killall VDCAssistant"
type bat >/dev/null 2>&1 && {
    alias more=bat
    alias less=bat
}

# Completion
export BASH_COMPLETION_COMPAT_DIR=/usr/local/etc/bash_completion.d 2>/dev/null
# shellcheck disable=SC1091
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

# Prompts

# @ref https://starship.rs/
type starship >/dev/null 2>&1 && {
    eval "$(starship init bash)"
}
# @ref https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/
# shellcheck disable=SC2154
PS2="${cyan}…${normal} "            # continuation
PS4="${cyan}$0.$LINENO ⨠${normal} " # tracing

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

[[ "$OSTYPE" == 'darwin'* ]] && {
    brew_update() {
        # Additional homebrew housekeeping
        brew update && brew upgrade && brew cleanup; 
    }
    # Automate homebrew update
    UPDATE_DATE="$HOME/.last_update"
    [ -f "$UPDATE_DATE" ] || echo "00" > "$UPDATE_DATE"
    if [ "$CDATE" != "$(head -n 1 "$UPDATE_DATE")" ]; then
        echo "$CDATE" > "$UPDATE_DATE"
        # shellcheck disable=SC2154
        echo -e "Checking homebrew..."
        brew_update
    fi
}

# Additional configurations/overrides
# shellcheck disable=SC1091
[ -r ~/.bashrc_local ] && source "$HOME/.bashrc_local"