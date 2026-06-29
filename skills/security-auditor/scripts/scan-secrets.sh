#!/usr/bin/env bash
set -euo pipefail

# Scan for Secrets
# Uses trivy to detect hardcoded secrets and credentials

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# Parse arguments
SCOPE=""
CHANGED_ONLY=false
SCAN_PATH="."

while [[ $# -gt 0 ]]; do
    case $1 in
        --scope)
            SCOPE="$2"
            SCAN_PATH="$2"
            shift 2
            ;;
        --changed-only)
            CHANGED_ONLY=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check if trivy is available
if ! command -v trivy &> /dev/null; then
    echo '{"error": "trivy not installed", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}'
    exit 0
fi

# Build trivy command
TRIVY_ARGS=(
    "fs"
    "--scanners" "secret"
    "--format" "json"
    "--quiet"
)

# Add severity filter
TRIVY_ARGS+=("--severity" "CRITICAL,HIGH,MEDIUM,LOW")

# Skip certain directories
TRIVY_ARGS+=(
    "--skip-dirs" "node_modules"
    "--skip-dirs" "vendor"
    "--skip-dirs" ".git"
    "--skip-dirs" "dist"
    "--skip-dirs" "build"
    "--skip-dirs" ".next"
    "--skip-dirs" "__pycache__"
)

# Run scan
RESULT=$(trivy "${TRIVY_ARGS[@]}" "$SCAN_PATH" 2>/dev/null || echo '{"Results": []}')

# Parse and normalize results
echo "$RESULT" | jq '{
    scanner: "trivy-secrets",
    scan_path: "'"$SCAN_PATH"'",
    findings: [
        .Results[]? | 
        select(.Secrets != null) |
        .Target as $target |
        .Secrets[] |
        {
            type: "secret",
            severity: .Severity,
            title: .Title,
            category: .Category,
            file: $target,
            line: .StartLine,
            end_line: .EndLine,
            match: .Match,
            rule_id: .RuleID,
            description: "Hardcoded \(.Category) detected"
        }
    ],
    summary: {
        critical: [.Results[]?.Secrets[]? | select(.Severity == "CRITICAL")] | length,
        high: [.Results[]?.Secrets[]? | select(.Severity == "HIGH")] | length,
        medium: [.Results[]?.Secrets[]? | select(.Severity == "MEDIUM")] | length,
        low: [.Results[]?.Secrets[]? | select(.Severity == "LOW")] | length
    }
}'
