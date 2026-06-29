#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
VALIDATOR="$SKILL_DIR/scripts/validate-runtime.sh"
PASSED=0
FAILED=0
TOTAL=0

pass() {
    PASSED=$((PASSED + 1))
    TOTAL=$((TOTAL + 1))
    echo "  PASS: $1"
}

fail() {
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
    echo "  FAIL: $1"
}

echo "=== Skill Creator Smoke Tests ==="
echo ""

# Test 1: Validator help should work
echo "Test 1: Validator help"
if bash "$VALIDATOR" --help > /dev/null 2>&1; then
    pass "Help command works"
else
    fail "Help command failed"
fi

# Test 2: Current skill validates for opencode runtime
echo "Test 2: Validate skill-creator (opencode)"
if bash "$VALIDATOR" "$SKILL_DIR" --runtime opencode > /dev/null 2>&1; then
    pass "Runtime validation passed"
else
    fail "Runtime validation failed"
fi

# Test 3: Invalid runtime should fail with clear message
echo "Test 3: Invalid runtime handling"
if bash "$VALIDATOR" "$SKILL_DIR" --runtime invalid > /tmp/skill-creator-smoke.out 2>&1; then
    fail "Invalid runtime unexpectedly succeeded"
else
    if grep -q "Invalid runtime" /tmp/skill-creator-smoke.out; then
        pass "Invalid runtime rejected correctly"
    else
        fail "Invalid runtime failed but expected message not found"
    fi
fi
rm -f /tmp/skill-creator-smoke.out

# Test 4: run-eval.sh --help works
echo "Test 4: run-eval.sh help"
if bash "$SKILL_DIR/scripts/run-eval.sh" --help > /dev/null 2>&1; then
    pass "run-eval.sh help works"
else
    fail "run-eval.sh help failed"
fi

# Test 5: grade-eval.sh --help works
echo "Test 5: grade-eval.sh help"
if bash "$SKILL_DIR/scripts/grade-eval.sh" --help > /dev/null 2>&1; then
    pass "grade-eval.sh help works"
else
    fail "grade-eval.sh help failed"
fi

# Test 6: aggregate-benchmark.sh --help works
echo "Test 6: aggregate-benchmark.sh help"
if bash "$SKILL_DIR/scripts/aggregate-benchmark.sh" --help > /dev/null 2>&1; then
    pass "aggregate-benchmark.sh help works"
else
    fail "aggregate-benchmark.sh help failed"
fi

# Test 7: optimize-description.sh --help works
echo "Test 7: optimize-description.sh help"
if bash "$SKILL_DIR/scripts/optimize-description.sh" --help > /dev/null 2>&1; then
    pass "optimize-description.sh help works"
else
    fail "optimize-description.sh help failed"
fi

# Test 8: Validate skill-creator for codex runtime
echo "Test 8: Validate skill-creator (codex)"
if bash "$VALIDATOR" "$SKILL_DIR" --runtime codex > /dev/null 2>&1; then
    pass "Codex runtime validation passed"
else
    fail "Codex runtime validation failed"
fi

# Test 9: Validate skill-creator for portable runtime
echo "Test 9: Validate skill-creator (portable)"
if bash "$VALIDATOR" "$SKILL_DIR" --runtime portable > /dev/null 2>&1; then
    pass "Portable runtime validation passed"
else
    fail "Portable runtime validation failed"
fi

# Test 10: SKILL-TEMPLATE.md exists and has valid frontmatter
echo "Test 10: SKILL-TEMPLATE.md has frontmatter"
if [[ -f "$SKILL_DIR/assets/SKILL-TEMPLATE.md" ]]; then
    if head -1 "$SKILL_DIR/assets/SKILL-TEMPLATE.md" | grep -q "^---$"; then
        pass "Template exists with frontmatter"
    else
        fail "Template exists but missing frontmatter"
    fi
else
    fail "SKILL-TEMPLATE.md not found"
fi

# Test 11: references/schemas.md exists and is non-empty
echo "Test 11: references/schemas.md"
if [[ -s "$SKILL_DIR/references/schemas.md" ]]; then
    pass "Schemas reference exists and is non-empty"
else
    fail "Schemas reference missing or empty"
fi

# Test 12: Grade a mock eval (create temp fixtures, grade, verify JSON)
echo "Test 12: Mock eval grading"
MOCK_DIR="$(mktemp -d)"
mkdir -p "$MOCK_DIR/outputs"
echo "Hello World from test output" > "$MOCK_DIR/outputs/output.txt"
echo '{"start_time":"2026-01-01T00:00:00Z","end_time":"2026-01-01T00:00:05Z","total_duration_seconds":5}' > "$MOCK_DIR/timing.json"
echo '{"tool_calls":3,"total_steps":2,"files_created":["output.txt"],"errors_encountered":0,"output_chars":28}' > "$MOCK_DIR/metrics.json"

GRADE_OUTPUT="$(bash "$SKILL_DIR/scripts/grade-eval.sh" \
    --run-dir "$MOCK_DIR" \
    --expectations '["Output contains Hello World", "File output.txt was created", "Output contains MISSING_STRING"]' 2>&1 || true)"

if [[ -f "$MOCK_DIR/grading.json" ]]; then
    GRADE_PASSED="$(jq '.summary.passed' "$MOCK_DIR/grading.json")"
    GRADE_FAILED="$(jq '.summary.failed' "$MOCK_DIR/grading.json")"
    if [[ "$GRADE_PASSED" == "2" && "$GRADE_FAILED" == "1" ]]; then
        pass "Mock grading: 2 passed, 1 failed as expected"
    else
        fail "Mock grading: expected 2 passed/1 failed, got $GRADE_PASSED/$GRADE_FAILED"
    fi
else
    fail "Mock grading: grading.json not created"
fi
rm -rf "$MOCK_DIR"

# Test 13: run-eval.sh creates workspace
echo "Test 13: run-eval.sh workspace creation"
EVAL_DIR="$(mktemp -d)/eval-test"
if bash "$SKILL_DIR/scripts/run-eval.sh" --skill "$SKILL_DIR" --prompt "test prompt" --output-dir "$EVAL_DIR" > /dev/null 2>&1; then
    if [[ -f "$EVAL_DIR/prompt.txt" && -f "$EVAL_DIR/timing.json" && -d "$EVAL_DIR/outputs" ]]; then
        pass "Eval workspace created correctly"
    else
        fail "Eval workspace missing expected files"
    fi
else
    fail "run-eval.sh failed to create workspace"
fi
rm -rf "$(dirname "$EVAL_DIR")"

# Test 14: optimize-description.sh --generate creates query file
echo "Test 14: optimize-description.sh generate"
GEN_DIR="$(mktemp -d)/test-skill"
mkdir -p "$GEN_DIR"
cp "$SKILL_DIR/SKILL.md" "$GEN_DIR/SKILL.md"
if bash "$SKILL_DIR/scripts/optimize-description.sh" --skill "$GEN_DIR" --generate > /dev/null 2>&1; then
    if [[ -f "$GEN_DIR/evals/trigger-queries.json" ]]; then
        if jq -e '.should_trigger' "$GEN_DIR/evals/trigger-queries.json" > /dev/null 2>&1; then
            pass "Generated valid trigger query file"
        else
            fail "Generated file has invalid JSON structure"
        fi
    else
        fail "Trigger query file not created"
    fi
else
    fail "optimize-description.sh --generate failed"
fi
rm -rf "$(dirname "$GEN_DIR")"

echo ""
echo "=== Results: $PASSED passed, $FAILED failed (of $TOTAL) ==="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
