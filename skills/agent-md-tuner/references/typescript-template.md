# TypeScript Project Template

Language-specific template for TypeScript projects. Adapt based on detected tooling.

---

## Detection Signals

| Signal | Indicates |
|--------|-----------|
| `tsconfig.json` | TypeScript project |
| `vite.config.ts` | Vite build tool |
| `vitest.config.ts` or `vitest` in package.json | Vitest test runner |
| `next.config.*` | Next.js framework |
| `astro.config.*` | Astro framework |
| `nuxt.config.*` | Nuxt framework |
| `jest.config.*` + `ts-jest` or `@swc/jest` | Jest with TS |
| `biome.json` | Biome linter/formatter |
| `eslint.config.*` + `typescript-eslint` | ESLint with TS |
| `.prettierrc*` | Prettier formatter |
| `bun.lock` | Bun runtime |

---

## Template: Vite + Vitest Stack

Use when both `vite.config.ts` and `vitest` are detected. This is the most common modern TS stack.

```markdown
# [Project Name] — Agent Guide

## About
[1-3 sentences]

## Behavioral Constraints
[All four Karpathy principles — see karpathy-principles.md]

## Project Context

### Stack
- **Language:** TypeScript (strict mode)
- **Build:** Vite
- **Test:** Vitest
- **Lint:** [detected: Biome | ESLint + typescript-eslint]
- **Format:** [detected: Biome | Prettier]
- **Package manager:** [detected: pnpm | bun | npm | yarn]

### Commands
| Task | Command |
|------|---------|
| Install deps | `pnpm install` |
| Dev server | `pnpm dev` |
| Build | `pnpm build` |
| Type check | `pnpm tsc --noEmit` |
| Test | `pnpm vitest run` |
| Test (watch) | `pnpm vitest` |
| Lint | `pnpm biome check .` |
| Format | `pnpm biome format --write .` |

### Directory Structure
[Detected from project]

### Conventions
- Strict TypeScript — no `any`, no `@ts-ignore` without justification.
- Prefer `type` over `interface` unless extending. [or vice versa — match project]
- Imports: use path aliases from tsconfig if configured.
- Tests: colocated `*.test.ts` files next to source. [or `__tests__/` — match project]
```

## Template: Next.js Stack

Use when `next.config.*` is detected.

```markdown
### Stack
- **Language:** TypeScript (strict mode)
- **Framework:** Next.js [detected version] (App Router | Pages Router)
- **Test:** [detected: Vitest | Jest + @swc/jest]
- **Lint:** `next lint` + ESLint
- **Package manager:** [detected]

### Commands
| Task | Command |
|------|---------|
| Install deps | `pnpm install` |
| Dev server | `pnpm dev` |
| Build | `pnpm build` |
| Type check | `pnpm tsc --noEmit` |
| Test | `pnpm vitest run` |
| Lint | `pnpm lint` |

### Conventions
- App Router: `app/` directory with `page.tsx`, `layout.tsx`, `loading.tsx` conventions.
- Server Components by default. Add `'use client'` only when needed.
- Server Actions in `app/actions/` or colocated with the route.
- API routes in `app/api/` using Route Handlers.
```

## Template: Plain TypeScript (Library / CLI)

Use when `tsconfig.json` exists but no framework is detected.

```markdown
### Stack
- **Language:** TypeScript (strict mode)
- **Build:** `tsc` [or detected: tsup | esbuild | rollup]
- **Test:** [detected: Vitest | Jest | node --test]
- **Lint:** [detected]
- **Package manager:** [detected]

### Commands
| Task | Command |
|------|---------|
| Install deps | `npm install` |
| Build | `npm run build` |
| Type check | `npx tsc --noEmit` |
| Test | `npm test` |
| Lint | `npm run lint` |

### Conventions
- Exports: use explicit named exports. Barrel files (`index.ts`) at package boundary only.
- Strict mode: `"strict": true` in tsconfig. No loosening without justification.
```

---

## Vite and Vitest: When to Include

**Include Vite** when `vite.config.*` exists. Vite is the build tool — it affects dev server, build output, and path resolution. Agents need to know:
- Dev server runs on `localhost:5173` by default
- Path aliases in `vite.config.ts` must match `tsconfig.json` paths
- Environment variables use `import.meta.env` (not `process.env`)

**Include Vitest** when `vitest` appears in package.json dependencies or `vitest.config.*` exists. Vitest is the test runner — it affects how agents write and run tests. Agents need to know:
- `vitest run` for single run (CI), `vitest` for watch mode (dev)
- Vitest uses Vite's config for path resolution and transforms
- Test files: `*.test.ts`, `*.spec.ts` (match project convention)
- `vi.mock()` for mocking, `vi.fn()` for spies

**Skip Vite/Vitest** when the project uses a different build/test stack. Don't include them just because they're popular.

---

## Adaptation Rules

1. **Detect, don't assume.** Read `package.json` scripts and config files. Use actual commands, not template defaults.
2. **Match the project's package manager.** If `bun.lock` exists, use `bun` commands. If `pnpm-lock.yaml`, use `pnpm`. Never mix.
3. **Match the project's conventions.** If tests are in `__tests__/`, say so. If they're colocated, say so. Don't impose a preference.
4. **Include type checking.** TypeScript projects should always have a `tsc --noEmit` command. If the project doesn't have one, flag it as a gap.
5. **Biome vs ESLint+Prettier.** If `biome.json` exists, the project uses Biome for both linting and formatting. Don't add Prettier commands.
