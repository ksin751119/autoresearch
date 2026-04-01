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

python3 -c "
import yaml, sys

with open('$CONFIG') as f:
    cfg = yaml.safe_load(f)

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

# Build YAML frontmatter
lines = []
lines.append('---')
lines.append('active: true')
lines.append('iteration: 0')
lines.append('session_id: $SESSION_ID')
lines.append(f'max_iterations: {max_iter}')
lines.append(f'goal: \"{goal}\"')
if promise:
    lines.append(f'completion_promise: \"{promise}\"')
else:
    lines.append('completion_promise: null')
lines.append(f'guard: \"{guard}\"')
lines.append(f'verify: \"{verify}\"')
lines.append(f'direction: {direction}')
lines.append(f'evaluator: {evaluator}')
lines.append(f'max_rework: {max_rework}')

if workflow:
    lines.append('workflow:')
    for step in workflow:
        lines.append(f'  - \"{step}\"')
else:
    lines.append('workflow: []')

if notes:
    lines.append('notes:')
    for note in notes:
        lines.append(f'  - \"{note}\"')
else:
    lines.append('notes: []')

lines.append(f'started_at: \"$STARTED_AT\"')
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
" > .claude/autoresearch-loop.local.md

# Read back for display
GOAL=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); print(d.get('goal',''))")
GUARD=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); print(d.get('guard','') or '')")
VERIFY=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); print(d.get('verify','') or '')")
DIRECTION=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); print(d.get('direction','') or '')")
EVALUATOR=$(python3 -c "
import yaml
d = yaml.safe_load(open('$CONFIG'))
v = d.get('evaluator', 'on')
if v is True or v is None: print('on')
elif v is False: print('off')
else: print(str(v))
")
MAX_REWORK=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); v=d.get('max_rework',2); print(v if v is not None else 2)")
MAX_ITERATIONS=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); print(d.get('max_iterations',0) or 0)")
COMPLETION_PROMISE=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); print(d.get('completion_promise','') or '')")
WORKFLOW_COUNT=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); w=d.get('workflow',[]); print(len(w) if w else 0)")
NOTES_COUNT=$(python3 -c "import yaml; d=yaml.safe_load(open('$CONFIG')); n=d.get('notes',[]); print(len(n) if n else 0)")

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
