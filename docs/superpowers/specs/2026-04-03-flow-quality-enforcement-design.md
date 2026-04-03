# Flow Quality Enforcement Design

Date: 2026-04-03
Status: Approved

## Problem Statement

Autoresearch v3 的 3-layer enforcement 架構在機械性合規（flow-check.sh）上有效，但品質把關層（Pre-Dev Gate、Evaluator）存在系統性弱點：

1. **Pre-Dev Gate scope 太窄** — 只檢查 workflow alignment + notes pattern，永遠 PASS
2. **Evaluator 判斷失準** — 無 severity 分級，缺乏 domain context，false positive/negative 頻繁
3. **Root cause 分析不夠深** — 失敗後 Coordinator 跳過 Research 自行分析，confirmation bias 導致方向錯誤
4. **Auto-resolve 粒度太粗** — Pre-Dev Gate 的 BLOCK 被當成互動式 gate 跳過

## Design Decisions

- **Approach:** Protocol + scripts 一起改（方案 B）
- **Mandatory re-dispatch enforcement:** 雙層 — Pre-Dev Gate 即時攔截 + flow-check.sh 事後強制（方案 C）
- **Evaluator domain context:** 傳 knowledge.md + context.md（方案 B）

## Changes

### 1. Pre-Dev Gate Scope Expansion

**Files:** `references/pre-dev-gate-protocol.md`, `references/coordinator-protocol.md`

移除 "Don't read files or run commands" 限制，改為可讀取 Coordinator 提供的 context。

#### New Input Fields

| Field | Type | Description |
|-------|------|-------------|
| `previous_outcome` | KEEP / DISCARD / REWORK / null | 上一輪 outcome，首輪為 null |
| `research_summary` | string / null | 本輪 Research Agent 分析摘要 |

#### New Check: Research Evidence Quality (BLOCK-level)

- `previous_outcome` 是 DISCARD 或 REWORK 且本輪無 Research dispatch → **BLOCK** (type: `missing-research-after-failure`)
- 有 Research 但 summary 缺乏具體證據（無數據、無 log 引用、無 file reference） → **WARNING**

#### Output Format Update

```
BLOCK
- Type: missing-research-after-failure
- Reason: 上一輪 DISCARD，本輪未 dispatch Research
- Correct action: dispatch Research Agent 分析失敗原因
```

### 2. Evaluator Enhancement

**Files:** `references/evaluator-protocol.md`, `references/coordinator-protocol.md`

#### New Input Fields

| Field | Type | Description |
|-------|------|-------------|
| `context_md` | string | `.autoresearch/context.md` 內容 |
| `knowledge_md` | string | `.autoresearch/knowledge.md` 內容 |

#### Output Format Update

```json
{
  "verdict": "pass | fail",
  "severity": "critical | major | minor",
  "severity_rationale": "為什麼是這個等級 — 必須引用具體影響",
  "critique": "...",
  "suggestions": ["..."],
  "risk_flags": ["direction-mismatch", "repeating-failed-approach"]
}
```

#### Severity Guidelines

| Level | Definition | Can trigger fail? |
|-------|-----------|-------------------|
| `critical` | Production 一定會出問題，或違反 Notes 約束 | Yes |
| `major` | 邏輯錯誤但非必然觸發，或跟 knowledge.md 已知發現矛盾 | Yes |
| `minor` | Edge case、效能、可讀性 | No — minor MUST NOT trigger fail |

#### New risk_flag Types

| Flag | Trigger |
|------|---------|
| `direction-mismatch` | Dev 修改方向跟 Research 結論不一致 |
| `repeating-failed-approach` | context.md 記錄此方向已失敗過 |

#### Rule #3 Strengthening

> 如果 context.md 或 knowledge.md 顯示類似方向已經失敗過，MUST verdict fail 並加 `repeating-failed-approach` flag。如果 Dev 實作方向跟 Research 結論明顯偏離，MUST 加 `direction-mismatch` flag。

#### Decision Logic Adjustment (coordinator-protocol.md)

- `fail` + `critical` or `major` → REWORK（現有邏輯）
- `fail` + `minor` → 不應發生（minor 不能 fail），若發生視為 KEEP + warning

### 3. Mandatory Re-dispatch Enforcement (Dual Layer)

**Files:** `scripts/flow-check.sh`, `scripts/stop-hook.sh` (state file), `references/coordinator-protocol.md`, `references/pre-dev-gate-protocol.md`

#### Layer 1: Pre-Dev Gate (Immediate)

Already covered in section 1 — `missing-research-after-failure` BLOCK.

#### Layer 2: flow-check.sh (Post-hoc)

New check #9 in `iteration-audit`:

```
Check 9: Research after failure
Condition: previous_outcome is DISCARD or REWORK
           AND current iteration has commits (= Dev dispatched)
Check: transcript contains Research dispatch keywords ("Research" AND ("dispatch" OR "spawn" OR "Agent"))
Fail: BLOCK exit with "上一輪失敗後必須 dispatch Research 再進行 Dev"
```

#### State File Update

New field in `autoresearch-loop.local.md` frontmatter:

```yaml
previous_outcome: null  # KEEP | DISCARD | REWORK | null
```

Written by stop-hook at end of each iteration, parsed from transcript (same pattern as existing `workflow_step` parsing).

#### Coordinator Protocol Addition

New section "When Research MUST Be Re-dispatched":

| Condition | Enforcement | Level |
|-----------|-------------|-------|
| 上一輪 DISCARD 或 REWORK | Script (flow-check.sh) + Pre-Dev Gate | Hard |
| verify/guard 報出新型態錯誤 | Protocol 指引 (Coordinator 判斷) | Soft |
| 連續 2 輪無 KEEP | Protocol 指引 (Coordinator 判斷) | Soft |

Only condition 1 has script enforcement. Conditions 2-3 require semantic judgment, not suitable for script checks.

### 4. Auto-resolve vs BLOCK Distinction

**Files:** `references/coordinator-protocol.md`

Rewrite Superpowers Integration section:

#### Auto-resolve Scope

| Category | Auto-resolve? | Reason |
|----------|--------------|--------|
| brainstorming 方案選擇 | Yes | 人類偏好選擇 |
| writing-plans plan approval | Yes | 人類偏好選擇 |
| executing-plans 進度確認 | Yes | 人類偏好選擇 |
| systematic-debugging 方向選擇 | Yes | 人類偏好選擇 |
| Pre-Dev Gate BLOCK | **No** | 品質/流程 gate |
| Post-iteration Review FAIL | **No** | 品質/流程 gate |
| Evaluator fail verdict | **No** | 品質/流程 gate |

Principle: auto-resolve 跳過「人類偏好選擇」，不跳過「品質/流程 gate」。

No script changes needed — BLOCK/FAIL execution already enforced by flow-check.sh.

## Priority

| Priority | Change | Impact |
|----------|--------|--------|
| P0 | #3 Mandatory re-dispatch | 防止最嚴重失敗模式（方向錯誤浪費多輪 iteration） |
| P1 | #2 Evaluator severity + domain context | 減少 false positive/negative |
| P1 | #4 Auto-resolve vs BLOCK 區分 | 防止流程強制被繞過 |
| P2 | #1 Pre-Dev Gate scope expansion | 長期品質提升 |

## Files Changed Summary

| File | Changes |
|------|---------|
| `references/pre-dev-gate-protocol.md` | New inputs, remove read restriction, add research-after-failure check |
| `references/evaluator-protocol.md` | New inputs, severity system, new risk flags, strengthen rule #3 |
| `references/coordinator-protocol.md` | Updated dispatch inputs, mandatory re-dispatch section, auto-resolve rewrite, decision logic adjustment |
| `scripts/flow-check.sh` | New check #9: research-after-failure |
| `scripts/stop-hook.sh` | Parse and write `previous_outcome` to state file |
