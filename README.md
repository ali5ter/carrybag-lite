# CarryBag Lite

```text
  ___                   ___              _    _ _
 / __|__ _ _ _ _ _ _  _| _ ) __ _ __ _  | |  (_) |_ ___
| (__/ _` | '_| '_| || | _ \/ _` / _` | | |__| |  _/ -_)
 \___\__,_|_| |_|  \_, |___/\__,_\__, | |____|_|\__\___|
                   |__/          |___/
```

**CarryBag is my collection of dot files, custom functions and theme settings
used to create a bash shell environment I can carry from machine to machine.**

One file, no fuss, less mess.

Tested on macOS Tahoe and Debian-based Linux (Bookworm/Trixie), including Raspberry Pi OS.

## Features

- ✨ Single-file configuration (`bash_profile`)
- 🚀 Automated bootstrap for macOS and Debian-based Linux
- 🐍 Python version management (pyenv)
- 📦 Node version management (nvm)
- ⭐ Starship prompt with custom themes
- 📁 Directory jumper (z.sh)
- 🔍 History search via fzf (Ctrl-R)
- 🎨 Syntax highlighting (bat)
- 🔄 Automatic daily package updates
- 🤖 AI tools: Claude Code, Gemini CLI, and Codex CLI (with shared coding standards)

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

This repository includes the **pfb** prompt framework as a Git submodule
under `bootstrap/pfb`. Initialise submodules before running the bootstrap
installer:

```bash
git submodule update --init --recursive
```

Or clone in one step:

```bash
git clone --recursive https://github.com/ali5ter/carrybag-lite.git ~/src/carrybag-lite
```

## What Gets Installed

**Common (macOS and Linux):**

- `git`, `vim`, `shellcheck`, `watch`
- `jq`, `yq`, `bat`, `tree`, `fzf`, `figlet`
- `starship` (prompt), `fzf` (history + fuzzy search), `z` (directory jumper)
- Nerd Fonts, Claude Code

**macOS only:**

- `bash` (latest), `bash-completion`, `node`, `go`
- `btop`, `ncdu`, `nmap`, `wakeonlan`
- GUI apps: iTerm2, Visual Studio Code, Figma, 1Password, Dropbox, CleanMyMac

**Linux only:**

- `curl`, `wget`, `gnupg`, `fontconfig`, `nodejs`, `npm`
- `btop`, `ncdu` (system monitoring)
- `gemini-cli`, `codex` (AI tools, installed via npm)
- ufw firewall configuration
- Login banner with hostname and system info

**Raspberry Pi extras:**

- `rpi-connect-lite` (remote management)
- Ethernet-over-WiFi priority configuration

**Optional (prompted during bootstrap):**

- `pyenv` (Python version management)
- `docker`

## Additional Tools

### Machine Migration

Transfer configurations from old machine to new:

```bash
./bootstrap/migrate.sh <username> <remote-host>
```

### Bulk Git Repository Updates

Update all git repositories in a directory in one pass, with optional parallel
mode (`--parallel`). See [tools/README.md](tools/README.md) for full details.

### Local and Remote Sync

Sync a directory to a local drive or a remote host over SSH, with custom port
and key support (`--port`, `--key`). See [tools/README.md](tools/README.md)
for full details.

## Testing in a Raspberry Pi–like Docker Container

Test the bootstrap process inside a simulated Raspberry Pi ARM64 environment:

```bash
./test_rpi.sh
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

## Customization

Add personal overrides without modifying `bash_profile`:

```bash
# Create local overrides file
echo "alias myalias='echo hello'" >> ~/.bashrc_local
```

The `bash_profile` automatically sources `~/.bashrc_local` if it exists.

## Documentation

See [tools/README.md](tools/README.md) for the utility script reference.

## License

MIT
