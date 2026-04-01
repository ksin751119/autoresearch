#!/usr/bin/env bash
set -euo pipefail

SETUP="$(cd "$(dirname "$0")/.." && pwd)/scripts/setup-loop.sh"
PASS=0 FAIL=0 TOTAL=0

setup() { TEST_DIR=$(mktemp -d); cd "$TEST_DIR"; git init -q; git commit --allow-empty -m "init" -q; }
teardown() { cd /; rm -rf "$TEST_DIR"; }
assert_exit() { local expected=$1 actual=$2 name=$3; TOTAL=$((TOTAL+1)); if [[ "$actual" -eq "$expected" ]]; then echo "  ✓ $name"; PASS=$((PASS+1)); else echo "  ✗ $name (expected $expected, got $actual)"; FAIL=$((FAIL+1)); fi; }
assert_file_contains() { local file=$1 pattern=$2 name=$3; TOTAL=$((TOTAL+1)); if grep -q "$pattern" "$file" 2>/dev/null; then echo "  ✓ $name"; PASS=$((PASS+1)); else echo "  ✗ $name (missing: $pattern)"; FAIL=$((FAIL+1)); fi; }
assert_file_exists() { local file=$1 name=$2; TOTAL=$((TOTAL+1)); if [[ -f "$file" ]]; then echo "  ✓ $name"; PASS=$((PASS+1)); else echo "  ✗ $name (not found: $file)"; FAIL=$((FAIL+1)); fi; }

echo "Test 1: Goal-only setup"
setup
CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" --goal "Test goal" --prompt "Goal: Test goal" > /dev/null
assert_file_exists ".claude/autoresearch-loop.local.md" "state file created"
assert_file_contains ".claude/autoresearch-loop.local.md" "goal: Test goal" "goal in frontmatter"
assert_file_contains ".claude/autoresearch-loop.local.md" "active: true" "active is true"
assert_file_contains ".claude/autoresearch-loop.local.md" "iteration: 0" "iteration starts at 0"
assert_file_contains ".claude/autoresearch-loop.local.md" "MANDATORY FIRST STEP" "mandatory instruction prepended"
assert_file_contains ".claude/autoresearch-loop.local.md" "Goal: Test goal" "user prompt in body"
teardown

echo "Test 2: Full config"
setup
CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" \
  --goal "Optimize latency" --prompt "Goal: Optimize latency" \
  --guard "bash check.sh" --verify "bash metric.sh" --direction "lower" \
  --max-iterations 25 --completion-promise "Latency under 100ms" \
  --evaluator "on" --max-rework 3 > /dev/null
assert_file_contains ".claude/autoresearch-loop.local.md" "max_iterations: 25" "max iterations"
assert_file_contains ".claude/autoresearch-loop.local.md" 'completion_promise: "Latency under 100ms"' "promise set"
assert_file_contains ".claude/autoresearch-loop.local.md" "evaluator: on" "evaluator set"
teardown

echo "Test 3: Missing goal fails"
setup
set +e; OUTPUT=$(CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" --prompt "no goal" 2>&1); EXIT=$?; set -e
assert_exit 1 "$EXIT" "exits 1 when goal missing"
teardown

echo "Test 4: Defaults"
setup
CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" --goal "Test" --prompt "Goal: Test" > /dev/null
assert_file_contains ".claude/autoresearch-loop.local.md" "max_iterations: 0" "default unlimited"
assert_file_contains ".claude/autoresearch-loop.local.md" "completion_promise: null" "default no promise"
assert_file_contains ".claude/autoresearch-loop.local.md" "evaluator: on" "default evaluator on"
assert_file_contains ".claude/autoresearch-loop.local.md" "max_rework: 2" "default max rework"
teardown

echo ""; echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
