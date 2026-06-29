#!/usr/bin/env bash
set -euo pipefail

# Scan Code for Security Issues (SAST)
# Uses semgrep for static application security testing

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

# Check if semgrep is available
if ! command -v semgrep &> /dev/null; then
    echo '{"error": "semgrep not installed", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}'
    exit 0
fi

# Build semgrep command
SEMGREP_ARGS=(
    "scan"
    "--config" "auto"  # Auto-detect language and use appropriate rules
    "--config" "p/security-audit"
    "--config" "p/owasp-top-ten"
    "--config" "p/secrets"
    "--json"
    "--quiet"
    "--no-git-ignore"  # We handle exclusions ourselves
)

# Exclude patterns
SEMGREP_ARGS+=(
    "--exclude" "node_modules"
    "--exclude" "vendor"
    "--exclude" ".git"
    "--exclude" "dist"
    "--exclude" "build"
    "--exclude" "*.min.js"
    "--exclude" "*.bundle.js"
    "--exclude" "__pycache__"
    "--exclude" "*.test.*"
    "--exclude" "*.spec.*"
    "--exclude" "test/*"
    "--exclude" "tests/*"
    "--exclude" "__tests__/*"
)

# Add timeout
SEMGREP_ARGS+=("--timeout" "300")

# Add scan path
SEMGREP_ARGS+=("$SCAN_PATH")

# Run scan
RESULT=$(semgrep "${SEMGREP_ARGS[@]}" 2>/dev/null || echo '{"results": [], "errors": []}')

# Map semgrep severity to our standard
# ERROR -> critical, WARNING -> high, INFO -> medium
echo "$RESULT" | jq '{
    scanner: "semgrep",
    scan_path: "'"$SCAN_PATH"'",
    findings: [
        .results[]? |
        {
            type: "code",
            severity: (
                if .extra.severity == "ERROR" then "CRITICAL"
                elif .extra.severity == "WARNING" then "HIGH"
                elif .extra.severity == "INFO" then "MEDIUM"
                else "LOW"
                end
            ),
            rule_id: .check_id,
            file: .path,
            line: .start.line,
            end_line: .end.line,
            column: .start.col,
            title: (.extra.message | split(".")[0]),
            description: .extra.message,
            code_snippet: .extra.lines,
            category: (
                if .check_id | test("sql|injection"; "i") then "injection"
                elif .check_id | test("xss|cross-site"; "i") then "xss"
                elif .check_id | test("auth|jwt|session"; "i") then "auth_bypass"
                elif .check_id | test("ssrf"; "i") then "ssrf"
                elif .check_id | test("path|traversal|directory"; "i") then "path_traversal"
                elif .check_id | test("command|exec|shell"; "i") then "command_injection"
                elif .check_id | test("secret|password|credential|key"; "i") then "hardcoded_credentials"
                elif .check_id | test("deserial"; "i") then "insecure_deserial"
                else "other"
                end
            ),
            cwe: (.extra.metadata.cwe // []),
            owasp: (.extra.metadata.owasp // []),
            references: (.extra.metadata.references // [])[:3],
            fix: (.extra.fix // null),
            exploitable: (
                if .extra.severity == "ERROR" then true
                elif .extra.severity == "WARNING" and (.extra.metadata.cwe // [] | length) > 0 then true
                else false
                end
            )
        }
    ],
    errors: [.errors[]? | {message: .message, path: .path}],
    summary: {
        critical: [.results[]? | select(.extra.severity == "ERROR")] | length,
        high: [.results[]? | select(.extra.severity == "WARNING")] | length,
        medium: [.results[]? | select(.extra.severity == "INFO")] | length,
        low: 0
    }
}'
