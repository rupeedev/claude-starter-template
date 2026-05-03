#!/bin/bash
# PreToolUse hook (Edit/Write/MultiEdit): when the assistant is about to
# touch a CI / IaC / deploy-config file in a way that involves a known
# resource-limit identifier (timeout, memory, retries, cpu, etc.), inject
# the three-paths framing as additionalContext so the framing question gets
# asked BEFORE the bump goes out.
#
# The framework — Path 1 (least cognitive resistance) / Path 2 (investigate
# then decide) / Path 3 (rewire-the-reflex or redesign-the-system) — is
# documented at .claude/references/three-paths.md. This hook nudges the
# assistant from Path 1 toward Path 2 at the moment it's about to ship.
#
# Behavior:
#   - ADVISORY only — never blocks. Sometimes raising a limit IS correct
#     (Path 2 step 5 — "decide"). This hook just ensures the framing
#     question gets asked.
#   - Per-session dedup via /tmp/claude-limit-bump-${session_id}/<file>
#     so the reminder fires once per file per session, not on every edit.
#
# Conventions (canonical for any PreToolUse advisory hook in this template):
#   - jq stdin parse for tool_name / tool_input.file_path / session_id
#   - per-session dedup flag-file pattern at /tmp/claude-<topic>-${session_id}/
#   - JSON additionalContext output with permissionDecision: "allow"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

[ -z "$file_path" ] && exit 0

# 1) File-path filter: only fire on CI / IaC / deploy-config files.
case "$file_path" in
  *.github/workflows/*.yml|*.github/workflows/*.yaml) ;;
  *Dockerfile|*Dockerfile.*|*/Dockerfile|*/Dockerfile.*) ;;
  *.tf|*.tfvars|*.tf.json) ;;
  *.cdk.ts|*.cdk.js) ;;
  */task-definition*.json|*/taskdef*.json) ;;
  */serverless.yml|*/serverless.yaml|*/serverless.json) ;;
  */deploy*.yml|*/deploy*.yaml) ;;
  *) exit 0 ;;
esac

# 2) Content filter: extract the proposed change content from the input.
#    For Edit:    .tool_input.new_string
#    For Write:   .tool_input.content
#    For MultiEdit: concat all .edits[].new_string
diff_content=$(echo "$input" | jq -r '
  if .tool_name == "Edit" then .tool_input.new_string // ""
  elif .tool_name == "Write" then .tool_input.content // ""
  elif .tool_name == "MultiEdit" then
    [.tool_input.edits[]? | .new_string // ""] | join("\n")
  else "" end
')

# 3) Pattern check: does the change touch a known resource-limit identifier?
#    Case-insensitive grep across the union of patterns. If none match,
#    silently allow.
if ! echo "$diff_content" | grep -qiE 'timeout-minutes|timeout:|--timeout|--max-time|memorysize|memory:|memory_mb|--max-attempts|maxretries|max_retries|max-retries|cpu:|ulimit|ram_gb|disk:|storage:|memorylimit'; then
  exit 0
fi

# 4) Per-session dedup: only emit once per file per session.
flag_dir="/tmp/claude-limit-bump-${session_id}"
mkdir -p "$flag_dir"
flag_key=$(echo "$file_path" | tr '/' '_' | tr -c 'a-zA-Z0-9_.-' '_')
flag_file="$flag_dir/$flag_key"
[ -f "$flag_file" ] && exit 0
touch "$flag_file"

# 5) Compose the advisory. Inline so the assistant reads it pre-tool-use.
read -r -d '' ctx <<'EOF'
LIMIT-BUMP DETECTED — three-paths framing reminder

You are about to edit a CI / IaC / deploy-config file and the change
touches a known resource-limit identifier (timeout / memory / retries /
cpu / etc.). Before this edit ships, frame the falsifiable question:

  1. WHY is this limit being touched? Specifically: "Why is the
     resource being consumed at level X when prior runs / instances /
     baselines used Y?" Make it answerable with data.
  2. CHEAPEST SIGNAL that answers it — usually one tool call:
       CI:        gh run list --workflow=<file> --limit 5
       Build:     read the longest step in the run log
       Memory:    CloudWatch metric or local profile
       Retries:   the underlying error in logs
  3. BASELINE — outlier (regression → root cause) or steady-state
     (limit may be correctly tight and a bump is right)?
  4. CLICHE CAUSES first:
       CI slowness: missing cache-from / cache-to (BuildKit GHA cache)
       Memory:      leak; load shedding; n+1 query
       Retries:     network flakiness vs underlying error
       Disk:        log accumulation; stale artifacts; cargo target/
  5. THEN DECIDE — raise the limit, fix the cause, or BOTH (paired in
     one commit). Bumping a limit alone is a smell.

Limits are DETECTORS, not the disease. The right question to ask any
limit is: "what is this limit catching?"

Two tells you're on Path 1 (least cognitive resistance):
  - Pattern-matching to the nearest knob the failure names.
  - Writing "investigate later" / "follow-up ticket" while shipping the
    workaround. The deferral is almost never justified.

Full framework: .claude/references/three-paths.md (project) and
~/.claude/three-paths.md (global).

If you've already done the framing — proceed. The hook is advisory, not
blocking. Per-session dedup is on; this fires once per file per session.
EOF

jq -n --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    additionalContext: $ctx
  }
}'
exit 0
