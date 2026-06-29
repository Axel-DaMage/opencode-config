#!/usr/bin/env bash
set -euo pipefail

# Scan for Misconfigurations
# Uses trivy to detect IaC and configuration issues

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

# Check if there are any IaC/config files to scan
HAS_IAC=false
if compgen -G "*.tf" > /dev/null 2>&1 || \
   compgen -G "Dockerfile*" > /dev/null 2>&1 || \
   compgen -G "docker-compose*.yml" > /dev/null 2>&1 || \
   compgen -G "docker-compose*.yaml" > /dev/null 2>&1 || \
   [[ -d "kubernetes" ]] || [[ -d "k8s" ]] || [[ -d "helm" ]] || \
   [[ -d ".github/workflows" ]]; then
    HAS_IAC=true
fi

if [[ "$HAS_IAC" == "false" ]]; then
    echo '{"scanner": "trivy-misconfig", "scan_path": "'"$SCAN_PATH"'", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}, "note": "No IaC/config files detected"}'
    exit 0
fi

# Build trivy command
TRIVY_ARGS=(
    "fs"
    "--scanners" "misconfig"
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
)

# Run scan
RESULT=$(trivy "${TRIVY_ARGS[@]}" "$SCAN_PATH" 2>/dev/null || echo '{"Results": []}')

# Parse and normalize results
echo "$RESULT" | jq '{
    scanner: "trivy-misconfig",
    scan_path: "'"$SCAN_PATH"'",
    findings: [
        .Results[]? | 
        select(.Misconfigurations != null) |
        .Target as $target |
        .Type as $config_type |
        .Misconfigurations[] |
        {
            type: "misconfig",
            severity: .Severity,
            config_type: $config_type,
            file: $target,
            title: .Title,
            description: .Description,
            message: .Message,
            resolution: .Resolution,
            rule_id: .ID,
            category: (
                if .ID | test("aws|azure|gcp|cloud"; "i") then "cloud"
                elif .ID | test("docker|container"; "i") then "container"
                elif .ID | test("k8s|kubernetes|helm"; "i") then "kubernetes"
                elif .ID | test("terraform"; "i") then "terraform"
                elif .ID | test("github|actions|ci"; "i") then "ci_cd"
                else "other"
                end
            ),
            references: (.References[:3] // []),
            exploitable: (
                if .Severity == "CRITICAL" then true
                elif .Severity == "HIGH" and (.ID | test("public|exposed|unencrypted"; "i")) then true
                else false
                end
            )
        }
    ],
    summary: {
        critical: [.Results[]?.Misconfigurations[]? | select(.Severity == "CRITICAL")] | length,
        high: [.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH")] | length,
        medium: [.Results[]?.Misconfigurations[]? | select(.Severity == "MEDIUM")] | length,
        low: [.Results[]?.Misconfigurations[]? | select(.Severity == "LOW")] | length
    }
}'
