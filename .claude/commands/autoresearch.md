---
name: autoresearch
description: Autonomous Goal-directed Iteration. Loops autonomously with multi-agent team — Research, Dev, Evaluator. Works with ANY task.
argument-hint: "--config <path>"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Step 1: Argument Parsing (do this FIRST)

Extract `--config <path>` from $ARGUMENTS.

If no `--config` is found, check if `.autoresearch/config.yaml` exists in the current directory. If it does, use it. If not, tell the user:

```
No config file found. Please either:
1. Create .autoresearch/config.yaml manually
2. Run /autoresearch:setup "your goal" to generate one interactively
```

## Step 2: Read Protocol

1. Read the SKILL file: `.claude/skills/autoresearch/SKILL.md`
2. Read your Coordinator protocol: `.claude/skills/autoresearch/references/coordinator-protocol.md`

## Step 3: Show Config Summary

Read the YAML config file. Display:

```
Configuration Summary:
  Goal:               <goal>
  Workflow:           <N steps or "none">
  Notes:              <N constraints or "none">
  Guard:              <cmd or "none">
  Verify:             <cmd or "none"> (<direction>)
  Max iterations:     <N or "unlimited">
  Completion promise: <text or "none">
  Evaluator:          <on/off>

Config: <path>

[Launch / Edit / Cancel]
```

Use `AskUserQuestion` to confirm. **Never skip confirmation.**

- **Launch** → Step 4
- **Edit** → tell user to modify the YAML, re-show summary
- **Cancel** → stop

## Step 4: Validate Config

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh" --config "<CONFIG_PATH>"
```

If validation fails → show error, ask user to fix, re-validate.

## Step 5: Activate the Stop Hook

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --config "<CONFIG_PATH>"
```

## Step 6: Execute the Autonomous Loop

Enter the loop. Read `.autoresearch/context.md`, dispatch agents, iterate.

The Stop hook blocks exit and re-injects the prompt each iteration. To stop: `/autoresearch:cancel` or max iterations reached.
