#!/usr/bin/env bash

# Options
# https://www.computerhope.com/unix/bash/shopt.htm
shopt -s checkwinsize   # check the window size after each command
shopt -s dotglob        # include file names beginning with a '.' in pathnames
shopt -s histappend     # append history instead of overwriting it
shopt -s cdspell        # corrected minor spelling errors during cd
# https://www.linuxjournal.com/content/using-bash-history-more-efficiently-histcontrol
HISTCONTROL=ignoreboth
CDATE=$(date '+%Y%m%d')

# OS specific settings (perhaps check for platform before applything)
# Turn on Touch ID for sudo auth
# https://sixcolors.com/post/2020/11/quick-tip-enable-touch-id-for-sudo/
# sudo echo 'auth sufficient pam_tid.so' >> /etc/pam.d/sudo

# Colors
# shellcheck disable=SC1090
[ -f ~/.colors.bash ] || curl -s -o ~/.colors.bash https://raw.githubusercontent.com/Bash-it/bash-it/master/themes/colors.theme.bash
# shellcheck disable=SC1090
source ~/.colors.bash

# Bookmarking
[ -f ~/.jump.sh ] || curl -s -o ~/.jump.sh https://raw.githubusercontent.com/ali5ter/jump/master/jump.sh
# shellcheck disable=SC1090
source ~/.jump.sh

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
# https://opensource.com/article/19/5/python-3-default-mac
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi
PATH="$(pyenv root)/shims:$PATH"

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
alias more=bat
alias less=bat
alias k=kubectl
alias mk=minikube

# Completion
# https://kubernetes.io/docs/tasks/tools/install-kubectl/#optional-kubectl-configurations
export BASH_COMPLETION_COMPAT_DIR=/usr/local/etc/bash_completion.d
# shellcheck disable=SC1091
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
# shellcheck disable=SC1091
source /Users/bowena/Documents/Projects/VMware/DX/cli_taxo/exp4/results/velero_completion.sh
# shellcheck disable=SC1090
source <(kubectl completion bash)
complete -F __start_kubectl k
# shellcheck disable=SC1090
source <(minikube completion bash)
complete -F __start_minikube mk

# Functions

kubeconf() {
    # Merge all kubeconfig files in ~/.kube into KUBECONFIG
    # https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
    local confs=''
    for file in ~/.kube/*config*; do
        confs="${confs}$file:";
    done
    export KUBECONFIG="$confs"
    env | grep KUBECONFIG
}
kubeconf >/dev/null

brew_update() {
    # Additional homebrew housekeeping
    brew update && brew upgrade && brew cleanup; 
}
# Automate homebrew update
# TODO: Check for OS before applying Darwin specific stuff
UPDATE_DATE="$HOME/.last_update"
[ -f "$UPDATE_DATE" ] || echo "00" > "$UPDATE_DATE"
if [ "$CDATE" != "$(head -n 1 "$UPDATE_DATE")" ]; then
    echo "$CDATE" > "$UPDATE_DATE"
    # shellcheck disable=SC2154
    echo -e "Checking homebrew..."
    brew_update
fi

vmw_whois() {
    # VMware specific whois
    # TODO: Migrate to seperate tool under vmware scripts
    local name="$*"
    #ref https://source.vmware.com/portal/search/people?q=alister&aq=(@cnbd%3D%22alister%22%20OR%20@ucnbd%3D%22alister%22)&client=InternalPeopleSearch&Tab=vmwarepeople&start=0&num=20&sid=1606940050&allPeople=true
    local url_base='https://source.vmware.com/portal/search/people?'
    local url_query_attributes="client=InternalPeopleSearch&Tab=vmwarepeople&start=0&num=20&sid=1606938064&allPeople=true"
    name="${name//+([[:space:]])/%20}"
    local url_query="q=${name}&aq=(@cnbd%3D%22${name}%22%20OR%20@ucnbd%3D%22${name}%22)"
    open "${url_base}${url_query}&${url_query_attributes}"
}

# Prompts
# https://github.com/justjanne/powerline-go
function _update_ps1() {
    # shellcheck disable=SC2046
    PS1="$(powerline-go \
        -newline \
        -modules "venv,user,host,kube,ssh,cwd,perms,git,hg,jobs,exit" \
        -truncate-segment-width 8 \
        -hostname-only-if-ssh \
        -error $? \
        -cwd-max-depth 4 \
        -jobs $(jobs -p | wc -l))"
}
if [[ $TERM != linux && ! $PROMPT_COMMAND =~ _update_ps1 ]]; then
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi
# https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/
# shellcheck disable=SC2154
#DEFAULT_PS1="\n[${red}\u@\h${normal}|${cyan}\W${normal}] "
# PS1="\$(kube_ps1)\n${cyan}§${normal} "
PS2="${cyan}…${normal} "            # continuation
PS4="${cyan}$0.$LINENO ⨠${normal} " # tracing

# History manager
# @ref https://github.com/dvorka/hstr/blob/master/CONFIGURATION.md
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

# Additional configurations/overrides
# shellcheck disable=SC1091
[ -r ~/.bashrc_local ] && source "$HOME/.bashrc_local"