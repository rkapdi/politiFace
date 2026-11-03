#!/bin/sh
# Starts one piece of work in its own worktree, branched from the latest
# main, so it cannot pick up half-finished changes from anything else.
#
#   scripts/new-task.sh fix/endless-timer
#
# Then work in .claude/worktrees/<name>, open one PR for that one change,
# and remove the worktree once it merges:
#   git worktree remove .claude/worktrees/<name>
set -eu

branch="${1:-}"
case "$branch" in
  */*) ;;
  *)
    echo "usage: scripts/new-task.sh <kind>/<name>   e.g. fix/endless-timer, feat/fcle-review" >&2
    exit 1
    ;;
esac

# The main checkout, even when run from inside another worktree.
root="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
dir="$root/.claude/worktrees/${branch#*/}"

git fetch --quiet origin main
git worktree add --no-track -b "$branch" "$dir" origin/main
echo
echo "Ready: $dir (branch $branch, from origin/main $(git rev-parse --short origin/main))"
echo "Before pushing: scripts/check-app.sh"
