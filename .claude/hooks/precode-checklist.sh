#!/bin/bash
# PreToolUse:Edit/Write hook — BLOCKS edits on main / master.
#
# Why: a direct edit on the deploy branch can trigger CI and ship half-finished
# work. Force a feature branch first, then merge when ready.
#
# Bypass: if you really need to edit on main (e.g. README typo on a private
# repo with no CI), comment out this hook in .claude/settings.json. Don't
# skip silently with --no-verify; the hook isn't on git, so there's nothing
# to skip.

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

# Don't block edits to files outside any git repo (config files in $HOME, etc.)
[ -z "$file_path" ] && exit 0
target_dir=$(dirname "$file_path")
[ -d "$target_dir" ] || exit 0

# Resolve the repo root for THIS file (handles git worktrees correctly —
# parent-repo branch != worktree branch; using the FILE'S repo root avoids
# false-positives when an agent edits inside an isolated worktree).
repo=$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  cat >&2 <<EOF
BLOCKED: editing $file_path directly on '$branch'.

Pushes to '$branch' typically trigger CI / deploy. A direct edit can ship
half-finished work and burn build minutes on a partial change.

Create a feature branch first:
  git checkout -b <fix|feat>/<short-name>

Then redo the edit. The hook will allow it on any non-main branch.
EOF
  exit 2
fi

exit 0
