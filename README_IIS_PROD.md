# Deploy OCR API on IIS (Windows Server)

This guide is for deploying on server 113.160.100.80 with domain ocr.dhhp.edu.vn.

## 0) Prerequisites
- Python 3.10 x64.
- Microsoft Visual C++ Redistributable x64.
- IIS + modules:
  - URL Rewrite
  - Application Request Routing (ARR) + enable Proxy
- NSSM (nssm.exe) at C:\Tools\nssm\nssm.exe

## 1) Copy source to server
Example: C:\deploy\deepdoc_vietocr

## 2) Create venv + install deps
```powershell
cd C:\deploy\deepdoc_vietocr
python -m venv .venv
.venv\Scripts\python -m pip install -U pip
.venv\Scripts\python -m pip install -r requirements_api.txt
```

## 3) Run API as Windows Service (NSSM)
```powershell
C:\Tools\nssm\nssm.exe install DeepDocVietOCR_API C:\deploy\deepdoc_vietocr\.venv\Scripts\python.exe "-m uvicorn api:app --host 127.0.0.1 --port 8000 --workers 1"
C:\Tools\nssm\nssm.exe set DeepDocVietOCR_API AppDirectory C:\deploy\deepdoc_vietocr
C:\Tools\nssm\nssm.exe set DeepDocVietOCR_API AppEnvironmentExtra "PYTHONIOENCODING=utf-8" "API_KEY=YOUR_API_KEY" "MAX_UPLOAD_MB=25" "MAX_PAGES=50" "MAX_CONCURRENT_JOBS=1"
net start DeepDocVietOCR_API
```

## 4) IIS Reverse Proxy
### 4.1 Enable ARR Proxy
IIS Manager -> Server -> "Application Request Routing Cache" -> "Server Proxy Settings..." -> tick "Enable proxy".

### 4.2 Create site + web.config
- Create site: host header ocr.dhhp.edu.vn, path C:\inetpub\ocr
- Copy web.config from:
  - C:\deploy\deepdoc_vietocr\iis\web.config
  - to: C:\inetpub\ocr\web.config

(Or run: scripts\iis_setup.ps1)

## 5) HTTPS
Bind HTTPS for ocr.dhhp.edu.vn with valid cert (Lets Encrypt or internal CA).

## 6) Test
```powershell
curl.exe http://127.0.0.1:8000/health
curl.exe -X POST "https://ocr.dhhp.edu.vn/v1/extract?task=ocr&output=text" -H "X-API-Key: YOUR_API_KEY" -F "file=@C:\test\hoadonbanhang.png"
```

## Notes
- OCR is CPU heavy. Recommended MAX_CONCURRENT_JOBS=1.
- Increase maxAllowedContentLength in iis\web.config if you need bigger uploads.
