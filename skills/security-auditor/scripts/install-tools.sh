#!/usr/bin/env bash
set -euo pipefail

# Install/Verify Security Tools
# Auto-installs trivy and semgrep if missing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Required tools
TOOLS=(
    "trivy"
    "semgrep"
)

# Optional tools (nice to have)
OPTIONAL_TOOLS=(
    "jq"
)

ACTION="${1:-check}"

check_tool() {
    local tool="$1"
    command -v "$tool" > /dev/null 2>&1
}

get_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

install_trivy() {
    local os=$(get_os)
    
    case "$os" in
        macos)
            if check_tool brew; then
                echo "Installing trivy via Homebrew..."
                brew install trivy
            else
                echo "Installing trivy via curl..."
                curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
            fi
            ;;
        linux)
            if check_tool apt-get; then
                echo "Installing trivy via apt..."
                sudo apt-get update
                sudo apt-get install -y wget apt-transport-https gnupg lsb-release
                wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
                sudo apt-get update
                sudo apt-get install -y trivy
            elif check_tool yum; then
                echo "Installing trivy via yum..."
                sudo yum install -y trivy
            else
                echo "Installing trivy via curl..."
                curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
            fi
            ;;
        *)
            echo "Unsupported OS for automatic trivy installation"
            return 1
            ;;
    esac
}

install_semgrep() {
    local os=$(get_os)
    
    # Prefer pip/pipx for semgrep as it's Python-based
    if check_tool pipx; then
        echo "Installing semgrep via pipx..."
        pipx install semgrep
    elif check_tool pip3; then
        echo "Installing semgrep via pip3..."
        pip3 install semgrep
    elif check_tool pip; then
        echo "Installing semgrep via pip..."
        pip install semgrep
    elif check_tool brew && [[ "$os" == "macos" ]]; then
        echo "Installing semgrep via Homebrew..."
        brew install semgrep
    else
        echo "Cannot install semgrep: pip/pipx/brew not found"
        return 1
    fi
}

install_jq() {
    local os=$(get_os)
    
    case "$os" in
        macos)
            if check_tool brew; then
                brew install jq
            fi
            ;;
        linux)
            if check_tool apt-get; then
                sudo apt-get update && sudo apt-get install -y jq
            elif check_tool yum; then
                sudo yum install -y jq
            fi
            ;;
    esac
}

install_tool() {
    local tool="$1"
    
    case "$tool" in
        trivy)   install_trivy ;;
        semgrep) install_semgrep ;;
        jq)      install_jq ;;
        *)
            echo "Unknown tool: $tool"
            return 1
            ;;
    esac
}

case "$ACTION" in
    --check|-c|check)
        missing=()
        for tool in "${TOOLS[@]}"; do
            if ! check_tool "$tool"; then
                missing+=("$tool")
            fi
        done
        
        if [[ ${#missing[@]} -gt 0 ]]; then
            echo "Missing required tools: ${missing[*]}"
            exit 1
        fi
        
        # Check optional tools
        for tool in "${OPTIONAL_TOOLS[@]}"; do
            if ! check_tool "$tool"; then
                echo "Warning: Optional tool '$tool' not found"
            fi
        done
        
        echo "All required tools are installed"
        exit 0
        ;;
        
    --install|-i|install)
        for tool in "${TOOLS[@]}"; do
            if ! check_tool "$tool"; then
                echo "Installing $tool..."
                install_tool "$tool"
            else
                echo "$tool is already installed"
            fi
        done
        
        # Also install optional tools
        for tool in "${OPTIONAL_TOOLS[@]}"; do
            if ! check_tool "$tool"; then
                echo "Installing optional tool $tool..."
                install_tool "$tool" || true
            fi
        done
        
        echo "Tool installation complete"
        ;;
        
    --version|-v|version)
        echo "Tool versions:"
        for tool in "${TOOLS[@]}"; do
            if check_tool "$tool"; then
                echo -n "  $tool: "
                case "$tool" in
                    trivy)   trivy --version 2>/dev/null | head -1 ;;
                    semgrep) semgrep --version 2>/dev/null ;;
                esac
            else
                echo "  $tool: not installed"
            fi
        done
        ;;
        
    *)
        echo "Usage: $(basename "$0") [--check|--install|--version]"
        exit 1
        ;;
esac
