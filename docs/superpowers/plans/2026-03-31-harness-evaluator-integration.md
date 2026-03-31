# Harness Evaluator Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Generator/Evaluator separation from Anthropic's Harness Design into autoresearch — restructure the loop into outer iteration + inner implement-evaluate loop with independent Evaluator subagent.

**Architecture:** The existing linear 8-phase loop is restructured so Phase 3 becomes an inner loop (3a-3e) containing Modify, Commit, Verify, Guard, and Evaluate. Phases 4-6 become Decide, Log, Repeat. A new Evaluator subagent is spawned at Phase 3e to critically review changes that pass mechanical metrics. Rework up to 2 times on Evaluator rejection.

**Tech Stack:** Bash (hooks/scripts), Markdown (skill references), Claude Agent tool (Evaluator subagent)

**Spec:** `docs/superpowers/specs/2026-03-31-harness-evaluator-integration-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `claude-plugin/skills/autoresearch/references/core-principles.md` | Modify | Add principle #8: Separate Generation from Evaluation |
| `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md` | Rewrite | Restructure phases: inner loop 3a-3e, renumber Phase 4-6 |
| `claude-plugin/skills/autoresearch/references/results-logging.md` | Modify | Add `eval` column, new `evaluator-rejected` status |
| `claude-plugin/skills/autoresearch/SKILL.md` | Modify | Update setup fields, config summary, loop summary, critical rules |
| `claude-plugin/scripts/validate-config.sh` | Modify | Add `--evaluator` and `--max-rework` validation |
| `claude-plugin/scripts/setup-loop.sh` | Modify | Add `--evaluator`, `--evaluate`, `--max-rework` to state file |
| `claude-plugin/skills/autoresearch/references/fix-workflow.md` | Modify | Add evaluator-default: on |
| `claude-plugin/skills/autoresearch/references/debug-workflow.md` | Modify | Add evaluator-default: on |
| `claude-plugin/skills/autoresearch/references/security-workflow.md` | Modify | Add evaluator-default: off |
| `claude-plugin/skills/autoresearch/references/predict-workflow.md` | Modify | Add evaluator-default: off |
| `claude-plugin/skills/autoresearch/references/scenario-workflow.md` | Modify | Add evaluator-default: off |
| `claude-plugin/skills/autoresearch/references/learn-workflow.md` | Modify | Add evaluator-default: off |
| `claude-plugin/skills/autoresearch/references/ship-workflow.md` | Modify | Add evaluator-default: off |

---

### Task 1: Add Core Principle #8

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/core-principles.md:197-208` (after principle #7, before "The Meta-Principle")

- [ ] **Step 1: Add principle #8 before The Meta-Principle section**

Insert the following after line 208 (the end of principle #7's "Apply:" paragraph) and before `## The Meta-Principle`:

```markdown
## 8. Separate Generation from Evaluation

Agents evaluating their own output exhibit systematic self-evaluation bias. Separating generator from evaluator is more tractable than making generators self-critical.

| Generator | Evaluator |
|-----------|-----------|
| Implements changes | Critically reviews changes |
| Tends to believe own approach works | Default stance is skeptical |
| Has full implementation context | Sees only diff + goal, judges independently |

**Why:** The same agent that wrote the code has sunk cost bias. An independent Evaluator has no attachment to the implementation and is more likely to find problems.

**Apply:** After mechanical metric passes, spawn an independent Evaluator subagent to review the change. Evaluator feedback drives the rework loop.

**When to skip:** When the task already has sufficient multi-perspective mechanisms (e.g., predict's multi-persona swarm). As models improve, the threshold for Evaluator intervention can be raised — re-examine periodically.

**Source:** [Anthropic — Harness Design for Long-Running Application Development](https://www.anthropic.com/engineering/harness-design-long-running-apps) (March 2026)
```

- [ ] **Step 2: Update The Meta-Principle to reference 8 principles**

Change the existing meta-principle section — no text change needed since it's a general statement, but update the Principles Reference in SKILL.md later (Task 5).

- [ ] **Step 3: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/core-principles.md
git commit -m "docs: add core principle #8 — separate generation from evaluation"
```

---

### Task 2: Update Results Logging Protocol

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/results-logging.md`

- [ ] **Step 1: Update TSV header in Setup & Initialization section**

At line 12, change the echo command from:

```bash
echo -e "iteration\tcommit\tmetric\tdelta\tguard\tstatus\tdescription" >> autoresearch-results.tsv
```

to:

```bash
echo -e "iteration\tcommit\tmetric\tdelta\tguard\teval\tstatus\tdescription" >> autoresearch-results.tsv
```

- [ ] **Step 2: Update baseline recording**

At line 22, change:

```bash
echo -e "0\t${COMMIT}\t${BASELINE}\t0.0\tpass\tbaseline\tinitial state — coverage ${BASELINE}%" >> autoresearch-results.tsv
```

to:

```bash
echo -e "0\t${COMMIT}\t${BASELINE}\t0.0\tpass\t-\tbaseline\tinitial state — coverage ${BASELINE}%" >> autoresearch-results.tsv
```

- [ ] **Step 3: Update Logging Function**

At lines 31-35, change the function to include the eval parameter:

```bash
log_iteration() {
  local iteration=$1 commit=$2 metric=$3 delta=$4 guard=$5 eval=$6 status=$7 description=$8
  echo -e "${iteration}\t${commit}\t${metric}\t${delta}\t${guard}\t${eval}\t${status}\t${description}" \
    >> autoresearch-results.tsv
}
```

- [ ] **Step 4: Update usage examples**

Replace the usage examples (lines 37-42) with:

```bash
log_iteration 1 "b2c3d4e" "87.1" "+1.9" "pass" "pass" "keep" "add tests for auth middleware"
log_iteration 2 "-" "86.5" "-0.6" "-" "-" "discard" "refactor test helpers (broke 2 tests)"
log_iteration 3 "-" "0.0" "0.0" "-" "-" "crash" "add integration tests (DB connection failed)"
log_iteration 4 "-" "-" "-" "-" "-" "no-op" "attempted to modify read-only config"
log_iteration 5 "-" "-" "-" "-" "-" "hook-blocked" "pre-commit lint rejected formatting"
log_iteration 6 "c3d4e5f" "88.3" "+1.2" "pass" "fail" "evaluator-rejected" "switch to greedy algorithm"
log_iteration 7 "d4e5f6g" "89.0" "+0.7" "pass" "pass(1)" "keep" "optimize connection pool (1 rework)"
```

- [ ] **Step 5: Update Columns table**

Replace the Columns table (lines 106-114) with:

```markdown
| Column | Type | Description |
|--------|------|-------------|
| iteration | int | Sequential counter starting at 0 (baseline) |
| commit | string | Short git hash (7 chars), "-" if reverted |
| metric | float | Measured value from verification |
| delta | float | Change from previous best (negative = improved for "lower is better") |
| guard | enum | `pass`, `fail`, or `-` (no guard configured) |
| eval | enum | `pass`, `fail`, `pass(N)` (passed after N reworks), `-` (not reached), `off` (Evaluator disabled) |
| status | enum | `baseline`, `keep`, `keep (reworked)`, `discard`, `crash`, `no-op`, `hook-blocked`, `evaluator-rejected` |
| description | string | One-sentence description of what was tried |
```

- [ ] **Step 6: Update Example TSV**

Replace the example TSV (lines 119-127) with:

```tsv
iteration	commit	metric	delta	guard	eval	status	description
0	a1b2c3d	85.2	0.0	pass	-	baseline	initial state — test coverage 85.2%
1	b2c3d4e	87.1	+1.9	pass	pass	keep	add tests for auth middleware edge cases
2	-	86.5	-0.6	-	-	discard	refactor test helpers (broke 2 tests)
3	-	0.0	0.0	-	-	crash	add integration tests (DB connection failed)
4	-	88.9	+1.8	fail	-	discard	inline hot-path functions (guard: 3 tests broke)
5	c3d4e5f	88.3	+1.2	pass	pass	keep	add tests for error handling in API routes
6	d4e5f6g	89.5	+1.2	pass	fail	evaluator-rejected	switch to greedy algorithm (evaluator: edge case not handled)
7	e5f6g7h	89.0	+0.7	pass	pass(1)	keep	optimize connection pool (1 rework)
```

- [ ] **Step 7: Update Integration section**

At line 73, update the phase mapping comment:

```
Phase 0 (Setup):         → CREATE log file, record baseline (iteration 0)
Phase 1 (Review):        → READ last 10-20 log entries for pattern recognition
Phase 3 (Implement):     → Inner loop: Modify, Commit, Verify, Guard, Evaluate
Phase 4 (Decide):        → Keep/Discard/Evaluator-rejected decision
Phase 5 (Log):           → APPEND new row after decision
Phase 6 (Repeat):        → Back to Phase 1 (reads updated log)
```

- [ ] **Step 8: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/results-logging.md
git commit -m "docs: add eval column and evaluator-rejected status to results logging"
```

---

### Task 3: Rewrite Autonomous Loop Protocol

This is the core change. The file `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md` needs to be restructured from a linear 8-phase loop to an outer iteration loop + inner implement-evaluate loop.

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md`

- [ ] **Step 1: Update Loop Modes section**

At lines 1-12, replace with:

```markdown
# Autonomous Loop Protocol

Detailed protocol for the autoresearch iteration loop. SKILL.md has the summary; this file has the full rules.

## Loop Structure

The loop has two layers:

- **Outer loop (iteration):** Phase 0 → 1 → 2 → 3 → 4 → 5 → 6 → repeat
- **Inner loop (implement-evaluate):** Phase 3a → 3b → 3c → 3d → 3e → keep or rework

```
Phase 0: Precondition (once, before loop starts)
Phase 1: Review
Phase 2: Ideate

Phase 3: Implement (inner loop, max attempts: 1 initial + Max-Rework reworks)
  +-- 3a: Modify
  +-- 3b: Commit
  +-- 3c: Verify (mechanical metric — hard gate)
  +-- 3d: Guard (safety net — hard gate)
  +-- 3e: Evaluate (Evaluator subagent — quality gate)
       -> pass: exit inner loop with "keep"
       -> fail + rework remaining: revert, inject critique, go to 3a
       -> fail + no rework left: revert, exit with "evaluator-rejected"

Phase 4: Decide
Phase 5: Log
Phase 6: Repeat
```

## Loop Modes

Autoresearch supports two loop modes:

- **Unbounded (default):** Loop forever until manually interrupted (`Ctrl+C`)
- **Bounded:** Loop exactly N times when `Iterations: N` is set in the inline config (or `--iterations N` flag for CLI/CI)

In both modes, the **stop hook** is the mechanical enforcement layer. In bounded mode, the hook tracks the iteration counter and allows exit after N iterations. You do NOT need to track iterations yourself — complete each iteration (Phase 1→5), then stop. The hook decides whether to re-inject.
```

- [ ] **Step 2: Keep Phase 0 and Phase 1 unchanged**

Phase 0 (Precondition Checks) and Phase 1 (Review) remain exactly as they are now. No edits needed.

- [ ] **Step 3: Update Phase 2 Ideate — add evaluator-rejected awareness**

At the end of the existing Phase 2 section (after the "Bounded mode consideration" paragraph around line 253), add:

```markdown
**Evaluator-rejected awareness:** If the results log shows the previous iteration was `evaluator-rejected`, read the Evaluator's critique from the log description. Use it to inform this iteration's approach — avoid the same problem. The Evaluator flagged a specific code-level issue; your next idea should address or avoid it.
```

- [ ] **Step 4: Replace Phase 3 (Modify) through Phase 5.5 (Guard) with new Phase 3 (Implement)**

Replace the existing Phase 3 (Modify), Phase 4 (Commit), Phase 5 (Verify), Phase 5.1 (Noise Handling), Phase 5.5 (Guard) sections with a new unified Phase 3: Implement section. The old content is preserved inside sub-phases 3a-3d, with Phase 3e being entirely new.

```markdown
## Phase 3: Implement (Inner Loop)

Phase 3 is an inner loop that wraps modification, verification, and evaluation into a single implement-evaluate cycle. The inner loop runs up to `1 + Max-Rework` times (default: 3 = 1 initial + 2 reworks).

### Inner Loop Flow

```
attempt = 0
max_rework = config.max_rework  # default: 2
evaluator_critique = null

LOOP:
  3a: Modify
  3b: Commit
  3c: Verify → fail? → revert → EXIT "discard"
  3d: Guard  → fail? → Guard rework (max 2, independent) or EXIT "discard"
  3e: Evaluate
      → Evaluator off?  → EXIT "keep"
      → pass?           → EXIT "keep" (with risk_flags if any)
      → fail + attempt < max_rework?
          → revert, store critique, attempt++, GOTO LOOP
      → fail + attempt >= max_rework?
          → revert → EXIT "evaluator-rejected"

EXIT → Phase 4: Decide
```

### Short-Circuit Rules

- **3c (Verify) fails** → revert, skip Guard and Evaluate, exit with "discard"
- **3d (Guard) fails** → existing Guard rework logic (max 2 attempts, independent count), never reaches Evaluate
- **3e (Evaluate) fails** → rework loop (max_rework attempts, default 2)
- **`Evaluator: off`** → 3e is skipped entirely, 3d pass goes straight to exit with "keep". Behavior identical to pre-Evaluator autoresearch.

### Phase 3a: Modify (One Atomic Change)
```

Then copy the existing Phase 3 (Modify) content — including the one-sentence test, multi-file atomic changes, atomicity enforcement, and all examples — but change the heading from `## Phase 3: Modify` to `### Phase 3a: Modify`. Add this paragraph at the top of the section:

```markdown
On the first attempt (attempt=0), use the plan from Phase 2 (Ideate). On rework attempts (attempt>0), use the Evaluator's critique and suggestions to modify the approach while preserving the original intent.
```

Then similarly:

```markdown
### Phase 3b: Commit (Before Verification)
```

Copy the existing Phase 4 (Commit) content, changing the heading. Keep all content unchanged.

```markdown
### Phase 3c: Verify (Mechanical Only)
```

Copy the existing Phase 5 (Verify) + Phase 5.1 (Noise Handling) content, changing the heading. Keep all content unchanged.

```markdown
### Phase 3d: Guard (Regression Check)
```

Copy the existing Phase 5.5 (Guard) content, changing the heading. Keep all content unchanged. Add at the end:

```markdown
**Interaction with Evaluator:** Guard rework and Evaluator rework have independent attempt counters. Guard rework (max 2) happens entirely within Phase 3d. If Guard passes after rework, proceed to Phase 3e (Evaluate). If Guard cannot pass after 2 rework attempts, exit inner loop with "discard" — Evaluator is never reached.
```

- [ ] **Step 5: Add Phase 3e: Evaluate (NEW)**

After Phase 3d, add the entirely new Phase 3e:

```markdown
### Phase 3e: Evaluate (Independent Review)

If `Evaluator: off` is set in the config, skip this phase entirely — exit inner loop with "keep".

Otherwise, spawn an independent Evaluator subagent using the Agent tool. The Evaluator has NO access to your context window — it only sees the structured input you provide. This separation is deliberate: it prevents self-evaluation bias.

**Spawn the Evaluator subagent with this prompt:**

```
# Role
You are an independent Evaluator. Your job is to critically review a code change.
You are completely separate from the agent that produced this code — you did not
participate in design or implementation. Your only goal is to find problems.

# Context
Goal: {goal}
Scope: {scope}
Iteration Intent: {ideate_description}
Mechanical Metric: {metric_name} = {metric_value} (passed threshold)

{if Evaluate field provided in config}
## Priority Review Targets
{evaluate_field}
{/if}

{if this is a rework attempt}
## Previous Review Feedback
{previous_critique}
Verify whether this revision addresses the above issues.
{/if}

# Git Diff
\```diff
{output of: git diff HEAD~1}
\```

# Rules
1. You MUST point to specific code lines in the diff. No vague critiques.
2. The mechanical metric already passed — do not question the metric itself.
   Focus on what the metric CANNOT cover.
3. Default stance is skeptical, but do not reject for the sake of rejecting.
4. If the change is simple and correct, pass it. Do not manufacture problems.

# Review Dimensions
1. Logical correctness — does the change implement the stated intent?
2. Edge cases — are there unhandled boundary conditions?
3. Metric authenticity — is the change gaming the metric without real improvement?
4. Side effects — unintended impact outside scope?
5. Simplicity — overly complex? simpler way to achieve the same?

# Output Format (strict JSON, nothing else)
{
  "verdict": "pass" or "fail",
  "critique": "specific issue description referencing code lines (required when fail, empty string when pass)",
  "suggestions": ["actionable fix suggestion 1", "..."],
  "risk_flags": ["potential concern even if passing", "..."]
}
```

**Processing the Evaluator's response:**

1. Parse the JSON output. If parsing fails, treat as "pass" (don't block on Evaluator errors).
2. If `verdict == "pass"`:
   - Store `risk_flags` (if any) for Phase 5 (Log).
   - Exit inner loop with status "keep".
3. If `verdict == "fail"` and `attempt < max_rework`:
   - Run `safe_revert()` to undo the current commit.
   - Store `critique` and `suggestions` for the next Phase 3a.
   - Increment `attempt`.
   - Go back to Phase 3a with the Evaluator's feedback as input.
4. If `verdict == "fail"` and `attempt >= max_rework`:
   - Run `safe_revert()` to undo the current commit.
   - Exit inner loop with status "evaluator-rejected".
   - Store the final `critique` for Phase 5 (Log).

**Rework guidance for Phase 3a:**

When re-entering Phase 3a after an Evaluator rejection, the agent should:
- Address the specific critique (not rewrite from scratch)
- Preserve the original intent from Phase 2 (Ideate)
- The one-sentence description should include "(rework)" suffix
- Commit message: `experiment(<scope>): rework — <original description> — address: <critique summary>`

**Cost awareness:** Each Evaluator spawn costs tokens and adds latency. For simple, low-risk changes (e.g., single-line config tweaks), the Evaluator will typically pass immediately. The cost is justified for complex logic changes where self-evaluation bias is most likely.
```

- [ ] **Step 6: Replace Phase 6 (Decide) with new Phase 4 (Decide)**

Replace the existing Phase 6 section with:

```markdown
## Phase 4: Decide

The inner loop (Phase 3) exits with one of these statuses: "keep", "discard", "crash", "no-op", "hook-blocked", or "evaluator-rejected". Phase 4 finalizes the decision.

```
IF exit_status == "keep":
    STATUS = "keep"
    # Commit stays. Git history preserves this success.
    # If Evaluator returned risk_flags, store them for logging.

IF exit_status == "keep" AND evaluator rework happened:
    STATUS = "keep (reworked)"
    # The final version passed both metric and Evaluator.

IF exit_status == "discard":
    STATUS = "discard"
    # Already reverted in Phase 3c or 3d.

IF exit_status == "evaluator-rejected":
    STATUS = "evaluator-rejected"
    # Already reverted in Phase 3e.
    # Store Evaluator's final critique — Phase 2 should avoid this pattern next iteration.

IF exit_status == "crash":
    STATUS = "crash"
    # Already handled crash recovery in Phase 3c.

IF exit_status == "no-op":
    STATUS = "no-op"
    # Phase 3a produced no diff.

IF exit_status == "hook-blocked":
    STATUS = "hook-blocked"
    # Pre-commit hook rejected the change.
```

**Simplicity override** (unchanged): If metric barely improved (+<0.1%) but change adds significant complexity, treat as "discard". If metric unchanged but code is simpler, treat as "keep".
```

- [ ] **Step 7: Replace Phase 7 (Log) with Phase 5 (Log)**

Replace the existing Phase 7 section with:

```markdown
## Phase 5: Log Results

Append to results log (TSV format). See `references/results-logging.md` for full protocol.

```
iteration  commit   metric  delta  guard  eval     status               description
42         a1b2c3d  0.9821  +0.01  pass   pass     keep                  increase attention heads
43         -        0.9845  +0.02  pass   fail     evaluator-rejected    switch optimizer (evaluator: no error handling)
44         -        0.0000  0.0    -      -        crash                 double batch size (OOM)
45         -        -       -      -      -        no-op                 no diff produced
46         -        -       -      -      -        hook-blocked          pre-commit lint hook rejected
47         b2c3d4e  0.9830  +0.01  pass   pass(1)  keep (reworked)       add caching layer (1 rework)
48         -        0.9835  +0.01  pass   off      keep                  tweak learning rate (evaluator off)
```

**eval column values:** `pass`, `fail`, `pass(N)` (passed after N reworks), `-` (not reached — Verify/Guard failed first), `off` (Evaluator disabled)

**Valid statuses:** `keep`, `keep (reworked)`, `discard`, `crash`, `no-op`, `hook-blocked`, `evaluator-rejected`

**Logging risk_flags:** If the Evaluator returned risk_flags on a "pass" verdict, append them to the description. Example: `"add caching layer [risk: cache invalidation not tested]"`
```

- [ ] **Step 8: Replace Phase 8 (Repeat) with Phase 6 (Repeat)**

Replace the existing Phase 8 section. The content stays largely the same, just renumber references:

```markdown
## Phase 6: Repeat

### Unbounded Mode (default)

Go to Phase 1. **NEVER STOP. NEVER ASK IF YOU SHOULD CONTINUE.**

### Bounded Mode (with Iterations: N)

**The stop hook controls bounded iteration counting.** You do NOT track iterations internally.

After completing Phase 5 (Log), stop. The hook will either:
- **Re-inject the prompt** (iterations remaining) — you start the next iteration from Phase 1
- **Allow exit** (N iterations reached) — the session ends

The system message from the hook shows your current iteration: `🔬 Autoresearch iteration X/N`. When you see the final iteration (`N/N`), print a summary after completing it.

**Final summary format (print on last iteration):**
```
=== Autoresearch Complete ===
Baseline: {baseline} → Final: {current} ({delta})
Keeps: X | Discards: Y | Crashes: Z | Eval-Rejected: R | Skipped: W (no-ops + hook-blocked)
Best iteration: #{n} — {description}
```

**How to know it's the last iteration:** The system message shows `iteration N/N`. Complete the iteration normally, print the summary, then stop.

### When Stuck (>5 consecutive discards or evaluator-rejected)

Applies to both modes:
1. Re-read ALL in-scope files from scratch
2. Re-read the original goal/direction
3. Review entire results log for patterns
4. If evaluator-rejected: re-read ALL evaluator critiques — find the common pattern
5. Try combining 2-3 previously successful changes
6. Try the OPPOSITE of what hasn't been working
7. Try a radical architectural change
```

- [ ] **Step 9: Update Crash Recovery and Communication sections**

Update phase references in the Crash Recovery section (change "Phase 7" references to "Phase 5", etc.). Update Communication section — add to the final summary format line about evaluator-rejected count.

- [ ] **Step 10: Verify the rewritten file is internally consistent**

Read through the entire rewritten file. Check that:
- All phase references use the new numbering (Phase 3a-3e, Phase 4, 5, 6)
- No dangling references to old Phase 4, 5, 5.5, 6, 7, 8
- The safe_revert() function is still defined (keep it in Phase 3b or Phase 4)
- Git as Memory section still works with new phase numbers

- [ ] **Step 11: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md
git commit -m "refactor: restructure loop protocol — inner implement-evaluate loop with Phase 3a-3e"
```

---

### Task 4: Update validate-config.sh

**Files:**
- Modify: `claude-plugin/scripts/validate-config.sh`

- [ ] **Step 1: Add --evaluator and --max-rework to argument parsing**

At line 25, change:

```bash
GOAL="" SCOPE="" METRIC="" DIRECTION="" VERIFY="" GUARD=""
```

to:

```bash
GOAL="" SCOPE="" METRIC="" DIRECTION="" VERIFY="" GUARD="" EVALUATOR="on" MAX_REWORK="2"
```

At lines 28-37, add new cases inside the while loop:

```bash
    --evaluator)  EVALUATOR="$2";  shift 2 ;;
    --max-rework) MAX_REWORK="$2"; shift 2 ;;
```

- [ ] **Step 2: Add validation checks after Check 6**

After the guard validation block (after line 157), add:

```bash
# ─── Check 7: Evaluator value ───────────────────────────────────
echo "Checking evaluator setting..."
if [[ "$EVALUATOR" != "on" ]] && [[ "$EVALUATOR" != "off" ]]; then
  fail "Evaluator must be 'on' or 'off', got: '$EVALUATOR'"
  echo "VALIDATION FAILED." >&2
  exit 1
fi
echo "  Evaluator: $EVALUATOR"

# ─── Check 8: Max-Rework value ──────────────────────────────────
echo "Checking max-rework setting..."
if ! [[ "$MAX_REWORK" =~ ^[0-9]+$ ]]; then
  fail "Max-Rework must be a non-negative integer, got: '$MAX_REWORK'"
  echo "VALIDATION FAILED." >&2
  exit 1
fi
echo "  Max-Rework: $MAX_REWORK"
```

- [ ] **Step 3: Update usage text**

At lines 7-8, update the usage line:

```bash
Usage: validate-config.sh --goal GOAL --scope SCOPE --metric METRIC --direction DIR --verify CMD [--guard CMD] [--evaluator on|off] [--max-rework N]
```

Add to the Checks list:

```
  7. Evaluator is "on" or "off"
  8. Max-Rework is a non-negative integer
```

- [ ] **Step 4: Commit**

```bash
git add claude-plugin/scripts/validate-config.sh
git commit -m "feat: add evaluator and max-rework validation to validate-config.sh"
```

---

### Task 5: Update setup-loop.sh

**Files:**
- Modify: `claude-plugin/scripts/setup-loop.sh`

- [ ] **Step 1: Add new arguments to parsing**

At line 26, change:

```bash
GOAL="" SCOPE="" METRIC="" DIRECTION="" VERIFY="" GUARD="" MAX_ITERATIONS=0 PROMPT=""
```

to:

```bash
GOAL="" SCOPE="" METRIC="" DIRECTION="" VERIFY="" GUARD="" MAX_ITERATIONS=0 PROMPT="" EVALUATOR="on" EVALUATE="" MAX_REWORK="2"
```

At lines 28-40, add new cases inside the while loop:

```bash
    --evaluator)      EVALUATOR="$2";      shift 2 ;;
    --evaluate)       EVALUATE="$2";       shift 2 ;;
    --max-rework)     MAX_REWORK="$2";     shift 2 ;;
```

- [ ] **Step 2: Add new fields to state file**

At lines 93-109, update the cat heredoc to include new fields. After the `guard:` line (line 104), add:

```bash
evaluator: ${EVALUATOR}
evaluate: $(yaml_escape "$EVALUATE")
max_rework: ${MAX_REWORK}
```

- [ ] **Step 3: Add Evaluator fields to default prompt**

At lines 62-76, update the default prompt generation. After the Guard line, add:

```bash
  PROMPT="${PROMPT}
Evaluator: ${EVALUATOR}"
  if [[ -n "$EVALUATE" ]]; then
    PROMPT="${PROMPT}
Evaluate: ${EVALUATE}"
  fi
  PROMPT="${PROMPT}
Max-Rework: ${MAX_REWORK}"
```

- [ ] **Step 4: Add to output display**

At lines 112-133, after the Guard echo block, add:

```bash
  echo "   Evaluator:      ${EVALUATOR}"
  if [[ -n "$EVALUATE" ]]; then
    echo "   Evaluate:       ${EVALUATE}"
  fi
  echo "   Max-Rework:     ${MAX_REWORK}"
```

- [ ] **Step 5: Update usage text**

Add to the Options section:

```
  --evaluator       "on" or "off" (default: on)
  --evaluate        Review focus areas for evaluator (optional)
  --max-rework      Max rework attempts on evaluator rejection (default: 2)
```

- [ ] **Step 6: Commit**

```bash
git add claude-plugin/scripts/setup-loop.sh
git commit -m "feat: add evaluator, evaluate, max-rework fields to setup-loop.sh"
```

---

### Task 6: Update SKILL.md

**Files:**
- Modify: `claude-plugin/skills/autoresearch/SKILL.md`

- [ ] **Step 1: Update Interactive Setup table**

At lines 510-520, add new rows to the setup question table:

```markdown
| 8 | Evaluator (optional) | "Evaluator is enabled by default. Set to 'off' to disable?" | "on" (default) / "off" |
| 9 | Evaluate (optional) | "Evaluator is enabled. Want to specify review focus areas? (Press Enter to skip — will auto-derive from Goal + Scope)" | Auto-derived / user text |
| 10 | Max-Rework (optional) | "Max rework attempts when Evaluator rejects? (default: 2)" | "2" |
```

- [ ] **Step 2: Update Configuration Summary**

At lines 529-539, replace the Configuration Summary block:

```
Configuration Summary:
  Goal:        <value>
  Scope:       <value>
  Metric:      <value>
  Direction:   <value>
  Verify:      <value>
  Guard:       <value or "none">
  Evaluator:   <on or off>
  Evaluate:    <value or "(auto-derived)">
  Max-Rework:  <value or "2">
  Iterations:  <value or "unlimited">

Ready to launch? [Launch / Edit / Cancel]
```

- [ ] **Step 3: Update Mechanical Validation list**

At lines 549-555, add items 7-8:

```markdown
7. Evaluator is exactly "on" or "off"
8. Max-Rework is a non-negative integer
```

- [ ] **Step 4: Update The Loop summary**

At lines 571-591, replace the loop summary with the new phase structure:

```
LOOP (FOREVER or N times):
  1. Review: Read current state + git history + results log
  2. Ideate: Pick next change based on goal, past results, evaluator feedback
  3. Implement (inner loop):
     3a. Modify: Make ONE focused change to in-scope files
     3b. Commit: Git commit the change (before verification)
     3c. Verify: Run the mechanical metric — fail → revert, exit with "discard"
     3d. Guard: If guard is set, run the guard — fail → Guard rework or exit with "discard"
     3e. Evaluate: If Evaluator on, spawn Evaluator subagent
         - pass → exit with "keep"
         - fail + rework remaining → revert, feed critique back, go to 3a
         - fail + max rework reached → revert, exit with "evaluator-rejected"
  4. Decide: Finalize keep/discard/evaluator-rejected/crash/no-op
  5. Log: Record result in results log (with eval column)
  6. Repeat: Go to step 1.
     - If unbounded: NEVER STOP. NEVER ASK "should I continue?"
     - If bounded (N): Stop after N iterations, print final summary
```

- [ ] **Step 5: Update Critical Rules**

At lines 629-633, update rule #4 and add rule #9:

```markdown
4. **Mechanical verification + independent evaluation** — Metrics are the hard gate. Evaluator subagent challenges what metrics can't catch.
```

Add after rule #8:

```markdown
9. **Separate generation from evaluation** — You write the code, a separate Evaluator subagent reviews it. Don't evaluate your own work — self-evaluation bias is real. See core principles #8.
```

- [ ] **Step 6: Update Principles Reference**

At line 635, change:

```markdown
See `references/core-principles.md` for the 8 generalizable principles from autoresearch.
```

- [ ] **Step 7: Commit**

```bash
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "feat: add evaluator config to SKILL.md — setup, loop summary, critical rules"
```

---

### Task 7: Add evaluator-default to Workflow References

**Files:**
- Modify: 7 workflow reference files

- [ ] **Step 1: Add evaluator-default: on to fix-workflow.md**

After line 5 (`**Core idea:**...`), add:

```markdown
**Evaluator default:** `on` — catches lazy fixes (suppressions, any types, deleted tests).
```

- [ ] **Step 2: Add evaluator-default: on to debug-workflow.md**

After line 5 (`**Core idea:**...`), add:

```markdown
**Evaluator default:** `on` — challenges hypothesis experiment design and evidence quality.
```

- [ ] **Step 3: Add evaluator-default: off to security-workflow.md**

After line 4 (`**Output:**...`), add:

```markdown
**Evaluator default:** `off` — this workflow already uses 4 adversarial personas for multi-perspective analysis.
```

- [ ] **Step 4: Add evaluator-default: off to predict-workflow.md**

After line 5 (`**Core idea:**...`), add:

```markdown
**Evaluator default:** `off` — this workflow already uses multi-persona swarm with debate and anti-herd detection.
```

- [ ] **Step 5: Add evaluator-default: off to scenario-workflow.md**

After line 5 (`**Core idea:**...`), add:

```markdown
**Evaluator default:** `off` — outputs scenarios, not code changes. No Verify/Guard flow to supplement.
```

- [ ] **Step 6: Add evaluator-default: off to learn-workflow.md**

After line 5 (`**Core idea:**...`), add:

```markdown
**Evaluator default:** `off` — outputs documentation with its own validation-fix loop.
```

- [ ] **Step 7: Add evaluator-default: off to ship-workflow.md**

After line 5 (`**Core idea:**...`), add:

```markdown
**Evaluator default:** `off` — uses checklist workflow, not iteration loop.
```

- [ ] **Step 8: Commit**

```bash
git add claude-plugin/skills/autoresearch/references/fix-workflow.md \
        claude-plugin/skills/autoresearch/references/debug-workflow.md \
        claude-plugin/skills/autoresearch/references/security-workflow.md \
        claude-plugin/skills/autoresearch/references/predict-workflow.md \
        claude-plugin/skills/autoresearch/references/scenario-workflow.md \
        claude-plugin/skills/autoresearch/references/learn-workflow.md \
        claude-plugin/skills/autoresearch/references/ship-workflow.md
git commit -m "docs: add evaluator-default to all workflow reference files"
```

---

### Task 8: Update SKILL.md version and final consistency check

**Files:**
- Modify: `claude-plugin/skills/autoresearch/SKILL.md:2`

- [ ] **Step 1: Bump version**

At line 3, change:

```yaml
version: 1.9.0
```

to:

```yaml
version: 2.0.0
```

This is a major version bump because the loop structure changed (phases renumbered, inner loop added).

- [ ] **Step 2: Cross-file consistency check**

Verify these match across all modified files:

1. Phase numbers: autonomous-loop-protocol.md uses 0,1,2,3(3a-3e),4,5,6 — check SKILL.md matches
2. Status values: results-logging.md lists `evaluator-rejected` — check autonomous-loop-protocol.md and SKILL.md also reference it
3. Config fields: setup-loop.sh accepts `--evaluator`, `--evaluate`, `--max-rework` — check validate-config.sh accepts the same names
4. Eval column: results-logging.md defines `eval` column values — check autonomous-loop-protocol.md log examples match
5. Evaluator prompt: autonomous-loop-protocol.md has the full prompt template — check it includes all 5 review dimensions from spec

- [ ] **Step 3: Commit**

```bash
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "chore: bump version to 2.0.0 — harness evaluator integration"
```
