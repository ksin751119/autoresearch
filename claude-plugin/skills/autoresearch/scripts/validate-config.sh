#!/usr/bin/env bash
set -euo pipefail

# validate-config.sh — Validates autoresearch YAML config file
# Usage: validate-config.sh --config <path>

CONFIG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: validate-config.sh --config <path>"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CONFIG" ]]; then
  echo "Error: --config is required" >&2
  exit 1
fi
if [[ ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

# Parse YAML with python3
PARSED=$(python3 -c "
import yaml, json, sys
with open('$CONFIG') as f:
    data = yaml.safe_load(f)
if not isinstance(data, dict):
    print('Error: config file is not a valid YAML mapping', file=sys.stderr)
    sys.exit(1)
print(json.dumps(data))
" 2>&1) || { echo "Error: failed to parse YAML: $PARSED" >&2; exit 1; }

# Extract fields via python3
field() {
  echo "$PARSED" | python3 -c "
import json,sys
d=json.load(sys.stdin)
v=d.get('$1')
if v is None: print(''); sys.exit(0)
if isinstance(v, bool): print('on' if v else 'off'); sys.exit(0)
print(v)
"
}
field_type() {
  echo "$PARSED" | python3 -c "import json,sys; d=json.load(sys.stdin); v=d.get('$1'); print(type(v).__name__ if v is not None else 'none')"
}

ERRORS=()

# Required: goal
GOAL=$(field "goal")
if [[ -z "$GOAL" ]]; then
  ERRORS+=("'goal' is required but was not provided.")
fi

# Git checks
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  ERRORS+=("Not inside a git repository. Autoresearch requires git.")
elif ! git symbolic-ref -q HEAD &>/dev/null; then
  ERRORS+=("Detached HEAD state. Please checkout a branch before starting.")
fi

# Optional: workflow (must be list if present)
WORKFLOW_TYPE=$(field_type "workflow")
if [[ "$WORKFLOW_TYPE" != "none" ]] && [[ "$WORKFLOW_TYPE" != "list" ]]; then
  ERRORS+=("'workflow' must be a YAML list, got: $WORKFLOW_TYPE")
fi

# Optional: notes (must be list if present)
NOTES_TYPE=$(field_type "notes")
if [[ "$NOTES_TYPE" != "none" ]] && [[ "$NOTES_TYPE" != "list" ]]; then
  ERRORS+=("'notes' must be a YAML list, got: $NOTES_TYPE")
fi

# Optional: direction
DIRECTION=$(field "direction")
if [[ -n "$DIRECTION" ]] && [[ "$DIRECTION" != "higher" ]] && [[ "$DIRECTION" != "lower" ]]; then
  ERRORS+=("'direction' must be 'higher' or 'lower', got: '$DIRECTION'")
fi

# Optional: verify (dry-run if present)
VERIFY=$(field "verify")
if [[ -n "$VERIFY" ]]; then
  if [[ -z "$DIRECTION" ]]; then
    ERRORS+=("'direction' is required when 'verify' is set.")
  fi
  echo "Dry-running verify command: $VERIFY" >&2
  set +e
  VERIFY_OUTPUT=$(eval "$VERIFY" 2>&1)
  VERIFY_EXIT=$?
  set -e
  if [[ $VERIFY_EXIT -ne 0 ]]; then
    ERRORS+=("Verify command failed (exit $VERIFY_EXIT): $VERIFY_OUTPUT")
  else
    METRIC_NUM=$(echo "$VERIFY_OUTPUT" | grep -oE '[0-9]+\.?[0-9]*' | tail -1)
    if [[ -z "$METRIC_NUM" ]]; then
      ERRORS+=("Verify command did not output a number. Output: $VERIFY_OUTPUT")
    else
      echo "Verify dry-run OK: metric = $METRIC_NUM" >&2
    fi
  fi
fi

# Optional: guard (dry-run if present)
GUARD=$(field "guard")
if [[ -n "$GUARD" ]]; then
  echo "Dry-running guard command: $GUARD" >&2
  set +e
  GUARD_OUTPUT=$(eval "$GUARD" 2>&1)
  GUARD_EXIT=$?
  set -e
  if [[ $GUARD_EXIT -ne 0 ]]; then
    ERRORS+=("Guard command failed (exit $GUARD_EXIT): $GUARD_OUTPUT")
  else
    echo "Guard dry-run OK" >&2
  fi
fi

# Optional: evaluator
EVALUATOR=$(field "evaluator")
if [[ -n "$EVALUATOR" ]] && [[ "$EVALUATOR" != "on" ]] && [[ "$EVALUATOR" != "off" ]]; then
  ERRORS+=("'evaluator' must be 'on' or 'off', got: '$EVALUATOR'")
fi

# Optional: max_iterations
MAX_ITER=$(field "max_iterations")
if [[ -n "$MAX_ITER" ]] && ! [[ "$MAX_ITER" =~ ^[0-9]+$ ]]; then
  ERRORS+=("'max_iterations' must be a non-negative integer, got: '$MAX_ITER'")
fi

# Optional: max_rework
MAX_REWORK=$(field "max_rework")
if [[ -n "$MAX_REWORK" ]] && ! [[ "$MAX_REWORK" =~ ^[0-9]+$ ]]; then
  ERRORS+=("'max_rework' must be a non-negative integer, got: '$MAX_REWORK'")
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "❌ Validation failed:" >&2
  for err in "${ERRORS[@]}"; do
    echo "  - $err" >&2
  done
  exit 1
fi

echo "✅ Validation passed" >&2
exit 0
