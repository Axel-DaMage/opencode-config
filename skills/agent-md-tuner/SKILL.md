---
name: agent-md-tuner
description: "Audit, enhance, and restructure a project's AI agent configuration files (AGENTS.md, CLAUDE.md, .cursorrules). Use when setting up a new project for AI-assisted development, when agent behavior is poor, or when asked to tune agent config, improve AGENTS.md, set up CLAUDE.md, configure this project for AI coding, sharpen agent rules, or tune agent md. DO NOT use for: editing application code, creating skills (use skill-creator), security audits (use security-auditor), or general documentation."
allowed-tools: Read Write Edit Glob Grep
context: fork
compatibility: "OpenCode, Codex CLI, GitHub Copilot, Kiro. No external dependencies."
---

# Agent MD Tuner

Audit, enhance, and restructure a project's AI agent configuration files so coding agents perform better — fewer wrong assumptions, less overengineering, more surgical changes, and verifiable goals.

**Announce at start:** "I'm using the agent-md-tuner skill."

## Operating Modes

| Mode | When | What it does |
|------|------|-------------|
| **Create** | No agent config exists | Generate complete project-aware file from scratch |
| **Enhance** | Config exists, <150 lines, has gaps | Sharpen generic sections with project-specific details, merge missing behavioral constraints |
| **Restructure** | Config >150 lines or disorganized | Propose lean rewrite (<100 lines root) following 3-tier architecture |

Mode is auto-detected but user can override. The 150-line threshold is a guideline — also consider content density: a 200-line file where every line is project-specific may be fine, while a 120-line file with 80 lines of generic methodology may need restructuring.

---

## Workflow

### Phase 1: Detect Project Context

Read project files to build a profile. Do NOT execute commands — only read files.

**Discovery sequence:**

1. **Language & framework:** Check for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `setup.py`, `Gemfile`, `pom.xml`, `build.gradle`, `Makefile`. **If TypeScript is detected (`tsconfig.json`), consult `references/typescript-template.md` for stack-specific templates and adaptation rules.**
2. **Package manager:** From lockfiles — `bun.lock`→bun, `pnpm-lock.yaml`→pnpm, `yarn.lock`→yarn, `package-lock.json`→npm, `uv.lock`→uv, `Pipfile.lock`→pipenv, `Cargo.lock`→cargo, `go.sum`→go
3. **Test runner:** From config or scripts — `jest.config.*`, `vitest.config.*`, `.borp.yaml`, `pytest.ini`, `pyproject.toml [tool.pytest]`, `Cargo.toml`, `mocha` in package.json scripts, `.github/workflows/*.yml` (grep for test commands)
4. **Linter/formatter:** `eslint.config.*`, `.eslintrc*`, `biome.json`, `ruff.toml`, `pyproject.toml [tool.ruff]`, `.prettierrc*`, `rustfmt.toml`
5. **Build system:** `vite.config.*`, `webpack.config.*`, `tsconfig.json`, `Makefile`, `Dockerfile`
6. **CI/CD:** `.github/workflows/*.yml` — extract actual test/build/lint commands used in CI
7. **Directory structure:** `Glob` for `src/`, `lib/`, `tests/`, `test/`, `app/`, `pages/`, `components/`
8. **Monorepo signals:** `workspaces` in package.json, `pnpm-workspace.yaml`, `Cargo.toml [workspace]`, `lerna.json`. **If monorepo detected, consult `references/monorepo-scoped.md` for scoped file generation rules and templates.**

**Fallback for non-application repos:** If no language/framework markers are found, check for `setup.sh`, `install.sh`, `Makefile`, or a `scripts/` directory with shell scripts. Classify as "infrastructure/config" project. The Commands table should reflect actual project operations (setup, test, deploy) rather than the standard dev-loop categories (install deps, run tests, lint, build).

**Package manager fallback:** If no lockfile is found but `package.json` exists, infer npm. This is common for published npm libraries that don't commit lockfiles.

**Output:** A mental "Project Profile" — do not write it to a file, just hold it for the audit phase.

### Phase 2: Detect Existing Agent Config

Check for these files in the project root:

| File | Used by |
|------|---------|
| `AGENTS.md` | OpenCode, Codex CLI, Kiro |
| `CLAUDE.md` | Claude Code |
| `.cursorrules` | Cursor |
| `.github/copilot-instructions.md` | GitHub Copilot |
| `.cursor/rules/*.mdc` | Cursor rules |
| `.claude/skills/*/SKILL.md` | Claude Code skills |
| `docs/agent-guides/*.md` | Agent reference docs (Tier 3) |

Record: which files exist, their line counts, and a quick read of their content.

### Phase 3: Audit Against Checklist

Score each category. For each item, mark: ✅ present and project-specific, ⚠️ present but generic, ❌ missing, or **N/A** if the item doesn't apply to this project type (e.g., "lint commands" for a repo with no linter is N/A, not a gap).

**Category 1: Behavioral Constraints (Karpathy-derived) — MANDATORY, consult `references/karpathy-principles.md` for scoring rubric and example wording**

- [ ] **Think Before Coding** — Guidance to surface assumptions explicitly, present multiple interpretations when ambiguous, push back when a simpler approach exists, stop and ask when confused rather than guessing
- [ ] **Simplicity First** — Anti-overengineering rules: no features beyond what was asked, no abstractions for single-use code, no speculative flexibility/configurability, rewrite if 200 lines could be 50
- [ ] **Surgical Changes** — Scope discipline: don't improve adjacent code/comments/formatting, don't refactor what isn't broken, match existing style, mention (don't delete) unrelated dead code, remove only orphans YOUR changes created
- [ ] **Goal-Driven Execution** — Transform tasks into verifiable goals: "add validation" → "write tests for invalid inputs, then make them pass". Multi-step plans with verify hooks.

**Category 2: Project Context (must be specific, not generic)**

- [ ] Package manager and dependency install commands
- [ ] Test commands (unit, integration, e2e) with actual flags
- [ ] Lint/format commands
- [ ] Build commands
- [ ] Key architectural patterns and directory conventions
- [ ] Directory overview (What lives Where)

**Category 3: Progressive Disclosure**

- [ ] Root file is under 100 lines
- [ ] Deep content lives in skills or agent-guides (if project complexity warrants)
- [ ] Directory-level overrides for distinct subsystems (if monorepo — see `references/monorepo-scoped.md` for scoped file templates and audit checks)
- [ ] No duplicated content across files

**Category 4: Anti-Patterns**

- [ ] Not using agent config as a linter (use eslint/ruff/prettier instead)
- [ ] No absolute/machine-specific paths
- [ ] No stale or incorrect commands
- [ ] No bloated sections that the model will deprioritize
- [ ] No significant overlap between agent config and README.md (reference README for shared content instead of duplicating)

### Phase 4: Gap Report

Present findings to the user organized by severity:

- **CRITICAL** — No agent config at all
- **HIGH** — Missing behavioral constraints (any of the four Karpathy principles — see `references/karpathy-principles.md`) OR missing project-specific context (generic commands)
- **MEDIUM** — Missing progressive disclosure, minor structural issues
- **LOW** — Style, organization, minor anti-patterns

State the auto-detected mode (Create/Enhance/Restructure) and ask the user to confirm or override before proceeding.

### Phase 5: Apply Fixes

**Create mode** (no config found):

**Before generating, read `references/karpathy-principles.md` for exact wording and adaptation guidance.** All four principles MUST appear in the output.

Generate a complete file using this structure:

```markdown
# [Project Name] — Agent Guide

## About
[1-3 sentences: what this project is, what matters]

## Behavioral Constraints

### Think Before Coding
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop and ask.

### Simplicity First
- No features beyond what was asked.
- No abstractions for single-use code.
- No speculative flexibility or configurability.
- If 200 lines could be 50, rewrite it.

### Surgical Changes
- Don't improve adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Remove only orphans YOUR changes created.

### Goal-Driven Execution
- Transform tasks into verifiable goals with success criteria.
- "Fix the bug" → "Write a test that reproduces it, then make it pass."
- For multi-step tasks, state a plan with verify hooks.

## Project Context

### Stack
[Detected language, framework, key libraries]

### Commands
| Task | Command |
|------|---------|
| Install deps | [detected] |
| Run tests | [detected] |
| Lint | [detected] |
| Build | [detected] |
| Type check | [detected, if applicable] |

### Directory Structure
[Key directories and what lives in them]

### Conventions
[Detected patterns: naming, file organization, error handling]

## Commit and Push
- Use conventional commits (or detected convention).
- Run tests before committing.
- Do not push to main directly.
```

**Enhance mode** (config exists, has gaps):

For each gap found in the audit:
- **Missing section** → Append with project-specific content at the appropriate location
- **Generic section** → Sharpen by replacing generic text with actual detected commands. Examples:
  - "run tests" → `npm test` or `pytest -x --tb=short` or `cargo test`
  - "use the project's linter" → `npx eslint .` or `ruff check .`
  - "follow existing patterns" → name the actual patterns detected
- **Partial behavioral coverage** → Consult `references/karpathy-principles.md` for the full four principles and integration patterns. Merge missing principles into existing methodology sections. Do NOT create a duplicate section. If the project has a "Debugging Protocol" that partially covers Goal-Driven Execution, add the missing aspects (verifiable goals, test-first transformation) to that section. All four principles MUST be present in the final output.
- **Preserve** all existing project-specific rules and conventions verbatim.

Show the user a diff of proposed changes before writing.

**Restructure mode** (config >150 lines or disorganized):

1. Analyze the existing file and categorize each section:
   - Universal rules (→ stays in root file)
   - Task-specific guidance (→ recommend moving to skills/)
   - Deep reference material (→ recommend moving to docs/agent-guides/)
2. Propose a lean root file (<100 lines) following: About → Behavioral Constraints (all four Karpathy principles from `references/karpathy-principles.md` — mandatory) → Project Context → Progressive Disclosure pointers
3. Show complete before/after diff
4. This is the most invasive mode — require explicit user confirmation
5. If the user declines restructuring, fall back to Enhance mode

---

## Karpathy Principles Reference

**⚠️ MANDATORY: Read `references/karpathy-principles.md` before every audit, create, enhance, or restructure operation.** The reference contains the full four principles (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution), example wording for each, an audit scoring rubric, and integration patterns for merging into existing methodology sections. Every agent config produced or modified by this skill MUST include all four principles — no exceptions, no partial coverage.

---

## Output Format Selection

| Detected State | Action |
|----------------|--------|
| Nothing | Create AGENTS.md (works with OpenCode, Codex, Copilot, Kiro) |
| AGENTS.md exists, <150 lines | Enhance mode |
| AGENTS.md exists, >150 lines | Restructure mode |
| CLAUDE.md exists, <150 lines | Enhance mode |
| CLAUDE.md exists, >150 lines | Restructure mode |
| Both exist | Audit both, flag conflicts, enhance/restructure each |
| .cursorrules exists | Audit and enhance, note format differences |
| User requests specific format | Generate that format |

When creating from scratch, prefer AGENTS.md — it's recognized by the widest set of agents (OpenCode, Codex, Copilot, Kiro). Mention that the user can rename to CLAUDE.md for Claude Code if preferred.

---

## Important Rules

- **Never write without confirmation.** Always show proposed changes and get user approval.
- **Never delete existing content** in Enhance mode. Only append or sharpen.
- **Use real commands** from the project, not placeholders. If a command can't be detected, say so and ask.
- **Keep root files lean.** Under 100 lines for new files. The context window is a shared resource.
- **Don't use agent config as a linter.** Style rules belong in eslint/ruff/prettier configs, not AGENTS.md.
