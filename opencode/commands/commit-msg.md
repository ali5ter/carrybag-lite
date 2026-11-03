---
description: Generate a conventional commit message from the staged diff.
---

Generate a conventional commit message for the staged changes:

!`git diff --cached --stat && echo && git diff --cached --`

Follow Conventional Commits: type(scope): description
Types: feat, fix, chore, docs, refactor, test, style, perf
Scope: the affected subsystem or file group (optional)
