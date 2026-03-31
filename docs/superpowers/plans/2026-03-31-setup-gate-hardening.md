# Setup Gate Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure `/autoresearch` interactive mode never starts the loop without all 5 required fields validated, with a final user confirmation and mechanical dry-run verification.

**Architecture:** Create a new `validate-config.sh` script that mechanically validates all config fields, git state, scope globs, and dry-runs verify/guard commands. Update `autoresearch.md` to fix the Direction gap and add the validate step. Update `SKILL.md` to replace batch-based setup with explicit sequential flow ending in a mandatory confirmation step.

**Tech Stack:** Bash (validate-config.sh), Markdown (prompt updates)

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `claude-plugin/scripts/validate-config.sh` | Mechanical validation: required fields, direction value, git state, scope glob, dry-run verify/guard |
| Modify | `claude-plugin/commands/autoresearch.md` | Fix Direction gap, add validate step, add Phase 0, strengthen execution flow |
| Modify | `claude-plugin/skills/autoresearch/SKILL.md:494-535` | Replace batch setup with sequential flow + mandatory confirmation step |
| Sync | `.claude/` dev copies | Mirror all changes |

---

### Task 1: Create validate-config.sh

**Files:**
- Create: `claude-plugin/scripts/validate-config.sh`

- [ ] **Step 1: Create the validation script**

```bash
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

VERIFY_OUTPUT=$(timeout 60 bash -c "$VERIFY" 2>&1)
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

  GUARD_OUTPUT=$(timeout 60 bash -c "$GUARD" 2>&1)
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x claude-plugin/scripts/validate-config.sh`

- [ ] **Step 3: Test — missing fields**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" 2>&1; echo "EXIT: $?"`
Expected: "FAIL: Scope is empty", "FAIL: Metric is empty", etc., EXIT: 1

- [ ] **Step 4: Test — invalid direction**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" --scope "*.md" --metric "count" --direction "up" --verify "echo 42" 2>&1; echo "EXIT: $?"`
Expected: "FAIL: Direction must be 'higher' or 'lower'", EXIT: 1

- [ ] **Step 5: Test — scope matches zero files**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" --scope "nonexistent/**/*.xyz" --metric "count" --direction "higher" --verify "echo 42" 2>&1; echo "EXIT: $?"`
Expected: "FAIL: Scope ... matches 0 files", EXIT: 1

- [ ] **Step 6: Test — verify command fails**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" --scope "*.md" --metric "count" --direction "higher" --verify "exit 1" 2>&1; echo "EXIT: $?"`
Expected: "FAIL: Verify command failed", EXIT: 1

- [ ] **Step 7: Test — verify command has no number**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" --scope "*.md" --metric "count" --direction "higher" --verify "echo hello" 2>&1; echo "EXIT: $?"`
Expected: "FAIL: Verify command produced no numeric output", EXIT: 1

- [ ] **Step 8: Test — all checks pass**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" --scope "*.md" --metric "count" --direction "higher" --verify "echo 42" 2>&1; echo "EXIT: $?"`
Expected: "ALL CHECKS PASSED", EXIT: 0

- [ ] **Step 9: Test — with guard that passes**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" --scope "*.md" --metric "count" --direction "higher" --verify "echo 42" --guard "echo ok" 2>&1; echo "EXIT: $?"`
Expected: "Guard command succeeded", "ALL CHECKS PASSED", EXIT: 0

- [ ] **Step 10: Test — with guard that fails**

Run: `bash claude-plugin/scripts/validate-config.sh --goal "test" --scope "*.md" --metric "count" --direction "higher" --verify "echo 42" --guard "exit 1" 2>&1; echo "EXIT: $?"`
Expected: "FAIL: Guard command failed", EXIT: 1

- [ ] **Step 11: Commit**

```bash
git add claude-plugin/scripts/validate-config.sh
git commit -m "feat: add validate-config.sh for mechanical setup validation"
```

---

### Task 2: Update autoresearch.md command

**Files:**
- Modify: `claude-plugin/commands/autoresearch.md`

Replace the entire file content. Key changes:
- Fix Direction gap in decision logic (line 28: add Direction to check)
- Add `validate-config.sh` to allowed-tools
- Add explicit validate step between setup and loop
- Add Phase 0 git status instructions
- Add mandatory confirmation display step

- [ ] **Step 1: Read the current file**

Run: Read `claude-plugin/commands/autoresearch.md`

- [ ] **Step 2: Replace with updated content**

Write the entire file with:

```markdown
---
name: autoresearch
description: Autonomous Goal-directed Iteration. Modify, verify, keep/discard, repeat. Apply to ANY task with a measurable metric.
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Direction: higher|lower] [Verify: <cmd>] [Guard: <cmd>] [--iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Step 1: Argument Parsing (do this FIRST)

Extract these from $ARGUMENTS. Ignore prose and extract ONLY structured fields:

- `Goal:` — text after "Goal:" keyword
- `Scope:` or `--scope <glob>` — file globs after "Scope:" keyword
- `Metric:` — text after "Metric:" keyword
- `Direction:` — "higher" or "lower" after "Direction:" keyword
- `Verify:` — shell command after "Verify:" keyword
- `Guard:` — shell command after "Guard:" keyword (optional)
- `Iterations:` or `--iterations` — integer N for bounded mode

For each field, record whether it was extracted or is MISSING.

## Step 2: Read Protocol

1. Read the autonomous loop protocol: `.claude/skills/autoresearch/references/autonomous-loop-protocol.md`
2. Read the results logging format: `.claude/skills/autoresearch/references/results-logging.md`

## Step 3: Collect Missing Fields

**Check ALL 5 required fields:** Goal, Scope, Metric, Direction, Verify.

**If ALL 5 are present** → skip to Step 4.

**If ANY of the 5 required fields is MISSING** → you MUST collect them interactively. Follow the "Interactive Setup" section in SKILL.md exactly:

1. Scan the project structure first (detect test framework, file layout, build tools)
2. For EACH missing field, use `AskUserQuestion` to ask the user — provide smart defaults based on your scan
3. Also ask about Guard (optional — user can skip) and Iterations (optional — default unlimited) if not provided inline
4. **MANDATORY — after collecting all fields, display the complete config:**

```
Configuration Summary:
  Goal:       <value>
  Scope:      <value>
  Metric:     <value>
  Direction:  <value>
  Verify:     <value>
  Guard:      <value or "none">
  Iterations: <value or "unlimited">

Ready to launch? [Launch / Edit / Cancel]
```

Use `AskUserQuestion` to ask user to confirm. If "Edit" → ask which field to change. If "Cancel" → stop. If "Launch" → proceed to Step 4.

**YOU MUST NOT proceed to Step 4 without ALL 5 required fields AND user confirmation.**

## Step 4: Validate Config (Mechanical Check)

Run the validation script. This checks git status, scope globs, and dry-runs the verify and guard commands:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh" \
  --goal "<GOAL>" \
  --scope "<SCOPE>" \
  --metric "<METRIC>" \
  --direction "<DIRECTION>" \
  --verify "<VERIFY>" \
  --guard "<GUARD>"
```

**If validation FAILS:**
- Show the user the error message
- Ask which field they want to fix
- Go back to Step 3 to re-collect the failed field
- Re-run validation

**If validation PASSES:** proceed to Step 5.

## Step 5: Activate the Stop Hook

Run the setup script to create the loop state file:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" \
  --goal "<GOAL>" \
  --scope "<SCOPE>" \
  --metric "<METRIC>" \
  --direction "<DIRECTION>" \
  --verify "<VERIFY>" \
  --guard "<GUARD>" \
  --max-iterations <N or 0>
```

## Step 6: Execute the Autonomous Loop

Enter the loop: Modify → Verify → Keep/Discard → Repeat.

If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

Stream all output live. Never stop early unless goal achieved or max_iterations reached.

## Stop Hook Behavior

Once Step 5 creates the state file, the Stop hook is active. If you try to exit, the hook will block the exit and re-inject the loop prompt. To stop: user runs `/autoresearch:cancel` or max iterations are reached.

Do NOT attempt to remove the state file yourself.
```

- [ ] **Step 3: Verify the update**

Run: `grep "Direction" claude-plugin/commands/autoresearch.md | head -5`
Expected: Direction appears in the check condition and field list

Run: `grep "validate-config" claude-plugin/commands/autoresearch.md`
Expected: References to validate-config.sh in allowed-tools and Step 4

- [ ] **Step 4: Commit**

```bash
git add claude-plugin/commands/autoresearch.md
git commit -m "fix: add Direction to required field check, add validate step and confirmation gate"
```

---

### Task 3: Update SKILL.md Interactive Setup section

**Files:**
- Modify: `claude-plugin/skills/autoresearch/SKILL.md:494-535`

Replace the "Setup Phase" and "Interactive Setup" sections with a clearer sequential flow that includes the mandatory confirmation step.

- [ ] **Step 1: Read the current section**

Run: Read `claude-plugin/skills/autoresearch/SKILL.md` lines 494-535

- [ ] **Step 2: Replace the Setup Phase section**

Use the Edit tool to replace lines 494-535. Find the text starting with `## Setup Phase (Do Once)` and ending with `7. **Confirm and go**` line. Replace with:

```markdown
## Setup Phase (Do Once)

### Quick Path (all fields provided inline)

If the user provides **all 5 required fields** (Goal, Scope, Metric, Direction, Verify) inline → extract them, run `validate-config.sh`, then proceed to "Setup Steps" below.

### Interactive Setup (when any required field is missing)

**CRITICAL: If ANY of the 5 required fields is missing (Goal, Scope, Metric, Direction, or Verify), you MUST collect them interactively. This is a BLOCKING prerequisite.**

**Before asking questions:** Scan the project to detect:
- Test framework (jest, vitest, pytest, go test, etc.)
- File structure (src/, lib/, content/, etc.)
- Build tools (npm, cargo, go, etc.)
- Existing test coverage or metric commands

**Then ask each missing field one at a time via `AskUserQuestion`:**

| Order | Field | Question | Smart Defaults |
|-------|-------|----------|----------------|
| 1 | Goal | "What do you want to improve?" | Based on project context |
| 2 | Scope | "Which files can autoresearch modify?" | Detected globs from project structure |
| 3 | Metric | "What number tells you if it got better? (must be a command output)" | Detected from test framework |
| 4 | Direction | "Higher or lower is better?" | "Higher is better" / "Lower is better" |
| 5 | Verify | "What command produces the metric?" | Detected commands from tooling |
| 6 | Guard (optional) | "Any command that must ALWAYS pass? (prevents regressions)" | Detected commands / "Skip — no guard" |
| 7 | Iterations (optional) | "How many iterations? (default: unlimited)" | "Unlimited" / "10" / "25" / "50" |

**Skip questions for fields already provided inline.** Only ask what's missing.

### MANDATORY: Configuration Confirmation

After ALL fields are collected (whether inline or interactive), you MUST display the complete config and ask for confirmation:

```
Configuration Summary:
  Goal:       <value>
  Scope:      <value>
  Metric:     <value>
  Direction:  <value>
  Verify:     <value>
  Guard:      <value or "none">
  Iterations: <value or "unlimited">

Ready to launch? [Launch / Edit / Cancel]
```

- **Launch** → proceed to validation and loop
- **Edit** → ask which field to change, re-collect that field, show summary again
- **Cancel** → stop, do not enter loop

**YOU MUST NOT skip this confirmation step. Even if all fields were provided inline, show the summary and confirm.**

### Mechanical Validation

After user confirms, run `validate-config.sh` to verify:
1. All 5 required fields are non-empty
2. Direction is exactly "higher" or "lower"
3. Inside a git repository, not detached HEAD
4. Scope glob matches at least 1 file
5. Verify command dry-run succeeds and outputs a number
6. Guard command dry-run succeeds (if set)

If validation fails → show the error, ask user to fix the failing field, re-validate.

### Setup Steps (after validation passes)

1. **Read all in-scope files** for full context before any modification
2. **Create a results log** — Track every iteration (see `references/results-logging.md`)
3. **Establish baseline** — Run verification on current state AND guard (if set). Record as iteration #0
4. **Activate Stop Hook** — Run `setup-loop.sh` to create loop state file
5. **BEGIN THE LOOP**
```

- [ ] **Step 3: Verify the edit**

Run: `grep "MANDATORY: Configuration Confirmation" claude-plugin/skills/autoresearch/SKILL.md`
Expected: Found on one line

Run: `grep "validate-config.sh" claude-plugin/skills/autoresearch/SKILL.md`
Expected: Referenced in Mechanical Validation section

- [ ] **Step 4: Also fix line 496 — the Quick Path check**

Verify that the old text `"If the user provides Goal, Scope, Metric, and Verify inline"` (missing Direction) is now replaced with `"all 5 required fields"`. This was already handled in Step 2, but verify:

Run: `grep -n "Goal, Scope, Metric, and Verify" claude-plugin/skills/autoresearch/SKILL.md`
Expected: No matches (the old 4-field text should be gone)

- [ ] **Step 5: Commit**

```bash
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "fix: replace batch setup with sequential flow, add mandatory confirmation gate"
```

---

### Task 4: Sync .claude/ dev copies

**Files:**
- Sync: `.claude/commands/autoresearch.md`
- Sync: `.claude/skills/autoresearch/SKILL.md`
- Sync: `.claude/scripts/validate-config.sh`

- [ ] **Step 1: Copy files**

```bash
cp claude-plugin/commands/autoresearch.md .claude/commands/autoresearch.md
cp claude-plugin/skills/autoresearch/SKILL.md .claude/skills/autoresearch/SKILL.md
cp claude-plugin/scripts/validate-config.sh .claude/scripts/validate-config.sh
chmod +x .claude/scripts/validate-config.sh
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/autoresearch.md .claude/skills/autoresearch/SKILL.md .claude/scripts/validate-config.sh
git commit -m "chore: sync dev copies with setup gate hardening changes"
```

---

### Task 5: End-to-end verification

**Files:**
- No files modified — verification only

- [ ] **Step 1: Test validate-config.sh full happy path**

```bash
bash claude-plugin/scripts/validate-config.sh \
  --goal "test coverage" \
  --scope "*.md" \
  --metric "count" \
  --direction "higher" \
  --verify "echo 42" \
  --guard "echo ok" 2>&1
echo "EXIT: $?"
```

Expected: All checks pass, EXIT: 0

- [ ] **Step 2: Test validate-config.sh catches missing Direction**

```bash
bash claude-plugin/scripts/validate-config.sh \
  --goal "test" \
  --scope "*.md" \
  --metric "count" \
  --direction "" \
  --verify "echo 42" 2>&1
echo "EXIT: $?"
```

Expected: "FAIL: Direction is empty", EXIT: 1

- [ ] **Step 3: Verify autoresearch.md references all required fields**

```bash
grep -c "Direction" claude-plugin/commands/autoresearch.md
```

Expected: 4+ occurrences (field list, check condition, validate call, setup-loop call)

- [ ] **Step 4: Verify SKILL.md no longer has old 4-field check**

```bash
grep "Goal, Scope, Metric, and Verify" claude-plugin/skills/autoresearch/SKILL.md
```

Expected: No output (old text removed)

- [ ] **Step 5: Verify SKILL.md has confirmation gate**

```bash
grep "MANDATORY: Configuration Confirmation" claude-plugin/skills/autoresearch/SKILL.md
```

Expected: One match

- [ ] **Step 6: Verify complete plugin structure**

```bash
ls -la claude-plugin/scripts/
```

Expected: Both `setup-loop.sh` and `validate-config.sh` present and executable
