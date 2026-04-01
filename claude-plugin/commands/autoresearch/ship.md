---
name: autoresearch:ship
description: Universal shipping workflow — ship code, content, marketing, sales, research, or anything through structured phases
argument-hint: "[What to ship] [--type TYPE] [--dry-run] [--auto] [--monitor N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Ship

Pre-filled Workflow:
```
1. Read context and identify what is being shipped
2. Assess current readiness — inventory gaps and blockers
3. Generate domain-specific pre-ship checklist
4. Fix failing checklist items (one per iteration)
5. Dry-run the ship action without side effects
6. Execute the actual delivery (merge, deploy, publish)
7. Post-ship health check — verify it landed
8. Record shipment in context
```

**Default config:**
- Evaluator: off (shipping checklist is mechanical verification)

Load `references/ship-workflow.md` for the full shipping protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for what to ship as the Goal. Pass --type, --dry-run, --auto, --monitor flags through to Notes.
