# Claude Starter Template

Minimum-viable scaffold for a new project that uses Claude Code as the primary
development agent. A small set of files (YAML + bash + markdown) that encode
one core principle: **enforcement belongs at edit-time (hooks), not at
review-time (memory + docs)**.

## What you get

```
.
├── CLAUDE.md                              ← thin index, ~100 lines
├── .claude/
│   ├── settings.json                      ← wires up the hooks + permissions
│   ├── hooks/
│   │   ├── precode-checklist.sh           ← BLOCKS edits on main / master
│   │   ├── responsive-classcheck.sh       ← BLOCKS bare grid-cols-N in tsx/jsx
│   │   └── limit-bump-investigate-first.sh ← ADVISES on CI/IaC limit bumps (three-paths framework)
│   ├── commands/
│   │   ├── ready-to-code.md               ← /ready-to-code — five-question gate
│   │   └── ship.md                        ← /ship — lint → commit → merge → deploy
│   └── references/
│       ├── CODING-GUIDELINES.md           ← starter rules; expand per project
│       └── three-paths.md                 ← decision-making framework for obstacles
├── .githooks/                             ← per-machine git guardrails (activated by installer)
│   ├── pre-commit                         ← runs check-pii.sh against staged content
│   └── pre-push                           ← project-specific gates (smoke test, etc.)
├── tools/
│   ├── guardrails/
│   │   ├── check-pii.sh                   ← block real UUIDs + personal-domain emails
│   │   └── install-git-hooks.sh           ← activates .githooks per machine
│   └── statusline/
│       ├── statusline.sh                  ← custom status line (branch · context % · cost · 5h limit)
│       └── README.md                      ← what each segment shows + customizing the palette
└── README.md (this file)
```

## What is intentionally **NOT** here

A starter should not pre-bake patterns the project hasn't earned yet. Add these
when the project warrants — not before:

- `FILE-MAP.md` — fill in once your codebase has paths to map
- `TECHSTACK.md` — fill in once you've picked the stack
- `CODEBASE-GAPS.md` — fill in when you find the first gap
- `ui-patterns/*.md` — write per-pattern when you actually need one
- A custom ESLint / Tailwind responsive lint plugin
- Playwright responsive snapshots
- Slash commands like `/audit-mobile`, `/diff-gaps`, `/feature-dev` skill
- A wiki / incident log

Add them when the project warrants — not before.

## Setup (one shell command)

After copying this template into a new repo, run:

```bash
ROOT="$(pwd)" \
  && find .claude -type f \( -name '*.json' -o -name '*.sh' \) \
       -exec sed -i '' "s|__PROJECT_ROOT__|$ROOT|g" {} + \
  && chmod +x .claude/hooks/*.sh tools/guardrails/*.sh .githooks/pre-commit .githooks/pre-push \
  && bash tools/guardrails/install-git-hooks.sh \
  && echo "✓ paths rewritten, hooks executable, local guardrails activated"
```

(GNU `sed` users: drop the `''` after `-i`.)

This rewrites the `__PROJECT_ROOT__` placeholder in `settings.json` so the
hook command paths resolve, marks every script executable, and activates
the per-machine local guardrails (sets `core.hooksPath = .githooks`).

If you ever move the repo, re-run the same command. If a contributor clones
fresh, they need to run `bash tools/guardrails/install-git-hooks.sh` (the
git-config side won't carry across machines).

## Verifying the hooks fire

Restart Claude Code (so it re-reads `.claude/settings.json`), then:

1. **`precode-checklist.sh`** — try `Edit` on any file while on `main`. The
   hook should `BLOCK` and tell you to branch.
2. **`responsive-classcheck.sh`** — try `Edit`-ing a `.tsx` file with
   `className="grid grid-cols-3 gap-4"` (no responsive cascade). The hook
   should `BLOCK` and point at CODING-GUIDELINES.md.

If either fails to fire, check `.claude/settings.json` paths and that the
hook scripts have execute bit (`ls -l .claude/hooks/`).

## How to evolve

- **Found a bug pattern that lint missed?** → add an `if` branch to
  `responsive-classcheck.sh` (or a sibling hook). Each new check is ~10 lines.
- **Found yourself repeating the same multi-step workflow?** → add a slash
  command in `.claude/commands/<name>.md`. Treat the existing two
  (`ready-to-code`, `ship`) as templates.
- **Found a project-specific rule that keeps biting?** → add it to
  `.claude/references/CODING-GUIDELINES.md`, NOT to `CLAUDE.md`. Keep
  CLAUDE.md thin (under 200 lines) — it's an index.
- **Operational fact you keep telling Claude?** (deploy command, AWS profile,
  active sprint lookup) → save to memory via the auto-memory system or in a
  `~/.claude/projects/<repo>/memory/` file. Don't put it in CLAUDE.md.

## Decision-making paths

Every obstacle the agent faces — failing CI run, error response, slow build,
flaky test — is solved via one of three paths. The choice is usually
unconscious; the goal of `.claude/references/three-paths.md` is to make it
conscious. Summary:

| Path | Reflex | When |
|---|---|---|
| **1 — Least cognitive resistance** | See error → match symptom to nearest config knob → ship the knob (e.g. bump `timeout-minutes`, add `--retries`, swallow the 500). | **Never the right answer.** Tells: pattern-matching to the limit name; writing "investigate later" while shipping a workaround. |
| **2 — Investigate then decide** | 5-step loop: frame falsifiable question → cheapest signal that answers it → compare against baseline → check domain clichés → decide. ~3 min, same wall-clock as the band-aid. | **Default.** When the framing question is obvious. |
| **3a — Rewire the reflex** | Notice the pull toward Path 1 BEFORE it fires; run framing questions before reaching for any tool. Mental discipline only — no commit ships from this path. | When you catch yourself reaching for a config knob without framing a question. |
| **3b — Question the premise** | The CLASS of problem is the bug, not the instance. File a "rethink X" ticket; redesign the system. | When the same fire keeps recurring across multiple tickets. |

**Limits are detectors, not the disease.** Bumping a limit silences the alarm without fixing the underlying waste. The cost compounds invisibly.

### The hook: `limit-bump-investigate-first.sh`

Fires (advisory, not blocking) when an `Edit` / `Write` / `MultiEdit` is about to touch a CI / IaC / deploy-config file in a way that involves a known limit identifier. Injects the 5-step framing as `additionalContext` so the question gets asked first.

- **File-path triggers:** `.github/workflows/*.yml`, `Dockerfile*`, `*.tf` / `*.tfvars`, `*.cdk.{ts,js}`, `task-definition*.json`, `serverless.{yml,json}`, `deploy*.yml`.
- **Content tokens:** `timeout-minutes`, `timeout:`, `--timeout`, `--max-time`, `MemorySize`, `Memory:`, `memory:`, `memory_mb`, `--max-attempts`, `MaxRetries`, `max_retries`, `cpu:`, `ulimit`, `RAM_GB`, `disk:`, `storage:`, `MemoryLimit`.
- **Per-session per-file dedup** so the reminder fires once per file per session.

Customize the patterns in `.claude/hooks/limit-bump-investigate-first.sh` as your stack adds new limit identifiers (Lambda's `Timeout` separate from `--timeout`, K8s `resources.limits`, etc.).

Full framework: [`.claude/references/three-paths.md`](.claude/references/three-paths.md).

---

## Guardrails (local pre-commit, not CI-only)

A second line of defense that complements PreToolUse hooks: **git pre-commit hooks** that block bad content from leaving the dev machine in the first place. CI guardrails are useful as a backstop, but by the time CI runs, the data has already pushed to GitHub — even a green CI guardrail can't unleak a real UUID or PII that landed in a commit.

### What ships

```
.githooks/
  pre-commit         ← runs check-pii.sh --cached on every commit
  pre-push           ← project-specific gates (curl-smoke, integration tests)
tools/guardrails/
  check-pii.sh       ← blocks real UUIDs + personal-domain emails
  install-git-hooks.sh ← per-machine activation (sets core.hooksPath)
```

### Per-machine activation

Pre-commit hooks are NOT activated by default after a `git clone` — git's design defers that decision to each contributor's machine. After cloning this template:

```bash
bash tools/guardrails/install-git-hooks.sh
```

This sets `core.hooksPath = .githooks` in the repo's local git config and `chmod +x` the hooks. One-time per machine. Idempotent.

Add a "First-time setup" line to your project README pointing at this command, so contributors know to run it.

### What `check-pii.sh` catches

- **Real-looking UUIDs** — anything matching the standard UUID format that ISN'T in the dummy allowlist (`xxxxxxxx-xxxx-...`, `00000000-0000-...`, `deadbeef-...`, `12345678-...`, `11111111-...`). Catches workspace / team / sprint / task UUIDs that leaked into docs, notes, or commit messages.
- **Personal-domain emails** — `@gmail.com`, `@outlook.com`, `@yahoo.com`, `@hotmail.com`, `@icloud.com`, `@live.com`, `@protonmail.com` (extend `PERSONAL_DOMAINS_REGEX` per project).

What it does NOT catch (extend the script if your project needs them):
- API keys / secrets — use `git-secrets` or `gitleaks` alongside.
- Credit cards / SSNs — out of scope for a starter template.
- Project-specific identifiers (e.g. customer IDs).

### File allowlist

Some files legitimately need real UUIDs (operational config that's gitignored, or this script itself which references its dummy patterns). Add them to `FILE_ALLOWLIST` in `tools/guardrails/check-pii.sh` with a 1-line rationale comment.

### The lint-staged trap

If your project uses `lint-staged` and runs Prettier / ESLint / similar in pre-commit, watch for this footgun: a misconfigured glob can match files anywhere in the repo and the configured command may scan the WHOLE source tree (ignoring lint-staged's staged-file argument-passing). Result: any commit touching one matching file gets blocked by pre-existing failures across hundreds of unrelated files.

**Correct config** (the command must consume staged paths from lint-staged):

```jsonc
"lint-staged": {
  "src/**/*.{ts,tsx,js,jsx}": [
    "prettier --check --ignore-unknown",
    "eslint --max-warnings=0"
  ]
}
```

**Footgun** (DON'T do this — runs against the whole tree, ignores staged paths):

```jsonc
"lint-staged": {
  "*.{ts,tsx}": [
    "bash -c 'pnpm format:check'"   // ← ignores the file paths lint-staged appends
  ]
}
```

### Why local + per-machine, not CI-only

- **CI runs after the data is on GitHub** — even a green guardrail can't undo a leak. Pre-commit catches it before it leaves the laptop.
- **CI minutes cost money** — running guardrails on every push when most pushes are clean is wasteful; pre-commit runs only on the diff that exists locally.
- **Faster feedback** — a 0.5s pre-commit check beats a 14m CI run for catching obvious leaks.

CI-side guardrails are still valuable as a backstop for `--no-verify` bypasses or contributors who skipped the installer. The right architecture is: **pre-commit primary, CI as a safety net.** This template ships the primary; configure the backstop in your project's CI when ready.

---

## Why these files and not others

A long-running project tends to accumulate dozens of hooks, dozens of slash
commands, and tens of KB of memory indexes — most of that pattern-knowledge
can be re-learned per-project. What reliably **prevents** regressions across
any project is:

1. A hook that **blocks** the obvious-wrong commit (precode-checklist).
2. A hook that **blocks** the silent class-string violations the lint
   doesn't catch (responsive-classcheck).
3. A hook that **advises** before pattern-matching to the nearest config
   knob (limit-bump-investigate-first → three-paths framework).
4. A pre-commit guardrail that **blocks** PII / real UUIDs from leaving
   the dev machine (check-pii.sh).
5. A slash command that **forces** thinking before coding (ready-to-code).
6. A slash command that **standardises** the ship-it sequence (ship).
7. A statusline that surfaces **what you actually need to see** every turn — branch + dirty markers, context % with thresholds, 5-hour rate-limit % (so you know to wrap up before getting blocked).

Everything else is optional. Start here, grow from here.
