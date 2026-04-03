# Autoresearch Skill Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address remaining autoresearch skill optimization — enrich descriptions with trigger words, trim 3 remaining oversized workflows, and improve SKILL.md reference navigation.

**Architecture:** Same template extraction pattern proven in the initial optimization (security 1001→323, predict 752→353, fix 683→275). Each workflow's output templates and domain-specific reference tables get moved to dedicated files. Descriptions enriched with `Use when:` triggers.

**Tech Stack:** Markdown, YAML frontmatter

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `claude-plugin/skills/autoresearch/SKILL.md` | Modify | Add Reference Map section, enrich description |
| `claude-plugin/commands/autoresearch/debug.md` | Modify | Add trigger phrases to description |
| `claude-plugin/commands/autoresearch/fix.md` | Modify | Add trigger phrases to description |
| `claude-plugin/commands/autoresearch/security.md` | Modify | Add trigger phrases to description |
| `claude-plugin/commands/autoresearch/ship.md` | Modify | Add trigger phrases to description |
| `claude-plugin/commands/autoresearch/scenario.md` | Modify | Add trigger phrases to description |
| `claude-plugin/commands/autoresearch/predict.md` | Modify | Add trigger phrases to description |
| `claude-plugin/commands/autoresearch/learn.md` | Modify | Add trigger phrases to description |
| `claude-plugin/commands/autoresearch/plan.md` | Modify | Add trigger phrases to description |
| `claude-plugin/.../references/debug-workflow.md` | Modify | Trim from 470 to ~300 lines |
| `claude-plugin/.../references/debug-reference-material.md` | Create | Domain checklists, tracing protocols, perf investigation |
| `claude-plugin/.../references/learn-workflow.md` | Modify | Trim from 481 to ~300 lines |
| `claude-plugin/.../references/learn-output-templates.md` | Create | Results TSV, progress report, summary, output dir format |
| `claude-plugin/.../references/ship-workflow.md` | Modify | Trim from 413 to ~280 lines |
| `claude-plugin/.../references/ship-domain-tables.md` | Create | Per-domain dry-run/ship/verify/rollback tables |
| `.claude/skills/autoresearch/` | Overwrite | Final sync from claude-plugin/ |

---

### Task 1: Enrich Main Skill Description

**Files:**
- Modify: `claude-plugin/skills/autoresearch/SKILL.md`

- [ ] **Step 1: Update the frontmatter description**

In `claude-plugin/skills/autoresearch/SKILL.md`, change the frontmatter from:

```yaml
---
name: autoresearch
description: Autonomous Goal-directed Iteration. Loops autonomously with multi-agent team — Research, Dev, Evaluator. Works with ANY task.
---
```

To:

```yaml
---
name: autoresearch
description: "Autonomous Goal-directed Iteration. Loops autonomously with multi-agent team — Research, Dev, Evaluator. Works with ANY task. Use when: (1) iterating autonomously on improvements, (2) running overnight optimization loops, (3) any task needing repeated modify-verify-keep/discard cycles. Triggers: \"iterate autonomously\", \"keep improving\", \"run overnight\", \"autonomous loop\", \"work autonomously\"."
---
```

- [ ] **Step 2: Add Reference Map section**

In `claude-plugin/skills/autoresearch/SKILL.md`, insert the following new section between the existing "## Knowledge System" section and the "## Exit Criteria" section (after line 125, before line 127):

```markdown

## Reference Map

| Category | Files | When to load |
|----------|-------|-------------|
| Agent protocols | coordinator, research, dev, evaluator, pre-dev-gate, post-iteration-reviewer | First iteration of any loop |
| Workflow presets | debug, fix, security, ship, scenario, predict, learn, plan, setup | When specific sub-skill invoked |
| Output templates | security-output, predict-knowledge, learn-output, debug-reference-material, ship-domain-tables | When creating output files |
| Shared patterns | interactive-setup-pattern, core-principles, knowledge-system | As needed during setup or iteration |
| Legacy (v2) | autonomous-loop-protocol, results-logging, ml-metric-examples | Only when v2 inline config detected |
```

- [ ] **Step 3: Verify SKILL.md is under 185 lines**

Run: `wc -l claude-plugin/skills/autoresearch/SKILL.md`
Expected: ~180 lines (was 166 + ~14 new lines).

- [ ] **Step 4: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "feat(SKILL.md): enrich description with triggers, add Reference Map"
```

---

### Task 2: Enrich Sub-skill Command Descriptions

**Files:**
- Modify: `claude-plugin/commands/autoresearch/debug.md`
- Modify: `claude-plugin/commands/autoresearch/fix.md`
- Modify: `claude-plugin/commands/autoresearch/security.md`
- Modify: `claude-plugin/commands/autoresearch/ship.md`
- Modify: `claude-plugin/commands/autoresearch/scenario.md`
- Modify: `claude-plugin/commands/autoresearch/predict.md`
- Modify: `claude-plugin/commands/autoresearch/learn.md`
- Modify: `claude-plugin/commands/autoresearch/plan.md`

Each command .md file has a `description:` field in its YAML frontmatter. Append `Use when:` trigger phrases to each. Trigger phrases are taken from the removed v2 SKILL.md "When to Activate" section.

- [ ] **Step 1: Update debug.md description**

In `claude-plugin/commands/autoresearch/debug.md`, change:

```
description: Autonomous bug-hunting loop — scientific method + autoresearch iteration. Finds ALL bugs, not just one.
```

To:

```
description: "Autonomous bug-hunting loop — scientific method + autoresearch iteration. Finds ALL bugs, not just one. Use when: \"find all bugs\", \"hunt bugs\", \"debug this\", \"why is this failing\", \"investigate\"."
```

- [ ] **Step 2: Update fix.md description**

In `claude-plugin/commands/autoresearch/fix.md`, change:

```
description: Autonomous fix loop — iteratively repairs errors until zero remain. One fix per iteration, atomic, auto-reverted on failure.
```

To:

```
description: "Autonomous fix loop — iteratively repairs errors until zero remain. One fix per iteration, atomic, auto-reverted on failure. Use when: \"fix all errors\", \"make tests pass\", \"fix the build\", \"clean up errors\"."
```

- [ ] **Step 3: Update security.md description**

In `claude-plugin/commands/autoresearch/security.md`, change:

```
description: Autonomous security audit — STRIDE threat model + OWASP Top 10 + red-team with 4 adversarial personas
```

To:

```
description: "Autonomous security audit — STRIDE threat model + OWASP Top 10 + red-team with 4 adversarial personas. Use when: \"security audit\", \"threat model\", \"find vulnerabilities\", \"OWASP\", \"STRIDE\", \"red-team\"."
```

- [ ] **Step 4: Update ship.md description**

In `claude-plugin/commands/autoresearch/ship.md`, change:

```
description: Universal shipping workflow — ship code, content, marketing, sales, research, or anything through structured phases
```

To:

```
description: "Universal shipping workflow — ship code, content, marketing, sales, research, or anything through structured phases. Use when: \"ship it\", \"deploy this\", \"publish this\", \"launch this\", \"release this\", \"push to prod\"."
```

- [ ] **Step 5: Update scenario.md description**

In `claude-plugin/commands/autoresearch/scenario.md`, change:

```
description: Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario
```

To:

```
description: "Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario. Use when: \"explore scenarios\", \"generate use cases\", \"what could go wrong\", \"edge cases for\", \"stress test this\"."
```

- [ ] **Step 6: Update predict.md description**

In `claude-plugin/commands/autoresearch/predict.md`, change:

```
description: Multi-persona swarm prediction — pre-analyze code from multiple expert perspectives using file-based knowledge representation
```

To:

```
description: "Multi-persona swarm prediction — pre-analyze code from multiple expert perspectives using file-based knowledge representation. Use when: \"predict\", \"multi-perspective\", \"swarm analysis\", \"analyze from different angles\"."
```

- [ ] **Step 7: Update learn.md description**

In `claude-plugin/commands/autoresearch/learn.md`, change:

```
description: Autonomous codebase documentation engine — scout, learn, generate/update docs with validation-fix loop
```

To:

```
description: "Autonomous codebase documentation engine — scout, learn, generate/update docs with validation-fix loop. Use when: \"learn this codebase\", \"generate docs\", \"document this project\", \"update docs\", \"docs health\"."
```

- [ ] **Step 8: Update plan.md description**

In `claude-plugin/commands/autoresearch/plan.md`, change:

```
description: Interactive wizard to build Scope, Metric, Direction & Verify from a Goal
```

To:

```
description: "Interactive wizard to build Scope, Metric, Direction & Verify from a Goal. Use when: \"plan an autoresearch run\", \"help me set up autoresearch\", \"configure autoresearch\"."
```

- [ ] **Step 9: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/commands/autoresearch/*.md
git commit -m "feat(commands): enrich sub-skill descriptions with trigger phrases"
```

---

### Task 3: Trim debug-workflow.md — Extract Reference Material

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/debug-workflow.md` (470 lines)
- Create: `claude-plugin/skills/autoresearch/references/debug-reference-material.md`

The debug workflow has ~170 lines of domain-specific checklists (API, Database, Auth, Async, Network bugs), multi-file tracing protocol, performance investigation guide, and 5 Whys template. These are reference material, not core workflow.

- [ ] **Step 1: Read debug-workflow.md fully to identify extract boundaries**

Read the full file to confirm section boundaries. Content to extract starts from "### API Bugs" (around line 300) through "### The 5 Whys" section end (around line 447), plus the "Anti-Patterns" table (around lines 353-366).

- [ ] **Step 2: Create debug-reference-material.md**

Create `claude-plugin/skills/autoresearch/references/debug-reference-material.md` with all extracted content:

```markdown
# Debug Reference Material

Domain-specific debugging checklists, tracing protocols, and investigation techniques. Referenced from `debug-workflow.md`.

## Domain-Specific Debug Checklists

### API Bugs
[Copy the API Bugs section with checklist from debug-workflow.md]

### Database Bugs
[Copy the Database Bugs section with checklist]

### Authentication / Authorization Bugs
[Copy the Auth section with checklist]

### Async / Concurrency Bugs
[Copy the Async section with checklist]

### Network / Integration Bugs
[Copy the Network section with checklist]

## Debug Anti-Patterns

[Copy the "What NOT to Do" anti-patterns table]

## Multi-File Bug Tracing

[Copy the full Multi-File Bug Tracing section including trace map format]

## Performance Bug Investigation

[Copy the full Performance Bug Investigation section including patterns table and checklist]

## The 5 Whys — Root Cause Drill-Down

[Copy the full 5 Whys section including template and example]
```

- [ ] **Step 3: Replace extracted sections in debug-workflow.md**

Replace all the extracted content (from "### API Bugs" through end of "5 Whys" section, and the anti-patterns table) with:

```markdown
## Domain-Specific Reference

For domain-specific debug checklists (API, Database, Auth, Async, Network), anti-patterns, multi-file tracing protocol, performance investigation, and root cause analysis (5 Whys), see `references/debug-reference-material.md`.
```

- [ ] **Step 4: Verify debug-workflow.md is under 320 lines**

Run: `wc -l claude-plugin/skills/autoresearch/references/debug-workflow.md`
Expected: ~300 lines (was 470).

- [ ] **Step 5: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/debug-workflow.md claude-plugin/skills/autoresearch/references/debug-reference-material.md
git commit -m "refactor(debug-workflow): extract reference material, trim from 470 to ~300 lines"
```

---

### Task 4: Trim learn-workflow.md — Extract Output Templates

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/learn-workflow.md` (481 lines)
- Create: `claude-plugin/skills/autoresearch/references/learn-output-templates.md`

The learn workflow has ~100 lines of output format templates (Phase 8 results TSV, progress report, final summary format, output directory structure), anti-patterns table, and chaining patterns.

- [ ] **Step 1: Read learn-workflow.md to confirm extract boundaries**

Content to extract:
- Phase 8 "Results File" TSV format + "Progress Report" format + "Final Summary" format (lines ~364-396)
- Anti-patterns table (lines ~430-441)
- Output directory structure (lines ~443-454)
- Chaining patterns (lines ~456-481)

- [ ] **Step 2: Create learn-output-templates.md**

Create `claude-plugin/skills/autoresearch/references/learn-output-templates.md`:

```markdown
# Learn Output Templates

Output file formats and reference material for /autoresearch:learn. Referenced from `learn-workflow.md`.

## Results TSV Format

[Copy the learn-results.tsv format with header and example rows]

## Progress Report (every 5 iterations)

[Copy the progress report template]

## Final Summary Format

[Copy the summary.md specification]

## Output Directory Structure

[Copy the output directory tree and explanation]

## Anti-Patterns

[Copy the What NOT to Do anti-patterns table]

## Chaining Patterns

[Copy the chaining examples]
```

- [ ] **Step 3: Replace extracted sections in learn-workflow.md**

Replace Phase 8's detailed formats, anti-patterns, output directory, and chaining sections with:

```markdown
## Phase 8: Log — Record Results

Append iteration results to `learn-results.tsv`. Write `summary.md` on completion. See `references/learn-output-templates.md` for TSV format, progress report template, and summary format.

## Output & Reference

For output directory structure, anti-patterns, and chaining patterns, see `references/learn-output-templates.md`.
```

- [ ] **Step 4: Verify learn-workflow.md is under 320 lines**

Run: `wc -l claude-plugin/skills/autoresearch/references/learn-workflow.md`
Expected: ~300 lines (was 481).

- [ ] **Step 5: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/learn-workflow.md claude-plugin/skills/autoresearch/references/learn-output-templates.md
git commit -m "refactor(learn-workflow): extract output templates, trim from 481 to ~300 lines"
```

---

### Task 5: Trim ship-workflow.md — Extract Domain Tables

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/ship-workflow.md` (413 lines)
- Create: `claude-plugin/skills/autoresearch/references/ship-domain-tables.md`

The ship workflow has ~160 lines of per-domain tables (9 shipment types x 4 phases = large tables for dry-run, ship, verify, rollback actions).

- [ ] **Step 1: Read ship-workflow.md to confirm extract boundaries**

Content to extract:
- Phase 5 dry-run action table (lines ~274-284)
- Phase 6 ship action table (lines ~298-309)
- Phase 7 verification table (lines ~322-333) + monitoring code block
- Phase 8 log format + summary template (lines ~344-362)
- Rollback protocol table (lines ~390-406)

- [ ] **Step 2: Create ship-domain-tables.md**

Create `claude-plugin/skills/autoresearch/references/ship-domain-tables.md`:

```markdown
# Ship Domain Tables

Per-domain action tables for each phase of /autoresearch:ship. Referenced from `ship-workflow.md`.

## Dry-Run Actions by Type (Phase 5)

[Copy the full dry-run action table]

## Ship Actions by Type (Phase 6)

[Copy the full ship action table]

## Verification Checks by Type (Phase 7)

[Copy the full verification table]

## Post-Ship Monitoring

[Copy the monitoring code block]

## Log Format (Phase 8)

[Copy the TSV format and summary template]

## Rollback Actions by Type

[Copy the full rollback protocol table including note about non-reversible actions]
```

- [ ] **Step 3: Replace extracted content in ship-workflow.md**

Replace each phase's domain table with a compact version + reference. For example, Phase 5 becomes:

```markdown
## Phase 5: Dry-Run — Simulate Before Shipping

Execute simulation without side effects. See `references/ship-domain-tables.md` for per-type dry-run actions.

**Dry-run gate:**
- Present dry-run results to user
- `--auto` flag: auto-approve if no errors
- Default: ask user "Ready to ship?" before proceeding
- `--dry-run` flag: stop here, don't actually ship

**Output:** `✓ Phase 5: Dry-run complete — [result summary]`
```

Apply same pattern to Phase 6, 7, 8, and Rollback Protocol.

- [ ] **Step 4: Verify ship-workflow.md is under 300 lines**

Run: `wc -l claude-plugin/skills/autoresearch/references/ship-workflow.md`
Expected: ~280 lines (was 413).

- [ ] **Step 5: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/ship-workflow.md claude-plugin/skills/autoresearch/references/ship-domain-tables.md
git commit -m "refactor(ship-workflow): extract domain tables, trim from 413 to ~280 lines"
```

---

### Task 6: Sync .claude/ and Final Verification

**Files:**
- Overwrite: `.claude/skills/autoresearch/` (entire directory)

- [ ] **Step 1: Sync .claude/ from plugin version**

```bash
rm -rf .claude/skills/autoresearch/
cp -r claude-plugin/skills/autoresearch/ .claude/skills/autoresearch/
```

- [ ] **Step 2: Verify sync**

```bash
diff -rq claude-plugin/skills/autoresearch/ .claude/skills/autoresearch/
```
Expected: No differences.

- [ ] **Step 3: Verify all reference file sizes**

```bash
wc -l claude-plugin/skills/autoresearch/references/*.md | sort -rn
```

Expected targets:
- All workflow files under 350 lines
- No file over 400 lines except template/reference files
- Total reference lines significantly reduced from 5241

- [ ] **Step 4: Verify SKILL.md under 185 lines with valid frontmatter**

```bash
head -4 claude-plugin/skills/autoresearch/SKILL.md
wc -l claude-plugin/skills/autoresearch/SKILL.md
```

- [ ] **Step 5: Commit sync**

```bash
cd /home/ubuntu/DEV/autoresearch
git add .claude/skills/autoresearch/
git commit -m "sync(.claude): mirror autoresearch skill polish changes"
```
