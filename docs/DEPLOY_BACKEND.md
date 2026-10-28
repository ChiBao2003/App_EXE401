# Deploy backend FastAPI lên server HTTPS

Mục tiêu: có URL dạng `https://...` để truyền vào app qua `--dart-define=BACKEND_URL=...`.

## 1. MongoDB Atlas (miễn phí)

1. https://www.mongodb.com/atlas → tạo cluster **M0 Free**.
2. **Database Access** → tạo user + mật khẩu.
3. **Network Access** → ưu tiên IP cố định của hosting nếu có. Render thường dùng IP động; nếu cần `0.0.0.0/0` cho bản thử, bắt buộc dùng tài khoản DB riêng với mật khẩu mạnh và quyền tối thiểu, sau đó giới hạn lại khi có hạ tầng hỗ trợ.
4. **Connect → Drivers** → copy chuỗi `mongodb+srv://<user>:<password>@...`. Đây là `MONGO_URI`.

## 2. Deploy lên Render (ví dụ)

1. Đẩy code lên GitHub (file `.env` đã bị `.gitignore`).
2. Render → **New → Web Service** → chọn repo.
3. Cấu hình:
   - **Root Directory**: `Backend_EXE401`
   - **Runtime**: Docker (dùng `Dockerfile` có sẵn) *hoặc* Python với
     - Build: `pip install -r requirements.txt`
     - Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`
4. **Environment Variables**: nhập các biến trong `Backend_EXE401/.env.example`:
   - `APP_ENV=production`
   - `MONGO_URI`, `MONGO_DB_NAME`, `DATABASE_NAME`
   - `SECRET_KEY` (>= 32 ký tự; server sẽ **từ chối khởi động** nếu thiếu/yếu)
   - `GOOGLE_WEB_CLIENT_ID`, `GEMINI_API_KEY`, `OPENWEATHER_API_KEY`
5. Deploy xong mở `https://<ten-dich-vu>.onrender.com/` → thấy `{"status":"OK",...}`; `/docs` xem Swagger. Kiểm tra thêm luồng đăng nhập và endpoint có truy cập MongoDB, vì health check gốc không kiểm tra truy vấn DB.

Railway, Fly.io, Google Cloud Run hoạt động tương tự vì có `Dockerfile` và đọc cổng từ biến `PORT`.

Tạo `SECRET_KEY`:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

## 3. Lưu ý

- **Gói Free của Render ngủ sau 15 phút không dùng**; request đầu sau khi ngủ có thể mất khoảng một phút. Render ghi rõ Free dùng cho thử nghiệm, không khuyến nghị production. Dùng Free cho Closed Testing nếu chấp nhận độ trễ, chuyển sang gói trả phí nhỏ trước Production nếu cần hoạt động ổn định.
- **ChromaDB (RAG)** lưu ở `storage/chroma` trên đĩa. Đĩa của hầu hết PaaS là tạm thời, dữ liệu mất khi redeploy. Muốn giữ lại cần gắn Persistent Disk/Volume. `RAGService` đã bắt lỗi khởi tạo nên app không sập nếu thiếu.
- **MQTT** mặc định trỏ `localhost`. Nếu tính năng này không dùng ở production thì bỏ qua.
- Backend có job xóa dữ liệu cũ hơn 15 ngày cho `pomodoro_sessions`, `productivity_logs`, `daily_summaries`. Các collection khác chưa được job này xóa; server ngủ sẽ làm job chạy trễ đến lần thức tiếp theo.
- Với `CORS_ORIGINS`, app Android native không bị CORS chặn. Chỉ đặt giá trị cụ thể nếu có bản web.

## 4. Kiểm tra từ máy bạn

```powershell
curl https://<ten-dich-vu>.onrender.com/
```
