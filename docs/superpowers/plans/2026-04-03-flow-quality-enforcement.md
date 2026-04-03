# Flow Quality Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strengthen autoresearch's quality gates — Pre-Dev Gate scope expansion, Evaluator severity system, mandatory Research re-dispatch after failure, and auto-resolve vs BLOCK distinction.

**Architecture:** Protocol-level changes to 3 reference files (pre-dev-gate, evaluator, coordinator) plus script-level enforcement in flow-check.sh and stop-hook.sh. All changes are additive — no existing checks removed.

**Tech Stack:** Markdown (protocols), Bash (flow-check.sh, stop-hook.sh)

---

### Task 1: stop-hook.sh — Parse and write `previous_outcome` to state file

This must be done first because flow-check.sh check #9 (Task 2) reads this field.

**Files:**
- Modify: `claude-plugin/hooks/stop-hook.sh:126-142` (after workflow_step update, before review instruction)

- [ ] **Step 1: Add `previous_outcome` parsing from transcript**

After the `workflow_step` update block (line 142) and before the Post-iteration Review instruction (line 144), add outcome parsing logic:

```bash
# Update previous_outcome from transcript for next iteration's checks
if [[ -n "$AUDIT_TRANSCRIPT_PATH" ]] && [[ -f "$AUDIT_TRANSCRIPT_PATH" ]]; then
  OUTCOME=$(grep -oE '(KEEP|DISCARD|REWORK)' "$AUDIT_TRANSCRIPT_PATH" | tail -1 || echo "")
  if [[ -n "$OUTCOME" ]]; then
    if grep -q '^previous_outcome:' "$STATE_FILE"; then
      sed -i "s/^previous_outcome: .*/previous_outcome: ${OUTCOME}/" "$STATE_FILE"
    else
      # Insert after workflow_step line
      sed -i "/^workflow_step:/a previous_outcome: ${OUTCOME}" "$STATE_FILE"
    fi
  fi
else
  # First iteration or no transcript — set to null
  if ! grep -q '^previous_outcome:' "$STATE_FILE"; then
    sed -i "/^workflow_step:/a previous_outcome: null" "$STATE_FILE" 2>/dev/null || true
  fi
fi
```

- [ ] **Step 2: Verify `AUDIT_TRANSCRIPT_PATH` is in scope**

`AUDIT_TRANSCRIPT_PATH` is currently set inside the `if [[ "$ITERATION" -gt 0 ]]` block (line 74-103). For iteration 0, it won't be set. Move the transcript path extraction before the audit block so it's available for outcome parsing too.

Move these lines (currently at 78-80) to just after `PLUGIN_ROOT` setup, before the `if [[ "$ITERATION" -gt 0 ]]` block:

```bash
PLUGIN_ROOT=$(cd "$(dirname "$0")/.." && pwd)
FLOW_CHECK="${PLUGIN_ROOT}/scripts/flow-check.sh"
AUDIT_TRANSCRIPT_PATH=""
if command -v jq &>/dev/null; then
  AUDIT_TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
fi
```

Place these at line 72, before `if [[ "$ITERATION" -gt 0 ]]; then`. Then inside the audit block, remove the duplicate `PLUGIN_ROOT`, `FLOW_CHECK`, and `AUDIT_TRANSCRIPT_PATH` lines, keeping only the `if [[ -x "$FLOW_CHECK" ]]` logic.

- [ ] **Step 3: Test — verify state file gets `previous_outcome` field**

Create a temporary state file and transcript, simulate:

```bash
cd /home/ubuntu/DEV/autoresearch
# Create a minimal test state file
cat > /tmp/test-state.md << 'EOF'
---
active: true
iteration: 1
max_iterations: 5
workflow_step: 1
commit_before: "abc123"
---
EOF

# Verify sed insert works
sed -i "/^workflow_step:/a previous_outcome: KEEP" /tmp/test-state.md
grep 'previous_outcome' /tmp/test-state.md
# Expected: previous_outcome: KEEP

# Verify sed replace works
sed -i "s/^previous_outcome: .*/previous_outcome: DISCARD/" /tmp/test-state.md
grep 'previous_outcome' /tmp/test-state.md
# Expected: previous_outcome: DISCARD

rm /tmp/test-state.md
```

- [ ] **Step 4: Commit**

```bash
git add claude-plugin/hooks/stop-hook.sh
git commit -m "feat: parse and persist previous_outcome in stop-hook state file"
```

---

### Task 2: flow-check.sh — Add check #9 (Research after failure)

**Files:**
- Modify: `claude-plugin/scripts/flow-check.sh:130-224` (check_iteration_audit function)

- [ ] **Step 1: Add check #9 inside `check_iteration_audit`**

After check ⑧ (line 218, before the final `if [[ -n "$errors" ]]` block), add:

```bash
  # ⑨ If previous_outcome was DISCARD or REWORK + commits exist → Research must be in transcript
  local previous_outcome
  previous_outcome=$(parse_field "$state_file" "previous_outcome")
  if [[ "$commit_count" -gt 0 ]] && { [[ "$previous_outcome" == "DISCARD" ]] || [[ "$previous_outcome" == "REWORK" ]]; }; then
    local research_mentions
    research_mentions=$(grep -ciE 'Research.*(dispatch|spawn|Agent)' "$transcript_path" 2>/dev/null || echo "0")
    if [[ "$research_mentions" -lt 1 ]]; then
      errors+="previous iteration was ${previous_outcome} but no Research Agent dispatch detected — must re-analyze before Dev\n"
    fi
  fi
```

- [ ] **Step 2: Update usage text**

In the `usage()` function (line 21), update the iteration-audit description:

```
  iteration-audit <state_file> <transcript>  Composite post-iteration check (9 validations)
```

- [ ] **Step 3: Test — verify check #9 catches missing Research**

```bash
cd /home/ubuntu/DEV/autoresearch

# Create test fixtures
mkdir -p /tmp/flow-test/.autoresearch
echo -e "# Context\nCompleted Step: 1" > /tmp/flow-test/.autoresearch/context.md
echo "# Knowledge" > /tmp/flow-test/.autoresearch/knowledge.md
touch /tmp/flow-test/.autoresearch/context.md /tmp/flow-test/.autoresearch/knowledge.md

cat > /tmp/flow-test/state.md << 'EOF'
---
active: true
iteration: 2
commit_before: "HEAD~1"
evaluator: "on"
workflow_step: 1
previous_outcome: DISCARD
---
EOF

# Transcript with Dev but NO Research
echo '{"role":"assistant","message":{"content":[{"type":"text","text":"I will dispatch the Pre-Dev Gate agent. PASS. I will dispatch the Dev Agent. Evaluator verdict pass. KEEP."}]}}' > /tmp/flow-test/transcript.jsonl

# Run check (should fail with check ⑨)
cd /tmp/flow-test && git init && git commit --allow-empty -m "init" && git commit --allow-empty -m "dev change"

bash /home/ubuntu/DEV/autoresearch/claude-plugin/scripts/flow-check.sh iteration-audit /tmp/flow-test/state.md /tmp/flow-test/transcript.jsonl 2>&1 || echo "EXIT: $?"
# Expected: error mentioning "previous iteration was DISCARD but no Research Agent dispatch detected"

rm -rf /tmp/flow-test
```

- [ ] **Step 4: Commit**

```bash
git add claude-plugin/scripts/flow-check.sh
git commit -m "feat: add flow-check #9 — enforce Research dispatch after DISCARD/REWORK"
```

---

### Task 3: Pre-Dev Gate protocol — Scope expansion

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/pre-dev-gate-protocol.md` (full rewrite of sections)

- [ ] **Step 1: Update Input section**

Replace the existing `## Input` section with:

```markdown
## Input

The Coordinator provides:
- **Planned Dev task:** What the Coordinator intends to tell Dev to do
- **Workflow steps:** From config.yaml (full list)
- **Current workflow step:** Which step the Coordinator says this iteration is on
- **Last completed step:** From context.md resolved items
- **Notes:** From config.yaml (constraints)
- **Research done this iteration:** Yes/No + summary of findings (if any)
- **Previous outcome:** KEEP / DISCARD / REWORK / null (from state file — the outcome of the previous iteration)
- **Research summary:** The Research Agent's analysis summary for this iteration (null if no Research dispatched)
```

- [ ] **Step 2: Add new check section C**

After section `### B. Notes Constraint Preview`, add:

```markdown
### C. Research Evidence Quality

1. **Missing Research after failure:** Is `previous_outcome` DISCARD or REWORK, AND no Research was dispatched this iteration?
   - YES → BLOCK (type: `missing-research-after-failure`): "上一輪 [DISCARD/REWORK]，必須 dispatch Research Agent 分析失敗原因再進行 Dev"
2. **Weak Research evidence:** Research was dispatched but the summary lacks concrete evidence (no data points, no log references, no file paths, no measurements)?
   - YES → WARNING: "Research 結論缺乏具體證據支撐 — Dev 應注意驗證假設"
```

- [ ] **Step 3: Update Output section**

Add a new BLOCK output example after the existing one:

```markdown
### BLOCK (missing research)

```
BLOCK
- Type: missing-research-after-failure
- Reason: 上一輪 DISCARD，本輪未 dispatch Research Agent
- Correct action: dispatch Research Agent 分析失敗原因，再基於分析結果 dispatch Dev
```
```

- [ ] **Step 4: Update Rules section**

Replace rule 1:

```markdown
1. **Be efficient but thorough.** Read the Coordinator-provided context (Research summary, previous outcome) but don't independently explore the codebase or run commands.
```

- [ ] **Step 5: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/pre-dev-gate-protocol.md
git commit -m "feat: expand Pre-Dev Gate — research evidence check, previous outcome input"
```

---

### Task 4: Evaluator protocol — Severity system and domain context

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/evaluator-protocol.md` (multiple sections)

- [ ] **Step 1: Update Input section**

Replace the existing `## Input` section with:

```markdown
## Input

The Coordinator provides:
- **Git diff:** The Dev Agent's changes
- **Analysis:** Research findings that motivated the changes
- **Goal:** The user's stated goal
- **Notes:** User's constraints and rules
- **Previous critique:** Your prior feedback if this is a rework attempt
- **context.md:** Current `.autoresearch/context.md` content (Active Issues, Resolved, failed approaches)
- **knowledge.md:** Current `.autoresearch/knowledge.md` content (cumulative domain findings)
```

- [ ] **Step 2: Update Output section**

Replace the existing `## Output` section with:

```markdown
## Output

Return strict JSON:

```json
{
  "verdict": "pass",
  "severity": "minor",
  "severity_rationale": "",
  "critique": "",
  "suggestions": [],
  "risk_flags": []
}
```

Or on failure:

```json
{
  "verdict": "fail",
  "severity": "critical",
  "severity_rationale": "Why this severity — must reference concrete impact",
  "critique": "Specific issue found: [description with code reference]",
  "suggestions": [
    "Actionable fix: [specific code change]"
  ],
  "risk_flags": ["direction-mismatch"]
}
```

### Severity Guidelines

| Level | Definition | Can trigger fail? |
|-------|-----------|-------------------|
| `critical` | Will definitely break production, or violates Notes constraints | Yes |
| `major` | Logic error that may trigger under certain conditions, or contradicts knowledge.md findings | Yes |
| `minor` | Edge case, performance, readability | **No — minor MUST NOT trigger fail** |

When assigning severity, `severity_rationale` MUST explain concrete impact. "Could overflow" is not enough — specify what input range triggers it and whether that range is reachable in practice.

### risk_flag Types

| Flag | When to use |
|------|-------------|
| `direction-mismatch` | Dev's changes don't align with Research analysis conclusions |
| `repeating-failed-approach` | context.md records a similar approach that already failed |
| `race-condition` | Concurrency issue identified |
| `constraint-violation` | Notes rule may be violated |
```

- [ ] **Step 3: Update Rule #3**

Replace existing rule 3 with:

```markdown
3. **Challenge the reasoning chain, not just the code.** If context.md or knowledge.md shows a similar approach already failed, MUST verdict fail with `repeating-failed-approach` risk_flag. If Dev's implementation direction visibly diverges from the Research analysis conclusions, MUST add `direction-mismatch` risk_flag. You review the entire reasoning chain — not just whether the code compiles.
```

- [ ] **Step 4: Add Rule #7**

After existing rule 6, add:

```markdown
7. **Use domain context.** Cross-reference the diff against knowledge.md findings and context.md history. If knowledge.md says "approach X doesn't work because Y" and the diff implements approach X, that's a fail regardless of code quality.
```

- [ ] **Step 5: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/evaluator-protocol.md
git commit -m "feat: evaluator severity system, domain context inputs, direction checks"
```

---

### Task 5: Coordinator protocol — Dispatch inputs, re-dispatch rules, auto-resolve rewrite

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/coordinator-protocol.md` (multiple sections)

- [ ] **Step 1: Update Pre-Dev Gate dispatch block (section 4)**

Replace the existing spawn block at lines 36-41 with:

```markdown
**Before dispatching Dev, you MUST dispatch the Pre-Dev Gate agent:**

```
spawn Pre-Dev Gate with:
  - Planned Dev task description
  - Workflow steps + current step + last completed step
  - Notes constraints
  - Whether Research was done this iteration
  - Previous outcome: KEEP / DISCARD / REWORK / null (from previous iteration)
  - Research summary: analysis summary if Research was dispatched this iteration (null otherwise)
```

See `references/pre-dev-gate-protocol.md`.
```

- [ ] **Step 2: Update Evaluator dispatch block (section 5)**

Replace the existing spawn block at lines 59-65 with:

```markdown
After Dev completes, dispatch Evaluator:

```
spawn Evaluator Agent with:
  - Git diff: Dev's changes
  - Analysis: Research findings that motivated the changes
  - Goal: user's goal
  - Notes: user's constraints
  - Previous critique: if this is a rework attempt
  - context.md: current .autoresearch/context.md content
  - knowledge.md: current .autoresearch/knowledge.md content
```
```

- [ ] **Step 3: Update decision logic table (section 6)**

Replace the existing table with:

```markdown
| Condition | Action |
|-----------|--------|
| Evaluator pass (or off) + guard pass + verify improved | **KEEP** — commit stands |
| Evaluator fail + severity critical/major + rework < max_rework | **REWORK** — git revert, re-dispatch Dev with critique |
| Evaluator fail + severity critical/major + rework >= max_rework | **DISCARD** — git revert, note in context.md |
| Evaluator fail + severity minor | Should not happen (minor cannot fail). Treat as **KEEP** + log warning |
| Guard fail | **DISCARD** — git revert immediately |
| Verify worse (if metric mode) | **DISCARD** — git revert |
| No changes made | **No-op** — note in context.md |
```

- [ ] **Step 4: Add "When Research MUST Be Re-dispatched" section**

After section 3 (Decide & Research) and before section 4 (Pre-Dev Gate + Dev), add:

```markdown
### 3.5 When Research MUST Be Re-dispatched

In these situations, you MUST dispatch the Research Agent — do NOT analyze logs, errors, or output yourself:

| Condition | Enforcement | Level |
|-----------|-------------|-------|
| Previous iteration outcome was DISCARD or REWORK | flow-check.sh + Pre-Dev Gate | **Hard** — script blocks exit if violated |
| verify/guard reports a new error type (different from previous iteration) | Coordinator judgment | Soft — protocol guidance |
| 2+ consecutive iterations with no KEEP | Coordinator judgment | Soft — protocol guidance |

**Why this matters:** After a failed iteration, you already have a hypothesis that turned out wrong. Analyzing the same logs yourself risks confirmation bias — you'll see what supports your existing theory. A fresh Research Agent dispatch provides independent analysis.
```

- [ ] **Step 5: Rewrite Superpowers Integration section**

Replace the existing `## Superpowers Integration (Auto-Resolve Mode)` section with:

```markdown
## Superpowers Integration (Auto-Resolve Mode)

When autoresearch is active, superpowers skills run in auto-resolve mode. But auto-resolve has a defined scope:

**Auto-resolve applies to (human preference choices):**
- brainstorming 方案選擇 — select best approach yourself
- writing-plans plan approval — review and approve plans yourself
- executing-plans 進度確認 — decide to continue yourself
- systematic-debugging 方向選擇 — choose direction yourself

**Auto-resolve does NOT apply to (quality/process gates):**
- Pre-Dev Gate BLOCK — mandatory compliance, execute the corrective action
- Post-iteration Review FAIL — must fix issues before continuing
- Evaluator fail verdict — must REWORK or DISCARD per decision logic

**Principle:** Auto-resolve skips "human preference choices." It never skips "quality/process gates."

Never wait for user approval on preference choices during the loop. Always comply with quality gate verdicts.
```

- [ ] **Step 6: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/coordinator-protocol.md
git commit -m "feat: coordinator — new dispatch inputs, mandatory re-dispatch, auto-resolve scope"
```

---

### Task 6: setup-loop.sh — Ensure `previous_outcome` initialized in state file

**Files:**
- Modify: `claude-plugin/scripts/setup-loop.sh` (state file template)

- [ ] **Step 1: Add `previous_outcome` to state file template**

In `claude-plugin/scripts/setup-loop.sh`, line 83 has `lines.append('workflow_step: 0')`. Add after it:

```python
lines.append('previous_outcome: null')
```

- [ ] **Step 2: Verify setup creates valid state file**

```bash
grep -A1 'workflow_step' /home/ubuntu/DEV/autoresearch/claude-plugin/scripts/setup-loop.sh
# Expected: 
#   lines.append('workflow_step: 0')
#   lines.append('previous_outcome: null')
```

- [ ] **Step 3: Commit**

```bash
git add claude-plugin/scripts/setup-loop.sh
git commit -m "feat: initialize previous_outcome in state file template"
```

---

### Task 7: Sync release script and final verification

**Files:**
- Modify: `scripts/release.sh` (if needed for plugin sync)

- [ ] **Step 1: Verify all modified files are consistent**

```bash
cd /home/ubuntu/DEV/autoresearch

# Check Pre-Dev Gate mentions previous_outcome
grep -c 'previous_outcome' claude-plugin/skills/autoresearch/references/pre-dev-gate-protocol.md
# Expected: >= 2

# Check Evaluator mentions severity
grep -c 'severity' claude-plugin/skills/autoresearch/references/evaluator-protocol.md
# Expected: >= 5

# Check Coordinator mentions mandatory re-dispatch
grep -c 'Research MUST' claude-plugin/skills/autoresearch/references/coordinator-protocol.md
# Expected: >= 1

# Check flow-check.sh has check ⑨
grep -c 'previous_outcome' claude-plugin/scripts/flow-check.sh
# Expected: >= 1

# Check stop-hook.sh writes previous_outcome
grep -c 'previous_outcome' claude-plugin/hooks/stop-hook.sh
# Expected: >= 2

# Check setup-loop.sh initializes previous_outcome
grep -c 'previous_outcome' claude-plugin/scripts/setup-loop.sh
# Expected: >= 1
```

- [ ] **Step 2: Run existing flow-check tests (if any)**

```bash
# Check if there's a test suite
ls claude-plugin/tests/ 2>/dev/null || echo "No test directory"
# If tests exist, run them
```

- [ ] **Step 3: Commit any remaining changes**

```bash
git status
# If any unstaged changes remain, commit them
```
