#!/usr/bin/env bash
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/stop-hook.sh"
PASS=0 FAIL=0 TOTAL=0

setup() { TEST_DIR=$(mktemp -d); cd "$TEST_DIR"; git init -q; git commit --allow-empty -m "init" -q; mkdir -p .claude; }
teardown() { cd /; rm -rf "$TEST_DIR"; }
assert_exit() { local expected=$1 actual=$2 name=$3; TOTAL=$((TOTAL+1)); if [[ "$actual" -eq "$expected" ]]; then echo "  ✓ $name"; PASS=$((PASS+1)); else echo "  ✗ $name (expected exit $expected, got $actual)"; FAIL=$((FAIL+1)); fi; }
assert_contains() { local output="$1" pattern="$2" name="$3"; TOTAL=$((TOTAL+1)); if echo "$output" | grep -q "$pattern"; then echo "  ✓ $name"; PASS=$((PASS+1)); else echo "  ✗ $name (output missing: $pattern)"; FAIL=$((FAIL+1)); fi; }

# Test 1: No state file
echo "Test 1: No state file"
setup
RESULT=$(echo '{"session_id":"s1"}' | bash "$HOOK" 2>&1; echo "EXIT:$?")
EXIT_CODE=$(echo "$RESULT" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
assert_exit 0 "$EXIT_CODE" "exits 0 when no state file"
teardown

# Test 2: Active loop blocks exit
echo "Test 2: Active loop blocks exit"
setup
cat > .claude/autoresearch-loop.local.md <<'STATE'
---
active: true
iteration: 0
session_id: test-session
max_iterations: 10
goal: test goal
completion_promise: null
guard: ""
verify: ""
direction: ""
evaluator: on
max_rework: 2
started_at: "2026-04-01T00:00:00Z"
---

MANDATORY FIRST STEP: Read .autoresearch/context.md
Goal: test goal
STATE
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"I completed the iteration."}]}}' > "$TRANSCRIPT"
OUTPUT=$(echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" '"decision"' "outputs JSON with decision"
assert_contains "$OUTPUT" '"block"' "decision is block"
assert_contains "$OUTPUT" 'test goal' "prompt contains goal"
ITER=$(grep '^iteration:' .claude/autoresearch-loop.local.md | sed 's/iteration: *//')
TOTAL=$((TOTAL+1)); if [[ "$ITER" == "1" ]]; then echo "  ✓ iteration incremented"; PASS=$((PASS+1)); else echo "  ✗ iteration should be 1, got $ITER"; FAIL=$((FAIL+1)); fi
rm -f "$TRANSCRIPT"; teardown

# Test 3: Max iterations reached
echo "Test 3: Max iterations reached"
setup
cat > .claude/autoresearch-loop.local.md <<'STATE'
---
active: true
iteration: 9
session_id: test-session
max_iterations: 10
goal: test goal
completion_promise: null
guard: ""
verify: ""
direction: ""
evaluator: on
max_rework: 2
started_at: "2026-04-01T00:00:00Z"
---

Goal: test goal
STATE
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"done"}]}}' > "$TRANSCRIPT"
echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "exits 0 at max iterations"
TOTAL=$((TOTAL+1)); if [[ ! -f .claude/autoresearch-loop.local.md ]]; then echo "  ✓ state file removed"; PASS=$((PASS+1)); else echo "  ✗ state file should be removed"; FAIL=$((FAIL+1)); fi
rm -f "$TRANSCRIPT"; teardown

# Test 4: Completion promise matched
echo "Test 4: Completion promise matched"
setup
cat > .claude/autoresearch-loop.local.md <<'STATE'
---
active: true
iteration: 2
session_id: test-session
max_iterations: 0
goal: test goal
completion_promise: "ALL TESTS PASS"
guard: ""
verify: ""
direction: ""
evaluator: on
max_rework: 2
started_at: "2026-04-01T00:00:00Z"
---

Goal: test goal
STATE
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"Everything done. <promise>ALL TESTS PASS</promise> Great."}]}}' > "$TRANSCRIPT"
echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "exits 0 on promise match"
TOTAL=$((TOTAL+1)); if [[ ! -f .claude/autoresearch-loop.local.md ]]; then echo "  ✓ state file removed"; PASS=$((PASS+1)); else echo "  ✗ state file should be removed"; FAIL=$((FAIL+1)); fi
rm -f "$TRANSCRIPT"; teardown

# Test 5: Promise NOT matched
echo "Test 5: Completion promise not matched"
setup
cat > .claude/autoresearch-loop.local.md <<'STATE'
---
active: true
iteration: 2
session_id: test-session
max_iterations: 0
goal: test goal
completion_promise: "ALL TESTS PASS"
guard: ""
verify: ""
direction: ""
evaluator: on
max_rework: 2
started_at: "2026-04-01T00:00:00Z"
---

Goal: test goal
STATE
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"Still working on it."}]}}' > "$TRANSCRIPT"
OUTPUT=$(echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" '"block"' "blocks when promise not matched"
rm -f "$TRANSCRIPT"; teardown

# Test 6: Session isolation
echo "Test 6: Session isolation"
setup
cat > .claude/autoresearch-loop.local.md <<'STATE'
---
active: true
iteration: 0
session_id: session-A
max_iterations: 10
goal: test
completion_promise: null
guard: ""
verify: ""
direction: ""
evaluator: on
max_rework: 2
started_at: "2026-04-01T00:00:00Z"
---

Goal: test
STATE
echo '{"session_id":"session-B"}' | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "allows exit for different session"
teardown

# Test 7: Unlimited mode
echo "Test 7: Unlimited mode"
setup
cat > .claude/autoresearch-loop.local.md <<'STATE'
---
active: true
iteration: 99
session_id: test-session
max_iterations: 0
goal: test
completion_promise: null
guard: ""
verify: ""
direction: ""
evaluator: on
max_rework: 2
started_at: "2026-04-01T00:00:00Z"
---

Goal: test
STATE
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"still going"}]}}' > "$TRANSCRIPT"
OUTPUT=$(echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" '"block"' "blocks in unlimited mode"
rm -f "$TRANSCRIPT"; teardown

echo ""; echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
