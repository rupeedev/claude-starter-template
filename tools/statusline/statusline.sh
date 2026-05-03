#!/bin/bash
# Claude Code custom statusline.
# Reads JSON session data from stdin (schema: https://code.claude.com/docs/en/statusline)
# and prints one line: user | dir | branch+dirty | vX.Y.Z | HH:MM | [Model] N% | $cost | 5h: N%
#
# Dirty indicators: + staged, * modified, ? untracked
# Colors via ANSI 24-bit truecolor; rendered with printf '%b' (per Claude Code docs).
set -u
input=$(cat)

j() { jq -r "$1" <<<"$input"; }

# -----------------------------------------------------------------------------
# Palette — ocean theme (deep navy background, light pastel foregrounds)
# -----------------------------------------------------------------------------
RESET='\033[0m'
B='\033[1m'

BG='\033[48;2;8;32;56m'             # deep ocean

USR='\033[38;2;176;220;255m'        # pale sky
SEP_COL='\033[38;2;110;160;200m'    # medium blue
DIR_COL='\033[38;2;120;220;240m'    # bright cyan
BRANCH_COL='\033[38;2;130;230;170m' # mint
DIRTY_COL='\033[38;2;255;220;120m'  # warm yellow
VER_COL='\033[38;2;180;200;220m'    # light slate
TIME_COL='\033[38;2;230;205;160m'   # sand
MODEL_COL='\033[38;2;240;160;230m'  # pink-magenta
COST_COL='\033[38;2;255;215;120m'   # gold
LBL_COL='\033[38;2;160;185;215m'    # muted blue (for "5h:")

# Threshold colors
GRN='\033[38;2;130;230;170m'
YEL='\033[38;2;255;220;120m'
RED='\033[38;2;255;130;130m'

# Pick threshold color for a percentage: green <70, yellow <90, red >=90
threshold_color() {
    local n="${1%%.*}"
    if [ "${n:-0}" -ge 90 ]; then printf '%b' "$RED"
    elif [ "${n:-0}" -ge 70 ]; then printf '%b' "$YEL"
    else printf '%b' "$GRN"
    fi
}

# Re-apply BG after a full reset (use between segments)
SEP=" ${RESET}${BG}${SEP_COL}|${RESET}${BG} "

# -----------------------------------------------------------------------------
# Inputs
# -----------------------------------------------------------------------------
USER_NAME="${USER:-$(whoami)}"
DIR=$(j '.workspace.current_dir // empty')
BASENAME="${DIR##*/}"
DIR_DISPLAY="${BASENAME:+…/$BASENAME}"
[ -z "$DIR_DISPLAY" ] && DIR_DISPLAY="?"

VERSION=$(j '.version // empty')
MODEL=$(j '.model.display_name // "?"')
PCT_RAW=$(j '.context_window.used_percentage // 0')
PCT="${PCT_RAW%%.*}"
COST=$(j '.cost.total_cost_usd // 0')
FIVE_H=$(j '.rate_limits.five_hour.used_percentage // empty')

TIME=$(date +%H:%M)

# Git: only if cwd is a repo
GIT_SEG=""
if [ -n "$DIR" ] && git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
    STAGED=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | awk 'END{print NR}')
    MODIFIED=$(git -C "$DIR" diff --numstat 2>/dev/null | awk 'END{print NR}')
    UNTRACKED=$(git -C "$DIR" ls-files --others --exclude-standard 2>/dev/null | awk 'END{print NR}')
    DIRTY=""
    [ "${STAGED:-0}" -gt 0 ] && DIRTY="${DIRTY}+"
    [ "${MODIFIED:-0}" -gt 0 ] && DIRTY="${DIRTY}*"
    [ "${UNTRACKED:-0}" -gt 0 ] && DIRTY="${DIRTY}?"
    if [ -n "$BRANCH" ]; then
        GIT_SEG="${SEP}${BRANCH_COL}${BRANCH}${RESET}${BG}"
        [ -n "$DIRTY" ] && GIT_SEG="${GIT_SEG} ${DIRTY_COL}${DIRTY}${RESET}${BG}"
    fi
fi

VER_SEG=""
[ -n "$VERSION" ] && VER_SEG="${SEP}${VER_COL}v${VERSION}${RESET}${BG}"

COST_FMT=$(printf '$%.2f' "${COST:-0}")

RATE_SEG=""
if [ -n "$FIVE_H" ]; then
    FIVE_INT=$(printf '%.0f' "$FIVE_H")
    FIVE_COL=$(threshold_color "$FIVE_INT")
    RATE_SEG="${SEP}${LBL_COL}5h:${RESET}${BG} ${FIVE_COL}${FIVE_INT}%${RESET}${BG}"
fi

PCT_COL=$(threshold_color "$PCT")

# Final compose. Pad with spaces inside BG so the bar feels chunky.
printf '%b\n' "${BG} ${USR}${USER_NAME}${RESET}${BG}${SEP}${DIR_COL}${DIR_DISPLAY}${RESET}${BG}${GIT_SEG}${VER_SEG}${SEP}${TIME_COL}${TIME}${RESET}${BG}${SEP}${B}${MODEL_COL}[${MODEL}]${RESET}${BG} ${PCT_COL}${PCT}%${RESET}${BG}${SEP}${COST_COL}${COST_FMT}${RESET}${BG}${RATE_SEG} ${RESET}"
