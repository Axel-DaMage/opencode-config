---
name: security-auditor
description: |
  Pre-deployment security audit for production releases and PR checks.
  Use BEFORE deploying to production/staging or when asked for a changed-only audit.
  Triggers: "deploy to production", "release", "pre-release", "security check",
  "merge to main", "audit before deploy", "security audit", "PR security audit",
  "changed-only audit".
  DO NOT use for: local dev, sandbox, feature branch testing.
  Requires fixing CRITICAL vulnerabilities before proceeding.
  Supports monorepos with scoped audits per app/package.
allowed-tools: Bash(trivy:*) Bash(semgrep:*) Bash(./scripts/*) Bash(brew:*) Bash(apt-get:*) Read Glob Grep Write(.security-audit/*)
context: fork
compatibility: "Harness-agnostic (OpenCode, Codex CLI, GitHub Copilot, Kiro). Requires trivy, semgrep, and gh CLI."
---

# Security Auditor Skill

Pre-deployment security audit that blocks on critical vulnerabilities. Context-aware, monorepo-ready, and integrated with GitHub security features.

Enhanced with:
- Security requirement extraction (threat/finding → requirement with acceptance criteria)
- Structured pre-deployment security checklist

## When to Use

- Before deploying to production or staging
- Before merging to main/master
- For pre-release security reviews
- When explicitly requested: "run security audit"

## When NOT to Use

- Local development testing
- Sandbox/ephemeral environments
- Feature branch iterations

## Tool Stack

| Tool | Purpose | License |
|------|---------|---------|
| **Trivy** | Secrets, dependencies, misconfigs | Apache 2.0 |
| **Semgrep** | SAST code analysis | LGPL 2.1 |
| **github-ops** | GitHub security alerts | (existing skill) |

## Audit Workflow

```
1. Detect project context (web app, API, CLI, library)
2. Detect monorepo structure (if applicable)
3. Resolve scope (app + dependencies)
4. Run parallel scans:
   - Secrets (trivy)
   - Dependencies (trivy)
   - Code SAST (semgrep)
   - Misconfigs (trivy)
   - GitHub alerts (github-ops)
5. Filter findings by project context
6. Extract actionable requirements: .security-audit/SECURITY-REQUIREMENTS.md
7. Generate report: .security-audit/SECURITY-AUDIT.md
8. Gate decision:
   - CRITICAL in scope → BLOCK deployment
   - HIGH → WARN
   - MEDIUM/LOW → Inform
```

## Running the Audit

**Always use the skill scripts (do not invent ad-hoc commands).**
Scripts live in `skills/security-auditor/scripts/`; `cd` into the skill directory before running them.
- Full audit: `./scripts/audit.sh`
- Changed-only/PR checks: `./scripts/audit.sh --changed-only`

### Full Audit (default for single-app repos)
```bash
cd skills/security-auditor
./scripts/audit.sh
```

### Scoped Audit (monorepos)
```bash
cd skills/security-auditor
./scripts/audit.sh --scope apps/my-api
```

### Changed-Only Audit (CI/PR checks)
```bash
cd skills/security-auditor
./scripts/audit.sh --changed-only
```

## Configuration

### contexts.yaml
Maps project types to relevant vulnerability categories. Prevents false positives by filtering out non-exploitable vulnerabilities (e.g., XSS in CLI tools).

### severity-gates.yaml
Defines what blocks deployment:
- CRITICAL + in-scope + exploitable = BLOCK
- Everything else = WARN or INFORM

### monorepo-patterns.yaml
Detection patterns for npm workspaces, Turborepo, Nx, Lerna, Go modules, Python projects.

### semgrep-rulesets.yaml
Curated Semgrep rule sets per project context (OWASP, security-audit, etc.).

## Output

Report saved to `<project-root>/.security-audit/SECURITY-AUDIT.md` — the root of the project being audited, resolved via the git repository root (falling back to the current directory if not a git repo). Override the location with `--output <dir>` or the `SECURITY_AUDIT_ROOT` environment variable.

Includes:
- Executive summary with severity counts
- Critical findings with remediation guidance
- Security requirement extraction summary and traceability
- Pre-deployment review checklist
- Scoped vs out-of-scope findings (monorepos)
- Full findings appendix

Additional generated artifact:
- `.security-audit/SECURITY-REQUIREMENTS.md` (prioritized requirements + acceptance criteria + test hints)

### Gitignore Recommendation

The audit report is a **point-in-time snapshot** and should NOT be committed to version control. Add this to your `.gitignore`:

```gitignore
# Security audit reports (generated, not source-controlled)
.security-audit/
```

**Why?**
- Reports contain timestamps and tool versions that change on every run
- Findings are environment-specific (different machines may have different tools)
- In CI/CD, audit reports should be artifacts, not committed files
- Committing reports creates noise in git history

## Blocking Behavior

The skill will **refuse to proceed with deployment** if:
1. CRITICAL severity finding exists
2. Finding is in the deployment scope (not an unrelated package)
3. Finding is exploitable in the project's context

Example:
- SQL injection in `apps/api/` being deployed → **BLOCKS**
- SQL injection in `apps/admin/` not being deployed → **WARNS only**
- XSS finding in a CLI tool → **IGNORED** (not exploitable)

## Integration with github-ops

If the project is a GitHub repository, the skill will also fetch:
- Dependabot vulnerability alerts
- Code scanning alerts
- Secret scanning alerts

These are merged with local findings for a comprehensive view.

## Security Requirement Extraction

The skill derives concrete security requirements from critical/high findings:

- Maps findings into requirement domains (auth, authorization, input validation, data protection, availability)
- Produces requirement statements with acceptance criteria and verification tests
- Adds traceability back to source findings
- Prioritizes by observed severity (CRITICAL/HIGH)

This helps convert a point-in-time scan into a backlog-ready remediation plan.

