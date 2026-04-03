---
name: autoresearch:security
description: "Autonomous security audit — STRIDE threat model + OWASP Top 10 + red-team with 4 adversarial personas. Use when: \"security audit\", \"threat model\", \"find vulnerabilities\", \"OWASP\", \"STRIDE\", \"red-team\"."
argument-hint: "[Scope/Focus description] [--max-iterations N] [--diff] [--fix] [--fail-on SEVERITY]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

## Workflow Preset: Security Audit

Pre-filled Workflow:
```
1. Read context and scan codebase for tech stack, dependencies, configs
2. Identify assets — data stores, auth systems, external services, user inputs
3. Map trust boundaries — browser↔server, public↔auth, user↔admin
4. Build STRIDE threat model for each trust boundary
5. Map attack surface — entry points, data flows, abuse paths
6. Test one vulnerability vector with code evidence
7. Log finding with severity, OWASP category, and code reference
8. Update context with findings and coverage progress
```

**Default config:**
- Evaluator: off (security findings are self-evident with code evidence)

Load `references/security-workflow.md` for the full security audit protocol, then follow `commands/autoresearch.md` Step 2+ with Workflow pre-filled.

Parse $ARGUMENTS for scope/focus as the Goal. Pass --diff, --fix, --fail-on flags through to Notes.
