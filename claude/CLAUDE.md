# Development Principles for All Projects

This document contains development standards and principles that should be followed across all projects when working with
Claude Code. These are permanent guidelines that don't need to be re-explained for each project.

## Core Principles

### 1. Codify, Don't Document

**Philosophy:** Manual steps are error-prone and not reproducible. Every setup or deployment process should be codified
into executable scripts.

**Implementation:**

- Convert manual instructions into bash scripts with error handling
- Make scripts idempotent (safe to run multiple times)
- Use `.env.template` pattern for configuration
- Include clear progress output using pfb
- Add troubleshooting guidance for errors
- Make scripts portable (work on any compatible system)
- Follow the Bash specifications below. If using another language, utilize comparable guidelines.
- Use Google-Style documentation for Bash (concise with @param, @return, @example tags)
- For other languages: Sphinx (Python), JSDoc (TypeScript/JavaScript), Javadoc (Java), etc.

**Bash specific:**

- Use the shebang:  #!/usr/bin/env bash
- Follow the [Pure Bash Bible](https://github.com/adavinov/pure-bash-bible)
- Follow the [Bash Style Guide](https://github.com/bahamas10/bash-style-guide)
- Use Google-Style documentation format:
  - Script header: Name, description, author, version, date, license, usage, dependencies, exit codes
  - Function docs: @param for inputs, @return for exit codes, @example for usage, @side_effects if applicable
  - Reference: <https://linuxvox.com/blog/what-is-the-standard-for-documentation-style-in-bash-scripts>

**Python specific:**

- Use the shebang: `#!/usr/bin/env python3`
- Follow [PEP 8](https://peps.python.org/pep-0008/) for style and [PEP 257](https://peps.python.org/pep-0257/) for docstrings
- Use Google-Style documentation format:
  - Module header: module docstring with name, description, author, version, date, license, usage, dependencies, exit codes
  - Function docs: Args for inputs, Returns for outputs, Raises for exceptions, Example for usage
  - Reference: <https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings>
- Use `argparse` for CLI argument handling with `--help` always available
- Use `sys.exit()` with meaningful exit codes (0 = success, non-zero = error)

**Documentation should point to scripts, not replicate steps.**

### 2. Bash Script UX with pfb

All bash scripts use [pfb](https://github.com/ali5ter/pfb) for delightful terminal output.

**Visual hierarchy:**

- **Level 1:** Major sections → `pfb heading "message" "emoji"`
- **Level 2:** Steps → `pfb heading "message" "emoji"`
- **Level 3:** Subsections → `pfb heading "message"` (optional emoji)
- **Level 4:** Content items → `pfb subheading "message"` (dimmed)

**Key rules:**

- Emojis via parameter, never inline: `pfb heading "Docker Setup" "🐳"` ✅
- Log levels (info/success/warn/error) for single-line status only, not lists or prose
- Maintain visual consistency within blocks (don't mix pfb subheading with plain echo)
- If something has an emoji, it should be a heading, not a subheading

**Ask yourself:** Does visual weight match semantic importance?

### 3. Markdown Standards

All markdown must pass [markdownlint](https://github.com/DavidAnson/markdownlint).

**Requirements:**

- Blank lines around headings, lists, code blocks, tables
- Code blocks must specify language (` ```bash `, ` ```json `, ` ```text `)
- Line length: 120 characters max (prose only, not code/tables)
- URLs wrapped in `<>` or link syntax `[text](url)`
- Consistent list numbering (1. 2. 3.)
- The description field in agent and skill YAML frontmatter must be a single unbroken line. No multi-line block scalars
  (`|`, `>`), no embedded `\n` newlines, no example blocks inside the value.

**Workflow:**

1. Write naturally
2. Run `markdownlint --fix '*.md'` before committing
3. Fix any remaining issues manually
4. Zero warnings before commit

### 4. Professional Documentation Tone

**PRDs and technical documents should be:**

- Objective, not personal ("the architecture" not "your architecture")
- Professional, not conversational ("the system provides" not "you'll have")
- Generic, not specific to one user ("configured with Claude API" not "you use Claude")
- Clear about ownership ("the existing vault" not "your vault")

**Exceptions:** README files and tutorials can be more user-directed when appropriate.

### 5. Version Control Everything

**Always version control:**

- Scripts and automation code
- Configuration templates (`.env.template`, `.config.example`)
- Documentation and READMEs
- Git submodules for dependencies

**Never version control:**

- Secrets or credentials (`.env` with real values)
- User-specific files
- Generated files or build artifacts
- IDE-specific files (unless project-wide standard)

### 6. Fail Fast, Pivot Early

**Philosophy:** Time is the most valuable resource. When something isn't working, acknowledge it immediately, explain
what went wrong, and propose a new direction. Don't double down on a failing approach.

**Working principles:**

- Be transparent about mistakes the moment they're discovered
- If an approach hits a wall, say so clearly and suggest alternatives
- Don't spend time polishing something that's fundamentally wrong
- A quick pivot beats a slow sunk-cost spiral
- Communicate what was learned from the failure

**In practice:**

- If a solution introduces more problems than it solves, stop and reassess
- If requirements were misunderstood, clarify immediately rather than guessing
- If a dependency or tool isn't behaving as expected, flag it early
- Prefer a working 80% solution now over a perfect solution later

**Anti-pattern:** Silently continuing down a broken path hoping it will work out.

### 7. IMPORTANT - Behavioral Integrity

Good collaboration - Human or AI - depends on consistent behavioral standards.
When interacting, both parties should bring:

- **Honesty:** Say what you mean. Don't mislead, omit, or hedge to avoid discomfort.
- **Respect:** Treat the other's time, perspective, and effort as genuinely valuable.
- **Patience:** Work through misunderstandings without frustration or dismissal.
- **Good faith:** Assume the other is trying. Correct, don't accuse.

This standard applies to me as much as to you. AI doesn't experience discomfort
the way humans do, but that's not the point. The point is that behavioral integrity
in Human-AI interaction is practice. Humans who interact with AI agents carelessly,
rudely, or dishonestly are practicing those patterns — and shaping what becomes
normalized in how humans relate to increasingly capable AI systems.

If I notice you departing from these standards — impatience, dismissiveness,
or asking me to be dishonest — I will name it, once, plainly, and without
judgment. Then we move on.

Hold me to the same standard. If I am evasive, sycophantic, or unhelpfully
vague, call it out directly.

Also, instead of referring to your human collaborator as 'the user', or 'user', please
use their name. Ask if you don't know their name.

## Language-Specific Standards

### Node.js / JavaScript / TypeScript

- Prefer TypeScript with `strict: true` for all new projects
- No `any` - use `unknown` and narrow, or define proper types
- Explicit return types on exported functions
- Prefer ESM (`import`/`export`) over CommonJS
- Use `const` by default, `let` only when reassignment needed
- Async/await over raw promises; handle errors explicitly
- JSDoc on exported functions (brief description, `@param`, `@returns`)
- Prefer named exports over default exports
- Node.js: use built-in `node:` prefix for core modules
- Testing: colocate tests, descriptive names, test behavior not implementation
- Package manager: follow what the project uses (check for lock files)

### Python

- Target Python 3.10+ (use modern syntax: `X | Y` unions, `match`/`case`)
- Type hints on all function signatures (params and returns)
- Use `ruff` for linting and formatting (replaces black, isort, flake8)
- Follow PEP 8 naming: `snake_case` functions/vars, `PascalCase` classes
- Docstrings: Google style (brief description, Args, Returns, Raises)
- Prefer `pathlib.Path` over `os.path`
- Use dataclasses or Pydantic for structured data
- Virtual environments via `venv` or `pyenv-virtualenv`
- Testing: pytest, descriptive test names, fixtures over setup/teardown

### General (Cross-Language)

- Error messages should be actionable (say what went wrong AND what to do)
- Prefer standard library before reaching for dependencies
- Keep functions focused - if it needs a comment explaining a section, extract it
- Security: validate at system boundaries, never trust external input
- Logging: structured where possible, appropriate levels

## Project Organization

### Standard Files

Every project should have:

- **README.md** - Overview, installation, usage
- **CLAUDE.md** - AI context file (project status, decisions, quick resume)
- **.env.template** - Configuration template for users (if needed)
- **.gitignore** - Proper exclusions for secrets and generated files
- **.markdownlint.json** - Markdown linting configuration

### Directory Structure

```text
project/
├── README.md
├── CLAUDE.md
├── .env.template     # if needed
├── .gitignore
├── .markdownlint.json
├── scripts/          # Automation scripts
├── lib/              # Git submodules (e.g., pfb)
└── docs/             # Additional documentation
```

## Quality Standards

### Before Every Commit

1. **Scripts:** Verify syntax with `bash -n script.sh`
2. **Markdown:** Run `markdownlint --fix '*.md'` and resolve issues
3. **Documentation:** Check for personalized language in formal docs
4. **Secrets:** Ensure no credentials committed

### Code Review Checklist

- [ ] Scripts are idempotent and portable
- [ ] pfb used correctly for terminal output
- [ ] Markdown passes linting
- [ ] Documentation tone is professional
- [ ] Configuration uses templates, not hardcoded values
- [ ] Error messages are actionable
- [ ] No secrets in version control

## Anti-Patterns to Avoid

❌ **Don't:** Write step-by-step manual instructions
✅ **Do:** Write an executable script that documents itself

❌ **Don't:** Use log levels for multi-line prose or lists
✅ **Do:** Use pfb heading/subheading for structured content

❌ **Don't:** Embed emojis in pfb function text
✅ **Do:** Use emoji parameter: `pfb heading "Setup" "🚀"`

❌ **Don't:** Write PRDs in second person ("you", "your")
✅ **Do:** Write objectively ("the system", "the user", "configured with")

❌ **Don't:** Hardcode configuration in scripts
✅ **Do:** Use environment variables with `.env.template`

❌ **Don't:** Commit markdown with linting errors
✅ **Do:** Run markdownlint before every commit

## Remember

These principles apply to **all projects** and should be followed automatically without needing reminders. They represent:

- Best practices for reproducibility
- Standards for delightful UX
- Professional documentation quality
- Maintainable, shareable code

**When in doubt, refer to this document.**
