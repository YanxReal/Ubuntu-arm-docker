#Requires -Version 5.1
<#
  Ubuntu ARM Docker — one-line installer for Windows (PowerShell)
  =================================================================
  Native Windows installer (no make / WSL / Git Bash required).
  It checks requirements, clones the repository, creates .env, and builds +
  starts the container with `docker compose`.

  Usage (PowerShell):
    irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 | iex

  Options:
    -Dir <path>      Directory to clone into (default: .\ubuntu-arm-docker)
    -Branch <name>   Git branch to use (default: main)
    -NoInstall       Only clone and prepare (.env); skip build/start
    -Help            Show this help

  Environment variables (same effect as parameters):
    UBUNTU_ARM_DOCKER_REPO, UBUNTU_ARM_DOCKER_BRANCH, UBUNTU_ARM_DOCKER_DIR
#>

[CmdletBinding()]
param(
    [string]$Dir,
    [string]$Branch,
    [switch]$NoInstall,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ProgressPreference     = 'SilentlyContinue'   # speed up Invoke-WebRequest/RestMethod

$RepoUrl   = if ($env:UBUNTU_ARM_DOCKER_REPO)   { $env:UBUNTU_ARM_DOCKER_REPO }   else { 'https://github.com/YanxReal/Ubuntu-arm-docker.git' }
$Branch    = if ($PSBoundParameters.ContainsKey('Branch')) { $Branch } elseif ($env:UBUNTU_ARM_DOCKER_BRANCH) { $env:UBUNTU_ARM_DOCKER_BRANCH } else { 'main' }
$TargetDir = if ($PSBoundParameters.ContainsKey('Dir'))     { $Dir }     elseif ($env:UBUNTU_ARM_DOCKER_DIR)     { $env:UBUNTU_ARM_DOCKER_DIR }     else { 'ubuntu-arm-docker' }

function Write-Step { param($Msg) Write-Host "==> $Msg" -ForegroundColor Cyan  }
function Write-Ok   { param($Msg) Write-Host "  ok $Msg" -ForegroundColor Green }
function Write-Warn { param($Msg) Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Fail       { param($Msg) Write-Host "  [x] $Msg" -ForegroundColor Red   -NoNewline; Write-Host; exit 1 }

if ($Help) {
    Write-Host @'
Ubuntu ARM Docker — Windows installer (PowerShell)

Clones https://github.com/YanxReal/Ubuntu-arm-docker, creates .env and builds +
starts the container with docker compose (no make required).

Usage (PowerShell):
  irm https://raw.githubusercontent.com/YanxReal/Ubuntu-arm-docker/main/install.ps1 | iex

Options:
  -Dir <path>      Directory to clone into (default: .\ubuntu-arm-docker)
  -Branch <name>   Git branch to use (default: main)
  -NoInstall       Only clone and prepare (.env); skip build/start
  -Help            Show this help
'@
    exit 0
}

Write-Host "`nUbuntu ARM Docker — installer (Windows / PowerShell)`n" -ForegroundColor Magenta

# ── Requirements ────────────────────────────────────────────────────────────
Write-Step 'Checking requirements...'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'git is required. Install it from https://git-scm.com/download/win and retry.' }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Fail 'Docker is required. Install Docker Desktop from https://www.docker.com/products/docker-desktop/.' }

try {
    docker version --format '{{.Server.Version}}' | Out-Null
} catch {
    Fail 'Docker is installed but not running. Start Docker Desktop and retry.'
}

$Arch = $env:PROCESSOR_ARCHITECTURE
switch -Regex ($Arch) {
    'ARM64|ARM' { Write-Ok "Architecture $Arch — native" }
    default {
        Write-Warn "You are on $Arch. The image is arm64, so it runs under QEMU emulation (slower). Docker Desktop emulates arm64 automatically."
    }
}

Write-Ok "Requirements OK ($Arch, Docker $(docker version --format '{{.Server.Version}}'))"

# ── Clone or update ─────────────────────────────────────────────────────────
if (Test-Path (Join-Path $TargetDir '.git')) {
    Write-Step "Existing repository found in $TargetDir; updating..."
    Push-Location $TargetDir
    git fetch --depth 1 origin $Branch
    git checkout $Branch
    git pull --ff-only origin $Branch
    Pop-Location
} elseif ((Test-Path $TargetDir) -and (Get-ChildItem $TargetDir -Force | Select-Object -First 1)) {
    Fail "$TargetDir already exists and is not a git repository. Choose another directory with -Dir."
} else {
    Write-Step "Cloning $RepoUrl (branch: $Branch) into $TargetDir..."
    git clone --depth 1 --branch $Branch $RepoUrl $TargetDir
}

Push-Location $TargetDir
try {
    if (-not (Test-Path '.env')) {
        Copy-Item '.env.example' '.env'
        Write-Ok 'Created .env from .env.example'
    }

    if ($NoInstall) {
        Write-Ok "Repository ready in $(Get-Location)"
        Write-Host "`nNext step: cd $TargetDir ; docker compose build ; docker compose up -d`n"
        exit 0
    }

    # ── Build and start ────────────────────────────────────────────────────
    Write-Step 'Building the image (first run may take a while)...'
    docker compose build
    if ($LASTEXITCODE -ne 0) { Fail 'docker compose build failed.' }

    Write-Step 'Starting the container...'
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { Fail 'docker compose up failed.' }

    Write-Step 'Waiting for noVNC to respond...'
    $Port = $env:NOVNC_HOST_PORT
    if (-not $Port) { $Port = '6080' }
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:$Port/vnc.html" -UseBasicParsing -TimeoutSec 2
            if ($r.StatusCode -eq 200) { $ready = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { Write-Warn 'noVNC did not answer in time — check `docker compose ps` and `docker compose logs`.' }

    $VncPassword = if ($env:VNC_PASSWORD) { $env:VNC_PASSWORD } else { 'admin' }
    $VncPort     = if ($env:VNC_HOST_PORT) { $env:VNC_HOST_PORT } else { '5902' }
    $SshPort     = if ($env:SSH_HOST_PORT) { $env:SSH_HOST_PORT } else { '2222' }

    Write-Host "`n"
    Write-Ok 'Installation finished.'
    Write-Host "  noVNC : http://localhost:$Port/vnc.html   (password: $VncPassword)"
    Write-Host "  VNC   : localhost:$VncPort                (password: $VncPassword)"
    Write-Host "  SSH   : ssh admin@localhost -p $SshPort   (password: admin)`n"
} finally {
    Pop-Location
}