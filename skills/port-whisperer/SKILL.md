---
name: port-whisperer
description: |
  Port and process management via port-whisperer CLI. Use when asked about port
  conflicts, orphaned dev servers, zombie processes, what's running on a port,
  killing a process on a port, cleaning up dev processes, or diagnosing
  "port already in use" errors.
  Triggers: "what's on port 3000", "kill port", "orphaned process", "zombie",
  "port conflict", "clean up dev servers", "what's running", "ports".
  DO NOT use for: network diagnostics, firewall rules, remote server management,
  or non-port-related process management.
allowed-tools: Bash(npx:*) Bash(./scripts/*) Read Glob Grep
context: fork
compatibility: "OpenCode, Codex CLI, GitHub Copilot, Kiro. Requires npx (Node.js 18+)."
---

# Port Whisperer — Dev Port & Process Management

See what's running on your ports, inspect processes, clean up orphans, and kill stubborn dev servers.

**Announce at start:** "I'm using the port-whisperer skill."

## Quick Reference

| Action | Command | Description |
|--------|---------|-------------|
| list | `./scripts/ports.sh list` | Show dev server ports (filtered) |
| list-all | `./scripts/ports.sh list-all` | Show all listening ports |
| ps | `./scripts/ports.sh ps` | Show all running dev processes |
| inspect | `./scripts/ports.sh inspect <port>` | Detailed info for a specific port |
| kill | `./scripts/ports.sh kill <port\|PID> [-f]` | Kill process on a port or by PID |
| clean | `./scripts/ports.sh clean` | Find and kill orphaned/zombie processes |
| logs | `./scripts/ports.sh logs <port> [-f]` | Tail process logs |
| help | `./scripts/ports.sh help` | Show usage help |

## Safety Rules

**Read-only commands** (`list`, `list-all`, `ps`, `inspect`, `logs`): Run freely without confirmation.

**`kill <specific-port>`**: OK to proceed if the user explicitly asked to kill that specific port or process. If the user's request is ambiguous (e.g., "clean up my ports"), confirm which ports/processes before killing.

**`clean`**: ALWAYS ask the user for confirmation before running. This is a bulk operation that kills all orphaned/zombie dev processes. Show the user what `list` or `ps` reports first, then ask before proceeding.

## How to Use

### Natural Language
- "What's running on port 3000?"
- "Show me all listening ports"
- "Kill whatever is on port 8080"
- "Clean up orphaned dev servers"
- "Show logs for port 3000"
- "What dev processes are running?"

### Workflow: Diagnose Port Conflict

1. Run `./scripts/ports.sh list` to see active dev ports
2. Run `./scripts/ports.sh inspect <port>` for details on the conflicting port
3. If the user wants to free the port, run `./scripts/ports.sh kill <port>`

### Workflow: Clean Up Orphans

1. Run `./scripts/ports.sh list` to show current state
2. Present the results to the user
3. Ask: "Would you like me to run `ports clean` to kill orphaned processes?"
4. Only run `./scripts/ports.sh clean` after explicit confirmation

## Prerequisites

- **Node.js 18+** (for npx)
- No global install required — the script uses `npx` as fallback
- If `ports` is on PATH (via `npm i -g port-whisperer` or mise), it will be used directly for speed

## Notes

- Output is stripped of ANSI color codes for readability
- Framework detection covers Next.js, Vite, Express, Django, Rails, FastAPI, and many others
- Docker containers are identified and collapsed in `ps` output
- Port ranges are supported for kill: `./scripts/ports.sh kill 3000-3010`
- Use `-f` flag with kill for SIGKILL when a process won't die gracefully
