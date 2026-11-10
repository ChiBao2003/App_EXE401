# Deploy backend FastAPI lên server HTTPS

Mục tiêu: có URL dạng `https://...` để truyền vào app qua `--dart-define=BACKEND_URL=...`.

## 1. MongoDB Atlas (miễn phí)

1. https://www.mongodb.com/atlas → tạo cluster **M0 Free**.
2. **Database Access** → tạo user + mật khẩu.
3. **Network Access** → ưu tiên IP cố định của hosting nếu có. Render thường dùng IP động; nếu cần `0.0.0.0/0` cho bản thử, bắt buộc dùng tài khoản DB riêng với mật khẩu mạnh và quyền tối thiểu, sau đó giới hạn lại khi có hạ tầng hỗ trợ.
4. **Connect → Drivers** → copy chuỗi `mongodb+srv://<user>:<password>@...`. Đây là `MONGO_URI`.

## 2. Deploy native Python lên Render (không dùng Docker)

1. Đẩy code lên GitHub (file `.env` đã bị `.gitignore`).
2. Cách nhanh: Render → **New → Blueprint** → chọn repo. File `render.yaml` ở gốc repo đã tạo Web Service **Python native**, Free, root `Backend_EXE401`, health check `/health/ready`. Khi Render hỏi, nhập `MONGO_URI` và `GOOGLE_WEB_CLIENT_ID`; Render tự tạo `SECRET_KEY`. Sau khi sync, nếu dùng Gemini hoặc OpenWeather thì thêm `GEMINI_API_KEY` / `OPENWEATHER_API_KEY` trong Environment.
3. Nếu tạo thủ công bằng **New → Web Service**, điền:
   - **Root Directory**: `Backend_EXE401`
   - **Language/Runtime**: **Python 3**, không chọn Docker. Render sẽ không dùng Dockerfile nếu chọn Python.
   - **Build Command**: `pip install --no-cache-dir -r requirements-render.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type**: Free để thử Closed Testing.
   - **Health Check Path**: `/health/ready` (kiểm tra kết nối MongoDB thật).
   - File `Backend_EXE401/.python-version` ghim Python **3.11**; Render hiện mặc định Python 3.14 cho dịch vụ mới, có thể gây lỗi tương thích thư viện.
4. **Environment Variables**: nhập các biến trong `Backend_EXE401/.env.example`:
   - `APP_ENV=production`
   - `MONGO_URI`, `MONGO_DB_NAME`, `DATABASE_NAME`
   - `SECRET_KEY` (>= 32 ký tự; server sẽ **từ chối khởi động** nếu thiếu/yếu)
   - `GOOGLE_WEB_CLIENT_ID` (phải trùng Web OAuth Client ID trong Flutter).
   - `ENABLE_RAG=false` (bắt buộc với `requirements-render.txt`; AI Coach vẫn dùng Gemini qua HTTP nếu cấu hình `GEMINI_API_KEY`).
   - `GEMINI_API_KEY`, `OPENWEATHER_API_KEY` tùy tính năng cần bật.
5. Deploy xong mở `https://<ten-dich-vu>.onrender.com/health/ready` → thấy `{"status":"OK","database":"reachable"}`; `/docs` xem Swagger. Nếu endpoint trả 503, kiểm tra `MONGO_URI`, database user và Atlas Network Access. Sau đó thử đăng nhập để kiểm tra luồng thực tế.

Render cấp URL HTTPS `onrender.com` tự động. `Dockerfile` vẫn có trong repo để dùng ở môi trường khác, nhưng cấu hình Web Service này **không sử dụng Docker**.

Tạo `SECRET_KEY`:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

## 3. Lưu ý

- **Gói Free của Render ngủ sau 15 phút không dùng**; request đầu sau khi ngủ có thể mất khoảng một phút. Render ghi rõ Free dùng cho thử nghiệm, không khuyến nghị production. Dùng Free cho Closed Testing nếu chấp nhận độ trễ, chuyển sang gói trả phí nhỏ trước Production nếu cần hoạt động ổn định.
- **ChromaDB (RAG)** không được cài trong `requirements-render.txt` để giảm dung lượng build và RAM cho Render Free. Dữ liệu RAG nằm trong `storage/chroma`, vốn sẽ mất khi Free instance ngủ/redeploy; đặt `ENABLE_RAG=false`. Gemini AI Coach cơ bản vẫn hoạt động nếu có `GEMINI_API_KEY`. Muốn dùng RAG lâu dài, cần nơi lưu bền vững và cài bộ thư viện trong `requirements.txt`.
- **MQTT** mặc định trỏ `localhost`. Nếu tính năng này không dùng ở production thì bỏ qua.
- Backend có job xóa dữ liệu cũ hơn 15 ngày cho `pomodoro_sessions`, `productivity_logs`, `daily_summaries`. Các collection khác chưa được job này xóa; server ngủ sẽ làm job chạy trễ đến lần thức tiếp theo.
- Với `CORS_ORIGINS`, app Android native không bị CORS chặn. Chỉ đặt giá trị cụ thể nếu có bản web.

## 4. Kiểm tra từ máy bạn

```powershell
Invoke-RestMethod https://<ten-dich-vu>.onrender.com/health/ready
```
