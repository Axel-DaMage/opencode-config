#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: aggregate-benchmark.sh --results-dir <path> --skill-name <name>

Aggregate multiple eval grading results into benchmark statistics.
Reads grading.json files from subdirectories grouped by configuration
(with_skill / without_skill).

Arguments:
  --results-dir <path>   Directory containing run subdirectories
  --skill-name <name>    Name of the skill being benchmarked
  --help                 Show this help

Expected directory structure:
  <results-dir>/
    with_skill/
      run-1/grading.json
      run-2/grading.json
    without_skill/
      run-1/grading.json
      run-2/grading.json

Output:
  <results-dir>/benchmark.json   Aggregated statistics
  <results-dir>/benchmark.md     Human-readable report

Examples:
  ./scripts/aggregate-benchmark.sh \
    --results-dir /tmp/benchmark-results \
    --skill-name github-ops
EOF
}

RESULTS_DIR=""
SKILL_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --results-dir)
            shift
            RESULTS_DIR="${1:-}"
            ;;
        --skill-name)
            shift
            SKILL_NAME="${1:-}"
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

if [[ -z "$RESULTS_DIR" ]]; then
    echo "ERROR: --results-dir is required" >&2
    show_help
    exit 1
fi

if [[ -z "$SKILL_NAME" ]]; then
    echo "ERROR: --skill-name is required" >&2
    show_help
    exit 1
fi

if [[ ! -d "$RESULTS_DIR" ]]; then
    echo "ERROR: Results directory not found: $RESULTS_DIR" >&2
    exit 1
fi

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required but not installed" >&2
    exit 1
}

compute_stats() {
    local config_dir="$1"
    local config_name="$2"

    local pass_rates=()
    local times=()
    local run_count=0

    if [[ ! -d "$config_dir" ]]; then
        echo '{"pass_rate":{"mean":0,"stddev":0,"min":0,"max":0},"time_seconds":{"mean":0,"stddev":0,"min":0,"max":0},"count":0}'
        return
    fi

    while IFS= read -r grading_file; do
        local pr
        pr="$(jq -r '.summary.pass_rate // 0' "$grading_file")"
        pass_rates+=("$pr")

        local ts="0"
        if [[ -f "$(dirname "$grading_file")/timing.json" ]]; then
            ts="$(jq -r '.total_duration_seconds // 0' "$(dirname "$grading_file")/timing.json")"
        fi
        times+=("$ts")
        run_count=$((run_count + 1))
    done < <(find "$config_dir" -name "grading.json" -type f 2>/dev/null | sort)

    if [[ $run_count -eq 0 ]]; then
        echo '{"pass_rate":{"mean":0,"stddev":0,"min":0,"max":0},"time_seconds":{"mean":0,"stddev":0,"min":0,"max":0},"count":0}'
        return
    fi

    local pr_list
    pr_list="$(printf '%s\n' "${pass_rates[@]}" | jq -s '.')"
    local t_list
    t_list="$(printf '%s\n' "${times[@]}" | jq -s '.')"

    jq -n \
        --argjson pr "$pr_list" \
        --argjson ts "$t_list" \
        --argjson count "$run_count" \
        '{
            pass_rate: {
                mean: ($pr | add / length),
                stddev: (if ($pr | length) > 1 then ($pr | (add / length) as $m | map(. - $m | . * .) | add / (length - 1) | sqrt) else 0 end),
                min: ($pr | min),
                max: ($pr | max)
            },
            time_seconds: {
                mean: ($ts | add / length),
                stddev: (if ($ts | length) > 1 then ($ts | (add / length) as $m | map(. - $m | . * .) | add / (length - 1) | sqrt) else 0 end),
                min: ($ts | min),
                max: ($ts | max)
            },
            count: $count
        }'
}

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "=== Aggregating Benchmark ==="
echo "Skill: $SKILL_NAME"
echo "Results: $RESULTS_DIR"

WITH_STATS="$(compute_stats "$RESULTS_DIR/with_skill" "with_skill")"
WITHOUT_STATS="$(compute_stats "$RESULTS_DIR/without_skill" "without_skill")"

WITH_COUNT="$(echo "$WITH_STATS" | jq '.count')"
WITHOUT_COUNT="$(echo "$WITHOUT_STATS" | jq '.count')"

WITH_PR_MEAN="$(echo "$WITH_STATS" | jq '.pass_rate.mean')"
WITHOUT_PR_MEAN="$(echo "$WITHOUT_STATS" | jq '.pass_rate.mean')"
DELTA_PR="$(echo "$WITH_PR_MEAN - $WITHOUT_PR_MEAN" | bc -l 2>/dev/null || echo "0")"

WITH_T_MEAN="$(echo "$WITH_STATS" | jq '.time_seconds.mean')"
WITHOUT_T_MEAN="$(echo "$WITHOUT_STATS" | jq '.time_seconds.mean')"
DELTA_T="$(echo "$WITH_T_MEAN - $WITHOUT_T_MEAN" | bc -l 2>/dev/null || echo "0")"

# Collect individual runs
RUNS="[]"
for config in with_skill without_skill; do
    config_dir="$RESULTS_DIR/$config"
    [[ -d "$config_dir" ]] || continue
    run_num=0
    while IFS= read -r grading_file; do
        run_num=$((run_num + 1))
        run_dir="$(dirname "$grading_file")"
        eval_id="$(basename "$run_dir" | grep -oE '[0-9]+' | head -1 || echo "$run_num")"

        RUN="$(jq -n \
            --argjson eval_id "$eval_id" \
            --arg config "$config" \
            --argjson run_number "$run_num" \
            --argjson result "$(jq '{pass_rate: .summary.pass_rate, passed: .summary.passed, failed: .summary.failed, total: .summary.total}' "$grading_file")" \
            '{eval_id: $eval_id, configuration: $config, run_number: $run_number, result: $result}')"

        if [[ -f "$run_dir/timing.json" ]]; then
            TS="$(jq '.total_duration_seconds // 0' "$run_dir/timing.json")"
            RUN="$(echo "$RUN" | jq --argjson ts "$TS" '.result.time_seconds = $ts')"
        fi

        RUNS="$(echo "$RUNS" | jq --argjson r "$RUN" '. + [$r]')"
    done < <(find "$config_dir" -name "grading.json" -type f 2>/dev/null | sort)
done

DELTA_PR_FMT="$(printf "%+.2f" "$DELTA_PR" 2>/dev/null || echo "+$DELTA_PR")"
DELTA_T_FMT="$(printf "%+.1f" "$DELTA_T" 2>/dev/null || echo "+$DELTA_T")"

jq -n \
    --arg skill_name "$SKILL_NAME" \
    --arg skill_path "$RESULTS_DIR" \
    --arg timestamp "$TIMESTAMP" \
    --argjson runs "$RUNS" \
    --argjson with_skill "$(echo "$WITH_STATS" | jq 'del(.count)')" \
    --argjson without_skill "$(echo "$WITHOUT_STATS" | jq 'del(.count)')" \
    --arg delta_pr "$DELTA_PR_FMT" \
    --arg delta_t "$DELTA_T_FMT" \
    '{
        metadata: {
            skill_name: $skill_name,
            skill_path: $skill_path,
            timestamp: $timestamp,
            runs_per_configuration: ([$runs[] | select(.configuration == "with_skill")] | length)
        },
        runs: $runs,
        run_summary: {
            with_skill: $with_skill,
            without_skill: $without_skill,
            delta: {
                pass_rate: $delta_pr,
                time_seconds: $delta_t
            }
        }
    }' > "$RESULTS_DIR/benchmark.json"

# Generate markdown report
cat > "$RESULTS_DIR/benchmark.md" <<MD_EOF
# Benchmark: $SKILL_NAME

**Date:** $TIMESTAMP
**With-skill runs:** $WITH_COUNT | **Without-skill runs:** $WITHOUT_COUNT

## Pass Rate

| Configuration | Mean | StdDev | Min | Max |
|---------------|------|--------|-----|-----|
| with_skill | $(echo "$WITH_STATS" | jq -r '.pass_rate | "\(.mean | . * 100 | round / 100) | \(.stddev | . * 100 | round / 100) | \(.min | . * 100 | round / 100) | \(.max | . * 100 | round / 100)"') |
| without_skill | $(echo "$WITHOUT_STATS" | jq -r '.pass_rate | "\(.mean | . * 100 | round / 100) | \(.stddev | . * 100 | round / 100) | \(.min | . * 100 | round / 100) | \(.max | . * 100 | round / 100)"') |
| **delta** | $DELTA_PR_FMT | | | |

## Time (seconds)

| Configuration | Mean | StdDev | Min | Max |
|---------------|------|--------|-----|-----|
| with_skill | $(echo "$WITH_STATS" | jq -r '.time_seconds | "\(.mean | . * 10 | round / 10) | \(.stddev | . * 10 | round / 10) | \(.min | . * 10 | round / 10) | \(.max | . * 10 | round / 10)"') |
| without_skill | $(echo "$WITHOUT_STATS" | jq -r '.time_seconds | "\(.mean | . * 10 | round / 10) | \(.stddev | . * 10 | round / 10) | \(.min | . * 10 | round / 10) | \(.max | . * 10 | round / 10)"') |
| **delta** | $DELTA_T_FMT | | | |
MD_EOF

echo ""
echo "With-skill:    $WITH_COUNT runs, pass_rate mean=$(echo "$WITH_STATS" | jq '.pass_rate.mean')"
echo "Without-skill: $WITHOUT_COUNT runs, pass_rate mean=$(echo "$WITHOUT_STATS" | jq '.pass_rate.mean')"
echo "Delta:         pass_rate $DELTA_PR_FMT, time ${DELTA_T_FMT}s"
echo ""
echo "Output: $RESULTS_DIR/benchmark.json"
echo "Report: $RESULTS_DIR/benchmark.md"
