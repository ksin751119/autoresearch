# Autoresearch Skill Polish Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 autoresearch skill 優化第二階段：7 個大型 reference 文件加 TOC、learn-workflow.md 裁剪至 ~320 行、8 個 sub-skill command descriptions 加 trigger phrases。

**Architecture:** 純 Markdown 變更。Task 1-3 互不依賴可並行。Task 4（sync）依賴 1-3。所有文件修改在 `claude-plugin/skills/autoresearch/references/` 和 `claude-plugin/commands/autoresearch/`。

**Tech Stack:** Markdown

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `claude-plugin/skills/autoresearch/references/scenario-workflow.md` | Modify | 加 TOC |
| `claude-plugin/skills/autoresearch/references/predict-workflow.md` | Modify | 加 TOC |
| `claude-plugin/skills/autoresearch/references/security-workflow.md` | Modify | 加 TOC |
| `claude-plugin/skills/autoresearch/references/debug-workflow.md` | Modify | 加 TOC |
| `claude-plugin/skills/autoresearch/references/fix-workflow.md` | Modify | 加 TOC |
| `claude-plugin/skills/autoresearch/references/plan-workflow.md` | Modify | 加 TOC |
| `claude-plugin/skills/autoresearch/references/setup-workflow.md` | Modify | 加 TOC |
| `claude-plugin/skills/autoresearch/references/learn-workflow.md` | Modify | 加 TOC + 提取 Phase 3 doc tables 至 learn-output-templates.md |
| `claude-plugin/skills/autoresearch/references/learn-output-templates.md` | Modify | 接收 Phase 3 doc tables |
| `claude-plugin/commands/autoresearch/debug.md` | Modify | 加 trigger phrases |
| `claude-plugin/commands/autoresearch/fix.md` | Modify | 加 trigger phrases |
| `claude-plugin/commands/autoresearch/security.md` | Modify | 加 trigger phrases |
| `claude-plugin/commands/autoresearch/ship.md` | Modify | 加 trigger phrases |
| `claude-plugin/commands/autoresearch/scenario.md` | Modify | 加 trigger phrases |
| `claude-plugin/commands/autoresearch/predict.md` | Modify | 加 trigger phrases |
| `claude-plugin/commands/autoresearch/learn.md` | Modify | 加 trigger phrases |
| `claude-plugin/commands/autoresearch/plan.md` | Modify | 加 trigger phrases |
| `.claude/skills/autoresearch/` | Sync | 鏡像 claude-plugin/ |

---

### Task 1: 7 個 reference 文件加 TOC

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/scenario-workflow.md:1`
- Modify: `claude-plugin/skills/autoresearch/references/predict-workflow.md:1`
- Modify: `claude-plugin/skills/autoresearch/references/security-workflow.md:1`
- Modify: `claude-plugin/skills/autoresearch/references/debug-workflow.md:1`
- Modify: `claude-plugin/skills/autoresearch/references/fix-workflow.md:1`
- Modify: `claude-plugin/skills/autoresearch/references/plan-workflow.md:1`
- Modify: `claude-plugin/skills/autoresearch/references/setup-workflow.md:1`

每個文件在 `# Title` 行後、第一個 `## Section` 前，插入一個 `## Contents` 段落，列出所有 `## ` H2 sections 作為 anchor links。

- [ ] **Step 1: 為 scenario-workflow.md 加 TOC**

在第 1 行 `# Scenario Workflow — /autoresearch:scenario` 後面（第 2 行之後），插入：

```markdown

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [PREREQUISITE: Interactive Setup](#prerequisite-interactive-setup-when-invoked-without-scenario)
- [Architecture](#architecture)
- [Inline Context Parsing Rules](#inline-context-parsing-rules)
- [Cancel & Interruption Handling](#cancel--interruption-handling)
- [Phase 1: Seed](#phase-1-seed--capture--analyze-scenario)
- [Phase 2: Decompose](#phase-2-decompose--break-into-exploration-dimensions)
- [Phase 3: Generate](#phase-3-generate--create-one-new-situation)
- [Phase 4: Classify](#phase-4-classify--evaluate--deduplicate)
- [Phase 5: Expand](#phase-5-expand--edge-cases--stress-tests)
- [Phase 6: Log](#phase-6-log--record-everything)
- [Phase 7: Repeat](#phase-7-repeat--next-exploration-vector)
- [Flags](#flags)
- [Composite Metric](#composite-metric)
```

- [ ] **Step 2: 為 predict-workflow.md 加 TOC**

在第 1 行 `# Predict Workflow — /autoresearch:predict` 後面，插入：

```markdown

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [PREREQUISITE: Interactive Setup](#prerequisite-interactive-setup-when-invoked-without-flags)
- [Inline Context Parsing Rules](#inline-context-parsing-rules)
- [Architecture](#architecture)
- [Phase 1: Setup](#phase-1-setup--configuration)
- [Phase 2: Reconnaissance](#phase-2-reconnaissance--build-knowledge-files)
- [Phase 3: Persona Generation](#phase-3-persona-generation)
- [Phase 4: Independent Analysis](#phase-4-independent-analysis)
- [Phase 5: Debate](#phase-5-debate--structured-cross-examination)
- [Phase 6: Consensus](#phase-6-consensus--synthesizer-aggregation)
- [Phase 7: Report](#phase-7-report--generate-output-files)
- [Phase 8: Handoff](#phase-8-handoff--chain-to-downstream)
- [Safety](#safety)
- [Flags](#flags)
```

- [ ] **Step 3: 為 security-workflow.md 加 TOC**

在第 1 行 `# Security Workflow — /autoresearch:security` 後面，插入：

```markdown

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [PREREQUISITE: Interactive Setup](#prerequisite-interactive-setup)
- [Architecture](#architecture)
- [Setup Phase](#setup-phase--threat-model-generation)
- [The Security Loop](#the-security-loop)
- [OWASP Checks Reference](#owasp-checks-reference)
- [Red-Team Adversarial Lenses](#red-team-adversarial-lenses)
- [Strix-Inspired Patterns](#strix-inspired-patterns)
- [Metric for the Loop](#metric-for-the-loop)
- [Flags & Modes](#flags--modes)
- [Error Recovery](#error-recovery)
- [Anti-Patterns](#anti-patterns)
- [Report Output](#report-output--structured-folder)
```

- [ ] **Step 4: 為 debug-workflow.md 加 TOC**

在第 1 行 `# Debug Workflow — /autoresearch:debug` 後面，插入：

```markdown

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [PREREQUISITE: Interactive Setup](#prerequisite-interactive-setup-when-invoked-without-flags)
- [Architecture](#architecture)
- [Phase 1: Gather](#phase-1-gather--symptoms--context)
- [Phase 2: Reconnaissance](#phase-2-reconnaissance--map-the-error-surface)
- [Phase 3: Hypothesize](#phase-3-hypothesize--form-falsifiable-hypothesis)
- [Phase 4: Test](#phase-4-test--run-experiment)
- [Phase 5: Classify](#phase-5-classify--what-did-we-learn)
- [Phase 6: Log](#phase-6-log--record-everything)
- [Phase 7: Repeat](#phase-7-repeat--next-investigation)
- [Flags](#flags)
- [Composite Metric](#composite-metric)
- [Investigation Techniques Reference](#investigation-techniques-reference)
- [Common Bug Patterns by Language](#common-bug-patterns-by-language)
```

- [ ] **Step 5: 為 fix-workflow.md 加 TOC**

在第 1 行 `# Fix Workflow — /autoresearch:fix` 後面，插入：

```markdown

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [Interactive Setup](#interactive-setup)
- [Architecture](#architecture)
- [Phase 1: Detect](#phase-1-detect--whats-broken)
- [Phase 2: Prioritize](#phase-2-prioritize--fix-order)
- [Phase 3: Fix ONE Thing](#phase-3-fix-one-thing--atomic-change)
- [Phase 4: Commit](#phase-4-commit--before-verification)
- [Phase 5: Verify](#phase-5-verify--did-it-help)
- [Phase 6: Guard](#phase-6-guard--did-anything-else-break)
- [Phase 7: Decide](#phase-7-decide--keep-revert-or-rework)
- [Phase 8: Log & Repeat](#phase-8-log--repeat)
- [Flags](#flags)
- [State Machine](#state-machine)
- [Anti-Patterns](#anti-patterns--never-do-these)
```

- [ ] **Step 6: 為 plan-workflow.md 加 TOC**

在第 1 行標題後面，插入：

```markdown

## Contents

- [Trigger](#trigger)
- [Workflow](#workflow)
- [Autoresearch Configuration](#autoresearch-configuration)
- [Metric Suggestion Database](#metric-suggestion-database)
- [Error Recovery](#error-recovery)
- [Anti-Patterns](#anti-patterns)
```

- [ ] **Step 7: 為 setup-workflow.md 加 TOC**

在第 1 行 `# Setup Wizard Protocol` 後面，插入：

```markdown

## Contents

- [Input](#input)
- [Question Flow](#question-flow)
- [After All Questions](#after-all-questions)
```

- [ ] **Step 8: 確認所有文件都有 TOC**

```bash
cd /home/ubuntu/DEV/autoresearch
for f in scenario-workflow predict-workflow security-workflow debug-workflow fix-workflow plan-workflow setup-workflow; do
  count=$(grep -c "^## Contents" "claude-plugin/skills/autoresearch/references/${f}.md")
  echo "$f: TOC=$count"
done
```

預期：全部 `TOC=1`。

- [ ] **Step 9: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/scenario-workflow.md \
        claude-plugin/skills/autoresearch/references/predict-workflow.md \
        claude-plugin/skills/autoresearch/references/security-workflow.md \
        claude-plugin/skills/autoresearch/references/debug-workflow.md \
        claude-plugin/skills/autoresearch/references/fix-workflow.md \
        claude-plugin/skills/autoresearch/references/plan-workflow.md \
        claude-plugin/skills/autoresearch/references/setup-workflow.md
git commit -m "docs: add TOC to 7 reference workflow files (>100 lines)"
```

---

### Task 2: learn-workflow.md 裁剪 — 提取 Phase 3 doc tables + 加 TOC

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/learn-workflow.md`
- Modify: `claude-plugin/skills/autoresearch/references/learn-output-templates.md`

learn-workflow.md 目前 402 行，目標 ~320。Phase 3 "Map" 是最大段落（74 行），其中 Init Mode 的 doc tables（always-create + conditional-create lists）和 Update Mode 的 diff-based doc targeting mapping 是純參考資料（不影響 workflow 邏輯）。提取到 learn-output-templates.md。

- [ ] **Step 1: 在 learn-output-templates.md 加入 Phase 3 reference material**

在 `claude-plugin/skills/autoresearch/references/learn-output-templates.md` 的 `## Phase 8: Results File` 段落前面（即第 4 行之後），插入新的 section：

```markdown
## Phase 3: Init Mode — Doc File Catalog

**Always create:**
- `docs/project-overview-pdr.md` — Project overview and PDR
- `docs/codebase-summary.md` — Codebase summary with file inventory
- `docs/code-standards.md` — Codebase structure and code standards
- `docs/system-architecture.md` — System architecture
- `README.md` at root (create or update, max 300 lines)

**Conditional creation (based on project signals from Phase 2):**
- `docs/deployment-guide.md` — if Dockerfile, CI config (`.github/workflows`, `.gitlab-ci.yml`), deploy scripts, or cloud config detected
- `docs/design-guidelines.md` — if UI components, CSS/style files, or frontend framework detected
- `docs/project-roadmap.md` — if project has milestones, issues, or TODO tracking
- `docs/api-reference.md` — if API routes, controllers, resolvers, or OpenAPI/Swagger specs detected. Include endpoint catalog with method, path, description, request/response shapes
- `docs/testing-guide.md` — if test directories (`tests/`, `__tests__/`, `spec/`), test config (jest.config, vitest.config, pytest.ini), or CI test steps detected. Document test strategy, how to run tests, coverage expectations, fixture patterns
- `docs/configuration-guide.md` — if `.env.example`, `config/` directory, feature flags, or environment-specific configs detected. Document all env vars, config keys, and their purpose
- `docs/changelog.md` — generate from `git log --oneline --no-merges -50` using conventional commit parsing. Group by type (feat, fix, docs, refactor). Only on init; update mode appends new entries

## Phase 3: Update Mode — Diff-Based Doc Targeting

Map changed source files to affected docs:
- `src/api/**` changes → prioritize `api-reference.md`, `system-architecture.md`
- `src/components/**` changes → prioritize `design-guidelines.md`
- `tests/**` changes → prioritize `testing-guide.md`
- `package.json` / dependency changes → prioritize `codebase-summary.md` (dependency section)
- Config file changes → prioritize `configuration-guide.md`
- New files in `src/` → prioritize `code-standards.md`, `system-architecture.md`

This is advisory, not exclusive — all docs still get reviewed, mapped ones get deeper updates.
```

- [ ] **Step 2: 在 learn-workflow.md Phase 3 Init Mode 替換 doc tables**

在 `claude-plugin/skills/autoresearch/references/learn-workflow.md` 找到 Phase 3 的 Init Mode 區塊，將以下內容（從 `**Always create:**` 到 conditional-create 最後一項 `docs/changelog.md` 行）：

```markdown
**Always create:**
- `docs/project-overview-pdr.md` — Project overview and PDR
- `docs/codebase-summary.md` — Codebase summary with file inventory
- `docs/code-standards.md` — Codebase structure and code standards
- `docs/system-architecture.md` — System architecture
- `README.md` at root (create or update, max 300 lines)

**Conditional creation (based on project signals from Phase 2):**
- `docs/deployment-guide.md` — if Dockerfile, CI config (`.github/workflows`, `.gitlab-ci.yml`), deploy scripts, or cloud config detected
- `docs/design-guidelines.md` — if UI components, CSS/style files, or frontend framework detected
- `docs/project-roadmap.md` — if project has milestones, issues, or TODO tracking
- `docs/api-reference.md` — if API routes, controllers, resolvers, or OpenAPI/Swagger specs detected. Include endpoint catalog with method, path, description, request/response shapes
- `docs/testing-guide.md` — if test directories (`tests/`, `__tests__/`, `spec/`), test config (jest.config, vitest.config, pytest.ini), or CI test steps detected. Document test strategy, how to run tests, coverage expectations, fixture patterns
- `docs/configuration-guide.md` — if `.env.example`, `config/` directory, feature flags, or environment-specific configs detected. Document all env vars, config keys, and their purpose
- `docs/changelog.md` — generate from `git log --oneline --no-merges -50` using conventional commit parsing. Group by type (feat, fix, docs, refactor). Only on init; update mode appends new entries
```

替換為：

```markdown
Create 5 core docs (always) + conditional docs based on project signals. See `references/learn-output-templates.md` "Phase 3: Init Mode — Doc File Catalog" for the full list and detection rules.
```

- [ ] **Step 3: 在 learn-workflow.md Phase 3 Update Mode 替換 diff-based targeting table**

找到 Update Mode 中的 diff-based doc targeting 區塊（從 `**Diff-based doc targeting (update mode optimization):**` 到 `- This is advisory, not exclusive` 行），替換為：

```markdown
**Diff-based doc targeting:** Map changed source files to affected docs. See `references/learn-output-templates.md` "Phase 3: Update Mode — Diff-Based Doc Targeting" for the mapping table.
```

- [ ] **Step 4: 在 learn-workflow.md 第 1 行標題後加 TOC**

在 `# Learn Workflow — /autoresearch:learn` 後面插入：

```markdown

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [PREREQUISITE: Interactive Setup](#prerequisite-interactive-setup-when-invoked-without-flags)
- [Architecture](#architecture)
- [Phase 1: Scout](#phase-1-scout--parallel-codebase-reconnaissance)
- [Phase 2: Analyze](#phase-2-analyze--structure-detection--classification)
- [Phase 3: Map](#phase-3-map--dynamic-doc-discovery--gap-analysis)
- [Phase 4: Generate](#phase-4-generate--spawn-docs-manager-agent)
- [Phase 5: Validate](#phase-5-validate--mechanical-verification)
- [Phase 6: Fix](#phase-6-fix--validation-fix-loop-autoresearch-core)
- [Phase 7: Finalize](#phase-7-finalize--inventory--summary)
- [Phase 8: Log](#phase-8-log--record-results)
- [Flags](#flags)
- [Composite Metric](#composite-metric)
- [Output & Reference](#output--reference)
```

- [ ] **Step 5: 確認 learn-workflow.md 行數下降**

```bash
wc -l claude-plugin/skills/autoresearch/references/learn-workflow.md
```

預期：~340 行以下（402 - ~15 always-create - ~8 conditional - ~10 diff-targeting + ~20 TOC = ~389，再加上替換語句縮減 ≈ ~350）。

- [ ] **Step 6: 確認 learn-output-templates.md 包含新 sections**

```bash
grep "^## Phase 3" claude-plugin/skills/autoresearch/references/learn-output-templates.md
```

預期：2 行（Init Mode + Update Mode）。

- [ ] **Step 7: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/learn-workflow.md \
        claude-plugin/skills/autoresearch/references/learn-output-templates.md
git commit -m "refactor(learn-workflow): extract Phase 3 doc tables, add TOC, trim to ~340 lines"
```

---

### Task 3: 8 個 sub-skill command descriptions 加 trigger phrases

**Files:**
- Modify: `claude-plugin/commands/autoresearch/debug.md`
- Modify: `claude-plugin/commands/autoresearch/fix.md`
- Modify: `claude-plugin/commands/autoresearch/security.md`
- Modify: `claude-plugin/commands/autoresearch/ship.md`
- Modify: `claude-plugin/commands/autoresearch/scenario.md`
- Modify: `claude-plugin/commands/autoresearch/predict.md`
- Modify: `claude-plugin/commands/autoresearch/learn.md`
- Modify: `claude-plugin/commands/autoresearch/plan.md`

每個 command `.md` 文件的 YAML frontmatter `description:` 後面追加 `Use when:` trigger phrases。

- [ ] **Step 1: 更新 debug.md**

將：
```
description: Autonomous bug-hunting loop — scientific method + autoresearch iteration. Finds ALL bugs, not just one.
```
改為：
```
description: "Autonomous bug-hunting loop — scientific method + autoresearch iteration. Finds ALL bugs, not just one. Use when: \"find all bugs\", \"hunt bugs\", \"debug this\", \"why is this failing\", \"investigate\"."
```

- [ ] **Step 2: 更新 fix.md**

將：
```
description: Autonomous fix loop — iteratively repairs errors until zero remain. One fix per iteration, atomic, auto-reverted on failure.
```
改為：
```
description: "Autonomous fix loop — iteratively repairs errors until zero remain. One fix per iteration, atomic, auto-reverted on failure. Use when: \"fix all errors\", \"make tests pass\", \"fix the build\", \"clean up errors\"."
```

- [ ] **Step 3: 更新 security.md**

將：
```
description: Autonomous security audit — STRIDE threat model + OWASP Top 10 + red-team with 4 adversarial personas
```
改為：
```
description: "Autonomous security audit — STRIDE threat model + OWASP Top 10 + red-team with 4 adversarial personas. Use when: \"security audit\", \"threat model\", \"find vulnerabilities\", \"OWASP\", \"STRIDE\", \"red-team\"."
```

- [ ] **Step 4: 更新 ship.md**

將：
```
description: Universal shipping workflow — ship code, content, marketing, sales, research, or anything through structured 8-phase workflow
```
改為：
```
description: "Universal shipping workflow — ship code, content, marketing, sales, research, or anything through structured phases. Use when: \"ship it\", \"deploy this\", \"publish\", \"launch\", \"release\", \"push to prod\"."
```

- [ ] **Step 5: 更新 scenario.md**

將：
```
description: Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario using autonomous iteration.
```
改為：
```
description: "Scenario-driven use case generator — explores situations, edge cases, and derivative scenarios from a seed scenario. Use when: \"explore scenarios\", \"generate use cases\", \"what could go wrong\", \"edge cases\", \"stress test\"."
```

- [ ] **Step 6: 更新 predict.md**

將：
```
description: Multi-persona swarm prediction — pre-analyze code from multiple expert perspectives using file-based knowledge representation. Zero external dependencies.
```
改為：
```
description: "Multi-persona swarm prediction — pre-analyze code from multiple expert perspectives using file-based knowledge representation. Use when: \"predict\", \"multi-perspective\", \"swarm analysis\", \"analyze from different angles\"."
```

- [ ] **Step 7: 更新 learn.md**

將：
```
description: Autonomous codebase documentation engine — scout, learn, generate/update docs with validation-fix loop
```
改為：
```
description: "Autonomous codebase documentation engine — scout, learn, generate/update docs with validation-fix loop. Use when: \"learn this codebase\", \"generate docs\", \"document this project\", \"update docs\", \"docs health\"."
```

- [ ] **Step 8: 更新 plan.md**

將：
```
description: Interactive wizard to build Scope, Metric, Direction & Verify from a Goal
```
改為：
```
description: "Interactive wizard to build Scope, Metric, Direction & Verify from a Goal. Use when: \"plan an autoresearch run\", \"help me set up autoresearch\", \"configure autoresearch\"."
```

- [ ] **Step 9: 確認所有 descriptions 都有 Use when**

```bash
cd /home/ubuntu/DEV/autoresearch
for f in debug fix security ship scenario predict learn plan; do
  has=$(grep -c "Use when:" "claude-plugin/commands/autoresearch/${f}.md")
  echo "$f: Use when=$has"
done
```

預期：全部 `Use when=1`。

- [ ] **Step 10: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/commands/autoresearch/*.md
git commit -m "feat(commands): enrich sub-skill descriptions with trigger phrases"
```

---

### Task 4: 同步 .claude/skills/autoresearch/ + .claude/commands/autoresearch/ 並驗證

**Files:**
- Sync: `.claude/skills/autoresearch/` ← `claude-plugin/skills/autoresearch/`
- Sync: `.claude/commands/autoresearch/` ← `claude-plugin/commands/autoresearch/`

- [ ] **Step 1: 同步 skills**

```bash
cd /home/ubuntu/DEV/autoresearch
rm -rf .claude/skills/autoresearch/
cp -r claude-plugin/skills/autoresearch/ .claude/skills/autoresearch/
```

- [ ] **Step 2: 同步 commands**

```bash
cd /home/ubuntu/DEV/autoresearch
rm -rf .claude/commands/autoresearch/
cp -r claude-plugin/commands/autoresearch/ .claude/commands/autoresearch/
```

- [ ] **Step 3: 確認同步無差異**

```bash
diff -rq claude-plugin/skills/autoresearch/ .claude/skills/autoresearch/
diff -rq claude-plugin/commands/autoresearch/ .claude/commands/autoresearch/
```

預期：兩個 diff 都無輸出。

- [ ] **Step 4: 全面驗證**

```bash
cd /home/ubuntu/DEV/autoresearch

echo "=== TOC check ==="
for f in scenario-workflow predict-workflow security-workflow debug-workflow fix-workflow plan-workflow setup-workflow learn-workflow; do
  count=$(grep -c "^## Contents" "claude-plugin/skills/autoresearch/references/${f}.md")
  echo "$f: TOC=$count"
done

echo ""
echo "=== learn-workflow line count ==="
wc -l claude-plugin/skills/autoresearch/references/learn-workflow.md

echo ""
echo "=== Command trigger phrases ==="
for f in debug fix security ship scenario predict learn plan; do
  has=$(grep -c "Use when:" "claude-plugin/commands/autoresearch/${f}.md")
  echo "$f: Use when=$has"
done
```

預期：全部 TOC=1，learn-workflow < 360 行，全部 Use when=1。

- [ ] **Step 5: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add .claude/skills/autoresearch/ .claude/commands/autoresearch/
git commit -m "sync(.claude): mirror skill polish phase 2 — TOC, learn trim, trigger phrases"
```
