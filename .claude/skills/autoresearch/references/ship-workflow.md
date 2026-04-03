# Ship Workflow — /autoresearch:ship

Universal shipping workflow that applies autoresearch loop principles to the last mile — taking anything from "done" to "deployed/published/delivered." Works for code, content, marketing, sales, research, design, or any artifact that needs to reach its audience.

**Core idea:** Shipping has a universal pattern regardless of domain. Identify → Checklist → Prepare → Dry-run → Ship → Verify → Log.
**Evaluator default:** `off` — uses checklist workflow, not iteration loop.

## Trigger

- User invokes `/autoresearch:ship`
- User says "ship it", "deploy this", "publish this", "launch this", "release this"
- User says "get this out the door", "push to prod", "send this out", "go live"

## Loop Support

Works with bounded mode for iterative pre-ship preparation:

```
# Ship with automatic preparation loop
/autoresearch:ship

# Bounded preparation — iterate N times before shipping
/autoresearch:ship
Iterations: 10

# Ship specific artifact
/autoresearch:ship
Target: src/features/auth/**
Destination: production
```

## PREREQUISITE: Interactive Setup (when invoked without flags)

**CRITICAL — BLOCKING PREREQUISITE:** If `/autoresearch:ship` is invoked without `--type` or target, you MUST scan for staged changes, open PRs, and recent commits, then use `AskUserQuestion` to gather user input BEFORE proceeding to ANY phase. DO NOT skip this step.

**Single batched call — all 3 questions at once:**

You MUST call `AskUserQuestion` with all 3 questions in ONE call:

| # | Header | Question | Options (from context scan) |
|---|--------|----------|----------------------------|
| 1 | `What` | "What are you shipping?" | "Code PR", "Release / version tag", "Deployment to production", "Blog post / documentation" |
| 2 | `Mode` | "How should I ship it?" | "Full workflow (checklist → dry-run → ship → verify)", "Dry-run only (validate without shipping)", "Checklist only (just check readiness)", "Auto-approve (ship if checklist passes)" |
| 3 | `Monitor` | "Post-ship monitoring?" | "No monitoring", "5 minutes", "10 minutes", "30 minutes" |

**IMPORTANT:** Always ask all questions in a single call — never one at a time.

If `--type`, `--dry-run`, `--auto`, or `--checklist-only` flags are provided, skip interactive setup and proceed directly.

## Architecture

```
/autoresearch:ship
  ├── Phase 1: Identify (what are we shipping?)
  ├── Phase 2: Inventory (what's the current state?)
  ├── Phase 3: Checklist (domain-specific pre-ship gates)
  ├── Phase 4: Prepare (autoresearch loop until checklist passes)
  ├── Phase 5: Dry-run (simulate the ship action)
  ├── Phase 6: Ship (execute the actual delivery)
  ├── Phase 7: Verify (post-ship health check)
  └── Phase 8: Log (record the shipment)
```

## Phase 1: Identify — What Are We Shipping?

Auto-detect the shipment type from context, or ask the user.

**Detection algorithm:**
```
FUNCTION detectShipmentType(context):
  # Check explicit user input first
  IF user specifies type → USE IT

  # Auto-detect from context
  IF git diff has staged changes OR user mentions "deploy/release/merge":
    IF has Dockerfile/k8s/deploy configs → "deployment"
    IF has open PR or branch changes → "code-pr"
    ELSE → "code-release"

  IF context mentions "blog/article/post" OR target files are *.md in content/:
    → "content"

  IF context mentions "email/campaign/newsletter":
    → "marketing-email"

  IF context mentions "landing page/ad/social":
    → "marketing-campaign"

  IF context mentions "deck/proposal/pitch/quote":
    → "sales"

  IF context mentions "paper/report/analysis/findings":
    → "research"

  IF context mentions "assets/mockup/design/figma":
    → "design"

  # Default: ask user
  → ASK "What are you shipping? (code/content/marketing/sales/research/design/other)"
```

**Output:** `✓ Phase 1: Identified shipment — [type]: [brief description]`

## Phase 2: Inventory — Current State Assessment

Scan the artifact and its environment to understand readiness. See `references/ship-domain-tables.md` for per-type inventory checks.

**Output:** `✓ Phase 2: Inventory complete — [N] items assessed, [M] gaps found`

## Phase 3: Checklist — Domain-Specific Pre-Ship Gates

Generate a mechanical checklist based on shipment type. Every item must be verifiable (pass/fail). See `references/ship-domain-tables.md` for all domain-specific checklists.

**Output:** `✓ Phase 3: Checklist generated — [N] items, [P] passing, [F] failing`

## Phase 4: Prepare — Iterative Improvement Loop

Apply the autoresearch loop to fix failing checklist items.

```
metric = count_passing_checklist_items / total_checklist_items * 100
direction = higher_is_better
target = 100 (all items pass)

LOOP (until all pass OR max iterations):
  1. Read checklist status
  2. Pick highest-priority failing item
  3. Fix it (one atomic change)
  4. Re-run checklist verification
  5. IF item now passes → keep, log "fixed: [item]"
  6. IF item still fails → revert, try different approach
  7. IF all items pass → EXIT LOOP with "ready to ship"
```

**Priority order for fixes:**
1. **Blockers** — security issues, broken builds, missing critical content
2. **Required** — tests, lint, links, compliance items
3. **Recommended** — descriptions, documentation, polish

**Auto-fix capabilities:**
- Run test suites and fix failures
- Fix lint errors automatically
- Add missing meta descriptions
- Generate changelog entries from git log
- Check and fix broken links
- Add alt text to images (describe or prompt user)
- Format citations
- Export missing design formats

**Items that require human input:**
- Pricing approval
- Legal review sign-off
- Brand approval
- Strategic decisions (A/B test variants)
- → Flag these and ask user, don't block on them

**Output:** `✓ Phase 4: Preparation complete — [N/N] checklist items passing`

## Phase 5: Dry-Run — Simulate Before Shipping

Execute simulation without side effects. See `references/ship-domain-tables.md` for per-type dry-run actions.

**Dry-run gate:**
- Present dry-run results to user
- `--auto` flag: auto-approve if no errors
- Default: ask user "Ready to ship?" before proceeding
- `--dry-run` flag: stop here, don't actually ship

**Output:** `✓ Phase 5: Dry-run complete — [result summary]`

## Phase 6: Ship — Execute the Delivery

The actual ship action. Domain-specific. See `references/ship-domain-tables.md` for per-type ship actions and safety rails.

**Output:** `✓ Phase 6: Shipped — [action taken] at [timestamp]`

## Phase 7: Verify — Post-Ship Health Check

Confirm the shipment actually landed and is healthy. See `references/ship-domain-tables.md` for per-type verification checks and post-ship monitoring.

**Output:** `✓ Phase 7: Verified — [health status summary]`

## Phase 8: Log — Record the Shipment

Create a ship log entry for traceability. See `references/ship-domain-tables.md` for TSV format and summary template.

## Flags

| Flag | Purpose |
|------|---------|
| `--dry-run` | Run all phases except actual ship (stop at Phase 5) |
| `--auto` | Auto-approve dry-run gate if no errors found |
| `--force` | Skip non-critical checklist items (still enforce blockers) |
| `--rollback` | Undo the last ship action (if reversible) |
| `--monitor N` | Post-ship monitoring for N minutes |
| `--type <type>` | Override auto-detection with explicit shipment type |
| `--checklist-only` | Only generate and evaluate checklist (stop at Phase 3) |

## Composite Metric

For bounded loop mode, the ship readiness metric:

```
ship_score = (checklist_passing / checklist_total) * 80
           + (dry_run_passed ? 15 : 0)
           + (no_blockers ? 5 : 0)
```

- **100** = fully ready to ship
- **80-99** = ready with minor items (can ship with `--force`)
- **<80** = not ready, continue preparing

## Rollback Protocol

If `--rollback` is specified or post-ship verification fails. See `references/ship-domain-tables.md` for per-type rollback actions and non-reversible action warnings.

## Output Directory

Creates `ship/{YYMMDD}-{HHMM}-{ship-slug}/` with:
- `checklist.md` — full checklist with pass/fail status
- `ship-log.tsv` — iteration log (if preparation loop ran)
- `summary.md` — final ship report
