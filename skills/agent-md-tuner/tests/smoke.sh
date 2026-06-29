#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$SKILL_DIR/SKILL.md"
PASS=0
FAIL=0

pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); echo "  ❌ $1"; }

echo "=== agent-md-tuner smoke tests ==="

# 1. SKILL.md exists
echo "--- Frontmatter checks ---"
[[ -f "$SKILL_FILE" ]] && pass "SKILL.md exists" || fail "SKILL.md missing"

# 2. Required frontmatter fields
for field in name description allowed-tools context compatibility; do
  grep -q "^${field}:" "$SKILL_FILE" && pass "frontmatter: $field" || fail "frontmatter: $field missing"
done

# 3. Name matches directory
dir_name="$(basename "$SKILL_DIR")"
grep -q "^name: ${dir_name}$" "$SKILL_FILE" && pass "name matches directory" || fail "name '$dir_name' not in frontmatter"

# 4. Description has negative triggers
grep -q "DO NOT use for:" "$SKILL_FILE" && pass "negative triggers present" || fail "missing 'DO NOT use for:' in description"

# 5. No external file references
echo "--- Self-containment checks ---"
if grep -qE '\.\./\.\.' "$SKILL_FILE"; then
  fail "contains ../../ path escape"
else
  pass "no path escapes"
fi

# 6. Line count under 500
lines=$(wc -l < "$SKILL_FILE" | tr -d ' ')
(( lines <= 500 )) && pass "SKILL.md is $lines lines (≤500)" || fail "SKILL.md is $lines lines (>500)"

# 7. Key sections present
echo "--- Content checks ---"
for section in "Phase 1:" "Phase 2:" "Phase 3:" "Phase 4:" "Phase 5:" "Karpathy Principles" "Create mode" "Enhance mode" "Restructure mode"; do
  grep -q "$section" "$SKILL_FILE" && pass "section: $section" || fail "missing section: $section"
done

# 8. Checklist categories present
for cat in "Behavioral Constraints" "Project Context" "Progressive Disclosure" "Anti-Patterns"; do
  grep -q "$cat" "$SKILL_FILE" && pass "checklist: $cat" || fail "missing checklist: $cat"
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
(( FAIL == 0 )) && exit 0 || exit 1
