# tools

Utility scripts for day-to-day development workflow.

## update.sh — Bulk git repository updater

Pull the latest changes for every git repository found in a directory.

```bash
update.sh [directory]
```

| Argument    | Default    | Description                                 |
|-------------|------------|---------------------------------------------|
| `directory` | `$PWD`     | Directory to scan for git repositories      |

**Behaviour:**

- Skips any repository with uncommitted local changes (warns you)
- Skips any repository whose remote is unreachable (warns you)
- Uses `--ff-only` to avoid creating merge commits
- Prints a summary: updated / already current / skipped / failed

**Examples:**

```bash
# Update all repos in the current directory
update.sh

# Update all repos in a specific directory
update.sh ~/Documents/projects
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
sync.sh [--dry-run] [source [target]]
```

| Argument    | Default                     | Description                   |
|-------------|-----------------------------|-------------------------------|
| `--dry-run` |                             | Show what would change, no-op |
| `-n`        |                             | Shorthand for `--dry-run`     |
| `source`    | `$HOME/`                    | Directory to sync from        |
| `target`    | `/Volumes/Lacie/$HOSTNAME/` | Local path or `user@host:path`|

**Local sync** preserves permissions, ownership, timestamps, and symlinks. Skips
files newer on the destination. Deletes files from the target that no longer
exist in the source.

**Remote sync** adds SSH compression and a 30-minute keepalive to survive slow
or intermittent connections.

**Examples:**

```bash
# Sync home to the default Lacie drive
sync.sh

# Preview what would be transferred without making changes
sync.sh --dry-run

# Sync a specific local source to a custom local target
sync.sh ~/Documents /Volumes/Backup/docs

# Sync home directory to a remote machine over SSH
sync.sh $HOME/ alice@myserver.local:/backups/alice/

# Pull a directory from a remote machine to local
sync.sh alice@myserver.local:/home/alice/projects/ ~/projects/
```
