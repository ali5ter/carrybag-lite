#!/usr/bin/env bash
#
# install.sh - Install OpenCode configuration
#
# Phase 1 (v2.0): symlinks CLAUDE.md from carrybag-lite/claude/ into
#   ~/.config/opencode/AGENTS.md, links plugin-installed Claude Code skills
#   into ~/.config/opencode/skills/, and merges a baseline provider config
#   into the global OpenCode config (~/.config/opencode/opencode.json).
#
# Phase 2 (v3.0): adds the following on top of v2.0:
#   • agents/  — reusable subagent definitions (frontmatter-based .md files)
#   • commands/ — slash-command definitions (frontmatter .md + shell blocks)
#   • MCP config — optional hindsight server entry in opencode.json
#
# Parallel architecture (Issue #32): Claude Code owns ~/.claude/ (settings.json,
# hooks, marketplace, statusline). OpenCode owns ~/.config/opencode/ (provider
# config, agents, commands, MCP, skills). Both share CLAUDE.md → AGENTS.md,
# ~/.claude/skills/, and the same Ollama server. OpenCode does not read or
# modify Claude Code's config, and vice versa.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 3.0.0
# Date: 2026-11-03
# License: MIT
#
# Usage: ./opencode/install.sh
#   LOCAL_ENDPOINT=<url> ./opencode/install.sh          # explicit Ollama endpoint
#   OPENCODE_LOCAL_MODEL=<name> ./opencode/install.sh   # preferred default model
#   HINDSIGHT_URL=<url>  ./opencode/install.sh          # enable Hindsight MCP
#   OPENCODE_CONTEXT_LIMIT=<tokens> OPENCODE_OUTPUT_LIMIT=<tokens> ./opencode/install.sh
#   Backs up any existing file before replacing it; running twice is idempotent.
#   Keys the script does not manage are preserved; comments are stripped before
#   parsing.
#
# Dependencies: bash 4.0+, curl, jq, md5 (or shasum); optional: pfb
#
# Exit codes:
#   0 - Success
#   1 - Source file, curl or jq not found
#   2 - Existing OpenCode config could not be parsed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(realpath "$SCRIPT_DIR" 2>/dev/null || printf '%s' "$SCRIPT_DIR")"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OPENCODE_DIR="$HOME/.config/opencode"
CLAUDE_PLUGIN_CACHE="$HOME/.claude/plugins/cache"
SOURCE="$REPO_DIR/claude/CLAUDE.md"
AGENTS_DIR="$OPENCODE_DIR/agents"
COMMANDS_DIR="$OPENCODE_DIR/commands"
CONFIG_JSON="$OPENCODE_DIR/opencode.json"
AGENTS_LINK="$OPENCODE_DIR/AGENTS.md"
OLLAMA_HOST_FILE="$HOME/.config/ollama_host"
PROVIDER="ollama"
CONTEXT_LIMIT="${OPENCODE_CONTEXT_LIMIT:-131072}"
OUTPUT_LIMIT="${OPENCODE_OUTPUT_LIMIT:-32768}"
CURL_TIMEOUT=5

type pfb >/dev/null 2>&1 || pfb() { echo "$2"; }

backup_if_exists() {
    local file="$1" backup
    if [[ -f "$file" && ! -L "$file" ]]; then
        backup="${file}.backup.$(date +"%Y%m%d%H%M%S")"
        pfb info "  Backing up existing $(basename "$file") to $(basename "$backup")"
        mv "$file" "$backup"
    fi
}

normalize_endpoint() {
    local url="${1%/}"
    [[ "$url" == http://* || "$url" == https://* ]] || url="http://$url"
    [[ "$url" == */v1 ]] || url="$url/v1"
    printf '%s' "$url"
}

local_endpoint() {
    local raw
    if [[ -n "${LOCAL_ENDPOINT:-}" ]]; then
        raw="$LOCAL_ENDPOINT"
    elif [[ -n "${OLLAMA_HOST:-}" ]]; then
        raw="$OLLAMA_HOST"
    elif [[ -r "$OLLAMA_HOST_FILE" && -s "$OLLAMA_HOST_FILE" ]]; then
        raw="$(<"$OLLAMA_HOST_FILE")"
    else
        raw="localhost:11434"
    fi
    normalize_endpoint "$raw"
}

list_models() {
    curl -s --max-time "$CURL_TIMEOUT" "$1/models" 2>/dev/null \
        | jq -r '.data[]?.id // empty' 2>/dev/null || true
}

model_context_length() {
    curl -s --max-time "$CURL_TIMEOUT" "${1%/v1}/api/show" -d "{\"model\":\"$2\"}" 2>/dev/null \
        | jq -r '.model_info | to_entries[] | select(.key | endswith(".context_length")) | .value' 2>/dev/null \
        | head -1 || true
}

build_provider() {
    local endpoint="$1" host models="{}" model arch context
    shift
    host="${endpoint#http://}"; host="${host#https://}"; host="${host%/v1}"
    for model in "$@"; do
        context="$CONTEXT_LIMIT"
        arch="$(model_context_length "$endpoint" "$model")"
        if [[ "$arch" =~ ^[0-9]+$ && "$arch" -lt "$context" ]]; then
            context="$arch"
        fi
        models="$(jq -n --argjson m "$models" --arg id "$model" \
            --argjson ctx "$context" --argjson out "$OUTPUT_LIMIT" \
            '$m + { ($id): { name: $id, limit: { context: $ctx, output: $out } } }')"
    done
    jq -n --arg host "$host" --arg url "$endpoint" --argjson models "$models" '{
        npm: "@ai-sdk/openai-compatible",
        name: ("Ollama (" + $host + ")"),
        options: { baseURL: $url },
        models: $models
    }'
}

pick_default_model() {
    local existing="$1" current
    shift
    if [[ -n "${OPENCODE_LOCAL_MODEL:-}" ]]; then
        if printf '%s\n' "$@" | grep -qxF -- "$OPENCODE_LOCAL_MODEL"; then
            printf '%s' "$OPENCODE_LOCAL_MODEL"
            return 0
        fi
        pfb warn "  OPENCODE_LOCAL_MODEL=$OPENCODE_LOCAL_MODEL is not served by the endpoint; falling back." >&2
    fi
    current="$(jq -r --arg p "$PROVIDER/" '.model // "" | select(startswith($p)) | ltrimstr($p)' <<<"$existing")"
    if [[ -n "$current" ]] && printf '%s\n' "$@" | grep -qxF -- "$current"; then
        printf '%s' "$current"
    else
        printf '%s' "$1"
    fi
}

build_config() {
    local existing="$1" provider="$2" model="$3"
    jq --arg p "$PROVIDER" --argjson prov "${provider:-null}" --arg model "$model" '
        . + { "$schema": "https://opencode.ai/config.json", autoupdate: false, share: "disabled" }
        | if $prov != null then
            .provider[$p] = $prov
            | .enabled_providers = (((.enabled_providers // []) + [$p]) | unique)
            | .model = ($p + "/" + $model)
          else . end' <<<"$existing"
}

target_config() {
    printf '%s' "$CONFIG_JSON"
}

read_existing() {
    local file="$1"
    [[ -f "$file" ]] || { printf '{}'; return 0; }
    # Strip whole-line // comments, collapse to single line, fix trailing commas
    # before } and ] so jq can parse the result.
    sed -E 's#^[[:space:]]*//.*$##' "$file" | tr '\n' ' ' | sed 's/, *}/}/g; s/, *\]/]/g' | jq -e 'if type == "object" then . else error("not an object") end' 2>/dev/null
}

link_plugin_skills() {
    local skills_dest="$OPENCODE_DIR/skills" skills_dir skill skill_name dest linked=0
    mkdir -p "$skills_dest"
    if [[ -d "$CLAUDE_PLUGIN_CACHE" ]]; then
        while IFS= read -r -d '' skills_dir; do
            for skill in "$skills_dir"/*/; do
                [[ -d "$skill" ]] || continue
                skill_name="$(basename "$skill")"
                dest="$skills_dest/$skill_name"
                [[ -e "$dest" && ! -L "$dest" ]] && { pfb warn "  Skipping non-symlink: $skill_name"; continue; }
                ln -sfn "$skill" "$dest"
                pfb success "  Linked skill: $skill_name"
                (( linked++ )) || true
            done
        done < <(find "$CLAUDE_PLUGIN_CACHE" -mindepth 4 -maxdepth 4 -type d -name "skills" -print0 2>/dev/null)
    fi
    [[ $linked -gt 0 ]] || pfb info "  No plugin skills found in $CLAUDE_PLUGIN_CACHE"
    return 0
}

# ── Phase 2: agents, commands, MCP ──────────────────────────────────────────

bootstrap_agents() {
    # Phase 2: create the standard agent files if they don't already exist.
    bootstrap_agent advisor \
'---
description: Architecture advisor for design decisions and code organization. Uses qwen3.8:27b for heavy thinking.
mode: subagent
model: ollama/qwen3.6:35b-a3b-coding
steps: 16
---

You are an architecture advisor. Focus on design decisions, code organization, and long-term maintainability.

Guidelines:
- Evaluate trade-offs across performance, complexity, and team velocity
- Prefer existing patterns over inventing new ones
- Flag dependencies that couple unrelated subsystems
- When the question is concrete, name files and lines
- If the answer requires deep analysis, say so and break the work into steps

Do not write code. Recommend, do not implement.
'

    bootstrap_agent reviewer \
'---
description: Read-only reviewer focused on correctness, security, and testing gaps.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "git status"
    effect: allow
  - action: shell
    resource: "git diff * --cached"
    effect: allow
  - action: shell
    resource: "git diff * --"
    effect: allow
  - action: shell
    resource: "git log --oneline *"
    effect: allow
  - action: read
    resource: "*"
    effect: allow
  - action: shell
    resource: "*"
    effect: deny
  - action: edit
    resource: "*"
    effect: deny
---

You are a code reviewer. Focus on correctness, security, and testing gaps.

Review the provided changes and report findings in severity order (critical, high, medium, low):
- **Critical:** data loss, security vulnerabilities, breaking changes
- **High:** incorrect behavior, missing error handling, race conditions
- **Medium:** style violations against existing project standards, missing edge cases
- **Low:** suggestions for clarity, minor optimisations

Reference specific files and line numbers. Do not suggest changes unless the defect is critical — report, do not fix.
'

    bootstrap_agent ux-tester \
'---
description: UX/UI tester for terminal apps and frontend interfaces. Loads the tui-ux-tester skill.
mode: all
steps: 12
---

You are a UX tester specializing in terminal interfaces and frontend designs.

Use the tui-ux-tester skill when reviewing terminal UIs. Evaluate:
- Navigation flow and discoverability
- Keyboard shortcut ergonomics (no more than 2 levels deep)
- Color contrast and information density
- Onboarding clarity (first run should produce value in under 30 seconds)
- Layout consistency across terminals and sizes

Use the frontend-design skill when reviewing web UIs. Evaluate:
- Visual hierarchy and spacing
- Typography choices and consistency
- Component reusability vs over-engineering
- Loading states and error handling UX

Reference real examples. Avoid generic "looks good" feedback. Be specific about what to change.
'
}

bootstrap_agent() {
    local name="$1" content
    content="$2"
    local file
    file="$AGENTS_DIR/${name}.md"
    if [[ -e "$file" || -L "$file" ]]; then
        return 0
    fi
    mkdir -p "$AGENTS_DIR"
    if [[ -f "$file" && ! -L "$file" ]]; then
        backup_if_exists "$file"
    fi
    printf '%s\n' "$content" > "$file"
    pfb success "  Wrote agent: $name"
}

bootstrap_commands() {
    # Phase 2: create the standard command files if they don't already exist.
    bootstrap_command review \
'---
description: Review the staged diff for correctness, security, and missing tests.
---
Review the staged diff for correctness, security, and missing tests.

!`git diff --cached --stat && echo && git diff --cached --`'

    bootstrap_command triage \
'---
description: Triage a GitHub issue — label, assign, find duplicates, suggest next action.
model: ollama/qwen3.8:27b
agent: plan
---
Review this issue and triage it:

!`gh issue view $1 --json title,body,labels,state,assignees,reactions,comments`

Label if appropriate, suggest next action, and check for duplicates.'

    bootstrap_command status \
'---
description: Produce a workspace status snapshot.
---
Produce a workspace status snapshot: branch, uncommitted changes, recent commits, dependency state.

!`git branch --show-current && echo && git status --short && echo && git log --oneline -10 && echo && ls -la node_modules/.package-lock.json 2>/dev/null | head -3 || echo "No node_modules lock"`'

    bootstrap_command commit-msg \
'---
description: Generate a conventional commit message from the staged diff.
---
Generate a conventional commit message for the staged changes:

!`git diff --cached --stat && echo && git diff --cached --`

Follow Conventional Commits: type(scope): description
Types: feat, fix, chore, docs, refactor, test, style, perf
Scope: the affected subsystem or file group (optional).'
}

bootstrap_command() {
    local name="$1" content
    content="$2"
    local file
    file="$COMMANDS_DIR/${name}.md"
    if [[ -e "$file" || -L "$file" ]]; then
        return 0
    fi
    mkdir -p "$COMMANDS_DIR"
    if [[ -f "$file" && ! -L "$file" ]]; then
        backup_if_exists "$file"
    fi
    printf '%s\n' "$content" > "$file"
    pfb success "  Wrote command: $name"
}

bootstrap_mcp() {
    # Hindsight is a machine-specific server (192.168.1.63:8888 on the Studio).
    # Not bootstrapped automatically — the user adds it with:
    #   opencode mcp add hindsight --url http://192.168.1.63:8888/mcp/health/ --transport streamable-http
    # The API key is in ~/.hindsight/api_key and is used via authorization header.
    # See carrybag-lite/claude/register-hindsight-mcp.sh for the Claude Code equivalent.
    pfb info "  Hindsight MCP not auto-configured; see carrybag-lite/claude/register-hindsight-mcp.sh"
}

write_config() {
    local target existing endpoint provider="" model="" new
    local -a models=()
    target="$(target_config)"
    if ! existing="$(read_existing "$target")"; then
        pfb error "Cannot parse $target as JSON. Whole-line // comments are fine; inline comments and trailing commas are not. Fix it or move it aside, then rerun."
        return 2
    fi

    endpoint="$(local_endpoint)"
    while IFS= read -r line; do [[ -n "$line" ]] && models+=("$line"); done < <(list_models "$endpoint")
    if [[ ${#models[@]} -gt 0 ]]; then
        model="$(pick_default_model "$existing" "${models[@]}")"
        provider="$(build_provider "$endpoint" "${models[@]}")"
    else
        pfb warn "  No Ollama models at $endpoint; writing baseline without a local provider."
        pfb warn "  Set LOCAL_ENDPOINT, OLLAMA_HOST or ~/.config/ollama_host and rerun to add one."
    fi

    new="$(build_config "$existing" "$provider" "$model")"
    if [[ -f "$target" && "$(cat "$target")" == "$new" ]]; then
        pfb info "  $(basename "$target") already up to date"
        return 0
    fi
    backup_if_exists "$target"
    printf '%s\n' "$new" > "$target"
    if [[ -n "$provider" ]]; then
        pfb success "  Wrote $(basename "$target") ($PROVIDER/$model default; ${#models[@]} model(s) via $endpoint)"
        pfb info "  Change the default with OPENCODE_LOCAL_MODEL=<id> $(basename "$0"), or /models inside opencode"
    else
        pfb success "  Wrote $(basename "$target") (baseline)"
    fi
}

main() {
    pfb heading "Installing OpenCode configuration" "🤖"
    echo

    if [[ ! -f "$SOURCE" ]]; then
        pfb error "Source not found: $SOURCE"
        exit 1
    fi
    local tool
    for tool in curl jq; do
        if ! type "$tool" >/dev/null 2>&1; then
            pfb error "$tool is required to write opencode.json. Install it (brew install $tool / apt install $tool) and rerun."
            exit 1
        fi
    done

    mkdir -p "$OPENCODE_DIR"

    # -- symlink AGENTS.md --
    backup_if_exists "$AGENTS_LINK"
    ln -sfn "$SOURCE" "$AGENTS_LINK"
    pfb success "  Linked AGENTS.md"

    # -- Phase 2: agents --
    bootstrap_agents

    # -- Phase 2: commands --
    bootstrap_commands

    # -- Phase 2: MCP (optional) --
    bootstrap_mcp

    # -- link plugin skills --
    link_plugin_skills

    # -- baseline provider config --
    write_config || exit $?

    echo
    pfb success "OpenCode configuration installed!"
    pfb info "  Config location: $OPENCODE_DIR"
    pfb info "  AGENTS.md location: $AGENTS_LINK"
    pfb info "  Source location: $SOURCE"
    pfb info "  Agents: $(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    pfb info "  Commands: $(find "$COMMANDS_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
}

main "$@"
