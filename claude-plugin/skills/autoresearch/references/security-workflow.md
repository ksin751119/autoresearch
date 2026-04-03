# Security Workflow — /autoresearch:security

Autonomous security auditing using the autoresearch loop: STRIDE threat modeling, OWASP Top 10 sweeps, and red-team adversarial analysis.

**Output:** Severity-ranked security report with threat model, findings, mitigations, and iteration log.
**Evaluator default:** `off` — this workflow already uses 4 adversarial personas.
**Templates:** See `references/security-output-templates.md` for all output file templates.

## Contents

- [Trigger](#trigger)
- [Loop Support](#loop-support)
- [PREREQUISITE: Interactive Setup](#prerequisite-interactive-setup)
- [Architecture](#architecture)
- [Setup Phase — Threat Model Generation](#setup-phase--threat-model-generation)
- [The Security Loop](#the-security-loop)
- [OWASP Checks Reference](#owasp-checks-reference)
- [Red-Team Adversarial Lenses](#red-team-adversarial-lenses)
- [Strix-Inspired Patterns](#strix-inspired-patterns)
- [Metric for the Loop](#metric-for-the-loop)
- [Flags & Modes](#flags--modes)
- [Error Recovery](#error-recovery)
- [Anti-Patterns](#anti-patterns)
- [Report Output — Structured Folder](#report-output--structured-folder)

## Trigger

- User invokes `/autoresearch:security`
- User says "security audit", "run a security sweep", "threat model this codebase", "find vulnerabilities", "red-team this app", "OWASP audit", "STRIDE analysis"

## Loop Support

```
/autoresearch:security                          # Unlimited
/autoresearch:security
Iterations: 10                                  # Bounded

/autoresearch:security
Scope: src/api/**/*.ts, src/middleware/**/*.ts   # With target scope
Focus: authentication and authorization flows
```

## PREREQUISITE: Interactive Setup

**CRITICAL — BLOCKING:** If invoked without `--diff`, scope, or focus, MUST scan codebase first, then use `AskUserQuestion` to gather input BEFORE any phase.

**Single batched call — all 3 questions at once:**

| # | Header | Question | Options |
|---|--------|----------|---------|
| 1 | `Scope` | "What should I audit?" | "Entire codebase", "API routes + middleware", "Auth + authorization", "External-facing code" |
| 2 | `Depth` | "How thorough?" | "Quick scan (5 iter)", "Standard (15 iter)", "Deep (30+ iter)", "Unlimited" |
| 3 | `Action` | "What to do with confirmed vulns?" | "Report only", "Report + auto-fix Critical/High", "Report + CI gate" |

If flags are provided inline, skip interactive setup.

## Architecture

```
SETUP PHASE (once):
  1. Scan codebase → tech stack, frameworks, APIs
  2. Map assets → data stores, auth, external services
  3. Identify trust boundaries
  4. Generate STRIDE threat model
  5. Build attack surface map
  6. Create security-audit-results.tsv log
  7. Establish baseline

AUTONOMOUS LOOP (forever or N times):
  1. Review: threat model + past findings + results log
  2. Select: pick next untested attack vector
  3. Analyze: deep-dive into target code
  4. Validate: construct proof (code path, input, output)
  5. Classify: severity + OWASP + STRIDE
  6. Log: append to results log
  7. Repeat
```

## Setup Phase — Threat Model Generation

### Step 1: Codebase Reconnaissance

Scan: package.json/requirements.txt/go.mod (deps), .env.example/config (secrets), Dockerfile (infra), API routes (attack surface), auth/middleware (trust boundaries), DB schemas (data assets), CI/CD configs (supply chain).

### Step 2: Asset Identification

| Asset Type | Priority |
|------------|----------|
| Data stores (DB, Redis, cookies, localStorage) | Critical |
| Authentication (login, OAuth, JWT, sessions, API keys) | Critical |
| API endpoints (REST, GraphQL, webhooks) | High |
| External services (payment, email, CDN) | High |
| User input surfaces (forms, URL params, headers, uploads) | High |
| Configuration (env vars, feature flags, CORS) | Medium |
| Static assets (public files, uploads) | Low |

### Step 3: Trust Boundary Mapping

Identify where trust levels change: Browser/Server, Server/DB, Server/External APIs, Public/Authenticated routes, User/Admin roles, CI-CD/Production, Container/Host.

### Step 4: STRIDE Threat Model

For each asset + trust boundary combination:

| Threat | Question |
|--------|----------|
| **S**poofing | Can an attacker impersonate a user/service? |
| **T**ampering | Can data be modified in transit or at rest? |
| **R**epudiation | Can actions be denied without evidence? |
| **I**nformation Disclosure | Can sensitive data leak? |
| **D**enial of Service | Can the service be disrupted? |
| **E**levation of Privilege | Can a user gain unauthorized access? |

### Step 5: Attack Surface Map

Map all entry points (API routes, WebSocket, webhooks), data flows (input -> processing -> storage), and abuse paths (chained attack scenarios).

### Step 6: Baseline

Run existing security linting (`npm audit`, `eslint-plugin-security`, `bandit`, etc.), count issues as baseline, record as iteration #0.

## The Security Loop

### Iteration Protocol

#### Phase 1: Review (Select Attack Vector)

Priority order:
1. Critical STRIDE threats not yet tested
2. OWASP Top 10 categories not yet covered
3. High-severity attack paths from surface map
4. Dependency vulnerabilities (supply chain)
5. Configuration weaknesses (headers, CORS, CSP)
6. Business logic flaws (race conditions, state manipulation)
7. Information disclosure (error handling, debug modes)

#### Phase 2: Analyze (Deep Dive)

Read all relevant code, trace data flow from entry to data store, identify missing validation/sanitization/access checks, look for known vulnerability patterns.

#### Phase 3: Validate (Proof Construction)

For each potential finding, construct: vulnerable code location (file:line), attack scenario (step-by-step), triggering input, expected vs actual behavior, impact assessment, confidence level (Confirmed/Likely/Possible).

**Confidence levels:**
- **Confirmed** — Code path clearly allows the attack, no guards present
- **Likely** — Guards exist but are bypassable or incomplete
- **Possible** — Theoretical risk, depends on configuration or runtime

Do NOT report findings without supporting code evidence.

#### Phase 4: Classify

**Severity:**
| Severity | Criteria |
|----------|----------|
| **Critical** | RCE, auth bypass, SQL injection, data breach, admin takeover |
| **High** | Stored XSS, SSRF, privilege escalation, mass data exposure |
| **Medium** | CSRF, open redirect, info disclosure, missing rate limits |
| **Low** | Missing headers, verbose errors, weak session config |
| **Info** | Best practice suggestions, hardening recommendations |

**OWASP Top 10 (2021):** A01 Broken Access Control, A02 Cryptographic Failures, A03 Injection, A04 Insecure Design, A05 Security Misconfiguration, A06 Vulnerable Components, A07 Auth Failures, A08 Software/Data Integrity, A09 Logging/Monitoring Failures, A10 SSRF.

**STRIDE:** Tag each finding with applicable STRIDE category.

#### Phase 5: Log

See `references/security-output-templates.md` for the security-audit-results.tsv format.

#### Phase 6: Repeat

- **Unbounded:** Keep finding vulnerabilities. Never stop. Never ask.
- **Bounded:** After N iterations, generate final report and stop.
- **Coverage tracking:** Every 5 iterations, print coverage summary (see templates).

## OWASP Checks Reference

### A01 — Broken Access Control
IDOR on parameterized routes, missing authorization middleware, horizontal/vertical privilege escalation, directory traversal, CORS misconfiguration, missing function-level access control.

### A02 — Cryptographic Failures
Plaintext sensitive data, weak hashing (MD5/SHA1 for passwords), hardcoded secrets, missing encryption at rest/in transit, weak RNG for tokens, exposed .env files.

### A03 — Injection
SQL/NoSQL injection, command injection (exec/spawn), XSS (stored/reflected/DOM), template injection (SSTI), LDAP injection, path injection, header injection (CRLF).

### A04 — Insecure Design
Missing rate limiting, no account lockout, predictable resource IDs, race conditions, missing CSRF protection, insecure direct object references.

### A05 — Security Misconfiguration
Debug mode in production, default credentials, verbose errors, missing security headers (CSP/HSTS/X-Content-Type-Options), unnecessary HTTP methods, directory listing, stack traces.

### A06 — Vulnerable Components
Known CVEs in dependencies, outdated frameworks, unmaintained dependencies, prototype pollution in deps.

### A07 — Auth Failures
Weak passwords, missing MFA for admin, session fixation, JWT vulns (none algo, weak secret, no expiry), insecure password reset, missing session invalidation.

### A08 — Software/Data Integrity
Missing CI/CD integrity checks, unsigned updates/deps, insecure deserialization, missing CSP/SRI for external scripts, unsigned webhooks.

### A09 — Logging/Monitoring Failures
Missing audit logs, no failed auth logging, sensitive data in logs, missing alerting, log injection.

### A10 — SSRF
Unvalidated URLs in server-side requests, DNS rebinding, missing allowlist for external calls, proxy/redirect without validation.

## Red-Team Adversarial Lenses

Four personas, each applied during analysis:

| Persona | Mindset | Focus |
|---------|---------|-------|
| **Security Adversary** | "I'm a hacker breaching this system" | Auth bypass, injection, data exposure, privilege escalation |
| **Supply Chain Attacker** | "I'm compromising deps or build pipeline" | Dependency CVEs, CI/CD weaknesses, unsigned artifacts |
| **Insider Threat** | "I'm a malicious employee" | Privilege escalation, data exfiltration, access control gaps |
| **Infrastructure Attacker** | "I'm attacking deployment, not code" | Container escape, exposed services, secrets in env |

## Strix-Inspired Patterns

- **Proof-of-Concept required:** Never report without proof — identify code path, construct exploit input, trace execution, show impact.
- **Chain findings across iterations:** Iteration 1 finds open endpoint -> Iteration 2 chains with IDOR. Each iteration reads past findings for chaining.
- **Suggest dynamic verification:** Where possible, provide curl/CLI commands to verify findings.

## Metric for the Loop

```
metric = (owasp_categories_tested / 10) * 50 + (stride_categories_tested / 6) * 30 + min(finding_count, 20)
```

Direction: higher is better. Maximum: 100. Baseline: 0. Incentivizes covering ALL categories before going deep.

## Flags & Modes

### `--diff` — Delta Mode

Only audit files changed since last audit. Reads most recent `security/` subfolder.

1. Find latest `security/*/overview.md` by timestamp
2. Parse previous `findings.md` for tested files
3. `git diff --name-only {last_audit_commit}..HEAD` for changed files
4. Scope to changed files only
5. Mark findings as **New**, **Fixed**, or **Recurring**

See `references/security-output-templates.md` for the Delta Summary template.

If no previous audit exists, falls back to full audit with warning.

### `--fail-on` — Severity Threshold Gate

Exit non-zero if findings meet/exceed severity threshold. For CI/CD blocking.

```
/autoresearch:security --fail-on critical    # Blocks on any Critical
/autoresearch:security --fail-on high        # Blocks on Critical or High
/autoresearch:security --fail-on medium      # Blocks on Critical, High, or Medium
```

CI usage: `claude -p "/autoresearch:security --fail-on critical --iterations 10"`

### `--fix` — Auto-Remediation Mode

After audit, switches to `/autoresearch:fix` for confirmed Critical/High findings:
1. Run full security audit
2. Filter: only **Confirmed** + **Critical**/**High**
3. Each fix iteration: pick highest-severity, apply mitigation, commit, re-verify
4. If fixed -> keep; if still vulnerable -> revert and retry; if new findings -> revert immediately

**Safety rules:** Never fix Low/Info automatically. Never modify test files. Run tests after each fix (revert on failure). Max 3 attempts per finding. Updates findings.md with Status column, recommendations.md with checkmarks, creates fix-log.md.

### Combining Flags

```
/autoresearch:security --diff --fix --fail-on critical
Iterations: 15
```

Execution order: `--diff` narrows scope -> audit runs -> `--fix` remediates -> `--fail-on` checks remaining findings.

### CI/CD GitHub Action

When `.github/workflows/` detected, offer to generate `security-audit.yml` via AskUserQuestion. See `references/security-output-templates.md` for the full GitHub Action template. Generated ONCE.

### Historical Comparison

When previous audit exists in `security/`, auto-generate comparison:
- Match findings by location (file:line) or description
- Tag as Recurring, New, or Fixed

See `references/security-output-templates.md` for the Historical Comparison template.

## Error Recovery

| Error | Recovery |
|-------|----------|
| Can't determine tech stack | Ask user |
| No API routes found | Scan all exported functions with HTTP patterns |
| Dependency audit fails | Skip, note in report, continue |
| Code too large for context | Focus on attack surface files (API, auth, DB) |
| False positive suspected | Mark as "Possible", include caveats |

## Anti-Patterns

- Do NOT report theoretical risks without code evidence (every finding needs file:line)
- Do NOT skip categories (aim for 100% OWASP + STRIDE coverage)
- Do NOT auto-fix vulnerabilities unless `--fix` flag is used
- Do NOT test against live production (static analysis only, suggest dynamic tests)
- Do NOT report duplicates (check results log before logging)
- Do NOT prioritize quantity over quality (5 confirmed critical > 50 theoretical lows)

## Report Output — Structured Folder

### Folder Structure

```
{project_root}/security/{YYMMDD}-{HHMM}-{slug}/
  overview.md, threat-model.md, attack-surface-map.md, findings.md,
  owasp-coverage.md, dependency-audit.md, recommendations.md, security-audit-results.tsv
```

### Folder Naming: `security/{YYMMDD}-{HHMM}-{audit-type-slug}/`

Slug rules: no scope -> `stride-owasp-full-audit`, auth scope -> `auth-authorization-audit`, API scope -> `api-security-audit`, infra -> `infrastructure-security-audit`, custom focus -> kebab-case + `-audit`.

### File Descriptions

See `references/security-output-templates.md` for all file templates (overview.md, threat-model.md, attack-surface-map.md, findings.md, owasp-coverage.md, dependency-audit.md, recommendations.md).

### Creation Protocol

1. **Start:** `mkdir -p security/{YYMMDD}-{HHMM}-{slug}`
2. **Setup Phase:** Write threat-model.md, attack-surface-map.md, security-audit-results.tsv (header + baseline)
3. **Loop:** Append to security-audit-results.tsv after each iteration
4. **Completion:** Write findings.md, owasp-coverage.md, dependency-audit.md, recommendations.md, overview.md (LAST)
5. **Print:** `Security audit complete. Report saved to: security/{folder}/overview.md`

### Gitignore

Add `security-audit-results.tsv` to `.gitignore` if not already present.
