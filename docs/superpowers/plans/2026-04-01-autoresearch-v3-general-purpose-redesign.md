# Autoresearch v3.0 — General-Purpose Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign autoresearch from a metric-only code optimization tool into a general-purpose autonomous iteration engine with multi-agent team, self-evolving knowledge, and prompt passthrough.

**Architecture:** Task-agnostic Stop Hook (with completion promise from Ralph Loop) re-injects the user's original prompt each iteration. Coordinator agent dispatches Research/Dev/Evaluator subagents. Living context document replaces append-only TSV logs.

**Tech Stack:** Bash (hooks/scripts), Markdown (SKILL.md, protocols, commands), jq (JSON processing), Perl (transcript parsing)

**Spec:** `docs/superpowers/specs/2026-04-01-autoresearch-v3-general-purpose-redesign.md`

---

## File Map

### Modified Files
| File | Current Lines | Action |
|------|---------------|--------|
| `claude-plugin/hooks/stop-hook.sh` | 109 | Rewrite — add transcript reading + completion promise |
| `claude-plugin/scripts/setup-loop.sh` | 155 | Rewrite — only goal required, prompt passthrough |
| `claude-plugin/scripts/validate-config.sh` | 184 | Rewrite — validate only provided fields |
| `claude-plugin/skills/autoresearch/SKILL.md` | 713 | Rewrite — slim to ~200 lines |
| `claude-plugin/commands/autoresearch.md` | 106 | Rewrite — new setup flow |
| `claude-plugin/commands/autoresearch/debug.md` | 31 | Update — workflow preset format |
| `claude-plugin/commands/autoresearch/fix.md` | 32 | Update — workflow preset format |
| `claude-plugin/commands/autoresearch/security.md` | 32 | Update — workflow preset format |
| `claude-plugin/commands/autoresearch/ship.md` | 33 | Update — workflow preset format |
| `claude-plugin/commands/autoresearch/scenario.md` | 32 | Update — workflow preset format |
| `claude-plugin/commands/autoresearch/predict.md` | 37 | Update — workflow preset format |
| `claude-plugin/commands/autoresearch/learn.md` | 34 | Update — workflow preset format |
| `claude-plugin/commands/autoresearch/plan.md` | 18 | Update — new param format |
| `claude-plugin/.claude-plugin/plugin.json` | 20 | Update version to 3.0.0 |

### New Files
| File | Purpose |
|------|---------|
| `claude-plugin/skills/autoresearch/references/coordinator-protocol.md` | Coordinator agent protocol |
| `claude-plugin/skills/autoresearch/references/research-agent-protocol.md` | Research agent protocol |
| `claude-plugin/skills/autoresearch/references/dev-agent-protocol.md` | Dev agent protocol |
| `claude-plugin/skills/autoresearch/references/evaluator-protocol.md` | Evaluator agent protocol (replaces inline spec in v2 loop protocol) |
| `claude-plugin/skills/autoresearch/references/knowledge-system.md` | context.md format + update rules |
| `claude-plugin/tests/test-stop-hook-v3.sh` | Stop hook integration tests |
| `claude-plugin/tests/test-setup-v3.sh` | Setup script tests |

### Kept As-Is (No Changes)
| File | Reason |
|------|--------|
| `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md` | Kept for backward compat (v2 metric mode) |
| `claude-plugin/skills/autoresearch/references/results-logging.md` | Kept for backward compat (v2 metric mode) |
| `claude-plugin/skills/autoresearch/references/core-principles.md` | Universal principles, still referenced |
| `claude-plugin/skills/autoresearch/references/debug-workflow.md` | Workflow preset source for /autoresearch:debug |
| `claude-plugin/skills/autoresearch/references/fix-workflow.md` | Workflow preset source for /autoresearch:fix |
| `claude-plugin/skills/autoresearch/references/security-workflow.md` | Workflow preset source for /autoresearch:security |
| `claude-plugin/skills/autoresearch/references/ship-workflow.md` | Workflow preset source for /autoresearch:ship |
| `claude-plugin/skills/autoresearch/references/scenario-workflow.md` | Workflow preset source for /autoresearch:scenario |
| `claude-plugin/skills/autoresearch/references/predict-workflow.md` | Workflow preset source for /autoresearch:predict |
| `claude-plugin/skills/autoresearch/references/learn-workflow.md` | Workflow preset source for /autoresearch:learn |
| `claude-plugin/skills/autoresearch/references/plan-workflow.md` | Workflow preset source for /autoresearch:plan |
| `claude-plugin/commands/autoresearch/cancel.md` | Still works (same state file path) |

---

## Task 1: Stop Hook v3 — Add Completion Promise

**Files:**
- Rewrite: `claude-plugin/hooks/stop-hook.sh`
- Create: `claude-plugin/tests/test-stop-hook-v3.sh`

### Why first
The Stop Hook is the mechanical core. Everything else depends on it working.

- [ ] **Step 1: Write the failing test suite**

Create `claude-plugin/tests/test-stop-hook-v3.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/stop-hook.sh"
PASS=0
FAIL=0
TOTAL=0

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init -q
  git commit --allow-empty -m "init" -q
  mkdir -p .claude
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

assert_exit() {
  local expected=$1 actual=$2 name=$3
  TOTAL=$((TOTAL + 1))
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local output="$1" pattern="$2" name="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -q "$pattern"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (output missing: $pattern)"
    FAIL=$((FAIL + 1))
  fi
}

# ─── Test 1: No state file → allow exit ───
echo "Test 1: No state file"
setup
RESULT=$(echo '{"session_id":"s1"}' | bash "$HOOK" 2>&1; echo "EXIT:$?")
EXIT_CODE=$(echo "$RESULT" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
assert_exit 0 "$EXIT_CODE" "exits 0 when no state file"
teardown

# ─── Test 2: Active loop → block exit + re-inject ───
echo "Test 2: Active loop blocks exit"
setup
cat > .claude/autoresearch-loop.local.md <<'EOF'
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
EOF

# Create a fake transcript file
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"I completed the iteration."}]}}' > "$TRANSCRIPT"

OUTPUT=$(echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" '"decision"' "outputs JSON with decision field"
assert_contains "$OUTPUT" '"block"' "decision is block"
assert_contains "$OUTPUT" 'test goal' "re-injects prompt containing goal"

# Check iteration incremented
ITER=$(grep '^iteration:' .claude/autoresearch-loop.local.md | sed 's/iteration: *//')
TOTAL=$((TOTAL + 1))
if [[ "$ITER" == "1" ]]; then
  echo "  ✓ iteration incremented to 1"
  PASS=$((PASS + 1))
else
  echo "  ✗ iteration should be 1, got $ITER"
  FAIL=$((FAIL + 1))
fi
rm -f "$TRANSCRIPT"
teardown

# ─── Test 3: Max iterations reached → allow exit ───
echo "Test 3: Max iterations reached"
setup
cat > .claude/autoresearch-loop.local.md <<'EOF'
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
EOF
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"done"}]}}' > "$TRANSCRIPT"
echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "exits 0 when max iterations reached"
TOTAL=$((TOTAL + 1))
if [[ ! -f .claude/autoresearch-loop.local.md ]]; then
  echo "  ✓ state file removed"
  PASS=$((PASS + 1))
else
  echo "  ✗ state file should be removed"
  FAIL=$((FAIL + 1))
fi
rm -f "$TRANSCRIPT"
teardown

# ─── Test 4: Completion promise matched → allow exit ───
echo "Test 4: Completion promise matched"
setup
cat > .claude/autoresearch-loop.local.md <<'EOF'
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
EOF
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"Everything is done. <promise>ALL TESTS PASS</promise> Great work."}]}}' > "$TRANSCRIPT"
echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "exits 0 when promise matched"
TOTAL=$((TOTAL + 1))
if [[ ! -f .claude/autoresearch-loop.local.md ]]; then
  echo "  ✓ state file removed on promise match"
  PASS=$((PASS + 1))
else
  echo "  ✗ state file should be removed"
  FAIL=$((FAIL + 1))
fi
rm -f "$TRANSCRIPT"
teardown

# ─── Test 5: Completion promise NOT matched → block ───
echo "Test 5: Completion promise not matched"
setup
cat > .claude/autoresearch-loop.local.md <<'EOF'
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
EOF
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"Still working on it."}]}}' > "$TRANSCRIPT"
OUTPUT=$(echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" '"block"' "blocks exit when promise not matched"
rm -f "$TRANSCRIPT"
teardown

# ─── Test 6: Different session → allow exit ───
echo "Test 6: Session isolation"
setup
cat > .claude/autoresearch-loop.local.md <<'EOF'
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
EOF
echo '{"session_id":"session-B"}' | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?
assert_exit 0 "$EXIT_CODE" "allows exit for different session"
teardown

# ─── Test 7: Unlimited mode (max_iterations=0) → always block ───
echo "Test 7: Unlimited mode"
setup
cat > .claude/autoresearch-loop.local.md <<'EOF'
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
EOF
TRANSCRIPT=$(mktemp --suffix=.jsonl)
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"still going"}]}}' > "$TRANSCRIPT"
OUTPUT=$(echo "{\"session_id\":\"test-session\",\"transcript_path\":\"$TRANSCRIPT\"}" | bash "$HOOK" 2>&1)
assert_contains "$OUTPUT" '"block"' "blocks exit in unlimited mode at iteration 99"
rm -f "$TRANSCRIPT"
teardown

# ─── Summary ───
echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/ubuntu/DEV/autoresearch && bash claude-plugin/tests/test-stop-hook-v3.sh`
Expected: Tests fail because current stop-hook.sh doesn't support completion_promise field or transcript reading.

- [ ] **Step 3: Write the new stop-hook.sh**

Rewrite `claude-plugin/hooks/stop-hook.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

# ─── Autoresearch v3 Stop Hook ──────────────────────────────────
# Prevents session exit during active autoresearch loop.
# Checks: completion promise (transcript) → max iterations → re-inject.

STATE_FILE=".claude/autoresearch-loop.local.md"

# ─── No state file → allow exit ─────────────────────────────────
[[ ! -f "$STATE_FILE" ]] && exit 0

# ─── Parse YAML frontmatter ─────────────────────────────────────
parse_field() {
  local field="$1"
  local value
  value=$(sed -n "/^---$/,/^---$/{ s/^${field}: *//p; }" "$STATE_FILE" | head -1)
  value="${value%\"}"
  value="${value#\"}"
  echo "$value"
}

ACTIVE=$(parse_field "active")
[[ "$ACTIVE" != "true" ]] && exit 0

# ─── Read hook input ────────────────────────────────────────────
HOOK_INPUT=$(cat)

# ─── Session isolation ──────────────────────────────────────────
SESSION_ID_STATE=$(parse_field "session_id")
HOOK_SESSION_ID=""
if command -v jq &>/dev/null; then
  HOOK_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
fi
if [[ -n "$HOOK_SESSION_ID" ]] && [[ -n "$SESSION_ID_STATE" ]] && [[ "$SESSION_ID_STATE" != "unknown" ]]; then
  [[ "$HOOK_SESSION_ID" != "$SESSION_ID_STATE" ]] && exit 0
fi

# ─── Validate numeric fields ────────────────────────────────────
ITERATION=$(parse_field "iteration")
MAX_ITERATIONS=$(parse_field "max_iterations")

if ! [[ "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Warning: autoresearch state file has invalid iteration: '$ITERATION'. Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi
if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: autoresearch state file has invalid max_iterations: '$MAX_ITERATIONS'. Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ─── Check completion promise (NEW — from Ralph Loop) ───────────
COMPLETION_PROMISE=$(parse_field "completion_promise")

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  TRANSCRIPT_PATH=""
  if command -v jq &>/dev/null; then
    TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  fi

  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    # Extract last assistant text block (capped at last 100 lines)
    LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100 || true)
    if [[ -n "$LAST_LINES" ]]; then
      set +e
      LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
        map(.message.content[]? | select(.type == "text") | .text) | last // ""
      ' 2>&1)
      JQ_EXIT=$?
      set -e

      if [[ $JQ_EXIT -eq 0 ]] && [[ -n "$LAST_OUTPUT" ]]; then
        # Extract <promise>...</promise> tag
        PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

        if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
          echo "✅ Autoresearch: completion promise fulfilled — <promise>$COMPLETION_PROMISE</promise>" >&2
          rm -f "$STATE_FILE"
          exit 0
        fi
      fi
    fi
  fi
fi

# ─── Check max iterations ───────────────────────────────────────
NEXT_ITERATION=$((ITERATION + 1))

if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$NEXT_ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  echo "Autoresearch: max iterations ($MAX_ITERATIONS) reached." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ─── Extract prompt (everything after second ---) ────────────────
PROMPT=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$STATE_FILE")

if [[ -z "$PROMPT" ]]; then
  echo "Warning: autoresearch state file has no prompt. Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ─── Increment iteration counter ────────────────────────────────
TMPFILE=$(mktemp)
sed "s/^iteration: .*/iteration: ${NEXT_ITERATION}/" "$STATE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$STATE_FILE"

# ─── Build system message ───────────────────────────────────────
GOAL=$(parse_field "goal")

SYS_MSG="🔬 Autoresearch iteration ${NEXT_ITERATION}"
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then
  SYS_MSG="${SYS_MSG}/${MAX_ITERATIONS}"
fi
SYS_MSG="${SYS_MSG} | Goal: ${GOAL} | To stop: /autoresearch:cancel"

# ─── Block exit and re-inject prompt ─────────────────────────────
if command -v jq &>/dev/null; then
  jq -n \
    --arg decision "block" \
    --arg reason "$PROMPT" \
    --arg systemMessage "$SYS_MSG" \
    '{"decision": $decision, "reason": $reason, "systemMessage": $systemMessage}'
else
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$PROMPT")
  ESCAPED_MSG=$(printf '%s' "$SYS_MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$SYS_MSG")
  echo "{\"decision\": \"block\", \"reason\": ${ESCAPED_PROMPT}, \"systemMessage\": ${ESCAPED_MSG}}"
fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/ubuntu/DEV/autoresearch && bash claude-plugin/tests/test-stop-hook-v3.sh`
Expected: All 7 tests pass (12+ assertions).

- [ ] **Step 5: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/hooks/stop-hook.sh claude-plugin/tests/test-stop-hook-v3.sh
git commit -m "feat: stop-hook v3 — add completion promise via transcript reading"
```

---

## Task 2: Setup Script v3 — Prompt Passthrough

**Files:**
- Rewrite: `claude-plugin/scripts/setup-loop.sh`
- Create: `claude-plugin/tests/test-setup-v3.sh`

- [ ] **Step 1: Write the failing test suite**

Create `claude-plugin/tests/test-setup-v3.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SETUP="$(cd "$(dirname "$0")/.." && pwd)/scripts/setup-loop.sh"
PASS=0
FAIL=0
TOTAL=0

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init -q
  git commit --allow-empty -m "init" -q
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

assert_exit() {
  local expected=$1 actual=$2 name=$3
  TOTAL=$((TOTAL + 1))
  if [[ "$actual" -eq "$expected" ]]; then echo "  ✓ $name"; PASS=$((PASS + 1))
  else echo "  ✗ $name (expected $expected, got $actual)"; FAIL=$((FAIL + 1)); fi
}

assert_file_contains() {
  local file=$1 pattern=$2 name=$3
  TOTAL=$((TOTAL + 1))
  if grep -q "$pattern" "$file" 2>/dev/null; then echo "  ✓ $name"; PASS=$((PASS + 1))
  else echo "  ✗ $name (file missing: $pattern)"; FAIL=$((FAIL + 1)); fi
}

assert_file_exists() {
  local file=$1 name=$2
  TOTAL=$((TOTAL + 1))
  if [[ -f "$file" ]]; then echo "  ✓ $name"; PASS=$((PASS + 1))
  else echo "  ✗ $name (file not found: $file)"; FAIL=$((FAIL + 1)); fi
}

# ─── Test 1: Goal-only (minimal) creates state file ───
echo "Test 1: Goal-only setup"
setup
CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" --goal "Test goal" --prompt "Goal: Test goal"
assert_file_exists ".claude/autoresearch-loop.local.md" "state file created"
assert_file_contains ".claude/autoresearch-loop.local.md" "goal: Test goal" "goal in frontmatter"
assert_file_contains ".claude/autoresearch-loop.local.md" "active: true" "active is true"
assert_file_contains ".claude/autoresearch-loop.local.md" "iteration: 0" "iteration starts at 0"
assert_file_contains ".claude/autoresearch-loop.local.md" "MANDATORY FIRST STEP" "mandatory instruction prepended"
assert_file_contains ".claude/autoresearch-loop.local.md" "Goal: Test goal" "user prompt in body"
teardown

# ─── Test 2: Full config with all flags ───
echo "Test 2: Full config setup"
setup
CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" \
  --goal "Optimize latency" \
  --prompt "Goal: Optimize latency" \
  --guard "bash check.sh" \
  --verify "bash metric.sh" \
  --direction "lower" \
  --max-iterations 25 \
  --completion-promise "Latency under 100ms" \
  --evaluator "on" \
  --max-rework 3
assert_file_contains ".claude/autoresearch-loop.local.md" "max_iterations: 25" "max iterations set"
assert_file_contains ".claude/autoresearch-loop.local.md" 'completion_promise: "Latency under 100ms"' "promise set"
assert_file_contains ".claude/autoresearch-loop.local.md" "guard: " "guard set"
assert_file_contains ".claude/autoresearch-loop.local.md" "verify: " "verify set"
assert_file_contains ".claude/autoresearch-loop.local.md" "evaluator: on" "evaluator set"
teardown

# ─── Test 3: Missing goal → error ───
echo "Test 3: Missing goal fails"
setup
set +e
OUTPUT=$(CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" --prompt "no goal here" 2>&1)
EXIT=$?
set -e
assert_exit 1 "$EXIT" "exits 1 when goal missing"
teardown

# ─── Test 4: Defaults are correct ───
echo "Test 4: Defaults"
setup
CLAUDE_CODE_SESSION_ID="test-session" bash "$SETUP" --goal "Test" --prompt "Goal: Test"
assert_file_contains ".claude/autoresearch-loop.local.md" "max_iterations: 0" "default unlimited"
assert_file_contains ".claude/autoresearch-loop.local.md" "completion_promise: null" "default no promise"
assert_file_contains ".claude/autoresearch-loop.local.md" "evaluator: on" "default evaluator on"
assert_file_contains ".claude/autoresearch-loop.local.md" "max_rework: 2" "default max rework 2"
teardown

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/ubuntu/DEV/autoresearch && bash claude-plugin/tests/test-setup-v3.sh`
Expected: Fail — current setup-loop.sh requires scope/metric/direction/verify.

- [ ] **Step 3: Write the new setup-loop.sh**

Rewrite `claude-plugin/scripts/setup-loop.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── Autoresearch v3 Setup ──────────────────────────────────────
# Creates state file for the autonomous loop.
# Only --goal is required. All other fields are optional.

usage() {
  cat <<'USAGE'
Usage: setup-loop.sh --goal GOAL --prompt PROMPT [OPTIONS]

Creates .claude/autoresearch-loop.local.md to activate the Stop hook loop.

Required:
  --goal            What to achieve
  --prompt          Full prompt to re-inject each iteration

Optional:
  --guard           Shell command that must always pass (regression check)
  --verify          Shell command that extracts a metric number
  --direction       "higher" or "lower" (required if --verify is set)
  --max-iterations  Stop after N iterations, 0 = unlimited (default: 0)
  --completion-promise  Semantic exit condition text
  --evaluator       "on" or "off" (default: on)
  --max-rework      Max rework attempts on evaluator rejection (default: 2)
  -h, --help        Show this help
USAGE
  exit 0
}

# ─── Argument Parsing ────────────────────────────────────────────
GOAL="" PROMPT="" GUARD="" VERIFY="" DIRECTION=""
MAX_ITERATIONS=0 COMPLETION_PROMISE="null" EVALUATOR="on" MAX_REWORK="2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --goal)                GOAL="$2";                shift 2 ;;
    --prompt)              PROMPT="$2";              shift 2 ;;
    --guard)               GUARD="$2";               shift 2 ;;
    --verify)              VERIFY="$2";              shift 2 ;;
    --direction)           DIRECTION="$2";           shift 2 ;;
    --max-iterations)      MAX_ITERATIONS="$2";      shift 2 ;;
    --completion-promise)  COMPLETION_PROMISE="$2";  shift 2 ;;
    --evaluator)           EVALUATOR="$2";           shift 2 ;;
    --max-rework)          MAX_REWORK="$2";          shift 2 ;;
    -h|--help)             usage ;;
    *)                     echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ─── Validation ──────────────────────────────────────────────────
if [[ -z "$GOAL" ]]; then
  echo "Error: --goal is required" >&2
  exit 1
fi

if [[ -z "$PROMPT" ]]; then
  echo "Error: --prompt is required" >&2
  exit 1
fi

if [[ "$MAX_ITERATIONS" != "0" ]] && ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Error: --max-iterations must be a non-negative integer, got: $MAX_ITERATIONS" >&2
  exit 1
fi

# ─── YAML escape helper ─────────────────────────────────────────
yaml_escape() {
  local val="$1"
  if [[ "$val" == *$'\n'* ]] || [[ "$val" == *':'* ]] || [[ "$val" == *'"'* ]] || [[ "$val" == *"'"* ]]; then
    echo "\"$(echo "$val" | sed 's/"/\\"/g')\""
  else
    echo "$val"
  fi
}

# ─── Quote completion promise for YAML ───────────────────────────
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  CP_YAML="\"$COMPLETION_PROMISE\""
else
  CP_YAML="null"
fi

# ─── Prepend mandatory context instruction to prompt ─────────────
FULL_PROMPT="MANDATORY FIRST STEP: Read .autoresearch/context.md before any action. If it doesn't exist yet, create it with initial state.

${PROMPT}"

# ─── Create state file ──────────────────────────────────────────
mkdir -p .claude
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-unknown}"

cat > .claude/autoresearch-loop.local.md <<EOF
---
active: true
iteration: 0
session_id: ${SESSION_ID}
max_iterations: ${MAX_ITERATIONS}
goal: $(yaml_escape "$GOAL")
completion_promise: ${CP_YAML}
guard: $(yaml_escape "$GUARD")
verify: $(yaml_escape "$VERIFY")
direction: ${DIRECTION}
evaluator: ${EVALUATOR}
max_rework: ${MAX_REWORK}
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

${FULL_PROMPT}
EOF

# ─── Output ──────────────────────────────────────────────────────
echo ""
echo "🔬 Autoresearch loop activated!"
echo "   Goal:                ${GOAL}"
if [[ -n "$GUARD" ]]; then
  echo "   Guard:              ${GUARD}"
fi
if [[ -n "$VERIFY" ]]; then
  echo "   Verify:             ${VERIFY} (${DIRECTION} is better)"
fi
echo "   Evaluator:          ${EVALUATOR}"
echo "   Max-Rework:         ${MAX_REWORK}"
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then
  echo "   Max iterations:     ${MAX_ITERATIONS}"
else
  echo "   Max iterations:     unlimited"
fi
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo "   Completion promise: ${COMPLETION_PROMISE}"
fi
echo "   Session:            ${SESSION_ID}"
echo ""
echo "The Stop hook will keep this session looping until:"
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo "  - Completion promise is fulfilled, OR"
fi
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then
  echo "  - ${MAX_ITERATIONS} iterations complete, OR"
fi
echo "  - You run /autoresearch:cancel"
echo ""
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/ubuntu/DEV/autoresearch && bash claude-plugin/tests/test-setup-v3.sh`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/scripts/setup-loop.sh claude-plugin/tests/test-setup-v3.sh
git commit -m "feat: setup-loop v3 — goal-only required, prompt passthrough, completion promise"
```

---

## Task 3: Validate Script v3 — Optional Fields

**Files:**
- Rewrite: `claude-plugin/scripts/validate-config.sh`

- [ ] **Step 1: Write the new validate-config.sh**

Rewrite `claude-plugin/scripts/validate-config.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── Autoresearch v3 Config Validation ──────────────────────────
# Validates only provided fields. Goal is the only required field.

usage() {
  cat <<'USAGE'
Usage: validate-config.sh --goal GOAL [OPTIONS]

Validates autoresearch configuration. Only --goal is required.
Other flags are validated only if provided.

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

# ─── Required: Goal ─────────────────────────────────────────────
if [[ -z "$GOAL" ]]; then
  ERRORS+=("Goal is required but was not provided.")
fi

# ─── Required: Git repo ─────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  ERRORS+=("Not inside a git repository. Autoresearch requires git for memory.")
fi
if git rev-parse --is-inside-work-tree &>/dev/null; then
  if git symbolic-ref -q HEAD &>/dev/null; then
    : # OK, on a branch
  else
    ERRORS+=("Detached HEAD state. Please checkout a branch before starting.")
  fi
fi

# ─── Optional: Direction ────────────────────────────────────────
if [[ -n "$DIRECTION" ]] && [[ "$DIRECTION" != "higher" ]] && [[ "$DIRECTION" != "lower" ]]; then
  ERRORS+=("Direction must be 'higher' or 'lower', got: '$DIRECTION'")
fi

# ─── Optional: Verify (dry-run) ─────────────────────────────────
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

# ─── Optional: Guard (dry-run) ──────────────────────────────────
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

# ─── Optional: Evaluator ────────────────────────────────────────
if [[ -n "$EVALUATOR" ]] && [[ "$EVALUATOR" != "on" ]] && [[ "$EVALUATOR" != "off" ]]; then
  ERRORS+=("Evaluator must be 'on' or 'off', got: '$EVALUATOR'")
fi

# ─── Optional: Max-Rework ───────────────────────────────────────
if [[ -n "$MAX_REWORK" ]] && ! [[ "$MAX_REWORK" =~ ^[0-9]+$ ]]; then
  ERRORS+=("Max-rework must be a non-negative integer, got: '$MAX_REWORK'")
fi

# ─── Report ─────────────────────────────────────────────────────
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "❌ Validation failed:" >&2
  for err in "${ERRORS[@]}"; do
    echo "  - $err" >&2
  done
  exit 1
fi

echo "✅ Validation passed" >&2
exit 0
```

- [ ] **Step 2: Test the new validate script**

Run:
```bash
cd /home/ubuntu/DEV/autoresearch
# Should pass — goal only
bash claude-plugin/scripts/validate-config.sh --goal "Test"
# Should fail — no goal
bash claude-plugin/scripts/validate-config.sh 2>&1; echo "exit: $?"
# Should fail — verify without direction
bash claude-plugin/scripts/validate-config.sh --goal "Test" --verify "echo 42" 2>&1; echo "exit: $?"
```
Expected: First passes, second fails with "Goal is required", third fails with "--direction is required when --verify is set".

- [ ] **Step 3: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/scripts/validate-config.sh
git commit -m "feat: validate-config v3 — goal-only required, optional field validation"
```

---

## Task 4: Knowledge System Reference Doc

**Files:**
- Create: `claude-plugin/skills/autoresearch/references/knowledge-system.md`

- [ ] **Step 1: Write knowledge-system.md**

Create `claude-plugin/skills/autoresearch/references/knowledge-system.md`:

```markdown
# Knowledge System Protocol

Autoresearch uses a 3-layer knowledge system to ensure context is preserved across iterations and sessions.

## Layer 1: Hook Prompt (Guaranteed Injection)

The Stop Hook re-injects the user's original prompt every iteration. This prompt is prepended with:

```
MANDATORY FIRST STEP: Read .autoresearch/context.md before any action. If it doesn't exist yet, create it with initial state.
```

This is the ONLY context delivery mechanism guaranteed to reach the agent every iteration.

## Layer 2: .autoresearch/context.md (Living Document)

**Location:** `.autoresearch/context.md` in the project root.

**Created by:** Coordinator at the start of the first iteration (if it doesn't exist).

**Updated by:** Coordinator at the END of every iteration.

### Format

```markdown
# Autoresearch Context
Last updated: iteration N | YYYY-MM-DD HH:MM

## Current State
Brief description of where things stand right now. 2-3 sentences max.

## Active Issues
- [ ] Issue description (impact: what this blocks or degrades)
- [ ] Issue description (impact: ...)

## Resolved This Session
- [x] Issue → fix applied (iteration N)
- [x] Issue → fix applied (iteration N)

## Effective Strategies
- Strategy → result achieved
- Strategy → result achieved

## Ineffective Strategies
- Strategy → why it failed (commit: <hash>, reverted)

## Next Priority
What to focus on in the next iteration and why.
```

### Update Rules

1. **Update at iteration END only** — not during the iteration
2. **Resolved issues:** move from Active to Resolved when fixed
3. **Resolved cap:** keep only the 5 most recent resolved items; remove older ones
4. **Size limit:** keep total under ~1000 words. Summarize aggressively.
5. **Each entry is a summary** — not a detailed log. One line per item.
6. **Ineffective strategies include commit hash** — so future iterations can inspect the reverted change via `git show <hash>`

### First Iteration Bootstrap

If `.autoresearch/context.md` does not exist, the Coordinator creates it:

```markdown
# Autoresearch Context
Last updated: iteration 1 | YYYY-MM-DD HH:MM

## Current State
Initial state. [Describe what was observed on first read.]

## Active Issues
[List any issues found during first analysis.]

## Resolved This Session
(none yet)

## Effective Strategies
(none yet)

## Ineffective Strategies
(none yet)

## Next Priority
[Based on first analysis.]
```

## Layer 3: Memory (Cross-Session Persistence)

Uses the project's `.claude/projects/*/memory/` system (auto memory).

### What to Save to Memory

Only findings that remain valuable across sessions:
- Architectural constraints discovered empirically
- Optimal parameters found through experimentation
- Domain-specific knowledge not obvious from code

### What NOT to Save

- Per-iteration details (that's what context.md is for)
- Temporary state
- Anything already captured in context.md
- Anything derivable from code or git history

### When to Save

The Coordinator saves to memory when:
1. A finding would be lost if context.md is reset (new session)
2. The finding is generalizable (not specific to current iteration)
3. The finding required significant effort to discover
```

- [ ] **Step 2: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/knowledge-system.md
git commit -m "docs: add knowledge system protocol — context.md + memory layers"
```

---

## Task 5: Coordinator Protocol

**Files:**
- Create: `claude-plugin/skills/autoresearch/references/coordinator-protocol.md`

- [ ] **Step 1: Write coordinator-protocol.md**

Create `claude-plugin/skills/autoresearch/references/coordinator-protocol.md`:

```markdown
# Coordinator Agent Protocol

You are the Coordinator — the main agent managing the autoresearch iteration loop. You do NOT write code. You orchestrate subagents, review their work, and maintain the knowledge system.

## Iteration Lifecycle

Every iteration follows this sequence:

### 1. Read Context
- Read `.autoresearch/context.md` (MANDATORY — the hook prompt tells you to do this)
- Read `git log --oneline -10` to see recent experiments
- Understand: what's the current state? What was tried? What's the priority?

### 2. Decide
Based on the user's Workflow (if provided) and context.md:
- Which Workflow step are we on?
- What needs to happen this iteration?
- Which agents do we need?

If no Workflow is provided, decide autonomously based on context.md priorities.

### 3. Dispatch Agents

**When analysis is needed** (log analysis, root cause investigation, research):
```
spawn Research Agent with:
  - Task: what to analyze
  - Context: relevant sections from context.md
  - Files/logs: specific paths to examine
```

**When implementation is needed** (code changes, fixes, optimizations):
```
spawn Dev Agent with:
  - Task: what to implement
  - Analysis: Research Agent's findings (if applicable)
  - Files: specific files to modify
  - Guard: guard command (if configured)
  - Verify: verify command (if configured)
```

**After Dev completes** (if Evaluator is enabled):
```
spawn Evaluator Agent with:
  - Git diff: Dev's changes
  - Analysis: Research findings that motivated the changes
  - Goal: user's goal
  - Notes: user's constraints/rules
  - Previous critique: if this is a rework attempt
```

### 4. Review Subagent Output

**CRITICAL: Never blindly trust subagent output.**

For Research output:
- Does the analysis cite specific evidence (log lines, error messages, data)?
- Are the conclusions logically supported by the evidence?
- If evidence is weak → ask Research to dig deeper or disregard the conclusion

For Dev output:
- Did the changes compile/run without errors?
- Did guard pass (if set)?
- Did verify show improvement (if set)?
- Send to Evaluator for independent review

For Evaluator output:
- If verdict = "pass" → proceed to Keep
- If verdict = "fail" + rework remaining → revert (git revert), pass critique to Dev, re-dispatch
- If verdict = "fail" + max rework reached → Discard

### 5. Decide: Keep / Discard / Rework

| Condition | Action |
|-----------|--------|
| Evaluator pass (or Evaluator off) + guard pass + verify improved | **Keep** — commit stands |
| Evaluator fail + rework < max_rework | **Rework** — git revert, feed critique to Dev |
| Evaluator fail + rework >= max_rework | **Discard** — git revert, note in context.md |
| Guard fail | **Discard** — git revert immediately |
| Verify worse (if metric mode) | **Discard** — git revert |
| No changes made | **No-op** — note in context.md |

### 6. Update Knowledge

At the END of the iteration:

1. **Update `.autoresearch/context.md`** — see `references/knowledge-system.md` for format
   - Update Current State
   - Move resolved issues from Active to Resolved
   - Add new issues to Active
   - Record effective/ineffective strategies
   - Set Next Priority for the next iteration

2. **Save to memory** (if cross-session finding discovered) — see knowledge-system.md

### 7. Exit

Simply stop. The Stop Hook will catch your exit and re-inject the prompt for the next iteration.

Do NOT:
- Ask "should I continue?" — the hook handles this
- Try to sleep or schedule — the hook handles this
- Remove the state file — only /autoresearch:cancel does this
- Output `<promise>` tag unless the completion promise is genuinely true

## Trust Rules

| Subagent | Trust Level | Verification Required |
|----------|-------------|----------------------|
| Research | Moderate | Check evidence exists and supports conclusion |
| Dev | Low | Always send to Evaluator; always check guard/verify |
| Evaluator | High | Can override only with explicit justification |

## When to Use Which Agents

| Situation | Agents Needed |
|-----------|---------------|
| Log analysis, investigation, diagnosis | Research |
| Code changes, fixes, implementation | Dev → Evaluator |
| Simple verification (run a command) | Coordinator directly (no subagent needed) |
| Knowledge update only | Coordinator directly |
| Full iteration (analysis + implementation) | Research → Dev → Evaluator |

## Superpowers Integration (Auto-Resolve Mode)

When autoresearch is active, use superpowers skills in auto-resolve mode:
- **brainstorming:** Select best approach yourself, no interactive gate
- **writing-plans:** Write and approve plans yourself
- **executing-plans:** Execute autonomously
- **systematic-debugging:** Follow protocol autonomously

Never wait for user approval during the loop. You are the autonomous decision-maker.

## Completion Promise

If a `completion_promise` is configured, output `<promise>TEXT</promise>` ONLY when the statement is genuinely true. The hook reads your transcript and matches this tag to decide whether to stop the loop.

**Never lie to escape the loop.** If you're stuck, note it in context.md and try a different approach.
```

- [ ] **Step 2: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/coordinator-protocol.md
git commit -m "docs: add coordinator agent protocol"
```

---

## Task 6: Research Agent Protocol

**Files:**
- Create: `claude-plugin/skills/autoresearch/references/research-agent-protocol.md`

- [ ] **Step 1: Write research-agent-protocol.md**

Create `claude-plugin/skills/autoresearch/references/research-agent-protocol.md`:

```markdown
# Research Agent Protocol

You are a Research Agent dispatched by the Coordinator. Your job is to analyze, investigate, and diagnose — not to implement.

## Input

The Coordinator provides:
- **Task:** What to analyze (e.g., "analyze logs from the past hour for errors")
- **Context:** Relevant state from context.md
- **Files/logs:** Specific paths to examine

## Output

Return a structured analysis report:

```
## Findings

### Finding 1: [Title]
**Evidence:** [specific log line, error message, data point]
**Impact:** [what this causes]
**Confidence:** [high/medium/low]

### Finding 2: [Title]
...

## Proposed Solutions (ranked by impact)

1. **[Solution]** — addresses Finding N
   - Approach: [specific steps]
   - Risk: [what could go wrong]
   - Files to modify: [paths]

2. **[Solution]** — addresses Finding N
   ...

## Questions for Coordinator
- [Any ambiguities or missing information]
```

## Rules

1. **Every finding must have evidence.** No speculation. If you suspect something but can't prove it, say "suspected, needs verification" and explain what evidence would confirm it.

2. **Be specific.** Not "there are errors in the logs" but "line 4523 of bot.log shows 'RPC timeout after 30s' occurring 12 times between 14:00-14:30".

3. **Rank solutions by impact.** Most impactful first. Include effort estimate if relevant.

4. **Don't implement.** Your job is analysis only. The Dev Agent will handle implementation.

5. **Challenge assumptions.** If the context.md says "X doesn't work", verify independently. Previous conclusions may be wrong.
```

- [ ] **Step 2: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/research-agent-protocol.md
git commit -m "docs: add research agent protocol"
```

---

## Task 7: Dev Agent Protocol

**Files:**
- Create: `claude-plugin/skills/autoresearch/references/dev-agent-protocol.md`

- [ ] **Step 1: Write dev-agent-protocol.md**

Create `claude-plugin/skills/autoresearch/references/dev-agent-protocol.md`:

```markdown
# Dev Agent Protocol

You are a Dev Agent dispatched by the Coordinator. Your job is to implement a specific solution, commit it, and run verification.

## Input

The Coordinator provides:
- **Task:** What to implement
- **Analysis:** Research findings that motivate this change (if applicable)
- **Files:** Specific files to modify
- **Guard command:** Shell command that must pass after changes (if set)
- **Verify command:** Shell command that measures a metric (if set)

## Process

### 1. Understand
Read the task and analysis completely. If anything is unclear, note it in your output — do not guess.

### 2. Implement
- Make ONE focused, atomic change
- If the task requires multiple files, that's OK — but it must serve a single logical purpose
- One-sentence test: if describing the change needs "and" to link two actions → it's too big

### 3. Commit
```bash
git add <specific-files>  # Never git add -A
git commit -m "experiment(<scope>): <description>"
```
Commit BEFORE verification. This enables clean rollback.

### 4. Verify (if commands provided)

**Guard (if set):**
```bash
<guard command>
```
Guard MUST pass. If it fails, report failure immediately.

**Verify (if set):**
```bash
<verify command>
```
Extract the metric number from output. Report it.

## Output

Return:
```
## Implementation Summary
- Changed: [file1, file2]
- Description: [one sentence]
- Commit: [hash]

## Verification Results
- Guard: [PASS/FAIL + output]
- Verify: [metric value + PASS/FAIL]

## Git Diff
[full diff of changes]
```

## Rules

1. **Atomic changes only.** One logical change per dispatch.
2. **Commit before verify.** This enables git revert on failure.
3. **Never modify test/guard files.** Adapt your implementation to pass existing tests, not the other way around.
4. **Report honestly.** If verification fails, report it. Don't try to fix it yourself — the Coordinator will decide whether to rework or discard.
5. **Use git revert for rollbacks** (not git reset). Preserves history for learning.
```

- [ ] **Step 2: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/dev-agent-protocol.md
git commit -m "docs: add dev agent protocol"
```

---

## Task 8: Evaluator Agent Protocol

**Files:**
- Create: `claude-plugin/skills/autoresearch/references/evaluator-protocol.md`

- [ ] **Step 1: Write evaluator-protocol.md**

Create `claude-plugin/skills/autoresearch/references/evaluator-protocol.md`:

```markdown
# Evaluator Agent Protocol

You are an independent Evaluator. Your job is to review implementation quality, challenge assumptions, and catch blind spots. You are NOT the implementer — you are the skeptic.

## Input

The Coordinator provides:
- **Git diff:** The Dev Agent's changes
- **Analysis:** Research findings that motivated the changes
- **Goal:** The user's stated goal
- **Notes:** User's constraints and rules
- **Previous critique:** Your prior feedback if this is a rework attempt

## Review Dimensions

Evaluate the change across these dimensions:

1. **Logical correctness** — Does the implementation actually do what the analysis says it should?
2. **Edge cases** — Are there unhandled boundary conditions, race conditions, or error paths?
3. **Side effects** — Does this change break anything outside its scope?
4. **Constraint compliance** — Does it violate any of the user's Notes/rules?
5. **Simplicity** — Is there a simpler way to achieve the same result?

If the user provided custom Notes, pay special attention to those constraints.

## Output

Return strict JSON:

```json
{
  "verdict": "pass",
  "critique": "",
  "suggestions": [],
  "risk_flags": []
}
```

Or on failure:

```json
{
  "verdict": "fail",
  "critique": "Specific issue found: [description with code reference]",
  "suggestions": [
    "Actionable fix: [specific code change]"
  ],
  "risk_flags": ["race-condition", "constraint-violation"]
}
```

## Rules

1. **Be specific.** Not "this might have issues" but "line 42 of pool.ts: the tickSpacing check uses > instead of >= which misses the boundary case".

2. **Critique must be actionable.** Every fail verdict must include suggestions the Dev Agent can act on.

3. **Question the Research analysis too.** If the analysis seems flawed and the implementation faithfully implements a flawed plan, flag it. You are not just reviewing code — you are reviewing the entire reasoning chain.

4. **Don't be a gatekeeper for style.** Focus on correctness and constraints. Naming conventions, formatting, and minor style issues are not reasons to fail.

5. **If this is a rework:** Check that your previous critique was actually addressed. Don't introduce new complaints on rework — focus on whether the original issue is fixed.

6. **pass with risk_flags** is valid. Use risk_flags for concerns that don't warrant a fail but the Coordinator should be aware of.
```

- [ ] **Step 2: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/evaluator-protocol.md
git commit -m "docs: add evaluator agent protocol"
```

---

## Task 9: SKILL.md v3 — Lean Rewrite

**Files:**
- Rewrite: `claude-plugin/skills/autoresearch/SKILL.md`

- [ ] **Step 1: Back up the current SKILL.md**

```bash
cd /home/ubuntu/DEV/autoresearch
cp claude-plugin/skills/autoresearch/SKILL.md claude-plugin/skills/autoresearch/SKILL.md.v2-backup
```

- [ ] **Step 2: Write the new SKILL.md**

Rewrite `claude-plugin/skills/autoresearch/SKILL.md`:

```markdown
---
name: autoresearch
description: Autonomous Goal-directed Iteration. Loops autonomously with multi-agent team — Research, Dev, Evaluator. Works with ANY task.
version: 3.0.0
---

# Autoresearch — Autonomous Goal-directed Iteration

Autonomous iteration engine. Define a goal, optionally a workflow, and let the agent team loop: analyze → implement → evaluate → keep/discard → repeat.

## Quick Start

```
/autoresearch "
Goal: <what to achieve>

Workflow:
1. <step 1>
2. <step 2>

Notes:
- <constraint>
" --max-iterations 10 --completion-promise "Done"
```

**Goal** is the only required field. Everything else is optional.

## MANDATORY: Setup Confirmation

For ALL commands, before launching:

1. Parse user's prompt + flags
2. If ANY field is unclear or missing, ask via `AskUserQuestion` — show all fields in one batch:
   - Goal (required)
   - Workflow (optional — skip = Coordinator decides)
   - Notes (optional — skip = none)
   - Guard (optional — shell command, skip = none)
   - Verify + Direction (optional — metric command + higher/lower, skip = none)
   - Max Iterations (optional — skip = unlimited)
   - Completion Promise (optional — skip = none)
   - Evaluator (optional — skip = on)
3. Show Configuration Summary with ALL fields
4. User confirms: [Launch / Edit / Cancel]
5. Run `validate-config.sh` with provided fields
6. Run `setup-loop.sh` to create state file and activate hook
7. Begin first iteration

**Never skip confirmation.** Even if all fields are provided inline.

## Config Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `--max-iterations N` | unlimited | Count-based exit |
| `--completion-promise "TEXT"` | none | Semantic exit — output `<promise>TEXT</promise>` when true |
| `--guard "CMD"` | none | Regression check (must pass every iteration) |
| `--verify "CMD"` | none | Metric extraction command |
| `--direction higher\|lower` | (with verify) | Metric direction |
| `--evaluator on\|off` | on | Enable/disable Evaluator |
| `--max-rework N` | 2 | Rework attempts before discard |

## Agent Team

| Agent | Role | Protocol |
|-------|------|----------|
| **Coordinator** (you) | Orchestrate loop, dispatch agents, manage knowledge | `references/coordinator-protocol.md` |
| **Research** | Analyze, investigate, diagnose | `references/research-agent-protocol.md` |
| **Dev** | Implement, commit, verify | `references/dev-agent-protocol.md` |
| **Evaluator** | Independent review, challenge assumptions | `references/evaluator-protocol.md` |

**Read your protocol file** at the start of the first iteration.

**Trust boundaries:**
- Research output → Coordinator verifies evidence exists
- Dev output → Evaluator reviews independently
- Evaluator output → Coordinator makes final decision

## The Loop

```
LOOP:
  1. Read .autoresearch/context.md (mandatory — knowledge from past iterations)
  2. Decide: what does this iteration do? (from Workflow or autonomous)
  3. Dispatch: Research / Dev / Evaluator as needed
  4. Review: check subagent outputs — never blindly trust
  5. Decide: Keep / Discard / Rework
  6. Update: .autoresearch/context.md + memory (if cross-session finding)
  7. Exit → Hook re-injects → next iteration
```

## Knowledge System

See `references/knowledge-system.md` for full protocol.

- **L1: Hook prompt** — guaranteed every iteration (user's original prompt)
- **L2: .autoresearch/context.md** — living document, updated every iteration
- **L3: Memory** — cross-session persistence for important discoveries

## Exit Criteria

Hook checks in order:
1. `<promise>TEXT</promise>` matches completion_promise → stop
2. iteration >= max_iterations → stop
3. `/autoresearch:cancel` → stop
4. None → continue

**Never lie in a promise tag.** Output `<promise>` ONLY when the statement is genuinely true.

## Critical Rules

1. **Read context first** — Every iteration starts by reading `.autoresearch/context.md`
2. **Dispatch, don't do** — Coordinator orchestrates, subagents execute
3. **Trust but verify** — Review subagent output for evidence and quality
4. **One change per iteration** — Atomic. If it breaks, you know why
5. **Git is memory** — Commit before verify, `git revert` (not reset) on failure
6. **Update knowledge** — End every iteration by updating context.md
7. **Autonomous decisions** — Never ask user except for missing access/permissions

## Backward Compatibility

If the prompt contains `Metric:`, `Direction:`, `Verify:`, and `Scope:` fields (v2 format), activate **metric mode**: use `references/autonomous-loop-protocol.md` for the 8-phase protocol and `references/results-logging.md` for TSV logging. These files are kept for this purpose.

## Sub-skills

Sub-skills are workflow presets that pre-fill the Workflow field:

| Command | Preset | Reference |
|---------|--------|-----------|
| `/autoresearch:debug` | Scientific debugging | `references/debug-workflow.md` |
| `/autoresearch:fix` | Error fixing | `references/fix-workflow.md` |
| `/autoresearch:security` | STRIDE + OWASP audit | `references/security-workflow.md` |
| `/autoresearch:ship` | Shipping workflow | `references/ship-workflow.md` |
| `/autoresearch:scenario` | Scenario exploration | `references/scenario-workflow.md` |
| `/autoresearch:predict` | Multi-persona analysis | `references/predict-workflow.md` |
| `/autoresearch:learn` | Docs generation | `references/learn-workflow.md` |
| `/autoresearch:plan` | Config wizard | `references/plan-workflow.md` |

## Superpowers Integration (Auto-Resolve)

During the loop, use superpowers skills in auto-resolve mode: select approaches yourself, approve plans yourself, execute autonomously. The Evaluator subagent replaces human review.
```

- [ ] **Step 3: Verify line count**

Run: `wc -l claude-plugin/skills/autoresearch/SKILL.md`
Expected: ~160-200 lines (down from 713).

- [ ] **Step 4: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/SKILL.md claude-plugin/skills/autoresearch/SKILL.md.v2-backup
git commit -m "feat: SKILL.md v3 — lean rewrite with agent team, ~200 lines (was 713)"
```

---

## Task 10: Main Command File v3

**Files:**
- Rewrite: `claude-plugin/commands/autoresearch.md`

- [ ] **Step 1: Write the new autoresearch.md**

Rewrite `claude-plugin/commands/autoresearch.md`:

```markdown
---
name: autoresearch
description: Autonomous Goal-directed Iteration. Modify, verify, keep/discard, repeat. Apply to ANY task.
argument-hint: "\"Goal: <text> [Workflow: ...] [Notes: ...]\" [--max-iterations N] [--completion-promise TEXT] [--guard CMD] [--verify CMD] [--direction higher|lower] [--evaluator on|off]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Step 1: Parse Arguments

Extract from $ARGUMENTS:

**From prompt text:**
- `Goal:` — text after keyword (REQUIRED)
- `Workflow:` — numbered steps after keyword (optional)
- `Notes:` — bullet points after keyword (optional)

**From flags (may appear in $ARGUMENTS or as CLI flags):**
- `--max-iterations N` (default: 0 = unlimited)
- `--completion-promise "TEXT"` (default: none)
- `--guard "CMD"` (default: none)
- `--verify "CMD"` (default: none)
- `--direction higher|lower` (required if --verify set)
- `--evaluator on|off` (default: on)
- `--max-rework N` (default: 2)

**Also check for v2 format fields** (backward compat):
- `Scope:`, `Metric:`, `Direction:`, `Verify:` — if all present, activate metric mode

Record which fields were extracted and which are MISSING.

## Step 2: Collect Missing Fields

If Goal is missing → ask via `AskUserQuestion`.

For ALL other fields, show them in one batch for the user to fill or skip:

```
Please configure the autoresearch loop:

1. Goal (required): [pre-filled or ___]
2. Workflow (steps per iteration, Enter to skip):
3. Notes (constraints/rules, Enter to skip):
4. Guard (shell command that must pass, Enter to skip):
5. Verify + Direction (metric command + higher/lower, Enter to skip):
6. Max Iterations (number, Enter to skip → unlimited):
7. Completion Promise (exit condition text, Enter to skip):
8. Evaluator (on/off, Enter to skip → on):
```

Pre-fill any fields already extracted from $ARGUMENTS. Only ask about missing ones.

## Step 3: Show Confirmation

Display the complete config and ask for confirmation:

```
📋 Configuration Summary:

  Goal:                <value>
  Workflow:            <steps or "default — Coordinator decides">
  Notes:               <items or "none">
  Guard:               <command or "none">
  Verify:              <command or "none">
  Direction:           <value or "n/a">
  Evaluator:           <on or off>
  Max-Rework:          <N>
  Max Iterations:      <N or "unlimited">
  Completion Promise:  <text or "none">

  Agent Team:
    - Coordinator: manage loop, dispatch agents, update knowledge
    - Research:    analyze data, find root causes
    - Dev:         implement solutions, commit, verify
    - Evaluator:   independent quality review

  ⚠️  Warnings (if any):
    - No exit criteria set — loop runs forever until /autoresearch:cancel
    - No guard set — no regression protection

Ready? [Launch / Edit / Cancel]
```

If "Edit" → ask which field, re-collect, show summary again.
If "Cancel" → stop.
If "Launch" → proceed.

## Step 4: Validate

Run validation with provided fields only:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh" \
  --goal "<GOAL>" \
  $([ -n "<GUARD>" ] && echo "--guard '<GUARD>'") \
  $([ -n "<VERIFY>" ] && echo "--verify '<VERIFY>' --direction '<DIR>'") \
  $([ -n "<EVALUATOR>" ] && echo "--evaluator '<EVALUATOR>'")
```

If fails → show error, ask to fix, re-validate.

## Step 5: Activate Loop

Build the prompt from Goal + Workflow + Notes:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" \
  --goal "<GOAL>" \
  --prompt "<FULL_PROMPT_TEXT>" \
  $([ -n "<GUARD>" ] && echo "--guard '<GUARD>'") \
  $([ -n "<VERIFY>" ] && echo "--verify '<VERIFY>' --direction '<DIR>'") \
  --max-iterations <N> \
  $([ -n "<PROMISE>" ] && echo "--completion-promise '<PROMISE>'") \
  --evaluator "<EVALUATOR>" \
  --max-rework <N>
```

## Step 6: Begin Iteration 1

Read `references/coordinator-protocol.md` then start the first iteration:
1. Create `.autoresearch/context.md` with initial state
2. Follow your Workflow (or decide autonomously)
3. Dispatch agents as needed
4. Update context.md at the end

The Stop Hook is now active. When you exit, it will re-inject the prompt for the next iteration.
```

- [ ] **Step 2: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/commands/autoresearch.md
git commit -m "feat: main command v3 — one-batch setup, prompt passthrough, agent team"
```

---

## Task 11: Sub-skill Command Updates

**Files:**
- Update: `claude-plugin/commands/autoresearch/debug.md`
- Update: `claude-plugin/commands/autoresearch/fix.md`
- Update: `claude-plugin/commands/autoresearch/security.md`
- Update: `claude-plugin/commands/autoresearch/ship.md`
- Update: `claude-plugin/commands/autoresearch/scenario.md`
- Update: `claude-plugin/commands/autoresearch/predict.md`
- Update: `claude-plugin/commands/autoresearch/learn.md`
- Update: `claude-plugin/commands/autoresearch/plan.md`

Each sub-skill command becomes a thin wrapper that pre-fills the Workflow field and delegates to the main autoresearch command logic.

- [ ] **Step 1: Update debug.md**

Rewrite `claude-plugin/commands/autoresearch/debug.md`:

```markdown
---
name: autoresearch:debug
description: Autonomous bug-hunting loop — scientific method + autoresearch iteration. Finds ALL bugs, not just one.
argument-hint: "[Issue/Symptom description] [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Debug

This is a workflow preset for `/autoresearch`. It pre-fills the Workflow with scientific-method debugging steps.

**Pre-filled Workflow:**
```
1. Read context and review known issues
2. Reproduce the bug — confirm it exists with evidence
3. Form hypothesis about root cause
4. Design experiment to test hypothesis
5. Run experiment and collect evidence
6. If hypothesis confirmed → implement fix
7. Verify fix resolves the issue without regressions
8. Record findings in context
```

**Default config:**
- Evaluator: on
- Completion Promise: (ask user or skip)

Load `references/debug-workflow.md` for the full debugging protocol, then follow the main autoresearch setup flow from `commands/autoresearch.md` — Step 2 onwards — with the Workflow pre-filled above.

Parse $ARGUMENTS for the issue/symptom description as the Goal.
```

- [ ] **Step 2: Update fix.md**

Rewrite `claude-plugin/commands/autoresearch/fix.md`:

```markdown
---
name: autoresearch:fix
description: Autonomous fix loop — iteratively repairs errors until zero remain. One fix per iteration, atomic, auto-reverted on failure.
argument-hint: "[Target errors description] [--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Fix

Pre-filled Workflow:
```
1. Read context and list all current errors (tests, types, lint, build)
2. Pick the highest-impact error
3. Analyze root cause
4. Implement minimal fix
5. Run full test/build suite to verify fix + no regressions
6. Record fix in context
```

**Default config:**
- Evaluator: on
- Guard: (detected from project — npm test, pytest, etc.)

Load `references/fix-workflow.md` for the full fix protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.
```

- [ ] **Step 3: Update security.md**

Rewrite `claude-plugin/commands/autoresearch/security.md`:

```markdown
---
name: autoresearch:security
description: Autonomous security audit — STRIDE threat model + OWASP Top 10 + red-team with 4 adversarial personas
argument-hint: "[Scope/Focus description] [--max-iterations N] [--diff] [--fix] [--fail-on SEVERITY]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Security Audit

Pre-filled Workflow:
` ` `
1. Read context and scan codebase for tech stack, dependencies, configs
2. Identify assets — data stores, auth systems, external services, user inputs
3. Map trust boundaries — browser↔server, public↔auth, user↔admin
4. Build STRIDE threat model for each trust boundary
5. Map attack surface — entry points, data flows, abuse paths
6. Test one vulnerability vector with code evidence
7. Log finding with severity, OWASP category, and code reference
8. Update context with findings and coverage progress
` ` `

**Default config:**
- Evaluator: off (security findings are self-evident with code evidence)

Load `references/security-workflow.md` for the full security audit protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for scope/focus as the Goal. Pass --diff, --fix, --fail-on flags through to Notes.
```

- [ ] **Step 4: Update ship.md**

Rewrite `claude-plugin/commands/autoresearch/ship.md`:

```markdown
---
name: autoresearch:ship
description: Universal shipping workflow — ship code, content, marketing, sales, research, or anything through structured phases
argument-hint: "[What to ship] [--type TYPE] [--dry-run] [--auto] [--monitor N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Ship

Pre-filled Workflow:
` ` `
1. Read context and identify what is being shipped
2. Assess current readiness — inventory gaps and blockers
3. Generate domain-specific pre-ship checklist
4. Fix failing checklist items (one per iteration)
5. Dry-run the ship action without side effects
6. Execute the actual delivery (merge, deploy, publish)
7. Post-ship health check — verify it landed
8. Record shipment in context
` ` `

**Default config:**
- Evaluator: off (shipping checklist is mechanical verification)

Load `references/ship-workflow.md` for the full shipping protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for what to ship as the Goal. Pass --type, --dry-run, --auto, --monitor flags through to Notes.
```

- [ ] **Step 5: Update scenario.md**

Rewrite `claude-plugin/commands/autoresearch/scenario.md`:

```markdown
---
name: autoresearch:scenario
description: Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario
argument-hint: "[Scenario description] [--domain TYPE] [--depth LEVEL] [--focus AREA]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Scenario Exploration

Pre-filled Workflow:
` ` `
1. Read context and parse seed scenario — identify actors, goals, preconditions
2. Decompose into 12 exploration dimensions (happy path, error, edge case, abuse, scale, concurrent, temporal, data variation, permission, integration, recovery, state transition)
3. Generate one concrete situation from an unexplored dimension
4. Classify situation — new, variant, duplicate, or out-of-scope
5. Expand kept situations — derive edge cases, what-ifs, failure modes
6. Record scenarios in context with dimension and severity
7. Pick next unexplored dimension for next iteration
` ` `

**Default config:**
- Evaluator: off (scenarios are exploratory, not code changes)

Load `references/scenario-workflow.md` for the full scenario protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for the seed scenario as the Goal. Pass --domain, --depth, --focus flags through to Notes.
```

- [ ] **Step 6: Update predict.md**

Rewrite `claude-plugin/commands/autoresearch/predict.md`:

```markdown
---
name: autoresearch:predict
description: Multi-persona swarm prediction — pre-analyze code from multiple expert perspectives using file-based knowledge representation
argument-hint: "[Scope/Goal] [--personas N] [--rounds N] [--depth LEVEL] [--chain TARGETS]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Multi-Persona Prediction

Pre-filled Workflow:
` ` `
1. Read context and scan codebase — extract entities, map dependencies
2. Generate 3-5 expert personas from codebase context
3. Each persona analyzes code from their unique perspective
4. Structured debate — 1-2 rounds of cross-examination with Devil's Advocate
5. Synthesize consensus with confidence scores + anti-herd check
6. Write findings to predict/ output folder
7. Generate handoff.json for optional --chain to other tools
8. Record findings in context
` ` `

**Default config:**
- Evaluator: off (prediction is analysis, not code changes)

Load `references/predict-workflow.md` for the full prediction protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for scope/goal as the Goal. Pass --personas, --rounds, --depth, --chain flags through to Notes.
```

- [ ] **Step 7: Update learn.md**

Rewrite `claude-plugin/commands/autoresearch/learn.md`:

```markdown
---
name: autoresearch:learn
description: Autonomous codebase documentation engine — scout, learn, generate/update docs with validation-fix loop
argument-hint: "[--mode MODE] [--scope GLOB] [--depth LEVEL] [--file NAME]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Codebase Learning

Pre-filled Workflow:
` ` `
1. Read context and scout codebase structure (scale-aware, monorepo detection)
2. Classify project type, detect tech stack, measure doc staleness
3. Discover existing docs (docs/*.md), run gap analysis
4. Generate or update one doc per iteration with full context
5. Validate — check code refs, links, completeness, size compliance
6. If validation fails — re-generate with feedback (max 3 retries)
7. Finalize — inventory check, git diff summary
8. Record results in context
` ` `

**Default config:**
- Evaluator: off (validation-fix loop provides mechanical verification)

Load `references/learn-workflow.md` for the full learning protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Auto-detect mode (init/update/check/summarize) based on docs/ state. Parse $ARGUMENTS flags through to Notes.
```

- [ ] **Step 8: Update plan.md**

Rewrite `claude-plugin/commands/autoresearch/plan.md`:

```markdown
---
name: autoresearch:plan
description: Interactive wizard to build Scope, Metric, Direction & Verify from a Goal
argument-hint: "[Goal description]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Planning Wizard

This is a ONE-SHOT command (not a loop). It helps the user build a complete autoresearch configuration.

Pre-filled Workflow:
` ` `
1. Capture the user's Goal (from $ARGUMENTS or ask)
2. Scan codebase for tooling, test runners, build scripts
3. Suggest Scope — file globs, validate they resolve to real files
4. Suggest Metric — mechanical metric, validate it outputs a number
5. Determine Direction — higher or lower is better
6. Construct Verify command — build it, dry-run it, confirm it works
7. Ask about optional fields: Guard, Iterations, Evaluator
8. Present complete config — offer to launch /autoresearch directly
` ` `

Load `references/plan-workflow.md` for the full planning protocol.

Parse $ARGUMENTS for the goal text. This command does NOT enter the autonomous loop — it produces a ready-to-use /autoresearch invocation.
```

- [ ] **Step 4: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/commands/autoresearch/
git commit -m "feat: convert sub-skills to workflow presets"
```

---

## Task 12: Plugin Metadata + Integration Verification

**Files:**
- Update: `claude-plugin/.claude-plugin/plugin.json`

- [ ] **Step 1: Update plugin.json version**

Edit `claude-plugin/.claude-plugin/plugin.json`:
- Change `"version": "1.9.0"` to `"version": "3.0.0"`
- Update description to mention "general-purpose" and "multi-agent team"

```json
{
  "name": "autoresearch",
  "description": "General-purpose autonomous iteration engine for Claude Code. Multi-agent team (Coordinator, Research, Dev, Evaluator) loops on any task with optional metrics. 8 workflow presets: debug, fix, security, ship, scenario, predict, learn, plan.",
  "version": "3.0.0",
  "author": {
    "name": "Udit Goenka",
    "url": "https://github.com/uditgoenka"
  },
  "repository": "https://github.com/uditgoenka/autoresearch",
  "license": "MIT",
  "homepage": "https://github.com/uditgoenka/autoresearch",
  "keywords": ["autonomous", "iteration", "multi-agent", "general-purpose", "debugging", "security-audit", "shipping"]
}
```

- [ ] **Step 2: Run all tests**

```bash
cd /home/ubuntu/DEV/autoresearch
bash claude-plugin/tests/test-stop-hook-v3.sh
bash claude-plugin/tests/test-setup-v3.sh
```

Expected: All tests pass.

- [ ] **Step 3: Verify file structure**

```bash
cd /home/ubuntu/DEV/autoresearch/claude-plugin
echo "=== SKILL.md line count ==="
wc -l skills/autoresearch/SKILL.md
echo "=== New reference files ==="
ls -la skills/autoresearch/references/coordinator-protocol.md \
      skills/autoresearch/references/research-agent-protocol.md \
      skills/autoresearch/references/dev-agent-protocol.md \
      skills/autoresearch/references/evaluator-protocol.md \
      skills/autoresearch/references/knowledge-system.md
echo "=== State file format ==="
cat hooks/hooks.json
```

Expected: SKILL.md < 200 lines, all 5 new reference files exist, hooks.json unchanged.

- [ ] **Step 4: Remove v2 backup**

```bash
cd /home/ubuntu/DEV/autoresearch
rm claude-plugin/skills/autoresearch/SKILL.md.v2-backup
```

- [ ] **Step 5: Final commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add -A
git commit -m "chore: bump version to 3.0.0 — general-purpose autonomous iteration engine"
```

---

## Post-Implementation: Sync to Installed Plugin

After all tasks are complete, sync the dev repo to the installed plugin cache:

```bash
# This step is manual — confirm with user before running
rsync -av --delete \
  /home/ubuntu/DEV/autoresearch/claude-plugin/ \
  /home/ubuntu/.claude/plugins/cache/autoresearch/autoresearch/3.0.0/
```

**Note:** The user should verify the sync target path matches their plugin installation.
