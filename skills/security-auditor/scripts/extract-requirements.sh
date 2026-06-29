#!/usr/bin/env bash
set -euo pipefail

# Extract actionable security requirements from scan findings

SECRETS_FILE=""
DEPS_FILE=""
CODE_FILE=""
MISCONFIG_FILE=""
GITHUB_FILE=""
OUTPUT_FILE=".security-audit/SECURITY-REQUIREMENTS.md"
MAX_REQUIREMENTS=25

while [[ $# -gt 0 ]]; do
    case "$1" in
        --secrets)   SECRETS_FILE="$2"; shift 2 ;;
        --deps)      DEPS_FILE="$2"; shift 2 ;;
        --code)      CODE_FILE="$2"; shift 2 ;;
        --misconfig) MISCONFIG_FILE="$2"; shift 2 ;;
        --github)    GITHUB_FILE="$2"; shift 2 ;;
        --output)    OUTPUT_FILE="$2"; shift 2 ;;
        --max)       MAX_REQUIREMENTS="$2"; shift 2 ;;
        *)           shift ;;
    esac
done

read_json_array() {
    local file="$1"
    if [[ -n "$file" && -f "$file" && -s "$file" ]]; then
        jq -c '.findings // []' "$file" 2>/dev/null || echo '[]'
    else
        echo '[]'
    fi
}

domain_for() {
    local category
    local title
    local scanner
    category="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    title="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
    scanner="$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"

    if [[ "$category" =~ auth|authorization|access ]]; then
        echo "Authentication & Authorization"
    elif [[ "$category" =~ injection|xss|csrf|command|path|deserial ]]; then
        echo "Input Validation & Injection Safety"
    elif [[ "$category" =~ secret|credential|password|key|token ]] || [[ "$scanner" == "trivy-secrets" ]]; then
        echo "Secrets Management"
    elif [[ "$category" =~ rate_limiting|dos|availability ]] || [[ "$title" =~ rate\ limiting|denial\ of\ service ]]; then
        echo "Availability & Abuse Protection"
    elif [[ "$category" =~ misconfig|network|exposure|cors ]] || [[ "$scanner" == "trivy-config" ]]; then
        echo "Security Configuration"
    elif [[ "$scanner" == "trivy-vuln" ]] || [[ "$title" =~ dependency|package|cve ]]; then
        echo "Dependency & Supply Chain"
    else
        echo "Secure Coding Controls"
    fi
}

acceptance_criteria_for() {
    local domain="$1"
    case "$domain" in
        "Secrets Management")
            cat <<'EOF'
- [ ] No hardcoded secrets exist in source or config
- [ ] Secrets are loaded from approved secret stores/environment variables
- [ ] Logs and error messages do not expose secret material
EOF
            ;;
        "Authentication & Authorization")
            cat <<'EOF'
- [ ] Authentication is required for protected operations
- [ ] Authorization checks are enforced server-side for sensitive actions
- [ ] Privilege escalation and direct object access are prevented
EOF
            ;;
        "Input Validation & Injection Safety")
            cat <<'EOF'
- [ ] Untrusted input is validated with strict allow-list rules
- [ ] Queries and commands use safe parameterization APIs
- [ ] Error handling avoids leaking internal implementation details
EOF
            ;;
        "Availability & Abuse Protection")
            cat <<'EOF'
- [ ] Rate limiting and abuse controls are enforced on public endpoints
- [ ] Expensive operations have protective throttling and timeouts
- [ ] Alerting exists for abnormal traffic and resource spikes
EOF
            ;;
        "Security Configuration")
            cat <<'EOF'
- [ ] Security headers and deployment settings follow baseline hardening
- [ ] Public exposure of sensitive services/storage is disabled
- [ ] Least-privilege and encryption controls are enabled by default
EOF
            ;;
        "Dependency & Supply Chain")
            cat <<'EOF'
- [ ] Critical/high vulnerable dependencies are upgraded or mitigated
- [ ] Lockfiles are committed and reproducible install paths are used
- [ ] Dependency review is included in release/PR security checks
EOF
            ;;
        *)
            cat <<'EOF'
- [ ] Control is implemented in production code path
- [ ] Security test coverage verifies expected behavior
- [ ] Remediation is documented with owner and follow-up tracking
EOF
            ;;
    esac
}

test_cases_for() {
    local domain="$1"
    case "$domain" in
        "Secrets Management")
            cat <<'EOF'
- Scan repository history and current tree for hardcoded credentials
- Validate runtime secret retrieval and rotation path
EOF
            ;;
        "Authentication & Authorization")
            cat <<'EOF'
- Verify unauthenticated requests are rejected on protected routes
- Verify unauthorized role/user cannot perform privileged operations
EOF
            ;;
        "Input Validation & Injection Safety")
            cat <<'EOF'
- Execute payload-based tests for SQL/command/template injection vectors
- Verify schema validation rejects malformed and oversized input
EOF
            ;;
        "Availability & Abuse Protection")
            cat <<'EOF'
- Validate endpoint throttling under burst request patterns
- Confirm graceful degradation under load and proper alerting
EOF
            ;;
        "Security Configuration")
            cat <<'EOF'
- Validate security headers and TLS-related settings in deployed environment
- Validate storage/network ACLs and least-privilege defaults
EOF
            ;;
        "Dependency & Supply Chain")
            cat <<'EOF'
- Re-run vulnerability scans after upgrades to confirm remediation
- Validate lockfile integrity and deterministic build/install process
EOF
            ;;
        *)
            cat <<'EOF'
- Add regression test to prevent reintroduction of the issue pattern
- Validate fix in CI and production-like environment
EOF
            ;;
    esac
}

mkdir -p "$(dirname "$OUTPUT_FILE")"

combined_json="$({
    read_json_array "$SECRETS_FILE"
    read_json_array "$DEPS_FILE"
    read_json_array "$CODE_FILE"
    read_json_array "$MISCONFIG_FILE"
    read_json_array "$GITHUB_FILE"
} | jq -s 'add | map(select((.severity // "") == "CRITICAL" or (.severity // "") == "HIGH"))')"

total_findings="$(echo "$combined_json" | jq 'length')"

cat > "$OUTPUT_FILE" <<EOF
# Security Requirements

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

This document converts critical/high findings into actionable requirements with acceptance criteria and validation tests.

EOF

if [[ "$total_findings" -eq 0 ]]; then
    cat >> "$OUTPUT_FILE" <<'EOF'
## Summary

- No CRITICAL/HIGH findings were detected.
- Continue with periodic review and baseline security controls.
EOF
    echo "Requirement extraction report generated: $OUTPUT_FILE"
    exit 0
fi

echo "## Summary" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "- Source findings (CRITICAL/HIGH): $total_findings" >> "$OUTPUT_FILE"
echo "- Requirements generated: $(jq -n --argjson n "$total_findings" --argjson m "$MAX_REQUIREMENTS" '$n|if . > $m then $m else . end')" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Requirements" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

index=1
while IFS= read -r finding; do
    [[ -z "$finding" || "$finding" == "null" ]] && continue
    if [[ $index -gt $MAX_REQUIREMENTS ]]; then
        break
    fi

    severity="$(echo "$finding" | jq -r '.severity // "HIGH"')"
    title="$(echo "$finding" | jq -r '.title // .vulnerability_id // "Security Finding"')"
    category="$(echo "$finding" | jq -r '.category // .type // "other"')"
    scanner="$(echo "$finding" | jq -r '.scanner // "unknown"')"
    file_ref="$(echo "$finding" | jq -r '.file // .manifest_path // "unknown"')"
    rule_ref="$(echo "$finding" | jq -r '.rule_id // .vulnerability_id // "n/a"')"
    domain="$(domain_for "$category" "$title" "$scanner")"
    req_id="SR-$(printf '%03d' "$index")"

    cat >> "$OUTPUT_FILE" <<EOF
### $req_id: $domain - $title

- Priority: ${severity}
- Domain: $domain
- Source: $scanner / $rule_ref
- Trace: $file_ref

**Requirement**

Implement and verify controls that mitigate the identified issue pattern for this component.

**Acceptance Criteria**

EOF
    acceptance_criteria_for "$domain" >> "$OUTPUT_FILE"
    cat >> "$OUTPUT_FILE" <<'EOF'

**Security Test Cases**

EOF
    test_cases_for "$domain" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    index=$((index + 1))
done < <(echo "$combined_json" | jq -c '.[]')

cat >> "$OUTPUT_FILE" <<'EOF'
## Threat/Requirement Traceability

Use each requirement's Source/Trace fields to map back to scan findings, remediation PRs, and release approvals.
EOF

echo "Requirement extraction report generated: $OUTPUT_FILE"
