#!/usr/bin/env bash
set -euo pipefail

# Security Audit Report Generator
# Generates a comprehensive markdown report from scan results

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# Parse arguments
CONTEXT_FILE=""
MONOREPO_FILE=""
SCOPE_FILE=""
SECRETS_FILE=""
DEPS_FILE=""
CODE_FILE=""
MISCONFIG_FILE=""
GITHUB_FILE=""
REQUIREMENTS_FILE=""
OUTPUT_FILE=".security-audit/SECURITY-AUDIT.md"

while [[ $# -gt 0 ]]; do
    case $1 in
        --context)   CONTEXT_FILE="$2"; shift 2 ;;
        --monorepo)  MONOREPO_FILE="$2"; shift 2 ;;
        --scope)     SCOPE_FILE="$2"; shift 2 ;;
        --secrets)   SECRETS_FILE="$2"; shift 2 ;;
        --deps)      DEPS_FILE="$2"; shift 2 ;;
        --code)      CODE_FILE="$2"; shift 2 ;;
        --misconfig) MISCONFIG_FILE="$2"; shift 2 ;;
        --github)    GITHUB_FILE="$2"; shift 2 ;;
        --requirements) REQUIREMENTS_FILE="$2"; shift 2 ;;
        --output)    OUTPUT_FILE="$2"; shift 2 ;;
        *)           shift ;;
    esac
done

# Helper to safely read JSON file
read_json() {
    local file="$1"
    local default="$2"
    if [[ -f "$file" ]] && [[ -s "$file" ]]; then
        cat "$file" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Load all scan results
context=$(read_json "$CONTEXT_FILE" '{"type": "unknown"}')
monorepo=$(read_json "$MONOREPO_FILE" '{"is_monorepo": false}')
scope=$(read_json "$SCOPE_FILE" '{"paths": []}')
secrets=$(read_json "$SECRETS_FILE" '{"findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}')
deps=$(read_json "$DEPS_FILE" '{"findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}')
code=$(read_json "$CODE_FILE" '{"findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}')
misconfig=$(read_json "$MISCONFIG_FILE" '{"findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}')
github=$(read_json "$GITHUB_FILE" '{"findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}')
requirements_count=0
if [[ -n "$REQUIREMENTS_FILE" && -f "$REQUIREMENTS_FILE" ]]; then
    requirements_count=$(grep -c '^### SR-' "$REQUIREMENTS_FILE" 2>/dev/null || echo "0")
fi

# Calculate totals
total_critical=$((
    $(echo "$secrets" | jq -r '.summary.critical // 0') +
    $(echo "$deps" | jq -r '.summary.critical // 0') +
    $(echo "$code" | jq -r '.summary.critical // 0') +
    $(echo "$misconfig" | jq -r '.summary.critical // 0') +
    $(echo "$github" | jq -r '.summary.critical // 0')
))

total_high=$((
    $(echo "$secrets" | jq -r '.summary.high // 0') +
    $(echo "$deps" | jq -r '.summary.high // 0') +
    $(echo "$code" | jq -r '.summary.high // 0') +
    $(echo "$misconfig" | jq -r '.summary.high // 0') +
    $(echo "$github" | jq -r '.summary.high // 0')
))

total_medium=$((
    $(echo "$secrets" | jq -r '.summary.medium // 0') +
    $(echo "$deps" | jq -r '.summary.medium // 0') +
    $(echo "$code" | jq -r '.summary.medium // 0') +
    $(echo "$misconfig" | jq -r '.summary.medium // 0') +
    $(echo "$github" | jq -r '.summary.medium // 0')
))

total_low=$((
    $(echo "$secrets" | jq -r '.summary.low // 0') +
    $(echo "$deps" | jq -r '.summary.low // 0') +
    $(echo "$code" | jq -r '.summary.low // 0') +
    $(echo "$misconfig" | jq -r '.summary.low // 0') +
    $(echo "$github" | jq -r '.summary.low // 0')
))

# Determine status
if [[ $total_critical -gt 0 ]]; then
    STATUS="BLOCKED"
    STATUS_ICON="⛔"
    STATUS_MSG="$total_critical Critical vulnerabilities found - deployment blocked"
elif [[ $total_high -gt 0 ]]; then
    STATUS="WARNING"
    STATUS_ICON="⚠️"
    STATUS_MSG="$total_high High severity findings - review recommended"
else
    STATUS="PASSED"
    STATUS_ICON="✅"
    STATUS_MSG="No critical or high severity findings"
fi

# Extract project info
project_type=$(echo "$context" | jq -r '.type // "unknown"')
project_languages=$(echo "$context" | jq -r '.languages | join(", ") // "unknown"')
project_frameworks=$(echo "$context" | jq -r '.frameworks | join(", ") // "none"')
is_monorepo=$(echo "$monorepo" | jq -r '.is_monorepo // false')
monorepo_type=$(echo "$monorepo" | jq -r '.type // "none"')
scope_paths=$(echo "$scope" | jq -r '.paths | join(", ") // "."')

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate report
cat > "$OUTPUT_FILE" << EOF
# Security Audit Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Status:** $STATUS_ICON **$STATUS** - $STATUS_MSG

## Project Information

| Property | Value |
|----------|-------|
| **Project Type** | $project_type |
| **Languages** | $project_languages |
| **Frameworks** | $project_frameworks |
| **Monorepo** | $is_monorepo $(if [[ "$is_monorepo" == "true" ]]; then echo "($monorepo_type)"; fi) |
| **Scope** | $scope_paths |

## Executive Summary

| Severity | Count | Action Required |
|----------|-------|-----------------|
| CRITICAL | $total_critical | $(if [[ $total_critical -gt 0 ]]; then echo "**MUST FIX** - Blocks deployment"; else echo "None"; fi) |
| HIGH | $total_high | $(if [[ $total_high -gt 0 ]]; then echo "Recommended to fix"; else echo "None"; fi) |
| MEDIUM | $total_medium | $(if [[ $total_medium -gt 0 ]]; then echo "Consider fixing"; else echo "None"; fi) |
| LOW | $total_low | $(if [[ $total_low -gt 0 ]]; then echo "Informational"; else echo "None"; fi) |

### Findings by Scanner

| Scanner | Critical | High | Medium | Low |
|---------|----------|------|--------|-----|
| Secrets (Trivy) | $(echo "$secrets" | jq -r '.summary.critical // 0') | $(echo "$secrets" | jq -r '.summary.high // 0') | $(echo "$secrets" | jq -r '.summary.medium // 0') | $(echo "$secrets" | jq -r '.summary.low // 0') |
| Dependencies (Trivy) | $(echo "$deps" | jq -r '.summary.critical // 0') | $(echo "$deps" | jq -r '.summary.high // 0') | $(echo "$deps" | jq -r '.summary.medium // 0') | $(echo "$deps" | jq -r '.summary.low // 0') |
| Code SAST (Semgrep) | $(echo "$code" | jq -r '.summary.critical // 0') | $(echo "$code" | jq -r '.summary.high // 0') | $(echo "$code" | jq -r '.summary.medium // 0') | $(echo "$code" | jq -r '.summary.low // 0') |
| Misconfig (Trivy) | $(echo "$misconfig" | jq -r '.summary.critical // 0') | $(echo "$misconfig" | jq -r '.summary.high // 0') | $(echo "$misconfig" | jq -r '.summary.medium // 0') | $(echo "$misconfig" | jq -r '.summary.low // 0') |
| GitHub Security | $(echo "$github" | jq -r '.summary.critical // 0') | $(echo "$github" | jq -r '.summary.high // 0') | $(echo "$github" | jq -r '.summary.medium // 0') | $(echo "$github" | jq -r '.summary.low // 0') |

### Security Requirement Extraction

- Requirements generated from CRITICAL/HIGH findings: $requirements_count
- Requirements artifact: 
    $(if [[ -n "$REQUIREMENTS_FILE" && -f "$REQUIREMENTS_FILE" ]]; then echo "\`$REQUIREMENTS_FILE\`"; else echo "Not generated"; fi)

## Pre-Deployment Security Checklist

- [ ] No hardcoded secrets in source/config/history
- [ ] Inputs validated with allow-list schemas and safe parsing
- [ ] Queries/commands protected against injection
- [ ] Authentication and authorization checks enforced server-side
- [ ] Rate limits configured for public and expensive endpoints
- [ ] Error responses and logs do not expose sensitive internals
- [ ] Dependency vulnerabilities reviewed and critical/high remediated
- [ ] Security headers/configuration reviewed for production baseline

EOF

# Add Critical Findings section
if [[ $total_critical -gt 0 ]]; then
    cat >> "$OUTPUT_FILE" << EOF
---

## 🚨 Critical Findings (Must Fix)

These vulnerabilities **must be fixed** before deployment can proceed.

EOF

    # Secrets
    echo "$secrets" | jq -r '.findings[] | select(.severity == "CRITICAL") | "### Secret: \(.title)\n\n- **File:** `\(.file)`\n- **Line:** \(.line)\n- **Category:** \(.category)\n- **Rule:** \(.rule_id)\n\n**Remediation:** Remove the hardcoded secret and use environment variables or a secrets manager.\n"' >> "$OUTPUT_FILE" 2>/dev/null || true

    # Dependencies
    echo "$deps" | jq -r '.findings[] | select(.severity == "CRITICAL") | "### Dependency: \(.vulnerability_id // .title)\n\n- **Package:** `\(.package)` @ \(.installed_version)\n- **Fixed Version:** \(.fixed_version)\n- **File:** `\(.file)`\n- **CVSS Score:** \(.cvss_score // "N/A")\n\n**Description:** \(.description[:200] // .title)...\n\n**Remediation:** Update to version \(.fixed_version) or later.\n"' >> "$OUTPUT_FILE" 2>/dev/null || true

    # Code
    echo "$code" | jq -r '.findings[] | select(.severity == "CRITICAL") | "### Code: \(.title)\n\n- **File:** `\(.file):\(.line)`\n- **Rule:** \(.rule_id)\n- **Category:** \(.category)\n- **CWE:** \(.cwe | join(", ") // "N/A")\n\n**Description:** \(.description)\n\n```\n\(.code_snippet // "")\n```\n\n**Fix:** \(.fix // "Review and remediate the vulnerable code pattern.")\n"' >> "$OUTPUT_FILE" 2>/dev/null || true

    # Misconfig
    echo "$misconfig" | jq -r '.findings[] | select(.severity == "CRITICAL") | "### Misconfig: \(.title)\n\n- **File:** `\(.file)`\n- **Type:** \(.config_type)\n- **Rule:** \(.rule_id)\n\n**Description:** \(.description)\n\n**Resolution:** \(.resolution)\n"' >> "$OUTPUT_FILE" 2>/dev/null || true

    # GitHub
    echo "$github" | jq -r '.findings[] | select(.severity == "CRITICAL") | "### GitHub: \(.title)\n\n- **Type:** \(.type)\n- **Package:** \(.package // "N/A")\n- **File:** \(.file // .manifest_path // "N/A")\n- **URL:** \(.url)\n\n**Description:** \(.description[:200] // .title)...\n"' >> "$OUTPUT_FILE" 2>/dev/null || true
fi

# Add High Findings section
if [[ $total_high -gt 0 ]]; then
    cat >> "$OUTPUT_FILE" << EOF
---

## ⚠️ High Severity Findings

These findings are strongly recommended to fix before deployment.

EOF

    # Summarize high findings (don't list all details to keep report readable)
    echo "| Type | Finding | File | Rule |" >> "$OUTPUT_FILE"
    echo "|------|---------|------|------|" >> "$OUTPUT_FILE"
    
    echo "$secrets" | jq -r '.findings[] | select(.severity == "HIGH") | "| Secret | \(.title[:40]) | `\(.file)` | \(.rule_id) |"' >> "$OUTPUT_FILE" 2>/dev/null || true
    echo "$deps" | jq -r '.findings[] | select(.severity == "HIGH") | "| Dependency | \(.package) \(.vulnerability_id // "") | `\(.file)` | - |"' >> "$OUTPUT_FILE" 2>/dev/null || true
    echo "$code" | jq -r '.findings[] | select(.severity == "HIGH") | "| Code | \(.title[:40]) | `\(.file):\(.line)` | \(.rule_id) |"' >> "$OUTPUT_FILE" 2>/dev/null || true
    echo "$misconfig" | jq -r '.findings[] | select(.severity == "HIGH") | "| Misconfig | \(.title[:40]) | `\(.file)` | \(.rule_id) |"' >> "$OUTPUT_FILE" 2>/dev/null || true
    echo "$github" | jq -r '.findings[] | select(.severity == "HIGH") | "| GitHub | \(.title[:40]) | \(.file // .manifest_path // "-") | - |"' >> "$OUTPUT_FILE" 2>/dev/null || true
fi

# Add Medium/Low summary
if [[ $total_medium -gt 0 ]] || [[ $total_low -gt 0 ]]; then
    cat >> "$OUTPUT_FILE" << EOF

---

## 📋 Other Findings

**Medium severity:** $total_medium findings  
**Low severity:** $total_low findings

These findings are informational and can be addressed in future iterations.

<details>
<summary>Click to expand all findings</summary>

EOF

    # Medium findings
    if [[ $total_medium -gt 0 ]]; then
        echo "### Medium Severity" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "$secrets" | jq -r '.findings[] | select(.severity == "MEDIUM") | "- **Secret:** \(.title) in `\(.file)`"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "$deps" | jq -r '.findings[] | select(.severity == "MEDIUM") | "- **Dep:** \(.package) \(.vulnerability_id // "")"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "$code" | jq -r '.findings[] | select(.severity == "MEDIUM") | "- **Code:** \(.title[:60]) in `\(.file):\(.line)`"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "$misconfig" | jq -r '.findings[] | select(.severity == "MEDIUM") | "- **Config:** \(.title) in `\(.file)`"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "" >> "$OUTPUT_FILE"
    fi

    # Low findings
    if [[ $total_low -gt 0 ]]; then
        echo "### Low Severity" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        echo "$secrets" | jq -r '.findings[] | select(.severity == "LOW") | "- \(.title) in `\(.file)`"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "$deps" | jq -r '.findings[] | select(.severity == "LOW") | "- \(.package) \(.vulnerability_id // "")"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "$code" | jq -r '.findings[] | select(.severity == "LOW") | "- \(.title[:60]) in `\(.file):\(.line)`"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "$misconfig" | jq -r '.findings[] | select(.severity == "LOW") | "- \(.title) in `\(.file)`"' >> "$OUTPUT_FILE" 2>/dev/null || true
        echo "" >> "$OUTPUT_FILE"
    fi

    echo "</details>" >> "$OUTPUT_FILE"
fi

# Add footer
cat >> "$OUTPUT_FILE" << EOF

---

## Scan Details

- **Trivy Version:** $(trivy --version 2>/dev/null | head -1 || echo "N/A")
- **Semgrep Version:** $(semgrep --version 2>/dev/null || echo "N/A")
- **Scan Duration:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

### Scanners Used

1. **Trivy** - Secrets, Dependencies, Misconfigurations
2. **Semgrep** - SAST (Static Application Security Testing)
3. **GitHub Security** - Dependabot, Code Scanning, Secret Scanning

---

*Generated by the security-auditor skill*
EOF

echo "Report generated: $OUTPUT_FILE"
