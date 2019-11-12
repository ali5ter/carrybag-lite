#!/usr/bin/env bash

# Options
# https://www.computerhope.com/unix/bash/shopt.htm
shopt -s checkwinsize   # check the window size after each command
shopt -s dotglob        # include file names beginning with a '.' in pathnames
shopt -s histappend     # append history instead of overwriting it
shopt -s cdspell        # corrected minor spelling errors during cd
# https://www.linuxjournal.com/content/using-bash-history-more-efficiently-histcontrol
HISTCONTROL=ignoreboth

# Colors
# shellcheck disable=SC1090
[ -f ~/.colors.bash ] || curl -s -o ~/.colors.bash https://raw.githubusercontent.com/Bash-it/bash-it/master/themes/colors.theme.bash
# shellcheck disable=SC1090
source ~/.colors.bash

# Bookmarking
[ -f ~/.jump.sh ] || curl -s -o ~/.jump.sh https://raw.githubusercontent.com/ali5ter/jump/master/jump.sh
# shellcheck disable=SC1090
source ~/.jump.sh

# K8s prompt
# https://github.com/jonmosco/kube-ps1
if [ -f "$(brew --prefix)/opt/kube-ps1/share/kube-ps1.sh" ]; then
    # shellcheck disable=SC2034
    KUBE_PS1_PREFIX='['
    # shellcheck disable=SC2034
    KUBE_PS1_SUFFIX='] '
    # shellcheck disable=SC2034
    KUBE_PS1_SEPARATOR=''
    # shellcheck disable=SC1090
    source "$(brew --prefix)/opt/kube-ps1/share/kube-ps1.sh"
    kubeoff
    # TODO: recover color to default prompt
fi

# git prompt
# https://github.com/magicmonty/bash-git-prompt
if [ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]; then
    # shellcheck disable=SC2034
    __GIT_PROMPT_DIR=$(brew --prefix)/opt/bash-git-prompt/share
    # shellcheck disable=SC2034
    GIT_PROMPT_ONLY_IN_REPO=1
    # shellcheck disable=SC2034
    GIT_PROMPT_START_USER="\n\$(kube_ps1)"
    # shellcheck disable=SC2034
    GIT_PROMPT_END_USER="\n\[\e[36m\]§\[\e[0m\]\] "
    # shellcheck disable=SC2034
    # shellcheck disable=SC2154
    GIT_PROMPT_BRANCH="${Cyan}"
    # shellcheck disable=SC2034
    # shellcheck disable=SC2154
    GIT_PROMPT_CHANGED="${Yellow}✚ "
    # shellcheck disable=SC2034
    # shellcheck disable=SC2154
    GIT_PROMPT_CLEAN="${BoldGreen}✔"
    # shellcheck disable=SC1090
    source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"
    # TODO: Remove space in 1st column
fi

# Paths
export PATH="/usr/local/sbin:$PATH"

# Editors
set -o vi
export EDITOR='vim'
export GIT_EDITOR="$EDITOR"

# Aliases
alias uuidgen="\uuidgen | tr [:upper:] [:lower:]"
alias suuidgen="uuidgen | cut -d- -f1"
alias k=kubectl
alias t=tmc
alias mk=minikube

# Completion
# https://kubernetes.io/docs/tasks/tools/install-kubectl/#optional-kubectl-configurations
export BASH_COMPLETION_COMPAT_DIR=/usr/local/etc/bash_completion.d
# shellcheck disable=SC1091
source /usr/local/etc/profile.d/bash_completion.sh
# shellcheck disable=SC1091
source /Users/bowena/Documents/Projects/VMware/DX/cli_taxo/exp4/results/velero_completion.sh
# shellcheck disable=SC1090
source <(kubectl completion bash)
complete -F __start_kubectl k
# shellcheck disable=SC1090
source <(tmc completion bash)
complete -F __start_mctl t
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

# Prompts
# https://www.thegeekstuff.com/2008/09/bash-shell-take-control-of-ps1-ps2-ps3-ps4-and-prompt_command/
# shellcheck disable=SC2154
#DEFAULT_PS1="\n[${red}\u@\h${normal}|${cyan}\W${normal}] "
PS1="\$(kube_ps1)\n${cyan}§${normal} "
PS2="${cyan}…${normal} "            # continuation
PS4="${cyan}$0.$LINENO ⨠${normal} " # tracing