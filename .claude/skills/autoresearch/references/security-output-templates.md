# Security Audit Output Templates

Templates for files created in `security/{YYMMDD}-{HHMM}-{slug}/`. Referenced from `security-workflow.md`.

## Final Report Structure

Generated at loop completion (bounded) or on interrupt (unbounded):

```markdown
# Security Audit Report

## Executive Summary
- **Date:** {date}
- **Scope:** {files/directories scanned}
- **Iterations:** {N}
- **Total Findings:** {count} ({critical} Critical, {high} High, {medium} Medium, {low} Low)

## Threat Model

### Assets
{table of identified assets}

### Trust Boundaries
{diagram of trust boundaries}

### STRIDE Analysis
{threat model table}

### Attack Surface Map
{entry points, data flows, abuse paths}

## Findings (Descending Severity)

### [CRITICAL] Finding 1: {title}
- **OWASP:** {category}
- **STRIDE:** {category}
- **Location:** `{file}:{line}`
- **Confidence:** Confirmed / Likely / Possible
- **Description:** {what's wrong}
- **Attack Scenario:** {step-by-step exploitation}
- **Code Evidence:**
  ```{lang}
  {vulnerable code snippet}
  ```
- **Mitigation:**
  ```{lang}
  {fixed code snippet}
  ```
- **References:** {CWE, CVE if applicable}

### [HIGH] Finding 2: ...
...

## Coverage Matrix

| OWASP Category | Tested | Findings |
|----------------|--------|----------|
| A01 Broken Access Control | check | 2 |
| A02 Cryptographic Failures | check | 0 |
| ... | ... | ... |

| STRIDE Category | Tested | Findings |
|-----------------|--------|----------|
| Spoofing | check | 1 |
| Tampering | check | 2 |
| ... | ... | ... |

## Dependency Audit
{npm audit / pip audit / go vulnerabilities}

## Security Headers Check
{CSP, HSTS, X-Frame-Options, etc.}

## Recommendations (Priority Order)
1. {Critical fix 1}
2. {Critical fix 2}
...

## Iteration Log
{full TSV content}
```

## overview.md

```markdown
# Security Audit — {audit-type}

**Date:** {YYYY-MM-DD HH:MM}
**Scope:** {files/directories}
**Focus:** {user-provided focus or "comprehensive"}
**Iterations:** {N completed} ({bounded or unlimited})
**Duration:** {approximate time}

## Summary

- **Total Findings:** {count}
  - Critical: {n} | High: {n} | Medium: {n} | Low: {n} | Info: {n}
- **STRIDE Coverage:** {n}/6 categories tested
- **OWASP Coverage:** {n}/10 categories tested
- **Confirmed:** {n} | Likely: {n} | Possible: {n}

## Top 3 Critical Findings

1. [{title}]({findings.md#finding-1}) — {one-line description}
2. [{title}]({findings.md#finding-2}) — {one-line description}
3. [{title}]({findings.md#finding-3}) — {one-line description}

## Files in This Report

- [Threat Model](./threat-model.md) — STRIDE analysis, assets, trust boundaries
- [Attack Surface Map](./attack-surface-map.md) — entry points, data flows, abuse paths
- [Findings](./findings.md) — all findings ranked by severity
- [OWASP Coverage](./owasp-coverage.md) — per-category test results
- [Dependency Audit](./dependency-audit.md) — known CVEs in dependencies
- [Recommendations](./recommendations.md) — prioritized mitigations
- [Iteration Log](./security-audit-results.tsv) — raw data from every iteration
```

## threat-model.md

Contains the full STRIDE analysis generated in the Setup Phase:
- Asset inventory table
- Trust boundary diagram
- STRIDE threat matrix (per asset x boundary)
- Risk ratings per threat

## attack-surface-map.md

Contains the attack surface generated in the Setup Phase:
- Entry points (all API routes, webhooks, WebSocket endpoints)
- Data flows (input -> processing -> storage)
- Abuse paths (chained attack scenarios)

## findings.md

All findings from the loop, in descending severity:
- Each finding uses the full proof structure (OWASP, STRIDE, location, evidence, mitigation)
- Findings are numbered and linkable via anchors (`#finding-1`, `#finding-2`)

## owasp-coverage.md

```markdown
| ID | Category | Tested | Findings | Status |
|----|----------|--------|----------|--------|
| A01 | Broken Access Control | check | 2 | issues found |
| A02 | Cryptographic Failures | check | 0 | clean |
| A03 | Injection | check | 1 | issues found |
| ... | ... | ... | ... | ... |
```

Also includes per-category detail: which specific checks were run and their results.

## dependency-audit.md

Output of dependency security tools:
- `npm audit` / `yarn audit` (Node.js)
- `pip audit` / `safety check` (Python)
- `go vuln` (Go)
- `cargo audit` (Rust)
- Known CVEs, severity, affected versions, fix versions

## recommendations.md

```markdown
## Priority 1 — Critical (Fix Immediately)

### 1. Restrict JWT Algorithm
**Finding:** [JWT Algorithm Confusion](./findings.md#finding-2)
**Effort:** 5 minutes
**Fix:**
\```typescript
// Before (vulnerable)
jwt.verify(token, secret);

// After (secure)
jwt.verify(token, secret, { algorithms: ['HS256'] });
\```

### 2. Add IDOR Protection
...

## Priority 2 — High (Fix This Sprint)
...

## Priority 3 — Medium (Plan for Next Sprint)
...
```

## security-audit-results.tsv

TSV header and example rows:

```tsv
iteration	vector	severity	owasp	stride	confidence	location	description
0	-	-	-	-	-	-	baseline — 3 npm audit warnings
1	IDOR	High	A01	EoP	Confirmed	src/api/users.ts:42	GET /api/users/:id returns any user data without ownership check
2	XSS	Medium	A03	Tampering	Likely	src/components/comment.tsx:18	User input rendered via dangerouslySetInnerHTML
3	rate-limit	Medium	A05	DoS	Confirmed	src/api/auth.ts:15	POST /login has no rate limiting — brute force possible
```

## Coverage Summary Format

Printed every 5 iterations during the loop:

```
=== Security Audit Progress (iteration 10) ===
STRIDE Coverage: S[check] T[check] R[x] I[check] D[check] E[check] — 5/6
OWASP Coverage: A01[check] A02[x] A03[check] A04[x] A05[check] A06[check] A07[check] A08[x] A09[x] A10[x] — 5/10
Findings: 4 Critical, 2 High, 3 Medium, 1 Low
Confirmed: 7 | Likely: 2 | Possible: 1
```

## Delta Summary Template

Added to overview.md when `--diff` is used:

```markdown
## Delta Summary (vs {previous_audit_folder})

| Status | Count | Details |
|--------|-------|---------|
| New findings | 3 | Found in changed files |
| Fixed | 2 | No longer present |
| Recurring | 5 | Still present from last audit |
| Files changed | 12 | Since last audit |
| Files audited | 8 | (security-relevant subset) |
```

## Historical Comparison Template

Added to overview.md when a previous audit exists:

```markdown
## Historical Comparison

**Previous audit:** security/260310-1430-stride-owasp-full-audit/ (5 days ago)

### Trend
| Metric | Previous | Current | Change |
|--------|----------|---------|--------|
| Critical | 3 | 1 | down -2 (improved) |
| High | 4 | 5 | up +1 (regressed) |
| Medium | 2 | 3 | up +1 |
| Total | 9 | 9 | 0 |
| OWASP coverage | 6/10 | 8/10 | up +2 |
| STRIDE coverage | 4/6 | 5/6 | up +1 |

### Finding Status
| Status | Count | Details |
|--------|-------|---------|
| Fixed since last audit | 4 | JWT algo, CORS, 2 XSS |
| New findings | 4 | SSRF, rate limit, 2 IDOR |
| Recurring (unfixed) | 5 | See findings.md |

### Regression Alert
WARNING: 4 new findings detected since last audit. Review [findings.md](./findings.md) for details.
```

Finding history tags: `New` (first time detected), `Recurring` (present in previous audit too), `Fixed` (no longer present).

## CI/CD GitHub Action Template

Generated when `.github/workflows/` directory is detected:

```yaml
name: Security Audit

on:
  pull_request:
    branches: [main, master]
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2am UTC

permissions:
  contents: read
  pull-requests: write

jobs:
  security-audit:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for delta mode

      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code

      - name: Install Autoresearch Skill
        run: |
          git clone https://github.com/uditgoenka/autoresearch.git /tmp/autoresearch
          cp -r /tmp/autoresearch/skills/autoresearch .claude/skills/autoresearch
          cp -r /tmp/autoresearch/commands/autoresearch .claude/commands/autoresearch
          cp /tmp/autoresearch/commands/autoresearch.md .claude/commands/autoresearch.md

      - name: Run Security Audit
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # Delta mode on PRs, full audit on schedule
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            claude -p "/autoresearch:security --diff --fail-on critical --iterations 5"
          else
            claude -p "/autoresearch:security --fail-on high --iterations 15"
          fi

      - name: Upload Security Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-audit-report
          path: security/
          retention-days: 90

      - name: Comment PR with Summary
        if: github.event_name == 'pull_request' && always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const glob = require('glob');
            const overviews = glob.sync('security/*/overview.md');
            if (overviews.length > 0) {
              const latest = overviews.sort().pop();
              const content = fs.readFileSync(latest, 'utf-8');
              const summary = content.split('## Summary')[1]?.split('##')[0] || 'See full report in artifacts.';
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: `## Security Audit Results\n\n${summary}\n\n> Full report available in workflow artifacts.`
              });
            }
```

The template is generated ONCE — after initial creation, it's the user's file to customize.
