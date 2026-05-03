# Custom statusline

A custom status line for Claude Code that surfaces what you actually want to see at a glance, every turn. Renders as a single line at the bottom of the chat window:

```
user │ …/dir │ branch +*?  │ vX.Y.Z │ HH:MM │ [Model] N% │ $cost │ 5h: N%
```

## What each segment shows

| Segment | Source | Notes |
|---|---|---|
| `user` | `$USER` env / `whoami` | Pale sky |
| `…/dir` | `workspace.current_dir` from stdin | Shows last path component only — keeps the line short |
| `branch +*?` | `git` in cwd | `+` staged, `*` modified, `?` untracked. Combine: `+*?` = all three |
| `vX.Y.Z` | `version` from stdin | Claude Code release |
| `HH:MM` | `date` | Local time |
| `[Model] N%` | `model.display_name` + `context_window.used_percentage` | Color thresholds: green <70, yellow <90, red ≥90 |
| `$cost` | `cost.total_cost_usd` | Session cost so far |
| `5h: N%` | `rate_limits.five_hour.used_percentage` | Five-hour rate-limit usage; same color thresholds |

## Why this matters

The default status line shows model + cost. That's the bare minimum. The custom line adds:

- **Branch + dirty markers** at a glance — catches "wait, am I on `main`?" before an edit fires.
- **Context window % with color thresholds** — yellow at 70% is your cue to wrap up the current line of investigation; red at 90% means consolidate or `/clear`.
- **5-hour rate-limit %** — knowing you're at 80% before sending the next big message lets you defer instead of getting blocked mid-task.

## Dependencies

- `jq` (parses the JSON Claude Code pipes to stdin)
- `git` (optional — segment hidden if cwd isn't a repo)
- A terminal that renders 24-bit truecolor (modern macOS Terminal, iTerm2, Alacritty, Kitty, Wezterm, Ghostty, recent Linux distros — all fine)

## Wiring

The starter template's `.claude/settings.json` already wires this in:

```json
"statusLine": {
  "type": "command",
  "command": "bash __PROJECT_ROOT__/tools/statusline/statusline.sh",
  "padding": 0
}
```

`__PROJECT_ROOT__` is rewritten by the setup command in the root README. After setup, restart Claude Code so it re-reads `settings.json` and the new statusline takes effect.

## Customizing the palette

Lines 19-30 of `statusline.sh` hold the ocean theme. Each color is an ANSI 24-bit truecolor escape (`\033[38;2;R;G;Bm`). Swap in your own RGB values — the rest of the script is theme-agnostic.

Common alternatives:
- Solarized: deeper blue background (#002b36), warm yellow accents
- Gruvbox: muted browns + pale greens
- Catppuccin Mocha: dark mauve background, lavender highlights

## Reference

Schema for the stdin JSON Claude Code pipes in: <https://code.claude.com/docs/en/statusline>.
