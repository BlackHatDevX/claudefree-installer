#!/bin/bash
# ClaudeFree Universal Installer – v1.4.0
# Downloads the correct binary for your OS/architecture and runs it.
# Usage: curl -sSL https://raw.githubusercontent.com/BlackHatDevX/claudefree-installer/main/claudefree-install.sh | bash
# For Windows, use the PowerShell command in README.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
die()   { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }
info()  { echo -e "${GREEN}[*]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

REPO="BlackHatDevX/claudefree-installer"
BRANCH="main"

# Detect OS & architecture
case "$(uname -s)" in
  Linux*)  PLATFORM="linux";   ARCH="$(uname -m)" ;;
  Darwin*) PLATFORM="macos";   ARCH="$(uname -m)" ;;
  MINGW*|MSYS*|CYGWIN*)
    echo -e "${RED}Windows detected. This script is for Unix-like systems only.${NC}"
    echo -e "${YELLOW}Please use the PowerShell command from the README:${NC}"
    echo -e "${GREEN}powershell -ExecutionPolicy Bypass -Command \"Invoke-WebRequest -Uri 'https://github.com/BlackHatDevX/claudefree-installer/raw/main/bin/setup_windows.exe' -OutFile ([Environment]::GetFolderPath('Desktop') + '\\setup_windows.exe'); Start-Process ([Environment]::GetFolderPath('Desktop') + '\\setup_windows.exe') -Wait\"${NC}"
    exit 1
    ;;
  *) die "Unsupported OS: $(uname -s)" ;;
esac

# Map to binary name (bin folder names)
case "$PLATFORM" in
  linux)
    case "$ARCH" in
      x86_64)   BIN_NAME="setup_linux_x86_64" ;;
      aarch64|arm64) BIN_NAME="setup_linux_arm64" ;;
      *) die "Unsupported architecture: $ARCH" ;;
    esac
    ;;
  macos)
    case "$ARCH" in
      arm64)    BIN_NAME="setup_macos_arm64" ;;
      x86_64)   BIN_NAME="setup_macos_x86_64" ;;
      *) die "Unsupported architecture: $ARCH" ;;
    esac
    ;;
esac

info "Detected: $PLATFORM / $ARCH -> $BIN_NAME"

# Download URL (always from raw bin/ folder, not release fallback)
URL="https://raw.githubusercontent.com/$REPO/$BRANCH/bin/$BIN_NAME"
OUTPUT="./claudefree-setup"

info "Downloading from $URL"
if command -v curl &>/dev/null; then
  curl -fsSL "$URL" -o "$OUTPUT"
elif command -v wget &>/dev/null; then
  wget -q "$URL" -O "$OUTPUT"
else
  die "Neither curl nor wget found. Please install one of them."
fi

info "Download successful"
chmod +x "$OUTPUT"
info "Running ClaudeFree installer..."
echo ""
"$OUTPUT"

# Optional: ask to delete the binary after execution?
echo ""
read -p "Delete the downloaded binary (claudefree-setup)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -f "$OUTPUT"
  info "Binary deleted."
else
  info "Binary left as '$OUTPUT' in current directory."
fi

exit 0