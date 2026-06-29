#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORTS="$SCRIPT_DIR/scripts/ports.sh"
PASS=0; FAIL=0

pass() { echo "✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL + 1)); }

run_test() {
    local desc="$1"; shift
    if bash "$PORTS" "$@" > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

echo "=== Smoke Test: port-whisperer ==="

run_test "help command exits 0" help
run_test "list command exits 0" list
run_test "ps command exits 0" ps

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
