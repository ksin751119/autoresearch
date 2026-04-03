---
name: autoresearch
description: "Autonomous Goal-directed Iteration. Loops autonomously with multi-agent team — Research, Dev, Evaluator. Works with ANY task. Use when: (1) iterating autonomously on improvements, (2) running overnight optimization loops, (3) any task needing repeated modify-verify-keep/discard cycles. Triggers: \"iterate autonomously\", \"keep improving\", \"run overnight\", \"autonomous loop\", \"work autonomously\"."
---

# Autoresearch — Autonomous Goal-directed Iteration

Autonomous iteration engine. Define a goal, optionally a workflow, and let the agent team loop: analyze → implement → evaluate → keep/discard → repeat.

## Quick Start

**Option 1: Interactive wizard (recommended)**
```
/autoresearch:setup "your goal here"
```
The wizard asks one question at a time and generates `.autoresearch/config.yaml`.

**Option 2: Write config manually**
```yaml
# .autoresearch/config.yaml
goal: "what to achieve"

workflow:
  - step 1
  - step 2

notes:
  - constraint

max_iterations: 10
completion_promise: "Done"
```

Then run:
```
/autoresearch --config .autoresearch/config.yaml
```

**`goal` is the only required field.** Everything else is optional.

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

## Config Fields

All fields are set in `.autoresearch/config.yaml`. Only `goal` is required.

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `goal` | string | **(required)** | What to achieve |
| `workflow` | list | Coordinator decides | Ordered steps per iteration |
| `notes` | list | none | Constraints for Pre-Dev Gate and Post-iteration Reviewer to enforce |
| `max_iterations` | integer | unlimited | Count-based exit |
| `completion_promise` | string | none | Semantic exit — output `<promise>TEXT</promise>` when true |
| `guard` | string | none | Shell command — regression check (must pass every iteration) |
| `verify` | string | none | Shell command — metric extraction |
| `direction` | `higher`/`lower` | (with verify) | Metric direction |
| `evaluator` | `on`/`off` | `on` | Enable/disable Evaluator |
| `max_rework` | integer | `2` | Rework attempts before discard |

## Agent Team

| Agent | Role | Protocol |
|-------|------|----------|
| **Coordinator** (you) | Orchestrate loop, dispatch agents, manage knowledge | `references/coordinator-protocol.md` |
| **Pre-Dev Gate** | Lightweight workflow/notes check before Dev dispatch | `references/pre-dev-gate-protocol.md` |
| **Research** | Analyze, investigate, diagnose | `references/research-agent-protocol.md` |
| **Dev** | Implement, commit, verify | `references/dev-agent-protocol.md` |
| **Evaluator** | Independent review, challenge assumptions | `references/evaluator-protocol.md` |
| **Post-iteration Reviewer** | Review previous iteration's notes compliance + quality | `references/post-iteration-reviewer-protocol.md` |

**Read your protocol file** at the start of the first iteration.

**Trust boundaries:**
- Pre-Dev Gate BLOCK → Coordinator must comply (High trust)
- Post-iteration Reviewer FAIL → Coordinator must fix before continuing (High trust)
- Research output → Coordinator verifies evidence exists
- Dev output → Evaluator reviews independently
- Evaluator output → Coordinator makes final decision

## The Loop

```
LOOP:
  1. Dispatch Post-iteration Reviewer (reviews PREVIOUS iteration — hook-injected, skipped on first)
  2. Read .autoresearch/context.md (mandatory — knowledge from past iterations)
  3. Decide + Research: what does this iteration do? Dispatch Research if analysis needed.
  4. Pre-Dev Gate + Dev: validate workflow alignment, then dispatch Dev if implementation needed.
  5. Evaluator: dispatch if Dev was used and evaluator=on.
  6. Decide: Keep / Discard / Rework (mandatory if Dev was dispatched).
  7. Update: context.md + knowledge.md + memory (mandatory).
  8. Exit → Hook runs mechanical checks → blocks if failed → re-injects → next iteration.

  Enforcement: stop-hook.sh validates mechanical checks (script-enforced).
  Pre-Dev Gate validates workflow alignment (1 subagent, before irreversible action).
  Post-iteration Reviewer validates notes compliance (1 subagent, after iteration).
```

## Knowledge System

See `references/knowledge-system.md` for full protocol.

- **L1: Hook prompt** — guaranteed every iteration (user's original prompt)
- **L2: .autoresearch/context.md** — current state + next action, updated every iteration
- **L3: .autoresearch/knowledge.md** — cumulative domain findings, organized by topic
- **L4: Memory** — cross-session persistence for important discoveries

## Reference Map

| Category | Files | When to load |
|----------|-------|-------------|
| Agent protocols | coordinator, research, dev, evaluator, pre-dev-gate, post-iteration-reviewer | First iteration of any loop |
| Workflow presets | debug, fix, security, ship, scenario, predict, learn, plan, setup | When specific sub-skill invoked |
| Output templates | security-output, predict-knowledge, learn-output, debug-reference-material, ship-domain-tables | When creating output files |
| Shared patterns | interactive-setup-pattern, core-principles, knowledge-system | As needed during setup or iteration |
| Legacy (v2) | autonomous-loop-protocol, results-logging, ml-metric-examples | Only when v2 inline config detected |

## Exit Criteria

Hook checks in order:
1. `<promise>TEXT</promise>` matches completion_promise → stop
2. iteration >= max_iterations → stop
3. `/autoresearch:cancel` → stop
4. None → continue

**Never lie in a promise tag.** Output `<promise>` ONLY when the statement is genuinely true.

## Critical Rules

1. **Pre-Dev Gate before Dev** — Dispatch Pre-Dev Gate agent before every Dev dispatch
2. **Read context first** — Every iteration starts by reading `.autoresearch/context.md`
3. **Dispatch, don't do** — Coordinator orchestrates, subagents execute
4. **Trust but verify** — Review subagent output for evidence and quality
5. **One change per iteration** — Atomic. Enforced by `stop-hook.sh` mechanical checks
6. **Git is memory** — Commit before verify, `git revert` (not reset) on failure
7. **Update knowledge** — End every iteration by updating context.md + knowledge.md. Enforced by `stop-hook.sh`
8. **Autonomous decisions** — Never ask user except for missing access/permissions

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
| `/autoresearch:setup` | Interactive YAML config wizard | `references/setup-workflow.md` |

## Superpowers Integration (Auto-Resolve)

See `references/coordinator-protocol.md` "Superpowers Integration (Auto-Resolve Mode)" for full scope.
Auto-resolve applies to human preference choices only — not Pre-Dev Gate BLOCKs, Post-iteration Review FAILs, or Evaluator fail verdicts.
