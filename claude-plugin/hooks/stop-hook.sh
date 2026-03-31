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

if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$NEXT_ITERATION" -ge "$MAX_ITERATIONS" ]]; then
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
