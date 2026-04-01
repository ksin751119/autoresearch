---
name: autoresearch
description: Autonomous Goal-directed Iteration. Modify, verify, keep/discard, repeat. Apply to ANY task.
argument-hint: "\"Goal: <text> [Workflow: ...] [Notes: ...]\" [--max-iterations N] [--completion-promise TEXT] [--guard CMD] [--verify CMD] [--direction higher|lower] [--evaluator on|off]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Step 1: Parse Arguments

Extract from $ARGUMENTS:

**From prompt text:**
- `Goal:` — text after keyword (REQUIRED)
- `Workflow:` — numbered steps after keyword (optional)
- `Notes:` — bullet points after keyword (optional)

**From flags (may appear in $ARGUMENTS or as CLI flags):**
- `--max-iterations N` (default: 0 = unlimited)
- `--completion-promise "TEXT"` (default: none)
- `--guard "CMD"` (default: none)
- `--verify "CMD"` (default: none)
- `--direction higher|lower` (required if --verify set)
- `--evaluator on|off` (default: on)
- `--max-rework N` (default: 2)

**Also check for v2 format fields** (backward compat):
- `Scope:`, `Metric:`, `Direction:`, `Verify:` — if all present, activate metric mode

Record which fields were extracted and which are MISSING.

## Step 2: Collect Missing Fields

If Goal is missing → ask via `AskUserQuestion`.

For ALL other fields, show them in one batch for the user to fill or skip:

```
Please configure the autoresearch loop:

1. Goal (required): [pre-filled or ___]
2. Workflow (steps per iteration, Enter to skip):
3. Notes (constraints/rules, Enter to skip):
4. Guard (shell command that must pass, Enter to skip):
5. Verify + Direction (metric command + higher/lower, Enter to skip):
6. Max Iterations (number, Enter to skip → unlimited):
7. Completion Promise (exit condition text, Enter to skip):
8. Evaluator (on/off, Enter to skip → on):
```

Pre-fill any fields already extracted from $ARGUMENTS. Only ask about missing ones.

## Step 3: Show Confirmation

Display the complete config and ask for confirmation:

```
📋 Configuration Summary:

  Goal:                <value>
  Workflow:            <steps or "default — Coordinator decides">
  Notes:               <items or "none">
  Guard:               <command or "none">
  Verify:              <command or "none">
  Direction:           <value or "n/a">
  Evaluator:           <on or off>
  Max-Rework:          <N>
  Max Iterations:      <N or "unlimited">
  Completion Promise:  <text or "none">

  Agent Team:
    - Coordinator: manage loop, dispatch agents, update knowledge
    - Research:    analyze data, find root causes
    - Dev:         implement solutions, commit, verify
    - Evaluator:   independent quality review

  ⚠️  Warnings (if any):
    - No exit criteria set — loop runs forever until /autoresearch:cancel
    - No guard set — no regression protection

Ready? [Launch / Edit / Cancel]
```

If "Edit" → ask which field, re-collect, show summary again.
If "Cancel" → stop.
If "Launch" → proceed.

## Step 4: Validate

Run validation with provided fields only:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh" \
  --goal "<GOAL>" \
  [--guard "<GUARD>" if set] \
  [--verify "<VERIFY>" --direction "<DIR>" if set] \
  [--evaluator "<EVALUATOR>" if set]
```

If fails → show error, ask to fix, re-validate.

## Step 5: Activate Loop

Build the prompt from Goal + Workflow + Notes, then run setup:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" \
  --goal "<GOAL>" \
  --prompt "<FULL_PROMPT_TEXT>" \
  [--guard "<GUARD>" if set] \
  [--verify "<VERIFY>" --direction "<DIR>" if set] \
  --max-iterations <N or 0> \
  [--completion-promise "<PROMISE>" if set] \
  --evaluator "<EVALUATOR>" \
  --max-rework <N>
```

## Step 6: Begin Iteration 1

Read `references/coordinator-protocol.md` then start the first iteration:
1. Create `.autoresearch/context.md` with initial state
2. Follow your Workflow (or decide autonomously)
3. Dispatch agents as needed
4. Update context.md at the end

The Stop Hook is now active. When you exit, it will re-inject the prompt for the next iteration.
