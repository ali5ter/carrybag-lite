# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CarryBag Lite is a portable bash shell environment configuration system. Unlike the original CarryBag, this version uses a single-file approach: "one file, no fuss, less mess."

**Supported platforms:** macOS (Mojave 10.14+, Sequoia 15.5) and Debian-based Linux (Bookworm, Raspberry Pi OS)

## Core Architecture

### Single-File Configuration Pattern
All bash configuration lives in `bash_profile` (~215 lines):
- Consolidated aliases, functions, prompts, environment setup
- Platform-specific logic via `[[ "$OSTYPE" == "darwin"* ]]` conditionals
- Optional local overrides sourced from `~/.bashrc_local` at end
- No complex directory structures or modular sourcing

### Installation Strategy
Different symlink patterns by platform:
- **macOS:** `~/.bash_profile` → `bash_profile`
- **Linux:** `~/.bashrc` → `bash_profile`, then `~/.bash_profile` → `~/.bashrc`

Handled by `config_carrybag()` in `bootstrap/install.sh`.

### Bootstrap System
`bootstrap/install.sh` orchestrates full system setup:
1. Installs [pfb](https://github.com/ali5ter/pfb) for formatted terminal output (required dependency)
2. Platform-specific package installation (`bootstrap_mac()` vs `bootstrap_linux()`)
3. Interactive prompts for optional components (pyenv, Docker)
4. Tool installations (Starship prompt, hstr, Nerd Fonts)
5. Links bash_profile to appropriate location
6. Configures Claude Code settings and development principles

Functions are modular and can be sourced/tested individually:
```bash
source bootstrap/install.sh
install_starship  # Test individual function
```

### Platform Detection Pattern
Standard pattern used throughout codebase:
```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS-specific code
else
    # Linux-specific (assumes Debian/Ubuntu with apt)
fi
```

Raspberry Pi detection: Check for `/etc/rpi-issue` file existence.

### Automatic Daily Updates
Both `bash_profile` and `bootstrap/install.sh` implement once-daily package updates:
- **macOS:** Checks `~/.last_brew_update`, runs `brew_update()` if date differs
- **Linux:** Checks `~/.last_apt_update`, runs `apt_update()` if date differs
- Date format: `CDATE=$(date '+%Y%m%d')`
- Raspberry Pi uses `apt full-upgrade` instead of `apt upgrade`

## Development Commands

### Testing bash_profile Changes
```bash
# Check syntax
bash -n bash_profile

# Run shellcheck
shellcheck bash_profile

# Test by sourcing
. bash_profile
# or use the alias
source_
```

### Testing Bootstrap in Isolation
Run full install in Docker container simulating Raspberry Pi OS:
```bash
./test_rpi.sh
```
Uses `debian:stable` with `--platform linux/arm64`, mounts repo at `/root/src/carrybag-lite`.

### Pre-requisites for macOS
```bash
brew install bash  # Install latest bash
chsh -s $(brew --prefix)/bin/bash  # Set as default shell
```

### Manual Installation
```bash
# Backup existing config
cp ~/.bash_profile ~/.bash_profile.$(date +"%Y%m%d%H%M%S")

# Link to carrybag-lite
ln -sf $PWD/bash_profile ~/.bash_profile
```

### Running Full Bootstrap
```bash
./bootstrap/install.sh
```
Interactive prompts will ask about optional components.

### Machine Migration
Transfer configurations and files from old machine to new:
```bash
./bootstrap/migrate.sh <username> <FQDN_or_IP>
```
- Generates SSH key if needed and copies to remote
- Prompts for each path to migrate (~/bin, ~/Documents/Projects/Personal, etc.)
- Uses rsync with infinite retry loop for large transfers
- 30-minute SSH keepalive (`CON_ALIVE=1800`)

### Local Backup/Sync
Sync home directory to external drive:
```bash
./tools/sync
# or with custom paths
./tools/sync /source/path /target/path
```
Defaults to `$HOME/` → `/Volumes/Lacie/$HOSTNAME/` on macOS.

## Key Components & Integration Points

### bash_profile Structure
Organized into sections:
1. **Paths:** Homebrew detection for Intel (`/usr/local`) and Apple Silicon (`/opt/homebrew`)
2. **Shell options:** `shopt -s checkwinsize dotglob histappend cdspell`
3. **OS-specific:** Touch ID for sudo (macOS), banner script (Linux)
4. **External tools:** z.sh (directory jumper), nvm (Node), pyenv (Python)
5. **Starship prompt:** Config at `~/.config/starship.toml`
6. **hstr:** Enhanced history with Ctrl-r binding
7. **Custom functions:** `ostype()`, `cwc()` (crossword lookup), `colors()`

### bootstrap/install.sh Functions
- **`src_dir()`:** Returns `~/Documents/projects` (macOS) or `~/src` (Linux)
- **`install()`:** Unified wrapper for `brew install` or `apt install`
- **`install_pyenv()`:** Python setup with 15+ build dependencies on Linux
- **`bootstrap_mac()`:** ~30 packages including GUI apps (iTerm2, 1Password, Figma, VSCode)
- **`bootstrap_linux()`:** Minimal package set, RPi-aware
- **`remote_management()`:** Sets up `rpi-connect-lite` for remote Pi access
- **`install_nerd_fonts()`:** Brew cask (macOS) vs manual download (Linux)
- **`config_claude_code()`:** Symlinks Claude Code configuration from `claude/` directory to `~/.claude/`

### Migration Tool (migrate.sh)
Two transfer methods available:
- **`transfer_using_cpio()`:** Lower-level transfer
- **`transfer_using_rsync()`:** Default, with retry logic and progress display

Predefined migration paths in `main()` can be edited to customize.

### External Dependencies Auto-Downloaded
- `~/.z.sh` - Directory jumper (downloaded on first bash_profile source)
- `~/.pyenv/` - Python version manager
- `~/.nvm/` - Node version manager
- `~/.config/starship.toml` - Starship prompt config
- `~/.fonts/` - Nerd Fonts (Linux only)

### Claude Code Configuration
The `claude/` directory contains Claude Code settings that get symlinked to `~/.claude/` during bootstrap:
- **`settings.json`:** Claude Code settings with SessionStart hook to load development principles
- **`development-principles.md`:** Global coding standards and best practices
- **`statusline-command.sh`:** Custom statusline showing git branch and status
- **`install.sh`:** Installation script with timestamped backup mechanism
- **`README.md`:** Documentation for the Claude Code configuration component

Installation handled by `config_claude_code()` in `bootstrap/install.sh`:
- Creates backups of existing files (`.backup.YYYYMMDDHHMMSS` suffix)
- Symlinks each file from `claude/` to `~/.claude/`
- Idempotent - can be run multiple times safely
- Uses pfb for formatted output consistent with carrybag-lite conventions

## Important Configuration Details

### Homebrew GitHub API Token (Optional)
To avoid rate limiting during `brew update`:
```bash
echo "your_github_token" > ~/.config/homebrew_github_api_token
```
Token is read and exported as `HOMEBREW_GITHUB_API_TOKEN` in bash_profile.

### pyenv Installation
Sets Python 3.10.0 as global default, installs Python 2.7.18 for legacy support. On Linux, requires extensive build dependencies (libssl-dev, zlib1g-dev, libffi-dev, etc.).

### Raspberry Pi Specifics
- Uses `apt full-upgrade` instead of `apt upgrade`
- Firmware updates via `rpi_firmware_update()` function (runs `rpi-update` and reboots)
- Remote management via `rpi-connect-lite` with `loginctl enable-linger`
- Banner script displays hostname (figlet), IP address, uptime on login

### ShellCheck Directives
Common suppressions in the codebase:
- `SC1091` - Ignore unreadable sourced files (external scripts)
- `SC2034` - Unused variables (e.g., `_Z_CMD` for z.sh)
- `SC2086` - Intentional word splitting for token expansion

## Adding New Tools

Pattern to follow in bash_profile:
```bash
# Check if tool exists before configuring
type <tool> >/dev/null 2>&1 && {
    # Tool-specific aliases/environment
    export TOOL_CONFIG=value
    alias toolcmd='...'
}
```

Add installation to appropriate function in `bootstrap/install.sh`:
- `bootstrap_mac()` for macOS packages
- `bootstrap_linux()` for Linux packages

## Platform-Specific Path Conventions

| Purpose | macOS | Linux |
|---------|-------|-------|
| Projects | `~/Documents/projects` | `~/src` |
| Shell config | `~/.bash_profile` | `~/.bashrc` → `~/.bash_profile` |
| Homebrew | `/opt/homebrew` (AS) or `/usr/local` (Intel) | N/A |
| Fonts | System | `~/.fonts` |
| Claude Code | `~/.claude/` | `~/.claude/` |

## Repository Structure

```
carrybag-lite/
├── bash_profile              # Single-file bash configuration
├── bootstrap/
│   ├── install.sh           # Main bootstrap orchestrator
│   ├── migrate.sh           # Machine-to-machine migration tool
│   └── pfb/                 # Git submodule for formatted output
├── claude/                  # Claude Code configuration (NEW)
│   ├── settings.json        # Claude Code settings with SessionStart hook
│   ├── development-principles.md  # Coding standards
│   ├── statusline-command.sh      # Git status display
│   ├── install.sh           # Installation script
│   └── README.md            # Component documentation
├── tools/
│   └── sync                 # Local backup/sync utility
├── test_rpi.sh              # Docker-based Raspberry Pi testing
├── CLAUDE.md                # This file - AI project context
└── README.md                # User-facing documentation
```
