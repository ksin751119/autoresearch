#!/usr/bin/env bash
set -euo pipefail

# flow-check.sh — Mechanical flow validation checks for autoresearch
# Called by Flow Reviewer agent at specific phases.
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

case "$COMMAND" in
  commit-count)           check_commit_count "$@" ;;
  evaluator-dispatched)   check_evaluator_dispatched "$@" ;;
  evaluator-format)       check_evaluator_format "$@" ;;
  outcome-declared)       check_outcome_declared "$@" ;;
  promise-guard)          check_promise_guard "$@" ;;
  -h|--help|"")           usage ;;
  *)                      echo "Unknown check: $COMMAND" >&2; exit 1 ;;
esac
