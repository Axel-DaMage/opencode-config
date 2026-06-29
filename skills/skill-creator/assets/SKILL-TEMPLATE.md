---
name: SKILL_NAME
description: "SKILL_DESCRIPTION. Use when..."
allowed-tools: Read Glob Grep
context: fork
# Optional cross-runtime fields (include only when target runtime supports them):
# compatibility:
#   runtime: opencode|codex|claude-api|portable
# metadata:
#   owner: team-or-user
---

# SKILL_NAME

Brief description of what this skill does.

**Announce at start:** "I'm using the SKILL_NAME skill."

## When to Use

- Use case 1
- Use case 2

## Runtime Profile

- Target runtime: `opencode` (or `codex` / `claude-api` / `portable`)
- Portability notes: list any runtime-specific assumptions

## How to Use

Describe how to invoke and use this skill.

## Validation Loop

1. Validate frontmatter and structure
2. Fix issues and re-validate
3. Run smoke test (if scripts exist)

## Quick Reference

| Action | Description |
|--------|-------------|
| action1 | What it does |
| action2 | What it does |

## Notes

- Important caveats or limitations
- Links to external documentation
- If using optional fields, document fallback behavior when unsupported
