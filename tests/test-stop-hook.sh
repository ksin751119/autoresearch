#!/usr/bin/env bash
# test-stop-hook.sh — standalone tests for stop-hook.sh bounded iteration logic
# Verifies iteration counting, boundary conditions, and unbounded mode.
# Tests 4 and 8 are expected to FAIL on current code (off-by-one bug: -gt vs -ge).
set -uo pipefail

# ─── Paths ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/claude-plugin/hooks/stop-hook.sh"
STATE_DIR="$PROJECT_ROOT/.claude"
STATE_FILE="$STATE_DIR/autoresearch-loop.local.md"

# ─── Counters ─────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# ─── Helpers ──────────────────────────────────────────────────────

create_state_file() {
  # Usage: create_state_file <active> <iteration> <max_iterations> [session_id]
  local active="${1:-true}"
  local iteration="${2:-0}"
  local max_iterations="${3:-0}"
  local session_id="${4:-test-session}"
  mkdir -p "$STATE_DIR"
  cat > "$STATE_FILE" <<STEOF
---
active: ${active}
iteration: ${iteration}
max_iterations: ${max_iterations}
session_id: ${session_id}
goal: test goal
metric: test metric
---
Continue the research loop.
STEOF
}

cleanup_state() {
  rm -f "$STATE_FILE"
}

run_hook() {
  # Run the stop hook, feeding session_id JSON on stdin.
  # Captures stdout and exit code. Stderr is discarded.
  local session_id="${1:-test-session}"
  local output
  local exit_code
  output=$(echo "{\"session_id\":\"${session_id}\"}" | bash "$HOOK" 2>/dev/null) || true
  # Re-run to capture exit code properly
  echo "{\"session_id\":\"${session_id}\"}" | bash "$HOOK" 2>/dev/null
  exit_code=$?
  # We need both output and exit code; use a subshell trick
  echo "$output"
  return $exit_code
}

# Better helper that captures both output and exit code
run_hook_capture() {
  local session_id="${1:-test-session}"
  local tmpout
  tmpout=$(mktemp)
  echo "{\"session_id\":\"${session_id}\"}" | bash "$HOOK" 2>/dev/null > "$tmpout"
  local ec=$?
  HOOK_OUTPUT=$(cat "$tmpout")
  HOOK_EXIT=$ec
  rm -f "$tmpout"
}

get_decision() {
  # Parse decision from hook JSON output. Returns empty if no JSON / no decision.
  if [[ -z "$HOOK_OUTPUT" ]]; then
    echo ""
    return
  fi
  python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d.get('decision', ''))
except:
    print('')
" <<< "$HOOK_OUTPUT"
}

get_iteration_from_state() {
  # Read current iteration from the state file
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "NO_STATE_FILE"
    return
  fi
  sed -n '/^---$/,/^---$/{ s/^iteration: *//p; }' "$STATE_FILE" | head -1
}

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $test_name (expected=$expected, got=$actual)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $test_name (expected=$expected, got=$actual)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ─── Test 1: Hook allows exit when iteration >= max_iterations ────
echo "Test 1: Hook allows exit when iteration=3, max=3"
create_state_file "true" 3 3
run_hook_capture "test-session"
decision=$(get_decision)
assert_eq "decision should be empty (allow exit)" "" "$decision"
assert_eq "exit code should be 0" "0" "$HOOK_EXIT"
cleanup_state

# ─── Test 2: Hook blocks exit when iteration=0, max=3 ────────────
echo ""
echo "Test 2: Hook blocks exit when iteration=0, max=3"
create_state_file "true" 0 3
run_hook_capture "test-session"
decision=$(get_decision)
assert_eq "decision should be block" "block" "$decision"
iter_after=$(get_iteration_from_state)
assert_eq "iteration should be incremented to 1" "1" "$iter_after"
cleanup_state

# ─── Test 3: Hook blocks at iteration=1, max=3 ───────────────────
echo ""
echo "Test 3: Hook blocks exit when iteration=1, max=3"
create_state_file "true" 1 3
run_hook_capture "test-session"
decision=$(get_decision)
assert_eq "decision should be block" "block" "$decision"
iter_after=$(get_iteration_from_state)
assert_eq "iteration should be incremented to 2" "2" "$iter_after"
cleanup_state

# ─── Test 4: Hook allows at iteration=2, max=3 (NEXT=3 >= 3) ─────
# THIS SHOULD FAIL on current code due to -gt vs -ge bug.
echo ""
echo "Test 4: Hook allows exit when iteration=2, max=3 (NEXT=3, should be >= boundary)"
create_state_file "true" 2 3
run_hook_capture "test-session"
decision=$(get_decision)
assert_eq "decision should be empty (allow exit)" "" "$decision"
cleanup_state

# ─── Test 5: Unbounded mode (max=0) always blocks ────────────────
echo ""
echo "Test 5: Unbounded mode (max=0) always blocks, even at high iteration"
create_state_file "true" 100 0
run_hook_capture "test-session"
decision=$(get_decision)
assert_eq "decision should be block" "block" "$decision"
iter_after=$(get_iteration_from_state)
assert_eq "iteration should be incremented to 101" "101" "$iter_after"
cleanup_state

# ─── Test 6: Hook allows exit when active=false ──────────────────
echo ""
echo "Test 6: Hook allows exit when active=false"
create_state_file "false" 0 3
run_hook_capture "test-session"
decision=$(get_decision)
assert_eq "decision should be empty (allow exit)" "" "$decision"
assert_eq "exit code should be 0" "0" "$HOOK_EXIT"
cleanup_state

# ─── Test 7: No state file → allow exit ──────────────────────────
echo ""
echo "Test 7: No state file -> allow exit"
cleanup_state  # ensure no state file
run_hook_capture "test-session"
decision=$(get_decision)
assert_eq "decision should be empty (allow exit)" "" "$decision"
assert_eq "exit code should be 0" "0" "$HOOK_EXIT"

# ─── Test 8: Full bounded simulation (max=3) ─────────────────────
# Run the hook in a loop, counting how many times it blocks.
# With max=3: should block at iter 0->1 and 1->2, allow at 2->3.
# That's exactly 2 blocks. On buggy code it will block 3 times.
echo ""
echo "Test 8: Full bounded simulation (max=3) — count blocking iterations"
create_state_file "true" 0 3
block_count=0
max_sim_iters=10  # safety cap to avoid infinite loop
for (( i=0; i<max_sim_iters; i++ )); do
  run_hook_capture "test-session"
  decision=$(get_decision)
  if [[ "$decision" == "block" ]]; then
    block_count=$((block_count + 1))
  else
    # Hook allowed exit — loop is done
    break
  fi
done
assert_eq "should block exactly 2 times (iterations 0->1 and 1->2)" "2" "$block_count"
cleanup_state

# ─── Summary ──────────────────────────────────────────────────────
echo ""
echo "=============================="
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed, $TOTAL_COUNT total"
echo "=============================="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
else
  exit 0
fi
