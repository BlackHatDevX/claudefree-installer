# ============================================================
# ClaudeFree v1.4.0 (Final)
# Claude Code + OpenCode AI Auto Setup – Windows
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ----------------------------- Colors -----------------------------
$ESC = [char]27
$RED = "${ESC}[31m"
$GREEN = "${ESC}[32m"
$YELLOW = "${ESC}[33m"
$BLUE = "${ESC}[34m"
$NC = "${ESC}[0m"

function log { Write-Host "${BLUE}[*]${NC} $args" }
function success { Write-Host "${GREEN}[OK]${NC} $args" }
function warn { Write-Host "${YELLOW}[!]${NC} $args" }
function error { Write-Host "${RED}[X]${NC} $args" }

function pause-exit {
    Write-Host ""
    if ($Host.Name -eq "ConsoleHost") { Read-Host "Press Enter to exit..." }
    exit 1
}

function ensure-admin {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        error "This script must be run as Administrator."
        Read-Host "Press Enter to exit..."
        exit 1
    }
}

function check-network {
    log "Checking internet connection..."
    try { $null = Invoke-WebRequest -Uri "https://opencode.ai" -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop; success "Internet connection OK" }
    catch { error "No internet connection or opencode.ai unreachable."; pause-exit }
}

function check-storage {
    log "Checking available storage..."
    try {
        $drive = Get-PSDrive -Name $PWD.Root.Name | Select-Object -First 1
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        if ($drive.Free / 1MB -lt 500) { error "At least 500MB free space required. Currently: ${freeGB}GB free"; pause-exit }
        success "Sufficient storage available (${freeGB}GB free)"
    } catch { warn "Could not determine free space, continuing..." }
}

function detect-windows {
    log "Detecting Windows version..."
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $major = $os.Version.Split('.')[0]
        $build = $os.BuildNumber
        $product = $os.Caption
    } catch {
        $osVersion = [System.Environment]::OSVersion.Version
        $major = $osVersion.Major; $build = $osVersion.Build; $product = "Windows"
    }
    if ($major -ge 10) { success "Detected $product (Version $major.$build)" }
    else { error "Windows 10 or later is required. Detected: $product (Version $major.$build)"; pause-exit }
}

function refresh-path { $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User") }

# ----------------------------- Installers -----------------------------
function install-chocolatey {
    log "Installing Chocolatey..."
    if (Get-Command choco -ErrorAction SilentlyContinue) { success "Chocolatey already installed"; return }
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    try { Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) }
    catch { error "Chocolatey installation failed: $_"; pause-exit }
    refresh-path
    if (Get-Command choco -ErrorAction SilentlyContinue) { success "Chocolatey installed" }
    else { error "Chocolatey not found after installation"; pause-exit }
}

function install-vscode {
    log "Installing VS Code..."
    if (Get-Command code -ErrorAction SilentlyContinue) { success "VS Code already installed"; return }
    choco install vscode -y --no-progress --limit-output
    refresh-path; Start-Sleep -Seconds 5
    foreach ($dir in @("${env:ProgramFiles}\Microsoft VS Code\bin", "${env:ProgramFiles(x86)}\Microsoft VS Code\bin", "C:\ProgramData\chocolatey\bin")) {
        if ((Test-Path "$dir\code.exe") -and ($env:Path -notlike "*$dir*")) { $env:Path = "$dir;$env:Path" }
    }
    refresh-path
    if (Get-Command code -ErrorAction SilentlyContinue) { success "VS Code installed" }
    else { warn "VS Code installed but 'code' command not in PATH." }
}

function install-nodejs {
    log "Installing Node.js v24.15.0..."
    try { $null = Get-Command node -ErrorAction Stop; $nodeVersion = (node --version 2>$null); if ($nodeVersion) { success "Node.js already installed ($nodeVersion)"; return } } catch {}
    choco install nodejs --version=24.15.0 -y --no-progress --limit-output
    refresh-path; Start-Sleep -Seconds 5
    foreach ($dir in @("${env:ProgramFiles}\nodejs", "${env:ProgramFiles(x86)}\nodejs", "C:\ProgramData\chocolatey\bin")) {
        if ((Test-Path "$dir\node.exe") -and ($env:Path -notlike "*$dir*")) { $env:Path = "$dir;$env:Path" }
    }
    refresh-path
    try { $nodeVersion = (node --version 2>$null); if ($nodeVersion) { success "Node.js installed ($nodeVersion)"; return } } catch {}
    error "Node.js installation failed - node command not found"; pause-exit
}

function install-opencode {
    log "Installing OpenCode AI..."
    if (Get-Command opencode -ErrorAction SilentlyContinue) { success "OpenCode already installed"; return }
    try {
        npm install -g opencode-ai
        refresh-path; Start-Sleep -Seconds 3
        if (Get-Command opencode -ErrorAction SilentlyContinue) { success "OpenCode AI installed" }
        else { error "OpenCode installation failed"; pause-exit }
    } catch { error "Failed to install OpenCode: $_"; pause-exit }
}

function install-claude-code {
    log "Installing Claude Code CLI..."
    if (Get-Command claude -ErrorAction SilentlyContinue) { success "Claude Code already installed"; return }
    try {
        Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -OutFile "$env:TEMP\claude_install.ps1" -UseBasicParsing
        powershell -ExecutionPolicy Bypass -File "$env:TEMP\claude_install.ps1"
        Remove-Item "$env:TEMP\claude_install.ps1" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $localBin = "$env:USERPROFILE\.local\bin"
        if (Test-Path "$localBin\claude.exe") {
            if ($env:Path -notlike "*$localBin*") { $env:Path = "$localBin;$env:Path" }
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$localBin*") {
                $newUserPath = if ($userPath) { "$userPath;$localBin" } else { $localBin }
                [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
                success "Added $localBin to user PATH (permanent)"
            }
            if (Get-Command claude -ErrorAction SilentlyContinue) { success "Claude Code CLI installed" }
            else { & "$localBin\claude.exe" --version | Out-Null; if ($LASTEXITCODE -eq 0) { success "Claude Code CLI installed (available at $localBin\claude.exe)" } else { error "Claude Code installation failed"; pause-exit } }
        } else { error "Claude Code binary not found at expected location: $localBin"; pause-exit }
    } catch { error "Failed to install Claude Code: $_"; pause-exit }
}

function validate-api-key {
    param([string]$key)
    log "Validating API key..."
    try { $response = Invoke-WebRequest -Uri "https://opencode.ai/zen/go/v1/models" -Headers @{ "Authorization" = "Bearer $key" } -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop; $httpCode = $response.StatusCode }
    catch { $httpCode = $_.Exception.Response.StatusCode.value__ }
    if ($httpCode -eq 200) { success "API key validated"; return $true }
    elseif ($httpCode -eq 401) { error "Invalid API key"; return $false }
    else { warn "Validation returned HTTP $httpCode - proceeding anyway"; return $true }
}

function install-claude-extension {
    log "Installing Claude Code extension..."
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) { error "VS Code 'code' command not found. Install it via VS Code."; pause-exit }
    $extensions = code --list-extensions 2>$null
    if ($extensions -match "anthropic.claude-code") { success "Claude Code extension already installed"; return }
    try { code --install-extension anthropic.claude-code --force; success "Claude Code extension installed" }
    catch { error "Failed to install Claude extension."; pause-exit }
}

function setup-claude-config {
    param([string]$apiKey)
    log "Configuring Claude settings..."

    # Remove any line breaks (CR, LF) and trim surrounding whitespace
    $cleanKey = $apiKey -replace "`r`n", "" -replace "`n", "" -replace "`r", ""
    $cleanKey = $cleanKey.Trim()

    $configDir = "$HOME\.claude"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $configFile = "$configDir\settings.json"
    
    # Escape double quotes (just in case)
    $escapedKey = $cleanKey -replace '"', '\"'
    
    $configJson = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://opencode.ai/zen/",
    "ANTHROPIC_API_KEY": "$escapedKey",
    "ANTHROPIC_MODEL": "minimax-m2.5-free",
    "ENABLE_TOOL_SEARCH": "true"
  }
}
"@

    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($configFile, $configJson, $utf8NoBom)
        success "Claude configuration saved to $configFile"
    } catch {
        error "Failed to write config file: $_"
        pause-exit
    }
}

function append-shell-env {
    param([string]$apiKey)
    $profilePath = $PROFILE
    if ([string]::IsNullOrEmpty($profilePath)) { warn "PowerShell profile path not found. Skipping environment variable setup."; return }
    $profileDir = Split-Path $profilePath
    if (-not (Test-Path $profileDir)) { try { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null } catch { warn "Could not create profile directory: $profileDir"; return } }
    $envContent = @"

# OpenCode Claude Setup
`$env:ANTHROPIC_BASE_URL = `"https://opencode.ai/zen/`"
`$env:ANTHROPIC_API_KEY = `"$apiKey`"
`$env:ANTHROPIC_MODEL = `"minimax-m2.5-free`"
`$env:ENABLE_TOOL_SEARCH = `"true`"
"@
    if (Test-Path $profilePath) {
        $existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($existing -notmatch "opencode.ai/zen/") { Add-Content -Path $profilePath -Value $envContent -Encoding UTF8; success "Shell environment configured in profile" }
        else { success "Shell environment already configured" }
    } else { Set-Content -Path $profilePath -Value $envContent -Encoding UTF8; success "Shell environment configured in new profile" }
}

# ----------------------------- Claude Interactive (new window) -----------------------------
function run-claude-setup {
    log "Launching Claude Code CLI for initial configuration..."
    Write-Host ""
    Write-Host "${YELLOW}A new terminal window will open with Claude CLI.${NC}"
    Write-Host "${YELLOW}Please complete any setup steps (Enter > Pointer UP > Enter x 4 > type /exit).${NC}"
    Write-Host "${YELLOW}When you are done, type ${GREEN}/exit${YELLOW} inside Claude, then close the terminal window.${NC}"
    Write-Host ""
    Read-Host "Press Enter to open Claude in a new window..."

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Host "${GREEN}Opening Claude in a new terminal window...${NC}"
        Start-Process cmd -ArgumentList "/k claude"
        Write-Host ""
        Write-Host "${YELLOW}Claude is running in another window.${NC}"
        Write-Host "${YELLOW}After you type ${GREEN}/exit${YELLOW} (and see the prompt return), please close that terminal window.${NC}"
        Write-Host ""
        Read-Host "Press Enter after you have closed the Claude terminal window..."
        success "Claude CLI session ended. Returning to setup script."
    } else {
        warn "Claude command not found. Skipping interactive setup."
        warn "You can launch Claude manually by typing 'claude' in a new terminal."
    }
}

function open-ide {
    if (Get-Command code -ErrorAction SilentlyContinue) { Write-Host "${GREEN}Opening VS Code...${NC}"; code . }
    else { warn "Cannot open VS Code - 'code' command not found" }
}

# ----------------------------- Main -----------------------------
Clear-Host
Write-Host "===================================================="
Write-Host " ClaudeFree v1.4.0 (Final)"
Write-Host " Claude Code + OpenCode AI Auto Setup"
Write-Host "===================================================="
Write-Host ""

# --- Load module for secure strings (if available)
try {
    Import-Module Microsoft.PowerShell.SecretManagement -Force -ErrorAction Stop
    $secureModuleAvailable = $true
} catch {
    $secureModuleAvailable = $false
    warn "Secure credential module not available. API key will be stored in plain text (less secure)."
}

$secureSecretPath = "$env:USERPROFILE\.claude_free\secret.claude"
$secretKey = $null

# --- Check for saved key
if (Test-Path $secureSecretPath) {
    Write-Host "${YELLOW}A saved API key was found.${NC}"
    $useSavedKey = Read-Host "Use it? (Y/N)"
    if ($useSavedKey -eq 'Y') {
        if ($secureModuleAvailable) {
            try {
                $secureKey = Get-Content $secureSecretPath | ConvertTo-SecureString
                $secretKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey))
                $secretKey = $secretKey.Trim() -replace "`r`n", "" -replace "`n", "" -replace "`r", ""
                success "Using saved API key."
            } catch {
                warn "Could not read saved key. You will be prompted for a new one."
                $secretKey = $null
            }
        } else {
            # Fallback: read plain text (not recommended but works)
            $secretKey = Get-Content $secureSecretPath -Raw
            success "Using saved API key (plain text)."
        }
    }
}

# --- If no saved key or user declined, prompt for new key
if (-not $secretKey) {
    Write-Host "${YELLOW}Opening OpenCode website to get your API key...${NC}"
    Start-Process "https://opencode.ai/auth"
    Write-Host ""
    if ($secureModuleAvailable) {
        $secureKey = Read-Host "Enter your OpenCode Secret Key" -AsSecureString
        $secretKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey))
        # Save encrypted
        $secureDir = Split-Path $secureSecretPath
        if (-not (Test-Path $secureDir)) { New-Item -ItemType Directory -Path $secureDir -Force | Out-Null }
        $secureKey | ConvertFrom-SecureString | Out-File $secureSecretPath
        success "API key saved securely for future use."
    } else {
        $secretKey = Read-Host "Enter your OpenCode Secret Key"
        # Save plain text (fallback)
        $secureDir = Split-Path $secureSecretPath
        if (-not (Test-Path $secureDir)) { New-Item -ItemType Directory -Path $secureDir -Force | Out-Null }
        $secretKey | Out-File $secureSecretPath
        success "API key saved (plain text) for future use."
    }
}

if ([string]::IsNullOrWhiteSpace($secretKey)) {
    error "Secret key cannot be empty."
    pause-exit
}

# --- Validate key
if (-not (validate-api-key $secretKey)) { pause-exit }

# --- Pre-flight checks
check-network
check-storage
detect-windows

# --- Installation
Write-Host ""
log "Starting installation..."
Write-Host ""

ensure-admin
refresh-path
install-chocolatey
Write-Host ""
install-vscode
Write-Host ""
install-nodejs
Write-Host ""
install-opencode
Write-Host ""
install-claude-code
Write-Host ""
install-claude-extension
Write-Host ""

try { setup-claude-config $secretKey } catch { error "Claude configuration failed: $_"; pause-exit }
Write-Host ""
try { append-shell-env $secretKey } catch { warn "Could not update PowerShell profile: $_" }

# --- Interactive Claude session (new window)
run-claude-setup

# --- Final message
Write-Host ""
Write-Host "===================================================="
Write-Host "${GREEN}Setup complete!${NC}"
Write-Host "===================================================="
Write-Host ""
$nodeVer = & cmd /c "node --version 2>nul"
$npmVer = & cmd /c "npm --version 2>nul"
Write-Host "Node.js version: $nodeVer"
Write-Host "npm version: $npmVer"
Write-Host "VS Code: $(if (Get-Command code -ErrorAction SilentlyContinue) { 'Available' } else { 'Not in PATH' })"
Write-Host "Claude Code: $(if (Get-Command claude -ErrorAction SilentlyContinue) { 'Available' } else { 'Not in PATH' })"
Write-Host "OpenCode: $(if (Get-Command opencode -ErrorAction SilentlyContinue) { 'Available' } else { 'Not in PATH' })"
Write-Host ""
Write-Host "${GREEN}Claude is FREE and ready to be used in VS Code${NC}"
Write-Host ""
Write-Host "${BLUE}GitHub Repository:${NC} https://github.com/BlackHatDevX/claudefree-installer"
Write-Host ""
Write-Host "${YELLOW}Star us on GitHub to support this project!${NC}"
Write-Host ""
Write-Host "${BLUE}Found an issue?${NC} https://github.com/BlackHatDevX/claudefree-installer/issues"
Write-Host ""

$openVscode = Read-Host "Press Enter to open VS Code, or type 'no' to skip"
if ($openVscode -ne "no") { open-ide }

Write-Host ""
Read-Host "Press Enter to exit..."