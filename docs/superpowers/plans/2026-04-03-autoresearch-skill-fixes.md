# Autoresearch Skill Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修復 autoresearch skill 中 5 個已確認問題：刪除 v2 legacy 文件、補齊 context.md 格式缺口、修正 plugin 路徑 bug、清除 core-principles.md v2 殘留語法、強化 flow-check.sh check #9 正則。

**Architecture:** 純文件與腳本層變更，無新增抽象。每個 task 獨立，互無依賴。最後一個 task 統一同步 `.claude/skills/autoresearch/`（與 `claude-plugin/skills/autoresearch/` 鏡像）。

**Tech Stack:** Markdown, Bash

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md` | Delete | v2 legacy |
| `claude-plugin/skills/autoresearch/references/results-logging.md` | Delete | v2 legacy |
| `claude-plugin/skills/autoresearch/references/ml-metric-examples.md` | Delete | v2 legacy |
| `claude-plugin/skills/autoresearch/SKILL.md` | Modify | 移除 Legacy (v2) row + 補 `${CLAUDE_PLUGIN_ROOT}` 路徑 |
| `claude-plugin/skills/autoresearch/references/knowledge-system.md` | Modify | context.md 格式補 `Completed Step: N` |
| `claude-plugin/skills/autoresearch/references/core-principles.md` | Modify | 刪除 v2 config block + 移除 ml-metric 連結 |
| `claude-plugin/scripts/flow-check.sh` | Modify | check #9 正則強化 |
| `.claude/skills/autoresearch/` | Sync | 從 claude-plugin/ 鏡像 |

---

### Task 1: 刪除 v2 Legacy 文件並更新 SKILL.md Reference Map

**Files:**
- Delete: `claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md`
- Delete: `claude-plugin/skills/autoresearch/references/results-logging.md`
- Delete: `claude-plugin/skills/autoresearch/references/ml-metric-examples.md`
- Modify: `claude-plugin/skills/autoresearch/SKILL.md:135`

- [ ] **Step 1: 確認 legacy 文件無其他外部引用**

```bash
cd /home/ubuntu/DEV/autoresearch
grep -rn "autonomous-loop-protocol\|results-logging\|ml-metric-examples" claude-plugin/ --include="*.md" --include="*.sh"
```

預期輸出（僅這幾處，全部將在後續 steps 處理）：
```
claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md:5:... results-logging.md ...
claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md:291:... results-logging.md ...
claude-plugin/skills/autoresearch/references/core-principles.md:46:... ml-metric-examples.md ...
claude-plugin/skills/autoresearch/SKILL.md:135:| Legacy (v2) | autonomous-loop-protocol, results-logging, ml-metric-examples ...
```

- [ ] **Step 2: 刪除 3 個 legacy 文件**

```bash
cd /home/ubuntu/DEV/autoresearch
rm claude-plugin/skills/autoresearch/references/autonomous-loop-protocol.md
rm claude-plugin/skills/autoresearch/references/results-logging.md
rm claude-plugin/skills/autoresearch/references/ml-metric-examples.md
```

- [ ] **Step 3: 確認刪除成功**

```bash
ls claude-plugin/skills/autoresearch/references/ | sort
```

預期：`autonomous-loop-protocol.md`、`results-logging.md`、`ml-metric-examples.md` 均不出現。

- [ ] **Step 4: 更新 SKILL.md — 移除 Legacy (v2) row**

在 `claude-plugin/skills/autoresearch/SKILL.md` 第 135 行，找到並刪除整行：

```
| Legacy (v2) | autonomous-loop-protocol, results-logging, ml-metric-examples | Only when v2 inline config detected |
```

刪除後 Reference Map 最後一行應為：

```
| Shared patterns | interactive-setup-pattern, core-principles, knowledge-system | As needed during setup or iteration |
```

- [ ] **Step 5: 確認 SKILL.md 已移除 legacy row**

```bash
grep -n "Legacy\|autonomous-loop\|results-logging\|ml-metric" claude-plugin/skills/autoresearch/SKILL.md
```

預期：無任何輸出。

- [ ] **Step 6: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add -u claude-plugin/skills/autoresearch/references/
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "chore: delete v2 legacy reference files, remove from SKILL.md Reference Map"
```

---

### Task 2: 修復 knowledge-system.md — context.md 格式補 `Completed Step: N`

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/knowledge-system.md`

**背景：** stop-hook.sh 第 138 行用 `grep -oP 'Completed Step: \K\d+'` 從 context.md 讀取 workflow 進度，但 knowledge-system.md 的 context.md 格式模板完全沒有這個欄位。照模板寫的 context.md 會讓 stop-hook 的 workflow step 追蹤靜默失敗。

- [ ] **Step 1: 確認 stop-hook.sh 實際讀取方式**

```bash
grep -n "Completed Step" /home/ubuntu/DEV/autoresearch/claude-plugin/hooks/stop-hook.sh
```

預期輸出：
```
138:  COMPLETED_STEP=$(grep -oP 'Completed Step: \K\d+' .autoresearch/context.md 2>/dev/null | tail -1 || echo "")
```

確認 pattern 是 `Completed Step: N`（大寫、冒號、空格、數字）。

- [ ] **Step 2: 更新常規格式模板（第一處）**

在 `claude-plugin/skills/autoresearch/references/knowledge-system.md` 找到以下 Format 區塊（約第 32-50 行）：

```markdown
### Format

```markdown
# Autoresearch Context
Last updated: iteration N | YYYY-MM-DD HH:MM

## Current State
```

在 `Last updated:` 行下方加入 `Completed Step: N`：

```markdown
### Format

```markdown
# Autoresearch Context
Last updated: iteration N | YYYY-MM-DD HH:MM
Completed Step: N

## Current State
```

- [ ] **Step 3: 更新 First Iteration Bootstrap 模板（第二處）**

找到約第 62-79 行的 First Iteration Bootstrap 範例：

```markdown
```markdown
# Autoresearch Context
Last updated: iteration 1 | YYYY-MM-DD HH:MM

## Current State
```

同樣在 `Last updated:` 行下方加入 `Completed Step: 0`：

```markdown
```markdown
# Autoresearch Context
Last updated: iteration 1 | YYYY-MM-DD HH:MM
Completed Step: 0

## Current State
```

- [ ] **Step 4: 更新 Update Rules 說明**

找到 `### Update Rules` 區塊（約第 52-58 行），在第 1 條後加入說明：

```markdown
### Update Rules

1. **Update at iteration END only** — not during the iteration
2. **`Completed Step: N`** — always update N to the workflow step completed this iteration (stop-hook reads this for step-skip detection)
3. **Resolved issues:** move from Active to Resolved when fixed
```

（原第 2 條以下的編號依次遞增）

- [ ] **Step 5: 確認兩處模板都包含 Completed Step**

```bash
grep -n "Completed Step" claude-plugin/skills/autoresearch/references/knowledge-system.md
```

預期：至少 3 行（Format 模板、Bootstrap 模板、Update Rules 說明）。

- [ ] **Step 6: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/knowledge-system.md
git commit -m "fix(knowledge-system): add Completed Step: N to context.md format templates"
```

---

### Task 3: 修復 SKILL.md — Setup Confirmation 加上 `${CLAUDE_PLUGIN_ROOT}` 路徑

**Files:**
- Modify: `claude-plugin/skills/autoresearch/SKILL.md:55-60`

**背景：** SKILL.md 第 57-58 行寫「Run `validate-config.sh`」和「Run `setup-loop.sh`」，沒有路徑前綴。當 autoresearch 以 skill（非 command）形式被調用時，Claude 會把相對路徑接在 skill directory（`${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/`）而非 `${CLAUDE_PLUGIN_ROOT}/scripts/`，導致找不到腳本。`setup-workflow.md` 第 147-148 行已有正確用法作為參考。

- [ ] **Step 1: 確認目前 SKILL.md 腳本行的位置**

```bash
grep -n "validate-config\|setup-loop\|CLAUDE_PLUGIN_ROOT" claude-plugin/skills/autoresearch/SKILL.md
```

預期：
```
57:5. Run `validate-config.sh` with provided fields
58:6. Run `setup-loop.sh` to create state file and activate hook
```

- [ ] **Step 2: 替換兩行，加入完整路徑**

將：
```
5. Run `validate-config.sh` with provided fields
6. Run `setup-loop.sh` to create state file and activate hook
```

改為：
```
5. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh" --config ".autoresearch/config.yaml"`
6. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --config ".autoresearch/config.yaml"` to create state file and activate hook
```

- [ ] **Step 3: 確認 CLAUDE_PLUGIN_ROOT 出現在 SKILL.md**

```bash
grep -n "CLAUDE_PLUGIN_ROOT" claude-plugin/skills/autoresearch/SKILL.md
```

預期：2 行，分別對應 validate-config 和 setup-loop。

- [ ] **Step 4: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "fix(SKILL.md): explicit CLAUDE_PLUGIN_ROOT paths for validate-config and setup-loop"
```

---

### Task 4: 清理 core-principles.md — 移除 v2 config block 和 ml-metric 連結

**Files:**
- Modify: `claude-plugin/skills/autoresearch/references/core-principles.md`

**變更 A：** 第 79-87 行有 v2 inline config 語法（`/autoresearch\nGit-Memory: enabled\nMemory-Depth: 20`），v3 已改用 `config.yaml`，這段 config block 會誤導讀者以為這是有效配置。

**變更 B：** 第 46 行連結 `references/ml-metric-examples.md`（已被刪除）。替換為 inline 說明。

- [ ] **Step 1: 確認兩處位置**

```bash
grep -n "Git-Memory\|Memory-Depth\|Configuration:\|ml-metric" claude-plugin/skills/autoresearch/references/core-principles.md
```

預期：
```
46:**Apply:** ... see `references/ml-metric-examples.md`.
80:**Configuration:**
83:Git-Memory: enabled     # default — always on, reads git history every iteration
84:Memory-Depth: 20        # number of past commits to review (default: 20)
```

- [ ] **Step 2: 移除 v2 Configuration block（第 80-87 行）**

找到並刪除以下整個 block（`**Configuration:**` 到閉合 ` ``` ` 行，約 8 行）：

```
**Configuration:**
```
/autoresearch
Git-Memory: enabled     # default — always on, reads git history every iteration
Memory-Depth: 20        # number of past commits to review (default: 20)
```
```

刪除後，`**Apply:**` 段落直接銜接 `**Key commands the agent runs every iteration:**` 段落：

```markdown
**Apply:** Commit before verify. Revert on failure. Agent reads its own git history to inform next experiment.

**Key commands the agent runs every iteration:**
```bash
git log --oneline -20
...
```

- [ ] **Step 3: 修正 ml-metric 連結（第 46 行）**

找到：

```markdown
**Apply:** Define the `grep` command (or equivalent) that extracts your metric BEFORE starting. For ML-specific examples (accuracy, loss, F1, BLEU), see `references/ml-metric-examples.md`.
```

改為（移除連結，inline 舉例）：

```markdown
**Apply:** Define the `grep` command (or equivalent) that extracts your metric BEFORE starting. Examples: `grep -oP 'val_loss: \K[\d.]+' log.txt` for loss, `grep -oP 'accuracy: \K[\d.]+' results.txt` for accuracy.
```

- [ ] **Step 4: 確認 v2 config block 已移除**

```bash
grep -n "Git-Memory\|Memory-Depth\|ml-metric" claude-plugin/skills/autoresearch/references/core-principles.md
```

預期：無任何輸出。

- [ ] **Step 5: 確認文件仍可讀（前 50 行）**

```bash
head -50 claude-plugin/skills/autoresearch/references/core-principles.md
```

確認第 46 行前後邏輯通順。

- [ ] **Step 6: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/skills/autoresearch/references/core-principles.md
git commit -m "fix(core-principles): remove v2 config block, replace ml-metric link with inline example"
```

---

### Task 5: 強化 flow-check.sh check #9 正則

**Files:**
- Modify: `claude-plugin/scripts/flow-check.sh:225`

**背景：** 目前 pattern `Research.*(dispatch|spawn|Agent)` 可以匹配「Research Agent」、「Research dispatch」等，但漏掉「dispatch Research」、「dispatching the Research」、「spawn Research Agent」等 Coordinator 常用語序。加入雙向 OR 匹配。

- [ ] **Step 1: 撰寫測試腳本**

```bash
cat > /tmp/test-check9-regex.sh << 'EOF'
#!/bin/bash
# 測試 check #9 正則的匹配涵蓋率
OLD_PATTERN='Research.*(dispatch|spawn|Agent)'
NEW_PATTERN='(dispatch|spawn|dispatching|spawning).{0,40}Research|Research.{0,40}(dispatch|spawn|Agent|dispatched|spawned)'

pass=0; fail=0

check() {
  local desc="$1" input="$2" pattern="$3" should_match="$4"
  count=$(echo "$input" | grep -ciE "$pattern" 2>/dev/null || echo 0)
  if [[ "$should_match" == "yes" && "$count" -gt 0 ]]; then
    echo "PASS [$desc]"; ((pass++))
  elif [[ "$should_match" == "no" && "$count" -eq 0 ]]; then
    echo "PASS [$desc]"; ((pass++))
  else
    echo "FAIL [$desc] — expected $should_match, count=$count"; ((fail++))
  fi
}

echo "=== Old pattern ==="
check "Research Agent (old)"       "I will dispatch the Research Agent" "$OLD_PATTERN" yes
check "dispatch Research (old)"    "I will dispatch Research to analyze" "$OLD_PATTERN" no   # 應該漏掉
check "dispatching Research (old)" "dispatching Research Agent"          "$OLD_PATTERN" yes
check "spawn Research (old)"       "spawn Research"                      "$OLD_PATTERN" no   # 應該漏掉

echo ""
echo "=== New pattern ==="
check "Research Agent"             "I will dispatch the Research Agent"  "$NEW_PATTERN" yes
check "dispatch Research"          "I will dispatch Research to analyze"  "$NEW_PATTERN" yes  # 現在應匹配
check "dispatching Research"       "dispatching Research Agent"           "$NEW_PATTERN" yes
check "spawn Research"             "spawn Research"                       "$NEW_PATTERN" yes  # 現在應匹配
check "Research dispatched"        "Research Agent dispatched successfully" "$NEW_PATTERN" yes
check "no research (should miss)"  "I will dispatch Dev Agent"            "$NEW_PATTERN" no

echo ""
echo "Results: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] && exit 0 || exit 1
EOF
chmod +x /tmp/test-check9-regex.sh
bash /tmp/test-check9-regex.sh
```

預期輸出：
```
=== Old pattern ===
PASS [Research Agent (old)]
FAIL [dispatch Research (old)] — expected no, count=0   ← 確認舊 pattern 確實漏掉
PASS [dispatching Research (old)]
FAIL [spawn Research (old)] — expected no, count=0      ← 確認舊 pattern 確實漏掉

=== New pattern ===
PASS [Research Agent]
PASS [dispatch Research]
PASS [dispatching Research]
PASS [spawn Research]
PASS [Research dispatched]
PASS [no research (should miss)]

Results: 8 passed, 2 failed
```

（`fail=2` 是預期的 — 這些是舊 pattern 的已知缺口，不是新 pattern 的問題）

- [ ] **Step 2: 更新 flow-check.sh 第 225 行**

找到：

```bash
    research_mentions=$(grep -ciE 'Research.*(dispatch|spawn|Agent)' "$transcript_path" 2>/dev/null || echo "0")
```

改為：

```bash
    research_mentions=$(grep -ciE '(dispatch|spawn|dispatching|spawning).{0,40}Research|Research.{0,40}(dispatch|spawn|Agent|dispatched|spawned)' "$transcript_path" 2>/dev/null || echo "0")
```

- [ ] **Step 3: 確認修改後的行**

```bash
grep -n "research_mentions" claude-plugin/scripts/flow-check.sh
```

預期輸出包含新 pattern：
```
225:    research_mentions=$(grep -ciE '(dispatch|spawn|dispatching|spawning).{0,40}Research|Research.{0,40}(dispatch|spawn|Agent|dispatched|spawned)' "$transcript_path" 2>/dev/null || echo "0")
```

- [ ] **Step 4: 重跑測試腳本，確認新 pattern 6/6 通過**

```bash
bash /tmp/test-check9-regex.sh
```

預期（僅 new pattern 段）：
```
=== New pattern ===
PASS [Research Agent]
PASS [dispatch Research]
PASS [dispatching Research]
PASS [spawn Research]
PASS [Research dispatched]
PASS [no research (should miss)]
```

- [ ] **Step 5: Commit**

```bash
cd /home/ubuntu/DEV/autoresearch
git add claude-plugin/scripts/flow-check.sh
git commit -m "fix(flow-check): strengthen check #9 regex — catch dispatch/spawn Research in both word orders"
```

---

### Task 6: 同步 .claude/skills/autoresearch/ 並最終驗證

**Files:**
- Sync: `.claude/skills/autoresearch/` ← `claude-plugin/skills/autoresearch/`

- [ ] **Step 1: 同步**

```bash
cd /home/ubuntu/DEV/autoresearch
rm -rf .claude/skills/autoresearch/
cp -r claude-plugin/skills/autoresearch/ .claude/skills/autoresearch/
```

- [ ] **Step 2: 確認同步無差異**

```bash
diff -rq claude-plugin/skills/autoresearch/ .claude/skills/autoresearch/
```

預期：無任何輸出。

- [ ] **Step 3: 確認 legacy 文件已從 .claude/ 移除**

```bash
ls .claude/skills/autoresearch/references/ | grep -E "autonomous-loop|results-logging|ml-metric"
```

預期：無任何輸出。

- [ ] **Step 4: 確認全部修改都到位**

```bash
cd /home/ubuntu/DEV/autoresearch

echo "=== Task 1: Legacy files deleted ==="
ls claude-plugin/skills/autoresearch/references/ | grep -E "autonomous-loop|results-logging|ml-metric" && echo "FAIL: still exist" || echo "PASS"

echo "=== Task 2: Completed Step in knowledge-system.md ==="
grep -c "Completed Step" claude-plugin/skills/autoresearch/references/knowledge-system.md | grep -q "^[3-9]" && echo "PASS" || echo "FAIL: count=$(grep -c 'Completed Step' claude-plugin/skills/autoresearch/references/knowledge-system.md)"

echo "=== Task 3: CLAUDE_PLUGIN_ROOT in SKILL.md ==="
grep -c "CLAUDE_PLUGIN_ROOT" claude-plugin/skills/autoresearch/SKILL.md | grep -q "^2$" && echo "PASS" || echo "FAIL"

echo "=== Task 4: No Git-Memory or ml-metric in core-principles.md ==="
grep -qE "Git-Memory|ml-metric" claude-plugin/skills/autoresearch/references/core-principles.md && echo "FAIL: still present" || echo "PASS"

echo "=== Task 5: New regex in flow-check.sh ==="
grep -q "dispatching|spawning" claude-plugin/scripts/flow-check.sh && echo "PASS" || echo "FAIL"
```

預期：全部 PASS。

- [ ] **Step 5: Commit sync**

```bash
cd /home/ubuntu/DEV/autoresearch
git add .claude/skills/autoresearch/
git commit -m "sync(.claude): mirror all skill fixes to local .claude/skills/autoresearch"
```
