# GitHub + Claude Code Integration

This is a complete setup guide for wiring Claude into a GitHub repository so it can:

1. respond to `@claude` in issues, PR comments, and PR reviews,
2. start working when an issue is assigned to Claude,
3. review pull requests automatically, and
4. optionally auto-merge Claude-created PRs after checks pass.

This guide is based on a proven production workflow pattern and the official
`anthropics/claude-code-action@v1` setup and usage docs.

## What this template gives you

The starter template includes these workflow files:

- `.github/workflows/claude.yml` — main Claude assistant workflow
- `.github/workflows/claude-code-review.yml` — automatic PR review workflow
- `.github/workflows/auto-merge-agent-prs.yml` — optional auto-approve/auto-merge workflow

If you want the minimum viable setup, start with only:

- `.github/workflows/claude.yml`

## Before you start

You need:

1. **Repository admin access** to the target repository.
2. **GitHub Actions enabled** in that repository.
3. The **Claude GitHub app** installed on the repository.
4. One Claude authentication method:
   - `CLAUDE_CODE_OAUTH_TOKEN` **or**
   - `ANTHROPIC_API_KEY`

For this template, the default workflow uses:

- `CLAUDE_CODE_OAUTH_TOKEN`

## The key concept: issue assignment needs more than the event trigger

Many people configure:

```yaml
on:
  issues:
    types: [assigned]
```

and assume assignment will trigger Claude correctly.

That is **not sufficient** on its own.

For assignment-based activation to work reliably with Claude Code Action, your workflow also needs:

```yaml
with:
  assignee_trigger: "claude"
```

That is the most important detail in this guide.

Without `assignee_trigger`, a workflow may listen for the assignment event but still behave like a mention-only workflow.

## Setup overview

You will do these steps in order:

1. Install the Claude GitHub app.
2. Add the Claude auth secret.
3. Copy the workflow files into `.github/workflows/`.
4. Commit the workflows to the default branch.
5. Test `@claude` mention flow.
6. Test issue assignment flow.
7. Optionally enable PR review and auto-merge workflows.

## Step 1: Install the Claude GitHub app

Install the official GitHub app here:

- `https://github.com/apps/claude`

### What to do

1. Open the Claude GitHub app page.
2. Click **Install**.
3. Choose the correct GitHub account or organization.
4. Select:
   - **All repositories**, or
   - **Only select repositories** if you want to limit access.
5. Make sure the target repository is included.

### How to verify installation

In GitHub:

1. Open the target repository.
2. Go to **Settings**.
3. Open **Integrations** or **Installed GitHub Apps**.
4. Confirm that **Claude** is installed for this repo.

If the app is not installed on the repository, the workflow file can exist and still never behave correctly.

## Step 2: Add authentication

The official action supports multiple auth methods, but the easiest setup for this template is:

- `CLAUDE_CODE_OAUTH_TOKEN`

### Option A — OAuth token (recommended for this template)

Generate the token locally:

```bash
claude setup-token
```

Then add it in GitHub:

1. Open the repository.
2. Go to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret**.
4. Add:
   - **Name:** `CLAUDE_CODE_OAUTH_TOKEN`
   - **Value:** your generated token

### Option B — Anthropic API key

If you prefer API-key auth, add:

- **Name:** `ANTHROPIC_API_KEY`

Then update the workflow from:

```yaml
claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

to:

```yaml
anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Security rules

- Never hardcode tokens or API keys in workflow YAML.
- Always use GitHub Actions secrets.
- Prefer the minimum permissions required by each workflow.
- Rotate tokens if they are exposed or copied into the wrong place.

## Step 3: Copy the workflow files

Copy these files into your repository:

- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `.github/workflows/auto-merge-agent-prs.yml` *(optional)*

### Minimal setup

If you only want Claude to work on issues and comments, copy only:

- `.github/workflows/claude.yml`

### Recommended setup order

1. `claude.yml`
2. `claude-code-review.yml`
3. `auto-merge-agent-prs.yml`

Do not start with auto-merge first.

## Step 4: Understand the main workflow

The main file is:

- `.github/workflows/claude.yml`

It listens for:

- new issue comments,
- PR review comments,
- PR review submissions,
- newly opened issues,
- assigned issues.

Core part:

```yaml
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  pull_request_review:
    types: [submitted]
  issues:
    types: [opened, assigned]
```

And the Claude action is configured with:

```yaml
with:
  trigger_phrase: "@claude"
  assignee_trigger: "claude"
```

### What each trigger does

| Trigger | What it means |
| --- | --- |
| `trigger_phrase: "@claude"` | Claude responds when users mention `@claude` in supported GitHub text surfaces |
| `assignee_trigger: "claude"` | Claude responds when an issue is assigned to the GitHub assignee named `claude` |

## Step 5: Set workflow permissions correctly

The workflows in this template already define permissions, but you should understand why.

### Main Claude workflow

`claude.yml` uses:

```yaml
permissions:
  contents: write
  pull-requests: write
  issues: write
  actions: read
  id-token: write
```

Why:

- `contents: write` — Claude may create branches, commits, or PR changes.
- `pull-requests: write` — Claude can comment on or update PR-related state.
- `issues: write` — Claude can comment on issues.
- `actions: read` — Claude can inspect workflow/check results.
- `id-token: write` — required by the action setup.

### GitHub repository Actions settings to check

In the repository:

1. Go to **Settings → Actions → General**.
2. Confirm GitHub Actions are allowed.
3. Confirm workflows are allowed to run.
4. If your repo has strict defaults, confirm GitHub Actions can write where needed.

If your organization restricts GitHub Actions or GitHub Apps, repository-level YAML alone will not be enough.

## Step 6: Commit the workflow to the default branch

This is important.

GitHub event-driven workflows only start from workflow files that exist on the repository's active branch state, typically the default branch.

So:

1. Add the workflow file(s).
2. Commit them.
3. Merge them into the default branch, usually `main`.

If the workflow exists only in your feature branch, issue assignments and `@claude` on new issues may appear to do nothing.

## Step 7: Test the integration

Test in this order.

### Test A — mention Claude in a new issue

Create a new issue with:

```md
@claude say hello and summarize what you can do in this repository
```

### Expected result

- A GitHub Actions run starts for `Claude Code`.
- Claude posts a response on the issue, or starts a work session depending on the prompt.

### Test B — assignment trigger

1. Create a normal issue with a plain title and body.
2. Assign the issue to **claude** in GitHub.

### Expected result

- A GitHub Actions run starts from the `issues.assigned` event.
- Claude starts processing the issue even if the issue body does not contain `@claude`.

### Test C — PR comment trigger

On a pull request, add:

```md
@claude please address this review feedback
```

### Expected result

- A GitHub Actions run starts.
- Claude responds in the PR context.

## Step 8: Verify assignment uses the correct assignee name

This matters.

The workflow currently uses:

```yaml
assignee_trigger: "claude"
```

That string must match the assignee identity the action expects.

### What to check

When you assign the issue in GitHub:

- confirm the assignee appears as **claude**,
- not a different bot/app name,
- not an internal org-specific alias.

If your actual GitHub assignee name is different, update:

```yaml
assignee_trigger: "claude"
```

to the correct value.

If you skip this, assignment will look configured correctly but still never activate Claude.

## Step 9: Optional PR review workflow

If you want Claude to automatically review every PR, also enable:

- `.github/workflows/claude-code-review.yml`

This workflow runs on:

- PR opened
- PR synchronize
- PR ready for review
- PR reopened

It uses the Claude Code review plugin:

```yaml
plugin_marketplaces: "https://github.com/anthropics/claude-code.git"
plugins: "code-review@claude-code-plugins"
prompt: "/code-review:code-review ${{ github.repository }}/pull/${{ github.event.pull_request.number }}"
```

### When to enable this

Enable it if you want:

- automatic AI review on every PR,
- a second-pass reviewer for external contributors,
- a lightweight security/code-quality review pass.

## Step 10: Optional auto-merge workflow

If your repository allows it, you can also enable:

- `.github/workflows/auto-merge-agent-prs.yml`

This workflow:

1. detects Claude-generated PRs,
2. marks drafts ready,
3. waits for checks,
4. approves the PR,
5. merges it.

### Warning

Only use this if your team explicitly wants bot-created PRs to merge automatically.

Do **not** enable it by default in high-risk repos without human review policy.

## Why this template uses `assignee_trigger`

A common mistake is to listen for issue assignment events but still rely on
`@claude` appearing in the issue body or title.

This template avoids that trap by making assignment a first-class trigger via:

```yaml
assignee_trigger: "claude"
```

## Common failure modes

| Problem | Likely cause | Fix |
| --- | --- | --- |
| Assigning an issue does nothing | `assignee_trigger` missing or wrong | Set `assignee_trigger` to the real Claude assignee name |
| `@claude` does nothing on issues | Workflow not on default branch | Merge workflow into default branch |
| Workflow never starts | Actions disabled or blocked by org policy | Enable Actions and verify org/repo policy |
| Workflow starts but Claude cannot comment or open PRs | Permissions too narrow | Use the permissions from the template |
| Workflow fails immediately | Missing `CLAUDE_CODE_OAUTH_TOKEN` or wrong auth input | Add the correct secret and matching workflow field |
| Review workflow runs but posts nothing useful | Review plugin config missing | Use the included `plugin_marketplaces` and `plugins` settings |
| Assignment looks correct but still does nothing | Wrong assignee identity | Verify the exact GitHub assignee name and update `assignee_trigger` |
| Auto-merge does not merge | Checks still pending, failed, or branch protection blocks it | Review checks and branch protection rules |

## First-run success checklist

You are done when all of these are true:

- [ ] Claude GitHub app is installed on the target repo
- [ ] `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` is configured
- [ ] `.github/workflows/claude.yml` exists on the default branch
- [ ] `assignee_trigger` matches the real Claude assignee name
- [ ] `@claude` in a new issue starts a workflow run
- [ ] assigning an issue to Claude starts a workflow run
- [ ] Claude can comment back on the issue or PR

## Fastest path for most teams

If you want the shortest working path:

1. Install the Claude GitHub app.
2. Add `CLAUDE_CODE_OAUTH_TOKEN`.
3. Copy `.github/workflows/claude.yml`.
4. Commit it to `main`.
5. Create a test issue with `@claude`.
6. Create another test issue and assign it to `claude`.

If both tests work, your core integration is done.

Then add PR review and auto-merge only if you want extra automation.

## Reference workflow snippets

### Minimal main workflow auth block

```yaml
- name: Run Claude Code
  uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    trigger_phrase: "@claude"
    assignee_trigger: "claude"
```

### API key variant

```yaml
- name: Run Claude Code
  uses: anthropics/claude-code-action@v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    trigger_phrase: "@claude"
    assignee_trigger: "claude"
```

## References

- Claude Code Action: `https://github.com/anthropics/claude-code-action`
- Claude Code Action setup: `https://github.com/anthropics/claude-code-action/blob/main/docs/setup.md`
- Claude Code Action usage: `https://github.com/anthropics/claude-code-action/blob/main/docs/usage.md`
- GitHub `GITHUB_TOKEN` permissions: `https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication`
