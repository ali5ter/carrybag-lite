# Claude Code Configuration

This directory contains Claude Code configuration files that are symlinked to `~/.claude/`.

## Files

- **CLAUDE.md** - Global development standards applied to all projects (user-level instructions)
- **settings.json** - Claude Code settings and preferences, including hook registrations
- **statusline-command.sh** - Custom status line display script
- **register-hindsight-mcp.sh** - Registers a Hindsight memory server with Claude Code
- **skills/** - Language standards loaded on demand rather than in every session
- **hooks/** - Command hooks that enforce standards that skills only state as guidance

## Hindsight memory server

[Hindsight](https://github.com/vectorize-io/hindsight) is a self-hosted agent memory service. It
exposes a standard HTTP MCP endpoint, so any MCP-capable agent can use it for long-term recall and
reflection — not only Claude Code.

`register-hindsight-mcp.sh` registers it in the **user scope**, making it available to every
project on the machine:

```bash
./claude/register-hindsight-mcp.sh                  # loopback:8888, bank "health"
./claude/register-hindsight-mcp.sh --url http://192.168.1.63:8888 --bank health
./claude/register-hindsight-mcp.sh --remove         # unregister
```

It probes before registering: the endpoint must answer, refuse anonymous callers, and accept the
key. A registration pointing at an unreachable or unauthenticated service is worse than none.

### Where the key comes from

The API key is **never stored in this repo**. The script tries, in order:

1. `HINDSIGHT_API_TENANT_API_KEY` in the environment
2. 1Password, if the `op` CLI is installed — item name from `HINDSIGHT_OP_ITEM`, default
   `Hindsight API key`
3. `~/.config/hindsight/credentials`, which should be `chmod 600`
4. An interactive prompt, when stdin is a terminal

Registration writes the bearer token into `~/.claude.json`. That file is outside this repo and
must never be committed.

### Server side

The server itself is not configured from here. It is set up by the scripts in
[`server-setup/studio/`](https://github.com/ali5ter/server-setup/tree/main/studio), which hold the
install, the launchd service, the import and the recall evaluation. The host restricts the MCP
surface with `HINDSIGHT_API_MCP_ENABLED_TOOLS`, so a client cannot reach a tool the server does not
expose.

The current instance on the Mac Studio binds to `127.0.0.1:8888`, so only agents running on that
machine can reach it. Pass `--url` once it is bound more widely.

Tools appear to agents as `mcp__<name>__<tool>`, for example `mcp__hindsight-health__recall`. Grant
an agent only `recall`, `reflect` and `retain`.

## Skills

`CLAUDE.md` is loaded into every session, so it holds only guidance that applies every time.
Language-specific conventions live in `skills/`, which Claude loads only when relevant:

| Skill | Loaded when writing |
| ----- | ------------------- |
| `bash-standards` | Bash or shell scripts |
| `python-standards` | Python code or CLI tools |
| `go-standards` | Go code, CLIs, or TUIs |
| `node-ts-standards` | Node.js, TypeScript, or JavaScript |

To add a skill, create `skills/<name>/SKILL.md` with `name` and `description` frontmatter and
re-run the installer — the directory is globbed, so no script change is needed.

## Hooks

A rule in `CLAUDE.md` or a skill is a request — Claude usually follows it. A hook is deterministic
code that runs at a fixed point in the session, so it can guarantee the behavior instead. These
four hooks enforce rules the rest of this directory only states as prose:

| Hook | Event | Guarantees |
| ---- | ----- | ---------- |
| `verify-edit.sh` | `PostToolUse` on `Edit\|Write` | Runs the matching skill's "Verification before commit" check (shellcheck, ruff, gofmt) right after the edit, and blocks on findings |
| `guard-gh-attribution.sh` | `PreToolUse` on `Bash`, `gh *` | Denies `gh pr/issue create/comment/review` when the body is missing the required 🤖 attribution footer |
| `guard-secrets.sh` | `PreToolUse` on `Bash` | Redacts token-shaped literals (API keys, PATs) out of a command before it runs, rather than blocking it |
| `resume-context.sh` | `SessionStart`, matcher `compact` | Re-injects a short git snapshot (branch, status, recent commits) after a compaction |

Markdown and Python checks in `verify-edit.sh` only run when the target repo opts in — a
`.markdownlint.json` or `pyproject.toml`/`ruff.toml` at its root — so cloned third-party repos stay
quiet. These hooks are user-level (symlinked to `~/.claude/settings.json`), so they run in every
project, not just carrybag-lite; `verify-edit.sh` needs `ruff` and `markdownlint-cli`, installed by
`install_lint_tools()` in `bootstrap/install.sh`.

To add a hook, drop a script into `hooks/`, re-run the installer, and register it under `hooks` in
`settings.json` — scripts are globbed for symlinking, but registration is explicit.

## Installation

The `install.sh` script is called automatically by `bootstrap/install.sh` and creates symlinks:

```bash
~/.claude/CLAUDE.md            -> carrybag-lite/claude/CLAUDE.md
~/.claude/settings.json        -> carrybag-lite/claude/settings.json
~/.claude/statusline-command.sh -> carrybag-lite/claude/statusline-command.sh
~/.claude/skills/<name>        -> carrybag-lite/claude/skills/<name>
~/.claude/hooks/<name>.sh      -> carrybag-lite/claude/hooks/<name>.sh
```

Because `codex/install.sh` and `antigravity/install.sh` link `~/.claude/skills/` into their own
skills directories, these skills reach Codex CLI and Antigravity CLI as well.

## Manual Installation

```bash
./claude/install.sh
```

This will backup any existing files and create the symlinks.
