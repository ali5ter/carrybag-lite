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

## sync — Home directory backup

Sync the home directory (or a custom source) to an external drive using rsync.

```bash
sync [source] [target]
```

| Argument | Default                       | Description              |
|----------|-------------------------------|--------------------------|
| `source` | `$HOME/`                      | Directory to sync from   |
| `target` | `/Volumes/Lacie/$HOSTNAME/`   | Directory to sync to     |

Preserves permissions, ownership, timestamps, and symlinks. Skips files newer
on the destination. Deletes files from the target that no longer exist in the source.

**Examples:**

```bash
# Sync home to the default Lacie drive
sync

# Sync a specific source to a custom target
sync ~/Documents /Volumes/Backup/docs
```
