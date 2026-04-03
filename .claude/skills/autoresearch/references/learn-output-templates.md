# Learn Output Templates

Output file formats and reference material for /autoresearch:learn. Referenced from `learn-workflow.md`.

## Phase 8: Results File

Append to `learn-results.tsv` in the output directory:

```tsv
iteration	mode	docs_generated	docs_updated	validation_score	fix_iterations	learn_score	duration_s
1	init	7	0	100	1	95	45
2	update	0	5	85	2	78	62
```

## Phase 8: Progress Report (every 5 iterations if bounded)

```
=== Learn Progress (iteration N) ===
Docs generated: [X] | Docs updated: [Y]
Validation score: [Z]% (target: 100%)
Fix iterations used: [A]/[B]
Coverage: [C]/[D] core docs present
Learn score: [S]
```

## Phase 8: Final Summary (on completion or iteration limit)

Write `summary.md` to output directory:
- Mode used, scope, depth
- Baseline state → final state
- Docs created/updated with one-line descriptions
- Validation score trajectory
- Learn score
- Remaining warnings (if any)
- Recommended next steps

## What NOT to Do — Anti-Patterns

| Anti-Pattern | Why Wrong | Do This Instead |
|---|---|---|
| Generate docs without scouting first | Produces hallucinated content disconnected from reality | Always scout → learn actual structure → then generate |
| Hardcode expected doc file list | Misses user's custom docs, breaks when files renamed | Dynamic discovery: scan `docs/*.md` at runtime |
| Skip validation on freshly generated docs | "New docs can't have errors" is wrong — LLMs hallucinate references | Always validate. Init and update both run Phase 5 |
| Retry validation-fix loop indefinitely | Diminishing returns after 3 attempts, wastes tokens | Cap at 3 retries, accept with warnings |
| Scout entire monorepo without scoping | Context overflow, massive token waste | Detect monorepo early, suggest `--scope` to user |
| Generate deployment-guide.md for a library | Irrelevant docs erode trust in all generated content | Create conditional docs only when project signals detected |
| Overwrite user's custom docs on update | Destroys manual work, violates trust | Discover custom docs, preserve their structure, update content only |
| Run check mode then modify files | Check is strictly read-only diagnostic | Use update mode for modifications |

## Output Directory

```
learn/{YYMMDD}-{HHMM}-{slug}/
├── learn-results.tsv     # iteration log (tsv)
├── summary.md            # executive summary
├── validation-report.md  # last validation output
└── scout-context.md      # merged scout reports (reference)
```

**Generated/updated docs go to `docs/` directly** — not the learn/ output folder.
**learn/ is the audit trail** — records what was learned, validated, and fixed.

## Chaining Patterns

```bash
# Learn codebase, then security audit
/autoresearch:learn --mode init
/autoresearch:security

# Learn changes, then predict issues
/autoresearch:learn --mode update
/autoresearch:predict --scope src/**

# Check health, update if stale
/autoresearch:learn --mode check
# If report says "Stale" →
/autoresearch:learn --mode update

# Learn then ship docs as PR
/autoresearch:learn --mode update
/autoresearch:ship --type code-pr

# Full quality pipeline
/autoresearch:learn --mode init
/autoresearch:scenario --domain software
/autoresearch:security
/autoresearch:ship
```
