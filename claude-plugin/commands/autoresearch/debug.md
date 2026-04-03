---
name: autoresearch:debug
description: "Autonomous bug-hunting loop — scientific method + autoresearch iteration. Finds ALL bugs, not just one. Use when: \"find all bugs\", \"hunt bugs\", \"debug this\", \"why is this failing\", \"investigate\"."
argument-hint: "[Issue/Symptom description] [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Debug

This is a workflow preset for `/autoresearch`. It pre-fills the Workflow with scientific-method debugging steps.

**Pre-filled Workflow:**
```
1. Read context and review known issues
2. Reproduce the bug — confirm it exists with evidence
3. Form hypothesis about root cause
4. Design experiment to test hypothesis
5. Run experiment and collect evidence
6. If hypothesis confirmed → implement fix
7. Verify fix resolves the issue without regressions
8. Record findings in context
```

**Default config:**
- Evaluator: on
- Completion Promise: (ask user or skip)

Load `references/debug-workflow.md` for the full debugging protocol, then follow the main autoresearch setup flow from `commands/autoresearch.md` — Step 2 onwards — with the Workflow pre-filled above.

Parse $ARGUMENTS for the issue/symptom description as the Goal.
