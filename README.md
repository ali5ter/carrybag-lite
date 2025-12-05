# CarryBag Lite

```
  ___                   ___              _    _ _
 / __|__ _ _ _ _ _ _  _| _ ) __ _ __ _  | |  (_) |_ ___
| (__/ _` | '_| '_| || | _ \/ _` / _` | | |__| |  _/ -_)
 \___\__,_|_| |_|  \_, |___/\__,_\__, | |____|_|\__\___|
                   |__/          |___/
```

**CarryBag is my collection of dot files, custom functions and theme settings
used to create a bash shell environment I can carry from machine to machine.**

Unlike [the original](https://github.com/ali5ter/carrybag), this version is
pared back. One file, no fuss, less mess.

Tested on macOS Sequoia (15.7) and Debian Trixie.

## Features

- ✨ Single-file configuration (`bash_profile`)
- 🚀 Automated bootstrap for macOS and Linux/Raspberry Pi
- 🐍 Python version management (pyenv)
- 📦 Node version management (nvm)
- ⭐ Starship prompt with custom themes
- 📁 Directory jumper (z.sh)
- 🔍 Enhanced history search (hstr)
- 🎨 Syntax highlighting (bat)
- 🔄 Automatic daily package updates

## Quick Install

### Option 1: Automated Bootstrap (Recommended)

```bash
# macOS
git clone https://github.com/ali5ter/carrybag-lite.git ~/Documents/projects/carrybag-lite

# Linux
git clone https://github.com/ali5ter/carrybag-lite.git ~/src/carrybag-lite

# Run installer
cd carrybag-lite
./bootstrap/install.sh
```

This installs all dependencies, links configuration, and sets up tools.

### Option 2: Manual Install

For macOS, install latest bash first:

```bash
brew install bash
chsh -s $(brew --prefix)/bin/bash
```

Then link the configuration:

```bash
cp ~/.bash_profile ~/.bash_profile.$(date +"%Y%m%d%H%M%S")
ln -sf $PWD/bash_profile ~/.bash_profile
```

## Submodule: pfb prompt framework

This repository now includes the **pfb** prompt framework as a Git submodule under `bootstrap/pfb`.  
After cloning the repository, be sure to initialize submodules before running the bootstrap installer:

```bash
git submodule update --init --recursive
```

Or clone in one step:

```bash
git clone --recursive https://github.com/ali5ter/carrybag-lite.git ~/src/carrybag-lite
```

## What Gets Installed

**Command-line tools:**
- `bash`, `git`, `vim`, `shellcheck`
- `jq`, `yq`, `bat`, `tree`, `fzf`
- `starship` (prompt), `hstr` (history), `z` (directory jumper)

**Development:**
- `pyenv` (Python version management) - optional
- `nvm` (Node version management)
- `docker` - optional

**macOS GUI apps:**
- iTerm2, Visual Studio Code, Figma
- 1Password, Dropbox, CleanMyMac
- Microsoft Teams, WhatsApp

**Raspberry Pi extras:**
- rpi-connect-lite (remote management)
- Custom banner with system info

## Additional Tools

### Machine Migration

Transfer configurations from old machine to new:

```bash
./bootstrap/migrate.sh <username> <remote-host>
```

## Testing in a Raspberry Pi–like Docker Container

You can test the bootstrap process inside a simulated Raspberry Pi ARM64 environment using:

```bash
./test-raspi.sh
```

This script will:

- initialize the `pfb` submodule automatically  
- mount the repo under `/root/src/carrybag-lite`  
- enable the **pfb** prompt inside the container shell  
- simulate Pi‑style network interfaces (`wlan0`, `eth1`)  
- run `bootstrap/install.sh`  
- keep the container alive for inspection  

To inspect the running container:

```bash
docker exec -it carrybag-test bash
```

To stop and remove the test container:

```bash
docker rm -f carrybag-test
```

### Local Backup

Sync home directory to external drive:

```bash
./tools/sync
```

## Customization

Add personal overrides without modifying `bash_profile`:

```bash
# Create local overrides file
echo "alias myalias='echo hello'" >> ~/.bashrc_local
```

The `bash_profile` automatically sources `~/.bashrc_local` if it exists.

## Documentation

See [CLAUDE.md](CLAUDE.md) for architecture details and development workflows.

## License

MIT
