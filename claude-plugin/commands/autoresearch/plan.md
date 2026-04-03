---
name: autoresearch:plan
description: "Interactive wizard to build Scope, Metric, Direction & Verify from a Goal. Use when: \"plan an autoresearch run\", \"help me set up autoresearch\", \"configure autoresearch\"."
argument-hint: "[Goal description]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Planning Wizard

This is a ONE-SHOT command (not a loop). It helps the user build a complete autoresearch configuration.

Pre-filled Workflow:
```
1. Capture the user's Goal (from $ARGUMENTS or ask)
2. Scan codebase for tooling, test runners, build scripts
3. Suggest Scope — file globs, validate they resolve to real files
4. Suggest Metric — mechanical metric, validate it outputs a number
5. Determine Direction — higher or lower is better
6. Construct Verify command — build it, dry-run it, confirm it works
7. Ask about optional fields: Guard, Iterations, Evaluator
8. Present complete config — offer to launch /autoresearch directly
```

Load `references/plan-workflow.md` for the full planning protocol.

Parse $ARGUMENTS for the goal text. This command does NOT enter the autonomous loop — it produces a ready-to-use /autoresearch invocation.
