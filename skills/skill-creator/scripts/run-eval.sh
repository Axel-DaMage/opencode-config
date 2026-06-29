#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: run-eval.sh --skill <path> --prompt <text> [--output-dir <dir>]

Run a single eval case against a skill, capturing output and timing.

Arguments:
  --skill <path>       Path to the skill directory (must contain SKILL.md)
  --prompt <text>      The eval prompt to execute
  --output-dir <dir>   Directory for eval output (default: /tmp/eval-run-<timestamp>)
  --help               Show this help

Output:
  <output-dir>/prompt.txt       The eval prompt
  <output-dir>/skill-path.txt   Path to the skill used
  <output-dir>/outputs/         Directory for any generated files
  <output-dir>/timing.json      Start/end times and duration
  <output-dir>/metrics.json     Execution metrics placeholder

Examples:
  ./scripts/run-eval.sh --skill skills/github-ops --prompt "List open PRs for owner/repo"
  ./scripts/run-eval.sh --skill skills/my-skill --prompt "Do the thing" --output-dir /tmp/my-eval
EOF
}

SKILL=""
PROMPT=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill)
            shift
            SKILL="${1:-}"
            ;;
        --prompt)
            shift
            PROMPT="${1:-}"
            ;;
        --output-dir)
            shift
            OUTPUT_DIR="${1:-}"
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

if [[ -z "$SKILL" ]]; then
    echo "ERROR: --skill is required" >&2
    show_help
    exit 1
fi

if [[ -z "$PROMPT" ]]; then
    echo "ERROR: --prompt is required" >&2
    show_help
    exit 1
fi

if [[ ! -f "$SKILL/SKILL.md" ]]; then
    echo "ERROR: SKILL.md not found at $SKILL/SKILL.md" >&2
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="/tmp/eval-run-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUTPUT_DIR/outputs"

echo "$PROMPT" > "$OUTPUT_DIR/prompt.txt"
echo "$SKILL" > "$OUTPUT_DIR/skill-path.txt"

START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_EPOCH="$(date +%s)"

echo "=== Eval Run ==="
echo "Skill: $SKILL"
echo "Output: $OUTPUT_DIR"
echo "Start:  $START_TIME"
echo ""
echo "Prompt: $PROMPT"
echo ""
echo "---"
echo "NOTE: This script sets up the eval workspace. The actual skill execution"
echo "should be done by the agent using Task sub-agents with the skill loaded."
echo "After execution, place output files in $OUTPUT_DIR/outputs/"
echo "---"

END_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
END_EPOCH="$(date +%s)"
DURATION=$((END_EPOCH - START_EPOCH))

# Write timing
cat > "$OUTPUT_DIR/timing.json" <<TIMING_EOF
{
  "start_time": "$START_TIME",
  "end_time": "$END_TIME",
  "total_duration_seconds": $DURATION
}
TIMING_EOF

# Write metrics placeholder
cat > "$OUTPUT_DIR/metrics.json" <<METRICS_EOF
{
  "tool_calls": 0,
  "total_steps": 0,
  "files_created": [],
  "errors_encountered": 0,
  "output_chars": 0
}
METRICS_EOF

echo ""
echo "Workspace ready: $OUTPUT_DIR"
echo "  timing.json:  written"
echo "  metrics.json: placeholder (update after execution)"
echo "  outputs/:     place output files here"
