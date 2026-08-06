---
name: python-standards
description: Python conventions — shebang, PEP 8 and PEP 257, Google-style docstrings, type hints, ruff, pathlib, argparse, pytest, and Rich terminal output for CLI tools. Use when writing, reviewing, or refactoring Python code, Python CLI tools, or .py files.
---

# Python standards

## Setup

- Shebang for executable scripts: `#!/usr/bin/env python3`
- Target Python 3.10+ and use modern syntax: `X | Y` unions, `match`/`case`
- Lint and format with `ruff` — it replaces black, isort, and flake8
- Virtual environments via `venv` or `pyenv-virtualenv`
- Follow [PEP 8](https://peps.python.org/pep-0008/) for style and
  [PEP 257](https://peps.python.org/pep-0257/) for docstrings

## Language

- Type hints on every function signature, parameters and return
- PEP 8 naming: `snake_case` for functions and variables, `PascalCase` for classes
- `pathlib.Path` over `os.path`
- Dataclasses or Pydantic for structured data — not bare dicts or tuples
- Prefer the standard library before adding a dependency

## Documentation

Google style. Module docstring at the top of the file:

```python
"""pdf2md.py - Convert a PDF to Markdown.

Extracts text and structure from a PDF and writes GitHub-flavoured Markdown.

Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
Version: 1.0.0
Date: 2026-08-06
License: MIT

Usage:
    ./pdf2md.py input.pdf -o output.md

Dependencies:
    pypdf, rich

Exit codes:
    0 - Success
    1 - Conversion failed
"""
```

Function docstrings use `Args`, `Returns`, `Raises`, and `Example`:

```python
def convert(source: Path, dest: Path | None = None) -> int:
    """Convert a PDF to Markdown.

    Args:
        source: Path to the input PDF.
        dest: Output path. Writes to stdout when None.

    Returns:
        Number of pages converted.

    Raises:
        FileNotFoundError: If source does not exist.

    Example:
        >>> convert(Path("in.pdf"), Path("out.md"))
        12
    """
```

Reference: <https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings>

## CLI tools

- `argparse` for argument handling, with `--help` always available
- `sys.exit()` with meaningful codes — 0 for success, non-zero for failure
- Follow the [Command Line Interface Guidelines](https://clig.dev)

## Terminal output with Rich

All CLI scripts use [Rich](https://github.com/Textualize/rich).

**Visual hierarchy:**

| Level | Use | Call |
| ----- | --- | ---- |
| 1 | Major sections | `console.rule("[bold]Section Title[/bold]")` |
| 2 | Steps and headings | `console.print("[bold cyan]Step message[/bold cyan]")` |
| 3 | Status items | `console.print("[green]✔[/green] message")`, `[red]✗[/red]`, `[yellow]![/yellow]` |
| 4 | Structured content | `rich.table.Table`, `rich.panel.Panel` |

**Rules:**

- One `console = Console()` instance per script, imported from `rich.console`
- `console.print()` everywhere — never plain `print()` for user-facing output
- Markup sparingly; semantic colours only: green success, red error, yellow warning, cyan info
- Errors to stderr via a dedicated `Console(stderr=True)` or `console.print(..., style="red")`
- Long-running work uses `rich.progress.Progress` — never a hand-rolled `print` spinner

**Ask yourself:** does visual weight match semantic importance?

## Testing

- pytest, with descriptive test names that state the behaviour under test
- Fixtures over `setUp`/`tearDown`
- Test behaviour, not implementation

## Verification before commit

```bash
ruff format .
ruff check .
pytest
```
