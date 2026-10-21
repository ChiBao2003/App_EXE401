# LUỒNG NGƯỜI DÙNG & DÒNG CHẢY DỮ LIỆU ĐẦU-CUỐI (USER FLOWS & DATA FLOW)
**Dự án:** Smart Pomodoro Watch × AI Productivity Ecosystem  
**Ngày kiểm toán:** 15/10/2026  
**Cơ sở kiểm toán:** Đối chiếu trực tiếp mã nguồn Flutter, FastAPI, Motor/MongoDB và firmware ESP32.

---

## 1. SƠ ĐỒ ĐIỀU HƯỚNG TỔNG THỂ (APPLICATION NAVIGATION MAP)

```mermaid
graph TD
    START((Khởi Động App)) --> CHECK_AUTH{Đã có JWT Token<br/>trong SharedPreferences?}
    
    CHECK_AUTH -->|Chưa có| LOGIN_SCR["SCR-01: LoginScreen<br/>(/login)"]
    CHECK_AUTH -->|Đã có| HOME_SCR["SCR-02: HomeScreen<br/>(/)"]
    
    LOGIN_SCR -->|Đăng nhập / Đăng ký thành công| HOME_SCR
    HOME_SCR -->|Bấm Logout| LOGIN_SCR

    subgraph MAIN_NAVIGATION["Các Màn Hình Truy Cập Được Từ Trang Chủ"]
        HOME_SCR -->|Năng suất| POMO_SCR["SCR-03: PomodoroScreen<br/>(/pomodoro)"]
        HOME_SCR -->|Thi đua| COMP_SCR["SCR-07: CompetitionScreen<br/>(/competition)"]
        HOME_SCR -->|Lịch nhắc| SCHED_SCR["SCR-08: WeeklyScheduleScreen<br/>(/schedule)"]
        HOME_SCR -->|Trợ lý AI| AIHUB_SCR["SCR-04: AiHubScreen<br/>(/ai-hub)"]
        HOME_SCR -->|Sức khỏe số| WELL_SCR["SCR-06: WellbeingScreen<br/>(/wellbeing)"]
        HOME_SCR -->|Đồng hồ| CLOCK_SCR["SCR-09: ClockModeScreen<br/>(/clock_mode)"]
        HOME_SCR -->|Cài đặt| SETT_SCR["SCR-10: GeneralSettingsScreen<br/>(/settings)"]
        HOME_SCR -->|Thông tin| INFO_SCR["SCR-11: InfoScreen<br/>(/info)"]
    end

    subgraph SUB_SCREENS["Màn Hình Phụ (Modal / Sub-route)"]
        AIHUB_SCR -->|Bấm nút nổi Live AI Coach| COACH_SCR["SCR-05: AIAssistantScreen<br/>(Push MaterialPageRoute)"]
    end

    subgraph ISOLATED_SCREENS["Các Màn Hình Bị Cô Lập (Chưa Có Lối Vào Từ Home)"]
        INTERFACES_SCR["SCR-12: InterfacesScreen<br/>(/interfaces)"]
        MARKET_SCR["SCR-14: MarketScreen<br/>(/market)"]
        DESIGN_SCR["SCR-13: DesignScreen<br/>(/design)"]
        
        MARKET_SCR -->|Bấm thẻ mẫu| DESIGN_SCR
    end

    style ISOLATED_SCREENS fill:#fff1f0,stroke:#ff4d4f,stroke-dasharray: 5 5
    style MAIN_NAVIGATION fill:#f6ffed,stroke:#52c41a
    style SUB_SCREENS fill:#e6f7ff,stroke:#1890ff
```

---

## 2. CHI TIẾT CÁC LUỒNG DỮ LIỆU ĐẦU-CUỐI (END-TO-END DATA FLOWS)

---

### LUỒNG 1: XÁC THỰC NGƯỜI DÙNG & QUẢN LÝ PHIÊN (AUTHENTICATION & SESSION FLOW)

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant UI as LoginScreen (SCR-01)
    participant AuthApi as AuthApi / ApiClient
    participant Router as auth_router.py
    participant DB as MongoDB (users)

    User->>UI: Nhập email, password, display_name -> Bấm Submit
    UI->>UI: _formKey.currentState.validate()
    UI->>AuthApi: AuthApi.login() / AuthApi.register()
    AuthApi->>Router: POST /api/v1/auth/login hoặc /register
    Router->>DB: find_one({"email": payload.email})
    alt Đăng Ký
        Router->>Router: hash_password(password) bằng bcrypt
        Router->>DB: insert_one(user_doc) kèm preferences & digital_twin mặc định
    else Đăng Nhập
        Router->>Router: verify_password(plain, password_hash)
    end
    Router->>Router: create_access_token({"sub": user_id}) -> JWT HS256
    Router-->>AuthApi: TokenOut (access_token, user: UserOut)
    AuthApi->>AuthApi: SharedPreferences lưu jwt_token, user_id, user_name, user_email
    AuthApi-->>UI: Thành công
    UI->>UI: Navigator.pushReplacementNamed(context, "/") -> HomeScreen
```

- **Bước 1: Hành động người dùng:** Nhập thông tin tài khoản và bấm "Đăng Nhập" hoặc "Tạo Tài Khoản".
  - *Tập tin:* [login_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/auth/login_screen.dart#L41-L62) (`_submit`)
- **Bước 2: Xử lý sự kiện UI:** `_formKey.currentState!.validate()` kiểm tra email và độ dài mật khẩu.
- **Bước 3: Tầng Service Frontend:** [auth_api.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/api/auth_api.dart#L9-L36) (`AuthApi.login` / `register`) -> [api_client.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/api/api_client.dart#L58-L65) (`ApiClient.post`).
- **Bước 4: Backend Route:** [auth_router.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/api/v1/auth_router.py#L28-L88) (`POST /api/v1/auth/login` hoặc `/register`).
- **Bước 5: Logic nghiệp vụ & Database:**
  - Kiểm tra trùng email (khi đăng ký).
  - Băm hoặc đối soát mật khẩu qua thư viện `bcrypt` trực tiếp ([security.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/core/security.py#L23-L31)).
  - Tạo token JWT có thời hạn 7 ngày (`ACCESS_TOKEN_EXPIRE_MINUTES = 10080`).
  - Ghi bản ghi vào collection `users` trong MongoDB.
- **Bước 6: Cập nhật State & Kết quả:** Frontend nhận JSON, lưu token và profile vào `SharedPreferences`, giải phóng form và điều hướng vào trang chủ.
- **Phân loại trạng thái:** ✅ **Hoàn thành và kiểm thử thành công (Implemented & Verified)**

---

### LUỒNG 2: ĐỒNG BỘ PHIÊN POMODORO PHẦN CỨNG ESP32 & PHẢN HỒI AI (POMODORO SYNC FLOW)

```mermaid
sequenceDiagram
    autonumber
    participant ESP as Bo mạch ESP32
    participant BLE as BleService / SppService
    participant UI as PomodoroScreen (SCR-03)
    participant Router as pomodoro_router.py
    participant Agent as AdaptivePomodoroAgent
    participant DB as MongoDB

    ESP->>BLE: Gửi chuỗi JSON qua Bluetooth SPP (Notify char 0xFFE2)
    Note over ESP,BLE: {"work_min":25,"break_min":5,"pauses":2,"completed":true,"session":1}
    BLE->>BLE: _handleJsonPayload() -> parse PomodoroSessionData
    BLE->>UI: Cập nhật lastSession, notifyListeners() -> UI hiển thị thẻ phiên
    BLE->>Router: POST /api/v1/pomodoro/sync (Bearer Token)
    Note over BLE,Router: hardware_data + phone_data (unlock_count, task_type)
    Router->>Router: Tính actual_work_secs, completion_rate, concentration_score
    Router->>Router: generate_ai_feedback() -> sinh nhận xét tiếng Việt
    Router->>DB: insert_one() vào pomodoro_sessions
    Router->>DB: insert_one() vào productivity_logs (dành cho Q-Learning)
    opt Có recommendation_id
        Router->>Agent: update(SessionFeedback) -> Cập nhật Q-Table
        Router->>DB: update_one() vào ai_recommendation_logs (Ghi nhận accepted/outcome)
    end
    Router-->>BLE: Response {"status": "ok", "feedback": "...", "computed": {...}}
    BLE->>UI: _lastFeedback = feedback, notifyListeners()
    UI->>UI: Thẻ AI Phân Tích hiển thị kết quả đánh giá chi tiết
```

- **Bước 1: Hành động phần cứng:** Phiên đếm giờ trên ESP32 kết thúc (hoặc bấm Reset), firmware gọi `sendPomodoroData()` xuất chuỗi JSON qua Bluetooth SPP.
- **Bước 2: Frontend Service đón nhận:** [ble_service.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/bluetooth/ble_service.dart#L127-L137) giải mã UTF-8 từ characteristic `0xFFE2` -> đẩy vào Stream -> [spp_service.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/bluetooth/spp_service.dart#L124-L135) parse thành `PomodoroSessionData`.
- **Bước 3: Gọi API Backend:** [spp_service.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/bluetooth/spp_service.dart#L138-L191) đóng gói `hardware_data` + `phone_data` gọi `POST /api/v1/pomodoro/sync` qua `ApiClient`.
- **Bước 4: Backend Route & Logic tính điểm:** [pomodoro_router.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/api/v1/pomodoro_router.py#L129-L265):
  - Tính thời gian làm thực tế `actual_work_secs` từ RTC DS3231.
  - Tính phạt xao nhãng: `distraction_penalty = (pauses * 5.0) + (unlocks * 10.0)`.
  - Tính điểm tập trung nhân theo tỷ lệ hoàn thành: `conc_score = round(quality_score * (comp_rate / 100.0), 1)`.
  - Sinh phản hồi cá nhân hóa bằng tiếng Việt qua hàm `generate_ai_feedback`.
- **Bước 5: Lưu trữ & Vòng lặp học máy (Feedback Loop):**
  - Lưu vào collection `pomodoro_sessions`.
  - Ghi nhật ký vào `productivity_logs`.
  - Nếu phiên bắt nguồn từ gợi ý của AI Coach (`recommendation_id` hợp lệ), kích hoạt `AdaptivePomodoroAgent.update` cập nhật bảng Q-table và ghi nhận kết quả vào `ai_recommendation_logs`.
- **Bước 6: Phản hồi UI:** [pomodoro_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/pomodoro/pomodoro_screen.dart#L256-L315) hiển thị thẻ AI Phân Tích màu xanh tím đậm.
- **Phân loại trạng thái:** 🟡 **Hoàn thành một phần (Partially Implemented - Unlock Count đang bị mock)**

---

### LUỒNG 3: TRÒ CHUYỆN VỚI AI COACH & SINH LỊCH TRÌNH THÔNG MINH (AI COACH CHAT & SCHEDULING FLOW)

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant UI as AIAssistantScreen (SCR-05)
    participant Router as ai_router.py
    participant Orch as AICoachOrchestrator
    participant Gemini as Google Gemini 3.8 / LLM
    participant DB as MongoDB
    participant Watch as ESP32 Watch

    User->>UI: Nhập "Lên lịch làm việc ngày mai" -> Bấm Gửi
    UI->>Router: POST /api/v1/ai/coach/chat (user_prompt, watch_connected)
    Router->>DB: Đọc Digital Twin profile (digital_twin_service)
    Router->>DB: Đọc Thống kê sử dụng điện thoại hôm nay (daily_summaries)
    Router->>DB: Đọc Nguy cơ kiệt sức BRIX (burnout_detector)
    Router->>DB: Đọc 10 lượt chat gần nhất (ai_chat_history)
    Router->>Orch: orchestrator.chat(user_id, prompt, digital_twin, context, history)
    Orch->>Gemini: Gọi Gemini API kèm Tool Declarations (generate_work_schedule, set_pomodoro_cycle...)
    Gemini-->>Orch: Tool Call: generate_work_schedule(target_date, grade_score, blocks...)
    Orch-->>Router: res kèm tool_calls và reply
    Router->>DB: insert_one() lịch sử vào ai_chat_history
    Router->>DB: Tự động lưu bản ghi lịch trình vào ai_work_schedules (status="active")
    Router-->>UI: Response (reply, tool_calls, schedule_plan, schedule_id)
    UI->>UI: Render bong bóng chat + Thẻ Lịch Trình Thông Minh (_ScheduleCard)
    
    opt Người dùng bấm "Sync Đồng Hồ"
        User->>UI: Bấm "Sync Đồng Hồ"
        loop Từng block làm việc
            UI->>Watch: Gửi lệnh BLE SET_ALARM (time, activity)
        end
    end

    opt Người dùng bấm "Lưu lịch trình"
        User->>UI: Bấm "Lưu lịch trình"
        UI->>Router: POST /api/v1/ai/schedule/save (schedule_id, confirmed)
        Router->>DB: update_one() status="confirmed" trong ai_work_schedules
        Router-->>UI: {"status": "ok", "message": "Đã xác nhận lịch trình."}
        UI->>UI: Hiện badge "Đã lưu lịch trình ✓"
    end
```

- **Bước 1: Hành động người dùng:** Mở `AIAssistantScreen`, nhập yêu cầu tư vấn hoặc lên kế hoạch.
- **Bước 2: Xử lý sự kiện UI:** Thêm tin nhắn user vào danh sách, cuộn xuống đáy, gọi `ApiClient.post('/api/v1/ai/coach/chat')`.
- **Bước 3: Tổng hợp Ngữ cảnh tại Backend ([ai_router.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/api/v1/ai_router.py#L235-L408)):**
  - Lấy Digital Twin profile từ `DigitalTwinService`.
  - Lấy thời tiết từ `ContextService`.
  - Tính toán nguy cơ kiệt sức từ `BurnoutDetector`.
  - Lấy dữ liệu sử dụng điện thoại thực tế từ collection `daily_summaries`.
  - Truy vấn 10 lượt hội thoại gần nhất từ `ai_chat_history`.
- **Bước 4: Điều phối LLM ([ai_coach_orchestrator.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/application/ai/ai_coach_orchestrator.py)):** Kích hoạt Gemini 3.8 / Flash với các công cụ Tool Calling.
- **Bước 5: Xử lý kết quả:**
  - Nếu có công cụ `generate_work_schedule`, Backend tự sinh UUID và lưu vào collection `ai_work_schedules`.
  - Trả về payload hoàn chỉnh cho Flutter.
- **Bước 6: Phản hồi UI:**
  - Nếu có công cụ phần cứng thông thường: Gửi lệnh BLE ngay (`SET_POMO`, `SET_ALARM`, `SHOW_NOTIF`).
  - Nếu có lịch trình: Render widget `_ScheduleCard` với timeline chi tiết, điểm Grade và các nút bấm đồng bộ.
- **Phân loại trạng thái:** 🟡 **Hoàn thành một phần (Partially Implemented - Radar Chart Digital Twin đang dùng dữ liệu mock)**

---

### LUỒNG 4: GIÁM SÁT SỨC KHỎE SỐ & ĐỒNG BỘ NỀN (DIGITAL WELLBEING FLOW)

```mermaid
sequenceDiagram
    autonumber
    participant Android as Android OS (UsageStatsManager)
    participant Service as UsageTrackerService
    participant UI as WellbeingScreen (SCR-06)
    participant Router as usage_router.py
    participant DB as MongoDB (daily_summaries)

    UI->>Service: hasPermission()
    alt Chưa có quyền
        Service-->>UI: false
        UI->>UI: Hiển thị màn hình giải thích chính sách bảo mật
        UI->>Service: requestPermission() -> Mở Cài đặt hệ thống Android
    else Đã có quyền
        UI->>Service: getDailySummary() & getUsageStats()
        Service->>Android: MethodChannel "queryUsageStats" & "queryEvents"
        Android-->>Service: Danh sách ứng dụng, thời gian chạy nền/chạy nổi, sự kiện unlock
        Service->>Service: Tính toán totalScreenTime, totalUnlocks, Focus Score (0-100)
        Service-->>UI: DailyUsageSummary
        UI->>UI: Animate Focus Score Ring, vẽ Top Apps & Pie Chart phân loại
        Service->>Router: POST /api/v1/usage/daily-summary
        Router->>DB: update_one(..., upsert=True) vào daily_summaries
        Router-->>Service: {"upserted": true/false, "modified": 1}
    end
```

- **Bước 1: Kiểm tra quyền hệ thống:** [usage_tracker_service.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/usage_tracking/usage_tracker_service.dart#L27-L45) gọi `checkPermission` qua `MethodChannel('com.daonguyen.iot47/usage_stats')`.
- **Bước 2: Thu thập số liệu:** Truy vấn `UsageStatsManager` của Android để lấy dữ liệu từ 00:00 hôm nay đến hiện tại.
- **Bước 3: Phân loại danh mục:** Phân loại ứng dụng thành `Productivity`, `Social Media`, `Games`, `Entertainment`...
- **Bước 4: Tính điểm Focus Score:**
  $$\text{Focus Score} = \left(1.0 - \frac{\text{Thời gian xao nhãng}}{\text{Tổng thời gian màn hình}}\right) \times 100$$
  *(Kèm hệ số phạt nếu số lần mở khóa quá 50 hoặc 100 lần/ngày).*
- **Bước 5: Đồng bộ máy chủ:** Gọi `POST /api/v1/usage/daily-summary` đẩy kết quả lên MongoDB để AI Coach sử dụng làm ngữ cảnh.
- **Phân loại trạng thái:** ✅ **Đã hoàn thành trên Android (Implemented & Verified on Android)**

---

### LUỒNG 5: ĐẤU TRƯỜNG NĂNG SUẤT THI ĐUA NHÓM (PRODUCTIVITY COMPETITION FLOW)

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant UI as CompetitionScreen (SCR-07)
    participant Router as competition_router.py
    participant DB as MongoDB (Groups, DailyStats)

    alt Tạo phòng mới
        User->>UI: Nhập tên phòng, chọn thời hạn 7/30 ngày -> Bấm "Tạo Phòng Mới"
        UI->>Router: POST /api/v1/competition/groups {"name": ..., "duration_days": ...}
        Router->>Router: generate_room_code() -> Tạo mã 6 ký tự ngẫu nhiên
        Router->>DB: insert_one() vào Groups
        Router-->>UI: {"status": "success", "room_code": "AB12CD"}
        UI->>UI: Tự động gọi join_group() và tải bảng xếp hạng
    else Tham gia phòng đã có
        User->>UI: Nhập mã phòng 6 chữ số -> Bấm "Vào Phòng"
        UI->>Router: POST /api/v1/competition/groups/join {"room_code": ..., "user_id": ...}
        Router->>DB: find_one({"room_code": ...})
        Router->>Router: Kiểm tra hết hạn (_check_expired) & kiểm tra phòng đầy (tối đa 5 người)
        Router->>DB: update_one() push user_id vào members
        Router-->>UI: {"status": "success"}
    end

    UI->>Router: GET /api/v1/competition/leaderboard/{room_code}?period=all
    Router->>DB: Aggregate tính tổng score từ DailyStats theo các thành viên
    Router-->>UI: Leaderboard sắp xếp theo điểm PRS giảm dần
    UI->>UI: Render Bảng xếp hạng trao giải 🥇, 🥈, 🥉
```

- **Bước 1: Hành động người dùng:** Tạo phòng hoặc nhập mã phòng thi đua 6 ký tự.
- **Bước 2: Xử lý tại Backend ([competition_router.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/api/v1/competition_router.py)):**
  - Tạo nhóm mới: Sinh mã UUID 6 ký tự, ghi vào collection `Groups`.
  - Tham gia nhóm: Kiểm tra thời hạn dựa trên `created_at + duration_days`. Giới hạn tối đa 5 người/phòng để đảm bảo tính cạnh tranh cao.
- **Bước 3: Chấm điểm PRS (Productivity Ranking Score):**
  $$\text{PRS} = \text{Phút làm việc} + (\text{Hoàn thành} \times 15) - (\text{Số lần Pause} \times 10)$$
- **Bước 4: Tổng hợp xếp hạng:** Dùng MongoDB Aggregation Pipeline tổng hợp điểm số từ collection `DailyStats` theo bộ lọc thời gian (`today`, `week`, `month`, `all`).
- **Phân loại trạng thái:** ✅ **Đã hoàn thành (Implemented - Cần cải thiện tự động lấy user_id từ token)**

---

### LUỒNG 6: ĐỒNG BỘ THỜI KHÓA BIỂU TUẦN (WEEKLY SCHEDULE FLOW) — [HIỆN TRẠNG LỖI]

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant UI as WeeklyScheduleScreen (SCR-08)
    participant Backend as FastAPI Backend
    participant DB as MongoDB (schedules)

    Note over UI,Backend: ⚠️ ĐIỂM GÃY TÍCH HỢP 1: Sai Route URL
    UI->>Backend: GET /api/schedules/
    Backend-->>UI: HTTP 404 Not Found (Vì router khai báo tại /api/v1/schedules)
    
    User->>UI: Cấu hình ghi chú, bật ngày, chọn slot -> Bấm "Lưu & Đồng bộ"
    Note over UI,Backend: ⚠️ ĐIỂM GÃY TÍCH HỢP 2: Lệch Payload Schema
    UI->>Backend: POST /api/schedules/ {"user_id": ..., "title": ..., "time": "08:00", "days_of_week": [2]}
    Backend-->>UI: HTTP 404 Not Found
    Note over Backend,DB: Backend mong đợi: {"day_of_week": "Mon", "hour": 8, "minute": 0, "label": "..."}
```

- **Phân loại trạng thái:** ❌ **Hỏng tích hợp (Broken Integration)**
- **Khắc phục yêu cầu:**
  1. Cập nhật URL trong [weekly_schedule_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/schedule/weekly_schedule_screen.dart) thành `${AppConstants.baseUrl}/api/v1/schedules/`.
  2. Chuẩn hóa Schema: Đồng nhất giữa cấu trúc `title`/`time`/`days_of_week` (kiểu lịch thực tế) và `ScheduleEntity` của Backend.

---

### LUỒNG 7: THIẾT KẾ & ĐĂNG HIỆU ỨNG LÊN CHỢ (DESIGN STUDIO & MARKETPLACE FLOW) — [HIỆN TRẠNG LỖI]

```mermaid
sequenceDiagram
    autonumber
    actor User as Người dùng
    participant Studio as DesignScreen (SCR-13)
    participant Market as MarketScreen (SCR-14)
    participant Backend as FastAPI Backend (/api/v1/market)
    participant DB as MongoDB (market_templates)

    Note over Studio,Backend: ⚠️ ĐIỂM GÃY TÍCH HỢP: Hardcode IP & Sai Route
    User->>Studio: Thiết kế giao diện E-ink -> Bấm "Đăng lên Chợ hiệu ứng"
    Studio->>Backend: POST http://192.168.1.18:8000/api/market/
    Backend-->>Studio: Lỗi kết nối / 404 Not Found
    
    User->>Market: Mở Chợ hiệu ứng
    Market->>Backend: GET /api/market/
    Backend-->>Market: HTTP 404 Not Found -> UI báo "Chợ hiện đang trống"
```

- **Phân loại trạng thái:** ❌ **Hỏng tích hợp & Bị cô lập (Broken Integration & Unreachable)**
- **Khắc phục yêu cầu:**
  1. Thêm nút truy cập "Chợ Hiệu Ứng" và "Thiết Kế Màn Hình" vào `HomeScreen`.
  2. Chuyển sang sử dụng [presentation/screens/market_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/market/presentation/screens/market_screen.dart) (Clean Architecture) đã dùng chuẩn `/api/v1/market`.
  3. Xóa bỏ IP hardcode `192.168.1.18:8000` trong `design_screen.dart`.

---

## 3. BẢNG PHÂN LOẠI TRẠNG THÁI TOÀN BỘ CÁC TÍNH NĂNG ỨNG DỤNG

| Tính Năng / Luồng Nghiệp Vụ | File Frontend | File Backend | Trạng Thái Phân Loại | Bằng Chứng Kỹ Thuật |
|---|---|---|---|---|
| **Đăng Ký & Đăng Nhập JWT** | `features/auth/login_screen.dart` | `api/v1/auth_router.py` | ✅ Implemented & Verified | Mã hóa bcrypt chuẩn, cấp JWT 7 ngày, lưu SharedPreferences an toàn |
| **Lấy Thông Tin Người Dùng Me** | `core/api/auth_api.dart` | `api/v1/auth_router.py` | ✅ Implemented & Verified | Endpoint `/me` giải mã Bearer token, trả về thông tin cá nhân |
| **Đồng Bộ Phiên Pomodoro ESP32** | `core/bluetooth/spp_service.dart` | `api/v1/pomodoro_router.py` | 🟡 Partially Implemented | Luồng BLE -> API -> DB hoạt động tốt; Số lần unlock điện thoại đang bị mock |
| **Gợi Ý Adaptive Pomodoro AI** | `features/ai_hub/ai_hub_screen.dart` | `api/v1/ai_router.py` | ✅ Implemented & Verified | Q-Learning Agent sinh chu kỳ dựa trên điểm tập trung và lịch sử |
| **Đo Lường Nguy Cơ Kiệt Sức** | `features/ai_hub/ai_hub_screen.dart` | `api/v1/ai_router.py` | ✅ Implemented & Verified | BurnoutDetector tính BRIX proxy dựa trên 15 ngày dữ liệu thực |
| **Huấn Luyện Viên AI Hôm Nay** | `features/ai_hub/ai_hub_screen.dart` | `api/v1/ai_router.py` | ✅ Implemented & Verified | Trả về lời khuyên kèm các chỉ số thống kê trung bình |
| **Trò Chuyện AI Coach Trực Tiếp** | `features/ai_hub/ai_assistant_screen.dart` | `api/v1/ai_router.py` | 🟡 Partially Implemented | Chat Gemini & Tool Calling hoạt động; Biểu đồ radar Digital Twin bị mock |
| **Sinh Lịch Trình Làm Việc AI** | `features/ai_hub/ai_assistant_screen.dart` | `api/v1/ai_router.py` | ✅ Implemented & Verified | Tool call tự động sinh `schedule_plan` và đồng bộ báo thức BLE |
| **Giám Sát Sức Khỏe Số Android** | `features/digital_wellbeing/wellbeing_screen.dart` | `api/v1/usage_router.py` | ✅ Implemented (Android) | Đọc `UsageStats` native, tính Focus Score, đồng bộ `daily_summaries` |
| **Đấu Trường Thi Đua Nhóm** | `features/competition/competition_screen.dart` | `api/v1/competition_router.py` | ✅ Implemented & Verified | Tạo phòng 6 ký tự, tính điểm PRS, bảng xếp hạng 4 mốc thời gian |
| **Đổi Giao Diện Mặt Đồng Hồ** | `features/clock_mode/clock_mode_screen.dart` | Firmware ESP32 | ✅ Implemented (BLE) | Gửi lệnh `SET_MODE` và `SET_THEME` qua BLE trực tiếp |
| **Đồng Bộ Giờ Thực RTC** | `features/general_settings/general_settings_screen.dart` | Bo mạch DS3231 | ✅ Implemented (BLE) | Hàm `ble.syncTime()` gửi lệnh `SET_TIME` qua BLE |
| **Cài Đặt Phần Cứng Nâng Cao** | `features/general_settings/general_settings_screen.dart` | Không | 🔶 Mocked / Hardcoded | 5 nút lưu cài đặt chỉ hiển thị SnackBar, không lưu dữ liệu |
| **Thời Khóa Biểu Tuần** | `features/schedule/weekly_schedule_screen.dart` | `api/v1/schedule_router.py` | ❌ Broken Integration | Lỗi HTTP 404 (sai endpoint) và lệch Schema dữ liệu |
| **Kiểm Tra & Cập Nhật Firmware** | `features/info/info_screen.dart` | `api/v1/firmware_router.py` | ❌ Broken Integration | Lỗi HTTP 404 (sai endpoint) và lệch tên trường `description` |
| **Studio Thiết Kế Màn Hình** | `features/design/design_screen.dart` | `api/v1/market_router.py` | ❌ Broken & Unreachable | Lỗi HTTP 404; hardcode IP; không có lối vào từ Trang Chủ |
| **Chợ Mẫu Giao Diện E-Ink** | `features/market/market_screen.dart` | `api/v1/market_router.py` | ❌ Broken & Unreachable | Lỗi HTTP 404; hardcode IP; không có lối vào từ Trang Chủ |
| **Quản Lý 9 Màn Hình Xoay Vòng** | `features/interfaces/interfaces_screen.dart` | Không | ⛔ Unreachable & Mocked | Màn hình bị cô lập; danh sách cứng trong RAM; nút lưu giả lập |
