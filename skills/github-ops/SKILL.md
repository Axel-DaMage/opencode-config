---
name: github-ops
description: |
  GitHub operations via gh CLI. Use for pull requests/PRs, GitHub code search,
  or drafting exact gh commands (owner/repo, gh pr list, gh search). Always use
  instead of WebFetch for github.com.
  DO NOT use for: local-only git operations, non-GitHub remotes (GitLab,
  Bitbucket), or reading repository file content that is already available locally.
allowed-tools: Bash(gh:*) Bash(git:*) Bash(./scripts/*) Read Glob Grep Task
context: fork
compatibility: "OpenCode, Codex CLI, GitHub Copilot. Requires gh CLI and git."
---

# GitHub Operations Skill

Full GitHub MCP Server parity using the `gh` CLI. This skill provides all the functionality of the official GitHub MCP Server without the token overhead.

**Requirements:** `gh` CLI installed and authenticated (`gh auth login`).

## Quick Reference

| Domain | Script | Key Operations |
|--------|--------|----------------|
| Repositories | `repos.sh` | view, clone, fork, list, create, delete, contents |
| Issues | `issues.sh` | list, view, create, close, reopen, comment, labels |
| Pull Requests | `prs.sh` | list, view, create, merge, diff, checks, review |
| Actions | `actions.sh` | runs, jobs, logs, artifacts, workflows, rerun |
| Releases | `releases.sh` | list, view, create, delete, download assets |
| Code Security | `code-security.sh` | code scanning alerts, dependabot alerts |
| Discussions | `discussions.sh` | list, view, comments, categories |
| Notifications | `notifications.sh` | list, mark read, subscription |
| Search | `search.sh` | repos, code, issues, PRs, users, commits |
| Users | `users.sh` | profile, followers, following, emails |
| Organizations | `orgs.sh` | info, members, teams, repos |
| Gists | `gists.sh` | list, view, create, edit, delete |
| Projects | `projects.sh` | list, view, items, fields (v2) |

## How to Use

### Method 1: Direct Script Execution

Run scripts directly from the skill directory:

```bash
cd {base_directory}

# Repository operations
bash scripts/repos.sh view --owner facebook --repo react
bash scripts/repos.sh contents --owner vercel --repo next.js --path packages

# Issue operations  
bash scripts/issues.sh list --owner cli --repo cli --state open --limit 10
bash scripts/issues.sh view --owner cli --repo cli --number 123

# Pull request operations
bash scripts/prs.sh list --owner facebook --repo react --state open
bash scripts/prs.sh diff --owner cli --repo cli --number 456

# And so on for each domain...
```

### Method 2: Router Script

Use the router for unified access:

```bash
cd {base_directory}
bash scripts/router.sh repos view --owner facebook --repo react
bash scripts/router.sh issues list --owner cli --repo cli --state open
bash scripts/router.sh search repos --query "language:go stars:>10000"
```

### Command-first responses

When the user asks for commands or "exact gh commands", respond with the command(s) first (gh or scripts), then brief notes if needed. Avoid prose-only answers for command requests.
If the user asks to list pull requests or to show the exact commands, always include a literal `gh` command line in the response.
If `owner/repo` is missing, still provide the exact `gh` command with `OWNER/REPO` placeholders, then ask the user to confirm the repo.

## Script Reference

Each script follows a consistent pattern:

```bash
bash scripts/<domain>.sh <action> [options]
```

### Common Options

| Option | Description | Example |
|--------|-------------|---------|
| `--owner` | Repository owner | `--owner facebook` |
| `--repo` | Repository name | `--repo react` |
| `--number` | Issue/PR number | `--number 123` |
| `--limit` | Max results | `--limit 10` |
| `--state` | Filter by state | `--state open` |
| `--json` | JSON output | `--json` |

### Safety Rules

**Destructive operations require confirmation:**
- Creating resources (issues, PRs, releases)
- Modifying state (close, merge, delete)
- Force operations

The scripts will prompt for confirmation before executing destructive actions.

> **Detailed script reference:** For full parameters, options, and examples for all 13 domain scripts, read `references/script-domains.md`.

## Error Handling

All scripts follow these error handling rules:

1. **Max 2 attempts** per operation before failing
2. Clear error messages with suggestions
3. Exit codes: 0 = success, 1 = error, 2 = user cancelled

## Authentication

```bash
# Check auth status
gh auth status

# Login
gh auth login

# Refresh with additional scopes
gh auth refresh -s repo -s workflow -s read:org
```

## Configuration

Edit `config/toolsets.json` to enable/disable feature groups:

```json
{
  "enabled": ["repos", "issues", "prs", "actions", "users"],
  "disabled": ["projects", "gists"]
}
```

---

**MCP Parity:** This skill provides equivalent functionality to all GitHub MCP Server toolsets.
