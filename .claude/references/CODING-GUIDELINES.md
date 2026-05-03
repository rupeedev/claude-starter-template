# Coding Guidelines

Starter rules. Add project-specific sections (backend, API, deploy, etc.) as
the codebase grows. Keep examples short and concrete.

---

## General Rules

### File size

- Max 400 lines per file. Split if larger.
- Components, modules, and route handlers all subject to the same limit.

### Lint policy

- `pnpm lint --max-warnings=0` (or stack-equivalent) MUST pass before commit.
- Pre-existing red counts. "Not mine" is not an excuse — either fix in scope
  (small fix), spin off a follow-up issue (large fix), or pause and ask the
  user. Never silently merge on red.

### Unused code

- Remove imports / variables / functions made unused by YOUR changes.
- Don't remove pre-existing dead code unless explicitly asked.

### Branch hygiene

- Every commit on a feature branch (`<type>/<short-name>`), never directly
  on main / master. Enforced by `.claude/hooks/precode-checklist.sh`.

---

## Frontend (React / TypeScript)

Customise this section once you've picked the stack. Below assumes Vite +
React + Tailwind because that's the most common starter target.

### Responsive Design — Mobile-First (CRITICAL)

**Every page, dialog, side panel, table, and chart must work at 375px width.**
Mobile is not a follow-up — it's a Day-1 requirement. The
`.claude/hooks/responsive-classcheck.sh` hook BLOCKS the two most-common
violations. The other three rules below are not yet automated; self-check
in Chrome DevTools (Cmd+Shift+M) at 375 / 768 / 1024 px before merging.

```tsx
// 1. Multi-column grids must declare a mobile column count  ← AUTOMATED
// BAD — 3 cards stay 3 cards on a 360px phone (hook BLOCKS)
<div className="grid grid-cols-3 gap-4">
// GOOD — mobile-first cascade
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">

// 2. No fixed pixel widths without a responsive override  ← AUTOMATED
// BAD — 260px overflows below 360px (hook BLOCKS)
<Input className="w-[260px]" />
// GOOD
<Input className="w-full sm:max-w-[260px]" />

// 3. Tables wrap in overflow-x-auto with a min-width
// BAD — page-level horizontal scroll
<table>...</table>
// GOOD — table scrolls inside its container
<div className="overflow-x-auto"><table className="min-w-[640px]">...</table></div>

// 4. Header rows wrap or stack on mobile
// BAD — long title + button group overflow at 430px
<div className="flex items-center justify-between">
// GOOD — wrap or stack
<div className="flex flex-wrap items-center justify-between gap-3">
// or
<div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">

// 5. Side panels stack on mobile
// BAD — 420px panel + content can't both fit at 768px
<div className="flex"><aside className="w-[420px]" />...</div>
// GOOD — stacks until lg:
<div className="flex flex-col lg:flex-row"><aside className="w-full lg:w-[420px] shrink-0" />...</div>
```

### Imports / variables

- No unused imports — let the lint catch it.
- No declared-but-unused vars. Prefix `_` only if intentionally unused
  (e.g. destructured prop you must accept but won't use).

### Async action buttons

- Every button that triggers a network call shows a pending state:
  disabled while in flight + visible spinner + re-enables on both success
  AND error (use `try/finally`).
- Build / borrow an `<AsyncButton>` primitive that bakes this in, then
  enforce its use via a lint rule or PR review checklist.

---

## Backend

Customise per stack. Generic rules:

- Validate inputs at the boundary (HTTP handler, gRPC entry). Trust internal
  callers.
- Don't add error handling for impossible scenarios. Let panics / exceptions
  surface obvious bugs in dev.
- Database migrations are forward-only and idempotent. No `DROP TABLE` in a
  migration file unless the column / table genuinely doesn't exist anywhere.

---

## Pre-Commit Checklist

Run before EVERY commit:

```bash
# Stack-equivalent of these — fill in:
pnpm lint --max-warnings=0       # or: cargo clippy -- -D warnings, ruff check
pnpm tsc --noEmit                # or: cargo check, mypy
pnpm test --changed               # or: cargo test, pytest -k <changed>
```

- [ ] Lint clean (zero warnings)
- [ ] Type-check passes
- [ ] Tests for changed code pass (or new test added if behavior changed)
- [ ] Any new layout / grid / dialog / table / chart was viewed at **375px**
      in Chrome DevTools (Cmd+Shift+M, iPhone SE preset)
- [ ] Any new button firing a network call uses the AsyncButton pattern
- [ ] No `git add -A` — only specific files staged
- [ ] Commit message references a ticket / issue ID

---

## How to grow this file

When you fix a bug that came from a missing rule, add the rule here. Each
rule lists:
- What the rule is (one sentence)
- An incident reference if available (commit / issue ID)
- Bad / good code example (4-8 lines)
- Whether automated enforcement exists (lint / hook / CI)

Don't copy rules speculatively. Add them when the bug actually happens.
