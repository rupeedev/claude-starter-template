# Ready to Code Gate

Before any non-trivial code change, answer five questions in this conversation.
This forces explicit thinking before edits and prevents the "I'll figure it out
while coding" failure mode.

## Rule

Answer ALL five questions BEFORE invoking Edit / Write / MultiEdit.
A test that reproduces the bug must exist BEFORE the fix is written.

## The five questions

1. **Done state** — What is concretely true when this is finished? (Not "it
   works" — name the observable behaviour.)

2. **Verification gate** — What test, curl, or visual check proves it's done?
   Run it FIRST against current code to confirm the failing baseline.

3. **Blast radius** — What could break? Which files, services, or workflows
   does this touch? How many call-sites?

4. **Scope boundary** — What is explicitly OUT of scope? Drift here is the
   #1 cause of "small fix" turning into a 200-line PR.

5. **Rollback plan** — If this ships and breaks production, how do we revert?
   Single commit revert? Feature flag? Database migration roll-back?

## Output format

Five short answers. Bullet form OK. Skip a question only if it genuinely
doesn't apply (e.g. rollback plan for a docs-only change), and say so explicitly.

## Arguments

`$ARGUMENTS` = the task description (optional — if omitted, use the most
recent user message as the task).

## When to skip this gate

- Pure typo fixes (one-line readme/comment)
- Renaming a single private function with no call-sites elsewhere
- Reverting a recent commit

For everything else, run the gate. The two minutes it costs catch the
ten-minute mistakes.
