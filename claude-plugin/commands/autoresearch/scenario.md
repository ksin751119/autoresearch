---
name: autoresearch:scenario
description: "Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario. Use when: \"explore scenarios\", \"generate use cases\", \"what could go wrong\", \"edge cases for\", \"stress test this\"."
argument-hint: "[Scenario description] [--domain TYPE] [--depth LEVEL] [--focus AREA]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Scenario Exploration

Pre-filled Workflow:
```
1. Read context and parse seed scenario — identify actors, goals, preconditions
2. Decompose into 12 exploration dimensions (happy path, error, edge case, abuse, scale, concurrent, temporal, data variation, permission, integration, recovery, state transition)
3. Generate one concrete situation from an unexplored dimension
4. Classify situation — new, variant, duplicate, or out-of-scope
5. Expand kept situations — derive edge cases, what-ifs, failure modes
6. Record scenarios in context with dimension and severity
7. Pick next unexplored dimension for next iteration
```

**Default config:**
- Evaluator: off (scenarios are exploratory, not code changes)

Load `references/scenario-workflow.md` for the full scenario protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for the seed scenario as the Goal. Pass --domain, --depth, --focus flags through to Notes.
