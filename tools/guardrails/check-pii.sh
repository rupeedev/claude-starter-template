#!/usr/bin/env bash
# check-pii.sh — block real-looking UUIDs and personal-domain emails from
# landing in committed content. Companion to .githooks/pre-commit.
#
# What's flagged:
#   - UUIDs that aren't in the dummy allowlist (00000000-..., xxxxxxxx-...,
#     deadbeef-..., 11111111-..., 12345678-...) — i.e. real workspace /
#     team / sprint / task UUIDs that leaked into docs or notes.
#   - Email addresses on a curated list of personal domains (gmail.com,
#     outlook.com, yahoo.com, hotmail.com, icloud.com).
#
# What's NOT flagged:
#   - The DUMMY_UUID_ALLOWLIST below — well-known placeholder UUIDs used in
#     examples and templates.
#   - Files in the FILE_ALLOWLIST below — operational config that
#     legitimately needs real UUIDs (e.g. teams-config.json with workspace
#     UUIDs needed by local scripts; these are also gitignored).
#
# Usage:
#   bash check-pii.sh --cached            # check staged content (pre-commit)
#   bash check-pii.sh --range BASE HEAD   # check a commit range (CI)
#
# Exit 0 if no violations, 1 if any. Output names the offending file +
# sample matches so the operator can run a redaction pass and re-stage.
set -euo pipefail

# --- Tune these per project ---

# Dummy UUID prefixes that are always allowed (placeholders in examples).
DUMMY_UUID_PATTERNS=(
  '00000000-0000-0000-0000-000000000000'
  'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
  '11111111-1111-1111-1111-111111111111'
  '12345678-1234-1234-1234-123456789012'
  'deadbeef-dead-beef-dead-beefdeadbeef'
)

# Files / dirs allowed to contain real UUIDs (gitignored config, etc).
# Glob patterns matched against repo-relative path.
FILE_ALLOWLIST=(
  '.gitignore'
  'tools/guardrails/check-pii.sh'   # this file references its own examples
)

# Personal-email domains to block (extend per project).
PERSONAL_DOMAINS_REGEX='@(gmail|outlook|yahoo|hotmail|icloud|live|protonmail)\.com'

# --- Mode parsing ---

mode=""
case "${1:-}" in
  --cached)
    mode=cached
    ;;
  --range)
    mode=range
    base="${2:-}"
    head="${3:-HEAD}"
    [ -z "$base" ] && { echo "usage: check-pii.sh --range BASE HEAD" >&2; exit 2; }
    ;;
  *)
    echo "usage: check-pii.sh --cached | --range BASE HEAD" >&2
    exit 2
    ;;
esac

cd "$(git rev-parse --show-toplevel)"

# Build the changed-file list.
if [ "$mode" = cached ]; then
  files=$(git diff --cached --name-only --diff-filter=ACMR)
else
  files=$(git diff --name-only --diff-filter=ACMR "$base" "$head")
fi

[ -z "$files" ] && exit 0

# Build a regex from FILE_ALLOWLIST (pipe-joined).
allow_pat=$(printf '%s\n' "${FILE_ALLOWLIST[@]}" | tr '\n' '|' | sed 's/|$//; s/\./\\./g')

# Build a regex from DUMMY_UUID_PATTERNS for filtering matches.
dummy_pat=$(printf '%s\n' "${DUMMY_UUID_PATTERNS[@]}" | tr '\n' '|' | sed 's/|$//')

violations=0
violations_log=""

for f in $files; do
  [ -f "$f" ] || continue
  # Skip allowlisted files.
  echo "$f" | grep -Eq "^($allow_pat)$" && continue
  # Skip binary files.
  file --mime "$f" 2>/dev/null | grep -q 'charset=binary' && continue

  # Get the staged content (cached mode) or current working tree (range mode).
  if [ "$mode" = cached ]; then
    content=$(git show ":$f" 2>/dev/null || true)
  else
    content=$(cat "$f" 2>/dev/null || true)
  fi

  # 1) UUID check — strip dummies first, then match anything UUID-shaped.
  uuids=$(echo "$content" \
    | grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
    | grep -viE "$dummy_pat" \
    | sort -u || true)
  if [ -n "$uuids" ]; then
    violations=$((violations+1))
    violations_log+=$'\n  '"$f"$'\n    UUID(s):\n'
    while IFS= read -r u; do
      [ -z "$u" ] && continue
      violations_log+="      $u"$'\n'
    done <<< "$uuids"
  fi

  # 2) Personal-email check.
  emails=$(echo "$content" \
    | grep -oiE "[A-Za-z0-9._%+-]+$PERSONAL_DOMAINS_REGEX" \
    | sort -u || true)
  if [ -n "$emails" ]; then
    violations=$((violations+1))
    violations_log+=$'\n  '"$f"$'\n    Personal email(s):\n'
    while IFS= read -r e; do
      [ -z "$e" ] && continue
      violations_log+="      $e"$'\n'
    done <<< "$emails"
  fi
done

if [ "$violations" -gt 0 ]; then
  cat >&2 <<EOF
BLOCKED: refusing to allow real UUIDs / personal-domain emails in committed content.
$violations_log
Fix:
  1. Replace real UUIDs with a dummy from the allowlist (xxxxxxxx-...).
  2. Replace personal emails with @example.com or remove.
  3. Or: if the path genuinely needs the value (e.g. operational config
     that's also gitignored), add it to FILE_ALLOWLIST in
     tools/guardrails/check-pii.sh with a 1-line rationale comment.
EOF
  exit 1
fi

exit 0
