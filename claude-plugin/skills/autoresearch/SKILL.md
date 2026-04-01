---
name: autoresearch
description: Autonomous Goal-directed Iteration. Loops autonomously with multi-agent team — Research, Dev, Evaluator. Works with ANY task.
version: 3.0.0
---

# Autoresearch — Autonomous Goal-directed Iteration

Autonomous iteration engine. Define a goal, optionally a workflow, and let the agent team loop: analyze → implement → evaluate → keep/discard → repeat.

## Quick Start

```
/autoresearch "
Goal: <what to achieve>

Workflow:
1. <step 1>
2. <step 2>

Notes:
- <constraint>
" --max-iterations 10 --completion-promise "Done"
```

**Goal** is the only required field. Everything else is optional.

## MANDATORY: Setup Confirmation

For ALL commands, before launching:

1. Parse user's prompt + flags
2. If ANY field is unclear or missing, ask via `AskUserQuestion` — show all fields in one batch:
   - Goal (required)
   - Workflow (optional — skip = Coordinator decides)
   - Notes (optional — skip = none)
   - Guard (optional — shell command, skip = none)
   - Verify + Direction (optional — metric command + higher/lower, skip = none)
   - Max Iterations (optional — skip = unlimited)
   - Completion Promise (optional — skip = none)
   - Evaluator (optional — skip = on)
3. Show Configuration Summary with ALL fields
4. User confirms: [Launch / Edit / Cancel]
5. Run `validate-config.sh` with provided fields
6. Run `setup-loop.sh` to create state file and activate hook
7. Begin first iteration

**Never skip confirmation.** Even if all fields are provided inline.

## Config Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `--max-iterations N` | unlimited | Count-based exit |
| `--completion-promise "TEXT"` | none | Semantic exit — output `<promise>TEXT</promise>` when true |
| `--guard "CMD"` | none | Regression check (must pass every iteration) |
| `--verify "CMD"` | none | Metric extraction command |
| `--direction higher\|lower` | (with verify) | Metric direction |
| `--evaluator on\|off` | on | Enable/disable Evaluator |
| `--max-rework N` | 2 | Rework attempts before discard |

## Agent Team

| Agent | Role | Protocol |
|-------|------|----------|
| **Coordinator** (you) | Orchestrate loop, dispatch agents, manage knowledge | `references/coordinator-protocol.md` |
| **Flow Reviewer** | Pre-action gate, flow enforcement, deviation reporting | `references/flow-reviewer-protocol.md` |
| **Research** | Analyze, investigate, diagnose | `references/research-agent-protocol.md` |
| **Dev** | Implement, commit, verify | `references/dev-agent-protocol.md` |
| **Evaluator** | Independent review, challenge assumptions | `references/evaluator-protocol.md` |

**Read your protocol file** at the start of the first iteration.

**Trust boundaries:**
- Flow Reviewer output → Coordinator must comply (High trust)
- Research output → Coordinator verifies evidence exists
- Dev output → Evaluator reviews independently
- Evaluator output → Coordinator makes final decision

## The Loop

```
LOOP:
  1. Read .autoresearch/context.md (mandatory — knowledge from past iterations)
  2. Ask Flow Reviewer → Decide: what does this iteration do?
  3. Ask Flow Reviewer → Dispatch: Research / Dev / Evaluator as needed
  4. Ask Flow Reviewer → Review: check subagent outputs
  5. Ask Flow Reviewer → Decide: Keep / Discard / Rework
  6. Ask Flow Reviewer → Update: context.md + knowledge.md + memory
  7. Exit → Hook re-injects → next iteration

  Flow Reviewer is dispatched BEFORE every phase. See references/flow-reviewer-protocol.md.
```

## Knowledge System

See `references/knowledge-system.md` for full protocol.

- **L1: Hook prompt** — guaranteed every iteration (user's original prompt)
- **L2: .autoresearch/context.md** — current state + next action, updated every iteration
- **L3: .autoresearch/knowledge.md** — cumulative domain findings, organized by topic
- **L4: Memory** — cross-session persistence for important discoveries

## Exit Criteria

Hook checks in order:
1. `<promise>TEXT</promise>` matches completion_promise → stop
2. iteration >= max_iterations → stop
3. `/autoresearch:cancel` → stop
4. None → continue

**Never lie in a promise tag.** Output `<promise>` ONLY when the statement is genuinely true.

## Critical Rules

1. **Ask Flow Reviewer first** — Dispatch Flow Reviewer before every phase transition
2. **Read context first** — Every iteration starts by reading `.autoresearch/context.md`
3. **Dispatch, don't do** — Coordinator orchestrates, subagents execute
4. **Trust but verify** — Review subagent output for evidence and quality
5. **One change per iteration** — Atomic. Enforced by `flow-check.sh commit-count`
6. **Git is memory** — Commit before verify, `git revert` (not reset) on failure
7. **Update knowledge** — End every iteration by updating context.md + knowledge.md
8. **Autonomous decisions** — Never ask user except for missing access/permissions

## Backward Compatibility

If the prompt contains `Metric:`, `Direction:`, `Verify:`, and `Scope:` fields (v2 format), activate **metric mode**: use `references/autonomous-loop-protocol.md` for the 8-phase protocol and `references/results-logging.md` for TSV logging. These files are kept for this purpose.

## Sub-skills

Sub-skills are workflow presets that pre-fill the Workflow field:

| Command | Preset | Reference |
|---------|--------|-----------|
| `/autoresearch:debug` | Scientific debugging | `references/debug-workflow.md` |
| `/autoresearch:fix` | Error fixing | `references/fix-workflow.md` |
| `/autoresearch:security` | STRIDE + OWASP audit | `references/security-workflow.md` |
| `/autoresearch:ship` | Shipping workflow | `references/ship-workflow.md` |
| `/autoresearch:scenario` | Scenario exploration | `references/scenario-workflow.md` |
| `/autoresearch:predict` | Multi-persona analysis | `references/predict-workflow.md` |
| `/autoresearch:learn` | Docs generation | `references/learn-workflow.md` |
| `/autoresearch:plan` | Config wizard | `references/plan-workflow.md` |

## Superpowers Integration (Auto-Resolve)

During the loop, use superpowers skills in auto-resolve mode: select approaches yourself, approve plans yourself, execute autonomously. The Evaluator subagent replaces human review.
