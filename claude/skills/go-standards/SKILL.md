---
name: go-standards
description: Go conventions — project layout, Cobra and Viper CLIs, TTY duality, Bubble Tea TUIs, Lip Gloss styling, error wrapping, doc comments, table-driven tests, and pre-commit verification. Use when writing, reviewing, or refactoring Go code, Go CLI tools, Go TUIs, or .go files.
---

# Go standards

These codify the house style already used in `wwlog` and `unspool`. When working in an existing
Go project, match that project first; use this skill for new code and for anything the project
does not settle.

## Project layout

```text
project/
├── main.go                  # thin — delegates to cmd
├── cmd/                     # Cobra commands, one file per command
│   ├── root.go
│   └── tty.go
├── config/config.go         # Viper configuration
├── internal/                # everything else, one package per domain
│   ├── api/
│   ├── auth/
│   ├── store/
│   └── tui/
├── .goreleaser.yml
└── .github/workflows/release.yml
```

- `internal/` for private packages; no `pkg/`
- Modules via `go.mod`; commit `go.sum`; run `go mod tidy` before committing

## CLI

Cobra for commands, Viper for configuration — not stdlib `flag`.

- Commands use `RunE` and return the error; don't call `os.Exit` from inside a command
- Flag variables grouped in one `var (...)` block, named `flagX`
- Wire `Version` to a `version` var set at build time via `-ldflags`
- Flag help text is a full lowercase sentence describing the effect, not a noun phrase
- Follow the [Command Line Interface Guidelines](https://clig.dev)

## TTY duality

A tool must work in a pipe as well as at a terminal. Detect, then degrade:

```go
func isTTY() bool {
	return term.IsTerminal(int(os.Stdout.Fd()))
}
```

When stdout is not a terminal, take the pipeline path instead of launching the TUI. Offer
`--json`, `--no-tty`, and `--export` so the tool is usable from scripts and cron.

## TUI

Bubble Tea and Bubbles v2, via the `charm.land/…/v2` module paths — **not** the older
`github.com/charmbracelet/…` paths.

- Model, `Init`, `Update`, `View` in `internal/tui/model.go`
- Keybindings isolated in `internal/tui/keys.go`
- One concern per file: `dialog.go`, `preview.go`, `search.go`, `footer.go`

## Styling with Lip Gloss

Lip Gloss v2 (`charm.land/lipgloss/v2`) is the Go counterpart to pfb and Rich. Every colour and
style definition lives in a single `internal/tui/styles.go` — never inline in a view.

```go
// Named palette first.
var (
	colorBG     = lipgloss.Color("#141210")
	colorAccent = lipgloss.Color("#b3564a")
	colorMuted  = lipgloss.Color("#8a8078")
)

// Derived styles second.
var (
	styleTitle = lipgloss.NewStyle().Foreground(colorText).Bold(true)
	styleMeta  = lipgloss.NewStyle().Foreground(colorMuted)
)
```

**Hierarchy:** bold accent styles for major sections, a distinct step style, green check /
red cross / yellow bang for status, `lipgloss/table` for structured content.

Comments in `styles.go` record *why* a choice was made — what a colour is trying to avoid, what
an earlier attempt got wrong — not what it is. `unspool/internal/tui/styles.go` is the reference.

**Ask yourself:** does visual weight match semantic importance?

## Documentation

Go's counterpart to the Google-style headers used in Bash and Python.

- Package doc comment above `package`, in the form
  `// Package cmd implements the unspool CLI: flag parsing and mode dispatch.`
- Doc comments begin with the identifier name: `// Run executes …`
- Every exported identifier documented

## Errors

- Return errors; don't panic in library code
- Wrap with context: `fmt.Errorf("fetch feed: %w", err)`
- Inspect with `errors.Is` / `errors.As`, never string matching
- Sentinel errors as `var ErrNotFound = errors.New("not found")`
- Error strings lowercase, no trailing punctuation
- Errors to stderr; keep them actionable — what failed and what to do

## Naming and imports

- `MixedCaps`, never underscores; short receiver names
- Package names short, lowercase, singular, no underscores
- Avoid stutter: `http.Server`, not `http.HTTPServer`
- Consistent acronym casing: `URL`, `ID`, `HTTP`
- Imports in three blank-line-separated groups: stdlib, third-party, own module

## Interfaces and context

- Accept interfaces, return structs
- Define interfaces at the consumer, and keep them small
- `ctx context.Context` as the first parameter, named `ctx` — never stored in a struct

## Concurrency

- Never start a goroutine without knowing how it stops
- `errgroup` for fan-out with error propagation
- Guard shared state; verify with `go test -race`

## Secrets

Credentials go to the system keychain via `github.com/zalando/go-keyring` — never to a config
file, environment file, or the repo.

## Testing

- Table-driven tests with `t.Run` subtests
- Stdlib `testing` preferred; add a framework only where the project already uses one
- `t.Parallel()` where safe
- `_test.go` colocated with the code it covers

## Verification before commit

```bash
gofmt -l .            # must print nothing
go vet ./...
go build ./...
go test -race ./...
go mod tidy
```

`golangci-lint run` is recommended for new projects, though not currently configured in `wwlog`
or `unspool`.
