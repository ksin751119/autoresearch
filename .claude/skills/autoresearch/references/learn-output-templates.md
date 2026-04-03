# Learn Output Templates

Output file formats and reference material for /autoresearch:learn. Referenced from `learn-workflow.md`.

## Phase 3: Init Mode — Doc File Catalog

**Always create:**
- `docs/project-overview-pdr.md` — Project overview and PDR
- `docs/codebase-summary.md` — Codebase summary with file inventory
- `docs/code-standards.md` — Codebase structure and code standards
- `docs/system-architecture.md` — System architecture
- `README.md` at root (create or update, max 300 lines)

**Conditional creation (based on project signals from Phase 2):**
- `docs/deployment-guide.md` — if Dockerfile, CI config (`.github/workflows`, `.gitlab-ci.yml`), deploy scripts, or cloud config detected
- `docs/design-guidelines.md` — if UI components, CSS/style files, or frontend framework detected
- `docs/project-roadmap.md` — if project has milestones, issues, or TODO tracking
- `docs/api-reference.md` — if API routes, controllers, resolvers, or OpenAPI/Swagger specs detected. Include endpoint catalog with method, path, description, request/response shapes
- `docs/testing-guide.md` — if test directories (`tests/`, `__tests__/`, `spec/`), test config (jest.config, vitest.config, pytest.ini), or CI test steps detected. Document test strategy, how to run tests, coverage expectations, fixture patterns
- `docs/configuration-guide.md` — if `.env.example`, `config/` directory, feature flags, or environment-specific configs detected. Document all env vars, config keys, and their purpose
- `docs/changelog.md` — generate from `git log --oneline --no-merges -50` using conventional commit parsing. Group by type (feat, fix, docs, refactor). Only on init; update mode appends new entries

## Phase 3: Update Mode — Diff-Based Doc Targeting

Map changed source files to affected docs:
- `src/api/**` changes → prioritize `api-reference.md`, `system-architecture.md`
- `src/components/**` changes → prioritize `design-guidelines.md`
- `tests/**` changes → prioritize `testing-guide.md`
- `package.json` / dependency changes → prioritize `codebase-summary.md` (dependency section)
- Config file changes → prioritize `configuration-guide.md`
- New files in `src/` → prioritize `code-standards.md`, `system-architecture.md`

This is advisory, not exclusive — all docs still get reviewed, mapped ones get deeper updates.

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
