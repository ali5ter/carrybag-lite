
                             |                 |    o|         
    ,---.,---.,---.,---.,   .|---.,---.,---.   |    .|--- ,---.
    |    ,---||    |    |   ||   |,---||   |---|    ||    |---'
    `---'`---^`    `    `---|`---'`---^`---|   `---'``---'`---'
                        `---'          `---'                   

# CarryBag Lite
**CarryBag is my collection of dot files, custom functions and theme settings 
used to create a bash shell environment I can carry from machine to machine.**

Unlike [the original](https://github.com/ali5ter/carrybag), this version is pared back. One file, no fuss, less mess.

Tested on macOS Sequoia (15.5) and Debian Bookwork.

# MacOS Pre-reqs
MacOS comes with an old verion of Bash and defaults to zsh. Use Homebrew to install the latest version of Bash by running:

    brew install bash

If you want to use this file, you need to configure your terminal application to use bash as the default login shell.
Set the default shell to bash by running:

    chsh -s $(brew --prefix)/bin/bash

# Install
Move your existing runcom aside and link to this one...

    cp ~/.bash_profile ~/.bash_profile.$(date +"%Y%m%d%H%M%S")
    ln -sf $PWD/bash_profile ~/.bash_profile