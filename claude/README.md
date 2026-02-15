# Claude Code Configuration

This directory contains Claude Code configuration files that are symlinked to `~/.claude/`.

## Files

- **CLAUDE.md** - Global development standards applied to all projects (user-level instructions)
- **settings.json** - Claude Code settings and preferences
- **statusline-command.sh** - Custom status line display script

## Installation

The `install.sh` script is called automatically by `bootstrap/install.sh` and creates symlinks:

```bash
~/.claude/CLAUDE.md -> carrybag-lite/claude/CLAUDE.md
~/.claude/settings.json -> carrybag-lite/claude/settings.json
~/.claude/statusline-command.sh -> carrybag-lite/claude/statusline-command.sh
```

## Manual Installation

```bash
./claude/install.sh
```

This will backup any existing files and create the symlinks.
