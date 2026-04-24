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
- 📁 Directory jumper (zoxide)
- 🔍 History search via fzf (Ctrl-R)
- 🎨 Syntax highlighting (bat)
- 🔄 Automatic daily package updates
- 🤖 AI tools: Claude Code, Gemini CLI, and Codex CLI — all sharing the same coding standards from a single source

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

This installs all dependencies (including pfb), links configuration, and sets up tools.

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

## AI Tools Configuration

The bootstrap installs Claude Code, Gemini CLI, and Codex CLI, and wires up shared
development standards so all three tools operate from the same principles.

### Shared development standards

`claude/CLAUDE.md` is the single source of truth for coding standards and project conventions.
It is automatically loaded by Claude Code as the user-level instruction file. The same file is
shared with Codex CLI via a symlink so all AI tools enforce the same standards:

| Tool | Config location | Source |
| --- | --- | --- |
| Claude Code | `~/.claude/CLAUDE.md` | symlinked from `claude/CLAUDE.md` |
| Codex CLI | `~/.codex/AGENTS.md` | symlinked from `claude/CLAUDE.md` |
| Gemini CLI | `~/.gemini/GEMINI.md` | symlinked from `claude/CLAUDE.md` |

### Claude Code

The full `claude/` directory is symlinked to `~/.claude/` during bootstrap, providing:

- **`CLAUDE.md`** — seven development principles loaded automatically into every session
- **`settings.json`** — preferences including statusline, always-thinking mode, and enabled plugins
- **`statusline-command.sh`** — custom statusline showing hostname, directory, git branch, model, and token usage

Enabled plugins (pre-configured in `settings.json`):

- [`claude-workflow-skills`](https://github.com/ali5ter/claude-workflow-skills) — `/promote`,
  `/audit-plugin`, `/audit-standards` workflow skills
- [`obsidian-project-documentation`](https://github.com/ali5ter/obsidian-project-assistant) — automatic
  project documentation in Obsidian
- [`over-50s-health`](https://github.com/ali5ter/over-50s-health-advisor) — health and fitness advisor

Plugins are distributed via the `ali5ter` Claude Code plugin marketplace. After bootstrapping,
install them with:

```text
/plugin marketplace add ali5ter/claude-plugins
/plugin install claude-workflow-skills@ali5ter
/plugin install obsidian-project-documentation@ali5ter
/plugin install over-50s-health@ali5ter
```

### Codex CLI

`codex/install.sh` symlinks `claude/CLAUDE.md` → `~/.codex/AGENTS.md`. Codex reads `AGENTS.md`
as its user-level instruction file, so it operates from the same seven principles as Claude Code
without any duplication.

### Gemini CLI

`gemini/install.sh` symlinks `claude/CLAUDE.md` → `~/.gemini/GEMINI.md`. Gemini CLI reads
`GEMINI.md` as its user-level instruction file (verified with `/memory show` inside a Gemini
session), applying the same seven development principles as Claude Code and Codex.

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

- mount the repo under `/root/src/carrybag-lite`
- install pfb inside the container via the official curl installer
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
