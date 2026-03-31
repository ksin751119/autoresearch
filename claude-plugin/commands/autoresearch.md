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
