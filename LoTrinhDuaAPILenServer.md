LỘ TRÌNH TRIỂN KHAI API FASTAPI LÊN IIS (THEO MICROSOFT) – DỄ NHƯ LỚP 1

LƯU Ý QUAN TRỌNG

- Cách này chỉ làm được trên Windows Pro/Enterprise/Server (Windows Home không có IIS).
- Cách này dùng HttpPlatformHandler (Microsoft khuyến nghị).

========================================
BƯỚC 1 — CÀI PYTHON

1. Tải Python 3.10 x64 và cài.
2. Khi cài, tick “Add Python to PATH”.
3. Ghi lại đường dẫn python.exe (ví dụ: C:\Python310\python.exe).
4. Mở CMD gõ:
   python --version

========================================
BƯỚC 2 — BẬT IIS + CGI

1. Nhấn Win + R → gõ optionalfeatures → Enter
2. Tick “Internet Information Services”
3. Mở rộng:
   Internet Information Services
   → Web Server
   → Application Development Features
4. Tick “CGI”
5. OK

========================================
BƯỚC 3 — CÀI HttpPlatformHandler

1. Tải tại:
   https://www.iis.net/downloads/microsoft/httpplatformhandler
2. Cài xong mở IIS Manager
3. Vào Modules, thấy “httpPlatformHandler” là đúng.

========================================
BƯỚC 4 — CHÉP SOURCE CODE LÊN SERVER

1. Tạo thư mục:
   C:\deploy\HPUni-OCR-vietnamese-handwriting
2. Copy toàn bộ code vào đây.

========================================
BƯỚC 5 — TẠO VENV VÀ CÀI THƯ VIỆN
Mở CMD:
cd C:\deploy\HPUni-OCR-vietnamese-handwriting
python -m venv .venv
.venv\Scripts\activate
.venv\Scripts\python -m pip install -U pip
pip install -r requirements.txt
pip install -r requirements_api.txt

========================================
BƯỚC 6 — TẠO THƯ MỤC IIS
Mở CMD:
mkdir C:\inetpub\ocr-local
mkdir C:\inetpub\ocr-local\logs

========================================
BƯỚC 7 — TẠO FILE web.config

1. Tạo file:
   C:\inetpub\ocr-local\web.config
2. Copy nội dung sau vào (chỉnh đúng đường dẫn):

<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="httpPlatformHandler" path="*" verb="*" modules="httpPlatformHandler"
           resourceType="Unspecified" requireAccess="Script" />
    </handlers>
    <httpPlatform
      processPath="C:\deploy\HPUni-OCR-vietnamese-handwriting\.venv\Scripts\python.exe"
      arguments="-m uvicorn api:app --host 127.0.0.1 --port %HTTP_PLATFORM_PORT%"
      stdoutLogEnabled="true"
      stdoutLogFile="C:\inetpub\ocr-local\logs\python.log"
      startupTimeLimit="60"
      startupRetryCount="10">
      <environmentVariables>
        <environmentVariable name="API_KEY" value="change-me" />
        <environmentVariable name="MAX_UPLOAD_MB" value="25" />
        <environmentVariable name="MAX_PAGES" value="20" />
      </environmentVariables>
    </httpPlatform>
  </system.webServer>
</configuration>

========================================
BƯỚC 8 — TẠO SITE IIS

1. Mở IIS Manager
2. Chuột phải Sites → Add Website
3. Điền:
   Site name: ocr-local
   Physical path: C:\inetpub\ocr-local
   Port: 8081
4. Bấm OK

========================================
BƯỚC 9 — START SITE

1. Chọn site ocr-local
2. Bấm Start

========================================
BƯỚC 10 — TEST

1. Test health:
   curl.exe http://localhost:8081/health
   → phải ra {"ok":true}
2. Test OCR:
   curl.exe -X POST "http://localhost:8081/extract?task=ocr&output=text" ^
   -H "X-API-Key: change-me" ^
   -F "file=@C:\path\to\file.pdf"

DONE

- IIS sẽ tự khởi chạy Python khi site start.
- Không cần NSSM.
