# Autonomous Loop Protocol

> **Legacy (v2):** This protocol is used when the user provides v2-format inline config (`Metric:`, `Direction:`, `Verify:`, `Scope:` fields). For v3 YAML-config mode, see `coordinator-protocol.md`.
>
> **Backward Compatibility:** If the prompt contains `Metric:`, `Direction:`, `Verify:`, and `Scope:` fields (v2 format), activate **metric mode**: use this file for the 8-phase protocol and `results-logging.md` for TSV logging.

Detailed protocol for the autoresearch metric-mode iteration loop. SKILL.md has the summary; this file has the full rules.

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

## Phase 0: Precondition Checks (before loop starts)

**MUST complete ALL checks before entering the loop. Fail fast if any check fails.**

```bash
# 1. Verify git repo exists
git rev-parse --git-dir 2>/dev/null || echo "FAIL: not a git repo"

# 2. Check for dirty working tree
git status --porcelain
# → If dirty: warn user and ask to stash or commit first

# 3. Check for stale lock files
ls .git/index.lock 2>/dev/null && echo "WARN: stale lock"

# 4. Check for detached HEAD
git symbolic-ref HEAD 2>/dev/null || echo "WARN: detached HEAD"

# 5. Check for git hooks that might interfere
ls .git/hooks/pre-commit .git/hooks/commit-msg 2>/dev/null && echo "INFO: git hook detected"
ls .husky/pre-commit .husky/commit-msg 2>/dev/null && echo "INFO: husky hook detected"
ls .pre-commit-config.yaml 2>/dev/null && echo "INFO: pre-commit framework detected"
```

**If any FAIL:** Stop and inform user. Do not enter the loop with broken preconditions.
**If any WARN:** Log the warning, proceed with caution, inform user.

## Phase 1: Review (30 seconds)

Before each iteration, build situational awareness. **You MUST complete ALL 6 steps — git history is critical for learning from past iterations.**

```
1. Read current state of in-scope files (full context)
2. Read last 10-20 entries from results log
3. MUST run: git log --oneline -20 to see recent changes
4. MUST run: git diff HEAD~1 (if last iteration was "keep") to review what worked
5. Identify: what worked, what failed, what's untried — based on BOTH results log AND git history
6. If bounded: check current_iteration vs max_iterations
```

**Why read git history every time?** Git IS the memory. After rollbacks, state may differ from what you expect. The git log shows which experiments were kept vs reverted. The git diff of kept changes reveals WHAT specifically improved the metric — use this to inform the next iteration.

## Phase 2: Ideate (Strategic)

Pick the NEXT change. **MUST consult git history and results log before deciding.**

**Priority order:**

1. **Fix crashes/failures** from previous iteration first
2. **Exploit successes** — run `git diff` on last kept commit, try variants in same direction
3. **Explore new approaches** — cross-reference results log AND git history to find untried approaches
4. **Combine near-misses** — two changes that individually didn't help might work together
5. **Simplify** — remove code while maintaining metric. Simpler = better
6. **Radical experiments** — when incremental changes stall, try something dramatically different

**Anti-patterns:**
- Don't repeat exact same change that was already discarded — CHECK git log first
- Don't make multiple unrelated changes at once (can't attribute improvement)
- Don't chase marginal gains with ugly complexity

**Bounded mode consideration:** If remaining iterations are limited (<3 left), prioritize exploiting successes over exploration.

**Evaluator-rejected awareness:** If the results log shows the previous iteration was `evaluator-rejected`, read the Evaluator's critique from the log description. Use it to inform this iteration's approach.

## Phase 3: Implement (Inner Loop)

The inner loop runs Phase 3a → 3b → 3c → 3d → 3e. If any hard gate (3c Verify, 3d Guard) fails and cannot be fixed, the inner loop exits early. Phase 3e (Evaluate) provides a quality gate that can trigger rework.

**Inner loop flow:**

```
attempt = 0
max_rework = Max-Rework config value (default: 2)

LOOP:
  3a: Modify (use Phase 2 plan on attempt=0, or Evaluator critique on attempt>0)
  3b: Commit
  3c: Verify
      -> crash: exit inner loop with "crash"
      -> no-op: exit inner loop with "no-op"
      -> hook-blocked: exit inner loop with "hook-blocked"
      -> metric worse or same: safe_revert(), exit inner loop with "discard"
      -> metric improved: continue to 3d
  3d: Guard (if configured)
      -> guard failed after 2 rework attempts: safe_revert(), exit inner loop with "discard"
      -> guard passed (or no guard): continue to 3e
  3e: Evaluate (if configured)
      -> evaluator off: exit inner loop with "keep"
      -> pass: exit inner loop with "keep"
      -> fail AND attempt < max_rework: safe_revert(), increment attempt, go to 3a
      -> fail AND attempt >= max_rework: safe_revert(), exit inner loop with "evaluator-rejected"
```

**Short-circuit rules:** Verify failure and Guard failure are hard gates — they exit the inner loop immediately (after rework attempts for Guard). The Evaluator is only reached if both Verify and Guard pass.

### Phase 3a: Modify (One Atomic Change)

On the first attempt (attempt=0), use the plan from Phase 2. On rework attempts (attempt>0), use the Evaluator's critique to modify the approach while preserving the original intent.

- Make ONE focused change to in-scope files
- The change should be explainable in one sentence
- Write the description BEFORE making the change (forces clarity)
- **The one-sentence test:** If you need "and" to describe it, it's two changes. Split them.

### Phase 3b: Commit (Before Verification)

**You MUST commit before running verification.** This enables clean rollback if the experiment fails.

```bash
# Stage ONLY in-scope files
git add <file1> <file2> ...
# AVOID git add -A — it stages ALL files including .env and user's unrelated work

# Check if there's actually something to commit
git diff --cached --quiet
# → exit code 0 (no changes): skip commit, log as "no-op"
# → exit code 1 (changes exist): proceed

# Commit with descriptive experiment message
git commit -m "experiment(<scope>): <one-sentence description>"
```

**Hook failure handling:** If a pre-commit hook blocks the commit:
1. Read the hook's error output to understand WHY
2. If fixable (lint error, formatting): fix, re-stage, retry — do NOT use `--no-verify`
3. If not fixable within 2 attempts: log as `status=hook-blocked`, revert changes, move on

**Rollback strategy:**
```bash
# Preferred: git revert (preserves history for learning)
git revert HEAD --no-edit

# Fallback: git reset (if revert conflicts)
git revert --abort && git reset --hard HEAD~1
```

### Phase 3c: Verify (Mechanical Only)

Run the verification command. Extract the metric. Compare against baseline/previous.

**Timeout rule:** If verification exceeds 2x normal time, kill and treat as crash.

**Noise handling for volatile metrics:**
- **Multi-run median:** Run verify N times, take median (configure via `Noise: high` or `Noise-Runs: N`)
- **Min-delta threshold:** Ignore improvements smaller than noise floor (`Min-Delta: 2.0`)
- **Confirmation run:** Re-verify before final keep decision
- **Environment pinning:** Pin seeds, disable random ordering, flush caches

### Phase 3d: Guard (Regression Check)

If a **guard** command was defined, run it after verification.

- **Verify** answers: "Did the metric improve?"
- **Guard** answers: "Did anything else break?"

**Guard rules:**
- Run AFTER verify — no point checking guard if metric didn't improve
- Guard is pass/fail only (exit code 0 = pass)
- If guard fails, rework (max 2 attempts) — revert, read guard output, try different implementation
- NEVER modify guard/test files — adapt the implementation instead
- Guard rework and Evaluator rework have independent attempt counters

### Phase 3e: Evaluate (Independent Review)

If `Evaluator: off`, skip — exit inner loop with "keep".

Otherwise, spawn an independent Evaluator subagent. The Evaluator has NO access to your context window — only the structured input you provide.

**Spawn the Evaluator subagent with this prompt:**

~~~
# Role
You are an independent Evaluator. Your job is to critically review a code change.
You are completely separate from the agent that produced this code.

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
```diff
{output of: git diff HEAD~1}
```

# Rules
1. Point to specific code lines in the diff. No vague critiques.
2. The mechanical metric already passed — focus on what the metric CANNOT cover.
3. Default stance is skeptical, but do not reject for the sake of rejecting.
4. If the change is simple and correct, pass it.

# Review Dimensions
1. Logical correctness — does the change implement the stated intent?
2. Edge cases — unhandled boundary conditions?
3. Metric authenticity — gaming the metric without real improvement?
4. Side effects — unintended impact outside scope?
5. Simplicity — overly complex? simpler way?

# Output Format (strict JSON, nothing else)
{
  "verdict": "pass" or "fail",
  "critique": "specific issue (required when fail, empty string when pass)",
  "suggestions": ["actionable fix 1", "..."],
  "risk_flags": ["potential concern even if passing", "..."]
}
~~~

**Processing the Evaluator's response:**

1. Parse JSON. If parsing fails, treat as "pass".
2. If `pass`: store `risk_flags` for logging, exit inner loop with "keep".
3. If `fail` and `attempt < max_rework`: `safe_revert()`, store critique/suggestions, increment attempt, go to 3a.
4. If `fail` and `attempt >= max_rework`: `safe_revert()`, exit with "evaluator-rejected".

**Rework guidance for Phase 3a:** Address the specific critique (not rewrite from scratch). Preserve original intent. Commit message: `experiment(<scope>): rework — <description> — address: <critique summary>`.

## Phase 4: Decide

The inner loop exits with: "keep", "discard", "crash", "no-op", "hook-blocked", or "evaluator-rejected".

```
IF "keep":           Commit stays. Store risk_flags if any.
IF "keep" + rework:  STATUS = "keep (reworked)"
IF "discard":        Already reverted in Phase 3c or 3d.
IF "evaluator-rejected": Already reverted in 3e. Store critique for Phase 2.
IF "crash":          Already handled in 3c.
IF "no-op":          Phase 3a produced no diff.
IF "hook-blocked":   Pre-commit hook rejected.
```

**Simplicity override:** If metric barely improved (+<0.1%) but change adds significant complexity, treat as "discard". If metric unchanged but code is simpler, treat as "keep".

## Phase 5: Log Results

Append to results log (TSV format). See `references/results-logging.md` for full protocol.

```
iteration  commit   metric  delta  guard  eval     status               description
42         a1b2c3d  0.9821  +0.01  pass   pass     keep                  increase attention heads
43         -        0.9845  +0.02  pass   fail     evaluator-rejected    switch optimizer
44         -        0.0000  0.0    -      -        crash                 double batch size (OOM)
45         -        -       -      -      -        no-op                 no diff produced
46         -        -       -      -      -        hook-blocked          pre-commit lint rejected
47         b2c3d4e  0.9830  +0.01  pass   pass(1)  keep (reworked)       add caching layer (1 rework)
```

**eval column values:** `pass`, `fail`, `pass(N)`, `-` (not reached), `off`

**Valid statuses:** `keep`, `keep (reworked)`, `discard`, `crash`, `no-op`, `hook-blocked`, `evaluator-rejected`

## Phase 6: Repeat

### Unbounded Mode (default)

Go to Phase 1. **NEVER STOP. NEVER ASK IF YOU SHOULD CONTINUE.**

### Bounded Mode (with Iterations: N)

After completing Phase 5, stop. The hook will either re-inject (iterations remaining) or allow exit (N reached).

**Final summary format (print on last iteration):**
```
=== Autoresearch Complete ===
Baseline: {baseline} → Final: {current} ({delta})
Keeps: X | Discards: Y | Crashes: Z | Eval-Rejected: R | Skipped: W
Best iteration: #{n} — {description}
```

### When Stuck (>5 consecutive discards or evaluator-rejected)

1. Re-read ALL in-scope files from scratch
2. Re-read the original goal/direction
3. Review entire results log for patterns
4. If evaluator-rejected: re-read ALL evaluator critiques — find the common pattern
5. Try combining 2-3 previously successful changes
6. Try the OPPOSITE of what hasn't been working
7. Try a radical architectural change

## Crash Recovery

- Syntax error → fix immediately, don't count as separate iteration
- Runtime error → attempt fix (max 3 tries), then move on
- Resource exhaustion (OOM) → revert, try smaller variant
- Infinite loop/hang → kill after timeout, revert, avoid that approach
- External dependency failure → skip, log, try different approach

## Communication

- **DO NOT** ask "should I keep going?" — in unbounded mode, YES. In bounded mode, continue until N.
- **DO NOT** summarize after each iteration — just log and continue
- **DO** print a brief one-line status every ~5 iterations
- **DO** alert if you discover something surprising or game-changing
- **DO** print a final summary when bounded loop completes
