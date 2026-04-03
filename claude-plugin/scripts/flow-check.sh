#!/usr/bin/env bash
set -euo pipefail

# flow-check.sh — Mechanical flow validation checks for autoresearch
# Called by stop-hook.sh for post-iteration enforcement.
# Exit 0 = pass, Exit 1 = fail (stdout = violation description)

COMMAND="${1:-}"
shift || true

usage() {
  cat <<'EOF'
Usage: flow-check.sh <check> [args...]

Checks:
  commit-count <commit_before>           Verify ≤ 1 commit since commit_before
  evaluator-dispatched <flow_state_path> Verify evaluator_dispatched=true in state file
  evaluator-format <output_file>         Verify Evaluator output is JSON with verdict field
  outcome-declared <flow_state_path>     Verify outcome_declared=true in state file
  promise-guard <verify_cmd> <direction> <baseline>  Run verify, check metric vs baseline
  iteration-audit <state_file> <transcript>  Composite post-iteration check (9 validations)
EOF
  exit 0
}

parse_field() {
  local file="$1" field="$2"
  sed -n "/^---$/,/^---$/{ s/^${field}: *//p; }" "$file" | head -1 | tr -d '"'
}

check_commit_count() {
  local commit_before="${1:?Usage: flow-check.sh commit-count <commit_before>}"
  if ! git rev-parse --verify "${commit_before}" &>/dev/null; then
    echo "Commit count: could not resolve commit_before '${commit_before}' — is this a valid SHA?"
    exit 1
  fi
  local count
  count=$(git log --oneline "${commit_before}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -gt 1 ]]; then
    echo "Commit count violation: ${count} commits since ${commit_before} (expected ≤ 1)"
    exit 1
  fi
  exit 0
}

check_evaluator_dispatched() {
  local state_file="${1:?Usage: flow-check.sh evaluator-dispatched <flow_state_path>}"
  if [[ ! -f "$state_file" ]]; then
    echo "Flow state file not found: ${state_file}"
    exit 1
  fi
  local dispatched
  dispatched=$(parse_field "$state_file" "evaluator_dispatched")
  if [[ "$dispatched" != "true" ]]; then
    echo "Evaluator not dispatched (evaluator_dispatched=${dispatched})"
    exit 1
  fi
  exit 0
}

check_evaluator_format() {
  local output_file="${1:?Usage: flow-check.sh evaluator-format <output_file>}"
  if [[ ! -f "$output_file" ]]; then
    echo "Evaluator output file not found: ${output_file}"
    exit 1
  fi
  if ! command -v jq &>/dev/null; then
    echo "jq not installed — cannot validate JSON format"
    exit 1
  fi
  local verdict
  verdict=$(jq -r '.verdict // empty' "$output_file" 2>/dev/null || true)
  if [[ -z "$verdict" ]]; then
    echo "Evaluator output is not valid JSON or missing 'verdict' field"
    exit 1
  fi
  if [[ "$verdict" != "pass" ]] && [[ "$verdict" != "fail" ]]; then
    echo "Evaluator verdict must be 'pass' or 'fail', got: ${verdict}"
    exit 1
  fi
  exit 0
}

check_outcome_declared() {
  local state_file="${1:?Usage: flow-check.sh outcome-declared <flow_state_path>}"
  if [[ ! -f "$state_file" ]]; then
    echo "Flow state file not found: ${state_file}"
    exit 1
  fi
  local declared
  declared=$(parse_field "$state_file" "outcome_declared")
  if [[ "$declared" != "true" ]]; then
    echo "Outcome not declared (outcome_declared=${declared})"
    exit 1
  fi
  exit 0
}

check_promise_guard() {
  local verify_cmd="${1:?Usage: flow-check.sh promise-guard <verify_cmd> <direction> <baseline>}"
  local direction="${2:?}"
  local baseline="${3:?}"

  # SECURITY: eval is intentional — verify_cmd is a user-configured shell command.
  # Do not pass untrusted input to this check.
  local metric
  metric=$(eval "$verify_cmd" 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | tail -1 || true)
  if [[ -z "$metric" ]]; then
    echo "Promise guard: verify command produced no metric"
    exit 1
  fi

  local pass=false
  if [[ "$direction" == "higher" ]]; then
    pass=$(awk "BEGIN{print ($metric >= $baseline) ? \"true\" : \"false\"}")
  elif [[ "$direction" == "lower" ]]; then
    pass=$(awk "BEGIN{print ($metric <= $baseline) ? \"true\" : \"false\"}")
  else
    echo "Promise guard: invalid direction '${direction}' (expected higher|lower)"
    exit 1
  fi

  if [[ "$pass" != "true" ]]; then
    echo "Promise guard: metric ${metric} is not ${direction} than baseline ${baseline}"
    exit 1
  fi
  exit 0
}

check_iteration_audit() {
  local state_file="${1:?Usage: flow-check.sh iteration-audit <state_file> <transcript_path>}"
  local transcript_path="${2:?Usage: flow-check.sh iteration-audit <state_file> <transcript_path>}"
  local errors=""

  # ① context.md exists and was updated recently (within 10 minutes)
  if [[ ! -f ".autoresearch/context.md" ]]; then
    errors+="context.md does not exist\n"
  else
    local context_age
    context_age=$(( $(date +%s) - $(stat -c %Y .autoresearch/context.md) ))
    if [[ $context_age -gt 600 ]]; then
      errors+="context.md not updated this iteration (last modified ${context_age}s ago)\n"
    fi
  fi

  # ② knowledge.md exists and was updated recently (within 10 minutes)
  if [[ ! -f ".autoresearch/knowledge.md" ]]; then
    errors+="knowledge.md does not exist\n"
  else
    local knowledge_age
    knowledge_age=$(( $(date +%s) - $(stat -c %Y .autoresearch/knowledge.md) ))
    if [[ $knowledge_age -gt 600 ]]; then
      errors+="knowledge.md not updated this iteration (last modified ${knowledge_age}s ago)\n"
    fi
  fi

  # ③ Commit count ≤ 1
  local commit_before
  commit_before=$(parse_field "$state_file" "commit_before")
  local commit_count=0
  if [[ -n "$commit_before" ]] && git rev-parse --verify "${commit_before}" &>/dev/null; then
    commit_count=$(git log --oneline "${commit_before}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$commit_count" -gt 1 ]]; then
      errors+="commit count violation: ${commit_count} commits since ${commit_before} (expected <= 1)\n"
    fi
  fi

  # ④ If commits exist + evaluator=on → transcript must mention "evaluator"
  local evaluator
  evaluator=$(parse_field "$state_file" "evaluator")
  if [[ "$commit_count" -gt 0 ]] && [[ "$evaluator" == "on" ]]; then
    local eval_mentions
    eval_mentions=$(grep -ci 'evaluator' "$transcript_path" 2>/dev/null || echo "0")
    if [[ "$eval_mentions" -lt 2 ]]; then
      errors+="evaluator=on but no Evaluator dispatch detected in transcript\n"
    fi
  fi

  # ⑤ If commits exist → transcript must have KEEP/DISCARD/REWORK
  if [[ "$commit_count" -gt 0 ]]; then
    local outcome_declared
    outcome_declared=$(grep -cE '(KEEP|DISCARD|REWORK)' "$transcript_path" 2>/dev/null || echo "0")
    if [[ "$outcome_declared" -lt 1 ]]; then
      errors+="no KEEP/DISCARD/REWORK outcome declared in transcript\n"
    fi
  fi

  # ⑥ If commits exist → transcript must have Dev Agent dispatch
  if [[ "$commit_count" -gt 0 ]]; then
    local dev_mentions
    dev_mentions=$(grep -ci 'dev.agent\|Dev Agent\|DISPATCH_DEV' "$transcript_path" 2>/dev/null || echo "0")
    if [[ "$dev_mentions" -lt 1 ]]; then
      errors+="code committed but no Dev Agent dispatch detected — Coordinator must not write code directly\n"
    fi
  fi

  # ⑦ If commits exist → transcript must have Pre-Dev Gate dispatch
  if [[ "$commit_count" -gt 0 ]]; then
    local gate_mentions
    gate_mentions=$(grep -ci 'pre-dev.*gate\|Pre-Dev Gate' "$transcript_path" 2>/dev/null || echo "0")
    if [[ "$gate_mentions" -lt 1 ]]; then
      errors+="code committed but no Pre-Dev Gate dispatch detected\n"
    fi
  fi

  # ⑧ Workflow step not skipped
  local workflow_step
  workflow_step=$(parse_field "$state_file" "workflow_step")
  local last_step="${workflow_step:-0}"
  if [[ -f ".autoresearch/context.md" ]]; then
    local current_step
    current_step=$(grep -oP 'Completed Step: \K\d+' .autoresearch/context.md 2>/dev/null | tail -1 || echo "")
    if [[ -n "$current_step" ]] && [[ -n "$last_step" ]] && [[ "$last_step" -gt 0 ]]; then
      if [[ $((current_step - last_step)) -gt 1 ]]; then
        errors+="workflow step jumped from $last_step to $current_step (skipped step $((last_step + 1)))\n"
      fi
    fi
  fi

  # ⑨ If previous_outcome was DISCARD or REWORK + commits exist → Research must be in transcript
  local previous_outcome
  previous_outcome=$(parse_field "$state_file" "previous_outcome")
  if [[ "$commit_count" -gt 0 ]] && { [[ "$previous_outcome" == "DISCARD" ]] || [[ "$previous_outcome" == "REWORK" ]]; }; then
    local research_mentions
    research_mentions=$(grep -ciE 'Research.*(dispatch|spawn|Agent)' "$transcript_path" 2>/dev/null || echo "0")
    if [[ "$research_mentions" -lt 1 ]]; then
      errors+="previous iteration was ${previous_outcome} but no Research Agent dispatch detected — must re-analyze before Dev\n"
    fi
  fi

  if [[ -n "$errors" ]]; then
    printf "Iteration audit failures:\n%b" "$errors"
    exit 1
  fi
  exit 0
}

case "$COMMAND" in
  commit-count)           check_commit_count "$@" ;;
  evaluator-dispatched)   check_evaluator_dispatched "$@" ;;
  evaluator-format)       check_evaluator_format "$@" ;;
  outcome-declared)       check_outcome_declared "$@" ;;
  promise-guard)          check_promise_guard "$@" ;;
  iteration-audit)        check_iteration_audit "$@" ;;
  -h|--help|"")           usage ;;
  *)                      echo "Unknown check: $COMMAND" >&2; exit 1 ;;
esac
