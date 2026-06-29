#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="$SKILL_DIR/scripts"

passed=0
failed=0

pass() {
    echo "[PASS] $1"
    passed=$((passed + 1))
}

fail() {
    echo "[FAIL] $1"
    failed=$((failed + 1))
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== Security Auditor Eval Tests ==="

cat > "$TMP_DIR/secrets.json" <<'EOF'
{
  "scanner": "trivy-secrets",
  "findings": [
    {
      "severity": "CRITICAL",
      "title": "Hardcoded API token",
      "category": "hardcoded_credentials",
      "scanner": "trivy-secrets",
      "file": "src/config.ts",
      "rule_id": "secret-1"
    }
  ],
  "summary": {"critical": 1, "high": 0, "medium": 0, "low": 0}
}
EOF

cat > "$TMP_DIR/code.json" <<'EOF'
{
  "scanner": "semgrep",
  "findings": [
    {
      "severity": "HIGH",
      "title": "SQL injection risk",
      "category": "injection",
      "scanner": "semgrep",
      "file": "src/db.ts",
      "rule_id": "sqli-1",
      "line": 42,
      "description": "Unparameterized query"
    }
  ],
  "summary": {"critical": 0, "high": 1, "medium": 0, "low": 0}
}
EOF

cat > "$TMP_DIR/empty.json" <<'EOF'
{"findings": [], "summary": {"critical": 0, "high": 0, "medium": 0, "low": 0}}
EOF

REQ_OUT="$TMP_DIR/SECURITY-REQUIREMENTS.md"
bash "$SCRIPTS_DIR/extract-requirements.sh" \
  --secrets "$TMP_DIR/secrets.json" \
  --code "$TMP_DIR/code.json" \
  --deps "$TMP_DIR/empty.json" \
  --misconfig "$TMP_DIR/empty.json" \
  --github "$TMP_DIR/empty.json" \
  --output "$REQ_OUT" > /dev/null

if grep -q "^### SR-001:" "$REQ_OUT" && grep -q "Secrets Management" "$REQ_OUT"; then
    pass "extract-requirements generates first requirement with expected domain"
else
    fail "extract-requirements missing expected SR-001 domain output"
fi

if grep -q "^### SR-002:" "$REQ_OUT" && grep -q "Input Validation & Injection Safety" "$REQ_OUT"; then
    pass "extract-requirements maps injection findings to expected domain"
else
    fail "extract-requirements missing expected injection domain mapping"
fi

REPORT_OUT="$TMP_DIR/SECURITY-AUDIT.md"
cat > "$TMP_DIR/context.json" <<'EOF'
{"type":"api-service","languages":["typescript"],"frameworks":["express"]}
EOF
cat > "$TMP_DIR/monorepo.json" <<'EOF'
{"is_monorepo":false}
EOF
cat > "$TMP_DIR/scope.json" <<'EOF'
{"paths":["."]}
EOF

bash "$SCRIPTS_DIR/report.sh" \
  --context "$TMP_DIR/context.json" \
  --monorepo "$TMP_DIR/monorepo.json" \
  --scope "$TMP_DIR/scope.json" \
  --secrets "$TMP_DIR/secrets.json" \
  --deps "$TMP_DIR/empty.json" \
  --code "$TMP_DIR/code.json" \
  --misconfig "$TMP_DIR/empty.json" \
  --github "$TMP_DIR/empty.json" \
  --requirements "$REQ_OUT" \
  --output "$REPORT_OUT" > /dev/null

if grep -q "Requirements generated from CRITICAL/HIGH findings: 2" "$REPORT_OUT"; then
    pass "report includes requirement extraction count"
else
    fail "report missing requirement count integration"
fi

if grep -q "## Pre-Deployment Security Checklist" "$REPORT_OUT"; then
    pass "report includes pre-deployment checklist section"
else
    fail "report missing pre-deployment checklist section"
fi

EVAL_ROOT="$TMP_DIR/eval-root"
mkdir -p "$EVAL_ROOT"
SECURITY_AUDIT_EVAL=1 SECURITY_AUDIT_ROOT="$EVAL_ROOT" bash "$SCRIPTS_DIR/audit.sh" --changed-only > /dev/null

if [[ -f "$EVAL_ROOT/.security-audit/SECURITY-AUDIT.md" && -f "$EVAL_ROOT/.security-audit/SECURITY-REQUIREMENTS.md" ]]; then
    pass "audit eval mode generates both audit and requirements artifacts"
else
    fail "audit eval mode did not generate expected artifacts"
fi

echo "Results: $passed passed, $failed failed"
if [[ $failed -gt 0 ]]; then
    exit 1
fi
