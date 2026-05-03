#!/usr/bin/env bash
# Install the local pre-commit / pre-push guardrails for THIS machine.
# Run once per fresh checkout. Idempotent.
#
# Sets `core.hooksPath = .githooks` in the repo's local git config so the
# hooks under .githooks/ fire on commit and push. Without this, the hooks
# are inert and any pre-commit guardrails (PII checks, secret scanning,
# etc.) are bypassed.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

chmod +x .githooks/pre-commit .githooks/pre-push tools/guardrails/*.sh 2>/dev/null || true

git config core.hooksPath .githooks

cat <<EOF
✓ Local guardrails activated for this machine.

  core.hooksPath = .githooks

Installed hooks:
  - pre-commit  → tools/guardrails/check-pii.sh --cached
  - pre-push    → (project-specific gates; see .githooks/pre-push)

The hooks fire on every commit + push from this machine. To bypass once
(NOT recommended), use --no-verify on the failing command.

This is per-machine. Every contributor needs to run this script after
cloning. Add a reminder to your README's "First-time setup" section.
EOF
