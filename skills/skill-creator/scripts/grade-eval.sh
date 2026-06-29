#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: grade-eval.sh --run-dir <path> --expectations <json-array>

Grade eval output against expectations. Checks for string matches, file
existence, and regex patterns.

Arguments:
  --run-dir <path>           Directory from run-eval.sh (must contain outputs/)
  --expectations <json>      JSON array of expectation strings
  --help                     Show this help

Expectation format:
  Each expectation is a verifiable statement. The grader checks:
  1. String presence in output files
  2. File existence (if expectation mentions "file X was created")
  3. Regex patterns (if expectation starts with "regex:")

Output:
  <run-dir>/grading.json     Grading results with pass/fail per expectation

Examples:
  ./scripts/grade-eval.sh \
    --run-dir /tmp/eval-run-1 \
    --expectations '["Output contains hello", "File output.md was created"]'
EOF
}

RUN_DIR=""
EXPECTATIONS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-dir)
            shift
            RUN_DIR="${1:-}"
            ;;
        --expectations)
            shift
            EXPECTATIONS="${1:-}"
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            show_help
            exit 1
            ;;
    esac
    shift
done

if [[ -z "$RUN_DIR" ]]; then
    echo "ERROR: --run-dir is required" >&2
    show_help
    exit 1
fi

if [[ -z "$EXPECTATIONS" ]]; then
    echo "ERROR: --expectations is required" >&2
    show_help
    exit 1
fi

if [[ ! -d "$RUN_DIR" ]]; then
    echo "ERROR: Run directory not found: $RUN_DIR" >&2
    exit 1
fi

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required but not installed" >&2
    exit 1
}

# Validate expectations JSON
if ! echo "$EXPECTATIONS" | jq -e 'type == "array"' > /dev/null 2>&1; then
    echo "ERROR: --expectations must be a valid JSON array" >&2
    exit 1
fi

ALL_OUTPUT=""
if [[ -d "$RUN_DIR/outputs" ]]; then
    ALL_OUTPUT="$(find "$RUN_DIR/outputs" -type f -exec cat {} + 2>/dev/null || true)"
fi

TOTAL="$(echo "$EXPECTATIONS" | jq 'length')"
PASSED=0
FAILED=0
RESULTS="[]"

for i in $(seq 0 $((TOTAL - 1))); do
    EXPECTATION="$(echo "$EXPECTATIONS" | jq -r ".[$i]")"
    EVIDENCE=""
    STATUS="false"

    if [[ "$EXPECTATION" == regex:* ]]; then
        PATTERN="${EXPECTATION#regex:}"
        if echo "$ALL_OUTPUT" | grep -qE "$PATTERN" 2>/dev/null; then
            STATUS="true"
            MATCH="$(echo "$ALL_OUTPUT" | grep -oE "$PATTERN" | head -1)"
            EVIDENCE="Regex match found: $MATCH"
        else
            EVIDENCE="Regex pattern not found in output: $PATTERN"
        fi
    elif echo "$EXPECTATION" | grep -qiE '(file|created|exists).*\b\S+\.\S+\b'; then
        FILENAME="$(echo "$EXPECTATION" | grep -oE '\b[a-zA-Z0-9_.-]+\.[a-zA-Z0-9]+\b' | head -1 || true)"
        if [[ -n "$FILENAME" ]] && find "$RUN_DIR/outputs" -name "$FILENAME" -type f 2>/dev/null | grep -q .; then
            STATUS="true"
            EVIDENCE="File found: $(find "$RUN_DIR/outputs" -name "$FILENAME" -type f | head -1)"
        elif [[ -n "$FILENAME" ]]; then
            EVIDENCE="File not found in outputs: $FILENAME"
        else
            EVIDENCE="Could not extract filename from expectation"
        fi
    else
        SEARCH_TERMS="$(echo "$EXPECTATION" | sed -E 's/(output |contains |includes |has |shows )//gi' | tr -d '"'"'")"
        if echo "$ALL_OUTPUT" | grep -qi "$SEARCH_TERMS" 2>/dev/null; then
            STATUS="true"
            MATCH_LINE="$(echo "$ALL_OUTPUT" | grep -i "$SEARCH_TERMS" | head -1 | cut -c1-200)"
            EVIDENCE="Found in output: $MATCH_LINE"
        else
            EVIDENCE="String not found in output files"
        fi
    fi

    if [[ "$STATUS" == "true" ]]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    RESULT="$(jq -n \
        --arg text "$EXPECTATION" \
        --argjson passed "$STATUS" \
        --arg evidence "$EVIDENCE" \
        '{text: $text, passed: $passed, evidence: $evidence}')"

    RESULTS="$(echo "$RESULTS" | jq --argjson r "$RESULT" '. + [$r]')"
done

if [[ "$TOTAL" -gt 0 ]]; then
    PASS_RATE="$(echo "scale=2; $PASSED / $TOTAL" | bc)"
else
    PASS_RATE="0"
fi

TIMING_DURATION="0"
if [[ -f "$RUN_DIR/timing.json" ]]; then
    TIMING_DURATION="$(jq -r '.total_duration_seconds // 0' "$RUN_DIR/timing.json")"
fi

TOOL_CALLS="0"
TOTAL_STEPS="0"
ERRORS="0"
OUTPUT_CHARS="${#ALL_OUTPUT}"
if [[ -f "$RUN_DIR/metrics.json" ]]; then
    TOOL_CALLS="$(jq -r '.tool_calls // 0' "$RUN_DIR/metrics.json")"
    TOTAL_STEPS="$(jq -r '.total_steps // 0' "$RUN_DIR/metrics.json")"
    ERRORS="$(jq -r '.errors_encountered // 0' "$RUN_DIR/metrics.json")"
fi

jq -n \
    --argjson expectations "$RESULTS" \
    --argjson passed "$PASSED" \
    --argjson failed "$FAILED" \
    --argjson total "$TOTAL" \
    --arg pass_rate "$PASS_RATE" \
    --argjson tool_calls "$TOOL_CALLS" \
    --argjson total_steps "$TOTAL_STEPS" \
    --argjson errors "$ERRORS" \
    --argjson output_chars "$OUTPUT_CHARS" \
    --argjson duration "$TIMING_DURATION" \
    '{
        expectations: $expectations,
        summary: {
            passed: $passed,
            failed: $failed,
            total: $total,
            pass_rate: ($pass_rate | tonumber)
        },
        execution_metrics: {
            tool_calls: $tool_calls,
            total_steps: $total_steps,
            errors_encountered: $errors,
            output_chars: $output_chars
        },
        timing: {
            total_duration_seconds: $duration
        }
    }' > "$RUN_DIR/grading.json"

echo "=== Grading Complete ==="
echo "Passed: $PASSED / $TOTAL ($(echo "scale=0; $PASS_RATE * 100" | bc)%)"
echo "Output: $RUN_DIR/grading.json"

if [[ "$FAILED" -gt 0 ]]; then
    echo ""
    echo "Failed expectations:"
    echo "$RESULTS" | jq -r '.[] | select(.passed == false) | "  ✗ \(.text)\n    → \(.evidence)"'
fi
