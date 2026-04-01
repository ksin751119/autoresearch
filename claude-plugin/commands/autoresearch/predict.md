---
name: autoresearch:predict
description: Multi-persona swarm prediction — pre-analyze code from multiple expert perspectives using file-based knowledge representation
argument-hint: "[Scope/Goal] [--personas N] [--rounds N] [--depth LEVEL] [--chain TARGETS]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Multi-Persona Prediction

Pre-filled Workflow:
```
1. Read context and scan codebase — extract entities, map dependencies
2. Generate 3-5 expert personas from codebase context
3. Each persona analyzes code from their unique perspective
4. Structured debate — 1-2 rounds of cross-examination with Devil's Advocate
5. Synthesize consensus with confidence scores + anti-herd check
6. Write findings to predict/ output folder
7. Generate handoff.json for optional --chain to other tools
8. Record findings in context
```

**Default config:**
- Evaluator: off (prediction is analysis, not code changes)

Load `references/predict-workflow.md` for the full prediction protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for scope/goal as the Goal. Pass --personas, --rounds, --depth, --chain flags through to Notes.
