# HỢP ĐỒNG KỸ THUẬT & MA TRẬN TÍCH HỢP FRONTEND - BACKEND (API CONTRACT AUDIT)
**Dự án:** Smart Pomodoro Watch × AI Productivity Ecosystem  
**Ngày kiểm toán:** 15/10/2026  
**Cơ sở kiểm toán:** Đối chiếu trực tiếp mã nguồn Flutter (`Frontend_EXE401/lib`) và FastAPI (`Backend_EXE401/api/v1` & `Backend_EXE401/routes`).

---

## 1. MA TRẬN HỢP ĐỒNG API CHI TIẾT

Bảng dưới đây truy vết từng thao tác mạng từ màn hình giao diện (Frontend) đến tầng xử lý Backend, cơ sở dữ liệu và dữ liệu trả về:

| # | HTTP Method & Route Thực Tế | Màn Hình / Thao Tác Gọi (Frontend) | Tham Số / Body Schema (Frontend Gửi) | Yêu Cầu Auth | Backend Controller / Service | Database Collections | Response Schema & Trường Frontend Dùng | Xử Lý Lỗi Frontend | Trạng Thái Đối Soát |
|---|---|---|---|---|---|---|---|---|---|
| **1** | `POST /api/v1/auth/register` | `SCR-01` Đăng Ký<br/>(Bấm nút "Tạo Tài Khoản") | `{"email": str, "password": str, "display_name": str}` | Không (`auth: false`) | `api/v1/auth_router.py`<br/>`register()` | `users` | Trả về `TokenOut` (`access_token`, `user`). Frontend lưu vào `SharedPreferences`. | Bắt `ApiException`, hiển thị thông báo trong box đỏ | ✅ **KHỚP CHUẨN** (Verified) |
| **2** | `POST /api/v1/auth/login` | `SCR-01` Đăng Nhập<br/>(Bấm nút "Đăng Nhập") | `{"email": str, "password": str}` | Không (`auth: false`) | `api/v1/auth_router.py`<br/>`login()` | `users` | Trả về `TokenOut`. Frontend lưu token, `user_id`, `user_name`, `user_email`. | Bắt `ApiException` (401/lỗi mạng), hiển thị box đỏ | ✅ **KHỚP CHUẨN** (Verified) |
| **3** | `GET /api/v1/auth/me` | `SCR-04` AI Hub<br/>(Khởi tạo màn hình) | Headers: `Bearer <token>` | Có (Bearer) | `api/v1/auth_router.py`<br/>`me()` | `users` | Trả về `UserOut`. Frontend dùng `display_name` hiển thị lời chào. | Fallback hiển thị tên "Bạn" nếu lỗi | ✅ **KHỚP CHUẨN** (Verified) |
| **4** | `PUT /api/v1/auth/me/preferences` | *Chưa màn hình nào gọi* | `{"preferences": dict}` | Có (Bearer) | `api/v1/auth_router.py`<br/>`update_preferences()` | `users` | `{"status": "ok", "message": "..."}` | Chưa triển khai | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **5** | `POST /api/v1/pomodoro/sync` | `SCR-03` Pomodoro<br/>(ESP32 gửi JSON qua BLE) | `{"user_id": str, "hardware_data": {...}, "phone_data": {...}}` | Có (Bearer - Backend inject `user_id`) | `api/v1/pomodoro_router.py`<br/>`sync_pomodoro_session()` | `pomodoro_sessions`<br/>`productivity_logs`<br/>`ai_recommendation_logs` | Trả về `{"status": "ok", "feedback": str, "computed": {...}}`. Frontend dùng `feedback`. | Bắt lỗi timeout và exception, gán vào `_lastFeedback` | ✅ **KHỚP CHUẨN** (Verified) |
| **6** | `GET /api/v1/pomodoro/history/{user_id}` | *Chưa màn hình nào gọi* | Path: `user_id`, Query: `limit=10` | Không bắt buộc | `api/v1/pomodoro_router.py`<br/>`get_pomodoro_history()` | `pomodoro_sessions` | Trả về `{"user_id": str, "sessions": [...]}` | Chưa triển khai trên UI `SCR-03` | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **7** | `GET /api/v1/ai/pomodoro/recommend` | `SCR-04` AI Hub<br/>(Bấm "Lấy Gợi Ý AI") | Query: `concentration_score`, `task_type` | Có (Bearer) | `api/v1/ai_router.py`<br/>`recommend_pomodoro()`<br/>`AdaptivePomodoroAgent` | `productivity_logs` | Trả về `AIRecommendation` (`work_min`, `break_min`, `reason`, `confidence`). | Bắt `ApiException`, hiện SnackBar đỏ | ✅ **KHỚP CHUẨN** (Verified) |
| **8** | `POST /api/v1/ai/pomodoro/feedback` | `AiApi.sendSessionFeedback`<br/>(Helper hàm) | `SessionFeedback` schema | Không bắt buộc | `api/v1/ai_router.py`<br/>`submit_session_feedback()` | `productivity_logs`<br/>`ai_recommendation_logs` | `{"status": "ok", "reward": float}` | Không hiển thị UI | ⚠️ **Ít dùng** (Sync endpoint đã tự ghi prod_log) |
| **9** | `POST /api/v1/ai/productivity/log` | *Chưa màn hình nào gọi* | `ProductivityLog` schema | Có (Bearer) | `api/v1/ai_router.py`<br/>`log_productivity()` | `productivity_logs` | `{"status": "ok"}` | Chưa gắn vào UI | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **10** | `GET /api/v1/ai/burnout/risk` | `SCR-04` AI Hub<br/>(Khởi tạo màn hình) | Headers: `Bearer <token>` | Có (Bearer) | `api/v1/ai_router.py`<br/>`get_burnout_risk()`<br/>`BurnoutDetector` | `pomodoro_sessions`<br/>`productivity_logs` | Trả về `BurnoutRiskResponse` (`risk_score`, `risk_level`, `indicators`, `advice`). | Bắt `ApiException`, hiện SnackBar đỏ | ✅ **KHỚP CHUẨN** (Verified) |
| **11** | `POST /api/v1/ai/coach/chat` | `SCR-05` AI Coach<br/>(Gửi tin nhắn chat) | `{"user_prompt": str, "watch_connected": bool}` | Có (Bearer) | `api/v1/ai_router.py`<br/>`chat_with_ai_coach()`<br/>`AICoachOrchestrator` | `ai_chat_history`<br/>`ai_work_schedules`<br/>`ai_recommendation_logs`<br/>`daily_summaries` | `{"reply": str, "tool_calls": [...], "schedule_plan": {...}, "recommendation_id": str}` | Thêm tin nhắn lỗi vào danh sách chat | ✅ **KHỚP CHUẨN** (Verified) |
| **12** | `POST /api/v1/ai/schedule/save` | `SCR-05` AI Coach<br/>(Bấm "Lưu lịch trình") | `SaveScheduleRequest` schema | Có (Bearer) | `api/v1/ai_router.py`<br/>`save_ai_schedule()` | `ai_work_schedules` | `{"status": "ok", "message": "...", "schedule_id": str}` | Hiện SnackBar thông báo thành công / lỗi | ✅ **KHỚP CHUẨN** (Verified) |
| **13** | `GET /api/v1/ai/schedule/latest` | *Chưa màn hình nào gọi* | Headers: `Bearer <token>` | Có (Bearer) | `api/v1/ai_router.py`<br/>`get_latest_schedule()` | `ai_work_schedules` | `{"status": "ok", "schedule": {...}}` | Chưa triển khai khôi phục lịch trình | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **14** | `GET /api/v1/ai/coach/daily-advice` | `SCR-04` AI Hub<br/>(Khởi tạo màn hình) | Headers: `Bearer <token>` | Có (Bearer) | `api/v1/ai_router.py`<br/>`daily_advice()` | `productivity_logs` | `{"advice": str, "source": str, "personalized": bool, "stats": {...}}` | Bắt `ApiException`, hiện SnackBar | ✅ **KHỚP CHUẨN** (Verified) |
| **15** | `GET /api/v1/context/today` | `SCR-04` AI Hub<br/>(Khởi tạo màn hình) | Query: `lat`, `lon` | Có (Bearer) | `api/v1/context_router.py`<br/>`get_today_context()` | External (OpenWeather) | `{"weather": {...}, "productivity_advice": str, "context_summary": str}` | Bắt `ApiException`, ẩn thẻ thời tiết | ✅ **KHỚP CHUẨN** (Verified) |
| **16** | `GET /api/v1/context/weather` | *Chưa màn hình nào gọi* | Query: `lat`, `lon` | Không | `api/v1/context_router.py`<br/>`get_current_weather()` | External (OpenWeather) | `{"temp_c": float, "humidity": int, ...}` | Chưa dùng | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **17** | `POST /api/v1/usage/events` | *Chưa màn hình nào gọi* | `{"events": [...]}` | Có (Bearer) | `api/v1/usage_router.py`<br/>`upload_usage_events()` | `usage_events` | `{"inserted": int}` | Chưa dùng | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **18** | `POST /api/v1/usage/daily-summary` | `SCR-06` Wellbeing<br/>(Đồng bộ nền / refresh) | `DailyUsageSummaryIn` schema | Có (Bearer) | `api/v1/usage_router.py`<br/>`upload_daily_summary()` | `daily_summaries` | `{"date": str, "upserted": bool, "modified": int}` | In log console `[UsageTracker]` | ✅ **KHỚP CHUẨN** (Verified) |
| **19** | `GET /api/v1/usage/analytics` | *Chưa màn hình nào gọi* | Query: `start_date`, `end_date` | Có (Bearer) | `api/v1/usage_router.py`<br/>`get_usage_analytics()` | `daily_summaries` | `{"period": {...}, "aggregate": {...}, "daily_data": [...]}` | Chưa dùng | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **20** | `GET /api/v1/usage/distractions` | *Chưa màn hình nào gọi* | Query: `session_id` | Không | `api/v1/usage_router.py`<br/>`get_session_distractions()` | `usage_events` | `{"session_id": str, "distractions": [...]}` | Chưa dùng | ⚠️ **CHƯA SỬ DỤNG** (Orphan Endpoint) |
| **21** | `GET /api/v1/usage/ai-context` | Tầng Backend dùng nội bộ | Query: `date` | Không | `api/v1/usage_router.py`<br/>`get_ai_usage_context()` | `daily_summaries` | `{"context": str, "has_data": bool, "summary": {...}}` | Dùng nội bộ cho AI Coach | ⚙️ **NỘI BỘ BACKEND** |
| **22** | `POST /api/v1/competition/groups` | `SCR-07` Thi Đua<br/>(Bấm "Tạo Phòng Mới") | `{"name": str, "duration_days": int}` | Không | `api/v1/competition_router.py`<br/>`create_group()` | `Groups` | `{"status": "success", "room_code": str, "message": str}` | Hiện SnackBar báo lỗi | ✅ **KHỚP CHUẨN** (Verified) |
| **23** | `POST /api/v1/competition/groups/join` | `SCR-07` Thi Đua<br/>(Bấm "Vào Phòng") | `{"room_code": str, "user_id": str}` | Không | `api/v1/competition_router.py`<br/>`join_group()` | `Groups` | `{"status": "success", "message": str}` | Hiện SnackBar lỗi phòng đầy/hết hạn | ✅ **KHỚP CHUẨN** (Verified) |
| **24** | `POST /api/v1/competition/submit` | `SCR-07` Thi Đua<br/>(Bấm "Test Cộng Điểm") | `{"user_id": str, "work_min": int, "completed": bool, "pauses": int}` | Không | `api/v1/competition_router.py`<br/>`submit_session()` | `DailyStats` | `{"status": "success", "prs_earned": int, "message": str}` | Hiện SnackBar thông báo PRS | ✅ **KHỚP CHUẨN** (Verified) |
| **25** | `GET /api/v1/competition/leaderboard/{room_code}` | `SCR-07` Thi Đua<br/>(Vào phòng / chọn tab) | Path: `room_code`, Query: `period` | Không | `api/v1/competition_router.py`<br/>`get_leaderboard()` | `Groups`<br/>`DailyStats` | `{"room_code": str, "leaderboard": [...]}` | Bắt ngoại lệ, set loading = false | ✅ **KHỚP CHUẨN** (Verified) |
| **26** | **XUNG ĐỘT 1**<br/>Frontend gọi: `GET /api/schedules/`<br/>Backend có: `GET /api/v1/schedules/` | `SCR-08` Lịch Nhắc<br/>(Khởi tạo màn hình) | Không có tham số | Không | `api/v1/schedule_router.py`<br/>`get_schedules()` | `schedules` | Backend trả: `[{"day_of_week": "Mon", "hour": 8, "minute": 0, "label": "..."}]`<br/>Frontend mong đợi: `[{"days_of_week": [2], "title": "...", "time": "08:00"}]` | In debugPrint lỗi | ❌ **HỎNG 404 & LỆCH SCHEMA** |
| **27** | **XUNG ĐỘT 2**<br/>Frontend gọi: `POST /api/schedules/`<br/>Backend có: `POST /api/v1/schedules/` | `SCR-08` Lịch Nhắc<br/>(Bấm "Lưu & Đồng bộ") | Frontend gửi: `{"user_id": str, "title": str, "time": str, "days_of_week": [...], "is_active": bool}` | Không | `api/v1/schedule_router.py`<br/>`create_schedule()` | `schedules` | Backend mong đợi: `{"day_of_week": str, "hour": int, "minute": int, "label": str}` | Hiện SnackBar "Lỗi kết nối máy chủ!" | ❌ **HỎNG 404 & LỆCH SCHEMA** |
| **28** | **XUNG ĐỘT 3**<br/>Frontend gọi: `GET /api/firmware/latest`<br/>Backend có: `GET /api/v1/firmware/latest` | `SCR-11` Thông Tin<br/>(Khởi tạo màn hình) | Không có tham số | Không | `api/v1/firmware_router.py`<br/>`get_latest_firmware()` | `firmwares` | Backend trả: `FirmwareEntity` (`version`, `download_url`, `changelog`)<br/>Frontend đọc: `data['description']` (bị NULL) | Bắt lỗi, ẩn thẻ cập nhật | ❌ **HỎNG 404 & LỆCH TÊN TRƯỜNG** |
| **29** | **XUNG ĐỘT 4**<br/>Frontend gọi: `GET /api/market/`<br/>Backend có: `GET /api/v1/market/` | `SCR-14` Chợ Hiệu Ứng<br/>(Khởi tạo màn hình) | Không có tham số | Không | `api/v1/market_router.py`<br/>`get_market_templates()` | `market_templates` | Backend trả danh sách `MarketEntity`. Frontend parse qua `MarketItem.fromJson`. | Hiện chữ "Chợ hiện đang trống" | ❌ **HỎNG 404 (Thiếu `/v1`)** |
| **30** | **XUNG ĐỘT 5**<br/>Frontend gọi: `POST /api/market/`<br/>Backend có: `POST /api/v1/market/` | `SCR-13` Studio & `SCR-14` Chợ<br/>(Bấm nút Upload) | `{"author": str, "thumbnail_url": str, "design_json": {...}, "likes": int}` | Không | `api/v1/market_router.py`<br/>`upload_market_template()` | `market_templates` | Backend trả `MarketEntity` đã tạo. | Hiện SnackBar "Lỗi kết nối máy chủ!" | ❌ **HỎNG 404 & HARDCODE IP** |

---

## 2. PHÂN TÍCH CÁC KHIẾM KHUYẾT & SAI LỆCH QUAN TRỌNG

### 2.1. Sai lệch Tiền tố Đường dẫn (Prefix Mismatch: `/api` vs `/api/v1`)
- **Nguyên nhân gốc rễ:** Ban đầu, Backend chạy các router đơn giản tại thư mục `Backend_EXE401/routes/` với tiền tố `/api/market/`, `/api/schedules/`, `/api/firmware/`. Sau đó, Backend được tái cấu trúc sang Clean Architecture với tiền tố phiên bản `/api/v1/` tại [main.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/main.py). Tuy nhiên, các màn hình cũ ở Frontend ([weekly_schedule_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/schedule/weekly_schedule_screen.dart), [info_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/info/info_screen.dart), [market_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/market/market_screen.dart), [design_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/design/design_screen.dart)) chưa bao giờ được cập nhật lên `/api/v1`.
- **Hậu quả:** 100% các request từ 4 màn hình trên đều nhận phản hồi HTTP `404 Not Found` khi kết nối vào server hiện tại.

### 2.2. Lệch Cấu Trúc Payload & Tên Trường (Field & Schema Inconsistency)

#### A. Mô hình Lịch Nhắc Nhở (`schedules`):
- **Frontend gửi & mong đợi:**
  ```json
  {
    "user_id": "DEFAULT_USER",
    "title": "Họp nhóm đồ án",
    "time": "14:30",
    "days_of_week": [2, 4, 6],
    "is_active": true
  }
  ```
- **Backend Entity (`ScheduleEntity`) định nghĩa:**
  ```python
  class ScheduleEntity:
      day_of_week: str       # "Mon", "Tue"...
      hour: int              # 14
      minute: int            # 30
      label: str             # "Họp nhóm đồ án"
      is_active: bool
  ```
- **Hậu quả:** Ngay cả khi sửa đường dẫn thành `/api/v1/schedules`, Backend vẫn nhận trường `label` rỗng (vì Frontend gửi `title`), và `hour`/`minute` bị gán giá trị mặc định `8:0` (vì Frontend gửi chuỗi `"14:30"`).

#### B. Mô hình Cập nhật Firmware (`firmwares`):
- **File mẫu CSDL [firmwares.json](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/EXE401_Database/firmwares.json):** chứa `"description"` và `"file_url"`.
- **Frontend [info_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/info/info_screen.dart):** đọc `data['description']`.
- **Backend [firmware_entity.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/domain/entities/firmware_entity.py):** định nghĩa `"changelog"` và `"download_url"`.
- **Hậu quả:** Mô tả bản cập nhật hiển thị rỗng (`null`).

### 2.3. Dữ Liệu Giả Lập & Bỏ Qua Backend (Hardcoded & Mock Data)
1. **Radar Chart Digital Twin:** Trong [ai_assistant_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/ai_hub/ai_assistant_screen.dart), widget `const DigitalTwinDashboard()` được khai báo hằng số không tham số, khiến 100% dữ liệu (Focus 82, Stress 40, Break 75, Efficiency 80, Burnout 25%) là số giả lập tĩnh.
2. **Số lần mở khóa điện thoại:** Trong [spp_service.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/bluetooth/spp_service.dart), trường `unlock_count` được gán bằng `(session.pauses * 1.5).round()` thay vì lấy số liệu từ [usage_tracker_service.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/usage_tracking/usage_tracker_service.dart).
3. **Các nút lưu trong Cài Đặt Chung:** Trong [general_settings_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/general_settings/general_settings_screen.dart), 5 nút Lưu (Hiệu chỉnh, Tiết kiệm pin, Báo thức, Đếm ngược, Khôi phục) chỉ kích hoạt `showSuccessSnackbar`, không lưu vào database hay gửi lệnh Bluetooth.
4. **Màn hình Các giao diện:** Trong [interfaces_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/interfaces/interfaces_screen.dart), toàn bộ 9 giao diện được gán cứng trong biến bộ nhớ `_interfaces`.

### 2.4. Hardcode Địa Chỉ IP Mạng Cục Bộ (LAN IP Hardcoding)
- Trong [design_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/design/design_screen.dart) (dòng 171) và [market_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/market/market_screen.dart) (dòng 199), địa chỉ IP được viết cứng: `http://192.168.1.18:8000`.
- Trong khi đó, file cấu hình tập trung [app_constants.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/constants/app_constants.dart) lại cấu hình mặc định là `10.66.196.167`.
- Hậu quả: Khi đổi mạng WiFi hoặc máy tính đổi IP, các chức năng upload sẽ bị treo hoặc sập vì trỏ vào địa chỉ IP không tồn tại.

### 2.5. Các Endpoint Backend Đang Bị Bỏ Quên (Orphan Backend Endpoints)
Các endpoint sau đây đã được cài đặt hoàn chỉnh trên Backend nhưng chưa được màn hình nào của Frontend kết nối:
1. `GET /api/v1/pomodoro/history/{user_id}` (Lấy lịch sử phiên Pomodoro)
2. `PUT /api/v1/auth/me/preferences` (Lưu cài đặt sở thích người dùng)
3. `POST /api/v1/ai/productivity/log` (Ghi nhận log thủ công)
4. `GET /api/v1/ai/schedule/latest` (Khôi phục lịch trình thông minh đang hoạt động)
5. `GET /api/v1/context/weather` (Lấy dữ liệu thời tiết thuần túy)
6. `POST /api/v1/usage/events` (Gửi batch log sử dụng app chi tiết)
7. `GET /api/v1/usage/analytics` (Biểu đồ phân tích sử dụng nhiều ngày)
8. `GET /api/v1/usage/distractions` (Lấy chi tiết danh sách xao nhãng trong 1 phiên)
