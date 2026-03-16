param(
    [string]$AppDir = "C:\deploy\deepdoc_vietocr",
    [string]$ServiceName = "DeepDocVietOCR_API",
    [string]$ApiKey = "change-me",
    [string]$NssmExe = "C:\Tools\nssm\nssm.exe",
    [string]$PythonExe = "C:\Python310\python.exe"
)

if (!(Test-Path $AppDir)) {
    Write-Error "AppDir not found: $AppDir"
    exit 1
}
if (!(Test-Path $NssmExe)) {
    Write-Error "NSSM not found: $NssmExe"
    exit 1
}
if (!(Test-Path $PythonExe)) {
    Write-Error "Python not found: $PythonExe"
    exit 1
}

Write-Host "Creating venv and installing requirements..."
& $PythonExe -m venv "$AppDir\.venv"
& "$AppDir\.venv\Scripts\python.exe" -m pip install -U pip
& "$AppDir\.venv\Scripts\python.exe" -m pip install -r "$AppDir\requirements_api.txt"

Write-Host "Installing Windows service..."
& $NssmExe install $ServiceName "$AppDir\.venv\Scripts\python.exe" "-m uvicorn api:app --host 127.0.0.1 --port 8000 --workers 1"
& $NssmExe set $ServiceName AppDirectory $AppDir
& $NssmExe set $ServiceName AppEnvironmentExtra "PYTHONIOENCODING=utf-8" "API_KEY=$ApiKey" "MAX_UPLOAD_MB=25" "MAX_PAGES=50" "MAX_CONCURRENT_JOBS=1"
& $NssmExe start $ServiceName

Write-Host "Service started: $ServiceName"
