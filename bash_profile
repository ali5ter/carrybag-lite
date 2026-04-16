#!/usr/bin/env bash
# ~/.bash_profile
# Sourced by bash when started as a login shell.
# @ref https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html

# ── PATHS ────────────────────────────────────────────────────────────────────

export PATH="/usr/local/sbin:$PATH"
[ -x /opt/homebrew/bin/brew ] && export PATH="/opt/homebrew/bin:$PATH"       # Apple Silicon
[ -x /usr/local/Homebrew/bin/brew ] && export PATH="/usr/local/Homebrew/bin:$PATH" # Intel Mac

# ── SHELL OPTIONS ─────────────────────────────────────────────────────────────

# @ref https://www.computerhope.com/unix/bash/shopt.htm
shopt -s checkwinsize   # update LINES/COLUMNS after each command
shopt -s dotglob        # include dotfiles in pathname expansion
shopt -s histappend     # append to history file, don't overwrite
shopt -s cdspell        # correct minor spelling errors in cd

# @ref https://www.linuxjournal.com/content/using-bash-history-more-efficiently-histcontrol
HISTCONTROL=ignoreboth
export HISTFILESIZE=10000
export HISTSIZE=${HISTFILESIZE}
export PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}" # sync across sessions

# ── ENVIRONMENT ───────────────────────────────────────────────────────────────

CDATE=$(date '+%Y%m%d')
export CLICOLOR=1
set -o vi
export EDITOR='vim'
export GIT_EDITOR="$EDITOR"

# ── PACKAGE MANAGER ───────────────────────────────────────────────────────────

if [[ "$OSTYPE" == 'darwin'* ]]; then
    # @ref https://brew.sh/
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
    [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
    if [[ -f "$HOME/.config/homebrew_github_api_token" ]]; then
        # shellcheck disable=SC2155,SC2086
        export HOMEBREW_GITHUB_API_TOKEN=$(cat $HOME/.config/homebrew_github_api_token)
    fi
    export BASH_SILENCE_DEPRECATION_WARNING=1
    brew_update() {
        brew update && brew upgrade && brew autoremove && brew cleanup
    }
    LAST_BREW_UPDATE="$HOME/.last_brew_update"
    [ -f "$LAST_BREW_UPDATE" ] || echo "00" > "$LAST_BREW_UPDATE"
    if [ "$CDATE" != "$(head -n 1 "$LAST_BREW_UPDATE")" ]; then
        echo "$CDATE" > "$LAST_BREW_UPDATE"
        echo -e "Checking homebrew..."
        brew_update
    fi
else
    apt_update() {
        sudo apt update
        if [[ -f /etc/rpi-issue ]]; then
            sudo apt full-upgrade   # Raspberry Pi OS
        else
            sudo apt upgrade
        fi
        sudo apt autoremove -y && sudo apt clean
    }
    rpi_firmware_update() {
        if [[ -f /etc/rpi-issue ]]; then
            sudo rpi-update
            sudo reboot
        fi
    }
    LAST_APT_UPDATE="$HOME/.last_apt_update"
    [ -f "$LAST_APT_UPDATE" ] || echo "00" > "$LAST_APT_UPDATE"
    if [ "$CDATE" != "$(head -n 1 "$LAST_APT_UPDATE")" ]; then
        echo "$CDATE" > "$LAST_APT_UPDATE"
        echo -e "Checking apt..."
        apt_update
    fi
fi

# ── TOOL SETUP ────────────────────────────────────────────────────────────────

# manual pages
# using bat — syntax-highlighted pager (bat on macOS, batcat on Debian)
type bat >/dev/null 2>&1 && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
type batcat >/dev/null 2>&1 && export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# zoxide — directory jumper
# @ref https://github.com/ajeetdsouza/zoxide
type zoxide >/dev/null 2>&1 && eval "$(zoxide init bash --cmd jump)"

# nvm — Node version management
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"                          # macOS (Homebrew)
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # macOS completion
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"                                               # Linux (standard)
# shellcheck disable=SC1091
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"                             # Linux completion

# pyenv — Python version management
# @ref https://opensource.com/article/19/5/python-3-default-mac
if [[ "$OSTYPE" == "darwin"* ]]; then
    type pyenv >/dev/null 2>&1 && {
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

# starship — prompt
# @ref https://starship.rs/
[ -f ~/.config/starship.toml ] || mkdir -p ~/.config && touch ~/.config/starship.toml
type starship >/dev/null 2>&1 && eval "$(starship init bash)"
# @ref https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/
# shellcheck disable=SC2154
PS2="… "             # continuation prompt
PS4="$0.$LINENO ⨠ " # tracing prompt

# fzf — fuzzy finder (Ctrl-R history, Ctrl-T files, Alt-C directories)
eval "$(fzf --bash)"
type fdfind >/dev/null 2>&1 && alias fd=fdfind  # Debian installs fd as fdfind
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --info=inline
'
_bat_cmd=$(type -P bat 2>/dev/null || type -P batcat 2>/dev/null) # bat on macOS, batcat on Debian
export FZF_CTRL_T_OPTS="
  --preview '$_bat_cmd -n --color=always {}'
  --line-range :500 {}
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

export FZF_ALT_C_OPTS="--preview 'tree -C {}'"

# ── ALIASES ───────────────────────────────────────────────────────────────────

# Reload config
alias source_=". ~/.bash_profile"

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Utilities
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias uuidgen="\uuidgen | tr [:upper:] [:lower:] | tee >(pbcopy)"
    alias suuidgen="uuidgen | cut -d- -f1 | tee >(pbcopy)"
    alias datestamp="date '+%F %T %z %Z' | tee >(pbcopy)"
else
    alias uuidgen="uuidgen | tr [:upper:] [:lower:]"
    alias suuidgen="uuidgen | cut -d- -f1"
    alias datestamp="date '+%F %T %z %Z'"
fi

# Git
alias gs="git status"
alias gd="git diff"

# bat — syntax-highlighted pager (bat on macOS, batcat on Debian)
type bat >/dev/null 2>&1 && alias more=bat && alias less=bat
type batcat >/dev/null 2>&1 && alias more=batcat && alias less=batcat

# claude-code
type claude >/dev/null 2>&1 && {
    cmd="claude --dangerously-skip-permissions"
    # shellcheck disable=SC2139
    alias claudeit="$cmd"
}

# ls and grep colours (Linux dircolors)
if [ -x /usr/bin/dircolors ]; then
    if test -r ~/.dircolors; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────

ostype() {
    # Echo the flavor of OS
    if [[ "$OSTYPE" == 'darwin'* ]]; then
        sw_vers
    else
        lsb_release -a
    fi
}

fb() {
    # Git branch switcher using fzf
    local branch
    branch=$(git branch --all | fzf --height 40% \
        --preview 'git log --oneline --color=always {-1}' | \
        sed 's/^[* ]*//' | sed 's|remotes/origin/||')
    [ -n "$branch" ] && git checkout "$branch"
}

db() {
    # Git branch deleter using fzf
    git branch |
        grep --invert-match '\*' |
        cut -c 3- |
        fzf --multi --preview="git log {} --" |
        xargs --no-run-if-empty git branch --delete --force
}

cl() {
    # Git commit log viewer using fzf
    git log --oneline --color=always | \
        fzf --ansi --preview 'git show --color=always {1}' \
            --bind 'enter:execute(git show --color=always {1} | less -R)'
}

bhelp() {
    # Help viewer using bat
    "$@" --help 2>&1 | bat --plain --language=help
}

# ── COMPLETIONS ───────────────────────────────────────────────────────────────

# @ref https://github.com/scop/bash-completion
if [ -d "/opt/homebrew/etc/bash_completion.d" ]; then
    export BASH_COMPLETION_COMPAT_DIR=/opt/homebrew/etc/bash_completion.d
elif [ -d "/usr/local/etc/bash_completion.d" ]; then
    export BASH_COMPLETION_COMPAT_DIR=/usr/local/etc/bash_completion.d
fi
# shellcheck disable=SC1091
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"
# shellcheck disable=SC1091
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

# ── LOCAL OVERRIDES ───────────────────────────────────────────────────────────

# shellcheck disable=SC1091
[ -r ~/.bashrc_local ] && source "$HOME/.bashrc_local"
