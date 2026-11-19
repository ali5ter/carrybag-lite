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
# Phase 3 (v3.3.0): reruns preserve existing per-model limit.context values
#   (an explicit OPENCODE_CONTEXT_LIMIT still wins), and .env.local is sourced
#   before the limit defaults so it can override them (Issue #92).
#
# Parallel architecture (Issue #32): Claude Code owns ~/.claude/ (settings.json,
# hooks, marketplace, statusline). OpenCode owns ~/.config/opencode/ (provider
# config, agents, commands, MCP, skills). Both share CLAUDE.md → AGENTS.md,
# ~/.claude/skills/, and the same Ollama server. OpenCode does not read or
# modify Claude Code's config, and vice versa.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 3.3.0
# Date: 2026-11-19
# License: MIT
#
# Usage: ./opencode/install.sh
#   LOCAL_ENDPOINT=<url> ./opencode/install.sh          # explicit Ollama endpoint
#   OPENCODE_LOCAL_MODEL=<name> ./opencode/install.sh   # preferred Ollama default model
#   LMSTUDIO_ENDPOINT=<url> ./opencode/install.sh       # add an LM Studio provider
#   LMSTUDIO_MODEL=<name> ./opencode/install.sh         # preferred LM Studio model
#   HINDSIGHT_URL=<url>  ./opencode/install.sh          # enable Hindsight MCP
#   OPENCODE_CONTEXT_LIMIT=<tokens> OPENCODE_OUTPUT_LIMIT=<tokens> ./opencode/install.sh
#
# When LMSTUDIO_ENDPOINT is set and serves a model, it becomes the OpenCode default
# (a second provider, id "lmstudio"); Ollama stays a fallback provider. Machines
# without LM Studio (no LMSTUDIO_ENDPOINT) keep the Ollama default unchanged.
#   Backs up any existing file before replacing it; running twice is idempotent.
#   Keys the script does not manage are preserved, as are hand-edited
#   limit.context values (an explicit OPENCODE_CONTEXT_LIMIT wins); comments
#   are stripped before parsing.
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

# Source machine-specific overrides from .env.local (gitignored) *before* the
# limit defaults below, so a .env.local value of OPENCODE_CONTEXT_LIMIT /
# OPENCODE_OUTPUT_LIMIT overrides the built-in default (Issue #92). Also sets
# HINDSIGHT_MCP_URL_DEFAULT for bootstrap_mcp() below.
_env_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/.env.local"
if [[ -r "$_env_file" ]]; then
    # shellcheck source=/dev/null
    source "$_env_file"
fi

CONTEXT_LIMIT="${OPENCODE_CONTEXT_LIMIT:-131072}"
OUTPUT_LIMIT="${OPENCODE_OUTPUT_LIMIT:-32768}"
CURL_TIMEOUT=5

# Result of resolve_default_model(), stashed in globals so the agent/command bootstrap and
# the config write reuse one probe instead of querying the servers twice.
RESOLVED_MODEL=""
DEFAULT_PROVIDER=""
PROVIDER_MERGED_JSON="{}"
# The current opencode.json, read lazily once and shared by build_provider() and the
# default-model pick so a run parses the file a single time.
EXISTING_CONFIG=""

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
    local endpoint="$1" name="$2" provider_id="$3" host models="{}" model arch context existing prev
    shift 3
    host="${endpoint#http://}"; host="${host#https://}"; host="${host%/v1}"
    existing="$(existing_config)"
    for model in "$@"; do
        context="$CONTEXT_LIMIT"
        # A hand-edited limit.context survives a rerun; an explicit
        # OPENCODE_CONTEXT_LIMIT (environment or .env.local) wins over it (Issue #92).
        if [[ -z "${OPENCODE_CONTEXT_LIMIT:-}" ]]; then
            prev="$(jq -r --arg id "$provider_id" --arg m "$model" \
                '(.providers[$id]?.models[$m]?.limit.context? // empty) | tostring' <<<"$existing" 2>/dev/null || true)"
            if [[ "$prev" =~ ^[0-9]+$ ]]; then
                context="$prev"
            fi
        fi
        arch="$(model_context_length "$endpoint" "$model")"
        if [[ "$arch" =~ ^[0-9]+$ && "$arch" -lt "$context" ]]; then
            context="$arch"
        fi
        models="$(jq -n --argjson m "$models" --arg id "$model" \
            --argjson ctx "$context" --argjson out "$OUTPUT_LIMIT" \
            '$m + { ($id): { name: $id, limit: { context: $ctx, output: $out } } }')"
    done
    local display="$name ($host)"
    jq -n --arg name "$display" --arg url "$endpoint" --argjson models "$models" '{
        package: "@opencode/ai/providers/openai-compatible",
        name: $name,
        settings: { baseURL: $url },
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
    local existing="$1" providers="$2" model="$3"
    # Migrate any legacy V1 keys the script used to write, and emit the V2-native
    # shape: `update` (not `autoupdate`), plural `providers` (not singular
    # `provider`), and no `enabled_providers`. Legacy singular providers and
    # top-level V1 keys are folded in before being removed. `providers` is the merged
    # {ollama:{...},lmstudio:{...}} object (possibly empty); `model` is the full
    # "provider/model" default (empty leaves the existing default in place).
    jq --argjson provs "${providers:-"{}"}" --arg model "$model" '
        (.providers // {}) as $base
        | (.provider // {}) as $legacy
        | del(.provider, .autoupdate, .enabled_providers)
        + { "$schema": "https://opencode.ai/config.json", update: "disable", share: "disabled" }
        | .providers = ($base + $legacy + $provs)
        | if $model != "" then .model = $model else . end' <<<"$existing"
}

# Probe the Ollama endpoint and, when LMSTUDIO_ENDPOINT is set, an LM Studio endpoint
# once, build a merged providers object, and pick the default model. Results are stashed
# in the globals declared near the top so the agent/command bootstrap and the config write
# reuse them without a second probe.
#
# Precedence: when LM Studio is configured and serves a model, the default is that model
# (LMSTUDIO_MODEL when named and present, else its first); otherwise the Ollama default,
# honoured from OPENCODE_LOCAL_MODEL, then the config's current choice, then its first.
# This keeps machines without LM Studio on Ollama.
# @return 0
resolve_default_model() {
    local ollama_endpoint lms_endpoint ollama_models=() lms_models=()
    local ollama_json lms_json lms_model existing line

    ollama_endpoint="$(local_endpoint)"
    while IFS= read -r line; do
        [[ -n "$line" ]] && ollama_models+=("$line")
    done < <(list_models "$ollama_endpoint")

    lms_endpoint=""
    if [[ -n "${LMSTUDIO_ENDPOINT:-}" ]]; then
        lms_endpoint="$(normalize_endpoint "$LMSTUDIO_ENDPOINT")"
        while IFS= read -r line; do
            [[ -n "$line" ]] && lms_models+=("$line")
        done < <(list_models "$lms_endpoint")
    fi

    ollama_json="null"
    if [[ ${#ollama_models[@]} -gt 0 ]]; then
        ollama_json="$(build_provider "$ollama_endpoint" "Ollama" "ollama" "${ollama_models[@]}")"
    fi
    lms_json="null"
    if [[ ${#lms_models[@]} -gt 0 ]]; then
        lms_json="$(build_provider "$lms_endpoint" "LM Studio" "lmstudio" "${lms_models[@]}")"
    fi

    PROVIDER_MERGED_JSON="$(jq -n --argjson o "$ollama_json" --argjson l "$lms_json" '
        (if $o != null then {ollama: $o} else {} end)
        + (if $l != null then {lmstudio: $l} else {} end)')"

    if [[ ${#lms_models[@]} -gt 0 ]]; then
        lms_model="${LMSTUDIO_MODEL:-}"
        if [[ -n "$lms_model" ]] && ! printf '%s\n' "${lms_models[@]}" | grep -qxF -- "$lms_model"; then
            pfb warn "  LMSTUDIO_MODEL=$lms_model is not served by $lms_endpoint; using its first model instead." >&2
        fi
        [[ -n "$lms_model" ]] || lms_model="${lms_models[0]}"
        RESOLVED_MODEL="lmstudio/$lms_model"
        DEFAULT_PROVIDER="lmstudio"
    elif [[ ${#ollama_models[@]} -gt 0 ]]; then
        existing="$(read_existing "$(target_config)")"
        RESOLVED_MODEL="ollama/$(pick_default_model "$existing" "${ollama_models[@]}")"
        DEFAULT_PROVIDER="ollama"
    else
        pfb warn "  No models at $ollama_endpoint${lms_endpoint:+ or $lms_endpoint}; writing baseline without a local provider." >&2
        pfb warn "  Set LOCAL_ENDPOINT/OLLAMA_HOST (Ollama) or LMSTUDIO_ENDPOINT (LM Studio) and rerun to add one." >&2
        RESOLVED_MODEL=""
        DEFAULT_PROVIDER=""
    fi
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

existing_config() {
    # The current opencode.json, parsed once per run; {} when absent or unparseable.
    # An unparseable file is still caught in write_config(), which exits 2.
    if [[ -z "$EXISTING_CONFIG" ]]; then
        EXISTING_CONFIG="$(read_existing "$(target_config)" || true)"
        [[ -n "$EXISTING_CONFIG" ]] || EXISTING_CONFIG="{}"
    fi
    printf '%s' "$EXISTING_CONFIG"
}

link_plugin_skills() {
    local skills_dest="$OPENCODE_DIR/skills" skills_dir skill skill_name dest linked=0
    mkdir -p "$skills_dest"

    # The Claude plugin cache can hold more than one version of a plugin after
    # an update. A symlink left pointing at a since-removed version dangles, so
    # prune any destination that no longer resolves before re-linking. Only
    # symlinks are pruned — a real directory a user added is left untouched.
    for dest in "$skills_dest"/*; do
        [[ -L "$dest" && ! -e "$dest" ]] || continue
        rm -f "$dest"
        pfb warn "  Pruned dead skill link: $(basename "$dest")"
    done

    if [[ -d "$CLAUDE_PLUGIN_CACHE" ]]; then
        # Cache layout: <org>/<plugin>/<version>/skills/<skill>. Sort the skill
        # roots and skip any whose skill directory is gone, so the final
        # `ln -sfn` keeps a deterministic live target and a removed version can
        # never dangle a destination.
        while IFS= read -r -d '' skills_dir; do
            for skill in "$skills_dir"/*/; do
                [[ -e "$skill" ]] || continue
                skill_name="$(basename "$skill")"
                dest="$skills_dest/$skill_name"
                [[ -e "$dest" && ! -L "$dest" ]] && { pfb warn "  Skipping non-symlink: $skill_name"; continue; }
                ln -sfn "$skill" "$dest"
                pfb success "  Linked skill: $skill_name"
                (( linked++ )) || true
            done
        done < <(find "$CLAUDE_PLUGIN_CACHE" -mindepth 4 -maxdepth 4 -type d -name "skills" -print0 2>/dev/null | sort -z)
    fi
    [[ $linked -gt 0 ]] || pfb info "  No plugin skills found in $CLAUDE_PLUGIN_CACHE"
    return 0
}

# ── Phase 2: agents, commands, MCP ──────────────────────────────────────────
# Standard agents (advisor, reviewer, ux-tester) + 4 slash commands are
# bootstrapped here. Custom agents and skills live in their own repos
# (e.g. over-50s-health, claude-workflow-skills) with their own
# opencode/ directory; bootstrap there is separate.

bootstrap_agents() {
    # Creates the 3 standard agents + ux-tester skill. Custom agents and skills
    # live in their own repos (over-50s-health, claude-workflow-skills, etc.) —
    # each plugin owns its OpenCode port under an opencode/ dir in that repo.
    # Bootstrap for those is run manually; install.sh only ships the shared defaults.
    # Phase 2: refresh the standard agent files on every run (Carrybag-owned;
    # backup-then-overwrite, see bootstrap_agent).
    bootstrap_agent advisor \
'---
description: Architecture advisor for design decisions and code organization. Uses the default local model for heavy thinking.
mode: subagent
model: {{DEFAULT_MODEL}}
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
    # Substitute the default-model sentinel with the model resolved by
    # resolve_default_model, so each agent follows the machine's default. When no
    # model was resolved, drop the line so the frontmatter stays valid. A `#`
    # delimiter avoids the `/` in "provider/model"; sed is used rather than
    # parameter expansion so the `}}` in the sentinel does not mis-parse.
    if [[ -n "$RESOLVED_MODEL" ]]; then
        content="$(printf '%s\n' "$content" | sed "s#{{DEFAULT_MODEL}}#${RESOLVED_MODEL}#g")"
    else
        content="$(printf '%s\n' "$content" | sed '/{{DEFAULT_MODEL}}/d')"
    fi
    local file="$AGENTS_DIR/${name}.md"
    mkdir -p "$AGENTS_DIR"

    # Carrybag owns these agents and refreshes them on every run, so an update to
    # this script reaches an already-installed agent instead of being skipped. A
    # symlink is dropped (never followed), an already-current file is left alone
    # to avoid churn, and a file with a genuine difference is backed up first.
    [[ -L "$file" ]] && rm -f "$file"
    local tmp
    tmp="$(mktemp)" || return 1
    printf '%s\n' "$content" > "$tmp"
    if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
        rm -f "$tmp"
        pfb info "  Agent up to date: $name"
        return 0
    fi
    [[ -f "$file" ]] && backup_if_exists "$file"
    mv "$tmp" "$file"
    pfb success "  Wrote agent: $name"
    return 0
}

bootstrap_commands() {
    # Phase 2: refresh the standard command files on every run (Carrybag-owned;
    # backup-then-overwrite, see bootstrap_command). Each body is an OpenCode
    # template: its backticks and $1 are literal content, expanded when the
    # command runs, never by the installer. Shellcheck 0.11 mis-reads the
    # backticks in single quotes as expressions, so each call needs the directive.
    # shellcheck disable=SC2016
    bootstrap_command review \
'---
description: Review the staged diff for correctness, security, and missing tests.
---
Review the staged diff for correctness, security, and missing tests.

!`git diff --cached --stat && echo && git diff --cached --`'

    # shellcheck disable=SC2016
    bootstrap_command triage \
'---
description: Triage a GitHub issue — label, assign, find duplicates, suggest next action.
model: {{DEFAULT_MODEL}}
agent: plan
---
Review this issue and triage it:

!`gh issue view $1 --json title,body,labels,state,assignees,reactions,comments`

Label if appropriate, suggest next action, and check for duplicates.'

    # shellcheck disable=SC2016
    bootstrap_command status \
'---
description: Produce a workspace status snapshot.
---
Produce a workspace status snapshot: branch, uncommitted changes, recent commits, dependency state.

!`git branch --show-current && echo && git status --short && echo && git log --oneline -10 && echo && ls -la node_modules/.package-lock.json 2>/dev/null | head -3 || echo "No node_modules lock"`'

    # shellcheck disable=SC2016
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
    # Substitute the default-model sentinel with the resolved model, mirroring
    # bootstrap_agent; drop the line when no model was resolved.
    if [[ -n "$RESOLVED_MODEL" ]]; then
        content="$(printf '%s\n' "$content" | sed "s#{{DEFAULT_MODEL}}#${RESOLVED_MODEL}#g")"
    else
        content="$(printf '%s\n' "$content" | sed '/{{DEFAULT_MODEL}}/d')"
    fi
    local file="$COMMANDS_DIR/${name}.md"
    mkdir -p "$COMMANDS_DIR"

    # Carrybag owns these commands and refreshes them on every run, mirroring
    # bootstrap_agent: drop a symlink, skip an already-current file to avoid
    # churn, and back up any genuine difference before overwriting.
    [[ -L "$file" ]] && rm -f "$file"
    local tmp
    tmp="$(mktemp)" || return 1
    printf '%s\n' "$content" > "$tmp"
    if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
        rm -f "$tmp"
        pfb info "  Command up to date: $name"
        return 0
    fi
    [[ -f "$file" ]] && backup_if_exists "$file"
    mv "$tmp" "$file"
    pfb success "  Wrote command: $name"
    return 0
}

bootstrap_mcp() {
    # Hindsight is machine-specific (Studio URL + API key). Bootstrap reads the key
    # from either the env var or ~/.hindsight/api_key, never committed (see
    # register-hindsight-mcp.sh, which does the same for Claude Code).
    local key
    if [[ -n "${HINDSIGHT_API_KEY:-}" ]]; then
        key="$HINDSIGHT_API_KEY"
    elif [[ -r ~/.hindsight/api_key && -s ~/.hindsight/api_key ]]; then
        key="$(head -1 ~/.hindsight/api_key)"
        key="$(sed -n 's/^HINDSIGHT_API_TENANT_API_KEY=//p;' <<<"$key")"
        key="$(printf '%s' "$key" | tr -d '[:space:]')"
    else
        return 0
    fi
    [[ -z "$key" ]] && return 0

    local existing has_mcp
    existing="$(read_existing "$CONFIG_JSON")"
    has_mcp=$(jq -r 'has("mcp") and (.mcp | has("servers") and (.servers | has("hindsight")))' <<<"$existing")
    if [[ "$has_mcp" == "true" ]]; then
        return 0
    fi

    local mcp_url
    mcp_url="${HINDSIGHT_MCP_URL_DEFAULT:-http://192.168.1.63:8888/mcp/health/}"

    local mcp_block
    mcp_block=$(jq -n --arg url "$mcp_url" '{
        mcp: {
            servers: {
                hindsight: {
                    type: "remote",
                    url: $url,
                    oauth: false,
                    headers: {
                        "Authorization": "Bearer {env:HINDSIGHT_API_KEY}"
                    }
                }
            }
        }
    }')

    local new
    new=$(jq --argjson mcp "$mcp_block" '. + $mcp' <<<"$existing")

    backup_if_exists "$CONFIG_JSON"
    printf '%s\n' "$new" > "$CONFIG_JSON"
    pfb success "  Wrote OpenCode Hindsight MCP server"
}

write_config() {
    local target existing new
    target="$(target_config)"
    if ! existing="$(read_existing "$target")"; then
        pfb error "Cannot parse $target as JSON. Whole-line // comments are fine; inline comments and trailing commas are not. Fix it or move it aside, then rerun."
        return 2
    fi

    new="$(build_config "$existing" "$PROVIDER_MERGED_JSON" "$RESOLVED_MODEL")"
    if [[ -f "$target" && "$(cat "$target")" == "$new" ]]; then
        pfb info "  $(basename "$target") already up to date"
        return 0
    fi
    backup_if_exists "$target"
    printf '%s\n' "$new" > "$target"
    if [[ -n "$RESOLVED_MODEL" ]]; then
        pfb success "  Wrote $(basename "$target") ($RESOLVED_MODEL default via $DEFAULT_PROVIDER)"
        pfb info "  Change the default with LMSTUDIO_ENDPOINT/LMSTUDIO_MODEL (LM Studio) or OPENCODE_LOCAL_MODEL (Ollama), or /models inside opencode"
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

    # -- resolve the default model (probes Ollama, and LM Studio when configured) --
    # Done before the agents/commands so their {{DEFAULT_MODEL}} sentinel resolves.
    resolve_default_model

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

# Run the script if it is being executed directly
[ "${BASH_SOURCE[0]}" -ef "$0" ] && main "$@"
