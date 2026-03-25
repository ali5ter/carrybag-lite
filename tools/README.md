# tools

Utility scripts for day-to-day development workflow.

## update.sh — Bulk git repository updater

Pull the latest changes for every git repository found in a directory.

```bash
update.sh [-q|--quiet] [-f|--fetch-only] [-s|--stash] [directory]
```

| Argument             | Default | Description                              |
|----------------------|---------|------------------------------------------|
| `-q`, `--quiet`      |         | Only show repos with changes or problems |
| `-f`, `--fetch-only` |         | Fetch only — report behind, no pull      |
| `-s`, `--stash`      |         | Auto-stash local changes, pull, then pop |
| `directory`          | `$PWD`  | Directory to scan for git repositories   |

**Behaviour:**

- Skips any repository with uncommitted local changes (warns you)
- Skips any repository whose remote is unreachable (warns you)
- Uses `--ff-only` to avoid creating merge commits
- All git operations are subject to a timeout (default 60s; override
  with `GIT_PULL_TIMEOUT=N`)
- Prints a summary: updated / already current / skipped / failed

**Examples:**

```bash
# Update all repos in the current directory
update.sh

# Only show repos that changed or had problems
update.sh --quiet

# See what's pending without pulling anything
update.sh --fetch-only

# Auto-stash local changes, pull, then restore
update.sh --stash

# Update all repos in a specific directory
update.sh ~/Documents/projects

# Use a shorter timeout
GIT_PULL_TIMEOUT=15 update.sh
```

**Debug mode:**

```bash
DEBUG=1 update.sh
```

---

## sync.sh — Directory backup and sync

Sync a source directory to a local target (external drive) or a remote target
over SSH. The mode is auto-detected: any target containing `:` is treated as
remote (`user@host:/path`).

```bash
sync.sh [--dry-run] [--exclude pattern] [--no-default-excludes] \
        [--max-retries N] [source [target]]
```

| Argument                | Default         | Description                   |
|-------------------------|-----------------|-------------------------------|
| `--dry-run`, `-n`       |                 | Show what would change, no-op |
| `--exclude pattern`     |                 | Exclude an additional pattern |
| `--no-default-excludes` |                 | Disable built-in exclude list |
| `--max-retries N`       | `0` (unlimited) | Max retry attempts (remote)   |
| `source`                | `$HOME/`        | Directory to sync from        |
| `target`                | (Lacie drive)   | Local path or `user@host:path`|

**Default excludes** (applied automatically unless `--no-default-excludes`):
`.DS_Store`, `.Trash/`, `node_modules/`, `.cache/`, `__pycache__/`, `*.pyc`,
`.venv/`, `dist/`, `build/`

**Local sync** preserves permissions, ownership, timestamps, and symlinks. Skips
files newer on the destination. Deletes files from the target that no longer
exist in the source.

**Remote sync** adds SSH compression and a 30-minute keepalive to survive slow
or intermittent connections. Retries automatically on failure (unlimited by
default; use `--max-retries` to cap). Resumes partial transfers.

**Examples:**

```bash
# Sync home to the default Lacie drive
sync.sh

# Preview what would be transferred without making changes
sync.sh --dry-run

# Sync with an extra exclusion on top of defaults
sync.sh --exclude '.env' ~/Documents /Volumes/Backup/docs

# Sync to a remote machine over SSH
sync.sh $HOME/ alice@myserver.local:/backups/alice/

# Remote sync with a cap of 5 retries
sync.sh --max-retries 5 $HOME/ alice@myserver.local:/backups/alice/

# Pull a directory from a remote machine to local
sync.sh alice@myserver.local:/home/alice/projects/ ~/projects/
```
