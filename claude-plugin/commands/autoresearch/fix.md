---
name: autoresearch:fix
description: Autonomous fix loop — iteratively repairs errors until zero remain. One fix per iteration, atomic, auto-reverted on failure.
argument-hint: "[Target errors description] [--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Fix

Pre-filled Workflow:
```
1. Read context and list all current errors (tests, types, lint, build)
2. Pick the highest-impact error
3. Analyze root cause
4. Implement minimal fix
5. Run full test/build suite to verify fix + no regressions
6. Record fix in context
```

**Default config:**
- Evaluator: on
- Guard: (detected from project — npm test, pytest, etc.)

Load `references/fix-workflow.md` for the full fix protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.
