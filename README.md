# CarryBag Lite

```text
╱╭━━━╮╱╭━━━╮╱╭━━━╮╱╭━━━╮╱╭╮╱╱╭╮╱╭━━╮╱╱╭━━━╮╱╭━━━╮╱╱╱╱╱╱╭╮╱╱╱╱╭━━╮╱╭━━━━╮╱╭━━━╮
╱┃╭━╮┃╱┃╭━╮┃╱┃╭━╮┃╱┃╭━╮┃╱┃╰╮╭╯┃╱┃╭╮┃╱╱┃╭━╮┃╱┃╭━╮┃╱╱╱╱╱╱┃┃╱╱╱╱╰┫┣╯╱┃╭╮╭╮┃╱┃╭━━╯
╱┃┃╱╰╯╱┃┃╱┃┃╱┃╰━╯┃╱┃╰━╯┃╱╰╮╰╯╭╯╱┃╰╯╰╮╱┃┃╱┃┃╱┃┃╱╰╯╱╱╱╱╱╱┃┃╱╱╱╱╱┃┃╱╱╰╯┃┃╰╯╱┃╰━━╮
╱┃┃╱╭╮╱┃╰━╯┃╱┃╭╮╭╯╱┃╭╮╭╯╱╱╰╮╭╯╱╱┃╭━╮┃╱┃╰━╯┃╱┃┃╭━╮╱╭━━╮╱┃┃╱╭╮╱╱┃┃╱╱╱╱┃┃╱╱╱┃╭━━╯
╱┃╰━╯┃╱┃╭━╮┃╱┃┃┃╰╮╱┃┃┃╰╮╱╱╱┃┃╱╱╱┃╰━╯┃╱┃╭━╮┃╱┃╰┻━┃╱╰━━╯╱┃╰━╯┃╱╭┫┣╮╱╱╱┃┃╱╱╱┃╰━━╮
╱╰━━━╯╱╰╯╱╰╯╱╰╯╰━╯╱╰╯╰━╯╱╱╱╰╯╱╱╱╰━━━╯╱╰╯╱╰╯╱╰━━━╯╱╱╱╱╱╱╰━━━╯╱╰━━╯╱╱╱╰╯╱╱╱╰━━━╯
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
- 🤖 AI tools: Claude Code, Antigravity CLI (agy), Codex CLI, and OpenCode — sharing the same standards and skills

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

- `git`, `go`, `nmap`, `vim`, `shellcheck`, `watch`
- `jq`, `yq`, `bat`, `fd`, `tree`, `fzf`, `figlet`, `cfonts`, `glow`
- `btop`, `ncdu` (system monitoring), `wakeonlan`
- `starship` (prompt), `fzf` (history + fuzzy search), `zoxide` (directory jumper)
- Nerd Fonts
- `ruff` and `markdownlint-cli` (used by the Claude Code `verify-edit.sh` hook)

**macOS only:**

- `bash` (latest), `bash-completion`, `node`
- GUI apps: iTerm2, Visual Studio Code, 1Password (incl. CLI), Dropbox
- [pfb](https://github.com/ali5ter/pfb) from the `ali5ter/tap` Homebrew tap

**Linux only:**

- `curl`, `wget`, `gnupg`, `fontconfig`, `nodejs`, `npm`
- Claude Code (via its curl installer) and `codex` (via npm; Antigravity CLI Linux install TBD)
- pfb via its curl installer
- ufw firewall configuration
- Login banner with hostname and system info

**Raspberry Pi extras:**

- `rpi-connect-lite` (remote management)
- Ethernet-over-WiFi priority configuration

**Optional (prompted during bootstrap):**

- `pyenv` (Python version management)
- `docker`
- Claude Code, Codex, Antigravity, and OpenCode context files and skills, asked about separately (default yes if
  the tool is installed)
- Symlinks for `tools/update.sh` and `tools/status.sh` in `~/Documents/Projects` and `~/src`, whichever
  of them exist (neither is created)
- macOS apps, asked about one at a time (default no): Figma, CleanMyMac, WhatsApp, Microsoft Teams,
  Claude, Claude Code, Codex, and Antigravity CLI; plus the `opencode` formula

## AI Tools Configuration

The bootstrap configures the four AI tools — Claude Code, Antigravity CLI (agy),
Codex CLI, and OpenCode — and wires up shared development standards and skills so they
all operate from the same source. OpenCode keeps its own config (see its section below);
the other three read that source from their own config directories.

### Shared development standards

`claude/CLAUDE.md` is the single source of truth for coding standards and project conventions.
It is loaded by Claude Code as its user-level instruction file, and is shared with
Codex CLI, Antigravity CLI, and OpenCode via a symlink to `AGENTS.md`, so every AI tool
enforces the same standards. The two tables below show where each tool reads its standards
and skills; OpenCode's skill population differs (see its section below).

| Harness | Config location | Source |
| --- | --- | --- |
| Claude Code | `~/.claude/CLAUDE.md` | symlinked from `claude/CLAUDE.md` |
| Codex CLI | `~/.codex/AGENTS.md` | symlinked from `claude/CLAUDE.md` |
| Antigravity CLI | `~/.gemini/config/AGENTS.md` | symlinked from `claude/CLAUDE.md` |
| OpenCode | `~/.config/opencode/AGENTS.md` | symlinked from `claude/CLAUDE.md` |

| Harness | Skills location | Source |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<skill>/` | symlinked from `claude/skills/` |
| Codex CLI | `~/.codex/skills/<skill>/` | symlinked from `~/.claude/skills/` |
| Antigravity CLI | `~/.gemini/config/skills/<skill>/` | symlinked from `~/.claude/skills/` |
| OpenCode | `~/.config/opencode/skills/<skill>/` | plugin skills linked from `~/.claude/plugins/cache`; user skills discovered natively |

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
- `github` and `frontend-design` from the official plugin marketplace

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

### OpenCode

OpenCode is a separate AI harness. It shares the same source of truth as the others — `CLAUDE.md` →
`AGENTS.md`, `~/.claude/skills/`, and the Ollama server — but keeps its own config directory and never reads or
modifies another harness's config:

- **Claude Code:** `~/.claude/` — `settings.json`, hooks, marketplace, statusline, `installed_plugins.json`
- **OpenCode:** `~/.config/opencode/` — provider config, agents, commands, MCP, plugins
- **Shared:** `carrybag-lite/claude/CLAUDE.md` (via symlink), `~/.claude/skills/`, skill symlinks in
  `~/.config/opencode/skills/`, Ollama server endpoint

`opencode/install.sh` symlinks `claude/CLAUDE.md` → `~/.config/opencode/AGENTS.md`. OpenCode 2.x does not fall
back to `~/.claude/CLAUDE.md`, so the link is required. User skills in `~/.claude/skills/` are discovered natively;
plugin-installed skills are linked into `~/.config/opencode/skills/`. It then merges a baseline into the global
config, `~/.config/opencode/opencode.json`, with `update: "disable"` and `share: "disabled"`. Keys the script
does not manage survive; whole-line `//` comments are stripped before parsing.

The endpoint is resolved in this order: `LOCAL_ENDPOINT`, then `OLLAMA_HOST`, then `~/.config/ollama_host`, then
`localhost:11434`. When it responds, the installer writes a `providers.ollama` entry (package
`@opencode/ai/providers/openai-compatible`, `settings.baseURL` pointing at the endpoint) listing every model the
server serves, each with its own context and output limits (`OPENCODE_CONTEXT_LIMIT` and `OPENCODE_OUTPUT_LIMIT`,
default 131072 and 32768; context is capped at the model's own architecture limit), plus a default `model`.

The default model is `OPENCODE_LOCAL_MODEL` when the endpoint serves it, otherwise the model the config already used,
otherwise the first in the list. The `providers` block alone enables the local lane — no API key or `/connect` is
needed, so `opencode auth list` showing nothing is expected. No cloud provider is configured, so requests stay
local. Rerun `./opencode/install.sh` after adding models to the server; the `providers` block is rebuilt each time.

`bash_profile` exports `OPENCODE_DISABLE_AUTOUPDATE=1` and `OPENCODE_DISABLE_MODELS_FETCH=1` when `opencode` is
present. Claude Code-specific hooks have no OpenCode event-system equivalent, so OpenCode sessions run without them.
Install via `brew install opencode`.

### Remote Ollama server

To point the `ollama` CLI at a remote Ollama server, put its address in `~/.config/ollama_host`:

```bash
echo '192.168.1.63:11434' > ~/.config/ollama_host
```

`bash_profile` exports it as `OLLAMA_HOST`. With no file, nothing changes, so a machine running its own local Ollama
is unaffected. An `OLLAMA_HOST` already in the environment wins. The file is per-machine and not tracked.

## Additional Tools

The bootstrap offers to symlink `update.sh` and `status.sh` into `~/Documents/Projects` and `~/src`, if
they exist. To do it later, run `./bootstrap/install.sh link_tools`. Any single component can be run the
same way, for example `./bootstrap/install.sh config_codex`.

### Machine Migration

Move a home-directory tree from an old machine to this one over SSH, with an SSH key generated if one is
needed and an rsync retry loop for slow links. See [tools/README.md](tools/README.md) for details and usage.

### Bulk Git Repository Updates

Pull every git repository under a directory in one pass — concurrent by default, skipping any repo with
uncommitted changes or an unreachable remote. See [tools/README.md](tools/README.md) for details.

### Local and Remote Sync

Back up a directory to a local drive or a remote host over SSH, mode auto-detected from whether the target
contains a colon. See [tools/README.md](tools/README.md) for details.

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

Two override files adapt the system to a machine or personal preference without
editing tracked files. Both are gitignored.

### Personal overrides (`~/.bashrc_local`)

Add aliases and functions without modifying `bash_profile`:

```bash
echo "alias myalias='echo hello'" >> ~/.bashrc_local
```

`bash_profile` sources `~/.bashrc_local` at the end of every login shell, if it
exists.

### Machine-specific values (`.env.local`)

The install scripts bake in sensible machine-specific defaults. To override any
of them for a machine, copy the template and edit it:

```bash
cp .env.template .env.local
$EDITOR .env.local
```

The install scripts source `.env.local` on each run; a missing file is
harmless, so a bare install keeps the built-in defaults. The variables:

| Variable | Purpose |
| --- | --- |
| `OLLAMA_SERVER_DEFAULT` | Remote Ollama server `host:port` |
| `OPENCODE_MODEL_DEFAULT` | Preferred OpenCode default model |
| `HINDSIGHT_MCP_URL_DEFAULT` | Hindsight MCP server URL (also read as `HINDSIGHT_URL`) |
| `STARSHIP_HOSTNAME_ALIASES` | Semicolon-separated `host:alias` pairs for the prompt and statusline |

The template's header lists which script consumes each variable and how to
format it, so it is the detailed reference.

## License

MIT
