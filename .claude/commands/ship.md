# Ship

End-to-end ship sequence: lint → review → commit → merge → push → deploy → verify.
Eliminates the "did I forget the lint?" / "did the deploy actually go live?"
failure modes by chaining the steps in one command.

## Sequence

1. **Lint.** `pnpm lint --max-warnings=0` (or stack-equivalent: `cargo clippy
   -- -D warnings`, `ruff check`, etc.). Must be clean. Pre-existing red is
   STILL red — fix or file a follow-up before shipping.

2. **Review the diff.** `git diff` — read every changed line. Confirm scope
   matches what the user asked for; no drive-by edits.

3. **Stage specific files.** `git add <path1> <path2> ...`. Never `git add -A`
   (catches `.env`, secrets, large binaries, sibling untracked work).

4. **Commit.** `git commit -m "<type>: <one-line summary> (<TICKET>)"` —
   `<type>` ∈ {fix, feat, refactor, docs, chore, test}. One concrete change
   per commit; not "WIP" or "fixes".

5. **Merge to main.** `git checkout main && git pull origin main && git merge
   --no-ff <branch>`. The `--no-ff` preserves the branch boundary in history.

6. **Push.** `git push origin main`. Triggers CI / deploy if configured.

7. **Deploy.** Run the project's deploy command (per
   `.claude/references/CODING-GUIDELINES.md` — fill in once decided). Run in
   background if it takes >20s; never hijack the terminal with foreground
   `aws ecs wait` / `gh run watch` / `sleep`.

8. **Verify live.** Bundle hash on the deployed URL matches the just-built
   bundle. Health endpoint returns 200. New behaviour is reachable.

9. **Mark ticket done.** Comment with the merge SHA + a one-line summary of
   what was actually shipped (matching the verification, not the original plan).

## Rules

- **Don't push partial work.** If parallel agents / subagents are still
  running, WAIT for all of them. One push = one deploy cycle; pushing a
  subset doubles CI minutes.
- **Don't deploy prod before user confirms dev.** Project policy: deploy
  to dev, wait for explicit "looks good", then prod.
- **Never skip steps to "save time".** The skipped step is the one that
  catches the bug. Lint takes 30s; debugging a lint regression in prod
  takes hours.

## Arguments

`$ARGUMENTS` = optional ticket key (e.g. `ABC-123` or `#42`). Used in the
commit message and the done comment.

## Bypass for emergency hotfix

If you genuinely need to deploy in under a minute (active incident,
reverting a known-bad commit), skip steps 5-6 and `git push origin main`
directly with the existing commit. Re-run the full sequence on the next
non-emergency change.
