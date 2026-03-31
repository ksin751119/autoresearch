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
