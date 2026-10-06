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

Tested on macOS Golden Gate (27.0.1) and Debian-based Linux (Bookworm/Trixie), including Raspberry Pi OS.

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
- 🤖 AI tools: Claude Code, Antigravity CLI (agy), and Codex CLI — sharing the same standards and skills

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

This installs all dependencies (including pfb), links configuration, and sets up tools. It works from a
fresh Mac: it loads Homebrew into the running shell, and re-runs itself under Homebrew bash because the
system bash (3.2) is too old for pfb. On macOS it also offers to make Homebrew bash your login shell.
When it finishes, open a new terminal window (or run `exec bash -l`) to load the new configuration.

### Option 2: Manual Install

For macOS, install latest bash first:

```bash
brew install bash
echo "$(brew --prefix)/bin/bash" | sudo tee -a /etc/shells
chsh -s "$(brew --prefix)/bin/bash"
```

Then link the configuration:

```bash
cp ~/.bash_profile ~/.bash_profile.$(date +"%Y%m%d%H%M%S")
ln -sf $PWD/bash_profile ~/.bash_profile
```

Then open a new terminal window to load it.

## What Gets Installed

**Common (macOS and Linux):**

- `git`, `vim`, `shellcheck`, `watch`
- `jq`, `yq`, `bat`, `fd`, `tree`, `fzf`, `figlet`, `cfonts`, `glow`
- `btop`, `ncdu` (system monitoring), `wakeonlan`
- `starship` (prompt), `fzf` (history + fuzzy search), `zoxide` (directory jumper)
- Nerd Fonts
- `ruff` and `markdownlint-cli` (used by the Claude Code `verify-edit.sh` hook)

**macOS only:**

- `bash` (latest), `bash-completion`, `node`, `go`, `nmap`
- GUI apps: iTerm2, Visual Studio Code, 1Password, Dropbox
- [pfb](https://github.com/ali5ter/pfb) from the `ali5ter/tap` Homebrew tap

**Linux only:**

- `curl`, `wget`, `gnupg`, `fontconfig`, `nodejs`, `npm`
- Claude Code and `codex` (AI tools; `codex` via npm; Antigravity CLI Linux install TBD)
- pfb via its curl installer
- ufw firewall configuration
- Login banner with hostname and system info

**Raspberry Pi extras:**

- `rpi-connect-lite` (remote management)
- Ethernet-over-WiFi priority configuration

**Optional (prompted during bootstrap):**

- `pyenv` (Python version management)
- `docker`
- Claude Code, Codex, and Antigravity context files and skills, asked about separately (default yes if
  the tool is installed)
- Symlinks for `tools/update.sh` and `tools/status.sh` in `~/Documents/Projects` and `~/src`, whichever
  of them exist (neither is created)
- macOS apps, asked about one at a time (default no): Figma, CleanMyMac, WhatsApp, Microsoft Teams,
  Claude, Claude Code, Codex, and Antigravity CLI

## AI Tools Configuration

The bootstrap installs Claude Code, Antigravity CLI (agy), and Codex CLI, and wires up
shared development standards and skills so all three tools operate from the same principles.

### Shared development standards

`claude/CLAUDE.md` is the single source of truth for coding standards and project conventions.
It is automatically loaded by Claude Code as the user-level instruction file. The same file is
shared with Codex CLI and Antigravity CLI via symlinks so all AI tools enforce the same standards.
Skills defined in `~/.claude/skills/` are also linked into each tool's skills directory
so the same skills are available across all three tools.

| Tool | Config location | Source |
| --- | --- | --- |
| Claude Code | `~/.claude/CLAUDE.md` | symlinked from `claude/CLAUDE.md` |
| Codex CLI | `~/.codex/AGENTS.md` | symlinked from `claude/CLAUDE.md` |
| Antigravity CLI | `~/.gemini/config/AGENTS.md` | symlinked from `claude/CLAUDE.md` |

| Tool | Skills location | Source |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<skill>/` | symlinked from `claude/skills/` |
| Codex CLI | `~/.codex/skills/<skill>/` | symlinked from `~/.claude/skills/` |
| Antigravity CLI | `~/.gemini/config/skills/<skill>/` | symlinked from `~/.claude/skills/` |

`CLAUDE.md` is loaded into every session, so it deliberately holds only guidance that applies
every time. Language-specific conventions live in `claude/skills/` and are loaded on demand:
`bash-standards`, `python-standards`, `go-standards`, and `node-ts-standards`.

### Claude Code

The full `claude/` directory is symlinked to `~/.claude/` during bootstrap, providing:

- **`CLAUDE.md`** — development principles loaded automatically into every session
- **`settings.json`** — preferences including statusline, always-thinking mode, and enabled plugins
- **`statusline-command.sh`** — custom statusline showing hostname, directory, git branch, model,
  color-coded context-window usage, session cost, and Claude plan rate-limit usage (5h/7d)
- **`skills/`** — language standards loaded on demand rather than in every session
- **`hooks/`** — command hooks that enforce standards instead of relying on Claude to remember them:
  lint on edit, the GitHub attribution footer, secret redaction, and git context after compaction
  (see [claude/README.md](claude/README.md))

Enabled plugins (pre-configured in `settings.json`):

- [`claude-workflow-skills`](https://github.com/ali5ter/claude-workflow-skills) — `/promote`,
  `/audit-plugin`, `/audit-standards` workflow skills
- [`tui-ux-tester`](https://github.com/ali5ter/claude-plugins) — UX evaluation of terminal UIs
- [`over-50s-health`](https://github.com/ali5ter/over-50s-health-advisor) — health and fitness advisor
- `github`, `mattpocock-skills` and `frontend-design` from the official plugin marketplace

Plugins are distributed via the `ali5ter` Claude Code plugin marketplace. After bootstrapping,
install them with:

```text
/plugin marketplace add ali5ter/claude-plugins
/plugin install claude-workflow-skills@ali5ter
/plugin install tui-ux-tester@ali5ter
/plugin install over-50s-health@ali5ter
```

### Codex CLI

`codex/install.sh` symlinks `claude/CLAUDE.md` → `~/.codex/AGENTS.md`. Codex reads `AGENTS.md`
as its user-level instruction file, so it operates from the same development principles as Claude
Code without any duplication. It also links each skill directory from `~/.claude/skills/` into
`~/.codex/skills/` so Codex has access to the same skills as Claude Code.

### Antigravity CLI (agy)

`antigravity/install.sh` symlinks `claude/CLAUDE.md` → `~/.gemini/config/AGENTS.md`.
Antigravity CLI (`agy`) is the successor to Gemini CLI and reads `AGENTS.md` from its Global
Customizations Root (`~/.gemini/config/`), applying the same development principles as Claude
Code and Codex. Skills are linked into `~/.gemini/config/skills/`. Note: despite the tool
migrating away from the Gemini CLI brand, `agy` still uses `~/.gemini/` as its home directory.
Install via `brew install --cask antigravity-cli`.

## Additional Tools

The bootstrap offers to symlink `update.sh` and `status.sh` into `~/Documents/Projects` and `~/src`, if
they exist. To do it later, run `./bootstrap/install.sh link_tools`. Any single component can be run the
same way, for example `./bootstrap/install.sh config_codex`.

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
