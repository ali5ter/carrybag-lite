# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CarryBag Lite is a portable bash shell environment configuration system. Unlike the original CarryBag, this version
uses a single-file approach: "one file, no fuss, less mess."

**Supported platforms:** macOS (Mojave 10.14+, Tahoe) and Debian-based Linux (Bookworm/Trixie, Raspberry Pi OS)

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
4. Tool installations (Starship prompt, fzf, Nerd Fonts)
5. Links bash_profile to appropriate location
6. Configures Claude Code settings and user-level coding standards
7. Configures Codex CLI (symlinks shared principles as `~/.codex/AGENTS.md`)

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

Refactored in v1.5.0 into nine clearly labelled sections using `# ── NAME ──` separators:

1. **PATHS:** Homebrew detection for Intel (`/usr/local`) and Apple Silicon (`/opt/homebrew`)
2. **SHELL OPTIONS:** `shopt -s checkwinsize dotglob histappend cdspell`; history sizing
3. **ENVIRONMENT:** `CDATE`, `CLICOLOR`, vi mode, `EDITOR`, `GIT_EDITOR`
4. **PACKAGE MANAGER:** Homebrew (macOS) or apt (Linux) daily update logic
5. **TOOL SETUP:** bat/MANPAGER, zoxide, nvm, pyenv, Starship, fzf (Ctrl-r history search)
6. **ALIASES:** Safety aliases (rm/cp/mv), platform-conditional utilities (uuidgen/datestamp),
   git shortcuts, bat/batcat, claudeit, Linux dircolors
7. **FUNCTIONS:** `ostype()`, `fb()` (branch switcher), `db()` (branch deleter), `cl()` (commit log), `bhelp()` (help viewer)
8. **COMPLETIONS:** Shell completion configurations
9. **LOCAL OVERRIDES:** Sources `~/.bashrc_local` if present

### bootstrap/install.sh Functions

- **`src_dir()`:** Returns `~/Documents/projects` (macOS) or `~/src` (Linux)
- **`install()`:** Unified wrapper for `brew install` or `apt install`
- **`install_pyenv()`:** Python setup with 15+ build dependencies on Linux
- **`install_ai_tools()`:** Installs Claude Code, Gemini CLI, and Codex CLI on both platforms
  (renamed from `install_claude_code()` in v1.4.0; Linux uses npm for gemini-cli and codex)
- **`bootstrap_mac()`:** ~30 packages including GUI apps (iTerm2, 1Password, Figma, VSCode)
- **`bootstrap_linux()`:** Core packages plus `nodejs`/`npm`, `btop`, `ncdu`; RPi-aware
- **`config_ssh()`:** SSH configuration setup — idempotent, called from `main()`
- **`remote_management()`:** Sets up `rpi-connect-lite` for remote Pi access
- **`install_nerd_fonts()`:** Brew cask (macOS) vs manual download (Linux)
- **`config_claude_code()`:** Symlinks Claude Code configuration from `claude/` directory to `~/.claude/`
- **`config_codex()`:** Delegates to `codex/install.sh` to set up Codex CLI configuration

### Migration Tool (migrate.sh)

Two transfer methods available:

- **`transfer_using_cpio()`:** Lower-level transfer
- **`transfer_using_rsync()`:** Default, with retry logic and progress display

Uses pfb for formatted output. Predefined migration paths can be edited to customize.

### External Dependencies Auto-Downloaded

- `~/.pyenv/` - Python version manager
- `~/.nvm/` - Node version manager
- `~/.config/starship.toml` - Starship prompt config
- `~/.fonts/` - Nerd Fonts (Linux only)

### Claude Code Configuration

The `claude/` directory contains Claude Code settings that get symlinked to `~/.claude/` during bootstrap:

- **`CLAUDE.md`:** User-level coding standards (loaded automatically by Claude Code — no hooks needed). Contains 7
  principles: Codify Don't Document, Bash UX with pfb, Markdown Standards, Professional Documentation Tone, Version
  Control Everything, Fail Fast Pivot Early, and Behavioral Integrity.
- **`settings.json`:** Claude Code preferences (statusLine, alwaysThinkingEnabled, skipDangerousModePermissionPrompt)
- **`statusline-command.sh`:** Custom statusline showing hostname, directory, git branch, model, and usage %
- **`install.sh`:** Installation script with timestamped backup mechanism
- **`README.md`:** Documentation for the Claude Code configuration component

Installation handled by `config_claude_code()` in `bootstrap/install.sh`:

- Creates backups of existing files (`.backup.YYYYMMDDHHMMSS` suffix)
- Symlinks each file from `claude/` to `~/.claude/`
- Idempotent - can be run multiple times safely
- Uses pfb for formatted output consistent with carrybag-lite conventions

**Note:** Development principles are loaded via `~/.claude/CLAUDE.md` (Claude Code's built-in
user-level instruction file), not via hooks. This provides zero-latency, zero-token-cost loading.

### Codex CLI Configuration

The `codex/` directory contains the Codex CLI installer:

- **`install.sh`:** Standalone installer that symlinks `claude/CLAUDE.md` → `~/.codex/AGENTS.md`

This means both Claude Code and Codex CLI share the same development principles from a single source
file (`claude/CLAUDE.md`). No separate principles document is maintained for Codex CLI.

Installation handled by `config_codex()` in `bootstrap/install.sh`, which delegates entirely to
`codex/install.sh`. Run standalone with:

```bash
./codex/install.sh
```

## Important Configuration Details

### Homebrew GitHub API Token (Optional)

To avoid rate limiting during `brew update`:

```bash
echo "your_github_token" > ~/.config/homebrew_github_api_token
```

Token is read and exported as `HOMEBREW_GITHUB_API_TOKEN` in bash_profile.

### pyenv Installation

Sets Python 3.10.0 as global default, installs Python 2.7.18 for legacy support. On Linux, requires extensive build
dependencies (libssl-dev, zlib1g-dev, libffi-dev, etc.).

### Raspberry Pi Specifics

- Uses `apt full-upgrade` instead of `apt upgrade`
- Firmware updates via `rpi_firmware_update()` function (runs `rpi-update` and reboots)
- Remote management via `rpi-connect-lite` with `loginctl enable-linger`
- Banner script displays hostname (figlet), IP address, uptime on login

### ShellCheck Directives

Common suppressions in the codebase:

- `SC1091` - Ignore unreadable sourced files (external scripts)
- `SC2034` - Unused variables (intentional exports or reserved names)
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

## Current Status and Next Work

As of v1.7.0 (2026-04-16), all open issues from the cross-platform audit are resolved:

### Resolved (v1.4.0)

- **#17:** `fd`/`fdfind` mismatch — aliased `fdfind` to `fd` on Linux
- **#18:** `bat`/`batcat` — resolved at startup via `type -P`; no static alias needed
- **#19:** `pbcopy` aliases — wrapped in macOS-only conditional
- **#20:** nvm on Linux — standard `$NVM_DIR` source paths added
- **#21:** `claude-code` double-install on macOS — removed from `bootstrap_mac()`
- **#22:** AI tools on Linux — `gemini-cli` and `codex` installed via npm; `nodejs`/`npm` added to `bootstrap_linux()`;
  function renamed to `install_ai_tools()`
- **#23:** `btop` and `ncdu` added to `bootstrap_linux()`
- **#24:** `config_ssh()` added to `main()` and verified idempotent

### Resolved (v1.5.0)

- **#25:** `bash_profile` refactored into nine named sections with consistent `# ── NAME ──` separators

### Resolved (v1.6.0)

- `bash_profile`: added `bat`/MANPAGER setup, `bhelp()` function, `--line-range` for fzf preview;
  simplified `claudeit` alias; removed stray unconditional source line
- `CLAUDE.md`: corrected bash_profile section descriptions to match actual content

### Resolved (v1.6.1)

- `claude/CLAUDE.md`: added Python specific scripting standards block under Codify, Don't Document principle

### Resolved (v1.6.2)

- `claude/CLAUDE.md`: added author attribution guidance — derive from `git config user.name`/`user.email`,
  format as `Name <email>`

### Resolved (v1.7.0)

- `bash_profile`: replaced `z.sh` with `zoxide` — uses `type`-guard pattern, no curl download on first source
- `bootstrap/install.sh`: added `zoxide` to both `bootstrap_mac()` and `bootstrap_linux()`

### Closed (Won't Fix)

- **#15:** Docker-based macOS bootstrap testing — not feasible; documented and closed (2026-03-30)
  - Docker-OSX and OSX-KVM both require a Linux host with KVM; neither runs on macOS
  - Spoofing `OSTYPE=darwin` in a Linux container covers almost nothing: `bootstrap_mac()` is
    entirely Homebrew calls that fail without macOS
  - The shared non-Homebrew functions (`config_ssh`, `config_carrybag`, etc.) already exercise
    their Linux paths via `test_rpi.sh`
  - No partial test provides meaningful macOS-specific coverage

### Possible Future Work

- Add `nmap` to Linux bootstrap for network tool parity with macOS
- Monitor whether apt `nodejs` is sufficient for gemini-cli/codex on Raspberry Pi OS;
  may need NodeSource or nvm-based install if apt version is too old

## Platform-Specific Path Conventions

| Purpose | macOS | Linux |
| ------- | ----- | ----- |
| Projects | `~/Documents/projects` | `~/src` |
| Shell config | `~/.bash_profile` | `~/.bashrc` → `~/.bash_profile` |
| Homebrew | `/opt/homebrew` (AS) or `/usr/local` (Intel) | N/A |
| Fonts | System | `~/.fonts` |
| Claude Code | `~/.claude/` | `~/.claude/` |
| Codex CLI | `~/.codex/` | `~/.codex/` |

## Repository Structure

```text
carrybag-lite/
├── bash_profile              # Single-file bash configuration
├── bootstrap/
│   ├── install.sh           # Main bootstrap orchestrator
│   ├── migrate.sh           # Machine-to-machine migration tool
│   └── pfb/                 # Git submodule for formatted output
├── claude/                  # Claude Code configuration
│   ├── CLAUDE.md            # User-level coding standards (7 principles, shared with Codex)
│   ├── settings.json        # Claude Code preferences
│   ├── statusline-command.sh # Git status display
│   ├── install.sh           # Installation script
│   └── README.md            # Component documentation
├── codex/                   # Codex CLI configuration
│   └── install.sh           # Symlinks claude/CLAUDE.md → ~/.codex/AGENTS.md
├── tools/
│   ├── sync.sh              # Local backup/sync utility (with --port, --key SSH options)
│   ├── update.sh            # Bulk git repository updater (with --parallel flag)
│   └── README.md            # Tool reference documentation
├── test_rpi.sh              # Docker-based Raspberry Pi testing
├── CLAUDE.md                # This file - AI project context
└── README.md                # User-facing documentation
```
