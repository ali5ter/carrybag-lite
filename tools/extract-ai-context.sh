#!/usr/bin/env bash
# @file extract-ai-context.sh
# @brief Move AI context files from a public repo into the private ai-context repo.
# @description
#   Given a path to a local git repository, finds all AI context files
#   (CLAUDE.md, AGENTS.md, GEMINI.md), removes them from git tracking,
#   adds them to .gitignore, moves them into the private ai-context repo under
#   a subdirectory named after the source repo, then symlinks them back. Both
#   repos are committed and pushed.
#
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>
# @version 1.1.0
# @date 2026-04-27
# @license MIT
#
# @usage extract-ai-context.sh <path-to-repo>
#
# @dependencies gh, git, pfb (https://github.com/ali5ter/pfb)
#
# @exit 0 Success
# @exit 1 Missing argument, invalid repo path, or AI_CONTEXT_REPO not set
# @exit 2 No AI context files found in target repo
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

# @description Untracks all given AI context files from git and commits .gitignore.
# @param $1 repo_path — absolute path to the target repo
# @param $@ ai_files — one or more filenames to untrack
# @return 0 on success
# @example untrack_from_repo /path/to/repo CLAUDE.md AGENTS.md
untrack_from_repo() {
    local repo_path="$1"; shift
    local files=("$@")

    pfb heading "Updating target repo" "📦"

    local gitignore="$repo_path/.gitignore"
    for ai_file in "${files[@]}"; do
        git -C "$repo_path" rm --cached "$ai_file"
        pfb success "removed $ai_file from git index"

        if ! grep -qxF "$ai_file" "$gitignore" 2>/dev/null; then
            echo "$ai_file" >> "$gitignore"
            pfb success "added $ai_file to .gitignore"
        else
            pfb subheading "$ai_file already in .gitignore"
        fi
    done

    local file_list
    file_list="${files[*]}"
    git -C "$repo_path" add .gitignore
    git -C "$repo_path" commit -m "chore: remove ${file_list// /, } from tracking, add to .gitignore"
    pfb success "committed .gitignore update"
}

# @description Copies all AI context files to the private repo and commits them.
# @param $1 private_dir — path to local clone of the private repo
# @param $2 repo_name — name of the source repo (used as subdirectory)
# @param $3 src_dir_path — directory containing the source files
# @param $@ ai_files — one or more filenames to copy
# @return 0 on success
# @example push_to_private_repo ~/projects/ai-context my-repo /path/to/repo CLAUDE.md AGENTS.md
push_to_private_repo() {
    local private_dir="$1" repo_name="$2" src_dir_path="$3"; shift 3
    local files=("$@")
    local dest_dir="$private_dir/$repo_name"

    pfb heading "Updating private repo" "🔒"

    mkdir -p "$dest_dir"
    for ai_file in "${files[@]}"; do
        cp "$src_dir_path/$ai_file" "$dest_dir/$ai_file"
        pfb success "copied $ai_file to $dest_dir/"
        git -C "$private_dir" add "$repo_name/$ai_file"
    done

    local file_list
    file_list="${files[*]}"
    git -C "$private_dir" commit -m "feat($repo_name): add AI context file(s) ${file_list// /, }"
    git -C "$private_dir" push
    pfb success "pushed to $PRIVATE_REPO"
}

# @description Creates symlinks in the target repo pointing to the private repo copies.
# @param $1 repo_path — directory where symlinks should be created
# @param $2 private_repo_name_dir — directory in the private repo for this source repo
# @param $@ ai_files — one or more filenames to symlink
# @return 0 on success
# @example create_symlinks /path/to/repo /path/to/ai-context/repo CLAUDE.md AGENTS.md
create_symlinks() {
    local repo_path="$1" private_repo_name_dir="$2"; shift 2
    local files=("$@")

    pfb heading "Creating symlinks" "🔗"

    for ai_file in "${files[@]}"; do
        local target="$repo_path/$ai_file"
        local source="$private_repo_name_dir/$ai_file"

        if [[ -f "$target" && ! -L "$target" ]]; then
            local backup="${target}.backup.$(date '+%Y%m%d%H%M%S')"
            mv "$target" "$backup"
            pfb warn "$ai_file backed up to $(basename "$backup")"
        fi

        ln -sf "$source" "$target"
        pfb success "$ai_file → $source"
    done
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

    # Collect all AI context files that are regular files (not already symlinks)
    local found_files=()
    local already_linked=()
    for candidate in "${AI_FILES[@]}"; do
        if [[ -L "$repo_path/$candidate" ]]; then
            already_linked+=("$candidate")
        elif [[ -f "$repo_path/$candidate" ]]; then
            found_files+=("$candidate")
        fi
    done

    for f in "${already_linked[@]+"${already_linked[@]}"}"; do
        pfb warn "$f is already a symlink — skipping"
    done

    if [[ ${#found_files[@]} -eq 0 ]]; then
        if [[ ${#already_linked[@]} -gt 0 ]]; then
            pfb info "all AI context files already extracted"
            exit 0
        fi
        pfb error "no AI context files found in $repo_path (looked for: ${AI_FILES[*]})"
        exit 2
    fi

    pfb info "found: ${found_files[*]}"

    # Ensure private repo is available locally
    local private_dir
    private_dir="$(private_repo_dir)"

    untrack_from_repo "$repo_path" "${found_files[@]}"
    push_to_private_repo "$private_dir" "$repo_name" "$repo_path" "${found_files[@]}"
    create_symlinks "$repo_path" "$private_dir/$repo_name" "${found_files[@]}"
    push_target_repo "$repo_path"

    pfb heading "Done" "✅"
    pfb subheading "run 'cd $private_dir && ./install.sh' on any new machine to restore symlinks"
}

main "$@"
