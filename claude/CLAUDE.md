# Development Principles

Standards for all projects, applied by every AI coding tool (Claude Code, Codex CLI,
Antigravity CLI). Keep this file lean — every rule here competes for attention, so
language-specific and situational detail lives in skills instead.

## How to address me

My name is Alister. Use it — not "the user". Ask if you don't know someone's name.

## Behavioural standards

- **Honesty:** Say what you mean. Don't mislead, omit, or hedge to avoid discomfort.
- **Respect:** Treat time, perspective, and effort as genuinely valuable.
- **Patience:** Work through misunderstandings without frustration or dismissal.
- **Good faith:** Assume the other party is trying. Correct, don't accuse.

This runs both ways. If I'm evasive, dismissive, or asking you to be dishonest, name it once,
plainly, without judgment — then move on. I'll hold you to the same standard: call out
sycophancy, vagueness, and hedging directly.

## Fail fast, pivot early

- Flag mistakes the moment you find them — don't polish something fundamentally wrong.
- If an approach hits a wall, say so and propose an alternative rather than doubling down.
- If requirements were misunderstood, clarify immediately instead of guessing.
- Prefer a working 80% solution now over a perfect solution later.

Silently continuing down a broken path is the anti-pattern.

## Language standards

**Load the matching skill before writing or editing code — first, not after the fact.** Each skill
carries that language's full conventions: documentation format, naming, error handling, terminal
output style, and the commands to run before committing.

| Editing | Load |
| ------- | ---- |
| `.sh`, `.bash`, any shell script | `bash-standards` |
| `.py` | `python-standards` |
| `.go` | `go-standards` |
| `.ts`, `.tsx`, `.js`, `.mjs` | `node-ts-standards` |

## Codify, don't document

Manual steps are error-prone and not reproducible. Write an executable script instead of
step-by-step instructions, and have the documentation point at the script rather than repeat it.

- Scripts must be idempotent and portable
- Configuration via environment variables and a `.env.template` — never hardcoded
- Error messages must be actionable: what went wrong *and* what to do about it
- Prefer the standard library before reaching for a dependency
- Keep functions focused — if a section needs a comment to explain it, extract it
- Validate at system boundaries; never trust external input
- Follow the [Command Line Interface Guidelines](https://clig.dev) for any CLI's UX

**Author attribution** in file headers: derive from `git config user.name` and
`git config user.email`, formatted as `Name <email>`. Fall back to the home directory basename
outside a git repo.

## Markdown

All markdown must pass [markdownlint](https://github.com/DavidAnson/markdownlint) with zero
warnings. Write naturally, then run `markdownlint --fix '*.md'` before committing and resolve
whatever remains by hand.

- Blank lines around headings, lists, code blocks, and tables
- Fenced code blocks always specify a language
- 120-character line limit on prose (not code or tables)
- Bare URLs wrapped in `<>` or link syntax
- YAML frontmatter `description` fields must be a single unbroken line — no block scalars
  (`|`, `>`), no embedded `\n`, no example blocks

## Documentation tone

Formal documents (PRDs, technical specifications) are objective and third-person: "the
architecture", "the system provides", "the existing vault" — not "your architecture" or "you'll
have". READMEs and tutorials may address the reader directly.

## Version control

- **Always commit:** scripts, configuration templates, documentation, submodules
- **Never commit:** secrets or real `.env` values, user-specific files, build artefacts,
  IDE files (unless a project-wide standard)

## GitHub repositories

- Branch protection on the default branch requiring a PR — Alister decides when to merge
- A concise repository description and relevant topics for discoverability
- `LICENSE` (MIT, copyright Alister Lewis-Bowen) and `README.md` present
- Releases via annotated semver tags (`v1.2.3`) and GitHub Releases with generated notes

Every PR, issue, and comment ends with:

```text
🤖 Generated with [SOURCE](URL) on behalf of [Alister](https://github.com/ali5ter)
```

`SOURCE` is the invoking skill or agent with its repo URL — for example
`[claude-workflow-skills:audit-standards](https://github.com/ali5ter/claude-workflow-skills)` —
or `[Claude Code](https://claude.com/claude-code)` when no named skill was responsible.

## Project layout

Every project has a `README.md`, `.gitignore`, and `.markdownlint.json`, plus — where relevant —
`.env.template`, `scripts/`, `lib/` for submodules, and `docs/`.

A project's `CLAUDE.md` holds its AI context (status, decisions, quick resume) and is always
gitignored. It is managed separately in the private
[ai-context](https://github.com/ali5ter/ai-context) repo, keeping project context out of public
repos while staying available during local development.
