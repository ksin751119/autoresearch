# Stop Hook Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate a ralph-loop-style Stop Hook into autoresearch so Claude cannot stop mid-loop to ask questions — the hook mechanically intercepts exit attempts and re-injects the loop prompt until the completion condition is met.

**Architecture:** Add a `hooks/` directory to the plugin with a `hooks.json` registration and `stop-hook.sh` script. A new `scripts/setup-loop.sh` creates a state file (`.claude/autoresearch-loop.local.md`) with all loop config (goal, scope, metric, verify, guard, iteration count). The Stop hook reads this state file on every exit attempt, checks completion conditions (max iterations reached, metric target met, or user cancelled), and either allows exit or blocks it by re-injecting the autoresearch prompt. The existing interactive setup gate (AskUserQuestion) remains for initial config collection — the hook only activates AFTER setup completes and the loop begins.

**Tech Stack:** Bash (stop-hook.sh, setup-loop.sh), JSON (hooks.json), Markdown (command updates, cancel command)

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `claude-plugin/hooks/hooks.json` | Register Stop hook with Claude Code |
| Create | `claude-plugin/hooks/stop-hook.sh` | Intercept exit, check completion, re-inject prompt or allow exit |
| Create | `claude-plugin/scripts/setup-loop.sh` | Parse args, create state file, output init message |
| Create | `claude-plugin/commands/autoresearch/cancel.md` | `/autoresearch:cancel` — remove state file, stop loop |
| Modify | `claude-plugin/commands/autoresearch.md` | After setup complete, call setup-loop.sh to activate hook before entering loop |
| Modify | `claude-plugin/skills/autoresearch/SKILL.md:536-561` | Add instructions for hook-based loop activation after setup |

---

### Task 1: Create hooks.json

**Files:**
- Create: `claude-plugin/hooks/hooks.json`

- [ ] **Step 1: Create the hooks registration file**

```json
{
  "description": "Autoresearch stop hook — prevents Claude from exiting during autonomous loop iterations",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Verify JSON is valid**

Run: `cat claude-plugin/hooks/hooks.json | jq .`
Expected: Pretty-printed JSON without errors

- [ ] **Step 3: Commit**

```bash
git add claude-plugin/hooks/hooks.json
git commit -m "feat: add Stop hook registration for autonomous loop"
```

---

### Task 2: Create setup-loop.sh

**Files:**
- Create: `claude-plugin/scripts/setup-loop.sh`

This script is called by the command after interactive setup completes. It writes all loop config into a state file that the stop hook reads.

- [ ] **Step 1: Create the setup script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── Usage ────────────────────────────────────────────────────────
usage() {
  cat <<'USAGE'
Usage: setup-loop.sh --goal GOAL --scope SCOPE --metric METRIC --direction DIR --verify CMD [--guard CMD] [--max-iterations N] [--prompt PROMPT]

Creates .claude/autoresearch-loop.local.md state file to activate the Stop hook loop.

Options:
  --goal            What to improve (required)
  --scope           File globs to modify (required)
  --metric          Metric name (required)
  --direction       "higher" or "lower" (required)
  --verify          Shell command that produces the metric (required)
  --guard           Shell command that must always pass (optional)
  --max-iterations  Stop after N iterations, 0 = unlimited (default: 0)
  --prompt          Full prompt to re-inject each iteration (optional, auto-generated if omitted)
  -h, --help        Show this help
USAGE
  exit 0
}

# ─── Argument Parsing ─────────────────────────────────────────────
GOAL="" SCOPE="" METRIC="" DIRECTION="" VERIFY="" GUARD="" MAX_ITERATIONS=0 PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --goal)           GOAL="$2";           shift 2 ;;
    --scope)          SCOPE="$2";          shift 2 ;;
    --metric)         METRIC="$2";         shift 2 ;;
    --direction)      DIRECTION="$2";      shift 2 ;;
    --verify)         VERIFY="$2";         shift 2 ;;
    --guard)          GUARD="$2";          shift 2 ;;
    --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
    --prompt)         PROMPT="$2";         shift 2 ;;
    -h|--help)        usage ;;
    *)                echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ─── Validation ───────────────────────────────────────────────────
missing=()
[[ -z "$GOAL" ]]      && missing+=("--goal")
[[ -z "$SCOPE" ]]     && missing+=("--scope")
[[ -z "$METRIC" ]]    && missing+=("--metric")
[[ -z "$DIRECTION" ]] && missing+=("--direction")
[[ -z "$VERIFY" ]]    && missing+=("--verify")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: Missing required arguments: ${missing[*]}" >&2
  exit 1
fi

if [[ "$MAX_ITERATIONS" != "0" ]] && ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Error: --max-iterations must be a positive integer or 0, got: $MAX_ITERATIONS" >&2
  exit 1
fi

# ─── Build default prompt if not provided ─────────────────────────
if [[ -z "$PROMPT" ]]; then
  PROMPT="Continue the autoresearch autonomous loop.
Goal: ${GOAL}
Scope: ${SCOPE}
Metric: ${METRIC}
Direction: ${DIRECTION}
Verify: ${VERIFY}"
  if [[ -n "$GUARD" ]]; then
    PROMPT="${PROMPT}
Guard: ${GUARD}"
  fi
  PROMPT="${PROMPT}

Read the autonomous loop protocol, check git log for recent experiments, review the results log, then execute the NEXT iteration. Do NOT re-run setup. Go directly to Phase 1 (Review) of the loop."
fi

# ─── Escape values for YAML ──────────────────────────────────────
yaml_escape() {
  local val="$1"
  if [[ "$val" == *$'\n'* ]] || [[ "$val" == *':'* ]] || [[ "$val" == *'"'* ]] || [[ "$val" == *"'"* ]]; then
    echo "\"$(echo "$val" | sed 's/"/\\"/g')\""
  else
    echo "$val"
  fi
}

# ─── Create state file ───────────────────────────────────────────
mkdir -p .claude

SESSION_ID="${CLAUDE_CODE_SESSION_ID:-unknown}"

cat > .claude/autoresearch-loop.local.md <<EOF
---
active: true
iteration: 0
session_id: ${SESSION_ID}
max_iterations: ${MAX_ITERATIONS}
goal: $(yaml_escape "$GOAL")
scope: $(yaml_escape "$SCOPE")
metric: $(yaml_escape "$METRIC")
direction: ${DIRECTION}
verify: $(yaml_escape "$VERIFY")
guard: $(yaml_escape "$GUARD")
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

${PROMPT}
EOF

# ─── Output ───────────────────────────────────────────────────────
echo ""
echo "🔬 Autoresearch loop activated!"
echo "   Goal:           ${GOAL}"
echo "   Scope:          ${SCOPE}"
echo "   Metric:         ${METRIC} (${DIRECTION} is better)"
echo "   Verify:         ${VERIFY}"
if [[ -n "$GUARD" ]]; then
  echo "   Guard:          ${GUARD}"
fi
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then
  echo "   Max iterations: ${MAX_ITERATIONS}"
else
  echo "   Max iterations: unlimited"
fi
echo "   Session:        ${SESSION_ID}"
echo ""
echo "The Stop hook will keep this session looping until:"
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then
  echo "  - ${MAX_ITERATIONS} iterations complete, OR"
fi
echo "  - You run /autoresearch:cancel"
echo ""
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x claude-plugin/scripts/setup-loop.sh`
Expected: No output, exit code 0

- [ ] **Step 3: Test argument parsing**

Run: `bash claude-plugin/scripts/setup-loop.sh --goal "test coverage" --scope "src/**/*.ts" --metric "coverage %" --direction higher --verify "npm test -- --coverage" --max-iterations 10 2>&1; echo "EXIT: $?"`
Expected: Activation message showing all fields, EXIT: 0
Then: `cat .claude/autoresearch-loop.local.md` to verify state file content

- [ ] **Step 4: Test validation**

Run: `bash claude-plugin/scripts/setup-loop.sh --goal "test" 2>&1; echo "EXIT: $?"`
Expected: "Error: Missing required arguments: --scope --metric --direction --verify", EXIT: 1

- [ ] **Step 5: Clean up test state file and commit**

```bash
rm -f .claude/autoresearch-loop.local.md
git add claude-plugin/scripts/setup-loop.sh
git commit -m "feat: add setup-loop.sh to create loop state file"
```

---

### Task 3: Create stop-hook.sh

**Files:**
- Create: `claude-plugin/hooks/stop-hook.sh`

This is the core mechanism. When Claude tries to exit, this script checks if an autoresearch loop is active and either allows exit or blocks it.

- [ ] **Step 1: Create the stop hook script**

```bash
#!/usr/bin/env bash
set -uo pipefail

# ─── Configuration ────────────────────────────────────────────────
STATE_FILE=".claude/autoresearch-loop.local.md"

# ─── No state file → not in a loop, allow exit ───────────────────
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# ─── Parse YAML frontmatter from state file ───────────────────────
parse_field() {
  local field="$1"
  local value
  value=$(sed -n "/^---$/,/^---$/{ s/^${field}: *//p; }" "$STATE_FILE" | head -1)
  # Strip surrounding quotes if present
  value="${value%\"}"
  value="${value#\"}"
  echo "$value"
}

ACTIVE=$(parse_field "active")
ITERATION=$(parse_field "iteration")
MAX_ITERATIONS=$(parse_field "max_iterations")
SESSION_ID_STATE=$(parse_field "session_id")

# ─── Validate state file ─────────────────────────────────────────
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# ─── Session isolation ────────────────────────────────────────────
# Read session_id from hook input (stdin JSON from Claude Code)
HOOK_INPUT=$(cat)
HOOK_SESSION_ID=""
if command -v jq &>/dev/null; then
  HOOK_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
fi

# If we can determine session IDs and they don't match, allow exit (different session)
if [[ -n "$HOOK_SESSION_ID" ]] && [[ -n "$SESSION_ID_STATE" ]] && [[ "$SESSION_ID_STATE" != "unknown" ]]; then
  if [[ "$HOOK_SESSION_ID" != "$SESSION_ID_STATE" ]]; then
    exit 0
  fi
fi

# ─── Validate numeric fields ─────────────────────────────────────
if ! [[ "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Warning: autoresearch state file has invalid iteration: '$ITERATION'. Removing state file." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: autoresearch state file has invalid max_iterations: '$MAX_ITERATIONS'. Removing state file." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ─── Check max iterations ────────────────────────────────────────
NEXT_ITERATION=$((ITERATION + 1))

if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$NEXT_ITERATION" -gt "$MAX_ITERATIONS" ]]; then
  echo "Autoresearch loop complete: reached max iterations ($MAX_ITERATIONS)." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ─── Extract prompt from state file (everything after second ---) ─
PROMPT=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$STATE_FILE")

if [[ -z "$PROMPT" ]]; then
  echo "Warning: autoresearch state file has no prompt. Removing state file." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ─── Increment iteration counter ─────────────────────────────────
TMPFILE=$(mktemp)
sed "s/^iteration: .*/iteration: ${NEXT_ITERATION}/" "$STATE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$STATE_FILE"

# ─── Build system message ────────────────────────────────────────
GOAL=$(parse_field "goal")
METRIC=$(parse_field "metric")

SYS_MSG="🔬 Autoresearch iteration ${NEXT_ITERATION}"
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then
  SYS_MSG="${SYS_MSG}/${MAX_ITERATIONS}"
fi
SYS_MSG="${SYS_MSG} | Goal: ${GOAL} | Metric: ${METRIC}"
SYS_MSG="${SYS_MSG} | To stop: /autoresearch:cancel"

# ─── Block exit and re-inject prompt ─────────────────────────────
# Output JSON that Claude Code interprets as: block exit, feed prompt as next message
if command -v jq &>/dev/null; then
  jq -n \
    --arg decision "block" \
    --arg reason "$PROMPT" \
    --arg systemMessage "$SYS_MSG" \
    '{"decision": $decision, "reason": $reason, "systemMessage": $systemMessage}'
else
  # Fallback without jq: manual JSON construction
  # Escape special chars in prompt for JSON
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$PROMPT")
  ESCAPED_MSG=$(printf '%s' "$SYS_MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$SYS_MSG")
  echo "{\"decision\": \"block\", \"reason\": ${ESCAPED_PROMPT}, \"systemMessage\": ${ESCAPED_MSG}}"
fi
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x claude-plugin/hooks/stop-hook.sh`
Expected: No output, exit code 0

- [ ] **Step 3: Unit test — no state file (should allow exit)**

Run: `rm -f .claude/autoresearch-loop.local.md && echo '{}' | bash claude-plugin/hooks/stop-hook.sh; echo "EXIT: $?"`
Expected: No output, EXIT: 0

- [ ] **Step 4: Unit test — active loop (should block exit)**

First create a test state file:
```bash
mkdir -p .claude
cat > .claude/autoresearch-loop.local.md <<'EOF'
---
active: true
iteration: 3
session_id: unknown
max_iterations: 10
goal: test coverage
scope: src/**/*.ts
metric: coverage %
direction: higher
verify: npm test
guard:
started_at: "2026-03-31T00:00:00Z"
---

Continue the autoresearch autonomous loop.
Goal: test coverage
EOF
```

Run: `echo '{}' | bash claude-plugin/hooks/stop-hook.sh`
Expected: JSON output with `"decision": "block"`, iteration incremented to 4

Then verify: `grep "iteration:" .claude/autoresearch-loop.local.md`
Expected: `iteration: 4`

- [ ] **Step 5: Unit test — max iterations reached (should allow exit)**

```bash
sed -i '' 's/^iteration: .*/iteration: 10/' .claude/autoresearch-loop.local.md
echo '{}' | bash claude-plugin/hooks/stop-hook.sh; echo "EXIT: $?"
```
Expected: "Autoresearch loop complete" message, EXIT: 0, state file removed

- [ ] **Step 6: Clean up and commit**

```bash
rm -f .claude/autoresearch-loop.local.md
git add claude-plugin/hooks/stop-hook.sh
git commit -m "feat: add stop-hook.sh — mechanical loop enforcement via Stop hook"
```

---

### Task 4: Create /autoresearch:cancel command

**Files:**
- Create: `claude-plugin/commands/autoresearch/cancel.md`

- [ ] **Step 1: Create the cancel command**

```markdown
---
name: autoresearch:cancel
description: Cancel the active autoresearch loop
allowed-tools: ["Bash(test -f .claude/autoresearch-loop.local.md:*)", "Bash(rm .claude/autoresearch-loop.local.md)", "Read(.claude/autoresearch-loop.local.md)"]
---

## Cancel Autoresearch Loop

1. Check if `.claude/autoresearch-loop.local.md` exists
2. If it exists:
   - Read the file to extract the current `iteration:` number and `goal:` field
   - Remove the file: `rm .claude/autoresearch-loop.local.md`
   - Report: "Cancelled autoresearch loop at iteration N (Goal: GOAL)"
3. If it does not exist:
   - Report: "No active autoresearch loop found."
```

- [ ] **Step 2: Commit**

```bash
git add claude-plugin/commands/autoresearch/cancel.md
git commit -m "feat: add /autoresearch:cancel command to stop loop"
```

---

### Task 5: Modify autoresearch.md command to activate the hook

**Files:**
- Modify: `claude-plugin/commands/autoresearch.md`

The command currently goes straight from setup to loop execution within the same prompt. We need to add a step that calls `setup-loop.sh` after interactive setup completes, so the Stop hook becomes active before the first iteration.

- [ ] **Step 1: Update the command file**

Replace the current content of `claude-plugin/commands/autoresearch.md` with:

```markdown
---
name: autoresearch
description: Autonomous Goal-directed Iteration. Modify, verify, keep/discard, repeat. Apply to ANY task with a measurable metric.
argument-hint: "[Goal: <text>] [Scope: <glob>] [Metric: <text>] [Verify: <cmd>] [Guard: <cmd>] [--iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST, before reading any files)

Extract these from $ARGUMENTS — the user may provide extensive context alongside config. Ignore prose and extract ONLY structured fields:

- `Goal:` — text after "Goal:" keyword
- `Scope:` or `--scope <glob>` — file globs after "Scope:" keyword
- `Metric:` — text after "Metric:" keyword
- `Direction:` — "higher" or "lower" after "Direction:" keyword
- `Verify:` — shell command after "Verify:" keyword
- `Guard:` — shell command after "Guard:" keyword (optional)
- `Iterations:` or `--iterations` — integer N for bounded mode (CRITICAL: if set, you MUST run exactly N iterations then stop)

If `Iterations: N` or `--iterations N` is found, set `max_iterations = N`. Track `current_iteration` starting at 0. After iteration N, print final summary and STOP.

## Execution

1. Read the autonomous loop protocol: `.claude/skills/autoresearch/references/autonomous-loop-protocol.md`
2. Read the results logging format: `.claude/skills/autoresearch/references/results-logging.md`
3. If Goal, Scope, Metric, and Verify are all extracted — proceed directly to step 5
4. If any critical field is missing — use `AskUserQuestion` with batched questions as defined in SKILL.md "Interactive Setup" section
5. **Activate the Stop hook** — After all config is collected, run the setup script to create the loop state file. This ensures the Stop hook will keep the session looping even if you try to exit:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" \
     --goal "<GOAL>" \
     --scope "<SCOPE>" \
     --metric "<METRIC>" \
     --direction "<DIRECTION>" \
     --verify "<VERIFY>" \
     --guard "<GUARD>" \
     --max-iterations <N or 0>
   ```

   Replace placeholders with actual values collected from args or interactive setup.

6. Execute the autonomous loop: Modify → Verify → Keep/Discard → Repeat
7. If bounded: after each iteration, check `current_iteration < max_iterations`. If not, STOP and print summary.

IMPORTANT: Start executing immediately. Stream all output live — never run in background. Never stop early unless goal achieved or max_iterations reached.

## Stop Hook Behavior

Once step 5 creates the state file, the Stop hook is active. If you try to exit (intentionally or accidentally), the hook will:
- Block the exit
- Re-inject the loop prompt with the current iteration number
- You will re-enter Phase 1 (Review) of the autonomous loop protocol

To stop the loop, the user must run `/autoresearch:cancel` or the max iterations must be reached.

Do NOT attempt to remove the state file yourself. Only `/autoresearch:cancel` or the hook's max-iteration check removes it.
```

- [ ] **Step 2: Verify the file is valid markdown**

Run: `head -5 claude-plugin/commands/autoresearch.md`
Expected: YAML frontmatter starting with `---`

- [ ] **Step 3: Commit**

```bash
git add claude-plugin/commands/autoresearch.md
git commit -m "feat: integrate Stop hook activation into autoresearch command"
```

---

### Task 6: Update SKILL.md with hook documentation

**Files:**
- Modify: `claude-plugin/skills/autoresearch/SKILL.md:536-561`

Add a section explaining the Stop hook behavior so Claude understands it will be mechanically prevented from exiting.

- [ ] **Step 1: Add Stop Hook section after "The Loop" section**

After line 561 (the closing ``` of The Loop section), insert:

```markdown

## Stop Hook (Mechanical Loop Enforcement)

Autoresearch uses a **Stop hook** to mechanically prevent the session from ending during the autonomous loop. This is NOT a prompt instruction — it is a runtime mechanism that intercepts exit attempts.

### How It Works

1. After interactive setup completes, `setup-loop.sh` creates `.claude/autoresearch-loop.local.md`
2. This state file activates the Stop hook
3. Every time you try to exit, the hook:
   - Reads the state file
   - Checks if max iterations reached → if yes, allows exit
   - Otherwise → blocks exit and re-injects the loop prompt
   - Increments the iteration counter

### What This Means For You

- **You cannot exit the loop by stopping.** The hook will restart you.
- **You do not need to ask "should I continue?"** — the hook handles continuation.
- **Focus on the current iteration only.** Do Phase 1-8, then let the hook handle the restart.
- **If truly blocked** (missing permissions, broken environment), output a clear error message. The user can run `/autoresearch:cancel` to stop the loop.

### State File Location

`.claude/autoresearch-loop.local.md` — contains YAML frontmatter with loop config (goal, scope, metric, verify, guard, iteration count) and the re-injection prompt.

### Stopping the Loop

- `/autoresearch:cancel` — removes state file, loop stops on next exit
- Max iterations reached — hook auto-removes state file
- User manually deletes `.claude/autoresearch-loop.local.md`
```

- [ ] **Step 2: Commit**

```bash
git add claude-plugin/skills/autoresearch/SKILL.md
git commit -m "docs: add Stop Hook documentation to SKILL.md"
```

---

### Task 7: Sync .claude/ dev copies

**Files:**
- Modify: `.claude/commands/autoresearch/` (dev copies)
- Modify: `.claude/skills/autoresearch/` (dev copies)

The project maintains dev copies under `.claude/` for local testing. Sync the changes.

- [ ] **Step 1: Copy updated command files to dev directory**

```bash
cp claude-plugin/commands/autoresearch.md .claude/commands/autoresearch.md
cp claude-plugin/commands/autoresearch/cancel.md .claude/commands/autoresearch/cancel.md
```

- [ ] **Step 2: Copy hooks and scripts to dev directory**

```bash
mkdir -p .claude/hooks .claude/scripts
cp claude-plugin/hooks/hooks.json .claude/hooks/hooks.json
cp claude-plugin/hooks/stop-hook.sh .claude/hooks/stop-hook.sh
cp claude-plugin/scripts/setup-loop.sh .claude/scripts/setup-loop.sh
chmod +x .claude/hooks/stop-hook.sh .claude/scripts/setup-loop.sh
```

- [ ] **Step 3: Copy updated SKILL.md**

```bash
cp claude-plugin/skills/autoresearch/SKILL.md .claude/skills/autoresearch/SKILL.md
```

- [ ] **Step 4: Commit**

```bash
git add .claude/commands/ .claude/hooks/ .claude/scripts/ .claude/skills/
git commit -m "chore: sync dev copies with Stop hook changes"
```

---

### Task 8: End-to-end integration test

**Files:**
- No files created or modified — this is a manual verification task

- [ ] **Step 1: Verify plugin structure is complete**

Run: `find claude-plugin/ -type f | sort`
Expected output should include:
```
claude-plugin/.claude-plugin/plugin.json
claude-plugin/commands/autoresearch.md
claude-plugin/commands/autoresearch/cancel.md
claude-plugin/commands/autoresearch/debug.md
claude-plugin/commands/autoresearch/fix.md
claude-plugin/commands/autoresearch/learn.md
claude-plugin/commands/autoresearch/plan.md
claude-plugin/commands/autoresearch/predict.md
claude-plugin/commands/autoresearch/scenario.md
claude-plugin/commands/autoresearch/security.md
claude-plugin/commands/autoresearch/ship.md
claude-plugin/hooks/hooks.json
claude-plugin/hooks/stop-hook.sh
claude-plugin/scripts/setup-loop.sh
claude-plugin/skills/autoresearch/SKILL.md
claude-plugin/skills/autoresearch/references/...
```

- [ ] **Step 2: Test full setup → hook → cancel flow**

```bash
# 1. Create state file
bash claude-plugin/scripts/setup-loop.sh \
  --goal "test coverage" \
  --scope "src/**/*.ts" \
  --metric "coverage %" \
  --direction higher \
  --verify "npm test -- --coverage" \
  --max-iterations 5

# 2. Verify state file exists
test -f .claude/autoresearch-loop.local.md && echo "STATE FILE: OK"

# 3. Simulate 3 stop-hook iterations
for i in 1 2 3; do
  echo '{}' | bash claude-plugin/hooks/stop-hook.sh > /dev/null
  echo "Iteration after hook: $(grep 'iteration:' .claude/autoresearch-loop.local.md)"
done

# 4. Verify iteration incremented correctly
grep 'iteration:' .claude/autoresearch-loop.local.md
# Expected: iteration: 3

# 5. Clean up
rm -f .claude/autoresearch-loop.local.md
```

Expected: State file created, iteration increments from 0→1→2→3, no errors

- [ ] **Step 3: Test max iteration exit**

```bash
# Create state at iteration 4 of 5
bash claude-plugin/scripts/setup-loop.sh \
  --goal "test" --scope "src/" --metric "count" \
  --direction higher --verify "echo 1" --max-iterations 5

# Fast-forward to iteration 4
sed -i '' 's/^iteration: .*/iteration: 4/' .claude/autoresearch-loop.local.md

# Next hook should increment to 5 and block
echo '{}' | bash claude-plugin/hooks/stop-hook.sh > /dev/null
echo "After iter 5: $(grep 'iteration:' .claude/autoresearch-loop.local.md 2>/dev/null || echo 'STATE FILE REMOVED')"

# Next hook should hit max (5+1 > 5) and allow exit
echo '{}' | bash claude-plugin/hooks/stop-hook.sh 2>&1
echo "EXIT: $?"

# Verify state file removed
test -f .claude/autoresearch-loop.local.md && echo "STILL EXISTS" || echo "REMOVED: OK"
```

Expected: Iteration reaches 5, next attempt removes state file, EXIT: 0, "REMOVED: OK"

- [ ] **Step 4: Clean up test artifacts**

```bash
rm -f .claude/autoresearch-loop.local.md
```

- [ ] **Step 5: Final commit with version bump in plugin.json**

Update version from 1.8.2 to 1.9.0 in `claude-plugin/.claude-plugin/plugin.json` (minor version bump for new feature), then:

```bash
git add claude-plugin/.claude-plugin/plugin.json
git commit -m "feat: bump version to 1.9.0 for Stop hook integration"
```
