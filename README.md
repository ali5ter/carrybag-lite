
                             |                 |    o|         
    ,---.,---.,---.,---.,   .|---.,---.,---.   |    .|--- ,---.
    |    ,---||    |    |   ||   |,---||   |---|    ||    |---'
    `---'`---^`    `    `---|`---'`---^`---|   `---'``---'`---'
                        `---'          `---'                   

# CarryBag Lite
**CarryBag is my collection of dot files, custom functions and theme settings 
used to create a bash shell environment I can carry from machine to machine.**

Unlike [the original](https://github.com/ali5ter/carrybag), this version is pared back. One file, no fuss, less mess.

Tested on macOS Mojave (v10.14.6).

# Install
Move your existing runcom aside and link to this one...

    cp ~/.bash_profile ~/.bash_profile.$(date +"%Y%m%d%H%M%S")
    ln -sf $PWD/bash_profile ~/.bash_profile