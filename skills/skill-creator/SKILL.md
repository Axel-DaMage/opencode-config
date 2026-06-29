---
name: skill-creator
description: |
  Create/scaffold agent skills (SKILL.md outline, file layout/folder structure,
  quick scaffold). Use when asked to create or scaffold a skill, to package steps
  into a reusable skill, run evals to test a skill, benchmark skill performance,
  optimize a skill's description for better triggering accuracy, or when the user
  says "use the skill-creator skill" / "skill-creator".
  DO NOT use for: general coding tasks, non-skill file creation, editing files
  unrelated to skill development, or modifying existing application code.
allowed-tools: Read Write Edit Glob Grep Bash Task WebFetch
context: fork
compatibility: "OpenCode, Codex CLI, GitHub Copilot, Kiro. Requires Bash."
---

# Skill Creator

Create, evaluate, improve, and optimize skills across OpenCode, Codex, Copilot, and Kiro.

**Announce at start (exact phrase required):** "I'm using the skill-creator skill."
You may follow with a second sentence like "I'm using the skill-creator skill to help design your new skill."

## Workflow Overview

Choose the workflow that matches the user's request:

| Request | Workflow |
|---------|----------|
| "Create a skill" / "scaffold a skill" | **Create** → Search → Interview → Generate → Validate |
| "Improve this skill" / "it's not working well" | **Improve** → Write Evals → Run → Grade → Iterate |
| "Run evals" / "test this skill" / "benchmark" | **Eval** → Run Evals → Grade → Aggregate |
| "Optimize description" / "it doesn't trigger" | **Optimize** → Generate Queries → Test → Iterate |
| `--quick` flag | **Quick Scaffold** → Skip interview, output template |

---

## Create Workflow

### Phase 1: Search Before Create

Before creating any skill, search for similar existing skills:

1. **Search local skills:**
   ```bash
   ls skills/
   ```
   Review names and read SKILL.md files that might overlap

2. **Ask about external search:**
   "Should I check external skill repositories (Gentleman-Skills, awesome-claude-skills) for similar skills?"

3. **If similar found, offer options:**
   - Adapt existing skill to your needs
   - Extend existing skill with new capabilities
   - Create new skill (explain why it's different)

4. **If no similar found:** Proceed to Phase 2

### Phase 2: Adaptive Interview

Gather requirements before creating. Ask one question at a time and wait for
the answer before proceeding to the next.

**Question sequence:**

1. "What's the primary purpose of this skill?" — accept freeform answer
2. "What tools will it need?" — suggest: Bash, Read/Glob/Grep, WebFetch, Task, MCP tools
3. "Which runtime should this target?" — suggest: OpenCode, Codex, Copilot, Kiro, All four, or Portable
   - **If OpenCode or Kiro:** "Should it use `context: fork` for isolated execution?" (default: yes)
   - **If Copilot:** "Note: `allowed-tools` uses different syntax on Copilot. I'll use Copilot-compatible values."
   - **If All four or Portable:** "I'll use only universally-supported frontmatter fields. Platform-specific fields (`allowed-tools`, `context: fork`) will be omitted."
4. "Will it have executable scripts?" — suggest: Yes or No
5. "Should it include eval test cases?" — suggest: Yes (recommended) or No

**Ask if unclear:**

6. Does it need configuration files (YAML/JSON)?
7. Does it need template assets?
8. Should it include optional cross-runtime metadata (`compatibility`, `metadata`)?
9. Does it handle secrets, credentials, or destructive operations (kill, delete, drop)?

**Context-aware shortcuts:**
- If the user's original request already answers a question, skip it
- If running in an autonomous/batch mode where questions would block,
  use sensible defaults and document assumptions made

**Defaults for autonomous mode:**
- Runtime: portable (safest default)
- Scripts: yes (if the user mentioned automation)
- Eval test cases: yes
- Tools: Read Glob Grep Bash (minimal safe set)

**Determine structure from answers:**

| Complexity | Structure | When |
|------------|-----------|------|
| Simple | Just SKILL.md | Instructions only, no automation |
| With scripts | SKILL.md + `scripts/` | Executable bash scripts |
| With config | SKILL.md + `config/` | Domain-specific data in YAML |
| With assets | SKILL.md + `assets/` | Templates, examples, reference files |
| With tests | Above + `tests/` | Scripts that need validation |

### Phase 3: Generate Skill

1. **Validate name:**
   - Pattern: `^[a-z][a-z0-9-]*[a-z0-9]$`
   - Minimum 3 characters
   - Directory must not exist

2. **Create structure:**
   ```bash
   mkdir -p skills/<name>
   mkdir -p skills/<name>/scripts  # if needed
   mkdir -p skills/<name>/config   # if needed
   mkdir -p skills/<name>/assets   # if needed
   mkdir -p skills/<name>/tests    # if needed
   ```

3. **Generate SKILL.md** with:
   - Proper frontmatter (name, description, allowed-tools, context)
   - Description MUST include "DO NOT use for:" with 2-3 negative triggers to prevent false activation
   - Optional portability fields only when requested/compatible (`compatibility`, `metadata`)
   - Purpose and usage sections
   - Quick reference table (if has actions)
   - Script documentation (if has scripts)

4. **Generate stub scripts** (if applicable):
   - Main script with action pattern
   - Proper shebang and error handling
   - Runtime validator helper: `scripts/validate-runtime.sh`

5. **Generate smoke test** (if has scripts):
   - `tests/smoke.sh` that validates basic functionality

6. **Generate Security section** (if skill handles secrets or destructive ops):
   - Add `> **Security:** ...` blockquote warnings at each point of risk in the SKILL.md
   - Credential handling: "Use environment variables, never hardcode secrets"
   - Destructive operations: "Require user confirmation before delete/kill/drop operations"
   - Data leakage: "Never log, echo, or include API keys/tokens in output"

### Phase 4: Validation Checklist

Before finishing, verify:

- [ ] Name matches directory name
- [ ] Description explains WHEN to use (trigger conditions)
- [ ] Description does NOT summarize the workflow (CSO violation — agents skip loading the skill)
- [ ] Description includes "DO NOT use for:" negative triggers
- [ ] `allowed-tools` is minimal and scoped
- [ ] Scripts have `#!/usr/bin/env bash` and `set -euo pipefail`
- [ ] Smoke test exists if scripts exist
- [ ] No duplicate of existing skill
- [ ] Runtime profile is documented (`opencode`, `codex`, `copilot`, or `portable`)
- [ ] Optional fields (`allowed-tools`, `compatibility`, `metadata`) align with target runtime support
- [ ] If skill handles secrets or destructive ops, Security section exists with blockquote warnings

### Phase 5: Validation Loop (Recommended)

Use a validator-first loop before final handoff:

1. Validate structure/frontmatter
2. Fix all reported issues
3. Re-run validation until clean
4. Run smoke tests (if scripts exist)
5. Run runtime-profile check:

```bash
bash skills/skill-creator/scripts/validate-runtime.sh skills/<name> --runtime opencode
```

---

## Eval Workflow

Use this workflow when asked to test, evaluate, or benchmark a skill.

### Writing Evals

Create `evals/evals.json` in the skill directory (see `references/schemas.md` for schema):

```json
{
  "skill_name": "my-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User prompt that exercises the skill",
      "expected_output": "What a correct result looks like",
      "expectations": [
        "Output contains the expected data",
        "No errors were reported",
        "File output.json was created"
      ]
    }
  ]
}
```

**Writing good expectations:**
- Make them **verifiable** — string matches, file existence, regex patterns
- Avoid subjective criteria ("output looks good")
- Include both positive checks ("file was created") and negative checks ("no errors")
- Aim for 3-7 expectations per eval case

### Running Evals

Run a single eval case against a skill:

```bash
bash skills/skill-creator/scripts/run-eval.sh \
  --skill skills/<name> \
  --prompt "the eval prompt" \
  --output-dir /tmp/eval-run-1
```

For benchmarking, run both with-skill and without-skill variants. Launch all
runs at once so they finish around the same time.

### Grading

Grade eval output against expectations:

```bash
bash skills/skill-creator/scripts/grade-eval.sh \
  --run-dir /tmp/eval-run-1 \
  --expectations '["Output contains X", "File Y was created"]'
```

Produces `grading.json` with pass/fail for each expectation and overall pass rate.

### Aggregating Benchmarks

After multiple runs, aggregate into statistics:

```bash
bash skills/skill-creator/scripts/aggregate-benchmark.sh \
  --results-dir /tmp/benchmark-results \
  --skill-name my-skill
```

Produces `benchmark.json` and `benchmark.md` with mean, stddev, min, max for
pass_rate and time per configuration (with_skill vs without_skill).

---

## Improve Workflow

Use this when asked to improve an existing skill or when eval results show problems.

### Iterative Improvement Loop

1. **Baseline** — Run evals against current skill version, grade, record pass rate as v0
2. **Analyze** — Identify which expectations fail and why
3. **Improve** — Make targeted changes to SKILL.md or scripts based on failure analysis
4. **Re-eval** — Run same evals against improved version
5. **Compare** — If pass rate improved, keep changes (new best). If not, revert.
6. **Repeat** — Up to 5 iterations or until pass rate plateaus

Track progress in `history.json` (see `references/schemas.md`).

**Key principle:** Change one thing at a time. If you change multiple things and
pass rate drops, you won't know which change caused the regression.

---

## Description Optimization Workflow

Use this when a skill isn't triggering correctly — it activates for wrong
prompts or doesn't activate for right ones.

> **CSO Rule:** Description must contain ONLY trigger conditions, NEVER workflow
> summary. If the description summarizes what the skill does step-by-step, agents
> read the description, decide they already know the workflow, and skip loading
> the full SKILL.md. This is the #1 cause of skills being "loaded but ignored."

### Step 1: Generate Trigger Queries

Create 20+ test queries split evenly:
- **should-trigger**: Prompts that should activate this skill
- **should-not-trigger**: Prompts that should NOT activate this skill (but might be confused for it)

**Near-miss negatives are the most valuable test cases** — prompts that are close to the skill's domain but should NOT trigger it. These catch false activation, which is a bigger problem than under-triggering.

Present the queries to the user for review before proceeding.

### Step 2: Optimization Loop

For each candidate description:
1. Score against query set (does description match should-trigger, reject should-not-trigger?)
2. Use 60/40 train/test split to avoid overfitting
3. Propose improved description based on failures
4. Re-score on both train and test sets
5. Select best by **test score** (not train score)
6. Iterate up to 5 times

```bash
bash skills/skill-creator/scripts/optimize-description.sh \
  --skill skills/<name> \
  --queries queries.json \
  --iterations 5
```

### Step 3: Apply Result

Update the skill's SKILL.md frontmatter with the optimized description.
Show the user the before/after and the improvement in trigger accuracy.

---

## Quick Mode

When invoked with `--quick` flag:

1. Skip Phase 1 (search)
2. Skip Phase 2 (interview)
3. Create directory + SKILL.md from template
4. Inform user what to customize

```bash
mkdir -p skills/<name>
# Copy template from assets/SKILL-TEMPLATE.md
# Replace name placeholder
# Write to skills/<name>/SKILL.md
```

---

## Frontmatter Reference

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Matches directory, lowercase-kebab-case |
| `description` | Yes | Include "Use when..." trigger conditions AND "DO NOT use for:" negative triggers. Describe WHEN to use, not HOW it works. |
| `allowed-tools` | OpenCode/Codex: Yes; Portable: Optional | Whitelist, scope bash commands (e.g., `Bash(gh:*)`) |
| `context` | Recommended | Use `fork` for isolated execution |
| `compatibility` | Optional | Runtime support notes |
| `metadata` | Optional | Additional namespaced metadata for tooling |

### allowed-tools Patterns

| Pattern | Meaning |
|---------|---------|
| `Bash` | Any bash command (broad) |
| `Bash(gh:*)` | Only `gh` commands |
| `Bash(./scripts/*)` | Only scripts in skill's scripts/ dir |
| `Read Glob Grep` | File reading tools |
| `Task` | Can spawn subagents |
| `WebFetch` | Can fetch URLs |

### Cross-Platform Frontmatter Compatibility

Not all fields work on all platforms. Use this table when generating frontmatter:

| Field | OpenCode | Codex | Copilot | Kiro | Portable |
|-------|----------|-------|---------|------|----------|
| `name` | ✅ Required | ✅ Required | ✅ Required | ✅ Required | ✅ Required |
| `description` | ✅ Required | ✅ Required | ✅ Required | ✅ Required | ✅ Required |
| `allowed-tools` | ✅ Space-separated | ✅ Space-separated | ⚠️ Different syntax | ✅ Space-separated | Omit |
| `context: fork` | ✅ Supported | ❌ Ignored | ❌ Ignored | ✅ Supported | Omit |
| `compatibility` | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Safe |
| `metadata` | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Optional | ✅ Safe |

**allowed-tools syntax differs by platform:**
- **OpenCode / Codex / Kiro**: `Bash(gh:*) Bash(./scripts/*) Read Glob Grep` (scoped, space-separated)
- **Copilot**: Uses `shell` keyword (broad — no scoping). Only pre-approve if you trust the skill source.
- **Portable**: Omit `allowed-tools` entirely — let each platform's defaults apply.

## Script Conventions

All bash scripts must include:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Action pattern for multi-command scripts:

```bash
ACTION="${1:-help}"
case "$ACTION" in
    action1) do_action1 "$@" ;;
    action2) do_action2 "$@" ;;
    help|*) show_help ;;
esac
```

## Smoke Test Template

For skills with scripts, generate `tests/smoke.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Smoke Test: <skill-name> ==="

# Test 1: Help command works
echo "Testing help command..."
bash "$SCRIPT_DIR/scripts/main.sh" help > /dev/null
echo "✓ Help command works"

# Test 2: Basic functionality
echo "Testing basic functionality..."
# Add skill-specific tests here
echo "✓ Basic tests pass"

echo "=== All smoke tests passed ==="
```

## Progressive Disclosure

Keep skills efficient:

- **Description** (~100 tokens): Loaded at startup, include trigger keywords
- **SKILL.md** (<5,000 tokens): Core instructions, loaded on activation
- **Subdirectories**: Heavy content, loaded on-demand
- **References**: Prefer one-level links directly from `SKILL.md`; avoid deep nested reference chains

## Writing Style

Skill instructions are read by agents across different harnesses. Follow these principles:

- Use **clear, direct language** — avoid jargon without explanation
- Use **intent-based instructions** ("ask the user", "suggest options") not tool-specific references ("call ask_user", "use the question tool")
- **Explain why** behind instructions rather than rigid MUST/NEVER directives. Agents follow rules better when they understand the reasoning. Reserve MUST/NEVER for true invariants (security, data loss). For preferences, explain the tradeoff.
- Keep **MUST/NEVER density low** — skills with too many absolute directives cause agents to ignore them all
- Provide **examples** for complex workflows
- Include **defaults** for every decision point so autonomous execution doesn't hang

## Runtime Profiles

Choose one default and optimize for it:

- **`opencode`**: Include `allowed-tools` (scoped, space-separated) and `context: fork`. Skills discovered from `~/.config/opencode/skills/`.
- **`codex`**: Same `allowed-tools` syntax as OpenCode. No `context: fork` support. Skills in `~/.codex/skills/` (individual symlinks, preserves `.system/`).
- **`copilot`**: Uses Agent Skills standard. `allowed-tools` syntax differs (`shell` keyword, no scoping). No `context: fork`. Skills in `~/.copilot/skills/`.
- **`kiro`**: Same as OpenCode (`allowed-tools`, `context: fork` both supported). Default agent auto-discovers from `~/.kiro/skills/`.
- **`portable`**: Use only `name`, `description`, and `compatibility` in frontmatter. Omit `allowed-tools` and `context: fork` — they are not universally supported. This is the safest default for skills targeting multiple platforms.

When uncertain, default to `portable` and add runtime-specific notes in a dedicated compatibility section.

## Reference Files

- `references/schemas.md` — JSON schemas for evals, grading, benchmarks, history
- `assets/SKILL-TEMPLATE.md` — Quick-mode template

For well-structured skills in this repo, see:
- `@skills/github-ops/SKILL.md` - Multi-script skill with domains
- `@skills/production-hardening/SKILL.md` - Multi-phase analysis and implementation
