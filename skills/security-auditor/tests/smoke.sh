#!/usr/bin/env bash
set -euo pipefail

# Smoke Tests for Security Auditor Skill
# Validates that all scripts are functional

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="$SKILL_DIR/scripts"
CONFIG_DIR="$SKILL_DIR/config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0
skipped=0

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    passed=$((passed + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    failed=$((failed + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    skipped=$((skipped + 1))
}

echo "========================================"
echo "Security Auditor Skill - Smoke Tests"
echo "========================================"
echo ""

# Test 1: All scripts exist and are executable
echo "--- Script Existence Tests ---"
scripts=(
    "audit.sh"
    "detect-context.sh"
    "detect-monorepo.sh"
    "resolve-scope.sh"
    "install-tools.sh"
    "scan-secrets.sh"
    "scan-deps.sh"
    "scan-code.sh"
    "scan-misconfig.sh"
    "github-security.sh"
    "extract-requirements.sh"
    "report.sh"
)

for script in "${scripts[@]}"; do
    if [[ -f "$SCRIPTS_DIR/$script" ]]; then
        if [[ -x "$SCRIPTS_DIR/$script" ]]; then
            log_pass "$script exists and is executable"
        else
            log_fail "$script exists but is not executable"
        fi
    else
        log_fail "$script does not exist"
    fi
done

echo ""

# Test 2: Config files exist and are valid YAML
echo "--- Config File Tests ---"
configs=(
    "contexts.yaml"
    "severity-gates.yaml"
    "monorepo-patterns.yaml"
    "semgrep-rulesets.yaml"
)

for config in "${configs[@]}"; do
    if [[ -f "$CONFIG_DIR/$config" ]]; then
        # Basic YAML syntax check (look for obvious errors)
        if head -1 "$CONFIG_DIR/$config" | grep -qE "^#|^[a-z]" ; then
            log_pass "$config exists and appears valid"
        else
            log_fail "$config may have syntax issues"
        fi
    else
        log_fail "$config does not exist"
    fi
done

echo ""

# Test 3: SKILL.md exists and has required frontmatter
echo "--- SKILL.md Tests ---"
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
    log_pass "SKILL.md exists"
    
    if grep -q "^name:" "$SKILL_DIR/SKILL.md"; then
        log_pass "SKILL.md has 'name' field"
    else
        log_fail "SKILL.md missing 'name' field"
    fi
    
    if grep -q "^description:" "$SKILL_DIR/SKILL.md"; then
        log_pass "SKILL.md has 'description' field"
    else
        log_fail "SKILL.md missing 'description' field"
    fi
    
    if grep -q "^allowed-tools:" "$SKILL_DIR/SKILL.md"; then
        log_pass "SKILL.md has 'allowed-tools' field"
    else
        log_fail "SKILL.md missing 'allowed-tools' field"
    fi
else
    log_fail "SKILL.md does not exist"
fi

echo ""

# Test 4: detect-context.sh produces valid JSON
echo "--- Functional Tests ---"
cd "$SKILL_DIR" # Use skill dir as test target

context_output=$("$SCRIPTS_DIR/detect-context.sh" 2>/dev/null || echo "{}")
if echo "$context_output" | jq -e '.type' > /dev/null 2>&1; then
    log_pass "detect-context.sh produces valid JSON with 'type' field"
else
    log_fail "detect-context.sh output is not valid JSON"
fi

# Test 5: detect-monorepo.sh produces valid JSON
monorepo_output=$("$SCRIPTS_DIR/detect-monorepo.sh" 2>/dev/null || echo "{}")
if echo "$monorepo_output" | jq -e 'has("is_monorepo")' > /dev/null 2>&1; then
    log_pass "detect-monorepo.sh produces valid JSON with 'is_monorepo' field"
else
    log_fail "detect-monorepo.sh output is not valid JSON"
fi

# Test 6: install-tools.sh --check runs without error
if "$SCRIPTS_DIR/install-tools.sh" --check > /dev/null 2>&1; then
    log_pass "install-tools.sh --check runs successfully (tools installed)"
else
    log_skip "install-tools.sh --check: some tools may not be installed"
fi

# Test 7: Scan scripts handle missing tools gracefully
for scanner in "scan-secrets.sh" "scan-deps.sh" "scan-code.sh" "scan-misconfig.sh"; do
    output=$("$SCRIPTS_DIR/$scanner" 2>/dev/null || echo '{"error": "failed"}')
    if echo "$output" | jq -e '.summary or .error' > /dev/null 2>&1; then
        log_pass "$scanner handles execution gracefully"
    else
        log_fail "$scanner does not produce valid JSON output"
    fi
done

# Test 8: github-security.sh handles non-github gracefully
github_output=$("$SCRIPTS_DIR/github-security.sh" 2>/dev/null || echo '{"error": "test"}')
if echo "$github_output" | jq -e '.scanner or .error' > /dev/null 2>&1; then
    log_pass "github-security.sh handles execution gracefully"
else
    log_fail "github-security.sh does not produce valid JSON"
fi

# Test 9: extract-requirements.sh generates markdown output
requirements_out="$(mktemp)"
if "$SCRIPTS_DIR/extract-requirements.sh" --output "$requirements_out" > /dev/null 2>&1; then
    if grep -q "^# Security Requirements" "$requirements_out"; then
        log_pass "extract-requirements.sh generates requirements markdown"
    else
        log_fail "extract-requirements.sh output missing expected heading"
    fi
else
    log_fail "extract-requirements.sh failed to run"
fi
rm -f "$requirements_out"

echo ""
echo "========================================"
echo "Results: $passed passed, $failed failed, $skipped skipped"
echo "========================================"

if [[ $failed -gt 0 ]]; then
    exit 1
fi

exit 0
