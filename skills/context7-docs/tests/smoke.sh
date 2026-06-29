#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Context7 Docs Skill Smoke Tests ==="
echo ""

# Test 1: Help command
echo "Test 1: Help command"
if "$SKILL_DIR/scripts/docs.sh" help > /dev/null 2>&1; then
    echo "  PASS: Help command works"
else
    echo "  FAIL: Help command failed"
    exit 1
fi

# Test 2: Search with missing argument should error gracefully
echo "Test 2: Search with missing argument"
if "$SKILL_DIR/scripts/docs.sh" search 2>&1 | grep -q "Library name required"; then
    echo "  PASS: Missing argument handled correctly"
else
    echo "  WARN: Expected error message not found"
fi

# Test 3: Docs with missing argument should error gracefully
echo "Test 3: Docs with missing argument"
if "$SKILL_DIR/scripts/docs.sh" docs 2>&1 | grep -q "Library name required"; then
    echo "  PASS: Missing argument handled correctly"
else
    echo "  WARN: Expected error message not found"
fi

# Test 4: Search for a library (may fail if Context7 not configured)
echo "Test 4: Search for library (requires Context7 MCP)"
if "$SKILL_DIR/scripts/docs.sh" search react 2>&1 | head -3; then
    echo "  PASS: Search command executed"
else
    echo "  WARN: Search returned non-zero (may be expected if Context7 not configured)"
fi

# Test 5: Force MCP timeout to verify direct REST fallback path
echo "Test 5: Fallback to direct REST API when MCP fails"
fallback_stdout="$(mktemp)"
fallback_stderr="$(mktemp)"
if MCPORTER_TIMEOUT=0.001 "$SKILL_DIR/scripts/docs.sh" docs react hooks >"$fallback_stdout" 2>"$fallback_stderr"; then
    if grep -q "MCP resolve failed, trying direct Context7 API fallback" "$fallback_stderr" \
        && grep -q "MCP docs call failed, trying direct Context7 API fallback" "$fallback_stderr" \
        && grep -q "=== Documentation for react ===" "$fallback_stdout"; then
        echo "  PASS: REST fallback triggered and returned docs"
    else
        echo "  WARN: Command succeeded but fallback markers were incomplete"
        echo "  stderr sample:"
        head -n 5 "$fallback_stderr" || true
    fi
else
    echo "  WARN: Fallback test command failed (network or API unavailable)"
fi
rm -f "$fallback_stdout" "$fallback_stderr"

echo ""
echo "=== Smoke tests completed ==="
