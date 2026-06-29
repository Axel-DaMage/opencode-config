#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$SKILL_DIR/SKILL.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ❌ $1"; }

echo "=== agent-browser smoke tests ==="

echo "--- Frontmatter checks ---"
[[ -f "$SKILL_FILE" ]] && pass "SKILL.md exists" || fail "SKILL.md missing"
grep -q '^name: agent-browser$' "$SKILL_FILE" && pass "name matches directory" || fail "name mismatch"
grep -q 'Do not use for' "$SKILL_FILE" && pass "negative triggers present" || fail "missing negative triggers"

echo "--- Self-containment checks ---"
if grep -qE '\.\./\.\.' "$SKILL_FILE"; then
    fail "contains ../../ path escape"
else
    pass "no path escapes in SKILL.md"
fi

echo "--- Reference checks ---"
for ref in \
    commands.md \
    snapshot-refs.md \
    auth-patterns.md \
    advanced.md \
    authentication.md \
    session-management.md \
    security.md \
    video-recording.md \
    profiling.md \
    proxy-support.md
do
    if [[ -f "$SKILL_DIR/references/$ref" ]]; then
        pass "reference exists: $ref"
    else
        fail "reference missing: $ref"
    fi
    if grep -Fq "references/$ref" "$SKILL_FILE"; then
        pass "SKILL links: $ref"
    else
        fail "SKILL missing link: $ref"
    fi
done

echo "--- Template checks ---"
for template in \
    form-automation.sh \
    authenticated-session.sh \
    capture-workflow.sh
do
    if [[ -f "$SKILL_DIR/templates/$template" ]]; then
        pass "template exists: $template"
    else
        fail "template missing: $template"
    fi
    if grep -Fq "templates/$template" "$SKILL_FILE"; then
        pass "SKILL links: $template"
    else
        fail "SKILL missing link: $template"
    fi
done

echo "--- Content checks ---"
for marker in \
    "When to Defer" \
    "Core Workflow" \
    "Handling Authentication" \
    "Ref Lifecycle" \
    "Core UI-testing References" \
    "Specialized / Non-default Workflows"
do
    grep -Fq "$marker" "$SKILL_FILE" && pass "section: $marker" || fail "missing section: $marker"
done

grep -Fq 'defer to `chrome-devtools-mcp`' "$SKILL_FILE" && pass "live Chrome boundary present" || fail "missing live Chrome boundary"
grep -Fq 'use `chrome-devtools-mcp` for DevTools performance work' "$SKILL_FILE" && pass "profiling boundary present" || fail "missing profiling boundary"
grep -Fq 'playwright-mcp' "$SKILL_FILE" && pass "playwright boundary present" || fail "missing playwright boundary"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
(( FAIL == 0 )) && exit 0 || exit 1
