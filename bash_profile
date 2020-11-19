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

# Powerline prompt
function _update_ps1() {
    PS1=$(powerline-shell $?)
}
if [[ $TERM != linux && ! $PROMPT_COMMAND =~ _update_ps1 ]]; then
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi

# K8s prompt
# https://github.com/jonmosco/kube-ps1
# if [ -f "$(brew --prefix)/opt/kube-ps1/share/kube-ps1.sh" ]; then
#     # shellcheck disable=SC2034
#     KUBE_PS1_PREFIX='['
#     # shellcheck disable=SC2034
#     KUBE_PS1_SUFFIX='] '
#     # shellcheck disable=SC2034
#     KUBE_PS1_SEPARATOR=''
#     # shellcheck disable=SC1090
#     source "$(brew --prefix)/opt/kube-ps1/share/kube-ps1.sh"
#     kubeoff
#     # TODO: recover color to default prompt
# fi

# git prompt
# https://github.com/magicmonty/bash-git-prompt
# if [ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]; then
#     # shellcheck disable=SC2034
#     __GIT_PROMPT_DIR=$(brew --prefix)/opt/bash-git-prompt/share
#     # shellcheck disable=SC2034
#     GIT_PROMPT_ONLY_IN_REPO=1
#     # shellcheck disable=SC2034
#     GIT_PROMPT_START_USER="\n\$(kube_ps1)"
#     # shellcheck disable=SC2034
#     GIT_PROMPT_END_USER="\n\[\e[36m\]§\[\e[0m\]\] "
#     # shellcheck disable=SC2034
#     # shellcheck disable=SC2154
#     GIT_PROMPT_BRANCH="${Cyan}"
#     # shellcheck disable=SC2034
#     # shellcheck disable=SC2154
#     GIT_PROMPT_CHANGED="${Yellow}✚ "
#     # shellcheck disable=SC2034
#     # shellcheck disable=SC2154
#     GIT_PROMPT_CLEAN="${BoldGreen}✔"
#     # shellcheck disable=SC1090
#     source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"
#     # TODO: Remove space in 1st column
# fi

# Node version management
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
# shellcheck disable=SC1091
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Paths
export PATH="/usr/local/sbin:$PATH"

# Editors
set -o vi
export EDITOR='vim'
export GIT_EDITOR="$EDITOR"

# Aliases
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

# TODO: Check for OS before applying Darwin specific stuff
brew_update() { brew update && brew upgrade; }

UPDATE_DATE="$HOME/.last_update"
[ -f "$UPDATE_DATE" ] || echo "00" > "$UPDATE_DATE"
if [ "$CDATE" != "$(head -n 1 "$UPDATE_DATE")" ]; then
    echo "$CDATE" > "$UPDATE_DATE"
    # shellcheck disable=SC2154
    echo -e "Checking homebrew..."
    brew_update
fi

# Prompts
# https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/
# shellcheck disable=SC2154
#DEFAULT_PS1="\n[${red}\u@\h${normal}|${cyan}\W${normal}] "
# PS1="\$(kube_ps1)\n${cyan}§${normal} "
PS2="${cyan}…${normal} "            # continuation
PS4="${cyan}$0.$LINENO ⨠${normal} " # tracing

#
# Additional configurations/overrides
# shellcheck disable=SC1090
[ -r ~/.bashrc_local ] && source "$HOME/.bashrc_local"