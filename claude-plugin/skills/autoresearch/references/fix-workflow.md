# Fix Workflow — /autoresearch:fix

Autonomous fix loop that takes a broken state and iteratively repairs it until everything passes. One fix per iteration. Atomic, committed, verified, auto-reverted on failure.

**Core idea:** Detect → Prioritize → Fix ONE thing → Verify → Keep/Revert → Repeat until zero errors.
**Evaluator default:** `on` — catches lazy fixes (suppressions, any types, deleted tests).

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [Interactive Setup](#interactive-setup)
- [Architecture](#architecture)
- [Phase 1: Detect — What's Broken?](#phase-1-detect--whats-broken)
- [Phase 2: Prioritize — Fix Order](#phase-2-prioritize--fix-order)
- [Phase 3: Fix ONE Thing — Atomic Change](#phase-3-fix-one-thing--atomic-change)
- [Phase 4: Commit — Before Verification](#phase-4-commit--before-verification)
- [Phase 5: Verify — Did It Help?](#phase-5-verify--did-it-help)
- [Phase 6: Guard — Did Anything Else Break?](#phase-6-guard--did-anything-else-break)
- [Phase 7: Decide — Keep, Revert, or Rework](#phase-7-decide--keep-revert-or-rework)
- [Phase 8: Log & Repeat](#phase-8-log--repeat)
- [Flags](#flags)
- [State Machine](#state-machine)
- [Anti-Patterns — Never Do These](#anti-patterns--never-do-these)
- [Compound Fix Detection](#compound-fix-detection)
- [Rollback Protocol](#rollback-protocol)
- [Escalation — After 3 Failed Attempts](#escalation--after-3-failed-attempts)
- [Fix Score (bounded loops)](#fix-score-bounded-loops)
- [Chaining Patterns](#chaining-patterns)
- [Output Directory](#output-directory)

## Trigger

- User invokes `/autoresearch:fix`
- User says "fix all errors", "make tests pass", "fix the build", "clean up all warnings"
- User has output from `/autoresearch:debug` and wants to fix the findings

## Loop Support

```
# Unlimited — keep fixing until everything passes
/autoresearch:fix

# Bounded — exactly N fix iterations
/autoresearch:fix
Iterations: 30

# With explicit target
/autoresearch:fix
Target: make all tests pass
Scope: src/**/*.ts
Guard: npm run typecheck
```

## Interactive Setup

Follow `references/interactive-setup-pattern.md`. Fix-specific questions:

| # | Header | Question | Options |
|---|--------|----------|---------|
| 1 | Fix What | "Found [N] test failures, [M] type errors, [K] lint errors. What should I fix?" | "Fix everything (recommended)", "Only tests", "Only type errors", "Only lint" |
| 2 | Guard | "What command must ALWAYS pass?" | Auto-detected commands, "Skip — no guard" |
| 3 | Scope | "Which files can I modify?" | Suggested globs from error locations, "All project files" |
| 4 | Launch | "Ready to fix?" | "Fix until zero errors", "Fix with iteration limit", "Edit config", "Cancel" |

Pre-scan: Run test suite, type checker, linter, and build to detect failures. Present summary in question 1.

## Architecture

```
/autoresearch:fix
  ├── Phase 1: Detect (what's broken?)
  ├── Phase 2: Prioritize (fix order)
  ├── Phase 3: Fix ONE thing (atomic change)
  ├── Phase 4: Commit (before verification)
  ├── Phase 5: Verify (did error count decrease?)
  ├── Phase 6: Guard (did anything else break?)
  ├── Phase 7: Decide (keep / revert / rework)
  └── Phase 8: Log & Repeat
```

## Phase 1: Detect — What's Broken?

Auto-detect the failure domain from context, or accept explicit target.

**Detection:** Run build first (if build fails, other results are unreliable), then test suite, type checker, linter, and check for debug findings. Also detect warnings (lowest priority). Sort failures by severity.

**Auto-detection signals:**

| Signal | Type | Command |
|--------|------|---------|
| `package.json` has `test` script | test | `npm test` |
| `tsconfig.json` exists | type | `tsc --noEmit` |
| `.eslintrc*` or `eslint.config.*` | lint | `npx eslint .` |
| `pyproject.toml` has `pytest` | test | `pytest` |
| `pyproject.toml` has `mypy`/`ruff` | type+lint | `mypy .`, `ruff check .` |
| `Cargo.toml` exists | test+lint | `cargo test`, `cargo clippy` |
| `go.mod` exists | test+lint | `go test ./...`, `golangci-lint run` |
| `build` script in package.json | build | `npm run build` |
| `debug/*/findings.md` exists | bug | Parse findings |
| `.github/workflows/*.yml` exists | ci | `gh run list --limit 1` |

**Output:** `✓ Phase 1: Detected — [N] test failures, [M] type errors, [K] lint errors, [W] warnings`

## Phase 2: Prioritize — Fix Order

| Priority | Category | Why First |
|----------|----------|-----------|
| 1 | **Build failures** | Nothing works if it doesn't compile |
| 2 | **Critical/High bugs** | From debug findings — data loss, security |
| 3 | **Type errors** | Type safety prevents cascading bugs |
| 4 | **Test failures** | Tests verify correctness |
| 5 | **Medium/Low bugs** | From debug findings |
| 6 | **Lint errors** | Code quality |
| 7 | **Warnings** | Polish |

Within a category: cascading impact first, then simplicity (quick wins), then file locality.

**Output:** `✓ Phase 2: Prioritized — fixing [category] first ([N] items)`

## Phase 3: Fix ONE Thing — Atomic Change

Pick the highest-priority unfixed item and make ONE focused change.

**Fix strategies:**

| Category | Strategy |
|----------|----------|
| Build failure | Read error, fix the exact line/import/config |
| Type error | Add proper types, fix signatures, handle null cases |
| Test failure | Read test + implementation, find mismatch, fix implementation (not test) |
| Lint error | Apply the rule — auto-fix where possible |
| Bug (from debug) | Apply the suggested fix from findings.md |
| Warning | Resolve the underlying issue, don't suppress |

**Language-specific rules:**

| Language | Never Do | Correct Pattern |
|----------|----------|-----------------|
| TypeScript | `any`, `@ts-ignore`, type assertions to bypass | Proper interfaces, generics, discriminated unions |
| Python | Bare `except:`, missing type hints on public API | `except SpecificError:`, full type hints |
| Go | Ignoring errors with `_`, `panic` in library code | `fmt.Errorf("context: %w", err)` |
| Rust | `.unwrap()` in production, `#[allow(unused)]` | `Result<T, E>` with `?`, `thiserror` |

**Rules:**
- ONE fix per iteration. Not two. Not "while I'm here."
- Fix the IMPLEMENTATION, not the test (unless the test is genuinely wrong)
- Never suppress errors (`@ts-ignore`, `eslint-disable`, `# type: ignore`, `any`)
- Never delete tests — fix the implementation to satisfy them
- Prefer minimal changes — smallest diff that fixes the issue

## Phase 4: Commit — Before Verification

```bash
git add <modified-files>
git commit -m "fix: [what was fixed] — [file:line]"
```

Commit BEFORE running verification. This enables clean rollback if the fix breaks something.

## Phase 5: Verify — Did It Help?

Re-run detection from Phase 1. Compute `delta = previous_errors - current_errors`. Expected: `delta > 0`.

## Phase 6: Guard — Did Anything Else Break?

If a guard command is specified, run it. Guard prevents regressions — fixing a type error shouldn't break a test.

## Phase 7: Decide — Keep, Revert, or Rework

| Condition | delta | Guard | Action | TSV Status |
|-----------|-------|-------|--------|-----------|
| Perfect fix | > 0 | pass | KEEP | fixed |
| Regression introduced | > 0 | fail | REWORK (max 2 attempts) | rework |
| No effect | == 0 | - | DISCARD, revert | discard |
| Made it worse | < 0 | - | DISCARD immediately | discard |
| Crash/exception | any | fail | RECOVER (simpler approach) | recover |
| 3rd attempt fails | any | any | SKIP to blocked list | blocked |

**Rework strategy (when guard fails):**
1. Revert: `git revert HEAD --no-edit`
2. Understand why the fix broke something else
3. Find an approach that fixes the target WITHOUT breaking the guard
4. If 2 rework attempts fail → skip, add to `blocked.md`, move to next

## Phase 8: Log & Repeat

**Append to fix-results.tsv:**
```tsv
iteration	category	target	delta	guard	status	description
0	-	-	-	pass	baseline	47 test failures, 12 type errors, 3 lint errors
1	type	auth.ts:42	-2	pass	fixed	add return type annotation
2	test	api.test.ts	-3	pass	fixed	fix expected status code (was 200, should be 201)
```

**Every 5 iterations, print progress:**
```
=== Fix Progress (iteration 15) ===
Baseline: 62 errors → Current: 23 errors (-39, -63%)
Keeps: 11 | Discards: 3 | Reworks: 1
```

**Completion:** If `current_errors == 0`, print "All Clear — Zero Errors" and STOP.

## Flags

| Flag | Purpose |
|------|---------|
| `--target <command>` | Explicit verify command (overrides auto-detection) |
| `--guard <command>` | Safety command that must always pass |
| `--scope <glob>` | Limit fixes to specific files |
| `--category <type>` | Only fix specific category (test, type, lint, build, bug) |
| `--skip-lint` | Don't fix lint errors (focus on functional issues) |
| `--from-debug` | Read findings from latest debug/ session |

## State Machine

```
DETECTING → PRIORITIZING → FIXING → VERIFYING → DECIDING → [DONE | LOOP]

DETECTING:   errors found → PRIORITIZING | zero errors → DONE
PRIORITIZING: pick first unfixed → FIXING
FIXING:      apply change, commit → VERIFYING
VERIFYING:   compute delta, run guard → DECIDING
DECIDING:
  delta > 0, guard pass → KEEP → LOOP
  delta > 0, guard fail → REWORK (max 2) → FIXING
  delta == 0 → DISCARD, revert → PRIORITIZING (next)
  delta < 0 → DISCARD, revert → PRIORITIZING
  3 failures → SKIP → blocked → PRIORITIZING
  all done → DONE
DONE: generate summary.md, print fix_score
```

## Anti-Patterns — Never Do These

| Anti-Pattern | Do This Instead |
|--------------|-----------------|
| `@ts-ignore` / `eslint-disable` | Fix the root cause |
| `any` type to silence TypeScript | Use proper types, generics, or `unknown` with narrowing |
| Delete or skip failing tests | Fix the implementation |
| Empty `catch (e) {}` blocks | Log, handle, or re-throw |
| Hardcode values to pass tests | Fix the logic |
| `--force` on npm/yarn install | Resolve conflicts explicitly |
| Increase test timeouts | Profile and fix the underlying issue |

## Compound Fix Detection

When fixing one error reveals new ones: these are likely pre-existing errors that were masked. Add them to the fix queue, don't treat as regression. If error count is unchanged but error details changed, the error just moved — revert and try differently.

## Rollback Protocol

When delta < 0 or guard breaks: revert (`git revert HEAD --no-edit`), verify error count returns to pre-fix state, log the failed approach in fix-results.tsv, then analyze what assumption was wrong before retrying with a different strategy.

## Escalation — After 3 Failed Attempts

1. Document what was tried and why each failed
2. Skip to `blocked.md`, continue with other errors
3. Suggest `/autoresearch:debug` on the specific error for root cause analysis
4. Never loop on the same failing approach — each attempt must use a different strategy

## Fix Score (bounded loops)

```
fix_score = reduction (60%) + guard (25%) + bonus (15%)

reduction = ((baseline - current) / baseline) * 60
guard     = guard_always_passed ? 25 : 0
bonus     = zero_errors ? 10 : 0 + no_discards ? 5 : 0
penalty   = -(suppressions * 5 + deleted_tests * 10 + any_types * 3), floor -20
```

**100+ = perfect | 80-99 = good | 60-79 = acceptable | <60 = needs work**

## Chaining Patterns

```bash
# Debug then fix
/autoresearch:debug → /autoresearch:fix --from-debug --guard "npm test"

# Category-by-category
/autoresearch:fix --category build
/autoresearch:fix --category type --guard "npm run build"
/autoresearch:fix --category test --guard "tsc --noEmit"

# Scoped parallel
/autoresearch:fix --scope "src/api/**" --category type
/autoresearch:fix --scope "src/auth/**" --category test

# Full pipeline
/autoresearch:debug → /autoresearch:fix --from-debug → /autoresearch:ship
```

## Output Directory

Creates `fix/{YYMMDD}-{HHMM}-{fix-slug}/` with:
- `fix-results.tsv` — iteration log
- `summary.md` — what was fixed, what remains, stats
- `blocked.md` — errors that needed 3+ attempts and were escalated
