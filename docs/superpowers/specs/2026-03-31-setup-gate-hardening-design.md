# Setup Gate Hardening — Design Spec

## Problem

`/autoresearch` interactive mode frequently fails to collect all required fields before starting the loop. Root causes:

1. **Direction field missing from decision logic** — `autoresearch.md` checks 4 fields (Goal/Scope/Metric/Verify) but SKILL.md requires 5 (+ Direction)
2. **No post-setup validation** — after AskUserQuestion, no check that all fields are actually populated
3. **No verify/guard dry-run** — invalid commands only fail at iteration 1
4. **Phase 0 git checks missing** — no dirty tree / detached HEAD / repo existence check
5. **No final confirmation** — Claude jumps to loop without showing user the complete config
6. **Scope glob not validated** — could match zero files

## Solution: Dual-Layer Hardening

### Layer 1: Prompt Hardening (autoresearch.md + SKILL.md)

#### autoresearch.md Changes

**Fix decision logic (line 28):**
```
Before: "If Goal, Scope, Metric, and Verify are all extracted — proceed"
After:  "If Goal, Scope, Metric, Direction, and Verify are all extracted — proceed"
```

**Add explicit step-by-step interactive setup flow:**

When any field is missing, Claude MUST follow this exact sequence:

1. Scan project (detect tooling, file structure, test framework)
2. Ask Goal (if missing)
3. Ask Scope with smart defaults from scan (if missing)
4. Ask Metric with detected options (if missing)
5. Ask Direction (if missing)
6. Ask Verify with detected commands (if missing)
7. Ask Guard — optional, can skip (if not provided)
8. Ask Iterations — optional, default unlimited (if not provided)
9. **MANDATORY: Display complete config summary, ask user to confirm [Launch / Edit / Cancel]**
10. Run `validate-config.sh` — must exit 0 before proceeding
11. Run `setup-loop.sh` — create state file
12. Enter loop

**Add explicit Phase 0 instruction:**

Before entering the loop, Claude must check:
- `git rev-parse --is-inside-work-tree` returns true
- `git status --porcelain` is empty (or warn user about uncommitted changes)
- `git symbolic-ref HEAD` succeeds (not detached HEAD)

#### SKILL.md Changes

**Strengthen Interactive Setup section:**

Replace the current batch-based approach with explicit sequential flow:
- Each question is one `AskUserQuestion` call
- After ALL questions answered, display full config summary
- User must confirm before proceeding
- Add the "Confirm and Launch" step as MANDATORY (not just in the wizard)

**Add validation step documentation:**

Document that `validate-config.sh` is called after user confirms, and what it checks.

### Layer 2: Mechanical Validation (validate-config.sh)

New script: `claude-plugin/scripts/validate-config.sh`

**Interface:**
```bash
validate-config.sh \
  --goal "..." \
  --scope "..." \
  --metric "..." \
  --direction "higher|lower" \
  --verify "..." \
  [--guard "..."]
```

**Checks (in order):**

1. **Required fields** — all 5 must be non-empty strings
2. **Direction value** — must be exactly "higher" or "lower"
3. **Git status:**
   - Is inside a git repo
   - Working tree is clean (warn if dirty, don't block)
   - Not detached HEAD
4. **Scope validation** — glob resolves to at least 1 file
5. **Verify dry-run:**
   - Run the verify command
   - Must exit 0
   - Must produce output containing at least one number
6. **Guard dry-run** (if provided):
   - Run the guard command
   - Must exit 0

**Output:**
- Exit 0 + "All checks passed" if everything OK
- Exit 1 + specific error message for first failure
- Warnings (dirty tree) printed to stderr but don't block

**Timeout:** Verify and guard dry-runs timeout after 60 seconds.

### Files Changed

| Action | File | What Changes |
|--------|------|-------------|
| Create | `claude-plugin/scripts/validate-config.sh` | New validation script |
| Modify | `claude-plugin/commands/autoresearch.md` | Fix Direction check, add validate step, add Phase 0, strengthen setup flow |
| Modify | `claude-plugin/skills/autoresearch/SKILL.md` | Strengthen interactive setup instructions, add confirmation step, add validate docs |
| Sync | `.claude/` dev copies | Mirror all changes |

### Scope

- **In scope:** `/autoresearch` main command only
- **Out of scope:** Other 8 sub-commands (Phase 2/3)
- **Out of scope:** Changes to `setup-loop.sh` or `stop-hook.sh` (already working correctly)

### Success Criteria

After this change:
1. Claude NEVER starts the loop without all 5 required fields populated
2. Claude ALWAYS shows complete config and asks for confirmation before launching
3. Invalid verify/guard commands are caught at setup time, not iteration 1
4. Scope globs that match zero files are caught at setup time
5. Git state issues are detected before loop starts
