# tools

Utility scripts for day-to-day development workflow.

## update.sh — Bulk git repository updater

Pull the latest changes for every git repository found in a directory.

```bash
update.sh [-q|--quiet] [-f|--fetch-only] [-s|--stash] [-p|--parallel] [-h] [directory]
```

| Argument             | Default | Description                              |
|----------------------|---------|------------------------------------------|
| `-q`, `--quiet`      |         | Only show repos with changes or problems |
| `-f`, `--fetch-only` |         | Fetch only — report behind, no pull      |
| `-s`, `--stash`      |         | Auto-stash local changes, pull, then pop |
| `-p`, `--parallel`   |         | Pull all repos concurrently              |
| `-h`, `--help`       |         | Show help and exit                       |
| `directory`          | `$PWD`  | Directory to scan for git repositories   |

**Behaviour:**

- Skips any repository with uncommitted local changes (warns you)
- Skips any repository whose remote is unreachable (warns you)
- Uses `--ff-only` to avoid creating merge commits
- All git operations are subject to a timeout (default 60s; override
  with `GIT_PULL_TIMEOUT=N`)
- Parallel mode runs up to 8 concurrent jobs (override with
  `UPDATE_MAX_JOBS=N`); results are displayed in original directory order
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

# Pull all repos in parallel (faster for many repos)
update.sh --parallel

# Parallel with a custom concurrency limit
UPDATE_MAX_JOBS=4 update.sh --parallel

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

## extract-ai-context.sh — Extract AI context file to private repo

Inspired by Dan Maby's article
[Managing AI Configuration Files Across Projects](https://www.danmaby.com/posts/2025/08/managing-ai-configuration-files-across-projects/).

Moves an AI context file (`CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`) out of a
public git repo, stores it in a private repo based on the
[ai-context-template](https://github.com/ali5ter/ai-context-template), and symlinks it back.
The file remains visible to local AI tooling but is no longer committed to the
public repo.

```bash
extract-ai-context.sh <path-to-repo>
```

| Argument        | Description                              |
|-----------------|------------------------------------------|
| `path-to-repo`  | Path to a local git repository clone     |

**What it does:**

1. Finds all of `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` present in the repo
2. Runs `git rm --cached` to untrack the file in the target repo
3. Appends the filename to `.gitignore` in the target repo
4. Copies the file to `ai-context/<repo-name>/` and pushes
5. Symlinks the original path back to the private repo copy
6. Pushes the updated target repo

**Prerequisites:**

Create a private repo from the
[ai-context-template](https://github.com/ali5ter/ai-context-template), then export its name:

```bash
export AI_CONTEXT_REPO="your-username/ai-context"
```

**Restoring on a new machine:**

```bash
cd ~/Documents/projects   # or ~/src on Linux
gh repo clone "$AI_CONTEXT_REPO"
cd ai-context
./install.sh
```

**Examples:**

```bash
# Extract CLAUDE.md from a local repo clone
AI_CONTEXT_REPO=your-username/ai-context extract-ai-context.sh ~/Documents/projects/my-public-repo
```

---

## pdf2md.py — PDF to Markdown converter

Convert a text-based PDF to clean Markdown. Preserves heading hierarchy,
paragraphs, bullet lists, and inline bold/italic formatting.  Requires
[PyMuPDF](https://pymupdf.readthedocs.io/) (`pip install pymupdf`).

```bash
pdf2md.py [--stdout] [--list-size PT] <input.pdf> [output.md]
```

| Argument          | Default              | Description                                     |
|-------------------|----------------------|-------------------------------------------------|
| `input.pdf`       |                      | Path to the source PDF file                     |
| `output.md`       | `<input>.md`         | Output path (defaults to input name with `.md`) |
| `--stdout`        |                      | Write output to stdout instead of a file        |
| `--list-size PT`  | `17.0`               | Font-size threshold (pt) for automatic lists    |
| `-h`, `--help`    |                      | Show help and exit                              |

**Behaviour:**

- Detects headings from font size and weight (≥ 20 pt bold → H1 or H2)
- Wraps inline bold/italic runs in `**…**` / `*…*` markers
- Filters page headers, footers, page numbers, and trademark symbols
- Merges heading text split across multiple design boxes
- Detects bullet lists from: small-font runs, multi-item blocks, and
  body paragraphs that follow a colon-ending intro sentence
- Normalises line-break whitespace so wrapped lines join correctly

**Examples:**

```bash
# Convert to a .md file next to the PDF
pdf2md.py document.pdf

# Specify output path
pdf2md.py ~/Desktop/report.pdf ~/Desktop/report.md

# Pipe to stdout (e.g. for preview)
pdf2md.py --stdout document.pdf | head -40

# Adjust list detection threshold
pdf2md.py --list-size 16 document.pdf output.md
```

**Limitations:**

- Works with text-based PDFs only; scanned/image PDFs are not supported
- Canva and other design-tool PDFs may have non-linear block order that
  affects reading order in the output
- Complex multi-column layouts are not re-flowed

---

## sync.sh — Directory backup and sync

Sync a source directory to a local target (external drive) or a remote target
over SSH. The mode is auto-detected: any target containing `:` is treated as
remote (`user@host:/path`).

```bash
sync.sh [--dry-run] [--exclude pattern] [--no-default-excludes] \
        [--max-retries N] [--bwlimit KBPS] [--port N] [--key path] \
        [source [target]]
```

| Argument                | Default         | Description                    |
|-------------------------|-----------------|--------------------------------|
| `--dry-run`, `-n`       |                 | Show what would change, no-op  |
| `--exclude pattern`     |                 | Exclude an additional pattern  |
| `--no-default-excludes` |                 | Disable built-in exclude list  |
| `--max-retries N`       | `0` (unlimited) | Max retry attempts (remote)    |
| `--bwlimit N`           | `0` (unlimited) | Bandwidth cap in KB/s          |
| `--port N`              |                 | SSH port (remote only)         |
| `--key path`            |                 | SSH identity file (remote only)|
| `-h`, `--help`          |                 | Show help and exit             |
| `source`                | `$HOME/`        | Directory to sync from         |
| `target`                | (Lacie drive)   | Local path or `user@host:path` |

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

# Throttle to ~10 MB/s to avoid saturating the network
sync.sh --bwlimit 10000 $HOME/ alice@myserver.local:/backups/alice/

# Remote sync with a non-standard SSH port and specific key
sync.sh --port 2222 --key ~/.ssh/id_backup $HOME/ alice@myserver.local:/backups/

# Pull a directory from a remote machine to local
sync.sh alice@myserver.local:/home/alice/projects/ ~/projects/
```
