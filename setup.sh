#!/bin/bash

# ============================================================
# ClaudeFree v1.4.0
# Claude Code + OpenCode AI Auto Setup
# ============================================================

set -euo pipefail
export LC_ALL=C

# -----------------------------
# Colors
# -----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

pause_exit() {
    echo ""
    read -rp "Press Enter to exit..." </dev/tty 2>/dev/null || true
    exit 1
}

# Non-interactive mode detection
NON_INTERACTIVE=false
if [[ "$*" == *"--non-interactive"* ]] || [[ "${CI:-}" == "1" ]]; then
    NON_INTERACTIVE=true
fi

# -----------------------------
# Checks
# -----------------------------
check_network() {
    log "Checking internet connection..."
    if ! curl -s --connect-timeout 10 --max-time 20 https://opencode.ai >/dev/null; then
        error "No internet connection or opencode.ai unreachable."
        pause_exit
    fi
    success "Internet connection OK"
}

check_storage() {
    log "Checking available storage..."
    AVAILABLE_KB=$(df . | awk 'NR==2 {print $4}')
    if [[ -n "${AVAILABLE_KB:-}" ]] && (( AVAILABLE_KB < 500000 )); then
        error "At least 500MB free space required."
        pause_exit
    fi
    success "Sufficient storage available"
}

# -----------------------------
# Detect OS
# -----------------------------
detect_os() {
    OS="$(uname -s)"
    case "$OS" in
        Linux*)  PLATFORM="linux" ;;
        Darwin*) PLATFORM="macos" ;;
        *) error "Unsupported OS: $OS"; pause_exit ;;
    esac
    success "Detected OS: $PLATFORM"
}

# -----------------------------
# VS Code Install (macOS fixed)
# -----------------------------
is_vscode_installed() { command -v code >/dev/null 2>&1; }

is_vscode_app_present() {
    [[ -d "/Applications/Visual Studio Code.app" ]]
}

fix_macos_code_cli() {
    local cli_path="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    if [[ ! -f "$cli_path" ]]; then
        error "VS Code app found but CLI binary missing at $cli_path"
        return 1
    fi
    local target=""
    for dir in /usr/local/bin "$HOME/.local/bin"; do
        if [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null; then
            target="$dir/code"
            break
        fi
    done
    if [[ -z "$target" ]]; then
        error "No writable directory in PATH to create 'code' symlink"
        return 1
    fi
    sudo ln -sf "$cli_path" "$target" 2>/dev/null || ln -sf "$cli_path" "$target"
    if [[ -x "$target" ]]; then
        success "Created 'code' symlink at $target"
        local dir=$(dirname "$target")
        if [[ ":$PATH:" != *":$dir:"* ]]; then
            export PATH="$dir:$PATH"
            success "Added $dir to PATH for this session"
        fi
        hash -r || true
        return 0
    else
        error "Failed to create 'code' symlink"
        return 1
    fi
}

install_vscode_linux() {
    log "Installing VS Code on Linux..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y wget gpg apt-transport-https curl
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/packages.microsoft.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        sudo apt update
        sudo apt install -y code
    elif command -v dnf >/dev/null 2>&1; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        cat <<EOF | sudo tee /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
        sudo dnf check-update || true
        sudo dnf install -y code
    else
        error "Unsupported Linux package manager."
        pause_exit
    fi
}

install_vscode_macos() {
    log "Installing VS Code on macOS..."

    _code_binary_exists() {
        [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]
    }

    _force_uninstall_vscode() {
        log "Removing broken VS Code installation..."
        brew uninstall --cask visual-studio-code --force 2>/dev/null || true
        sudo rm -rf "/Applications/Visual Studio Code.app" 2>/dev/null || rm -rf "/Applications/Visual Studio Code.app"
        rm -rf "$HOME/Library/Application Support/Code" 2>/dev/null || true
        success "VS Code completely removed"
    }

    if ! [[ -d "/Applications/Visual Studio Code.app" ]]; then
        if brew list --cask 2>/dev/null | grep -q "^visual-studio-code$"; then
            warn "VS Code cask registered but app is missing - cleaning up stale metadata..."
            _force_uninstall_vscode
        fi
    fi

    if [[ -d "/Applications/Visual Studio Code.app" ]] && ! _code_binary_exists; then
        warn "VS Code app found but CLI binary is missing - installation is corrupted."
        _force_uninstall_vscode
    fi

    if command -v code >/dev/null 2>&1; then
        success "VS Code already installed and CLI available"
        return
    fi

    if ! command -v brew >/dev/null 2>&1; then
        error "Homebrew not installed. Install from https://brew.sh"
        pause_exit
    fi

    log "Installing VS Code via Homebrew..."
    brew install --cask visual-studio-code

    if ! _code_binary_exists; then
        error "VS Code installed but CLI binary still missing - something is wrong with the cask."
        echo "Please manually install VS Code from https://code.visualstudio.com/download"
        pause_exit
    fi

    if ! command -v code >/dev/null 2>&1; then
        local cli_path="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        local target=""
        for dir in /usr/local/bin "$HOME/.local/bin"; do
            if [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null; then
                target="$dir/code"
                break
            fi
        done
        if [[ -z "$target" ]]; then
            error "No writable directory in PATH to create 'code' symlink"
            pause_exit
        fi
        ln -sf "$cli_path" "$target"
        export PATH="$(dirname "$target"):$PATH"
        hash -r || true
        success "Created 'code' symlink at $target"
    fi

    success "VS Code installed and CLI configured"
}

install_vscode() {
    case "$PLATFORM" in
        linux)  install_vscode_linux ;;
        macos)  install_vscode_macos ;;
    esac
}

# -----------------------------
# Claude Extension
# -----------------------------
install_claude_extension() {
    log "Installing Claude Code extension..."

    if ! command -v code >/dev/null 2>&1; then
        error "Unable to find 'code' command even after VS Code installation."
        echo ""
        echo "Manual fix:"
        echo "1. Open VS Code"
        echo "2. Press Cmd+Shift+P (Mac) / Ctrl+Shift+P (Linux)"
        echo "3. Run 'Shell Command: Install code command in PATH'"
        echo "4. Then rerun this script or just run 'claude' directly"
        pause_exit
    fi

    if code --list-extensions | grep -qi "anthropic.claude-code"; then
        success "Claude Code extension already installed"
        return
    fi

    log "Installing Claude extension..."
    if code --install-extension anthropic.claude-code --force; then
        success "Claude Code extension installed"
    else
        error "Failed to install Claude extension."
        pause_exit
    fi
}

# -----------------------------
# OpenCode API Key
# -----------------------------
validate_api_key() {
    local key="$1"
    log "Validating API key..."
    HTTP_CODE=$(curl -s --connect-timeout 10 --max-time 20 -o /tmp/opencode_check.json -w "%{http_code}" -H "Authorization: Bearer $key" https://opencode.ai/zen/go/v1/models || true)
    if [[ "$HTTP_CODE" == "200" ]]; then
        success "API key validated"
        return 0
    elif [[ "$HTTP_CODE" == "401" ]]; then
        error "Invalid API key"
        return 1
    else
        warn "Validation returned HTTP $HTTP_CODE - proceeding anyway"
        return 0
    fi
}

# -----------------------------
# Install OpenCode
# -----------------------------
install_opencode() {
    log "Installing OpenCode..."
    if command -v opencode >/dev/null 2>&1; then
        success "OpenCode already installed"
        return
    fi
    if curl -fsSL https://opencode.ai/install | bash; then
        success "OpenCode installed"
    else
        error "Failed to install OpenCode"
        pause_exit
    fi
    export PATH="$HOME/.local/bin:$PATH"
    [[ "$SHELL" == *"zsh"* ]] && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    hash -r || true
}

# -----------------------------
# Install Claude Code CLI
# -----------------------------
install_claude_code() {
    log "Installing Claude Code CLI..."
    if command -v claude >/dev/null 2>&1; then
        success "Claude Code already installed"
        return
    fi
    case "$PLATFORM" in
        macos)
            if command -v brew >/dev/null 2>&1; then
                brew install --cask claude-code || true
            else
                curl -fsSL https://claude.ai/install.sh | bash
            fi
            ;;
        linux)
            curl -fsSL https://claude.ai/install.sh | bash
            ;;
    esac
    export PATH="$HOME/.local/bin:$PATH"
    hash -r || true
    if command -v claude >/dev/null 2>&1; then
        success "Claude Code installed"
    else
        error "Claude installation failed"
        pause_exit
    fi
}

# -----------------------------
# Claude Config
# -----------------------------
setup_claude_config() {
    CONFIG_DIR="$HOME/.claude"
    CONFIG_FILE="$CONFIG_DIR/settings.json"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://opencode.ai/zen/",
    "ANTHROPIC_API_KEY": "$SECRET_KEY",
    "ANTHROPIC_MODEL": "minimax-m2.5-free",
    "ENABLE_TOOL_SEARCH": "true"
  }
}
EOF
    success "Claude configuration saved"
}

append_shell_env() {
    local rc=""
    [[ "$SHELL" == *"zsh"* ]] && rc="$HOME/.zshrc" || rc="$HOME/.bashrc"
    if [[ -n "$rc" ]] && ! grep -q "opencode.ai/zen/" "$rc" 2>/dev/null; then
        cat >> "$rc" <<EOF

# OpenCode Claude Setup
export ANTHROPIC_BASE_URL="https://opencode.ai/zen/"
export ANTHROPIC_API_KEY="$SECRET_KEY"
export ANTHROPIC_MODEL="minimax-m2.5-free"
export ENABLE_TOOL_SEARCH="true"
EOF
        success "Shell environment configured"
    else
        success "Shell environment already configured"
    fi
}

# -----------------------------
# Open VS Code
# -----------------------------
open_ide() {
    if command -v code >/dev/null 2>&1; then
        code .
    else
        warn "Cannot open IDE - 'code' command still missing"
    fi
}

# -----------------------------
# Main
# -----------------------------
clear
echo "===================================================="
echo " ClaudeFree v1.4.0"
echo " Claude Code + OpenCode AI Auto Setup"
echo "===================================================="
echo ""
echo "Get your OpenCode API key here: https://opencode.ai/"

if [[ "$*" == *"--help"* ]]; then
    echo ""
    echo "Usage:"
    echo "  bash <(curl -sSL https://raw.githubusercontent.com/BlackHatDevX/claudefree-installer/main/setup.sh)"
    echo "  curl -sSL ... | bash -s -- --non-interactive"
    echo ""
    echo "Options:"
    echo "  --non-interactive   Skip all prompts (use CI=1 as well)."
    echo "  --help              Show this help."
    exit 0
fi

check_network
check_storage
detect_os

# API key handling
SAVED_KEY_FILE="$HOME/.claude_free_api_key"
SECRET_KEY=""
if [[ -f "$SAVED_KEY_FILE" ]] && [[ -s "$SAVED_KEY_FILE" ]] && [[ "$NON_INTERACTIVE" != "true" ]]; then
    SAVED_KEY=$(cat "$SAVED_KEY_FILE")
    echo ""
    echo -e "${YELLOW}Found saved API key.${NC}"
    read -rp "Press Enter to use saved key, or type 'no' to enter a new one: " REUSE_KEY </dev/tty
    if [[ "$REUSE_KEY" != "no" ]]; then
        SECRET_KEY="$SAVED_KEY"
        success "Using saved API key"
    fi
fi

if [[ -z "$SECRET_KEY" ]]; then
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        error "Non-interactive mode requires an existing saved API key or setting SECRET_KEY environment variable."
        exit 1
    fi
    echo ""
    echo "Get your secret key from: https://opencode.ai/auth"
    echo ""
    case "$PLATFORM" in
        macos)  open "https://opencode.ai/auth" 2>/dev/null || true ;;
        linux)  xdg-open "https://opencode.ai/auth" 2>/dev/null || true ;;
    esac
    echo "Paste your API key below:"
    read -rsp "Enter your OpenCode Secret Key: " SECRET_KEY </dev/tty
    echo ""
    if [[ -z "${SECRET_KEY// }" ]]; then
        error "Secret key cannot be empty."
        pause_exit
    fi
    echo "$SECRET_KEY" > "$SAVED_KEY_FILE"
    chmod 600 "$SAVED_KEY_FILE"
fi

validate_api_key "$SECRET_KEY" || pause_exit

install_opencode
install_claude_code
install_vscode
install_claude_extension
setup_claude_config
append_shell_env

echo ""
echo "===================================================="
echo -e "${GREEN}Setup complete!${NC}"
echo "===================================================="
echo ""

if [[ -t 0 ]] && [[ "$NON_INTERACTIVE" != "true" ]]; then
    echo "Starting Claude CLI. Type your questions/commands below."
    echo "Please complete any setup steps (Enter > Pointer UP > Enter x 4 > type /exit)."
    echo "When done, type /exit and press Enter."
    echo ""
    read -rp "Press Enter to start Claude CLI..." </dev/tty
    echo ""
    unset ANTHROPIC_API_KEY ANTHROPIC_BASE_URL
    claude
else
    echo "To start Claude CLI interactively, run: claude"
    echo "Or open VS Code and use the Claude Code extension."
fi

echo ""
echo "===================================================="
echo -e "${GREEN}Claude is FREE and ready to be used in VS Code${NC}"
echo "===================================================="
echo ""
echo -e "${BLUE}GitHub Repository:${NC}"
echo "https://github.com/BlackHatDevX/claudefree-installer"
echo ""
echo -e "${YELLOW}Please give us a star on GitHub to support this project!${NC}"
echo ""
echo -e "${BLUE}Found an issue?${NC}"
echo "  Raise an issue: https://github.com/BlackHatDevX/claudefree-installer/issues"
echo "  Contact developer: https://github.com/BlackHatDevX"
echo ""
echo "Claude Extension: https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code"
echo ""

if [[ -t 0 ]] && [[ "$NON_INTERACTIVE" != "true" ]]; then
    read -rp "Press Enter to open your IDE..." </dev/tty
    open_ide
else
    echo "Run 'code .' to open VS Code in the current directory."
fi
