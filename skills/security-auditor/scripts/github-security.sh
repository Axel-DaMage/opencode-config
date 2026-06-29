#!/usr/bin/env bash
set -euo pipefail

# GitHub Security Integration
# Fetches security alerts from GitHub (Dependabot, code scanning, secret scanning)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_OPS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/github-ops"

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo '{"error": "Not a git repository", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}'
    exit 0
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo '{"error": "gh CLI not installed", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}'
    exit 0
fi

# Check if authenticated
if ! gh auth status > /dev/null 2>&1; then
    echo '{"error": "gh CLI not authenticated", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}'
    exit 0
fi

# Get repo info
REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
    echo '{"error": "No remote origin", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}'
    exit 0
fi

# Extract owner/repo from URL
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo '{"error": "Not a GitHub repository", "findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}'
    exit 0
fi

findings=()
summary_critical=0
summary_high=0
summary_medium=0
summary_low=0

# Fetch Dependabot alerts
fetch_dependabot() {
    local alerts=$(gh api "repos/$OWNER/$REPO/dependabot/alerts?state=open&per_page=100" 2>/dev/null || echo "[]")
    
    echo "$alerts" | jq -c '.[]? | {
        type: "github-dependabot",
        severity: (
            if .security_advisory.severity == "critical" then "CRITICAL"
            elif .security_advisory.severity == "high" then "HIGH"
            elif .security_advisory.severity == "medium" then "MEDIUM"
            else "LOW"
            end
        ),
        vulnerability_id: .security_advisory.cve_id,
        ghsa_id: .security_advisory.ghsa_id,
        package: .dependency.package.name,
        ecosystem: .dependency.package.ecosystem,
        manifest_path: .dependency.manifest_path,
        title: .security_advisory.summary,
        description: .security_advisory.description,
        fixed_version: (.security_vulnerability.first_patched_version.identifier // "not fixed"),
        url: .html_url,
        created_at: .created_at
    }' 2>/dev/null || true
}

# Fetch code scanning alerts
fetch_code_scanning() {
    local alerts=$(gh api "repos/$OWNER/$REPO/code-scanning/alerts?state=open&per_page=100" 2>/dev/null || echo "[]")
    
    echo "$alerts" | jq -c '.[]? | {
        type: "github-code-scanning",
        severity: (
            if .rule.security_severity_level == "critical" then "CRITICAL"
            elif .rule.security_severity_level == "high" then "HIGH"
            elif .rule.security_severity_level == "medium" then "MEDIUM"
            elif .rule.security_severity_level == "low" then "LOW"
            else "MEDIUM"
            end
        ),
        rule_id: .rule.id,
        tool: .tool.name,
        file: .most_recent_instance.location.path,
        line: .most_recent_instance.location.start_line,
        title: .rule.description,
        description: .most_recent_instance.message.text,
        url: .html_url,
        state: .state,
        created_at: .created_at
    }' 2>/dev/null || true
}

# Fetch secret scanning alerts
fetch_secret_scanning() {
    local alerts=$(gh api "repos/$OWNER/$REPO/secret-scanning/alerts?state=open&per_page=100" 2>/dev/null || echo "[]")
    
    echo "$alerts" | jq -c '.[]? | {
        type: "github-secret-scanning",
        severity: "CRITICAL",
        secret_type: .secret_type,
        secret_type_display: .secret_type_display_name,
        title: "Exposed \(.secret_type_display_name // .secret_type)",
        description: "Secret detected in repository",
        url: .html_url,
        state: .state,
        created_at: .created_at,
        locations_url: .locations_url
    }' 2>/dev/null || true
}

# Collect all findings
all_findings=$(
    {
        fetch_dependabot
        fetch_code_scanning
        fetch_secret_scanning
    } | jq -s '.'
)

# Calculate summary
summary_critical=$(echo "$all_findings" | jq '[.[] | select(.severity == "CRITICAL")] | length')
summary_high=$(echo "$all_findings" | jq '[.[] | select(.severity == "HIGH")] | length')
summary_medium=$(echo "$all_findings" | jq '[.[] | select(.severity == "MEDIUM")] | length')
summary_low=$(echo "$all_findings" | jq '[.[] | select(.severity == "LOW")] | length')

# Output result
jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --argjson findings "$all_findings" \
    --argjson critical "$summary_critical" \
    --argjson high "$summary_high" \
    --argjson medium "$summary_medium" \
    --argjson low "$summary_low" \
    '{
        scanner: "github-security",
        repository: "\($owner)/\($repo)",
        findings: $findings,
        summary: {
            critical: $critical,
            high: $high,
            medium: $medium,
            low: $low
        }
    }'
