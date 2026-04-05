param(
    [string]$AppRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$AppPool = "DefaultAppPool",
    [bool]$UpdateAppSettings = $true
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) {
    Write-Host "[setup-iis] $msg"
}

function Replace-Regex([string]$text, [string]$pattern, [string]$replacement) {
    return [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        $pattern,
        { param($m) $replacement }
    )
}

$resolved = Resolve-Path $AppRoot
$AppRoot = $resolved.Path.TrimEnd("\")

$venvPython = Join-Path $AppRoot ".venv_iis\\Scripts\\python.exe"
$logFile = Join-Path $AppRoot "logs\\python.log"
$appsettingsPath = Join-Path $AppRoot "appsettings.json"

Write-Info "AppRoot = $AppRoot"
Write-Info "Venv Python = $venvPython"
Write-Info "Log File = $logFile"
Write-Info "AppSettings = $appsettingsPath"

$configPaths = @(
    (Join-Path $AppRoot "web.config"),
    (Join-Path $AppRoot "iis\\web.config")
)

foreach ($cfg in $configPaths) {
    if (-not (Test-Path $cfg)) {
        Write-Info "Skip missing: $cfg"
        continue
    }

    $content = Get-Content -Raw $cfg
    $updated = $content

    $updated = Replace-Regex $updated 'processPath="[^"]*?\\.venv_iis\\Scripts\\python\\.exe"' ("processPath=`"$venvPython`"")
    $updated = Replace-Regex $updated 'stdoutLogFile="[^"]*?\\logs\\python\\.log"' ("stdoutLogFile=`"$logFile`"")

    if ($updated -match 'name="APP_CONFIG_PATH"') {
        $updated = Replace-Regex $updated 'name="APP_CONFIG_PATH"\s+value="[^"]*"' ("name=`"APP_CONFIG_PATH`" value=`"$appsettingsPath`"")
    } else {
        if ($updated -match '</environmentVariables>') {
            $insert = "        <environmentVariable name=`"APP_CONFIG_PATH`" value=`"$appsettingsPath`" />`r`n"
            $updated = $updated -replace '</environmentVariables>', ($insert + "      </environmentVariables>")
        } else {
            Write-Info "Warning: environmentVariables not found in $cfg (APP_CONFIG_PATH not set)"
        }
    }

    if ($updated -ne $content) {
        Set-Content -Encoding UTF8 $cfg $updated
        Write-Info "Updated: $cfg"
    } else {
        Write-Info "No change: $cfg"
    }
}

if ($UpdateAppSettings -and (Test-Path $appsettingsPath)) {
    try {
        $json = Get-Content -Raw $appsettingsPath | ConvertFrom-Json
        $json | Add-Member -MemberType NoteProperty -Name "APP_ROOT" -Value $AppRoot -Force
        $json | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $appsettingsPath
        Write-Info "Updated APP_ROOT in appsettings.json"
    } catch {
        Write-Info "Warning: failed to update appsettings.json: $($_.Exception.Message)"
    }
}

$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force $logDir | Out-Null
    Write-Info "Created logs folder"
}

if ($AppPool) {
    try {
        & $env:windir\System32\inetsrv\appcmd.exe recycle apppool /apppool.name:"$AppPool" | Out-Null
        Write-Info "Recycled app pool: $AppPool"
    } catch {
        Write-Info "Warning: failed to recycle app pool ($AppPool): $($_.Exception.Message)"
    }
}
