# Debug Workflow — /autoresearch:debug

Autonomous bug-hunting loop that applies the scientific method iteratively. Doesn't stop at one bug — keeps investigating until the codebase is clean or you interrupt.

**Core idea:** Hypothesize → Test → Prove/Disprove → Log → Repeat. Every finding needs code evidence. Every failed hypothesis teaches the next one.
**Evaluator default:** `on` — challenges hypothesis experiment design and evidence quality.

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [PREREQUISITE: Interactive Setup (when invoked without flags)](#prerequisite-interactive-setup-when-invoked-without-flags)
- [Architecture](#architecture)
- [Phase 1: Gather — Symptoms & Context](#phase-1-gather--symptoms--context)
- [Phase 2: Reconnaissance — Map the Error Surface](#phase-2-reconnaissance--map-the-error-surface)
- [Phase 3: Hypothesize — Form Falsifiable Hypothesis](#phase-3-hypothesize--form-falsifiable-hypothesis)
- [Phase 4: Test — Run Experiment](#phase-4-test--run-experiment)
- [Phase 5: Classify — What Did We Learn?](#phase-5-classify--what-did-we-learn)
- [Phase 6: Log — Record Everything](#phase-6-log--record-everything)
- [Phase 7: Repeat — Next Investigation](#phase-7-repeat--next-investigation)
- [Flags](#flags)
- [Composite Metric](#composite-metric)
- [Investigation Techniques Reference](#investigation-techniques-reference)
- [Common Bug Patterns by Language](#common-bug-patterns-by-language)
- [Domain-Specific Reference](#domain-specific-reference)
- [Output Directory](#output-directory)
- [Chaining with /autoresearch:fix](#chaining-with-autoresearchfix)

## Trigger

- User invokes `/autoresearch:debug`
- User says "find all bugs", "debug this", "why is this failing", "hunt bugs", "investigate"
- User reports a specific error and wants root cause analysis

## Loop Support

```
# Unlimited — keep hunting bugs until interrupted
/autoresearch:debug

# Bounded — exactly N investigation iterations
/autoresearch:debug
Iterations: 20

# Focused scope
/autoresearch:debug
Scope: src/api/**/*.ts
Symptom: API returns 500 on POST /users
```

## PREREQUISITE: Interactive Setup (when invoked without flags)

**CRITICAL — BLOCKING PREREQUISITE:** If `/autoresearch:debug` is invoked without `--scope` or `--symptom`, you MUST use `AskUserQuestion` to gather full context BEFORE proceeding to ANY phase. DO NOT skip this step. DO NOT jump to Phase 1 without completing interactive setup.

Scan the codebase first (run tests, lint, typecheck) to detect existing failures and provide smart defaults.

**Single batched call — all 4 questions at once:**

You MUST call `AskUserQuestion` with all 4 questions in ONE call:

| # | Header | Question | Options (from codebase scan) |
|---|--------|----------|------------------------------|
| 1 | `Issue` | "What's the problem?" | "Hunt all bugs (scan entire codebase)", "Specific error (I'll describe it)", "Failing tests", "CI/CD failure", "Performance issue" |
| 2 | `Scope` | "Which files should I investigate?" | Suggested globs from project structure + "Entire codebase" |
| 3 | `Depth` | "How deep should I investigate?" | "Quick scan (5 iterations)", "Standard (15 iterations)", "Deep investigation (30+)", "Unlimited" |
| 4 | `After` | "When bugs are found, should I also fix them?" | "Find bugs only (report)", "Find and fix (chain to /autoresearch:fix)", "Ask me after each finding" |

**IMPORTANT:** Always ask all 4 questions in a single call — never one at a time. Users need full context to make informed decisions.

If `--scope`, `--symptom`, or `--fix` flags are provided, skip the interactive setup and proceed directly to Phase 1.

## Architecture

```
/autoresearch:debug
  ├── Phase 1: Gather (symptoms + context)
  ├── Phase 2: Reconnaissance (scan codebase, map error surface)
  ├── Phase 3: Hypothesize (form falsifiable hypothesis)
  ├── Phase 4: Test (run experiment to prove/disprove)
  ├── Phase 5: Classify (bug found / hypothesis disproven / inconclusive)
  ├── Phase 6: Log (record finding or elimination)
  └── Phase 7: Repeat (next hypothesis, next vector)
```

## Phase 1: Gather — Symptoms & Context

**STOP: Have you completed the Interactive Setup above?** If invoked without `--scope`/`--symptom` flags, you MUST complete the `AskUserQuestion` call above BEFORE entering this phase.

Collect everything known about the problem before investigating.

**If user provides symptoms:**
- Expected behavior vs actual behavior
- Error messages, stack traces, log output
- When it started (commit, deploy, config change)
- Reproduction steps (if known)
- Environment (OS, runtime, versions)

**If no symptoms (autonomous bug hunting):**
- Run existing test suite, collect failures
- Run linter, collect errors
- Run type checker, collect issues
- Check build, collect warnings
- Scan for common anti-patterns (unhandled promises, unchecked nulls, race conditions)

**Output:** `✓ Phase 1: Gathered — [N] symptoms, [M] error signals detected`

## Phase 2: Reconnaissance — Map the Error Surface

Understand the codebase area where bugs likely live.

**Actions:**
1. Read files mentioned in stack traces / error messages
2. Trace call chains from error origin backward
3. Identify entry points (API routes, event handlers, CLI commands)
4. Map data flow through affected components
5. Check recent git changes in affected area (`git log --oneline -20 -- <path>`)
6. Identify external dependencies and integration points

**Error surface map:**
```
Entry Point → Data Flow → Failure Point → Side Effects
  POST /users → validate() → db.insert() → ← FAILS HERE
                                             → notification.send() ← cascading
```

**Output:** `✓ Phase 2: Recon — [N] files scanned, [M] potential failure points mapped`

## Phase 3: Hypothesize — Form Falsifiable Hypothesis

**A good hypothesis is:**
- Specific: "The JWT validation skips algorithm check on line 42 of auth.ts"
- Testable: Can be proven/disproven with a concrete experiment
- Falsifiable: There exists evidence that would prove it wrong
- Prioritized: Most likely cause first (based on evidence so far)

**Hypothesis formation strategy:**

| Priority | Strategy | When to Use |
|----------|----------|-------------|
| 1 | **Error message literal** | Stack trace points to exact line |
| 2 | **Recent change** | Bug started after specific commit |
| 3 | **Data flow trace** | Input → Transform → Output chain |
| 4 | **Environment diff** | Works locally, fails in CI/prod |
| 5 | **Dependency issue** | After upgrade/install |
| 6 | **Race condition** | Intermittent, timing-dependent |
| 7 | **Edge case** | Works for most inputs, fails for specific ones |

**Cognitive bias guards:**
- Confirmation bias: Actively seek evidence AGAINST your hypothesis
- Anchoring: Don't fixate on the first clue — consider alternatives
- Sunk cost: If 3 experiments fail to confirm, abandon and try new hypothesis
- Availability: Just because a bug pattern is familiar doesn't mean it's the cause

**Output:** `Hypothesis [N]: "[specific, testable claim]" — testing...`

## Phase 4: Test — Run Experiment

Design a minimal experiment that definitively proves or disproves the hypothesis.

**Experiment types:**

| Type | Method | Best For |
|------|--------|----------|
| **Direct inspection** | Read the code at suspected location | Logic errors, missing checks |
| **Trace execution** | Add logging, run, read output | Data flow issues |
| **Minimal reproduction** | Create smallest failing case | Complex interactions |
| **Binary search** | Comment out half the code, narrow | "Something in this file breaks" |
| **Differential** | Compare working vs broken (git diff, env diff) | Regressions |
| **Git bisect** | Find exact commit that introduced bug | "It used to work" |
| **Input variation** | Change inputs systematically | Edge cases, boundary issues |

**Experiment rules:**
- ONE experiment per iteration (atomic — know exactly what you tested)
- Record the exact command/action and its output
- If experiment is destructive, git stash first
- Timeout: if an experiment takes >30 seconds, it's too complex — simplify

## Phase 5: Classify — What Did We Learn?

| Result | Action |
|--------|--------|
| **Bug confirmed** | Record finding with full evidence, severity, location |
| **Hypothesis disproven** | Log as eliminated, extract learnings for next hypothesis |
| **Inconclusive** | Refine hypothesis with additional constraints, re-test |
| **New lead discovered** | Log discovery, add to hypothesis queue |

**Bug finding format:**
```
### [SEVERITY] Bug: [title]
- **Location:** `file:line`
- **Hypothesis:** [what we suspected]
- **Evidence:** [code snippet + experiment result]
- **Reproduction:** [exact steps to trigger]
- **Impact:** [what breaks, who's affected]
- **Root cause:** [WHY it happens, not just WHAT happens]
- **Suggested fix:** [concrete code change]
```

**Severity classification:**
| Level | Criteria |
|-------|----------|
| CRITICAL | Data loss, security breach, system crash |
| HIGH | Feature broken, incorrect results, performance degradation >10x |
| MEDIUM | Edge case failure, degraded UX, workaround exists |
| LOW | Cosmetic, minor inconsistency, theoretical risk |

## Phase 6: Log — Record Everything

**Append to debug-results.tsv:**
```tsv
iteration	type	hypothesis	result	severity	location	description
1	hypothesis	JWT skips alg check	confirmed	CRITICAL	auth.ts:42	Algorithm confusion vulnerability
2	hypothesis	Rate limit missing	disproven	-	-	Rate limiter exists in middleware
3	discovery	-	new_lead	-	db.ts:88	Unhandled promise rejection in insert
4	hypothesis	DB insert missing await	confirmed	HIGH	db.ts:88	Silent failure on write errors
```

**Every 5 iterations, print progress:**
```
=== Debug Progress (iteration 10) ===
Bugs found: 3 (1 Critical, 1 High, 1 Medium)
Hypotheses tested: 8 (3 confirmed, 4 disproven, 1 inconclusive)
Files investigated: 14 / 47 in scope
Techniques used: direct inspection, trace, binary search
```

## Phase 7: Repeat — Next Investigation

**Prioritization for next iteration:**
1. Follow new leads discovered during previous experiments
2. Untested high-priority hypotheses
3. Uninvestigated files in the error surface
4. Deeper investigation of confirmed bugs (find root cause, not just symptom)
5. Pattern-based search (if found NULL check bug, look for similar patterns elsewhere)

**When to stop (unbounded mode):**
- Never stop automatically — user interrupts
- Print a "diminishing returns" warning after 5 iterations with no new findings

**When to stop (bounded mode):**
- After N iterations, print final summary and stop

## Flags

| Flag | Purpose |
|------|---------|
| `--fix` | After finding bugs, switch to autoresearch:fix mode to fix them |
| `--scope <glob>` | Limit investigation to specific files |
| `--symptom "<text>"` | Pre-fill symptom instead of asking |
| `--severity <level>` | Only report findings at or above this severity |
| `--technique <name>` | Force a specific investigation technique |

## Composite Metric

For bounded loops, the debug thoroughness metric:

```
debug_score = bugs_found * 15
            + hypotheses_tested * 3
            + (files_investigated / files_in_scope) * 40
            + (techniques_used / 7) * 10
```

Higher = more thorough. Incentivizes breadth (cover more files) AND depth (test more hypotheses).

## Investigation Techniques Reference

### Binary Search
Comment out half the suspicious code. If bug disappears, it's in that half. Repeat.

### Differential Debugging
Compare working state vs broken state:
- `git stash` to test clean state
- `git bisect` to find exact breaking commit
- Environment variables diff between working/failing environments

### Minimal Reproduction
Strip away everything until you have the smallest possible case that reproduces the bug. Fewer moving parts = clearer cause.

### Trace Execution
Add strategic console.log/print statements at key data flow points. Run and read the actual values vs expected values.

### Pattern Search
Found one bug? Search for the same anti-pattern across the codebase:
```bash
grep -rn "pattern" src/ --include="*.ts"
```

### Working Backwards
Start from the error (output) and trace backward through the code until you find where correct behavior diverges from actual behavior.

### Rubber Duck
Explain the code out loud, line by line. The act of explaining often reveals the assumption that's wrong.

## Common Bug Patterns by Language

Quick reference for language-specific bugs to scan for during reconnaissance.

| Language | Classic Bug | Pattern to Search | Why It Happens |
|----------|-------------|-------------------|----------------|
| **JavaScript** | Unhandled promise rejection | `Promise` without `.catch` / missing `await` | Async errors are swallowed silently |
| **TypeScript** | `undefined` access after null check narrowing | `obj?.prop` then `obj.other` (lost narrowing) | Type narrowing is scope-limited |
| **Python** | Mutable default argument | `def f(x=[]):` — shared across all calls | Python evaluates defaults once at definition time |
| **Python** | `None` injection from unchecked return | Function returns `None` on error path, caller chains it | Missing null/None guard |
| **Go** | Goroutine leak | Goroutine blocks on channel that's never closed | Missing `defer close(ch)` or `context.Cancel()` |
| **Go** | Race condition on shared map | Concurrent read/write without mutex | Maps in Go are not goroutine-safe |
| **Go** | Integer overflow in slice/buffer ops | `int` size differences on 32-bit vs 64-bit | Implicit numeric type assumptions |
| **Rust** | Panic in production from `.unwrap()` | `Option::unwrap()` / `Result::unwrap()` on `Err` | Error path not handled |
| **Java** | `NullPointerException` cascade | Unguarded method chain `a.b().c().d()` | No null checks in chain |
| **Java** | SQL injection via string concat | `"SELECT * FROM t WHERE id=" + id` | Missing parameterized queries |
| **SQL** | N+1 query | Loop calling DB inside loop | Missing JOIN or batch fetch |
| **All** | Race condition on shared state | Global/singleton mutated from concurrent threads | Missing synchronization |
| **All** | Integer overflow in calculations | Arithmetic on large numbers without bounds check | Silent wrap-around on overflow |
| **All** | Injection vulnerability | User input concatenated into command/query/template | Missing sanitization/escaping |

**Reconnaissance shortcut:** When entering Phase 2, grep for these patterns first — they're statistically the most common issues.

## Domain-Specific Reference

For domain-specific debug checklists (API, Database, Auth, Async, Network), anti-patterns, multi-file tracing protocol, performance investigation, and root cause analysis (5 Whys), see `references/debug-reference-material.md`.

## Output Directory

Creates `debug/{YYMMDD}-{HHMM}-{debug-slug}/` with:
- `findings.md` — all confirmed bugs with evidence
- `eliminated.md` — disproven hypotheses (equally valuable)
- `debug-results.tsv` — iteration log
- `summary.md` — executive summary with recommendations

## Chaining with /autoresearch:fix

```
# Find bugs, then fix them
/autoresearch:debug --fix

# Or manually chain
/autoresearch:debug
Iterations: 15

/autoresearch:fix
Iterations: 20
```

When `--fix` is specified, after the debug loop completes, automatically switches to `/autoresearch:fix --from-debug` targeting the discovered issues. The `--from-debug` flag tells fix to read findings from the latest debug session.
