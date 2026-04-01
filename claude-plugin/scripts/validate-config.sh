#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: validate-config.sh --goal GOAL [OPTIONS]

Validates autoresearch configuration. Only --goal is required.

Required:
  --goal            What to achieve

Optional (validated if provided):
  --guard CMD       Dry-run the guard command
  --verify CMD      Dry-run the verify command (must output a number)
  --direction DIR   Must be "higher" or "lower" (required with --verify)
  --evaluator VAL   Must be "on" or "off"
  --max-rework N    Must be a non-negative integer
USAGE
  exit 0
}

GOAL="" GUARD="" VERIFY="" DIRECTION="" EVALUATOR="" MAX_REWORK=""
ERRORS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --goal)        GOAL="$2";       shift 2 ;;
    --guard)       GUARD="$2";      shift 2 ;;
    --verify)      VERIFY="$2";     shift 2 ;;
    --direction)   DIRECTION="$2";  shift 2 ;;
    --evaluator)   EVALUATOR="$2";  shift 2 ;;
    --max-rework)  MAX_REWORK="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *)             shift ;;
  esac
done

if [[ -z "$GOAL" ]]; then
  ERRORS+=("Goal is required but was not provided.")
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  ERRORS+=("Not inside a git repository. Autoresearch requires git for memory.")
fi
if git rev-parse --is-inside-work-tree &>/dev/null; then
  if ! git symbolic-ref -q HEAD &>/dev/null; then
    ERRORS+=("Detached HEAD state. Please checkout a branch before starting.")
  fi
fi

if [[ -n "$DIRECTION" ]] && [[ "$DIRECTION" != "higher" ]] && [[ "$DIRECTION" != "lower" ]]; then
  ERRORS+=("Direction must be 'higher' or 'lower', got: '$DIRECTION'")
fi

if [[ -n "$VERIFY" ]]; then
  if [[ -z "$DIRECTION" ]]; then
    ERRORS+=("--direction is required when --verify is set.")
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

if [[ -n "$EVALUATOR" ]] && [[ "$EVALUATOR" != "on" ]] && [[ "$EVALUATOR" != "off" ]]; then
  ERRORS+=("Evaluator must be 'on' or 'off', got: '$EVALUATOR'")
fi

if [[ -n "$MAX_REWORK" ]] && ! [[ "$MAX_REWORK" =~ ^[0-9]+$ ]]; then
  ERRORS+=("Max-rework must be a non-negative integer, got: '$MAX_REWORK'")
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
