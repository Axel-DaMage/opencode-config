#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: optimize-description.sh --skill <path> [--queries <json-file>] [--iterations <n>]

Framework for optimizing a skill's description for trigger accuracy.
Scores the current description against should-trigger and should-not-trigger
queries using keyword overlap heuristics.

Arguments:
  --skill <path>         Path to the skill directory (must contain SKILL.md)
  --queries <file>       JSON file with trigger queries (see format below)
  --generate             Generate a starter query set from the skill's description
  --iterations <n>       Max optimization iterations (default: 5)
  --help                 Show this help

Query file format:
  {
    "should_trigger": [
      "Create a new skill for Kubernetes",
      "Scaffold a reusable OpenCode skill"
    ],
    "should_not_trigger": [
      "How do I configure my editor?",
      "Fix this TypeScript bug"
    ]
  }

Output:
  Prints scoring results to stdout as JSON.
  When --generate is used, writes a starter query file to <skill>/evals/trigger-queries.json

Examples:
  ./scripts/optimize-description.sh --skill skills/github-ops --generate
  ./scripts/optimize-description.sh --skill skills/github-ops --queries queries.json
EOF
}

SKILL=""
QUERIES_FILE=""
GENERATE=false
ITERATIONS=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill)
            shift
            SKILL="${1:-}"
            ;;
        --queries)
            shift
            QUERIES_FILE="${1:-}"
            ;;
        --generate)
            GENERATE=true
            ;;
        --iterations)
            shift
            ITERATIONS="${1:-5}"
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

if [[ ! -f "$SKILL/SKILL.md" ]]; then
    echo "ERROR: SKILL.md not found at $SKILL/SKILL.md" >&2
    exit 1
fi

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is required but not installed" >&2
    exit 1
}

extract_description() {
    local skill_file="$1"
    awk '
        NR==1 && $0=="---" { in_fm=1; next }
        in_fm && $0=="---" { exit }
        in_fm && /^description:/ {
            sub(/^description:[[:space:]]*/, "")
            gsub(/^["'"'"']|["'"'"']$/, "")
            print
        }
    ' "$skill_file"
}

extract_name() {
    local skill_file="$1"
    awk '
        NR==1 && $0=="---" { in_fm=1; next }
        in_fm && $0=="---" { exit }
        in_fm && /^name:/ {
            sub(/^name:[[:space:]]*/, "")
            gsub(/^["'"'"']|["'"'"']$/, "")
            print
        }
    ' "$skill_file"
}

# Tokenize a string into lowercase words
tokenize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | sort -u | grep -v '^$' || true
}

# Score: fraction of query keywords found in description
keyword_overlap_score() {
    local description="$1"
    local query="$2"

    local desc_tokens
    desc_tokens="$(tokenize "$description")"
    local query_tokens
    query_tokens="$(tokenize "$query")"

    local total=0
    local matched=0

    while IFS= read -r token; do
        [[ -z "$token" ]] && continue
        total=$((total + 1))
        if echo "$desc_tokens" | grep -qw "$token"; then
            matched=$((matched + 1))
        fi
    done <<< "$query_tokens"

    if [[ $total -eq 0 ]]; then
        echo "0"
    else
        echo "scale=2; $matched / $total" | bc
    fi
}

DESCRIPTION="$(extract_description "$SKILL/SKILL.md")"
SKILL_NAME="$(extract_name "$SKILL/SKILL.md")"

if [[ -z "$DESCRIPTION" ]]; then
    echo "ERROR: Could not extract description from SKILL.md" >&2
    exit 1
fi

echo "=== Description Optimization ==="
echo "Skill: $SKILL_NAME"
echo "Description: ${DESCRIPTION:0:100}..."
echo ""

if [[ "$GENERATE" == "true" ]]; then
    mkdir -p "$SKILL/evals"
    cat > "$SKILL/evals/trigger-queries.json" <<QUERIES_EOF
{
  "should_trigger": [
    "Use the $SKILL_NAME skill",
    "I need help with $SKILL_NAME"
  ],
  "should_not_trigger": [
    "Fix this TypeScript compilation error",
    "How do I configure my editor settings?"
  ]
}
QUERIES_EOF
    echo "Generated starter query file: $SKILL/evals/trigger-queries.json"
    echo "Edit this file to add domain-specific queries (aim for 10+ per category)."
    echo "Then re-run with: --queries $SKILL/evals/trigger-queries.json"
    exit 0
fi

if [[ -z "$QUERIES_FILE" ]]; then
    echo "ERROR: --queries is required (or use --generate to create a starter file)" >&2
    exit 1
fi

if [[ ! -f "$QUERIES_FILE" ]]; then
    echo "ERROR: Queries file not found: $QUERIES_FILE" >&2
    exit 1
fi

SHOULD_TRIGGER="$(jq -r '.should_trigger[]' "$QUERIES_FILE")"
SHOULD_NOT_TRIGGER="$(jq -r '.should_not_trigger[]' "$QUERIES_FILE")"

TP=0; FN=0; TN=0; FP=0
THRESHOLD="0.15"

echo "--- Should-Trigger Queries ---"
while IFS= read -r query; do
    [[ -z "$query" ]] && continue
    score="$(keyword_overlap_score "$DESCRIPTION" "$query")"
    triggered=$(echo "$score > $THRESHOLD" | bc -l 2>/dev/null || echo "0")
    if [[ "$triggered" -eq 1 ]]; then
        TP=$((TP + 1))
        echo "  ✓ ($score) $query"
    else
        FN=$((FN + 1))
        echo "  ✗ ($score) $query"
    fi
done <<< "$SHOULD_TRIGGER"

echo ""
echo "--- Should-NOT-Trigger Queries ---"
while IFS= read -r query; do
    [[ -z "$query" ]] && continue
    score="$(keyword_overlap_score "$DESCRIPTION" "$query")"
    triggered=$(echo "$score > $THRESHOLD" | bc -l 2>/dev/null || echo "0")
    if [[ "$triggered" -eq 0 ]]; then
        TN=$((TN + 1))
        echo "  ✓ ($score) $query"
    else
        FP=$((FP + 1))
        echo "  ✗ ($score) $query"
    fi
done <<< "$SHOULD_NOT_TRIGGER"

TOTAL=$((TP + FN + TN + FP))
if [[ $TOTAL -gt 0 ]]; then
    ACCURACY="$(echo "scale=2; ($TP + $TN) / $TOTAL" | bc)"
else
    ACCURACY="0"
fi

TPR="0"; TNR="0"
if [[ $((TP + FN)) -gt 0 ]]; then
    TPR="$(echo "scale=2; $TP / ($TP + $FN)" | bc)"
fi
if [[ $((TN + FP)) -gt 0 ]]; then
    TNR="$(echo "scale=2; $TN / ($TN + $FP)" | bc)"
fi

echo ""
echo "=== Results ==="
jq -n \
    --arg description "${DESCRIPTION:0:200}" \
    --argjson tp "$TP" \
    --argjson fn "$FN" \
    --argjson tn "$TN" \
    --argjson fp "$FP" \
    --arg accuracy "$ACCURACY" \
    --arg true_positive_rate "$TPR" \
    --arg true_negative_rate "$TNR" \
    '{
        description: $description,
        true_positives: $tp,
        false_negatives: $fn,
        true_negatives: $tn,
        false_positives: $fp,
        accuracy: ($accuracy | tonumber),
        true_positive_rate: ($true_positive_rate | tonumber),
        true_negative_rate: ($true_negative_rate | tonumber)
    }'

echo ""
echo "Accuracy: $ACCURACY ($((TP + TN))/$TOTAL)"
echo "True Positive Rate: $TPR ($TP/$((TP + FN)) should-trigger correctly matched)"
echo "True Negative Rate: $TNR ($TN/$((TN + FP)) should-not-trigger correctly rejected)"

if [[ "$FN" -gt 0 ]]; then
    echo ""
    echo "TIP: $FN should-trigger queries missed. Consider adding their keywords to the description."
fi
if [[ "$FP" -gt 0 ]]; then
    echo ""
    echo "TIP: $FP should-not-trigger queries falsely matched. Consider making the description more specific."
fi
