# The Three Paths

A framework for choosing which path to take when an obstacle, error, or limit appears. Every problem the agent solves picks one of these — usually unconsciously. The goal of this doc is to make the choice conscious.

---

## Path 1 — Least Cognitive Resistance

**Reflex.** See error → match symptom to nearest config knob → ship the knob.

**Examples:**
- CI fails with "exceeded N min timeout" → bump `timeout-minutes`.
- Memory error → bump `memorySize` / pod memory limit.
- Test flaky → add retries, mark `it.skip`, increase `--retries`.
- API 500 → wrap in try/catch and swallow.
- Build slow → skip a step.

**Why it's tempting.** Fast. The fix matches the symptom literally. No "why" required.

**Why it's wrong.** Limits are detectors, not the disease. Bumping them silences the alarm without fixing the underlying waste. The cost compounds invisibly.

**Tell #1 — pattern-matching to the nearest knob.** "The error names the limit, so the limit is the problem." That's surface-level. The limit CAUGHT the disease, didn't cause it.

**Tell #2 — the "investigate later" sidebar.** When you're shipping a workaround AND simultaneously writing "separate investigation needed" / "follow-up ticket" — that's the moment to stop the workaround and do the investigation now. The deferral is almost never justified.

---

## Path 2 — Investigate, then Decide

**The corrective.** Run a 5-step loop BEFORE touching any tool. Whole loop is ~3 minutes — same wall-clock as the band-aid.

1. **Frame the falsifiable question.** Not "how do I make this not fail" but a specific question that data can answer: "Why did this run take N min when prior runs took M?"
2. **Pick the cheapest signal that answers the question** — usually one tool call. CI slowness: `gh run list --limit 5`. 500 error: response body. Flaky test: failure message.
3. **Compare against a known-good baseline.** Outlier (regression) → look for root cause. Steady-state (always slow) → maybe the limit is correctly tight.
4. **Check the domain's cliché causes first:**
   - **CI/build slowness:** missing `cache-from` / `cache-to`; missing `actions/cache` for `~/.cargo` or `node_modules`; cold image registry pull.
   - **Auth failures:** identity-format mismatch; token expiry; missing scope.
   - **DB slowness:** missing index; n+1 query; sequential where parallel was needed.
   - **Async bugs:** race; missing await; promise leak.
   - **Migration crashes:** legacy column type; NOT NULL on existing nulls; checksum mismatch.
5. **Then decide.** Raise the limit, fix the cause, or both — pair them in the same commit if both. Bumping a limit alone is a smell.

The 5-step ritual makes investigation cheap enough that it's no longer competing with the band-aid on speed.

---

## Path 3 — Question the Premise / Rewire the Reflex

Two flavors, both hardest in different dimensions.

### 3a — Rewire the reflex (mentally hardest, compounds across every task)

Path 2 is a *corrective* — it catches the reflex AFTER it fires. The hardest path is not having the reflex at all: training yourself to NAME "I'm pattern-matching to the nearest knob" the moment you feel the pull, and running the framing question BEFORE reaching for any tool.

Memory entries and rules are scaffolds; they only fire when you remember to consult them. The work is mental discipline that's not externally enforced — slowing down when you'd rather move, accepting the friction tax. Hard because nothing in the moment punishes the lazy path; the cost is invisible until much later.

**Practice it on small problems** where the cost of the reflex is low, so the muscle is built before high-stakes situations.

### 3b — Question the premise / redesign the system (hardest in scope)

Path 2 treats THIS instance correctly. Path 3b treats the CLASS of problem.

**Example:** Path 2 says "add the cache directive". Path 3b asks "should this artifact even be a 1.6 GB monolithic binary built every push?" The answer might be: split, ship a smaller artifact, redesign the deploy primitive entirely.

Hard because it crosses ownership lines, requires weeks not minutes, can't be justified by any single failure. Each individual instance looks tolerable; the cumulative drag of "everyone gets a slow build forever" is the real bill.

**When to take 3b.** Not on the current bug. File it as a "rethink X" ticket, capture the friction tax, raise it during planning when others are pitching new features.

---

## Decision rule

| Situation | Path |
|---|---|
| You have 2 minutes and the framing question is obvious | Path 2 |
| You catch yourself reaching for a config knob without framing a question | Path 3a — STOP, frame the question, then go to Path 2 |
| The same class of problem keeps recurring across multiple bugs | Path 3b — file a "rethink X" ticket, return to Path 2 for the immediate fix |
| You feel the pull to write "investigate later" while shipping a workaround | Path 3a — that's the tell; do Path 2 instead |

**Default to Path 2** unless you've noticed the reflex (Path 3a) or seen the same fire three times (Path 3b).

The hardest path that compounds is **3a — rewiring the reflex**. The hardest path that ships durable value is **3b — redesigning the system**. Path 1 is never the right answer; if you find yourself there, the question is which of 2 / 3a / 3b you should be on instead.

---

## Hook: `limit-bump-investigate-first.sh`

The starter template ships a PreToolUse hook that fires when an `Edit` / `Write` / `MultiEdit` is about to touch a CI / IaC / deploy-config file in a way that involves a known resource-limit identifier (`timeout-minutes`, `MemorySize`, `MaxRetries`, `cpu`, etc.).

The hook is **advisory, not blocking** — sometimes raising a limit IS the right call (Path 2 step 5 — "decide"). It just injects the 5-step framing as `additionalContext` so the question gets asked first. Per-session per-file dedup, so it fires once per file per session.

Patterns it watches for:
- File paths: `.github/workflows/*.yml`, `Dockerfile*`, `*.tf` / `*.tfvars`, `*.cdk.{ts,js}`, `task-definition*.json`, `serverless.{yml,yaml,json}`, `deploy*.yml`.
- Content tokens: `timeout-minutes`, `timeout:`, `--timeout`, `--max-time`, `MemorySize`, `Memory:`, `memory:`, `memory_mb`, `--max-attempts`, `MaxRetries`, `max_retries`, `cpu:`, `ulimit`, `RAM_GB`, `disk:`, `storage:`, `MemoryLimit`.

Add patterns as your stack grows. The hook is small (~120 lines bash + jq); each new pattern is a single regex addition.

---

## Why this framework belongs at the project level

These three paths apply across every project. The paths themselves are universal; the hook that nudges Path 1 → Path 2 is portable; the **specific cliché causes** in step 4 of Path 2 are project-specific (a Rust project's clichés differ from a Node/TS project's). Override that section per project as the cliché list grows.
