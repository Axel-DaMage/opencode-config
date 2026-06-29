# Monorepo Scoped Agent Config

Guide for generating per-subsystem agent config files in monorepos. Each workspace or subsystem gets its own scoped file that overrides or extends the root config.

---

## When to Generate Scoped Files

Generate scoped files when **all** of these are true:

1. The project is a monorepo (workspaces in `package.json`, `pnpm-workspace.yaml`, `Cargo.toml [workspace]`, or `lerna.json`)
2. Subsystems have **different stacks, conventions, or commands** (e.g., `apps/web` is Next.js, `packages/api` is Express)
3. The root config would exceed 100 lines if it included all subsystem details

**Do NOT generate scoped files** when:
- All workspaces share the same stack and conventions (one root file is enough)
- The monorepo has only 2-3 packages with trivial differences
- The user hasn't asked for it and the root file is under 100 lines

---

## Detection

### Workspace discovery

```
# Check these in order:
1. pnpm-workspace.yaml → packages field (glob patterns)
2. package.json → workspaces field (array or object with packages key)
3. Cargo.toml → [workspace] members
4. lerna.json → packages field
```

### Subsystem profiling

For each workspace, detect:
- **Stack:** framework, language, runtime (may differ from root)
- **Commands:** test/build/lint commands (may have workspace-specific scripts)
- **Conventions:** file structure, naming patterns
- **Shared dependencies:** which packages import from sibling packages

---

## File Placement

Place scoped files in the subsystem root, using the same filename as the root config:

```
monorepo/
├── AGENTS.md                    # Root: shared constraints + pointers
├── apps/
│   ├── web/
│   │   └── AGENTS.md            # Scoped: Next.js-specific
│   └── mobile/
│       └── AGENTS.md            # Scoped: React Native-specific
├── packages/
│   ├── api/
│   │   └── AGENTS.md            # Scoped: Express-specific
│   └── shared/
│       └── AGENTS.md            # Scoped: library conventions
```

For CLAUDE.md projects, use the same pattern with CLAUDE.md files.

---

## Root File Template

The root file stays lean — behavioral constraints and shared context only. Point to subsystem files for specifics.

```markdown
# [Project Name] — Agent Guide

## About
[Monorepo description. What the project is, how workspaces relate.]

## Behavioral Constraints
[All four Karpathy principles — see karpathy-principles.md]

## Project Context

### Monorepo Structure
| Workspace | Stack | Purpose |
|-----------|-------|---------|
| `apps/web` | Next.js + TypeScript | Customer-facing web app |
| `apps/mobile` | React Native + TypeScript | Mobile app |
| `packages/api` | Express + TypeScript | REST API |
| `packages/shared` | TypeScript | Shared types and utilities |

### Shared Commands
| Task | Command |
|------|---------|
| Install all deps | `pnpm install` |
| Build all | `pnpm -r build` |
| Test all | `pnpm -r test` |
| Lint all | `pnpm -r lint` |

### Cross-Package Rules
- Import from sibling packages via package name, not relative paths.
- Shared types live in `packages/shared`. Don't duplicate across workspaces.
- Changes to `packages/shared` require running tests in all consuming workspaces.

## Subsystem Guides
Each workspace has its own AGENTS.md with stack-specific commands and conventions.
See the workspace directory for details.
```

---

## Scoped File Template

Each scoped file covers only what differs from the root. Do NOT repeat behavioral constraints or shared rules.

```markdown
# [Workspace Name] — Agent Guide

## About
[1 sentence: what this workspace does, its role in the monorepo.]

## Stack
- **Framework:** [detected]
- **Language:** [detected]
- **Test:** [detected]
- **Lint:** [detected]

## Commands
| Task | Command |
|------|---------|
| Dev server | `pnpm dev` |
| Build | `pnpm build` |
| Test | `pnpm vitest run` |
| Lint | `pnpm lint` |
| Type check | `pnpm tsc --noEmit` |

## Directory Structure
[Key directories specific to this workspace]

## Conventions
[Workspace-specific patterns that differ from root]
```

---

## Scope Rules

1. **Root owns behavioral constraints.** Scoped files inherit them — never repeat or contradict.
2. **Scoped files own commands.** `pnpm dev` in `apps/web` may start Next.js; in `packages/api` it may start Express. Each scoped file has its own Commands table.
3. **Scoped files own conventions.** File naming, directory structure, and framework patterns are workspace-specific.
4. **Cross-package rules live in root.** Import conventions, shared type locations, and dependency policies apply to the whole monorepo.
5. **Keep scoped files under 50 lines.** If a scoped file grows beyond that, the workspace may need its own skills or agent-guides.

---

## Audit Additions for Monorepos

When auditing a monorepo, add these checks to the standard checklist:

| Check | ✅ | ⚠️ | ❌ |
|-------|---|---|---|
| Root file exists with shared constraints | Has behavioral constraints + monorepo structure table | Has root file but missing structure overview | No root file |
| Scoped files for distinct subsystems | Each workspace with a different stack has its own file | Some workspaces covered, others missing | No scoped files despite different stacks |
| No duplication across files | Scoped files reference root, don't repeat it | Minor duplication | Behavioral constraints copy-pasted into every scoped file |
| Cross-package rules documented | Import conventions, shared types, test impact documented | Partially covered | No cross-package guidance |
| Commands are workspace-specific | Each scoped file has correct commands for its stack | Commands present but generic | Root file tries to list all workspace commands |
