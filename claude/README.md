# Claude Code Configuration

This directory contains Claude Code configuration files that are symlinked to `~/.claude/`.

## Files

- **CLAUDE.md** - Global development standards applied to all projects (user-level instructions)
- **settings.json** - Claude Code settings and preferences
- **statusline-command.sh** - Custom status line display script
- **skills/** - Language standards loaded on demand rather than in every session

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

## Installation

The `install.sh` script is called automatically by `bootstrap/install.sh` and creates symlinks:

```bash
~/.claude/CLAUDE.md            -> carrybag-lite/claude/CLAUDE.md
~/.claude/settings.json        -> carrybag-lite/claude/settings.json
~/.claude/statusline-command.sh -> carrybag-lite/claude/statusline-command.sh
~/.claude/skills/<name>        -> carrybag-lite/claude/skills/<name>
```

Because `codex/install.sh` and `antigravity/install.sh` link `~/.claude/skills/` into their own
skills directories, these skills reach Codex CLI and Antigravity CLI as well.

## Manual Installation

```bash
./claude/install.sh
```

This will backup any existing files and create the symlinks.
