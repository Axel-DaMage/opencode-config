#!/usr/bin/env bash
set -euo pipefail

# Port Whisperer wrapper — prefers `ports` on PATH, falls back to npx.

# Resolve CLI command
if command -v ports &> /dev/null; then
    PORTS_CMD=(ports)
else
    if ! command -v npx &> /dev/null; then
        echo "Error: npx not found. Install Node.js 18+ to use this skill." >&2
        exit 1
    fi
    PORTS_CMD=(npx --yes port-whisperer)
fi

# Strip ANSI escape codes for agent-friendly output
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

run() { "${PORTS_CMD[@]}" "$@" 2>&1 | strip_ansi; }

show_help() {
    cat <<EOF
Port Whisperer — Dev Port & Process Management

USAGE:
    $(basename "$0") <action> [options]

ACTIONS:
    list                    Show dev server ports (filtered)
    list-all                Show all listening ports
    ps                      Show all running dev processes
    inspect <port>          Detailed info for a specific port
    kill <port|PID> [-f]    Kill process on a port or by PID
    clean                   Find and kill orphaned/zombie processes
    logs <port> [-f]        Tail process logs
    help                    Show this help message

EXAMPLES:
    $(basename "$0") list
    $(basename "$0") inspect 3000
    $(basename "$0") kill 3000
    $(basename "$0") kill 3000-3010
    $(basename "$0") clean
    $(basename "$0") logs 3000 -f
EOF
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
    list)      run ;;
    list-all)  run --all ;;
    ps)        run ps "$@" ;;
    inspect)   run "$@" ;;
    kill)      run kill "$@" ;;
    clean)     run clean ;;
    logs)      run logs "$@" ;;
    help|--help|-h) show_help ;;
    *)
        echo "Unknown action: ${ACTION}" >&2
        show_help
        exit 1
        ;;
esac
