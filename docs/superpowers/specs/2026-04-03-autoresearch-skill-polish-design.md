# Autoresearch Skill Polish — Design Spec

**Goal:** Address remaining optimization opportunities in the autoresearch skill after the initial optimization pass.

## Context

The initial optimization (10 tasks) reduced reference files from 6481→5241 lines, fixed shell injection, synced v2→v3, and applied progressive disclosure. Three areas remain:

1. Descriptions lack trigger words (main skill + sub-skills)
2. learn/debug/ship workflows still 413-481 lines (approaching 500-line limit)
3. SKILL.md reference navigation could be clearer

## Change 1: Enrich Description Trigger Words

**Main skill** (`claude-plugin/skills/autoresearch/SKILL.md` frontmatter):
- Add `Use when:` triggers and natural language trigger phrases
- Keep under 3 lines

**Sub-skill commands** (`claude-plugin/commands/autoresearch/*.md` frontmatter):
- Add `Use when:` with natural language trigger phrases to each sub-skill description
- Phrases taken from the v2 SKILL.md "When to Activate" section (now removed)

Files affected: `SKILL.md`, `commands/autoresearch/{debug,fix,security,ship,scenario,predict,learn,plan}.md`

## Change 2: Trim learn/debug/ship Workflows

Apply the same template extraction pattern used successfully on security (1001→323), predict (752→353), fix (683→275).

| File | Current | Target | Extract to |
|------|---------|--------|-----------|
| learn-workflow.md | 481 | ~300 | learn-output-templates.md |
| debug-workflow.md | 470 | ~300 | debug-output-templates.md |
| ship-workflow.md | 413 | ~280 | ship-output-templates.md |

Extract: output file templates, report formats, TSV headers, checklist templates.

## Change 3: Add Reference Map to SKILL.md

Add a categorized reference navigation table between "Agent Team" and "The Loop" sections. Groups: Agent protocols, Workflow presets, Output templates, Core docs, Legacy (v2). Each row specifies when to load.

## Change 4: Sync .claude/ after all changes

Mirror claude-plugin/skills/autoresearch/ to .claude/skills/autoresearch/ (same as initial optimization Task 9).
