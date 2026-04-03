# Interactive Setup Pattern

Shared protocol for sub-skill interactive setup. Each sub-skill customizes the questions but follows this pattern.

## Protocol

1. **Check inline context** — If all required fields are provided inline (flags or `Key: value` syntax), skip setup entirely
2. **Auto-detect** — Scan project for relevant tooling, frameworks, file structure
3. **Batch questions** — Ask ALL missing fields in ONE `AskUserQuestion` call (never one at a time)
4. **Tool availability** — `AskUserQuestion` may be deferred. If calling fails, use `ToolSearch` to fetch the schema first, then retry. NEVER skip setup because of tool fetch issues.
5. **Show summary** — Display all collected fields for confirmation
6. **User confirms** — Launch / Edit / Cancel

## Question Format

Each question in the batch should have:

| Field | Description |
|-------|-------------|
| Header | Short label (e.g., "Scope", "Guard") |
| Question | Clear question with context from auto-detection |
| Options | 3-5 options including auto-detected suggestions and a sensible default |

## Key Rules

- **BLOCKING prerequisite** — No phase/loop execution before setup completes
- **Adaptive** — Only ask questions for fields NOT provided inline
- **Smart defaults** — Use auto-detection results to suggest options
- **Single batch** — All questions in one call to avoid back-and-forth
