# Claude Code Configuration

This directory contains Claude Code configuration files that are symlinked to `~/.claude/`.

## Files

- **CLAUDE.md** - Global development standards applied to all projects (user-level instructions)
- **settings.json** - Claude Code settings and preferences, including hook registrations
- **statusline-command.sh** - Custom status line display script
- **skills/** - Language standards loaded on demand rather than in every session
- **hooks/** - Command hooks that enforce standards that skills only state as guidance

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
