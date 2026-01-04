#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

for dir in */; do
  [ -d "$dir/.git" ] || continue
  printf 'Updating %s\n' "$dir"
  (
    cd "$dir"
    if ! git ls-remote --exit-code origin >/dev/null 2>&1; then
      printf 'Skipping %s (remote not reachable or repo missing)\n' "$dir"
      exit 0
    fi
    if ! git pull --ff-only; then
      printf 'Skipping %s (pull failed)\n' "$dir"
      exit 0
    fi
  )
done
