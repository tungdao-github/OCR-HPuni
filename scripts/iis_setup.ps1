param(
    [string]$SiteName = "ocr.dhhp.edu.vn",
    [string]$SitePath = "C:\inetpub\ocr",
    [string]$BackendUrl = "http://127.0.0.1:8000",
    [int]$HttpPort = 80
)

Import-Module WebAdministration

if (!(Test-Path $SitePath)) {
    New-Item -ItemType Directory -Path $SitePath | Out-Null
}

# Copy web.config if exists in deploy folder
$configSrc = "C:\deploy\deepdoc_vietocr\iis\web.config"
if (Test-Path $configSrc) {
    Copy-Item $configSrc -Destination (Join-Path $SitePath "web.config") -Force
}

# Create or update site
if (Get-Website | Where-Object { $_.Name -eq $SiteName }) {
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $SitePath
} else {
    New-Website -Name $SiteName -PhysicalPath $SitePath -Port $HttpPort -HostHeader $SiteName | Out-Null
}

# Enable ARR proxy if ARR is installed
try {
    Set-WebConfigurationProperty -pspath "MACHINE/WEBROOT/APPHOST" -filter "system.webServer/proxy" -name "enabled" -value "True"
} catch {
    Write-Warning "ARR proxy not enabled. Make sure ARR is installed, then re-run this script."
}

Write-Host "IIS site ready: $SiteName -> $SitePath"
Write-Host "Backend URL expected: $BackendUrl"
