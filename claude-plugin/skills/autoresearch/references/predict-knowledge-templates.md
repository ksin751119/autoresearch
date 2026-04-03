# Predict Knowledge File Templates

Templates for knowledge files and output files created by `/autoresearch:predict`. Referenced from `predict-workflow.md`.

---

## Knowledge File: codebase-analysis.md

```markdown
---
commit_hash: {git rev-parse HEAD}
analyzed_at: {ISO timestamp}
scope: {glob patterns used}
files_analyzed: {count}
---

## Functions

| File | Function | Signature | Lines | Calls | Called By |
|------|----------|-----------|-------|-------|-----------|
| src/api/users.ts | getUser | (id: string) => Promise<User> | 42-61 | db.findById, logger.info | router.get |

## Classes & Types

| File | Name | Kind | Key Properties | Methods |
|------|------|------|----------------|---------|
| src/models/user.ts | User | interface | id, email, role, createdAt | - |

## Routes / Endpoints

| Method | Path | File | Handler | Auth Required | Input |
|--------|------|------|---------|---------------|-------|
| GET | /api/users/:id | src/api/users.ts:15 | getUser | yes | param:id |

## Models / Database

| Name | File | Fields | Indexes | Relations |
|------|------|--------|---------|-----------|
| users | src/db/schema.ts:8 | id, email, role, created_at | email (unique), id (pk) | has_many: sessions |
```

---

## Knowledge File: dependency-map.md

```markdown
---
commit_hash: {git rev-parse HEAD}
---

## Import Graph

| File | Imports From | Symbols |
|------|-------------|---------|
| src/api/users.ts | src/db/client.ts | db |
| src/api/users.ts | src/middleware/auth.ts | requireAuth |

## Call Graph

| Caller | Callee | File:Line | Type |
|--------|--------|-----------|------|
| router.get /api/users/:id | getUser | users.ts:15 | route handler |
| getUser | db.findById | users.ts:48 | async call |

## Data Flows

| Source | Transform | Sink | Risk Areas |
|--------|-----------|------|------------|
| req.params.id | no sanitization | db.findById | injection, IDOR |
| db.user row | JSON.stringify | res.json | PII exposure |
```

---

## Knowledge File: component-clusters.md

```markdown
---
commit_hash: {git rev-parse HEAD}
---

## Clusters

| Cluster | Files | Key Entities | External Deps | Risk Areas |
|---------|-------|-------------|---------------|------------|
| Authentication | src/auth/*.ts | JWTService, SessionStore | jsonwebtoken | token validation, session fixation |
| User API | src/api/users.ts, src/models/user.ts | User, getUser, updateUser | postgres | IDOR, PII exposure |
| Background Jobs | src/workers/*.ts | EmailWorker, CleanupJob | bull, nodemailer | race conditions, retries |
```

---

## Persona Prompt Template

```
You are {name}, a {role} with expertise in {expertise}.

Your task: Analyze the provided codebase files and knowledge context. Produce findings independently — do NOT reference or anticipate other personas' views.

Context available to you:
- codebase-analysis.md: Functions, types, routes, models
- dependency-map.md: Import graph, call graph, data flows
- component-clusters.md: Logical groupings and risk areas
- In-scope source files: {file list}

Goal: {user-provided goal}

Constraints:
- Every finding MUST include a file:line reference
- Maximum {finding_limit} findings (prioritize highest-severity)
- Do NOT hallucinate APIs or functions not present in the source files
- Confidence scale: HIGH (certain from code), MEDIUM (likely but depends on runtime), LOW (theoretical, needs verification)

Bias: {bias_direction}

Output format:
<{persona_tag}_findings>
  <finding id="{persona_abbr}-{n}">
    <title>{one-line title}</title>
    <location>{file}:{line}</location>
    <severity>CRITICAL|HIGH|MEDIUM|LOW</severity>
    <confidence>HIGH|MEDIUM|LOW</confidence>
    <evidence>{exact code or flow that demonstrates the finding}</evidence>
    <recommendation>{concrete action to address it}</recommendation>
  </finding>
</{persona_tag}_findings>
```

---

## Analysis Output Format (Phase 4)

Per-persona structured XML output:

```xml
<architecture_reviewer_findings>
  <finding id="AR-1">
    <title>Circular dependency between UserService and AuthService</title>
    <location>src/services/user.ts:12</location>
    <severity>MEDIUM</severity>
    <confidence>HIGH</confidence>
    <evidence>UserService imports AuthService at line 12; AuthService imports UserService at line 8 of src/services/auth.ts — creates circular module dependency</evidence>
    <recommendation>Extract shared types to src/types/user-auth.ts to break the cycle</recommendation>
  </finding>
</architecture_reviewer_findings>
```

---

## Debate Format (Phase 5)

Per-persona per-round structured XML:

```xml
<architecture_reviewer_debate round="1">
  <challenge target_finding="SA-2" position="disagree">
    <peer_claim>Security Analyst claims the JWT secret is hardcoded at auth.ts:33</peer_claim>
    <counter_evidence>Line 33 reads `process.env.JWT_SECRET` — the secret is injected at runtime. However, there is no fallback guard if the env var is absent.</counter_evidence>
    <revised_position>Finding is partially correct. Risk is lower than CRITICAL — downgrade to HIGH. Recommend adding startup assertion: `if (!process.env.JWT_SECRET) throw new Error(...)`</revised_position>
  </challenge>
  <revised_finding id="AR-1">
    <change>Severity unchanged. Added note: circular dependency also prevents tree-shaking, confirmed by webpack bundle analysis pattern in webpack.config.js:44</change>
  </revised_finding>
</architecture_reviewer_debate>
```

---

## overview.md

```markdown
# Predict Analysis — {slug}

**Date:** {YYYY-MM-DD HH:MM}
**Scope:** {glob patterns}
**Personas:** {N} ({names})
**Debate Rounds:** {N completed}
**Commit Hash:** {hash}
**Anti-Herd Status:** PASSED | ⚠️ GROUPTHINK WARNING

## Summary

- **Total Findings:** {count}
  - Confirmed: {n} | Probable: {n} | Minority: {n}
- **Severity Breakdown:** Critical: {n} | High: {n} | Medium: {n} | Low: {n}
- **Composite Score:** {predict_score} (see metric below)

## Top Findings

1. [{title}](./findings.md#finding-1) — {severity} | {consensus_ratio} consensus
2. [{title}](./findings.md#finding-2) — {severity} | {consensus_ratio} consensus
3. [{title}](./findings.md#finding-3) — {severity} | {consensus_ratio} consensus

## Files in This Report

- [Findings](./findings.md) — ranked by priority score
- [Hypothesis Queue](./hypothesis-queue.md) — for chain handoff
- [Persona Debates](./persona-debates.md) — full debate transcript
- [Iteration Log](./predict-results.tsv) — per-persona per-round data
```

---

## findings.md

All findings ranked by `priority_score` descending. Per finding:

```markdown
## Finding {n}: {title}

**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Confidence:** HIGH | MEDIUM | LOW
**Location:** `{file}:{line}`
**Consensus:** {personas_confirmed}/{personas_total} personas

**Evidence:**
{exact code or flow excerpt}

**Recommendation:**
{concrete action}

**Persona Votes:**
| Persona | Vote | Note |
|---------|------|------|
| Architecture Reviewer | confirm | Circular dep confirmed in import graph |
| Security Analyst | confirm | Adds attack surface via predictable module load order |
| Performance Engineer | abstain | Outside domain |
| Reliability Engineer | confirm | Initialization order failures observed in component-clusters.md |
| Devil's Advocate | dispute | Only affects bundler environments — runtime Node.js may be unaffected |

**Debate Log:** [Round 1, AR challenge to SA-2](./persona-debates.md#round-1)
```

---

## hypothesis-queue.md

```markdown
## Hypothesis Queue

| Rank | ID | Hypothesis | Confidence | Location | Source Persona |
|------|----|-----------|-----------|----------|----------------|
| 1 | H-01 | JWT secret falls back to empty string when JWT_SECRET env var is absent | HIGH | src/auth/jwt.ts:33 | Security Analyst (confirmed 4/5) |
| 2 | H-02 | Circular dependency between UserService and AuthService causes initialization failures in test environments | MEDIUM | src/services/user.ts:12 | Architecture Reviewer (confirmed 3/5) |
```

---

## persona-debates.md

Full transcript of all debate rounds. Per round, per persona:

```markdown
## Round 1

### Architecture Reviewer

**Challenge → SA-2:** [disagree] SA claims JWT secret is hardcoded. Evidence: line 33 reads `process.env.JWT_SECRET`. Counter: no startup assertion guards absence. Revised SA-2 to HIGH.

**Revised AR-1:** Severity unchanged. Added: circular dep prevents tree-shaking (webpack.config.js:44).

### Security Analyst
...
```

---

## predict-results.tsv

```tsv
round	persona	findings_produced	findings_revised	challenges_issued	flip_count	status
0	Architecture Reviewer	6	0	0	0	independent_analysis
0	Security Analyst	8	0	0	0	independent_analysis
1	Architecture Reviewer	6	1	2	1	debate_round_1
1	Devil's Advocate	6	0	4	3	debate_round_1
```

---

## handoff.json Schema

```json
{
  "version": "1.0",
  "tool": "predict",
  "generated_at": "2026-03-18T11:05:00Z",
  "commit_hash": "a1b2c3d4",
  "scope": ["src/api/**/*.ts", "src/auth/**/*.ts"],
  "summary": {
    "personas": 5,
    "rounds": 2,
    "findings_confirmed": 8,
    "findings_probable": 3,
    "findings_minority": 2,
    "anti_herd_passed": true,
    "predict_score": 142
  },
  "findings": [
    {
      "id": "H-01",
      "type": "security",
      "severity": "HIGH",
      "confidence": "HIGH",
      "location": "src/auth/jwt.ts:33",
      "title": "JWT secret absent when JWT_SECRET env var missing",
      "description": "No startup assertion guards against undefined JWT_SECRET. Falls back to empty string.",
      "evidence": "process.env.JWT_SECRET used directly without null check at jwt.ts:33",
      "recommendation": "Add: if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET required')",
      "personas_agreed": 4,
      "personas_total": 5
    }
  ],
  "hypotheses": [
    {
      "rank": 1,
      "id": "H-01",
      "hypothesis": "JWT secret falls back to empty string when JWT_SECRET env var is absent",
      "confidence": "HIGH",
      "location": "src/auth/jwt.ts:33"
    }
  ]
}
```

---

## Chain Conversion Templates

### --chain debug

```
/autoresearch:debug
Scope: {unique file paths from findings}
Symptom: Swarm-predicted issues — {N} hypotheses queued
Hypotheses:
  H-01 [HIGH] JWT secret absent — src/auth/jwt.ts:33
  H-02 [MEDIUM] Circular dep init failure — src/services/user.ts:12
```

### --chain security

Filter findings where `type == "security"`. Map to STRIDE categories:

```
/autoresearch:security
Scope: {files from security findings}
Focus: Swarm-identified vectors: {comma-separated finding titles}
```

### --chain fix

Sort by `severity * consensus_ratio`. Add cascade hints from dependency-map.md:

```
/autoresearch:fix
Target: {top finding title}
Scope: {file:line from top finding}
Cascade: {dependent files from dependency-map.md}
```

### --chain ship

Convert findings to gate classifications:

| Severity | Gate Classification |
|----------|-------------------|
| CRITICAL or HIGH (confirmed) | BLOCKER — must resolve before ship |
| MEDIUM (confirmed) | WARNING — document or resolve |
| LOW or minority | INFO — log for backlog |

```
/autoresearch:ship
Blockers: {count} from swarm analysis
Gate: {PASS if 0 blockers, FAIL otherwise}
```

### --chain scenario

Each confirmed finding becomes a scenario seed:

```
/autoresearch:scenario
Scenario: {finding title} — {description}
Domain: software
Depth: standard
```
