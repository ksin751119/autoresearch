#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: setup-loop.sh --goal GOAL --prompt PROMPT [OPTIONS]

Creates .claude/autoresearch-loop.local.md to activate the Stop hook loop.

Required:
  --goal            What to achieve
  --prompt          Full prompt to re-inject each iteration

Optional:
  --guard           Shell command that must always pass
  --verify          Shell command that extracts a metric number
  --direction       "higher" or "lower" (required if --verify set)
  --max-iterations  Stop after N iterations, 0 = unlimited (default: 0)
  --completion-promise  Semantic exit condition text
  --evaluator       "on" or "off" (default: on)
  --max-rework      Max rework attempts on evaluator rejection (default: 2)
  -h, --help        Show this help
USAGE
  exit 0
}

GOAL="" PROMPT="" GUARD="" VERIFY="" DIRECTION=""
MAX_ITERATIONS=0 COMPLETION_PROMISE="null" EVALUATOR="on" MAX_REWORK="2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --goal)                GOAL="$2";                shift 2 ;;
    --prompt)              PROMPT="$2";              shift 2 ;;
    --guard)               GUARD="$2";               shift 2 ;;
    --verify)              VERIFY="$2";              shift 2 ;;
    --direction)           DIRECTION="$2";           shift 2 ;;
    --max-iterations)      MAX_ITERATIONS="$2";      shift 2 ;;
    --completion-promise)  COMPLETION_PROMISE="$2";  shift 2 ;;
    --evaluator)           EVALUATOR="$2";           shift 2 ;;
    --max-rework)          MAX_REWORK="$2";          shift 2 ;;
    -h|--help)             usage ;;
    *)                     echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$GOAL" ]]; then
  echo "Error: --goal is required" >&2
  exit 1
fi
if [[ -z "$PROMPT" ]]; then
  echo "Error: --prompt is required" >&2
  exit 1
fi
if [[ "$MAX_ITERATIONS" != "0" ]] && ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Error: --max-iterations must be a non-negative integer, got: $MAX_ITERATIONS" >&2
  exit 1
fi

yaml_escape() {
  local val="$1"
  if [[ "$val" == *$'\n'* ]] || [[ "$val" == *':'* ]] || [[ "$val" == *'"'* ]] || [[ "$val" == *"'"* ]]; then
    echo "\"$(echo "$val" | sed 's/"/\\"/g')\""
  else
    echo "$val"
  fi
}

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  CP_YAML="\"$COMPLETION_PROMISE\""
else
  CP_YAML="null"
fi

FULL_PROMPT="MANDATORY FIRST STEP: Read .autoresearch/context.md before any action. If it doesn't exist yet, create it with initial state.

${PROMPT}"

mkdir -p .claude
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-unknown}"

cat > .claude/autoresearch-loop.local.md <<EOF
---
active: true
iteration: 0
session_id: ${SESSION_ID}
max_iterations: ${MAX_ITERATIONS}
goal: $(yaml_escape "$GOAL")
completion_promise: ${CP_YAML}
guard: $(yaml_escape "$GUARD")
verify: $(yaml_escape "$VERIFY")
direction: ${DIRECTION}
evaluator: ${EVALUATOR}
max_rework: ${MAX_REWORK}
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

${FULL_PROMPT}
EOF

echo ""
echo "🔬 Autoresearch loop activated!"
echo "   Goal:                ${GOAL}"
if [[ -n "$GUARD" ]]; then echo "   Guard:              ${GUARD}"; fi
if [[ -n "$VERIFY" ]]; then echo "   Verify:             ${VERIFY} (${DIRECTION} is better)"; fi
echo "   Evaluator:          ${EVALUATOR}"
echo "   Max-Rework:         ${MAX_REWORK}"
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then echo "   Max iterations:     ${MAX_ITERATIONS}"; else echo "   Max iterations:     unlimited"; fi
if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "   Completion promise: ${COMPLETION_PROMISE}"; fi
echo "   Session:            ${SESSION_ID}"
echo ""
echo "The Stop hook will keep this session looping until:"
if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "  - Completion promise is fulfilled, OR"; fi
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then echo "  - ${MAX_ITERATIONS} iterations complete, OR"; fi
echo "  - You run /autoresearch:cancel"
echo ""
