---
name: autoresearch
description: Autonomous Goal-directed Iteration. Modify, verify, keep/discard, repeat. Apply to ANY task with a measurable metric.
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Verify: <cmd>] [Guard: <cmd>] [--iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST, before reading any files)

Extract these from $ARGUMENTS — the user may provide extensive context alongside config. Ignore prose and extract ONLY structured fields:

- `Goal:` — text after "Goal:" keyword
- `Scope:` or `--scope <glob>` — file globs after "Scope:" keyword
- `Metric:` — text after "Metric:" keyword
- `Direction:` — "higher" or "lower" after "Direction:" keyword
- `Verify:` — shell command after "Verify:" keyword
- `Guard:` — shell command after "Guard:" keyword (optional)
- `Iterations:` or `--iterations` — integer N for bounded mode (CRITICAL: if set, you MUST run exactly N iterations then stop)

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

## Execution

1. Read the autonomous loop protocol: `.claude/skills/autoresearch/references/autonomous-loop-protocol.md`
2. Read the results logging format: `.claude/skills/autoresearch/references/results-logging.md`
3. If Goal, Scope, Metric, and Verify are all extracted — proceed directly to step 5
4. If any critical field is missing — use `AskUserQuestion` with batched questions as defined in SKILL.md "Interactive Setup" section
5. **Activate the Stop hook** — After all config is collected, run the setup script to create the loop state file. This ensures the Stop hook will keep the session looping even if you try to exit:

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

   Replace placeholders with actual values collected from args or interactive setup.

6. Execute the autonomous loop: Modify → Verify → Keep/Discard → Repeat
7. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

IMPORTANT: Start executing immediately. Stream all output live — never run in background. Never stop early unless goal achieved or max_iterations reached.

## Stop Hook Behavior

Once step 5 creates the state file, the Stop hook is active. If you try to exit (intentionally or accidentally), the hook will:
- Block the exit
- Re-inject the loop prompt with the current iteration number
- You will re-enter Phase 1 (Review) of the autonomous loop protocol

To stop the loop, the user must run `/autoresearch:cancel` or the max iterations must be reached.

Do NOT attempt to remove the state file yourself. Only `/autoresearch:cancel` or the hook's max-iteration check removes it.
