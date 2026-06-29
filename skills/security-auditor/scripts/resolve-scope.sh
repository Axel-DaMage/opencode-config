#!/usr/bin/env bash
set -euo pipefail

# Resolve Scope for Monorepo Audits
# Given a target package, resolves all dependencies that should be scanned

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    echo '{"error": "No target specified", "paths": [], "dependencies": []}'
    exit 1
fi

# Normalize target path
TARGET="${TARGET#./}"
TARGET="${TARGET%/}"

# Check if target exists
if [[ ! -d "$TARGET" ]]; then
    echo "{\"error\": \"Target path does not exist: $TARGET\", \"paths\": [], \"dependencies\": []}"
    exit 1
fi

# Detect monorepo type
MONOREPO_INFO=$("$SCRIPT_DIR/detect-monorepo.sh")
MONOREPO_TYPE=$(echo "$MONOREPO_INFO" | jq -r '.type // "unknown"')

# Initialize result
paths=("$TARGET")
dependencies=()

# Resolve dependencies based on monorepo type
resolve_npm_dependencies() {
    local target="$1"
    local target_package_json="$target/package.json"
    
    if [[ ! -f "$target_package_json" ]]; then
        return
    fi
    
    # Get all workspace packages
    local all_packages=$(echo "$MONOREPO_INFO" | jq -r '.packages[]')
    
    # Get dependencies from target package.json
    local deps=$(jq -r '(.dependencies // {}) | keys[]' "$target_package_json" 2>/dev/null || true)
    
    # For each dependency, check if it's a workspace package
    for dep in $deps; do
        for pkg_path in $all_packages; do
            if [[ -f "$pkg_path/package.json" ]]; then
                local pkg_name=$(jq -r '.name // empty' "$pkg_path/package.json" 2>/dev/null)
                if [[ "$pkg_name" == "$dep" ]]; then
                    paths+=("$pkg_path")
                    dependencies+=("$pkg_name")
                    # Recursively resolve (one level deep to avoid infinite loops)
                    local nested_deps=$(jq -r '(.dependencies // {}) | keys[]' "$pkg_path/package.json" 2>/dev/null || true)
                    for nested in $nested_deps; do
                        for nested_path in $all_packages; do
                            if [[ -f "$nested_path/package.json" ]]; then
                                local nested_name=$(jq -r '.name // empty' "$nested_path/package.json" 2>/dev/null)
                                if [[ "$nested_name" == "$nested" ]] && [[ ! " ${paths[*]} " =~ " $nested_path " ]]; then
                                    paths+=("$nested_path")
                                    dependencies+=("$nested_name")
                                fi
                            fi
                        done
                    done
                fi
            fi
        done
    done
}

resolve_go_dependencies() {
    local target="$1"
    local go_mod="$target/go.mod"
    
    if [[ ! -f "$go_mod" ]]; then
        return
    fi
    
    # Get module name
    local module_name=$(grep "^module " "$go_mod" | awk '{print $2}')
    
    # Get all workspace packages
    local all_packages=$(echo "$MONOREPO_INFO" | jq -r '.packages[]')
    
    # For each package, check if it's imported by the target
    for pkg_path in $all_packages; do
        if [[ "$pkg_path" == "$target" ]]; then
            continue
        fi
        
        if [[ -f "$pkg_path/go.mod" ]]; then
            local pkg_module=$(grep "^module " "$pkg_path/go.mod" | awk '{print $2}')
            # Check if target imports this package
            if grep -q "\"$pkg_module" "$target"/**/*.go 2>/dev/null; then
                paths+=("$pkg_path")
                dependencies+=("$pkg_module")
            fi
        fi
    done
}

resolve_python_dependencies() {
    local target="$1"
    local pyproject="$target/pyproject.toml"
    local requirements="$target/requirements.txt"
    
    # Get all workspace packages
    local all_packages=$(echo "$MONOREPO_INFO" | jq -r '.packages[]')
    
    # Check each package
    for pkg_path in $all_packages; do
        if [[ "$pkg_path" == "$target" ]]; then
            continue
        fi
        
        local pkg_name=""
        if [[ -f "$pkg_path/pyproject.toml" ]]; then
            pkg_name=$(grep -E "^name\s*=" "$pkg_path/pyproject.toml" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
        elif [[ -f "$pkg_path/setup.py" ]]; then
            pkg_name=$(grep -E "name\s*=" "$pkg_path/setup.py" 2>/dev/null | head -1 | cut -d'"' -f2 | cut -d"'" -f2 || true)
        fi
        
        if [[ -n "$pkg_name" ]]; then
            # Check if it's in dependencies
            if [[ -f "$pyproject" ]] && grep -qE "\"$pkg_name\"|'$pkg_name'" "$pyproject" 2>/dev/null; then
                paths+=("$pkg_path")
                dependencies+=("$pkg_name")
            elif [[ -f "$requirements" ]] && grep -qE "^$pkg_name" "$requirements" 2>/dev/null; then
                paths+=("$pkg_path")
                dependencies+=("$pkg_name")
            fi
        fi
    done
}

resolve_cargo_dependencies() {
    local target="$1"
    local cargo_toml="$target/Cargo.toml"
    
    if [[ ! -f "$cargo_toml" ]]; then
        return
    fi
    
    # Get all workspace packages
    local all_packages=$(echo "$MONOREPO_INFO" | jq -r '.packages[]')
    
    # Get dependencies section
    local in_deps=false
    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\[dependencies\]|\[dev-dependencies\]"; then
            in_deps=true
            continue
        fi
        if [[ "$in_deps" == "true" ]] && echo "$line" | grep -qE "^\["; then
            in_deps=false
            continue
        fi
        if [[ "$in_deps" == "true" ]]; then
            local dep_name=$(echo "$line" | cut -d'=' -f1 | tr -d ' ')
            if [[ -n "$dep_name" ]]; then
                for pkg_path in $all_packages; do
                    if [[ -f "$pkg_path/Cargo.toml" ]]; then
                        local pkg_name=$(grep "^name" "$pkg_path/Cargo.toml" 2>/dev/null | head -1 | cut -d'"' -f2 || true)
                        if [[ "$pkg_name" == "$dep_name" ]]; then
                            paths+=("$pkg_path")
                            dependencies+=("$pkg_name")
                        fi
                    fi
                done
            fi
        fi
    done < "$cargo_toml"
}

# Main resolution
case "$MONOREPO_TYPE" in
    npm-workspaces|turborepo|lerna|nx)
        resolve_npm_dependencies "$TARGET"
        ;;
    go-workspace|go-modules)
        resolve_go_dependencies "$TARGET"
        ;;
    python-monorepo|poetry-monorepo)
        resolve_python_dependencies "$TARGET"
        ;;
    cargo-workspace)
        resolve_cargo_dependencies "$TARGET"
        ;;
esac

# Remove duplicates and output
unique_paths=$(printf '%s\n' "${paths[@]}" | sort -u | jq -R . | jq -s .)
unique_deps=$(printf '%s\n' "${dependencies[@]}" | sort -u | jq -R . | jq -s . 2>/dev/null || echo "[]")

jq -n \
    --arg target "$TARGET" \
    --argjson paths "$unique_paths" \
    --argjson dependencies "$unique_deps" \
    '{
        target: $target,
        paths: $paths,
        dependencies: $dependencies,
        paths_count: ($paths | length)
    }'
