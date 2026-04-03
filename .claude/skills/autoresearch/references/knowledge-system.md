# Knowledge System Protocol

Autoresearch uses a 4-layer knowledge system to ensure context is preserved across iterations and sessions.

| Layer | File | Scope | Updated |
|-------|------|-------|---------|
| L1 | Hook prompt | User's original prompt | Every iteration (by hook) |
| L2 | `.autoresearch/context.md` | Current state + next action | End of every iteration |
| L3 | `.autoresearch/knowledge.md` | Cumulative domain findings | When reusable finding discovered |
| L4 | Memory (`~/.claude/projects/*/memory/`) | Cross-project learnings | When finding generalizes beyond project |

## Layer 1: Hook Prompt (Guaranteed Injection)

The Stop Hook re-injects the user's original prompt every iteration. This prompt is prepended with:

```
MANDATORY FIRST STEP: Read .autoresearch/context.md before any action. If it doesn't exist yet, create it with initial state.
```

This is the ONLY context delivery mechanism guaranteed to reach the agent every iteration.

## Layer 2: .autoresearch/context.md (Living Document)

**Location:** `.autoresearch/context.md` in the project root.

**Created by:** Coordinator at the start of the first iteration (if it doesn't exist).

**Updated by:** Coordinator at the END of every iteration.

### Format

```markdown
# Autoresearch Context
Last updated: iteration N | YYYY-MM-DD HH:MM

## Current State
Brief description of where things stand right now. 2-3 sentences max.

## Active Issues
- [ ] Issue description (impact: what this blocks or degrades)
- [ ] Issue description (impact: ...)

## Resolved This Session
- [x] Issue → fix applied (iteration N)
- [x] Issue → fix applied (iteration N)

## Next Priority
What to focus on in the next iteration and why.
```

### Update Rules

1. **Update at iteration END only** — not during the iteration
2. **Resolved issues:** move from Active to Resolved when fixed
3. **Resolved cap:** keep only the 5 most recent resolved items; remove older ones
4. **Size limit:** keep total under ~1000 words. Summarize aggressively.
5. **Each entry is a summary** — not a detailed log. One line per item.
6. **Reverted changes:** note commit hash in Active Issues — so future iterations can inspect via `git show <hash>`

### First Iteration Bootstrap

If `.autoresearch/context.md` does not exist, the Coordinator creates it:

```markdown
# Autoresearch Context
Last updated: iteration 1 | YYYY-MM-DD HH:MM

## Current State
Initial state. [Describe what was observed on first read.]

## Active Issues
[List any issues found during first analysis.]

## Resolved This Session
(none yet)

## Next Priority
[Based on first analysis.]
```

## Layer 3: .autoresearch/knowledge.md (Cumulative Findings)

**Location:** `.autoresearch/knowledge.md` in the project root.

**Created by:** Coordinator at the first iteration if it doesn't exist.

**Updated by:** Coordinator during UPDATE_KNOWLEDGE phase.

### Purpose

Cumulative domain knowledge organized by topic. Unlike context.md (which tracks current state), knowledge.md accumulates **reusable findings** across all rounds. Entries are facts learned, not actions taken.

### Format

```markdown
# Autoresearch Knowledge

## [Topic Area]
- Finding with evidence — specific data or commit hash (commit abc1234)
- Another finding — measurement or observation

## [Another Topic]
- Finding — evidence
```

### Write Rules

1. **Categorize by domain topic** — not by round or iteration
2. **Each entry is a reusable finding** — "what we learned", not "what we did"
3. **Include evidence** — concrete data, measurements, or commit hashes
4. **Update contradicted entries** — if a new finding contradicts an old one, update or remove the old entry
5. **No duplication** — before adding, check if the finding already exists in another form

### First Iteration Bootstrap

If `.autoresearch/knowledge.md` does not exist:

```markdown
# Autoresearch Knowledge

(Findings will be added as the session progresses)
```

### Enforcement

The stop-hook mechanical checks verify that knowledge.md was updated (file mtime check). The Post-iteration Review Agent verifies that context.md reflects the iteration's results. If either check fails, the hook blocks exit until the Coordinator fixes the issue.

## Layer 4: Memory (Cross-Session Persistence)

Uses the project's `.claude/projects/*/memory/` system (auto memory).

### What to Save to Memory

Only findings that remain valuable across sessions:
- Architectural constraints discovered empirically
- Optimal parameters found through experimentation
- Domain-specific knowledge not obvious from code

### What NOT to Save

- Per-iteration details (that's what context.md is for)
- Temporary state
- Anything already captured in context.md
- Anything derivable from code or git history

### When to Save

The Coordinator saves to memory when:
1. A finding would be lost if context.md is reset (new session)
2. The finding is generalizable (not specific to current iteration)
3. The finding required significant effort to discover
