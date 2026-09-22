---
name: bash-standards
description: Bash and shell scripting conventions — shebang, Google-style script and function headers, pfb terminal output hierarchy, idempotency, and shellcheck verification. Use when writing, reviewing, or refactoring any bash script, shell script, or .sh file.
---

# Bash standards

## Setup

- Shebang is always `#!/usr/bin/env bash` on line 1 — nothing above it, not even a comment
- Follow the [Pure Bash Bible](https://github.com/dylanaraps/pure-bash-bible) for idiomatic
  parameter expansion and built-ins over external processes
- Follow the [Bash Style Guide](https://github.com/bahamas10/bash-style-guide) for structure
- Scripts must be idempotent — safe to run repeatedly — and portable across macOS and
  Debian-based Linux

## Documentation

Google-style, applied at two levels.

Script header, immediately below the shebang:

```bash
#!/usr/bin/env bash
#
# install.sh - Install Claude Code configuration
#
# Symlinks Claude Code configuration files from the repo to ~/.claude/.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-08-06
# License: MIT
#
# Usage: ./claude/install.sh
#
# Dependencies: bash 4.0+, pfb
#
# Exit codes:
#   0 - Success
#   1 - Errors during installation
```

Function documentation, immediately above the function:

```bash
# Back up an existing regular file to a timestamped copy before symlinking.
# No-op if the file does not exist or is already a symlink.
# @param $1  Absolute path of the file to check and back up
# @return 0
# @example backup_if_exists "$HOME/.claude/CLAUDE.md"
# @side_effects Moves the file to <path>.backup-YYYYMMDDHHMMSS
backup_if_exists() {
```

Use `@param`, `@return`, `@example`, and `@side_effects` where applicable. Reference:
<https://linuxvox.com/blog/what-is-the-standard-for-documentation-style-in-bash-scripts>

## Terminal output with pfb

All scripts use [pfb](https://github.com/ali5ter/pfb) for output.

**Visual hierarchy:**

| Level | Use | Call |
| ----- | --- | ---- |
| 1 | Major sections | `pfb heading "message" "emoji"` |
| 2 | Steps | `pfb heading "message" "emoji"` |
| 3 | Subsections | `pfb heading "message"` (emoji optional) |
| 4 | Content items | `pfb subheading "message"` (dimmed) |

**Rules:**

- Emojis go in the parameter, never inline: `pfb heading "Docker Setup" "🐳"`
- Log levels (`info`/`success`/`warn`/`error`) are for single-line status only — never for
  lists or prose
- Keep visual consistency within a block; don't mix `pfb subheading` with plain `echo`
- If something carries an emoji it should be a heading, not a subheading

**Anti-patterns:**

- ❌ `pfb info "🚀 Setup"` → ✅ `pfb heading "Setup" "🚀"`
- ❌ `pfb info` repeated for a multi-line list → ✅ `pfb subheading` per item
- ❌ Step-by-step instructions in a README → ✅ an executable script the README points at

**Ask yourself:** does visual weight match semantic importance?

## Verification before commit

```bash
bash -n script.sh        # syntax check
shellcheck script.sh     # lint — resolve or annotate every finding
```

Suppress a finding only with a targeted directive and a reason, e.g.
`# shellcheck disable=SC2034  # exported for downstream sourcing`.
