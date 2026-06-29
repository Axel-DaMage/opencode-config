#!/usr/bin/env bash
set -euo pipefail

# Scan for Dependency Vulnerabilities
# Uses trivy to detect vulnerable dependencies

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
    "--scanners" "vuln"
    "--format" "json"
    "--quiet"
)

# Add severity filter
TRIVY_ARGS+=("--severity" "CRITICAL,HIGH,MEDIUM,LOW")

# Skip certain directories
TRIVY_ARGS+=(
    "--skip-dirs" ".git"
    "--skip-dirs" "dist"
    "--skip-dirs" "build"
)

# Run scan
RESULT=$(trivy "${TRIVY_ARGS[@]}" "$SCAN_PATH" 2>/dev/null || echo '{"Results": []}')

# Parse and normalize results
echo "$RESULT" | jq '{
    scanner: "trivy-deps",
    scan_path: "'"$SCAN_PATH"'",
    findings: [
        .Results[]? | 
        select(.Vulnerabilities != null) |
        .Target as $target |
        .Type as $pkg_type |
        .Vulnerabilities[] |
        {
            type: "dependency",
            severity: .Severity,
            vulnerability_id: .VulnerabilityID,
            package: .PkgName,
            installed_version: .InstalledVersion,
            fixed_version: (.FixedVersion // "not fixed"),
            title: .Title,
            description: .Description,
            file: $target,
            package_type: $pkg_type,
            cvss_score: (.CVSS.nvd.V3Score // .CVSS.ghsa.V3Score // null),
            references: (.References[:3] // []),
            exploitable: (
                if .Severity == "CRITICAL" and (.FixedVersion != null and .FixedVersion != "") then true
                elif .Severity == "HIGH" and (.CVSS.nvd.V3Score // 0) >= 8.0 then true
                else false
                end
            )
        }
    ],
    summary: {
        critical: [.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length,
        high: [.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length,
        medium: [.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length,
        low: [.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length
    }
}'
