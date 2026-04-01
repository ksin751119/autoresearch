# Autoresearch Issues

## Bug: Bounded mode iteration counter desync — runs 2x expected iterations

**Severity:** High
**Date:** 2026-03-31
**Version:** 1.9.0

### Problem

When `max_iterations=N` is set, the loop runs approximately **2N iterations** instead of N. User expects 3 iterations but gets 6.

### Root Cause

There are **two independent iteration counters** that don't coordinate:

1. **Stop hook counter** (`stop-hook.sh`): stored in `.claude/autoresearch-loop.local.md` field `iteration`. Incremented each time Claude attempts to **exit the conversation**.
2. **Loop protocol counter**: tracked internally by Claude during the conversation. Incremented each time a loop iteration (Phase 1→8) completes.

In bounded mode, the loop protocol runs N iterations then tries to exit. But the stop hook's counter starts at 0 at that point and blocks exit N more times — resulting in ~2N total iterations.

### Reproduction

```
/autoresearch
Goal: any goal
Iterations: 3
```

**Expected:** 3 iterations, then stop.
**Actual:** 6 iterations (3 from loop protocol + 3 from stop hook blocking exit).

### Timeline of events

```
Loop iteration 1 → complete → protocol says continue (not at max yet)
Loop iteration 2 → complete → protocol says continue
Loop iteration 3 → complete → protocol says "max reached, print summary"
                            → Claude tries to exit conversation
                            → Stop hook fires → hook counter 0→1 < 3 → BLOCKS exit
                            → Re-injects loop prompt → Claude runs iteration 4
Loop iteration 4 → complete → Claude tries to exit
                            → Stop hook fires → hook counter 1→2 < 3 → BLOCKS exit
Loop iteration 5 → ...hook counter 2→3 = 3 → removes state file → allows exit
Loop iteration 6 → finally exits (or one more depending on timing)
```

### Suggested Fix

**Option A: Shared counter** — The loop protocol should update the `iteration` field in the state file after each completed iteration. The stop hook should read this field instead of maintaining its own counter.

```bash
# In the loop protocol (Phase 8), after each iteration:
sed -i "s/^iteration: .*/iteration: ${CURRENT_ITERATION}/" "$STATE_FILE"
```

Then the stop hook just checks `iteration >= max_iterations` without incrementing.

**Option B: Remove hook counter** — The stop hook should NOT increment its own counter. It should only check `active: true` to block exit. The loop protocol is solely responsible for tracking iterations and setting `active: false` when done.

```bash
# stop-hook.sh: simplified
if [[ "$ACTIVE" == "true" ]]; then
  # block exit, re-inject prompt
else
  exit 0  # allow exit
fi
```

The loop protocol sets `active: false` in the state file when max_iterations is reached, then the next exit attempt succeeds.

**Option B is recommended** — single source of truth for iteration count, simpler logic, no desync possible.

### Files involved

- `hooks/stop-hook.sh` — line 62-68 (iteration increment + max check)
- `scripts/setup-loop.sh` — creates state file with `iteration: 0`
- `skills/autoresearch/references/autonomous-loop-protocol.md` — Phase 8 bounded mode logic
