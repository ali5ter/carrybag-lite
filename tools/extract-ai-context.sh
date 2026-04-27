#!/usr/bin/env bash
# @file extract-ai-context.sh
# @brief Move an AI context file from a public repo into the private ai-context repo.
# @description
#   Given a path to a local git repository, finds the AI context file
#   (CLAUDE.md, AGENTS.md, or GEMINI.md), removes it from git tracking,
#   adds it to .gitignore, moves it into the private ai-context repo under
#   a subdirectory named after the source repo, then symlinks it back. Both
#   repos are committed and pushed.
#
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 1.0.0
# @date 2026-04-27
# @license MIT
#
# @usage extract-ai-context.sh <path-to-repo>
#
# @dependencies gh, git, pfb (https://github.com/ali5ter/pfb)
#
# @exit 0 Success
# @exit 1 Missing argument or invalid repo path
# @exit 2 No AI context file found in target repo
# @exit 3 Private ai-context repo could not be located or cloned

set -euo pipefail

# Set AI_CONTEXT_REPO to your private repo (e.g. "your-username/ai-context").
# See https://github.com/ali5ter/ai-context-template to create one from the template.
PRIVATE_REPO="${AI_CONTEXT_REPO:-}"
AI_FILES=(CLAUDE.md AGENTS.md GEMINI.md)

# pfb stub — used only when pfb is unavailable
type pfb >/dev/null 2>&1 || pfb() {
    local cmd="${1:-}"; shift || true
    case "$cmd" in
        heading)    echo -e "\n▶ $*" ;;
        subheading) echo -e "  $*" ;;
        info)       echo -e "  ℹ $*" ;;
        success)    echo -e "  ✓ $*" ;;
        warn)       echo -e "  ⚠ $*" ;;
        error)      echo -e "  ✗ $*" >&2 ;;
        *)          echo -e "  $*" ;;
    esac
}

# @description Returns the platform-appropriate projects root directory.
# @return Prints the path to stdout
# @example src_dir
src_dir() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "$HOME/Documents/projects"
    else
        echo "$HOME/src"
    fi
}

# @description Ensures the private ai-context repo is cloned locally.
# @return Prints the local path to the private repo on stdout
# @exit 3 if clone fails
# @example private_repo_dir
private_repo_dir() {
    local dir
    dir="$(src_dir)/ai-context"
    if [[ ! -d "$dir/.git" ]]; then
        pfb info "cloning $PRIVATE_REPO to $dir"
        gh repo clone "$PRIVATE_REPO" "$dir" || {
            pfb error "failed to clone $PRIVATE_REPO"
            exit 3
        }
    fi
    echo "$dir"
}

# @description Removes an AI context file from git tracking in the target repo.
# @param $1 repo_path — absolute path to the target repo
# @param $2 ai_file — filename to untrack (e.g. CLAUDE.md)
# @return 0 on success
# @example untrack_from_repo /path/to/repo CLAUDE.md
untrack_from_repo() {
    local repo_path="$1" ai_file="$2"

    pfb heading "Updating target repo" "📦"

    # Remove from git index (keep file on disk)
    git -C "$repo_path" rm --cached "$ai_file"
    pfb success "removed $ai_file from git index"

    # Add to .gitignore (idempotent)
    local gitignore="$repo_path/.gitignore"
    if ! grep -qxF "$ai_file" "$gitignore" 2>/dev/null; then
        echo "$ai_file" >> "$gitignore"
        pfb success "added $ai_file to .gitignore"
    else
        pfb subheading "$ai_file already in .gitignore"
    fi

    git -C "$repo_path" add .gitignore
    git -C "$repo_path" commit -m "chore: remove $ai_file from tracking, add to .gitignore"
    pfb success "committed .gitignore update"
}

# @description Copies the AI context file to the private repo and commits it.
# @param $1 private_dir — path to local clone of the private repo
# @param $2 repo_name — name of the source repo (used as subdirectory)
# @param $3 src_file — full path to the AI context file
# @param $4 ai_file — filename (e.g. CLAUDE.md)
# @return 0 on success
# @example push_to_private_repo ~/projects/ai-context my-repo /path/CLAUDE.md CLAUDE.md
push_to_private_repo() {
    local private_dir="$1" repo_name="$2" src_file="$3" ai_file="$4"
    local dest_dir="$private_dir/$repo_name"

    pfb heading "Updating private repo" "🔒"

    mkdir -p "$dest_dir"
    cp "$src_file" "$dest_dir/$ai_file"
    pfb success "copied $ai_file to $dest_dir/"

    git -C "$private_dir" add "$repo_name/$ai_file"
    git -C "$private_dir" commit -m "feat($repo_name): add AI context file $ai_file"
    git -C "$private_dir" push
    pfb success "pushed to $PRIVATE_REPO"
}

# @description Creates a symlink in the target repo pointing to the private repo copy.
# @param $1 target — full path where the symlink should be created
# @param $2 source — full path in the private repo
# @return 0 on success
# @example create_symlink /path/to/repo/CLAUDE.md /path/to/ai-context/repo/CLAUDE.md
create_symlink() {
    local target="$1" source="$2"

    pfb heading "Creating symlink" "🔗"

    # Back up if a regular file still exists at target
    if [[ -f "$target" && ! -L "$target" ]]; then
        local backup="${target}.backup.$(date '+%Y%m%d%H%M%S')"
        mv "$target" "$backup"
        pfb warn "existing file backed up to $(basename "$backup")"
    fi

    ln -sf "$source" "$target"
    pfb success "$(basename "$target") → $source"
}

# @description Pushes any outstanding changes in the target repo.
# @param $1 repo_path — absolute path to the target repo
# @return 0 on success
# @example push_target_repo /path/to/repo
push_target_repo() {
    local repo_path="$1"

    pfb heading "Pushing target repo" "🚀"

    if git -C "$repo_path" push 2>&1; then
        pfb success "pushed"
    else
        pfb warn "push failed — you may need to push manually"
    fi
}

# @description Main entry point.
# @param $1 path — path to the local git repository to process
# @return 0 on success
# @example main /path/to/my-public-repo
main() {
    if [[ $# -lt 1 ]]; then
        pfb error "usage: $(basename "$0") <path-to-repo>"
        exit 1
    fi

    local repo_path
    repo_path="$(cd "$1" && pwd)"

    if [[ ! -d "$repo_path/.git" ]]; then
        pfb error "$repo_path is not a git repository"
        exit 1
    fi

    local repo_name
    repo_name="$(basename "$repo_path")"

    if [[ -z "$PRIVATE_REPO" ]]; then
        pfb error "AI_CONTEXT_REPO is not set — export it before running:"
        pfb error "  export AI_CONTEXT_REPO=\"your-username/ai-context\""
        pfb error "Create a private repo from the template: https://github.com/ali5ter/ai-context-template"
        exit 1
    fi

    pfb heading "extract-ai-context" "🤖"
    pfb subheading "target: $repo_path"

    # Find the AI context file
    local ai_file=""
    for candidate in "${AI_FILES[@]}"; do
        if [[ -f "$repo_path/$candidate" ]]; then
            ai_file="$candidate"
            break
        fi
    done

    if [[ -z "$ai_file" ]]; then
        pfb error "no AI context file found in $repo_path (looked for: ${AI_FILES[*]})"
        exit 2
    fi

    pfb info "found: $ai_file"

    # Ensure private repo is available locally
    local private_dir
    private_dir="$(private_repo_dir)"

    # Check if already extracted
    if [[ -L "$repo_path/$ai_file" ]]; then
        pfb warn "$ai_file is already a symlink — nothing to do"
        exit 0
    fi

    local src_file="$repo_path/$ai_file"

    untrack_from_repo "$repo_path" "$ai_file"
    push_to_private_repo "$private_dir" "$repo_name" "$src_file" "$ai_file"
    create_symlink "$src_file" "$private_dir/$repo_name/$ai_file"
    push_target_repo "$repo_path"

    pfb heading "Done" "✅"
    pfb subheading "run 'cd $private_dir && ./install.sh' on any new machine to restore symlinks"
}

main "$@"
