---
name: autoresearch:cancel
description: Cancel the active autoresearch loop
allowed-tools: ["Bash(test -f .claude/autoresearch-loop.local.md:*)", "Bash(rm .claude/autoresearch-loop.local.md)", "Read(.claude/autoresearch-loop.local.md)"]
---

## Cancel Autoresearch Loop

1. Check if `.claude/autoresearch-loop.local.md` exists
2. If it exists:
   - Read the file to extract the current `iteration:` number and `goal:` field
   - Remove the file: `rm .claude/autoresearch-loop.local.md`
   - Report: "Cancelled autoresearch loop at iteration N (Goal: GOAL)"
3. If it does not exist:
   - Report: "No active autoresearch loop found."
