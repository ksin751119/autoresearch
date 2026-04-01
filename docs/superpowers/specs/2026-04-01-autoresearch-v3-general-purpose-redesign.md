# Autoresearch v3.0 — General-Purpose Autonomous Iteration Redesign

**Date:** 2026-04-01
**Status:** Draft
**Author:** AlbertLin + Claude
**Supersedes:** v2.0.0 (Harness Evaluator Integration)

## Problem Statement

Autoresearch v2.0 is designed around code optimization with mechanical metrics. This creates three failure modes when used for non-metric tasks:

1. **Setup Gate bypass** — AI skips the 5 required parameters (Goal, Scope, Metric, Direction, Verify) when the task doesn't have a numerical metric, and jumps straight into user-provided workflow steps
2. **Hook never activates** — Without Setup completing, state file is never created, Stop Hook never fires, loop has no mechanical enforcement
3. **Protocol collision** — User-provided workflow steps conflict with the hardcoded 8-phase protocol, causing the AI to follow neither correctly

**Evidence:** When using `/autoresearch` with a custom brickie ops workflow (12-step monitoring/optimization loop), the AI:
- Skipped Setup Gate entirely
- Did not use the Stop Hook
- Said "wait 30 minutes for next round" and stopped (no mechanical loop enforcement)

## Design Goals

1. **Task-agnostic loop** — Work with ANY task, not just code optimization with metrics
2. **Multi-agent team** — Coordinator, Research, Dev, Evaluator with trust boundaries
3. **Self-evolving knowledge** — Living context document updated each iteration, not append-only logs
4. **Mechanical loop enforcement** — Hook-based, with semantic exit support (completion promise)
5. **Backward compatible** — Existing metric-mode usage still works
6. **Lean SKILL.md** — ~200 lines max, detailed protocols in reference files per agent

## Key Influences

- **From Ralph Loop:** Task-agnostic hook, prompt passthrough (replay original prompt), completion promise via transcript reading, zero-friction setup
- **From Autoresearch v2:** Git as memory, Evaluator subagent, experiment tracking, Guard regression checks, baseline verification
- **New:** Multi-agent team, living knowledge document, config/prompt separation

## Architecture

```
User prompt (Goal + Workflow + Notes)     Config flags (--guard, --verify, etc.)
            │                                          │
            ▼                                          ▼
    ┌──────────────────────────────────────────────────────┐
    │                    State File                        │
    │  YAML frontmatter: config flags (mechanical)         │
    │  Body: user's original prompt (semantic, untouched)  │
    └────────────────────────┬─────────────────────────────┘
                             │
                             ▼
    ┌──────────────────────────────────────────────────────┐
    │                    Stop Hook                         │
    │  1. Check completion promise (read transcript)       │
    │  2. Check max_iterations                             │
    │  3. Re-inject prompt + systemMessage                 │
    └────────────────────────┬─────────────────────────────┘
                             │
                             ▼
    ┌──────────────────────────────────────────────────────┐
    │              Coordinator Agent (main)                 │
    │                                                      │
    │  1. Read autoresearch-context.md                     │
    │  2. Decide what to do this iteration                 │
    │  3. Dispatch subagents                               │
    │  4. Review subagent outputs (don't blindly trust)    │
    │  5. Keep / Discard / Rework decision                 │
    │  6. Update autoresearch-context.md                   │
    │  7. Update memory (cross-session findings only)      │
    │  8. Exit → Hook catches → next iteration             │
    │                                                      │
    │  ┌──────────┐  ┌──────────┐  ┌──────────────┐       │
    │  │ Research  │  │   Dev    │  │  Evaluator   │       │
    │  │  Agent    │  │  Agent   │  │    Agent     │       │
    │  └──────────┘  └──────────┘  └──────────────┘       │
    └──────────────────────────────────────────────────────┘
                             │
                             ▼
    ┌──────────────────────────────────────────────────────┐
    │                Knowledge System                      │
    │                                                      │
    │  L1: Hook prompt         — guaranteed every iteration│
    │  L2: context.md          — updated every iteration   │
    │  L3: Memory              — cross-session persistence │
    └──────────────────────────────────────────────────────┘
```

## User Interface

### Prompt Format

The user's prompt is stored in the state file and replayed verbatim each iteration. It contains semantic information that Claude interprets.

```
/autoresearch "
Goal: <what to achieve — REQUIRED>

Workflow:
1. <step 1>
2. <step 2>
...

Notes:
- <constraint or rule>
- <things to avoid>
" [--flags]
```

- **Goal** is the only required field
- **Workflow** is optional — if omitted, Coordinator decides each iteration's approach autonomously
- **Notes** is optional — constraints, rules, things to watch out for

### Config Flags

Config flags are mechanical constraints parsed by the hook and setup script. They go in CLI flags, not in the prompt.

| Flag | Required | Default | Purpose |
|------|----------|---------|---------|
| `--max-iterations N` | No | 0 (unlimited) | Count-based exit |
| `--completion-promise "TEXT"` | No | none | Semantic exit — hook reads transcript for `<promise>TEXT</promise>` |
| `--guard "CMD"` | No | none | Shell command that must pass every iteration (regression check) |
| `--verify "CMD"` | No | none | Shell command that extracts a metric number |
| `--direction higher\|lower` | If verify set | none | Whether metric should increase or decrease |
| `--evaluator on\|off` | No | on | Enable/disable Evaluator agent |
| `--max-rework N` | No | 2 | Max rework attempts on Evaluator rejection |

### Backward Compatibility

If the prompt contains `Metric:`, `Direction:`, `Verify:`, and `Scope:` fields (v2 format), the Coordinator automatically activates metric mode with the v2 8-phase protocol. Existing usage patterns work without changes.

## Setup Flow

### Interactive Setup (lightweight, one-batch)

```
/autoresearch [prompt] [--flags]
    ↓
Parse prompt + flags → pre-fill known fields
    ↓
Show all fields in one batch:
  - Known fields: pre-filled, user can accept or change
  - Unknown fields: user fills or skips (optional fields)
    ↓
Show confirmation summary
    ↓
[Launch / Edit / Cancel]
    ↓
Launch → setup.sh creates state file → Hook activates → iteration 1
```

### Setup Questions (one batch)

```
Please configure the autoresearch loop:

1. Goal (required): ___  ← pre-filled from prompt if available
2. Workflow (steps per iteration, skip → Coordinator decides):
   > ___
3. Notes (constraints/rules, skip → none):
   > ___
4. Guard (shell command that must always pass, skip → none):
   > ___
5. Verify + Direction (metric command + higher/lower, skip → no metric):
   > ___
6. Max Iterations (number, skip → unlimited):
   > ___
7. Completion Promise (semantic exit condition, skip → none):
   > ___
8. Evaluator (on/off, skip → on):
   > ___
```

Fields already provided via prompt or flags are pre-filled and shown. User confirms or modifies.

### Confirmation Summary

Always shown before launch, even if all fields were provided inline:

```
Configuration Summary:

  Goal:                <value>

  Workflow:
    1. <step>
    2. <step>
    ...
  (or: "default — Coordinator decides each iteration")

  Notes:
    - <note>
    - <note>
  (or: "none")

  Guard:               <command or "none">
  Verify:              <command or "none">
  Direction:           <higher/lower or "n/a">
  Evaluator:           on
  Max-Rework:          2
  Max Iterations:      <N or "unlimited">
  Completion Promise:  <text or "none">

  Agent Team:
    - Coordinator: manage loop, dispatch agents, update knowledge
    - Research:    analyze data, find root causes
    - Dev:         implement solutions, commit, verify
    - Evaluator:   independent quality review

  ⚠️  Warnings (if any):
    - No exit criteria set — loop runs forever until /autoresearch:cancel
    - No guard set — no regression protection

Ready? [Launch / Edit / Cancel]
```

## State File

### Format

```yaml
---
active: true
iteration: 0
session_id: <CLAUDE_CODE_SESSION_ID>
max_iterations: <N or 0>
goal: <extracted from prompt — used in systemMessage display>
completion_promise: <"text" or null>
guard: <"command" or "">
verify: <"command" or "">
direction: <"higher" or "lower" or "">
evaluator: <on or off>
max_rework: <N>
started_at: "<ISO 8601>"
---

<user's original prompt — stored verbatim, replayed each iteration>
```

### Key Design Decision: Prompt Passthrough

The user's prompt is stored exactly as provided and replayed each iteration (like Ralph). This means:
- User controls what Claude sees each iteration
- Custom workflows are preserved without transformation
- The hook doesn't need to understand the task semantics

## Stop Hook

### Enhanced Design

Combines Ralph's transcript reading with autoresearch's structured state:

```bash
#!/usr/bin/env bash
set -uo pipefail

STATE_FILE=".claude/autoresearch-loop.local.md"

# 1. No state file → allow exit
[[ ! -f "$STATE_FILE" ]] && exit 0

# 2. Parse frontmatter
ACTIVE=$(parse_field "active")
[[ "$ACTIVE" != "true" ]] && exit 0

# 3. Session isolation
# (same as v2 — only block the session that started the loop)

# 4. Check completion promise (NEW — from Ralph)
COMPLETION_PROMISE=$(parse_field "completion_promise")
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
  LAST_OUTPUT=$(extract_last_assistant_text "$TRANSCRIPT_PATH")
  PROMISE_TEXT=$(extract_promise_tag "$LAST_OUTPUT")
  if [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    rm -f "$STATE_FILE"
    exit 0  # Promise fulfilled → allow exit
  fi
fi

# 5. Check max iterations
ITERATION=$(parse_field "iteration")
MAX_ITERATIONS=$(parse_field "max_iterations")
NEXT_ITERATION=$((ITERATION + 1))
if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$NEXT_ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  rm -f "$STATE_FILE"
  exit 0  # Max reached → allow exit
fi

# 6. Increment iteration
sed "s/^iteration: .*/iteration: ${NEXT_ITERATION}/" "$STATE_FILE" > tmp && mv tmp "$STATE_FILE"

# 7. Re-inject prompt
PROMPT=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$STATE_FILE")
GOAL=$(parse_field "goal")  # extracted from prompt for display

SYS_MSG="🔬 Autoresearch iteration ${NEXT_ITERATION}"
[[ "$MAX_ITERATIONS" -gt 0 ]] && SYS_MSG="${SYS_MSG}/${MAX_ITERATIONS}"
SYS_MSG="${SYS_MSG} | Goal: ${GOAL} | To stop: /autoresearch:cancel"

jq -n --arg d "block" --arg r "$PROMPT" --arg s "$SYS_MSG" \
  '{"decision":$d,"reason":$r,"systemMessage":$s}'
```

### What the Hook Does NOT Do

- Does NOT run guard/verify commands (those happen inside the iteration, managed by Coordinator/Dev)
- Does NOT modify the prompt (replays verbatim)
- Does NOT track task-specific state (only iteration counter + exit criteria)

## Agent Team

### Coordinator (Main Agent)

**Role:** Orchestrator. Does not write code. Manages the iteration lifecycle.

**Responsibilities:**
1. Read `autoresearch-context.md` at iteration start
2. Interpret user's Workflow to decide what this iteration does
3. Dispatch Research/Dev/Evaluator agents as needed
4. Review every subagent output — never blindly trust
5. Make final Keep/Discard/Rework decisions
6. Run guard command (if set) after Dev completes
7. Run verify command (if set) for metric tracking
8. Update `autoresearch-context.md` at iteration end
9. Save cross-session findings to memory system
10. Output `<promise>` tag when completion promise is genuinely true

**Protocol:** `references/coordinator-protocol.md`

**Trust Rules:**
- Research output: verify conclusions have evidence before passing to Dev
- Dev output: always send to Evaluator (if enabled), never accept without review
- Evaluator output: can override with explicit justification (rare)

### Research Agent (Subagent)

**Role:** Analyst. Investigates, diagnoses, proposes.

**Responsibilities:**
- Analyze logs, data, codebase
- Identify issues and root causes with evidence
- Propose solutions ranked by impact

**Input from Coordinator:**
- Task description (what to analyze)
- Relevant context from `autoresearch-context.md`
- Specific files/logs to examine

**Output to Coordinator:**
- Structured analysis report: findings, evidence, proposed solutions

**Protocol:** `references/research-agent-protocol.md`

**Trust Boundary:** Coordinator reviews analysis for evidence. If a conclusion lacks evidence, Coordinator asks for more data or disregards.

### Dev Agent (Subagent)

**Role:** Implementer. Writes code, makes changes, verifies.

**Responsibilities:**
- Implement the solution specified by Coordinator
- Make atomic changes (one logical change per dispatch)
- Git commit with descriptive message
- Run verification if Coordinator requests

**Input from Coordinator:**
- Solution to implement (from Research analysis or Coordinator's decision)
- Specific files to modify
- Verification commands to run

**Output to Coordinator:**
- Implementation summary
- Git diff
- Verification results (if applicable)

**Protocol:** `references/dev-agent-protocol.md`

**Trust Boundary:** Evaluator reviews all Dev output. Coordinator checks verification results.

### Evaluator Agent (Subagent)

**Role:** Independent reviewer. Challenges, questions, catches blind spots.

**Responsibilities:**
- Review Dev's implementation for quality, edge cases, side effects
- Question Research's analysis for gaps or flawed assumptions
- Check compliance with user's Notes/Guard constraints
- Provide verdict: pass or fail with specific critique

**Input from Coordinator:**
- Git diff of Dev's changes
- Research analysis that led to the changes
- User's Goal + Notes + Guard constraints
- Previous critique (if this is a rework)

**Output to Coordinator:**
```json
{
  "verdict": "pass | fail",
  "critique": "specific issues found",
  "suggestions": ["actionable fix 1", "actionable fix 2"],
  "risk_flags": ["potential-issue-1"]
}
```

**Protocol:** `references/evaluator-protocol.md`

**Trust Boundary:** Coordinator makes the final decision. Evaluator's fail verdict triggers rework (up to max_rework), then discard.

### Iteration Flow

```
Hook re-injects prompt
    │
    ▼
Coordinator reads autoresearch-context.md
    │
    ▼
Coordinator interprets Workflow → decides what to do this iteration
    │
    ├── Analysis needed? ──→ spawn Research Agent
    │                              │
    │                              ▼
    │                     Coordinator reviews analysis
    │                     (has evidence? reasonable?)
    │                              │
    ▼                              ▼
    ├── Implementation needed? ─→ spawn Dev Agent
    │                              (with analysis context)
    │                              │
    │                              ▼
    │                     Dev commits + reports results
    │                              │
    │                              ▼
    │                     Coordinator runs guard (if set)
    │                     Coordinator runs verify (if set)
    │                              │
    │                              ▼
    │                     spawn Evaluator Agent (if enabled)
    │                              │
    │                              ▼
    │                     Evaluator verdict
    │                              │
    │                     ┌────────┼────────┐
    │                     ▼        ▼        ▼
    │                   Pass    Fail+     Fail+
    │                   →Keep   rework    max reached
    │                           →Revert   →Discard
    │                           →Back to
    │                            Dev
    │
    ▼
Coordinator updates autoresearch-context.md
    │
    ▼
Coordinator updates memory (if cross-session finding)
    │
    ▼
Coordinator exits → Hook catches → next iteration or stop
```

**Not every iteration needs all agents.** Coordinator decides based on Workflow phase:
- Analysis phase → Research only
- Implementation phase → Dev + Evaluator
- Verification-only → Coordinator runs commands directly
- Knowledge update → Coordinator alone

## Knowledge System

### Layer 1: Hook Prompt (guaranteed injection)

The re-injected prompt includes a mandatory instruction to read context:

```
🔬 Autoresearch iteration 5/10 | Goal: ... | To stop: /autoresearch:cancel

MANDATORY FIRST STEP: Read autoresearch-context.md before any action.

[user's original prompt]
```

The `MANDATORY FIRST STEP` line is prepended by setup.sh when creating the state file. It's part of the stored prompt.

### Layer 2: autoresearch-context.md (living document)

**Location:** Project root or `.autoresearch/context.md`

**Format:**
```markdown
# Autoresearch Context
Last updated: iteration 4 | 2026-04-01 14:30

## Current State
Brief description of where things stand right now.

## Active Issues
- [ ] Issue description (impact: ...)
- [ ] Issue description (impact: ...)

## Resolved This Session
- [x] Issue description → fix description
- [x] Issue description → fix description

## Effective Strategies
- Strategy description → result

## Ineffective Strategies
- Strategy description → why it failed (commit: abc1234, reverted)

## Next Priority
What to focus on next iteration and why.
```

**Update Rules (enforced by Coordinator protocol):**
- Updated at the END of every iteration, not during
- Resolved issues move from Active to Resolved
- Resolved section capped at 5 most recent (older ones removed)
- Total size kept under ~1000 words
- Each entry is a summary, not a detailed log

### Layer 3: Memory (cross-session persistence)

Uses the existing `.claude/projects/*/memory/` system.

**What to save:** Only findings that remain valuable across sessions:
- Architectural discoveries ("pool X requires special routing")
- Hard constraints discovered empirically ("pipeline must be <1s")
- Optimal parameters ("gas buffer 15% is sweet spot")

**What NOT to save:** Per-iteration details, temporary state, things already in context.md.

## Exit Criteria

Priority order (hook checks in this sequence):

1. **Completion Promise** — `<promise>TEXT</promise>` in Claude's output matches `completion_promise` config → stop
2. **Max Iterations** — `iteration >= max_iterations` → stop
3. **Manual Cancel** — `/autoresearch:cancel` removes state file → stop on next exit
4. **None matched** — continue loop

### Completion Promise Rules

Adopted from Ralph Loop:
- Coordinator may ONLY output `<promise>TEXT</promise>` when the statement is genuinely true
- Must NOT output false promises to escape the loop
- Hook uses exact string matching (case-sensitive, whitespace-normalized)
- If no completion promise is set, this check is skipped

## SKILL.md Restructure

### Target: ~200 lines

Current v2.0 SKILL.md is ~700 lines. v3.0 splits into:

```
SKILL.md (~200 lines)
├── Overview & philosophy
├── User interface (prompt format + config flags)
├── Setup flow (interactive + confirmation)
├── Agent roles (brief — one paragraph each)
├── Critical rules (5-7 rules max)
├── Exit criteria
├── Pointers to reference files
└── Backward compatibility note

references/
├── coordinator-protocol.md     ← loaded by Coordinator
├── research-agent-protocol.md  ← loaded by Research agent
├── dev-agent-protocol.md       ← loaded by Dev agent
├── evaluator-protocol.md       ← loaded by Evaluator agent
├── knowledge-system.md         ← context.md format + update rules
├── autonomous-loop-protocol.md ← kept for v2 backward compat (metric mode)
├── results-logging.md          ← kept for v2 backward compat (metric mode)
├── core-principles.md          ← universal principles, still referenced
└── [domain]-workflow.md        ← kept as workflow preset sources
```

Each agent only loads its own protocol file — no agent needs the full 700 lines.

### Critical Rules (v3.0 — reduced from 10 to 7)

1. **Read context first** — Every iteration starts by reading `autoresearch-context.md`
2. **Dispatch, don't do** — Coordinator dispatches to subagents, does not write code itself
3. **Trust but verify** — Never blindly accept subagent output; review for evidence and quality
4. **One change per iteration** — Atomic changes. If it breaks, you know why
5. **Git is memory** — Commit before verify, revert on failure (use `git revert`, not `git reset`)
6. **Update knowledge** — End every iteration by updating `autoresearch-context.md`
7. **Autonomous decisions** — All decisions made by agents based on evidence. Only ask user when truly blocked by missing access/permissions

## Sub-skills

Existing sub-skills (debug, fix, security, ship, scenario, predict, learn) become **workflow presets** that pre-fill the Workflow field:

```bash
/autoresearch:debug  →  pre-fills Workflow with scientific-method debugging steps
/autoresearch:fix    →  pre-fills Workflow with error-fixing steps
/autoresearch:security → pre-fills Workflow with STRIDE/OWASP steps
```

Each sub-skill's reference file becomes a Workflow template + domain-specific Notes. The core loop mechanism is identical — only the Workflow content changes.

## Migration Path

### v2.0 → v3.0

1. **Hook:** Add transcript reading (completion promise) from Ralph
2. **Setup:** Replace mandatory 5-field Q&A with one-batch optional setup
3. **State file:** Simplify — remove scope/metric/direction from frontmatter (move to prompt body if needed)
4. **SKILL.md:** Rewrite to ~200 lines, extract agent protocols to reference files
5. **Agent team:** Implement Coordinator/Research/Dev/Evaluator dispatch pattern
6. **Knowledge:** Add `autoresearch-context.md` system, update Coordinator protocol
7. **Sub-skills:** Convert to workflow presets

### Breaking Changes

- `Scope`, `Metric`, `Direction`, `Verify` no longer required fields (still usable via --verify/--direction flags or in prompt body)
- Setup flow no longer asks 5 mandatory questions
- 8-phase protocol no longer hardcoded — replaced by user-defined or default Workflow
- Results logging format may change (context.md replaces TSV as primary knowledge store)

## Design Decisions (Resolved)

1. **context.md location:** `.autoresearch/context.md` — keeps project root clean, groups all autoresearch artifacts together
2. **Cross-iteration Workflow state:** `context.md` tracks which Workflow steps have been completed. Coordinator reads this at iteration start and continues from where it left off.

## Open Questions

1. **Parallel agents:** Can Research and Dev run in parallel for independent tasks, or always sequential?
2. **Agent failure:** If a subagent crashes or returns garbage, how does Coordinator recover?
3. **Sub-skill Evaluator defaults:** Should debug/fix/security have Evaluator on or off by default?
