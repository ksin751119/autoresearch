---
name: autoresearch:learn
description: Autonomous codebase documentation engine — scout, learn, generate/update docs with validation-fix loop
argument-hint: "[--mode MODE] [--scope GLOB] [--depth LEVEL] [--file NAME]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Codebase Learning

Pre-filled Workflow:
```
1. Read context and scout codebase structure (scale-aware, monorepo detection)
2. Classify project type, detect tech stack, measure doc staleness
3. Discover existing docs (docs/*.md), run gap analysis
4. Generate or update one doc per iteration with full context
5. Validate — check code refs, links, completeness, size compliance
6. If validation fails — re-generate with feedback (max 3 retries)
7. Finalize — inventory check, git diff summary
8. Record results in context
```

**Default config:**
- Evaluator: off (validation-fix loop provides mechanical verification)

Load `references/learn-workflow.md` for the full learning protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Auto-detect mode (init/update/check/summarize) based on docs/ state. Parse $ARGUMENTS flags through to Notes.
