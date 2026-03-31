# Harness Evaluator Integration Design

**Date:** 2026-03-31
**Origin:** [Anthropic — Harness Design for Long-Running Application Development](https://www.anthropic.com/engineering/harness-design-long-running-apps)
**Scope:** autoresearch loop protocol + core principles

## Summary

Integrate the Generator/Evaluator separation pattern from Anthropic's Harness Design into autoresearch. An independent Evaluator subagent challenges implementation quality after mechanical metrics pass, driving a rework loop before the Decide phase.

## Problem

Autoresearch relies on a single mechanical metric (a number) to decide keep/discard. This works well for tasks with clear metrics (coverage %, bundle size), but has blind spots:

1. **Self-evaluation bias** — the same agent that wrote the code evaluates it. It tends to believe its own approach is correct.
2. **Metric gaming** — changes can improve the number without genuinely improving the system (e.g., gaming benchmark conditions).
3. **Qualitative gaps** — edge cases, race conditions, logical flaws — things a number can't catch.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Evaluator role | Optional enhancement layer | Mechanical metric remains hard gate; Evaluator adds depth |
| Implementation | Subagent (Agent tool spawn) | True independence — separate context window, no self-evaluation bias |
| Failure handling | Rework max 2 times, then discard | Consistent with existing Guard rework pattern |
| Review scope | Auto-derive from config + optional `Evaluate` field | Zero config burden by default, power users can customize |
| Default state | On (user can set `Evaluator: off`) | Push better practices; easy opt-out |

## New Loop Structure

The existing 8-phase linear loop is restructured into an **outer iteration loop + inner implement-evaluate loop**.

### Before (current)

```
Phase 0: Precondition
Phase 1: Review
Phase 2: Ideate
Phase 3: Modify
Phase 4: Commit
Phase 5: Verify
Phase 5.5: Guard
Phase 6: Decide
Phase 7: Log
Phase 8: Repeat
```

### After (new)

```
Phase 0: Precondition (unchanged)
Phase 1: Review (unchanged)
Phase 2: Ideate (unchanged)

Phase 3: Implement (inner loop, max 3 attempts: initial + 2 rework)
  +-- 3a: Modify (was Phase 3)
  +-- 3b: Commit (was Phase 4)
  +-- 3c: Verify (was Phase 5 -- mechanical metric, hard gate)
  +-- 3d: Guard (was Phase 5.5)
  +-- 3e: Evaluate (NEW -- spawn Evaluator subagent)
       -> pass: exit inner loop with "keep"
       -> fail + rework remaining: revert, inject critique, go to 3a
       -> fail + no rework left: revert, exit with "evaluator-rejected"

Phase 4: Decide (was Phase 6)
Phase 5: Log (was Phase 7)
Phase 6: Repeat (was Phase 8)
```

### Inner Loop Short-Circuit Rules

- **3c (Verify) fails** -> revert, skip Guard and Evaluate, exit with "discard"
- **3d (Guard) fails** -> existing Guard rework logic (max 2 attempts, independent count), never reaches Evaluate
- **3e (Evaluate) fails** -> rework loop (max 2 attempts)
- **`Evaluator: off`** -> 3e is skipped entirely, 3d pass goes straight to Decide. Behavior identical to current autoresearch.

### Inner Loop Pseudocode

```
attempt = 0
max_rework = config.max_rework  # default: 2

LOOP:
  3a: Modify
      if attempt == 0: use Ideate plan
      if attempt > 0:  use Evaluator critique + suggestions
  
  3b: Commit
      git add <in-scope files>
      git commit -m "experiment(<scope>): <description>"
  
  3c: Verify
      metric = run(config.verify)
      IF metric not improved:
          revert -> EXIT "discard"
  
  3d: Guard
      IF config.guard defined:
          result = run(config.guard)
          IF failed:
              Guard rework (max 2, independent) or EXIT "discard"
  
  3e: Evaluate
      IF config.evaluator == "off":
          EXIT "keep"
      
      spawn Evaluator subagent with:
          goal, scope, evaluate, git_diff, metric_value,
          ideate_description, previous_critique (if rework)
      
      IF verdict == "pass":
          EXIT "keep" (with risk_flags if any)
      ELIF attempt < max_rework:
          revert
          attempt += 1
          store critique + suggestions for next 3a
          GOTO LOOP
      ELSE:
          revert -> EXIT "evaluator-rejected"

EXIT -> Phase 4: Decide
```

## Evaluator Subagent Specification

### Input

| Field | Source | Required |
|-------|--------|----------|
| `goal` | Config | Always |
| `scope` | Config | Always |
| `evaluate` | Config (optional field) | Only if user provided |
| `git_diff` | `git diff HEAD~1` | Always |
| `metric_value` | Phase 3c output | Always |
| `ideate_description` | Phase 2 output | Always |
| `previous_critique` | Previous 3e output | Only on rework |

### Output (strict JSON)

```json
{
  "verdict": "pass | fail",
  "critique": "string (required when fail)",
  "suggestions": ["string", "..."] ,
  "risk_flags": ["string", "..."]
}
```

### Review Dimensions (auto-derived)

1. **Logical correctness** — does the change actually implement the stated intent?
2. **Edge cases** — are there unhandled boundary conditions?
3. **Metric authenticity** — is the change gaming the metric without real improvement?
4. **Side effects** — does it cause unintended impact outside the scope?
5. **Simplicity** — is it overly complex? Is there a simpler way?

When `Evaluate` field is provided, those items become priority review targets on top of the 5 default dimensions.

### Prompt Template

```markdown
# Role
You are an independent Evaluator. Your job is to critically review a code change.
You are completely separate from the agent that produced this code — you did not
participate in design or implementation. Your only goal is to find problems.

# Context
Goal: {goal}
Scope: {scope}
Iteration Intent: {ideate_description}
Mechanical Metric: {metric_name} = {metric_value} (passed threshold)

{if evaluate field provided}
## Priority Review Targets
{evaluate_field}
{/if}

{if rework}
## Previous Review Feedback
{previous_critique}
Verify whether this revision addresses the above issues.
{/if}

# Git Diff
\`\`\`diff
{git_diff}
\`\`\`

# Rules
1. You MUST point to specific code lines in the diff. No vague critiques.
2. The mechanical metric already passed — do not question the metric itself.
   Focus on what the metric CANNOT cover.
3. Default stance is skeptical, but do not reject for the sake of rejecting.
4. If the change is simple and correct, pass it. Do not manufacture problems.

# Output Format (strict JSON)
{
  "verdict": "pass" or "fail",
  "critique": "...",
  "suggestions": ["...", "..."],
  "risk_flags": ["...", "..."]
}
```

### Prompt Design Principles

- **Skeptical but not adversarial:** Anthropic's article warns that Evaluator prompt tuning is critical to avoid false positives. The prompt explicitly says "do not reject for the sake of rejecting."
- **Specificity requirement:** Every critique must reference code lines from the diff. Prevents unactionable feedback like "might have race condition."
- **Rework focus:** On rework, previous critique is injected so Evaluator focuses on "was the issue fixed?" rather than finding new issues.

## Decide Phase (Phase 4) Changes

### New Decision Matrix

```
IF exit_status == "keep":
    STATUS = "keep"

IF exit_status == "keep" AND risk_flags is not empty:
    STATUS = "keep"
    risk_flags written to Log (for Phase 1 Review in next iteration)

IF exit_status == "discard":
    STATUS = "discard" (unchanged from current)

IF exit_status == "evaluator-rejected":
    STATUS = "evaluator-rejected" (new status)
    Last Evaluator critique written to Log
    Next Phase 2 Ideate should avoid the same issues
```

### Valid Statuses (updated)

`keep`, `keep (reworked)`, `discard`, `crash`, `no-op`, `hook-blocked`, `evaluator-rejected`

### Log Format (updated)

```
iteration  commit   metric  eval     status               description
1          a1b2c3d  92.1    pass     keep                  add response caching
2          b2c3d4e  93.5    fail     evaluator-rejected    switch to greedy algorithm
3          -        88.0    -        discard               reduce batch size (verify failed)
4          c3d4e5f  94.2    pass     keep                  add retry with backoff
5          d4e5f6g  93.8    pass(1)  keep                  optimize connection pool (1 rework)
```

New `eval` column values: `pass`, `fail`, `pass(N)` (passed after N reworks), `-` (not reached), `off` (Evaluator disabled)

## Configuration

### New Inline Config Fields

| Field | Default | Values | Description |
|-------|---------|--------|-------------|
| `Evaluator` | `on` | `on` / `off` | Enable or disable Evaluator subagent |
| `Evaluate` | (auto-derived) | free text | Optional user-defined review focus areas |
| `Max-Rework` | `2` | integer | Maximum rework attempts when Evaluator fails |

### Setup Phase Changes

After existing Batch 2 (Verify, Guard, Iterations), add optional prompt:

> "Evaluator is enabled. Want to specify review focus areas? (Press Enter to skip — will auto-derive from Goal + Scope)"

### Configuration Summary (updated)

```
Configuration Summary:
  Goal:        ...
  Scope:       ...
  Metric:      ...
  Direction:   ...
  Verify:      ...
  Guard:       ...
  Evaluator:   on
  Evaluate:    (auto-derived) or user-specified text
  Max-Rework:  2
  Iterations:  ...

Ready to launch? [Launch / Edit / Cancel]
```

### Validation (validate-config.sh updates)

- `Evaluator`: must be exactly `on` or `off`
- `Max-Rework`: must be integer >= 0
- `Evaluate`: no validation (free text, optional)

## Sub-command Evaluator Defaults

Each sub-command can declare its own default via `evaluator-default` in its workflow reference file. User can always override with explicit `Evaluator: on/off`.

| Sub-command | evaluator-default | Rationale |
|-------------|-------------------|-----------|
| `/autoresearch` (main) | `on` | Core use case |
| `/autoresearch:fix` | `on` | Catch lazy fixes (suppress, any type) |
| `/autoresearch:debug` | `on` | Challenge hypothesis experiment design |
| `/autoresearch:security` | `off` | Already has 4 adversarial personas |
| `/autoresearch:predict` | `off` | Already has multi-persona swarm + debate |
| `/autoresearch:scenario` | `off` | Outputs scenarios, not code changes |
| `/autoresearch:learn` | `off` | Outputs docs, has validation-fix loop |
| `/autoresearch:ship` | `off` | Checklist workflow, not iteration loop |

## New Core Principle (#8)

Added to `core-principles.md`:

### 8. Separate Generation from Evaluation

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

## File Changes Summary

| File | Change Type | Description |
|------|------------|-------------|
| `references/autonomous-loop-protocol.md` | Rewrite | Phase renumbering, new Phase 3 inner loop with 3a-3e |
| `references/core-principles.md` | Add section | New principle #8: Separate Generation from Evaluation |
| `SKILL.md` | Update | Setup phase: new fields, Configuration Summary update |
| `references/fix-workflow.md` | Minor | Add `evaluator-default: on` |
| `references/debug-workflow.md` | Minor | Add `evaluator-default: on` |
| `references/security-workflow.md` | Minor | Add `evaluator-default: off` |
| `references/predict-workflow.md` | Minor | Add `evaluator-default: off` |
| `references/scenario-workflow.md` | Minor | Add `evaluator-default: off` |
| `references/learn-workflow.md` | Minor | Add `evaluator-default: off` |
| `references/ship-workflow.md` | Minor | Add `evaluator-default: off` |
| `hooks/validate-config.sh` | Minor | Add Evaluator/Max-Rework field validation |
| `hooks/stop-hook.sh` | None | No changes needed |
