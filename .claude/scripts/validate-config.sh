#!/usr/bin/env bash
set -uo pipefail

# ─── Usage ────────────────────────────────────────────────────────
usage() {
  cat <<'USAGE'
Usage: validate-config.sh --goal GOAL --scope SCOPE --metric METRIC --direction DIR --verify CMD [--guard CMD]

Validates autoresearch config before loop activation.

Checks:
  1. All 5 required fields are non-empty
  2. Direction is "higher" or "lower"
  3. Git repo exists and is not detached HEAD
  4. Scope glob resolves to at least 1 file
  5. Verify command dry-run succeeds and outputs a number
  6. Guard command dry-run succeeds (if provided)

Exit 0 = all checks passed. Exit 1 = validation failed.
USAGE
  exit 0
}

# ─── Argument Parsing ─────────────────────────────────────────────
GOAL="" SCOPE="" METRIC="" DIRECTION="" VERIFY="" GUARD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --goal)      GOAL="$2";      shift 2 ;;
    --scope)     SCOPE="$2";     shift 2 ;;
    --metric)    METRIC="$2";    shift 2 ;;
    --direction) DIRECTION="$2"; shift 2 ;;
    --verify)    VERIFY="$2";    shift 2 ;;
    --guard)     GUARD="$2";     shift 2 ;;
    -h|--help)   usage ;;
    *)           echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

ERRORS=0

fail() {
  echo "FAIL: $1" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo "WARN: $1" >&2
}

# ─── Check 1: Required fields ────────────────────────────────────
echo "Checking required fields..."
[[ -z "$GOAL" ]]      && fail "Goal is empty"
[[ -z "$SCOPE" ]]     && fail "Scope is empty"
[[ -z "$METRIC" ]]    && fail "Metric is empty"
[[ -z "$DIRECTION" ]] && fail "Direction is empty"
[[ -z "$VERIFY" ]]    && fail "Verify is empty"

if [[ $ERRORS -gt 0 ]]; then
  echo "VALIDATION FAILED: $ERRORS required field(s) missing." >&2
  exit 1
fi
echo "  All required fields present."

# ─── Check 2: Direction value ─────────────────────────────────────
echo "Checking direction value..."
if [[ "$DIRECTION" != "higher" ]] && [[ "$DIRECTION" != "lower" ]]; then
  fail "Direction must be 'higher' or 'lower', got: '$DIRECTION'"
  echo "VALIDATION FAILED." >&2
  exit 1
fi
echo "  Direction: $DIRECTION"

# ─── Check 3: Git status ─────────────────────────────────────────
echo "Checking git status..."
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  fail "Not inside a git repository"
  echo "VALIDATION FAILED." >&2
  exit 1
fi
echo "  Inside git repo."

if ! git symbolic-ref HEAD &>/dev/null; then
  warn "Detached HEAD detected — commits may be lost. Consider checking out a branch."
fi

DIRTY=$(git status --porcelain 2>/dev/null)
if [[ -n "$DIRTY" ]]; then
  warn "Working tree has uncommitted changes. Autoresearch will commit experiments on top of current state."
fi

# ─── Check 4: Scope glob ─────────────────────────────────────────
echo "Checking scope glob..."
# Split scope by comma or space, check each glob
SCOPE_COUNT=0
IFS=', ' read -ra SCOPE_PARTS <<< "$SCOPE"
for glob in "${SCOPE_PARTS[@]}"; do
  # Use bash globbing to count matches
  COUNT=$(find . -path "./$glob" 2>/dev/null | head -20 | wc -l | tr -d ' ')
  if [[ "$COUNT" -eq 0 ]]; then
    # Try with git ls-files for better glob support
    COUNT=$(git ls-files "$glob" 2>/dev/null | head -20 | wc -l | tr -d ' ')
  fi
  SCOPE_COUNT=$((SCOPE_COUNT + COUNT))
done

if [[ "$SCOPE_COUNT" -eq 0 ]]; then
  fail "Scope '$SCOPE' matches 0 files. Check the glob pattern."
  echo "VALIDATION FAILED." >&2
  exit 1
fi
echo "  Scope matches $SCOPE_COUNT+ file(s)."

# ─── Check 5: Verify dry-run ─────────────────────────────────────
echo "Dry-running verify command..."
echo "  Command: $VERIFY"

VERIFY_OUTPUT=$(bash -c "$VERIFY" 2>&1)
VERIFY_EXIT=$?

if [[ $VERIFY_EXIT -ne 0 ]]; then
  fail "Verify command failed with exit code $VERIFY_EXIT"
  echo "  Output (last 5 lines):" >&2
  echo "$VERIFY_OUTPUT" | tail -5 >&2
  echo "VALIDATION FAILED." >&2
  exit 1
fi

# Check output contains at least one number
if ! echo "$VERIFY_OUTPUT" | grep -qE '[0-9]+\.?[0-9]*'; then
  fail "Verify command produced no numeric output. The metric must be a number."
  echo "  Output (last 5 lines):" >&2
  echo "$VERIFY_OUTPUT" | tail -5 >&2
  echo "VALIDATION FAILED." >&2
  exit 1
fi

echo "  Verify command succeeded (exit 0, numeric output found)."

# ─── Check 6: Guard dry-run (optional) ───────────────────────────
if [[ -n "$GUARD" ]]; then
  echo "Dry-running guard command..."
  echo "  Command: $GUARD"

  GUARD_OUTPUT=$(bash -c "$GUARD" 2>&1)
  GUARD_EXIT=$?

  if [[ $GUARD_EXIT -ne 0 ]]; then
    fail "Guard command failed with exit code $GUARD_EXIT"
    echo "  Output (last 5 lines):" >&2
    echo "$GUARD_OUTPUT" | tail -5 >&2
    echo "VALIDATION FAILED." >&2
    exit 1
  fi

  echo "  Guard command succeeded (exit 0)."
fi

# ─── Result ───────────────────────────────────────────────────────
echo ""
echo "ALL CHECKS PASSED. Ready to start autoresearch loop."
exit 0
