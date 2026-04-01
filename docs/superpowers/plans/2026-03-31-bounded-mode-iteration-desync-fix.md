# Bounded Mode Iteration Counter Desync Fix

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix bounded mode running 2N iterations instead of N by making the stop hook the sole iteration counter.

**Architecture:** The stop hook (`stop-hook.sh`) becomes the single source of truth for iteration counting in bounded mode. The loop protocol (`autonomous-loop-protocol.md`) and skill file (`SKILL.md`) are updated to delegate bounded-mode iteration control entirely to the hook. The protocol's Phase 8 bounded section no longer tracks iterations internally — Claude completes one iteration, stops, and the hook decides whether to re-inject.

**Tech Stack:** Bash (stop-hook.sh, setup-loop.sh), Markdown (protocol docs)

**Bug reference:** `issues.md` — "Bounded mode iteration counter desync — runs 2x expected iterations"

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `claude-plugin/hooks/stop-hook.sh` | Modify | Fix off-by-one: `>` → `>=` on max iteration check |
| `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md` | Modify | Remove bounded-mode internal counting from Phase 8; add "hook controls bounded iteration" |
| `claude-plugin/skills/autoresearch/SKILL.md` | Modify | Update Stop Hook docs and bounded-mode description to reflect hook-as-sole-counter |
| `.claude/skills/autoresearch/references/autonomous-loop-protocol.md` | Sync | Copy from `claude-plugin/` after edit |
| `.claude/skills/autoresearch/SKILL.md` | Sync | Copy from `claude-plugin/` after edit |
| `tests/test-stop-hook.sh` | Create | Shell-based test script to verify hook iteration logic |

---

### Task 1: Write test for stop-hook iteration logic

**Files:**
- Create: `tests/test-stop-hook.sh`

This project has no test framework — we write a standalone bash test that simulates the hook's iteration logic.

- [ ] **Step 1: Create test directory**

```bash
mkdir -p tests
```

- [ ] **Step 2: Write the test script**

Create `tests/test-stop-hook.sh` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Test: stop-hook.sh bounded mode iteration logic
# Simulates the hook being called repeatedly and checks exit behavior.

HOOK="claude-plugin/hooks/stop-hook.sh"
STATE_FILE=".claude/autoresearch-loop.local.md"
PASS=0
FAIL=0

setup_state_file() {
  local iteration="$1"
  local max="$2"
  mkdir -p .claude
  cat > "$STATE_FILE" <<EOF
---
active: true
iteration: ${iteration}
session_id: test-session
max_iterations: ${max}
goal: test goal
scope: test
metric: test metric
direction: higher
verify: echo 1
guard:
started_at: "2026-01-01T00:00:00Z"
---

Continue the autoresearch loop.
EOF
}

cleanup() {
  rm -f "$STATE_FILE"
}

# Helper: run hook with a fake session_id via stdin JSON
run_hook() {
  echo '{"session_id":"test-session"}' | bash "$HOOK" 2>/dev/null
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    ((PASS++))
  else
    echo "  FAIL: $desc (expected='$expected', actual='$actual')"
    ((FAIL++))
  fi
}

# ─── Test 1: Hook allows exit when iteration >= max_iterations ────
echo "Test 1: Hook allows exit when iteration >= max_iterations"
setup_state_file 3 3
EXIT_CODE=0
run_hook > /dev/null || EXIT_CODE=$?
assert_eq "exit code is 0 (allow exit)" "0" "$EXIT_CODE"
assert_eq "state file removed" "false" "$([ -f "$STATE_FILE" ] && echo true || echo false)"
cleanup

# ─── Test 2: Hook blocks exit when iteration < max_iterations ─────
echo "Test 2: Hook blocks exit when iteration < max_iterations"
setup_state_file 0 3
OUTPUT=$(run_hook)
DECISION=$(echo "$OUTPUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['decision'])" 2>/dev/null || echo "")
assert_eq "decision is block" "block" "$DECISION"
# Check iteration was incremented to 1
NEW_ITER=$(sed -n 's/^iteration: //p' "$STATE_FILE" | head -1)
assert_eq "iteration incremented to 1" "1" "$NEW_ITER"
cleanup

# ─── Test 3: Hook blocks at iteration=1, max=3 ───────────────────
echo "Test 3: Hook blocks at iteration=1, max=3"
setup_state_file 1 3
OUTPUT=$(run_hook)
DECISION=$(echo "$OUTPUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['decision'])" 2>/dev/null || echo "")
assert_eq "decision is block" "block" "$DECISION"
NEW_ITER=$(sed -n 's/^iteration: //p' "$STATE_FILE" | head -1)
assert_eq "iteration incremented to 2" "2" "$NEW_ITER"
cleanup

# ─── Test 4: Hook allows at iteration=2, max=3 (NEXT=3 >= 3) ────
echo "Test 4: Hook allows at iteration=2, max=3 (this is the off-by-one fix)"
setup_state_file 2 3
EXIT_CODE=0
run_hook > /dev/null || EXIT_CODE=$?
assert_eq "exit code is 0 (allow exit)" "0" "$EXIT_CODE"
assert_eq "state file removed" "false" "$([ -f "$STATE_FILE" ] && echo true || echo false)"
cleanup

# ─── Test 5: Unbounded mode (max=0) always blocks ────────────────
echo "Test 5: Unbounded mode (max=0) always blocks"
setup_state_file 100 0
OUTPUT=$(run_hook)
DECISION=$(echo "$OUTPUT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['decision'])" 2>/dev/null || echo "")
assert_eq "decision is block" "block" "$DECISION"
cleanup

# ─── Test 6: Hook allows exit when active=false ──────────────────
echo "Test 6: Hook allows exit when active=false"
mkdir -p .claude
cat > "$STATE_FILE" <<'EOF'
---
active: false
iteration: 1
session_id: test-session
max_iterations: 3
goal: test
scope: test
metric: test
direction: higher
verify: echo 1
guard:
started_at: "2026-01-01T00:00:00Z"
---

prompt
EOF
EXIT_CODE=0
run_hook > /dev/null || EXIT_CODE=$?
assert_eq "exit code is 0 (allow exit)" "0" "$EXIT_CODE"
cleanup

# ─── Test 7: No state file → allow exit ──────────────────────────
echo "Test 7: No state file allows exit"
cleanup
EXIT_CODE=0
run_hook > /dev/null || EXIT_CODE=$?
assert_eq "exit code is 0 (allow exit)" "0" "$EXIT_CODE"

# ─── Test 8: Full bounded simulation — 3 iterations exactly ──────
echo "Test 8: Full bounded simulation (max=3 should block exactly 2 times)"
setup_state_file 0 3
BLOCKS=0
for i in 1 2 3 4 5; do
  EXIT_CODE=0
  OUTPUT=$(run_hook 2>/dev/null) || EXIT_CODE=$?
  if [[ "$EXIT_CODE" -eq 0 ]] && [[ -z "$OUTPUT" || "$OUTPUT" != *'"block"'* ]]; then
    break
  fi
  ((BLOCKS++))
done
assert_eq "hook blocked exactly 2 times" "2" "$BLOCKS"
cleanup

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
```

- [ ] **Step 3: Make test executable and run to verify tests fail**

```bash
chmod +x tests/test-stop-hook.sh
bash tests/test-stop-hook.sh
```

Expected: Tests 4 and 8 should **FAIL** — Test 4 because the current code uses `>` (so iteration=2, NEXT=3, 3>3 is false = block instead of allow). Test 8 because the hook blocks 3 times instead of 2.

- [ ] **Step 4: Commit failing tests**

```bash
git add tests/test-stop-hook.sh
git commit -m "test: add stop-hook bounded iteration tests (failing — exposes off-by-one)"
```

---

### Task 2: Fix stop-hook.sh off-by-one

**Files:**
- Modify: `claude-plugin/hooks/stop-hook.sh:64`

- [ ] **Step 1: Change `-gt` to `-ge` on line 64**

In `claude-plugin/hooks/stop-hook.sh`, change line 64 from:

```bash
if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$NEXT_ITERATION" -gt "$MAX_ITERATIONS" ]]; then
```

to:

```bash
if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$NEXT_ITERATION" -ge "$MAX_ITERATIONS" ]]; then
```

This single character change (`-gt` → `-ge`) means: when `iteration=2` and `max=3`, `NEXT=3`, `3 >= 3` is true → allow exit. Previously `3 > 3` was false → wrongly blocked.

- [ ] **Step 2: Run tests to verify they pass**

```bash
bash tests/test-stop-hook.sh
```

Expected: All 8 tests PASS, including Test 4 and Test 8.

- [ ] **Step 3: Commit**

```bash
git add claude-plugin/hooks/stop-hook.sh
git commit -m "fix: stop-hook off-by-one — change -gt to -ge for bounded iteration check"
```

---

### Task 3: Update autonomous-loop-protocol.md — remove bounded-mode internal counting

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md:7-12, 662-682`

Two sections need updating.

- [ ] **Step 1: Update the Loop Modes intro (lines 7-12)**

Replace:

```markdown
Autoresearch supports two loop modes:

- **Unbounded (default):** Loop forever until manually interrupted (`Ctrl+C`)
- **Bounded:** Loop exactly N times when `Iterations: N` is set in the inline config (or `--iterations N` flag for CLI/CI)

When bounded, track `current_iteration` against `max_iterations`. After the final iteration, print a summary and stop.
```

With:

```markdown
Autoresearch supports two loop modes:

- **Unbounded (default):** Loop forever until manually interrupted (`Ctrl+C`)
- **Bounded:** Loop exactly N times when `Iterations: N` is set in the inline config (or `--iterations N` flag for CLI/CI)

In both modes, the **stop hook** is the mechanical enforcement layer. In bounded mode, the hook tracks the iteration counter and allows exit after N iterations. You do NOT need to track iterations yourself — complete each iteration (Phase 1→7), then stop. The hook decides whether to re-inject.
```

- [ ] **Step 2: Replace Phase 8 Bounded Mode section (lines 662-682)**

Replace:

```markdown
### Bounded Mode (with Iterations: N)

\```
IF current_iteration < max_iterations:
    Go to Phase 1
ELIF goal_achieved:
    Print: "Goal achieved at iteration {N}! Final metric: {value}"
    Print final summary
    STOP
ELSE:
    Print final summary
    STOP
\```

**Final summary format:**
\```
=== Autoresearch Complete (N/N iterations) ===
Baseline: {baseline} → Final: {current} ({delta})
Keeps: X | Discards: Y | Crashes: Z | Skipped: W (no-ops + hook-blocked)
Best iteration: #{n} — {description}
\```
```

With:

```markdown
### Bounded Mode (with Iterations: N)

**The stop hook controls bounded iteration counting.** You do NOT track iterations internally.

After completing Phase 7 (Log), stop. The hook will either:
- **Re-inject the prompt** (iterations remaining) — you start the next iteration from Phase 1
- **Allow exit** (N iterations reached) — the session ends

The system message from the hook shows your current iteration: `🔬 Autoresearch iteration X/N`. When you see the final iteration (`N/N`), print a summary after completing it.

**Final summary format (print on last iteration):**
```
=== Autoresearch Complete ===
Baseline: {baseline} → Final: {current} ({delta})
Keeps: X | Discards: Y | Crashes: Z | Skipped: W (no-ops + hook-blocked)
Best iteration: #{n} — {description}
```

**How to know it's the last iteration:** The system message shows `iteration N/N`. Complete the iteration normally, print the summary, then stop.
```

- [ ] **Step 3: Run tests to confirm nothing broke**

```bash
bash tests/test-stop-hook.sh
```

Expected: All 8 tests still PASS (this task only changed docs, not code).

- [ ] **Step 4: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md
git commit -m "docs: update loop protocol — bounded mode delegates iteration counting to stop hook"
```

---

### Task 4: Update SKILL.md — stop hook and bounded mode docs

**Files:**
- Modify: `claude-plugin/skills/autoresearch/SKILL.md:601-621`

- [ ] **Step 1: Update the "How It Works" list (lines 601-605)**

Replace:

```markdown
3. Every time you try to exit, the hook:
   - Reads the state file
   - Checks if max iterations reached → if yes, allows exit
   - Otherwise → blocks exit and re-injects the loop prompt
   - Increments the iteration counter
```

With:

```markdown
3. Every time you try to exit, the hook:
   - Reads the state file
   - If `active: false` or max iterations reached → allows exit and removes state file
   - Otherwise → increments iteration counter, blocks exit, and re-injects the loop prompt
```

- [ ] **Step 2: Update "What This Means For You" (lines 607-612)**

Replace:

```markdown
### What This Means For You

- **You cannot exit the loop by stopping.** The hook will restart you.
- **You do not need to ask "should I continue?"** — the hook handles continuation.
- **Focus on the current iteration only.** Do Phase 1-8, then let the hook handle the restart.
- **If truly blocked** (missing permissions, broken environment), output a clear error message. The user can run `/autoresearch:cancel` to stop the loop.
```

With:

```markdown
### What This Means For You

- **You cannot exit the loop by stopping.** The hook will restart you.
- **You do not need to ask "should I continue?"** — the hook handles continuation.
- **In bounded mode, do NOT track iterations yourself.** Complete Phase 1-7, then stop. The hook counts iterations and decides whether to continue or allow exit. The system message shows `iteration X/N` so you know where you are.
- **Focus on the current iteration only.** Do Phase 1-7, log results, then stop.
- **If truly blocked** (missing permissions, broken environment), output a clear error message. The user can run `/autoresearch:cancel` to stop the loop.
```

- [ ] **Step 3: Update "Stopping the Loop" (lines 618-622)**

Replace:

```markdown
### Stopping the Loop

- `/autoresearch:cancel` — removes state file, loop stops on next exit
- Max iterations reached — hook auto-removes state file
- User manually deletes `.claude/autoresearch-loop.local.md`
```

With:

```markdown
### Stopping the Loop

- `/autoresearch:cancel` — removes state file, loop stops on next exit
- Max iterations reached — hook allows exit and removes state file
- User manually deletes `.claude/autoresearch-loop.local.md`
```

- [ ] **Step 4: Commit**

```bash
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "docs: update SKILL.md — stop hook is sole iteration counter for bounded mode"
```

---

### Task 5: Sync dev copies and final verification

**Files:**
- Sync: `.claude/skills/autoresearch/references/autonomous-loop-protocol.md`
- Sync: `.claude/skills/autoresearch/SKILL.md`

- [ ] **Step 1: Copy updated files to .claude/**

```bash
cp claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md .claude/skills/autoresearch/references/autonomous-loop-protocol.md
cp claude-plugin/skills/autoresearch/SKILL.md .claude/skills/autoresearch/SKILL.md
```

- [ ] **Step 2: Verify copies are identical**

```bash
diff claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md .claude/skills/autoresearch/references/autonomous-loop-protocol.md
diff claude-plugin/skills/autoresearch/SKILL.md .claude/skills/autoresearch/SKILL.md
```

Expected: No output (files identical).

- [ ] **Step 3: Run full test suite one final time**

```bash
bash tests/test-stop-hook.sh
```

Expected: All 8 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/autoresearch/references/autonomous-loop-protocol.md .claude/skills/autoresearch/SKILL.md
git commit -m "chore: sync dev copies with bounded-mode iteration fix"
```
