#!/usr/bin/env bash
set -uo pipefail

STATE_FILE=".claude/autoresearch-loop.local.md"
[[ ! -f "$STATE_FILE" ]] && exit 0

parse_field() {
  local field="$1"
  local value
  value=$(sed -n "/^---$/,/^---$/{ s/^${field}: *//p; }" "$STATE_FILE" | head -1)
  value="${value%\"}"
  value="${value#\"}"
  echo "$value"
}

ACTIVE=$(parse_field "active")
[[ "$ACTIVE" != "true" ]] && exit 0

HOOK_INPUT=$(cat)

SESSION_ID_STATE=$(parse_field "session_id")
HOOK_SESSION_ID=""
if command -v jq &>/dev/null; then
  HOOK_SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
fi
if [[ -n "$HOOK_SESSION_ID" ]] && [[ -n "$SESSION_ID_STATE" ]] && [[ "$SESSION_ID_STATE" != "unknown" ]]; then
  [[ "$HOOK_SESSION_ID" != "$SESSION_ID_STATE" ]] && exit 0
fi

ITERATION=$(parse_field "iteration")
MAX_ITERATIONS=$(parse_field "max_iterations")

if ! [[ "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Warning: autoresearch state file has invalid iteration: '$ITERATION'. Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi
if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: autoresearch state file has invalid max_iterations: '$MAX_ITERATIONS'. Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Check completion promise (NEW — from Ralph Loop)
COMPLETION_PROMISE=$(parse_field "completion_promise")
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  TRANSCRIPT_PATH=""
  if command -v jq &>/dev/null; then
    TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  fi
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100 || true)
    if [[ -n "$LAST_LINES" ]]; then
      set +e
      LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
        map(.message.content[]? | select(.type == "text") | .text) | last // ""
      ' 2>&1)
      JQ_EXIT=$?
      set -e
      if [[ $JQ_EXIT -eq 0 ]] && [[ -n "$LAST_OUTPUT" ]]; then
        PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
        if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
          echo "✅ Autoresearch: completion promise fulfilled — <promise>$COMPLETION_PROMISE</promise>" >&2
          rm -f "$STATE_FILE"
          exit 0
        fi
      fi
    fi
  fi
fi

# Check max iterations
NEXT_ITERATION=$((ITERATION + 1))
if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$NEXT_ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  echo "Autoresearch: max iterations ($MAX_ITERATIONS) reached." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Extract prompt
PROMPT=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$STATE_FILE")
if [[ -z "$PROMPT" ]]; then
  echo "Warning: autoresearch state file has no prompt. Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Increment iteration
TMPFILE=$(mktemp)
sed "s/^iteration: .*/iteration: ${NEXT_ITERATION}/" "$STATE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$STATE_FILE"

# Update commit_before to current HEAD for next iteration
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")
if [[ -n "$CURRENT_HEAD" ]]; then
  sed -i "s/^commit_before: .*/commit_before: \"${CURRENT_HEAD}\"/" "$STATE_FILE"
fi

# Update workflow_step from context.md if present
if [[ -f ".autoresearch/context.md" ]]; then
  COMPLETED_STEP=$(grep -oP 'Completed Step: \K\d+' .autoresearch/context.md 2>/dev/null | tail -1 || echo "")
  if [[ -n "$COMPLETED_STEP" ]]; then
    sed -i "s/^workflow_step: .*/workflow_step: ${COMPLETED_STEP}/" "$STATE_FILE"
  fi
fi

# Build system message
GOAL=$(parse_field "goal")
SYS_MSG="🔬 Autoresearch iteration ${NEXT_ITERATION}"
[[ "$MAX_ITERATIONS" -gt 0 ]] && SYS_MSG="${SYS_MSG}/${MAX_ITERATIONS}"
SYS_MSG="${SYS_MSG} | Goal: ${GOAL} | To stop: /autoresearch:cancel"

# Block exit and re-inject
if command -v jq &>/dev/null; then
  jq -n \
    --arg decision "block" \
    --arg reason "$PROMPT" \
    --arg systemMessage "$SYS_MSG" \
    '{"decision": $decision, "reason": $reason, "systemMessage": $systemMessage}'
else
  ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$PROMPT")
  ESCAPED_MSG=$(printf '%s' "$SYS_MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$SYS_MSG")
  echo "{\"decision\": \"block\", \"reason\": ${ESCAPED_PROMPT}, \"systemMessage\": ${ESCAPED_MSG}}"
fi
