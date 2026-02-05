# Claude Code Configuration

This directory contains Claude Code configuration files that are symlinked to `~/.claude/`.

## Files

- **development-principles.md** - Global development standards applied to all projects
- **settings.json** - Claude Code settings including hooks and preferences
- **statusline-command.sh** - Custom status line display script

## Installation

The `install.sh` script is called automatically by `bootstrap/install.sh` and creates symlinks:

```bash
~/.claude/development-principles.md -> carrybag-lite/claude/development-principles.md
~/.claude/settings.json -> carrybag-lite/claude/settings.json
~/.claude/statusline-command.sh -> carrybag-lite/claude/statusline-command.sh
```

## Manual Installation

```bash
./claude/install.sh
```

This will backup any existing files and create the symlinks.
