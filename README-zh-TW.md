<div align="center">

# Claude Autoresearch

**把 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 變成不停歇的自主改進引擎。**

基於 [Karpathy 的 autoresearch](https://github.com/karpathy/autoresearch) — 約束 + 機械指標 + 自主迭代 = 複利式進步。

[![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-blue?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)
[![Version](https://img.shields.io/badge/version-1.9.0-blue.svg)](https://github.com/uditgoenka/autoresearch/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

*「設定目標 → Claude 跑迴圈 → 你醒來看結果」*

*你不需要 AGI。你需要一個目標、一個指標、和一個永不停止的迴圈。*

[運作原理](#運作原理) · [指令一覽](#指令一覽) · [快速開始](#快速開始) · [使用範例](#使用範例) · [常見問題](#常見問題)

</div>

---

## 為什麼需要這個

[Karpathy 的 autoresearch](https://github.com/karpathy/autoresearch) 用 630 行 Python 讓 AI 一夜自主改進 ML 模型 — **每晚 100 次實驗**。原理很簡單：一個指標、約束範圍、快速驗證、自動回滾、用 git 當記憶體。

**Claude Autoresearch 把這些原則推廣到任何領域。** 不只是 ML — 程式碼、文件、測試、安全、部署，任何有可量化指標的工作都適用。

---

## 運作原理

```
迴圈 (永遠 或 N 次):
  1. Review  — 讀取現狀 + git 歷史 + 結果記錄
  2. Ideate  — 根據成功/失敗/未嘗試，選擇下一步
  3. Modify  — 做「一個」原子化改動
  4. Commit  — 驗證之前先 git commit（方便回滾）
  5. Verify  — 執行機械式驗證（測試、benchmark、分數）
  6. Guard   — 可選的回歸檢查
  7. Decide  — 改善 → 保留 / 退步 → git revert / 崩潰 → 修復或跳過
  8. Log     — 記錄結果到 TSV
  9. Repeat  — 永不停止（或完成 N 次後停止）
```

每次改善都會累積。每次失敗都自動回滾。進度以 TSV 格式記錄。

### Stop Hook — 機械式迴圈強制（v1.9.0 新增）

Autoresearch 使用 **Stop Hook** 在 runtime 層面機械式阻止 Claude 退出迴圈。這不是 prompt 指令 — 而是真正的退出攔截機制。

- Setup 完成後，`setup-loop.sh` 建立狀態檔 `.claude/autoresearch-loop.local.md`
- Claude 嘗試停止時，hook 攔截退出並重新注入相同 prompt
- 迴圈持續直到達到最大迭代次數或使用者執行 `/autoresearch:cancel`

### 8 條關鍵規則

| # | 規則 |
|---|------|
| 1 | **迴圈到底** — 無限模式：永遠。有限模式：N 次後總結 |
| 2 | **先讀再寫** — 完全理解現狀後才修改 |
| 3 | **一次改一處** — 原子化改動，壞了馬上知道原因 |
| 4 | **機械式驗證** — 不要主觀的「看起來不錯」，用數字說話 |
| 5 | **自動回滾** — 失敗的改動立即 git revert |
| 6 | **簡單為王** — 同樣結果 + 更少程式碼 = 保留 |
| 7 | **Git 就是記憶** — 實驗用 `experiment:` 前綴提交，`git revert` 保留失敗歷史，每輪必讀 `git log` |
| 8 | **卡住就想更深** — 重讀檔案、合併近似成功、嘗試激進改動 |

---

## 指令一覽

| 指令 | 功能 |
|------|------|
| `/autoresearch` | 執行自主迭代迴圈（預設無限） |
| `/autoresearch:plan` | 互動式設定精靈：目標 → 範圍、指標、驗證指令 |
| `/autoresearch:debug` | 自主找 bug — 科學方法 + 迭代調查，找出**所有** bug |
| `/autoresearch:fix` | 自主修錯 — 一次修一個，原子化，失敗自動回滾，修到零錯誤 |
| `/autoresearch:security` | 安全審計 — STRIDE 威脅模型 + OWASP Top 10 + 4 個對抗角色紅隊測試 |
| `/autoresearch:ship` | 交付工作流 — 8 階段（識別→清單→準備→乾跑→交付→驗證→記錄） |
| `/autoresearch:scenario` | 場景探索 — 12 維度邊界情境生成 |
| `/autoresearch:predict` | 多角色分析 — 5 個專家角色獨立分析→辯論→共識 |
| `/autoresearch:learn` | 文件引擎 — 掃描程式碼→生成/更新文件→驗證→修復迴圈 |
| `/autoresearch:cancel` | 停止迴圈 — 移除狀態檔，下次退出時允許停止 |
| `Iterations: N` | 加在設定中，限制執行 N 次後停止 |
| `Guard: <command>` | 可選安全網 — 必須通過才保留改動 |

### 快速決策指南

| 我想要... | 使用 |
|-----------|------|
| 提升測試覆蓋率 / 縮小 bundle / 任何指標 | `/autoresearch`（加 `Iterations: N` 限制次數） |
| 不知道該用什麼指標 | `/autoresearch:plan` |
| 跑安全審計 | `/autoresearch:security` |
| 交付 PR / 部署 / 發版 | `/autoresearch:ship` |
| 優化時不破壞現有測試 | 加上 `Guard: npm test` |
| 找出所有 bug | `/autoresearch:debug` |
| 修掉所有錯誤（測試、型別、lint） | `/autoresearch:fix` |
| 找 bug 後自動修 | `/autoresearch:debug --fix` |
| 探索邊界情境 | `/autoresearch:scenario` |
| 多角度分析後再行動 | `/autoresearch:predict --chain debug` |
| 自動產生文件 | `/autoresearch:learn --mode init` |
| 更新既有文件 | `/autoresearch:learn --mode update` |
| 停止正在跑的迴圈 | `/autoresearch:cancel` |

---

## 快速開始

### 1. 安裝

**方式 A — Plugin 安裝（推薦）：**

在 Claude Code 中執行：
```
/plugin marketplace add uditgoenka/autoresearch
/plugin install autoresearch@autoresearch
```

安裝後**重啟 Claude Code session** 即可使用所有指令。

**更新（無需重裝）：**
```
/plugin update autoresearch
```

**方式 B — 手動複製：**
```bash
git clone https://github.com/uditgoenka/autoresearch.git

# 複製到你的專案
cp -r autoresearch/claude-plugin/skills/autoresearch .claude/skills/autoresearch
cp -r autoresearch/claude-plugin/commands/autoresearch .claude/commands/autoresearch
cp autoresearch/claude-plugin/commands/autoresearch.md .claude/commands/autoresearch.md

# 複製 hooks（Stop Hook 必須）
mkdir -p .claude/hooks .claude/scripts
cp -r autoresearch/claude-plugin/hooks/* .claude/hooks/
cp -r autoresearch/claude-plugin/scripts/* .claude/scripts/
```

### 2. 執行

兩種使用方式：

**方式一：提供完整設定（直接開始，不問問題）**

```
/autoresearch
Goal: 提升測試覆蓋率到 90%
Scope: src/**/*.ts
Metric: coverage %
Direction: higher
Verify: npm test -- --coverage
Guard: npm run build
Iterations: 20
```

**方式二：只給 Goal（Claude 會互動問你其餘設定）**

```
/autoresearch
Goal: 減少 bundle size
```

Claude 會批次問你 Scope、Metric、Direction、Verify 等設定。

### 3. 放著讓它跑

Claude 讀取所有檔案、建立基線、開始迭代 — 一次一個改動。保留改善、自動回滾失敗、記錄一切。**永不停止，直到你中斷**（或 N 次迭代完成）。

---

## 使用範例

### 範例一：提升測試覆蓋率

假設你的 TypeScript 專案目前測試覆蓋率 65%，想自動提升到 90%：

```
/autoresearch
Goal: 提升測試覆蓋率從 65% 到 90%
Scope: src/**/*.ts
Metric: coverage %
Direction: higher
Verify: npx jest --coverage 2>&1 | grep 'All files' | awk '{print $4}'
Guard: npx tsc --noEmit
Iterations: 30
```

**Claude 會這樣運作：**

```
Setup 完成 → 啟動 Stop Hook → 建立狀態檔

迭代 1:
  Review → 讀 git log、現有測試
  Ideate → 發現 auth 模組沒有測試
  Modify → 新增 auth.test.ts
  Commit → experiment(auth): add auth module tests
  Verify → 覆蓋率 65% → 71% (+6%)  改善
  Guard  → tsc 通過
  Decide → KEEP

迭代 2:
  Review → 讀 git log，上次 auth 測試成功
  Ideate → 發現 utils 模組覆蓋率低
  Modify → 新增 utils.test.ts
  Verify → 71% → 74% (+3%)  改善
  Decide → KEEP

迭代 3:
  Modify → 重構 api handler 測試
  Verify → 74% → 73% (-1%)  退步
  Decide → DISCARD (git revert)

... 持續迭代 ...

迭代 30: 最終摘要
  Baseline: 65% → Best: 91.2%
  Keeps: 18 | Discards: 10 | Crashes: 2
```

### 範例二：自動找 Bug 並修復

```
/autoresearch:debug
Scope: src/api/**/*.ts
Symptom: API 回傳 500 on POST /users
Iterations: 20
```

找到所有 bug 後自動修復：
```
/autoresearch:fix --from-debug
```

### 範例三：安全審計

```
/autoresearch:security
Scope: src/api/
Iterations: 10
```

產出結構化報告到 `security/` 目錄，包含 STRIDE 威脅模型和 OWASP 覆蓋。

### 範例四：探索邊界情境

```
/autoresearch:scenario
Scenario: 用戶在高併發下同時下單
Domain: software
Depth: deep
```

從 12 個維度（正常路徑、錯誤、邊界、濫用、規模、併發、時序、資料、權限、整合、恢復、狀態轉換）產生場景。

### 範例五：自動生成文件

```
/autoresearch:learn --mode init --depth deep
```

掃描整個程式碼庫，自動產生架構圖、API 文件、測試指南等。

### 範例六：多角色分析後再行動

```
/autoresearch:predict --chain debug,fix
Scope: src/payment/
Goal: 分析支付模組潛在問題
```

5 個專家角色（架構師、安全分析師、效能工程師、可靠性工程師、魔鬼代言人）獨立分析，辯論後達成共識，再自動串接 debug 和 fix。

---

## 停止迴圈的方式

| 方式 | 說明 |
|------|------|
| `/autoresearch:cancel` | 移除狀態檔，迴圈在下次退出時停止 |
| `Iterations: N` | 設定時加上，跑 N 次後自動停止 |
| `Ctrl+C` | 強制中斷 session |
| 手動刪除狀態檔 | `rm .claude/autoresearch-loop.local.md` |

---

## 結果追蹤

每次迭代以 TSV 格式記錄：

```tsv
iteration  commit   metric  delta   status    description
0          a1b2c3d  85.2    0.0     baseline  initial state
1          b2c3d4e  87.1    +1.9    keep      add tests for auth edge cases
2          -        86.5    -0.6    discard   refactor test helpers (broke 2 tests)
3          c3d4e5f  88.3    +1.2    keep      add error handling tests
```

每 10 次迭代印出進度摘要。有限模式最後印出基線 → 最佳值的總結。

---

## 崩潰恢復

| 失敗類型 | 處理方式 |
|----------|----------|
| 語法錯誤 | 立即修復，不算一次迭代 |
| 執行時錯誤 | 嘗試修復（最多 3 次），然後跳過 |
| 資源耗盡 | 回滾，嘗試更小的變體 |
| 無限迴圈 / 卡死 | 超時後 kill，回滾 |
| 外部相依問題 | 跳過，記錄，嘗試不同方法 |

---

## Guard — 防止回歸

優化指標時可能破壞其他功能。**Guard** 是可選的安全網。

```
/autoresearch
Goal: 減少 API 回應時間到 100ms 以下
Verify: npm run bench:api | grep "p95"
Guard: npm test
```

- **Verify** = 「指標有改善嗎？」（目標）
- **Guard** = 「其他東西壞了嗎？」（安全網）

如果指標改善但 Guard 失敗，Claude 會重新調整優化（最多 2 次嘗試），且永遠不修改 Guard/測試檔案。

---

## 常見問題

**Q: 我不知道該用什麼指標。**
A: 執行 `/autoresearch:plan` — 它會分析你的程式碼庫，建議指標，並在啟動前乾跑驗證指令。

**Q: 這適用於任何專案嗎？**
A: 是的。任何語言、框架或領域。透過 `/plugin marketplace add uditgoenka/autoresearch` 安裝，或手動從 `claude-plugin/` 複製。

**Q: 怎麼停止迴圈？**
A: 執行 `/autoresearch:cancel`、加 `Iterations: N` 限制次數、或 `Ctrl+C`。Claude 在驗證前就會 commit，所以最後的成功狀態永遠在 git 中。

**Q: 可以用在非程式碼的工作嗎？**
A: 完全可以。文案、文件、政策文件 — 任何有可量化指標的工作。

**Q: /autoresearch:security 會修改我的程式碼嗎？**
A: 不會。預設是唯讀分析，產出結構化報告。加 `--fix` 才會自動修復已確認的高/嚴重漏洞。

**Q: Stop Hook 是什麼？為什麼需要它？**
A: Stop Hook 是 v1.9.0 新增的機制。之前靠 prompt 指令告訴 Claude「不要停」，但 Claude 常常忽略而停下來問問題。Stop Hook 在 runtime 層面攔截退出，機械式地把 Claude 拉回迴圈，確保它真正自主運作。

---

## 貢獻

歡迎貢獻！請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## 授權

[MIT](LICENSE)
