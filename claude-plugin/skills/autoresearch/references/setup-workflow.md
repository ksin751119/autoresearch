# Setup Wizard Protocol

Interactive wizard for `/autoresearch:setup`. Takes a Goal, asks one question at a time, generates `.autoresearch/config.yaml`, then launches autoresearch.

## Contents

- [Input](#input)
- [Question Flow](#question-flow)
- [After All Questions](#after-all-questions)

## Input

The user provides a Goal via $ARGUMENTS. Example: `/autoresearch:setup "最大化套利利潤"`

## Question Flow

Ask ONE question per message using `AskUserQuestion`. Allow the user to skip any optional field by pressing Enter or saying "skip".

### Question 1: Workflow

```
請列出你希望每輪 iteration 遵循的步驟（一行一步）。

例如：
1. 分析 log
2. 找 root cause
3. 規劃方案
4. 實作
5. 驗證

直接輸入「skip」跳過（Coordinator 自主決定流程）
```

Parse the response into a YAML list. If skipped, omit from config.

### Question 2: Notes

```
有什麼約束條件？（一行一條）

例如：
- 不能修改測試檔案
- pipeline < 1 sec

直接輸入「skip」跳過（無約束）
```

### Question 3: Guard

```
有沒有每輪必須通過的安全檢查命令？

例如：cargo build, npm test, pytest

直接輸入「skip」跳過（無 guard）
```

### Question 4: Verify + Direction

```
有沒有量化指標的命令？（執行後會輸出一個數字）

例如：cargo run -- --benchmark

直接輸入「skip」跳過（無量化指標）
```

If verify is provided, ask:

```
這個指標是越高越好還是越低越好？ [higher / lower]
```

### Question 5: Max Iterations

```
最多跑幾輪？

直接輸入「skip」跳過（不限制）
```

### Question 6: Completion Promise

```
什麼條件下算完成？（用一句話描述）

例如：所有測試通過、套利利潤穩定提升

直接輸入「skip」跳過（無語義退出條件）
```

### Question 7: Evaluator

```
要開啟獨立審查嗎？ [on / off]

預設 on（推薦）。直接輸入「skip」= on
```

## After All Questions

### 1. Generate config.yaml

Write `.autoresearch/config.yaml` with all collected fields. Only include fields that were provided (not skipped).

Example output:
```yaml
goal: "最大化套利利潤"

workflow:
  - 分析 log
  - 找 root cause
  - 實作
  - 驗證

notes:
  - 不能修改測試檔案

max_iterations: 10
guard: "cargo build"
evaluator: on
```

### 2. Show Configuration Summary

```
Configuration Summary:
  Goal:               最大化套利利潤
  Workflow:           4 steps
  Notes:              1 constraint
  Guard:              cargo build
  Verify:             (none)
  Max iterations:     10
  Completion promise: (none)
  Evaluator:          on

Config saved to: .autoresearch/config.yaml

[Launch / Edit / Cancel]
```

Use `AskUserQuestion` for confirmation.

### 3. Handle Response

- **Launch** → Run validate-config.sh, then setup-loop.sh, then begin iteration loop
- **Edit** → Tell user to modify `.autoresearch/config.yaml`, then re-show summary
- **Cancel** → Stop

### 4. Launch Sequence

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh" --config ".autoresearch/config.yaml"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" --config ".autoresearch/config.yaml"
```

Then read the Coordinator protocol and begin the first iteration.
