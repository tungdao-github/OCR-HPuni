# Deploy API Với IIS (Windows Server)

Mục tiêu: chạy `uvicorn` ở localhost và dùng IIS reverse-proxy ra Internet.

## 1) Cài prerequisites trên server

- Cài Python 3.10+ (x64).
- Cài Microsoft Visual C++ Redistributable (x64) 2015–2022/2026.
- Cài IIS.
- Cài IIS modules:
  - URL Rewrite
  - Application Request Routing (ARR) + bật “Proxy”

## 2) Cài project + chạy Uvicorn

Trong thư mục `deepdoc_vietocr`:

```powershell
python -m venv .venv
.venv\Scripts\python -m pip install -U pip
.venv\Scripts\python -m pip install -r requirements_api.txt
```

Chạy thử local:

```powershell
$env:PYTHONIOENCODING="utf-8"
$env:API_KEY="change-me"           # optional, để trống thì không check
$env:MAX_UPLOAD_MB="25"
$env:MAX_PAGES="50"
$env:MAX_CONCURRENT_JOBS="1"

.venv\Scripts\python -m uvicorn api:app --host 127.0.0.1 --port 8000
```

Test:

```powershell
curl.exe -X POST "http://127.0.0.1:8000/v1/extract?task=all" -H "X-API-Key: change-me" -F "file=@C:\path\to\hoadonbanhang.png"
```

## 3) Chạy như Windows Service (khuyến nghị)

Cách đơn giản: dùng NSSM.

1. Tải `nssm.exe` (64-bit) và đặt vào `C:\Tools\nssm\nssm.exe`.
2. Cài service:

```powershell
cd C:\Users\TUNG\deloyAPIToServer\deepdoc_vietocr
C:\Tools\nssm\nssm.exe install DeepDocVietOCR_API
```

Trong NSSM GUI:

- Application Path: `C:\Users\TUNG\deloyAPIToServer\deepdoc_vietocr\.venv\Scripts\python.exe`
- Startup directory: `C:\Users\TUNG\deloyAPIToServer\deepdoc_vietocr`
- Arguments:
  - `-m uvicorn api:app --host 127.0.0.1 --port 8000 --workers 1`
- Environment:
  - `PYTHONIOENCODING=utf-8`
  - `API_KEY=...` (nếu muốn khoá)
  - `MAX_UPLOAD_MB=25`
  - `MAX_PAGES=50`
  - `MAX_CONCURRENT_JOBS=1`

Start service:

```powershell
net start DeepDocVietOCR_API
```

## 4) IIS Reverse Proxy

### 4.1 Bật proxy trong ARR

IIS Manager → server root → “Application Request Routing Cache” → “Server Proxy Settings…” → tick “Enable proxy”.

### 4.2 Tạo site và rule rewrite

- Tạo website mới (bind domain + HTTPS nếu có).
- Dùng URL Rewrite tạo rule reverse proxy về:
  - `http://127.0.0.1:8000`

## 5) Public ra Internet (nhắc nhanh)

- Mở inbound port 443 trên firewall.
- NAT/Port forward nếu server nằm sau router.
- Khuyến nghị dùng Cloudflare/WAF để rate-limit + chống abuse upload file.

## API Endpoints

- `GET /health`
- `POST /v1/extract?task=ocr|layout|tsr|all`
  - Header (optional): `X-API-Key: ...`
  - Multipart: `file=@...`

