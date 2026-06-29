# Karpathy Principles for AI-Assisted Coding

Derived from Andrej Karpathy's observations on LLM coding failure modes (90k+ stars at github.com/forrestchang/andrej-karpathy-skills). These four principles are the highest-leverage, lowest-cost intervention for AI-assisted coding — behavioral constraints beat feature checklists.

---

## The Problem

> "The models make wrong assumptions on your behalf and just run along with them without checking. They don't manage their confusion, don't seek clarifications, don't surface inconsistencies, don't present tradeoffs, don't push back when they should."

> "They really like to overcomplicate code and APIs, bloat abstractions, don't clean up dead code... implement a bloated construction over 1000 lines when 100 would do."

> "They still sometimes change/remove comments and code they don't sufficiently understand as side effects, even if orthogonal to the task."

---

## The Four Principles

### 1. Think Before Coding

**Counters:** Wrong assumptions, silent guessing, missing tradeoffs.

**What to include in agent config:**
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop and ask.

**Example wording (adapt to project voice):**

```markdown
### Think Before Coding
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop and ask.
```

### 2. Simplicity First

**Counters:** Overengineering, bloated abstractions, speculative flexibility.

**What to include in agent config:**
- No features beyond what was asked.
- No abstractions for single-use code.
- No speculative flexibility or configurability.
- If 200 lines could be 50, rewrite it.

**Example wording:**

```markdown
### Simplicity First
- No features beyond what was asked.
- No abstractions for single-use code.
- No speculative flexibility or configurability.
- If 200 lines could be 50, rewrite it.
```

### 3. Surgical Changes

**Counters:** Scope creep, drive-by refactors, unintended side effects.

**What to include in agent config:**
- Don't improve adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Remove only orphans YOUR changes created.

**Example wording:**

```markdown
### Surgical Changes
- Don't improve adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Remove only orphans YOUR changes created.
```

### 4. Goal-Driven Execution

**Counters:** Vague task interpretation, unverifiable outcomes, missing success criteria.

**What to include in agent config:**
- Transform tasks into verifiable goals with success criteria.
- "Fix the bug" → "Write a test that reproduces it, then make it pass."
- For multi-step tasks, state a plan with verify hooks.

**Example wording:**

```markdown
### Goal-Driven Execution
- Transform tasks into verifiable goals with success criteria.
- "Fix the bug" → "Write a test that reproduces it, then make it pass."
- For multi-step tasks, state a plan with verify hooks.
```

---

## Audit Checklist

When auditing an existing agent config, score each principle:

| Principle | ✅ Present & specific | ⚠️ Present but generic | ❌ Missing |
|-----------|----------------------|------------------------|-----------|
| Think Before Coding | Has project-specific examples of when to ask | Says "ask when unsure" with no context | No mention of assumption surfacing |
| Simplicity First | Names specific anti-patterns seen in the codebase | Generic "keep it simple" | No anti-overengineering rules |
| Surgical Changes | References actual style guide or conventions | Says "match existing style" | No scope discipline rules |
| Goal-Driven Execution | Includes project test commands and verify steps | Says "write tests" generically | No verifiable goal transformation |

**Scoring:**
- All 4 ✅ → Behavioral constraints are strong
- Any ❌ → HIGH severity gap — these are the most impactful missing sections
- All ⚠️ → MEDIUM severity — present but need project-specific sharpening

---

## Integration Patterns

### Merging into existing methodology sections

If the project already has methodology sections (e.g., "Debugging Protocol", "Code Review Guidelines"), merge the missing Karpathy principles into those sections rather than creating a duplicate "Behavioral Constraints" block.

**Example:** A project with a "Debugging Protocol" that says "reproduce the bug first" already partially covers Goal-Driven Execution. Add the missing aspects (verifiable goals, test-first transformation) to that section.

### Adapting to project voice

The example wordings above are direct and imperative. Adapt to the project's existing tone:
- **Formal codebase:** "Engineers should state assumptions explicitly and seek clarification when requirements are ambiguous."
- **Casual codebase:** "Say what you're assuming. If you're not sure, ask."
- **Terse codebase:** "State assumptions. Ask if unclear."

The content matters more than the wording. All four principles must be present.
