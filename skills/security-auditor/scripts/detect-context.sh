#!/usr/bin/env bash
set -euo pipefail

# Detect Project Context
# Identifies project type, languages, and deployment context

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# Initialize result
result=$(cat <<EOF
{
  "type": "unknown",
  "languages": [],
  "frameworks": [],
  "deployment_context": "unknown",
  "indicators": {}
}
EOF
)

# Detect languages based on files
detect_languages() {
    local languages=()
    
    # JavaScript/TypeScript
    if [[ -f "package.json" ]] || compgen -G "*.js" > /dev/null 2>&1 || compgen -G "*.ts" > /dev/null 2>&1; then
        if compgen -G "*.ts" > /dev/null 2>&1 || compgen -G "*.tsx" > /dev/null 2>&1 || [[ -f "tsconfig.json" ]]; then
            languages+=("typescript")
        else
            languages+=("javascript")
        fi
    fi
    
    # Python
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]] || compgen -G "*.py" > /dev/null 2>&1; then
        languages+=("python")
    fi
    
    # Go
    if [[ -f "go.mod" ]] || compgen -G "*.go" > /dev/null 2>&1; then
        languages+=("go")
    fi
    
    # Rust
    if [[ -f "Cargo.toml" ]] || compgen -G "*.rs" > /dev/null 2>&1; then
        languages+=("rust")
    fi
    
    # Java/Kotlin
    if [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]] || [[ -f "build.gradle.kts" ]]; then
        if compgen -G "*.kt" > /dev/null 2>&1; then
            languages+=("kotlin")
        else
            languages+=("java")
        fi
    fi
    
    # Ruby
    if [[ -f "Gemfile" ]] || compgen -G "*.rb" > /dev/null 2>&1; then
        languages+=("ruby")
    fi
    
    # PHP
    if [[ -f "composer.json" ]] || compgen -G "*.php" > /dev/null 2>&1; then
        languages+=("php")
    fi
    
    # Output as JSON array (safe when empty under `set -u`)
    if [[ ${#languages[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf '%s\n' "${languages[@]}" | jq -R . | jq -s .
    fi
}

# Detect frameworks from dependencies
detect_frameworks() {
    local frameworks=()
    
    # Node.js frameworks
    if [[ -f "package.json" ]]; then
        local deps=$(cat package.json | jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys[]' 2>/dev/null || true)
        
        # Frontend frameworks
        echo "$deps" | grep -qE "^react$" && frameworks+=("react")
        echo "$deps" | grep -qE "^vue$" && frameworks+=("vue")
        echo "$deps" | grep -qE "^@angular/core$" && frameworks+=("angular")
        echo "$deps" | grep -qE "^svelte$" && frameworks+=("svelte")
        echo "$deps" | grep -qE "^next$" && frameworks+=("nextjs")
        echo "$deps" | grep -qE "^nuxt$" && frameworks+=("nuxt")
        
        # Backend frameworks
        echo "$deps" | grep -qE "^express$" && frameworks+=("express")
        echo "$deps" | grep -qE "^fastify$" && frameworks+=("fastify")
        echo "$deps" | grep -qE "^koa$" && frameworks+=("koa")
        echo "$deps" | grep -qE "^hapi$" && frameworks+=("hapi")
        echo "$deps" | grep -qE "^@nestjs/core$" && frameworks+=("nestjs")
    fi
    
    # Python frameworks
    if [[ -f "requirements.txt" ]]; then
        grep -qiE "^flask" requirements.txt 2>/dev/null && frameworks+=("flask")
        grep -qiE "^django" requirements.txt 2>/dev/null && frameworks+=("django")
        grep -qiE "^fastapi" requirements.txt 2>/dev/null && frameworks+=("fastapi")
    fi
    if [[ -f "pyproject.toml" ]]; then
        grep -qiE "flask" pyproject.toml 2>/dev/null && frameworks+=("flask")
        grep -qiE "django" pyproject.toml 2>/dev/null && frameworks+=("django")
        grep -qiE "fastapi" pyproject.toml 2>/dev/null && frameworks+=("fastapi")
    fi
    
    # Go frameworks
    if [[ -f "go.mod" ]]; then
        grep -qE "gin-gonic/gin" go.mod 2>/dev/null && frameworks+=("gin")
        grep -qE "labstack/echo" go.mod 2>/dev/null && frameworks+=("echo")
        grep -qE "gofiber/fiber" go.mod 2>/dev/null && frameworks+=("fiber")
    fi
    
    # Ruby frameworks
    if [[ -f "Gemfile" ]]; then
        grep -qE "rails" Gemfile 2>/dev/null && frameworks+=("rails")
        grep -qE "sinatra" Gemfile 2>/dev/null && frameworks+=("sinatra")
    fi
    
    if [[ ${#frameworks[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf '%s\n' "${frameworks[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]"
    fi
}

# Detect project type based on indicators
detect_project_type() {
    # Check for infrastructure
    if [[ -f "terraform.tf" ]] || [[ -d "terraform" ]] || compgen -G "*.tf" > /dev/null 2>&1; then
        echo "infrastructure"
        return
    fi
    
    # Check for CLI tool indicators
    if [[ -d "cmd" ]] || [[ -d "bin" ]]; then
        if [[ -f "package.json" ]]; then
            local bin_field=$(jq -r '.bin // empty' package.json 2>/dev/null)
            if [[ -n "$bin_field" ]]; then
                echo "cli-tool"
                return
            fi
        elif [[ -f "go.mod" ]] && [[ -d "cmd" ]]; then
            echo "cli-tool"
            return
        fi
    fi
    
    # Check for library indicators
    if [[ -f "package.json" ]]; then
        local is_private=$(jq -r '.private // false' package.json 2>/dev/null)
        local has_main=$(jq -r '.main // empty' package.json 2>/dev/null)
        if [[ "$is_private" == "false" ]] && [[ -n "$has_main" ]]; then
            echo "library"
            return
        fi
    fi
    
    # Check for web app (frontend indicators)
    if [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]] || [[ -f "nuxt.config.ts" ]] || \
       [[ -f "vite.config.js" ]] || [[ -f "vite.config.ts" ]] || [[ -f "angular.json" ]]; then
        echo "web-app"
        return
    fi
    
    # Check for API service
    if [[ -f "openapi.yaml" ]] || [[ -f "openapi.json" ]] || [[ -f "swagger.yaml" ]] || \
       compgen -G "*.proto" > /dev/null 2>&1 || [[ -f "schema.graphql" ]]; then
        echo "api-service"
        return
    fi
    
    # Check for microservice (containerized)
    if [[ -f "Dockerfile" ]]; then
        if [[ -f "package.json" ]] || [[ -f "go.mod" ]] || [[ -f "requirements.txt" ]]; then
            echo "microservice"
            return
        fi
    fi
    
    # Default based on frameworks detected
    local frameworks=$(detect_frameworks)
    if echo "$frameworks" | grep -qE "express|fastify|flask|django|fastapi|gin|echo"; then
        echo "api-service"
        return
    fi
    if echo "$frameworks" | grep -qE "react|vue|angular|svelte|nextjs|nuxt"; then
        echo "web-app"
        return
    fi
    
    echo "unknown"
}

# Detect deployment context
detect_deployment_context() {
    # Check for Kubernetes
    if [[ -d "k8s" ]] || [[ -d "kubernetes" ]] || [[ -d "helm" ]] || compgen -G "*.yaml" | xargs grep -l "kind: Deployment" > /dev/null 2>&1; then
        echo "kubernetes"
        return
    fi
    
    # Check for serverless
    if [[ -f "serverless.yml" ]] || [[ -f "serverless.yaml" ]] || [[ -f "sam.yaml" ]] || [[ -f "template.yaml" ]]; then
        echo "serverless"
        return
    fi
    
    # Check for Docker
    if [[ -f "Dockerfile" ]] || [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
        echo "container"
        return
    fi
    
    # Check for cloud platforms
    if [[ -f "vercel.json" ]] || [[ -f ".vercel" ]]; then
        echo "vercel"
        return
    fi
    if [[ -f "netlify.toml" ]]; then
        echo "netlify"
        return
    fi
    
    echo "traditional"
}

# Build the result
languages=$(detect_languages)
frameworks=$(detect_frameworks)
project_type=$(detect_project_type)
deployment_context=$(detect_deployment_context)

# Collect indicators
indicators=$(cat <<EOF
{
  "has_dockerfile": $(test -f "Dockerfile" && echo "true" || echo "false"),
  "has_kubernetes": $(test -d "k8s" -o -d "kubernetes" && echo "true" || echo "false"),
  "has_terraform": $(compgen -G "*.tf" > /dev/null 2>&1 && echo "true" || echo "false"),
  "has_github_actions": $(test -d ".github/workflows" && echo "true" || echo "false"),
  "has_tests": $(test -d "test" -o -d "tests" -o -d "__tests__" && echo "true" || echo "false")
}
EOF
)

# Output final result
jq -n \
    --arg type "$project_type" \
    --argjson languages "$languages" \
    --argjson frameworks "$frameworks" \
    --arg deployment_context "$deployment_context" \
    --argjson indicators "$indicators" \
    '{
        type: $type,
        languages: $languages,
        frameworks: $frameworks,
        deployment_context: $deployment_context,
        indicators: $indicators
    }'
