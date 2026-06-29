#!/usr/bin/env bash
set -euo pipefail

# Detect Monorepo Structure
# Identifies monorepo patterns and workspace configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# Initialize result
result=$(cat <<EOF
{
  "is_monorepo": false,
  "type": null,
  "root": ".",
  "packages": [],
  "workspaces": []
}
EOF
)

# Check for npm/yarn/pnpm workspaces
detect_npm_workspaces() {
    if [[ -f "package.json" ]]; then
        local workspaces=$(jq -r '.workspaces // empty' package.json 2>/dev/null)
        if [[ -n "$workspaces" && "$workspaces" != "null" ]]; then
            # Handle both array and object formats
            local workspace_patterns
            if echo "$workspaces" | jq -e 'type == "array"' > /dev/null 2>&1; then
                workspace_patterns=$(echo "$workspaces" | jq -r '.[]')
            else
                workspace_patterns=$(echo "$workspaces" | jq -r '.packages[]? // empty')
            fi
            
            if [[ -n "$workspace_patterns" ]]; then
                echo "npm-workspaces"
                return 0
            fi
        fi
    fi
    return 1
}

# Check for Turborepo
detect_turborepo() {
    if [[ -f "turbo.json" ]]; then
        echo "turborepo"
        return 0
    fi
    return 1
}

# Check for Nx
detect_nx() {
    if [[ -f "nx.json" ]]; then
        echo "nx"
        return 0
    fi
    return 1
}

# Check for Lerna
detect_lerna() {
    if [[ -f "lerna.json" ]]; then
        echo "lerna"
        return 0
    fi
    return 1
}

# Check for Go workspace
detect_go_workspace() {
    if [[ -f "go.work" ]]; then
        echo "go-workspace"
        return 0
    fi
    # Check for multiple go.mod files
    local go_mod_count=$(find . -name "go.mod" -maxdepth 3 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$go_mod_count" -gt 1 ]]; then
        echo "go-modules"
        return 0
    fi
    return 1
}

# Check for Python monorepo
detect_python_monorepo() {
    # Check for poetry with packages
    if [[ -f "pyproject.toml" ]]; then
        if grep -q "tool.poetry.packages" pyproject.toml 2>/dev/null; then
            echo "poetry-monorepo"
            return 0
        fi
    fi
    # Check for multiple pyproject.toml files
    local pyproject_count=$(find . -name "pyproject.toml" -maxdepth 3 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$pyproject_count" -gt 1 ]]; then
        echo "python-monorepo"
        return 0
    fi
    return 1
}

# Check for Cargo workspace
detect_cargo_workspace() {
    if [[ -f "Cargo.toml" ]]; then
        if grep -q "\[workspace\]" Cargo.toml 2>/dev/null; then
            echo "cargo-workspace"
            return 0
        fi
    fi
    return 1
}

# Get list of packages/workspaces
get_packages() {
    local monorepo_type="$1"
    local packages=()
    
    case "$monorepo_type" in
        npm-workspaces|turborepo|lerna)
            # Get workspace patterns from package.json
            local patterns=$(jq -r '.workspaces | if type == "array" then .[] else .packages[]? // empty end' package.json 2>/dev/null || true)
            for pattern in $patterns; do
                # Expand glob patterns
                for dir in $pattern; do
                    if [[ -d "$dir" ]] && [[ -f "$dir/package.json" ]]; then
                        packages+=("$dir")
                    fi
                done
            done
            ;;
        nx)
            # Nx projects from project.json files
            while IFS= read -r dir; do
                packages+=("$(dirname "$dir")")
            done < <(find . -name "project.json" -maxdepth 3 2>/dev/null || true)
            ;;
        go-workspace)
            # From go.work file
            while IFS= read -r line; do
                local path=$(echo "$line" | awk '{print $2}' | tr -d ')')
                if [[ -n "$path" ]]; then
                    packages+=("$path")
                fi
            done < <(grep -E "^\s*use " go.work 2>/dev/null || true)
            ;;
        go-modules)
            # Find all go.mod directories
            while IFS= read -r mod; do
                packages+=("$(dirname "$mod")")
            done < <(find . -name "go.mod" -maxdepth 3 2>/dev/null || true)
            ;;
        python-monorepo|poetry-monorepo)
            # Find all pyproject.toml directories
            while IFS= read -r proj; do
                packages+=("$(dirname "$proj")")
            done < <(find . -name "pyproject.toml" -maxdepth 3 2>/dev/null || true)
            ;;
        cargo-workspace)
            # Parse Cargo.toml workspace members
            local in_members=false
            while IFS= read -r line; do
                if echo "$line" | grep -q "^members"; then
                    in_members=true
                    continue
                fi
                if [[ "$in_members" == "true" ]]; then
                    if echo "$line" | grep -q "^\]"; then
                        break
                    fi
                    local member=$(echo "$line" | tr -d ' ",' | grep -v '^$')
                    if [[ -n "$member" ]]; then
                        # Expand glob
                        for dir in $member; do
                            if [[ -d "$dir" ]]; then
                                packages+=("$dir")
                            fi
                        done
                    fi
                fi
            done < Cargo.toml
            ;;
    esac
    
    # Output as JSON array
    printf '%s\n' "${packages[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]"
}

# Categorize packages (apps, packages, libs, etc.)
categorize_packages() {
    local packages="$1"
    
    echo "$packages" | jq -c '[.[] | {
        path: .,
        category: (
            if startswith("apps/") or startswith("applications/") or startswith("services/") then "app"
            elif startswith("packages/") or startswith("libs/") or startswith("libraries/") or startswith("shared/") then "package"
            elif startswith("tools/") or startswith("scripts/") or startswith("internal/") then "tool"
            elif startswith("infra/") or startswith("infrastructure/") or startswith("terraform/") or startswith("deploy/") then "infrastructure"
            else "other"
            end
        )
    }]'
}

# Main detection logic
main() {
    local monorepo_type=""
    
    # Try each detection method
    if monorepo_type=$(detect_turborepo); then
        : # Turborepo (superset of npm workspaces)
    elif monorepo_type=$(detect_nx); then
        : # Nx
    elif monorepo_type=$(detect_lerna); then
        : # Lerna
    elif monorepo_type=$(detect_npm_workspaces); then
        : # Plain npm workspaces
    elif monorepo_type=$(detect_cargo_workspace); then
        : # Rust Cargo workspace
    elif monorepo_type=$(detect_go_workspace); then
        : # Go workspace
    elif monorepo_type=$(detect_python_monorepo); then
        : # Python monorepo
    else
        # Not a monorepo
        echo '{"is_monorepo": false, "type": null, "root": ".", "packages": [], "workspaces": []}'
        exit 0
    fi
    
    # Get packages
    local packages=$(get_packages "$monorepo_type")
    local categorized=$(categorize_packages "$packages")
    
    # Output result
    jq -n \
        --argjson is_monorepo true \
        --arg type "$monorepo_type" \
        --arg root "$(pwd)" \
        --argjson packages "$packages" \
        --argjson workspaces "$categorized" \
        '{
            is_monorepo: $is_monorepo,
            type: $type,
            root: $root,
            packages: $packages,
            workspaces: $workspaces
        }'
}

main "$@"
