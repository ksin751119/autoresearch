#!/usr/bin/env bash
set -euo pipefail

# setup-loop.sh — Creates state file from YAML config
# Usage: setup-loop.sh --config <path>

CONFIG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: setup-loop.sh --config <path>"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CONFIG" ]]; then
  echo "Error: --config is required" >&2
  exit 1
fi
if [[ ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

# Parse YAML and generate state file content via python3
mkdir -p .claude
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-unknown}"
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

python3 - "$CONFIG" "$SESSION_ID" "$STARTED_AT" <<'PYEOF' > .claude/autoresearch-loop.local.md
import yaml, sys

with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)

session_id = sys.argv[2]
started_at = sys.argv[3]

goal = cfg.get('goal', '')
workflow = cfg.get('workflow', []) or []
notes = cfg.get('notes', []) or []
max_iter = cfg.get('max_iterations', 0) or 0
promise = cfg.get('completion_promise', None)
guard = cfg.get('guard', '')  or ''
verify = cfg.get('verify', '') or ''
direction = cfg.get('direction', '') or ''
evaluator = cfg.get('evaluator', 'on')
# PyYAML parses bare 'on'/'off' as bool; convert back to string
if evaluator is True or evaluator is None:
    evaluator = 'on'
elif evaluator is False:
    evaluator = 'off'
else:
    evaluator = str(evaluator)
max_rework = cfg.get('max_rework', 2)

if max_rework is None: max_rework = 2

def esc(s):
    return s.replace('\\', '\\\\').replace('"', '\\"')

# Build YAML frontmatter
lines = []
lines.append('---')
lines.append('active: true')
lines.append('iteration: 0')
lines.append(f'session_id: {session_id}')
lines.append(f'max_iterations: {max_iter}')
lines.append(f'goal: "{esc(goal)}"')
if promise:
    lines.append(f'completion_promise: "{esc(promise)}"')
else:
    lines.append('completion_promise: null')
lines.append(f'guard: "{esc(guard)}"')
lines.append(f'verify: "{esc(verify)}"')
lines.append(f'direction: {direction}')
lines.append(f'evaluator: {evaluator}')
lines.append(f'max_rework: {max_rework}')
lines.append('commit_before: ""')
lines.append('workflow_step: 0')

if workflow:
    lines.append('workflow:')
    for step in workflow:
        lines.append(f'  - "{esc(step)}"')
else:
    lines.append('workflow: []')

if notes:
    lines.append('notes:')
    for note in notes:
        lines.append(f'  - "{esc(note)}"')
else:
    lines.append('notes: []')

lines.append(f'started_at: "{started_at}"')
lines.append('---')
lines.append('')

# Build prompt for hook re-injection
lines.append('MANDATORY FIRST STEP: Read .autoresearch/context.md before any action. If it does not exist yet, create it with initial state.')
lines.append('')
lines.append(f'Goal: {goal}')

if workflow:
    lines.append('')
    lines.append('Workflow:')
    for i, step in enumerate(workflow, 1):
        lines.append(f'{i}. {step}')

if notes:
    lines.append('')
    lines.append('Notes:')
    for note in notes:
        lines.append(f'- {note}')

lines.append('')

print('\n'.join(lines))
PYEOF

# Read back for display
# SAFETY: python3 outputs KEY=shlex.quote(VALUE) — safe for eval
eval "$(python3 - "$CONFIG" <<'PYEOF'
import yaml, sys, shlex

with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)

def val(key, default=''):
    v = cfg.get(key, default)
    if v is None: return str(default)
    if isinstance(v, bool): return 'on' if v else 'off'
    return str(v)

def count(key):
    v = cfg.get(key, [])
    return str(len(v) if isinstance(v, list) else 0)

print(f"GOAL={shlex.quote(val('goal'))}")
print(f"GUARD={shlex.quote(val('guard'))}")
print(f"VERIFY={shlex.quote(val('verify'))}")
print(f"DIRECTION={shlex.quote(val('direction'))}")
print(f"EVALUATOR={shlex.quote(val('evaluator', 'on'))}")
print(f"MAX_REWORK={shlex.quote(val('max_rework', '2'))}")
print(f"MAX_ITERATIONS={shlex.quote(val('max_iterations', '0'))}")
print(f"COMPLETION_PROMISE={shlex.quote(val('completion_promise'))}")
print(f"WORKFLOW_COUNT={shlex.quote(count('workflow'))}")
print(f"NOTES_COUNT={shlex.quote(count('notes'))}")
PYEOF
)"

echo ""
echo "🔬 Autoresearch loop activated!"
echo "   Config:             $CONFIG"
echo "   Goal:               $GOAL"
echo "   Workflow:           $WORKFLOW_COUNT steps"
echo "   Notes:              $NOTES_COUNT constraints"
if [[ -n "$GUARD" ]]; then echo "   Guard:              $GUARD"; fi
if [[ -n "$VERIFY" ]]; then echo "   Verify:             $VERIFY ($DIRECTION is better)"; fi
echo "   Evaluator:          $EVALUATOR"
echo "   Max-Rework:         $MAX_REWORK"
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then echo "   Max iterations:     $MAX_ITERATIONS"; else echo "   Max iterations:     unlimited"; fi
if [[ -n "$COMPLETION_PROMISE" ]]; then echo "   Completion promise: $COMPLETION_PROMISE"; fi
echo "   Session:            $SESSION_ID"
echo ""
echo "The Stop hook will keep this session looping until:"
if [[ -n "$COMPLETION_PROMISE" ]]; then echo "  - Completion promise is fulfilled, OR"; fi
if [[ "$MAX_ITERATIONS" -gt 0 ]]; then echo "  - $MAX_ITERATIONS iterations complete, OR"; fi
echo "  - You run /autoresearch:cancel"
echo ""
