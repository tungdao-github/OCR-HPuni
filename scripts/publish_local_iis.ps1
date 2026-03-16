param(
    [string]$SourceDir = "C:\Users\TUNG\deloyAPIToServer\deepdoc_vietocr",
    [string]$TargetDir = "C:\inetpub\ocr-local",
    [string]$SiteName = "ocr-local",
    [string]$Port = "8081",
    [string]$ApiKey = "change-me",
    [string]$NssmExe = "C:\Tools\nssm\nssm.exe"
)

function Require-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Error "Please run PowerShell as Administrator."
        exit 1
    }
}

Require-Admin

if (!(Test-Path $SourceDir)) {
    Write-Error "SourceDir not found: $SourceDir"
    exit 1
}

# Copy project to IIS folder
Write-Host "Copying project to $TargetDir ..."
if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}
robocopy $SourceDir $TargetDir /E /XD .git .venv __pycache__ ocr_outputs ocr_outputs_invoice layouts_outputs_layout layouts_outputs_tsr layouts_outputs_invoice_layout layouts_outputs_invoice_tsr log _smoke_ocr _smoke_layout /XF *.log *.tmp *.cache | Out-Null

# Ensure web.config exists in target
if (!(Test-Path (Join-Path $TargetDir "web.config"))) {
    Copy-Item (Join-Path $SourceDir "iis\web.config") -Destination (Join-Path $TargetDir "web.config") -Force
}

# Create venv and install API deps (only if missing)
if (!(Test-Path (Join-Path $TargetDir ".venv\Scripts\python.exe"))) {
    Write-Host "Creating venv and installing requirements..."
    python -m venv (Join-Path $TargetDir ".venv")
    & (Join-Path $TargetDir ".venv\Scripts\python.exe") -m pip install -U pip
    & (Join-Path $TargetDir ".venv\Scripts\python.exe") -m pip install -r (Join-Path $TargetDir "requirements_api.txt")
}

# Install Windows service via NSSM
if (!(Test-Path $NssmExe)) {
    Write-Error "NSSM not found: $NssmExe"
    exit 1
}
$serviceName = "DeepDocVietOCR_API"
& $NssmExe install $serviceName (Join-Path $TargetDir ".venv\Scripts\python.exe") "-m uvicorn api:app --host 127.0.0.1 --port 8000 --workers 1"
& $NssmExe set $serviceName AppDirectory $TargetDir
& $NssmExe set $serviceName AppEnvironmentExtra "PYTHONIOENCODING=utf-8" "API_KEY=$ApiKey" "MAX_UPLOAD_MB=25" "MAX_PAGES=50" "MAX_CONCURRENT_JOBS=1"
& $NssmExe start $serviceName

# Create/update IIS site binding
Import-Module WebAdministration
if (Get-Website | Where-Object { $_.Name -eq $SiteName }) {
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $TargetDir
} else {
    New-Website -Name $SiteName -PhysicalPath $TargetDir -Port $Port -HostHeader "" | Out-Null
}

# Force binding to localhost:Port (no host header)
$binding = "*:${Port}:"
& $env:windir\System32\inetsrv\appcmd.exe set site "$SiteName" /bindings.[protocol='http',bindingInformation="$binding"]

# Enable ARR proxy
try {
    Set-WebConfigurationProperty -pspath "MACHINE/WEBROOT/APPHOST" -filter "system.webServer/proxy" -name "enabled" -value "True"
} catch {
    Write-Warning "ARR proxy not enabled. Make sure ARR + URL Rewrite are installed."
}

Write-Host "Done. Test: curl.exe http://localhost:$Port/health"
