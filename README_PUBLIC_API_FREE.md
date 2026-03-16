# Public API Miễn Phí (Chuẩn DevOps, Không Tốn Dịch Vụ)

Không có “hosting OCR nặng” nào thật sự miễn phí mãi mãi. Cách miễn phí thực tế nhất là:

- Bạn tự chạy server (PC/VPS của bạn).
- Dùng Cloudflare Tunnel (free) để public ra Internet mà không mở port.

Ưu điểm: free, nhanh triển khai, không cần IP tĩnh.
Nhược: URL tunnel dạng “quick tunnel” sẽ đổi khi restart (muốn URL cố định cần domain – domain thường không free).

## 1) Chạy bằng Docker (khuyến nghị)

Trong `deepdoc_vietocr`:

```powershell
docker compose up -d --build
```

Test local:

```powershell
curl.exe -X POST "http://localhost:8000/v1/extract?task=all&output=minimal" -H "X-API-Key: change-me" -F "file=@C:\path\to\hoadonbanhang.png"
```

Test bằng URL (server tự tải file):

```powershell
curl.exe -X POST "http://localhost:8000/v1/extract_url?task=ocr&output=text" -H "X-API-Key: change-me" -H "Content-Type: application/json" --data "{\"url\":\"https://example.com/file.pdf\"}"
```

## 2) Public ra Internet (Free) bằng Cloudflare Quick Tunnel

```powershell
docker compose --profile tunnel up -d
docker compose logs -f cloudflared
```

Trong log sẽ có URL dạng `https://xxxx.trycloudflare.com` → share URL đó cho người khác gọi API.

## 3) Bảo vệ API (bắt buộc khi public)

- Đặt `API_KEY` khác `change-me`.
- Giữ `MAX_CONCURRENT_JOBS=1` để tránh quá tải.
- Giới hạn `MAX_UPLOAD_MB`, `MAX_PAGES`.

## Endpoints

- `GET /health`
- `POST /v1/extract?task=ocr|layout|tsr|all&output=json|minimal|text`
  - Header: `X-API-Key: <key>`
  - Multipart: `file=@...`
- `POST /v1/extract_url?task=ocr|layout|tsr|all&output=json|minimal|text`
  - Header: `X-API-Key: <key>`
  - JSON body: `{"url":"https://..."}`
