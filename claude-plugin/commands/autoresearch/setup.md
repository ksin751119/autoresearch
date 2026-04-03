---
name: autoresearch:setup
description: Interactive wizard — asks questions one at a time, generates .autoresearch/config.yaml, then launches autoresearch
argument-hint: "[goal description]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-config.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)"]
---

EXECUTE IMMEDIATELY — do not deliberate, do not ask clarifying questions before reading the protocol.

## Argument Parsing (do this FIRST)

Extract the goal from $ARGUMENTS. The user may provide extensive context — treat the entire text as the goal. Look for `Goal:` keyword; if absent, the full $ARGUMENTS text IS the goal.

## Execution

1. Read the setup wizard protocol: `.claude/skills/autoresearch/references/setup-workflow.md`
2. Execute the 7-question wizard with the extracted goal
3. Generate `.autoresearch/config.yaml`
4. Show Configuration Summary
5. On Launch: validate, setup loop, begin iteration

Stream all output live — never run in background.
