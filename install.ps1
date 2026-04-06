param(
    [string]$RepoUrl = "https://github.com/tungdao-github/OCR-HPuni.git",
    [string]$AppRoot = "C:\\apps\\OCR-HPuni",
    [string]$AppPool = "OCR-HPuni-Pool",
    [string]$SiteName = "OCR-HPuni",
    [int]$Port = 9090,
    [string]$PythonPath = "",
    [string]$ApiKey = "",
    [string]$CorsOrigins = ""
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) {
    Write-Host "[install] $msg"
}

function Read-Default([string]$prompt, [string]$default) {
    $val = Read-Host "$prompt [$default]"
    if ([string]::IsNullOrWhiteSpace($val)) { return $default }
    return $val
}

function Read-DefaultInt([string]$prompt, [int]$default) {
    $val = Read-Host "$prompt [$default]"
    if ([string]::IsNullOrWhiteSpace($val)) { return $default }
    return [int]$val
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host "[install] Warning: not running as Administrator. IIS steps may fail."
}

Write-Host "=== OCR-HPuni IIS Installer ==="
$RepoUrl = Read-Default "Repo URL" $RepoUrl
$AppRoot = Read-Default "AppRoot (install folder)" $AppRoot
$AppPool = Read-Default "IIS App Pool name" $AppPool
$SiteName = Read-Default "IIS Site name" $SiteName
$Port = Read-DefaultInt "IIS Port" $Port

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = Read-Host "API Key (leave empty to skip)"
}
if ([string]::IsNullOrWhiteSpace($CorsOrigins)) {
    $CorsOrigins = Read-Host "CORS origins (comma-separated, leave empty to skip)"
}
if ([string]::IsNullOrWhiteSpace($PythonPath)) {
    $PythonPath = Read-Host "Python path (leave empty for auto-detect)"
}

if (-not (Test-Path $AppRoot)) {
    Write-Info "Cloning repo to $AppRoot"
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $git) { throw "git not found. Please install Git first." }
    git clone $RepoUrl $AppRoot
} else {
    Write-Info "Repo folder exists: $AppRoot"
}

$deployScript = Join-Path $AppRoot "deploy-iis.ps1"
if (-not (Test-Path $deployScript)) {
    throw "deploy-iis.ps1 not found in $AppRoot"
}

Write-Info "Running deploy-iis.ps1..."
& $deployScript -AppRoot $AppRoot -PythonPath $PythonPath -AppPool $AppPool -SiteName $SiteName -Port $Port -ApiKey $ApiKey -CorsOrigins $CorsOrigins

Write-Info "Done. Test: http://localhost:$Port/health"
