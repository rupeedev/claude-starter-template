#!/bin/bash
# PreToolUse:Edit/Write hook — BLOCKS bare grid-cols-N (N>=2) and bare
# w-[Npx] without a mobile-first cascade in .tsx/.jsx files.
#
# Why: ESLint and Prettier don't inspect Tailwind class strings for
# responsive coverage, so mobile-rendering regressions slip through normal
# lint. This hook closes the gap for the two most-common offenders. Once
# you have a Tailwind ESLint plugin configured, this hook can be removed.
#
# Patterns blocked:
#   1. className="...grid-cols-[2-9]..." with no grid-cols-1 in the same string
#      Example bad:  className="grid grid-cols-3 gap-4"
#      Example good: className="grid grid-cols-1 sm:grid-cols-3 gap-4"
#
#   2. className="...w-[<digits>px]..." with no sm:max-w-/sm:w- variant
#      Example bad:  className="w-[260px]"
#      Example good: className="w-full sm:max-w-[260px]"
#
# False-positive escape hatch: add the literal comment {/* responsive-ok */}
# on the same line as the class string. Use sparingly — every escape hatch
# is a future bug.
#
# Non-tsx/jsx files exit silently.

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

# Only React/JSX files
case "$file_path" in
  *.tsx|*.jsx) : ;;
  *) exit 0 ;;
esac

# Edit gives new_string; Write gives content; MultiEdit fans out via Edit calls
content=$(echo "$input" | jq -r '.tool_input.new_string // .tool_input.content // ""')
[ -z "$content" ] && exit 0

# ──────────────────────────────────────────────────────────────────────
# Check 1: bare grid-cols-[2-9] without grid-cols-1 (mobile-first miss)
# ──────────────────────────────────────────────────────────────────────
grid_violations=$(echo "$content" \
  | grep -nE 'className=["`][^"`]*\bgrid-cols-[2-9][^"`]*["`]' \
  | grep -v 'grid-cols-1' \
  | grep -v 'responsive-ok')

# ──────────────────────────────────────────────────────────────────────
# Check 2: bare w-[Npx] without a sm: variant on the same line
# ──────────────────────────────────────────────────────────────────────
width_violations=$(echo "$content" \
  | grep -nE 'className=["`][^"`]*\bw-\[[0-9]+px\][^"`]*["`]' \
  | grep -vE '(sm|md|lg|xl):(max-)?w-' \
  | grep -v 'responsive-ok')

if [ -n "$grid_violations" ] || [ -n "$width_violations" ]; then
  cat >&2 <<EOF
BLOCKED: responsive class-string violation in $file_path

CLAUDE.md core rule #2: mobile-first cascade. Multi-column grids must
declare a mobile column count; pixel widths must have a responsive override.

EOF
  if [ -n "$grid_violations" ]; then
    cat >&2 <<EOF
── grid-cols-N without mobile-first cascade ──────────────
$grid_violations

  Bad:  className="grid grid-cols-3 gap-4"
  Good: className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"

EOF
  fi
  if [ -n "$width_violations" ]; then
    cat >&2 <<EOF
── fixed pixel width without responsive override ──────────
$width_violations

  Bad:  className="w-[260px]"
  Good: className="w-full sm:max-w-[260px]"

EOF
  fi
  cat >&2 <<EOF
See: .claude/references/CODING-GUIDELINES.md → "Responsive Design — Mobile-First"

If this is a legitimate exception, append {/* responsive-ok */} to the line.
But please document why in code review — every escape hatch is a future bug.
EOF
  exit 2
fi

exit 0
