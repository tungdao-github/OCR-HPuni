param(
    [string]$AppRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$PythonPath = "",
    [string]$AppPool = "DefaultAppPool",
    [string]$SiteName = "",
    [int]$Port = 9090,
    [string]$ApiKey = "",
    [string]$CorsOrigins = ""
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) {
    Write-Host "[deploy-iis] $msg"
}

function Resolve-PythonPath([string]$customPath) {
    if ($customPath -and (Test-Path $customPath)) { return $customPath }

    $candidates = @(
        "C:\\Python310\\python.exe",
        "C:\\Python311\\python.exe",
        "C:\\Python39\\python.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    $cmd = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    return ""
}

$resolved = Resolve-Path $AppRoot
$AppRoot = $resolved.Path.TrimEnd("\")

Write-Info "AppRoot = $AppRoot"

$PythonPath = Resolve-PythonPath $PythonPath
if (-not $PythonPath) {
    throw "Python not found. Install Python to C:\\Python310 or pass -PythonPath."
}
Write-Info "Python = $PythonPath"

$venvPython = Join-Path $AppRoot ".venv_iis\\Scripts\\python.exe"
$reqFile = Join-Path $AppRoot "requirements_api.txt"
$appsettingsPath = Join-Path $AppRoot "appsettings.json"
$logsDir = Join-Path $AppRoot "logs"

if (-not (Test-Path $venvPython)) {
    Write-Info "Create venv .venv_iis"
    & $PythonPath -m venv (Join-Path $AppRoot ".venv_iis")
}

Write-Info "Install requirements (this can take time)..."
& $venvPython -m pip install -U pip
& $venvPython -m pip install -r $reqFile

if (-not (Test-Path $appsettingsPath)) {
    Write-Info "Create appsettings.json"
    @"
{
  "APP_ROOT": "$AppRoot",
  "API_KEY": "change-me",
  "MAX_UPLOAD_MB": 25,
  "MAX_PAGES": 20,
  "CORS_ALLOW_ORIGINS": "http://localhost:3000,https://your-web.com"
}
"@ | Set-Content -Encoding UTF8 $appsettingsPath
}

try {
    $json = Get-Content -Raw $appsettingsPath | ConvertFrom-Json
    $json | Add-Member -MemberType NoteProperty -Name "APP_ROOT" -Value $AppRoot -Force
    if ($ApiKey) { $json | Add-Member -MemberType NoteProperty -Name "API_KEY" -Value $ApiKey -Force }
    if ($CorsOrigins) { $json | Add-Member -MemberType NoteProperty -Name "CORS_ALLOW_ORIGINS" -Value $CorsOrigins -Force }
    $json | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $appsettingsPath
    Write-Info "Updated appsettings.json"
} catch {
    Write-Info "Warning: failed to update appsettings.json: $($_.Exception.Message)"
}

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Force $logsDir | Out-Null
    Write-Info "Created logs folder"
}

$setupScript = Join-Path $AppRoot "setup-iis.ps1"
if (-not (Test-Path $setupScript)) {
    throw "setup-iis.ps1 not found in $AppRoot"
}

& $setupScript -AppRoot $AppRoot -AppPool $AppPool -UpdateAppSettings:$false

if ($SiteName) {
    $appcmd = Join-Path $env:windir "System32\\inetsrv\\appcmd.exe"
    if (Test-Path $appcmd) {
        $poolExists = & $appcmd list apppool "$AppPool" 2>$null
        if (-not $poolExists) {
            Write-Info "Create app pool: $AppPool"
            & $appcmd add apppool /name:"$AppPool" | Out-Null
            & $appcmd set apppool "$AppPool" /autoStart:true | Out-Null
        } else {
            Write-Info "App pool exists: $AppPool"
        }

        $exists = & $appcmd list site "$SiteName" 2>$null
        if (-not $exists) {
            Write-Info "Create IIS site: $SiteName (port $Port)"
            & $appcmd add site /name:$SiteName /bindings:"http/*:$Port:" /physicalPath:"$AppRoot" | Out-Null
        } else {
            Write-Info "Site exists: $SiteName"
            & $appcmd set site "$SiteName" /physicalPath:"$AppRoot" | Out-Null
        }
        & $appcmd set app "$SiteName/" /applicationPool:"$AppPool" | Out-Null
    } else {
        Write-Info "Warning: appcmd not found, skip site setup."
    }
}

Write-Info "Done. Test: http://localhost:$Port/health"
