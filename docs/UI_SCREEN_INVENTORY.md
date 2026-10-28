# BẢNG KIỂM KÊ TOÀN DIỆN MÀN HÌNH ỨNG DỤNG (UI SCREEN INVENTORY)
**Dự án:** Smart Pomodoro Watch × AI Productivity Ecosystem  
**Frontend Framework:** Flutter 3.x (Dart 3.11+)  
**Backend Framework:** FastAPI 2.0 (Python 3.11+)  
**Ngày kiểm toán:** 15/10/2026  
**Trạng thái kiểm toán:** Đã đối soát 100% mã nguồn thực tế

---

## 1. TỔNG QUAN HỆ THỐNG MÀN HÌNH

Hệ thống Frontend bao gồm tổng cộng **15 màn hình và giao diện con**:
- **13 routes chính** được khai báo tại [main.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/main.dart).
- **1 màn hình phụ (Sub-screen / Modal)**: `AIAssistantScreen` được mở qua nút nổi Floating Action Button tại [ai_hub_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/ai_hub/ai_hub_screen.dart).
- **1 màn hình song song (Clean Architecture)**: `presentation/screens/market_screen.dart` đã được cấu trúc nhưng chưa được đấu nối vào `main.dart`.
- **3 màn hình bị cô lập (Unreachable)**: Không có liên kết điều hướng từ [home_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/home/home_screen.dart) (`/interfaces`, `/design`, `/market`).

---

## 2. DANH MỤC CHI TIẾT TỪNG MÀN HÌNH

---

### SCR-01: Màn hình Đăng Nhập & Đăng Ký (Authentication Screen)
- **ID định danh:** `SCR-01-AUTH`
- **Tên màn hình:** Login / Register Screen (`LoginScreen`)
- **Tuyến đường (Route):** `/login`
- **Mục đích:** Xác thực người dùng, cấp phát JWT Bearer Token và khởi tạo hồ sơ người dùng cục bộ.
- **Tập tin nguồn:** [login_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/auth/login_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Mở tự động khi ứng dụng khởi chạy nếu chưa có token trong `SharedPreferences` (`ApiClient.hasToken() == false`). Không yêu cầu token.
- **Thành phần UI trực quan:**
  - Background hiệu ứng Gradient Blob phát sáng (`_GlowBlob`).
  - Logo biểu tượng đồng hồ + Tiêu đề "AI Watch - Productivity Ecosystem".
  - Tiêu đề chào mừng "Chào mừng trở lại!" và phụ đề.
  - Bộ chuyển Tab hai chế độ: `Đăng Nhập` (index 0) và `Đăng Ký` (index 1).
  - Trường `Tên hiển thị` (chỉ hiển thị ở tab Đăng Ký).
  - Trường `Email` (bàn phím email, tiền tố icon hòm thư).
  - Trường `Mật khẩu` (icon ổ khóa, nút bật/tắt ẩn hiện ký tự).
  - Khung thông báo lỗi viền đỏ khi server từ chối hoặc lỗi mạng.
  - Nút bấm Gradient dạng viên thuốc lớn ("Đăng Nhập" / "Tạo Tài Khoản").
  - Dòng text chú thích địa chỉ IP server ở chân trang.
- **Hành vi người dùng & Xử lý sự kiện:**
  - Chuyển tab Đăng Nhập / Đăng Ký -> chuyển đổi FormState.
  - Bấm nút con mắt -> ẩn/hiện mật khẩu (`_obscure = !_obscure`).
  - Bấm Submit (`_submit`): Kiểm tra validate Form -> hiển thị `CircularProgressIndicator` -> Gọi `AuthApi.login` hoặc `AuthApi.register` -> Lưu session -> Điều hướng `pushReplacementNamed("/")`.
- **Quy tắc kiểm tra (Validation):**
  - Tên hiển thị: Tối thiểu 2 ký tự.
  - Email: Phải chứa ký tự `@`.
  - Mật khẩu: Tối thiểu 6 ký tự.
- **Dữ liệu hiển thị & Nguồn gốc:** Dữ liệu tĩnh và phản hồi từ Backend (`access_token`, `user.id`, `user.display_name`, `user.email`).
- **Các trạng thái giao diện:**
  - *Loading:* Nút submit chuyển thành vòng quay tròn trắng.
  - *Error:* Xuất hiện box đỏ hiển thị chuỗi lỗi từ Backend `ApiException.message` hoặc lỗi mất kết nối.
  - *Success:* Tự động đóng màn hình và chuyển vào `HomeScreen`.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `POST /api/v1/auth/login`
  - `POST /api/v1/auth/register`
- **Trạng thái thực tế:** **ĐÃ HOÀN THÀNH (Implemented)**
- **Khiếm khuyết phát hiện:**
  - Dòng chú thích chân trang đang hardcode IP cũ: `http://192.168.1.18:8000` (dòng 206), không đồng bộ với cấu hình động trong [app_constants.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/constants/app_constants.dart).
  - Chưa có tính năng "Quên mật khẩu" hay "Khôi phục mật khẩu".

---

### SCR-02: Màn hình Trang Chủ (Home Dashboard)
- **ID định danh:** `SCR-02-HOME`
- **Tên màn hình:** Home Screen (`HomeScreen`)
- **Tuyến đường (Route):** `/`
- **Mục đích:** Trung tâm điều hướng chính, hiển thị trạng thái kết nối phần cứng Bluetooth ESP32 và các nhóm chức năng của hệ sinh thái.
- **Tập tin nguồn:** [home_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/home/home_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập (tồn tại `jwt_token`).
- **Thành phần UI trực quan:**
  - AppBar trong suốt với tiêu đề "Trang Chủ", nút Logout màu đỏ.
  - Thẻ trạng thái kết nối Bluetooth (`_ConnectionCard`):
    - Đổi màu xanh lá khi kết nối, màu đỏ nhạt khi ngắt kết nối.
    - Icon Bluetooth pulse animation.
    - Tên thiết bị (mặc định "Eink Clock" hoặc tên ESP32) và dòng hướng dẫn.
    - Nút bấm "Quét / Scan" hoặc "Ngắt kết nối".
  - Nhóm 1: `NĂNG SUẤT & HỌC TẬP`
    - Mục "Pomodoro AI" (Icon cam) -> `/pomodoro`
    - Mục "Thi Đua Năng Suất" (Icon vàng) -> `/competition`
    - Mục "Lịch Nhắc Nhở" (Icon xanh teal) -> `/schedule`
  - Nhóm 2: `TRỢ LÝ THÔNG MINH`
    - Mục "AI Hub & Coach" (Icon chàm) -> `/ai-hub`
    - Mục "Digital Wellbeing" (Icon hồng) -> `/wellbeing`
    - Mục "Chế độ đồng hồ" (Icon xanh da trời) -> `/clock_mode`
  - Nhóm 3: `HỆ THỐNG CỦA THIẾT BỊ`
    - Mục "Cài Đặt Chung" (Icon xám xanh) -> `/settings`
    - Mục "Cập nhật Firmware" (Icon xanh lá) -> `/info`
- **Hành vi người dùng & Xử lý sự kiện:**
  - Bấm nút Logout: Gọi `AuthApi.logout()` (xóa token) -> `Navigator.pushNamedAndRemoveUntil('/login')`.
  - Bấm "Quét / Scan": Gọi `BleService.startScan()` quét tìm thiết bị có tên chứa `ESP32_Pomodoro` hoặc `Eink`.
  - Bấm "Ngắt kết nối": Gọi `BleService.disconnect()`.
  - Bấm vào từng dòng menu: Điều hướng sang route tương ứng.
- **Yêu cầu API & Phụ thuộc Backend:**
  - Trực tiếp: Không gọi API HTTP trực tiếp (dùng `BleService` và `AuthApi.logout`).
- **Trạng thái thực tế:** **ĐÃ HOÀN THÀNH (Implemented)**
- **Khiếm khuyết phát hiện:**
  - Ba màn hình quan trọng trong dự án gồm `InterfacesScreen` (`/interfaces`), `DesignScreen` (`/design`), và `MarketScreen` (`/market`) hoàn toàn không có nút mở trên giao diện `HomeScreen`. Người dùng không thể truy cập nếu không đổi code hoặc gõ thủ công.

---

### SCR-03: Màn hình Pomodoro Đồng Bộ Phần Cứng (Pomodoro Sync Screen)
- **ID định danh:** `SCR-03-POMO`
- **Tên màn hình:** Pomodoro Screen (`PomodoroScreen`)
- **Tuyến đường (Route):** `/pomodoro`
- **Mục đích:** Giám sát trạng thái kết nối Bluetooth SPP với ESP32, nhận gói tin JSON phiên Pomodoro hoàn thành từ phần cứng, hiển thị kết quả và nhận phản hồi đánh giá thông minh từ AI.
- **Tập tin nguồn:** [pomodoro_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/pomodoro/pomodoro_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập, cấp quyền Bluetooth & Vị trí.
- **Thành phần UI trực quan:**
  - AppBar tiêu đề "Pomodoro ESP32".
  - Thẻ kết nối SPP (`_buildConnectionCard`):
    - Icon Bluetooth với hiệu ứng nảy xung nhịp khi đang quét.
    - Dòng trạng thái (Chưa kết nối / Đang tìm... / Đã kết nối).
    - Nút bấm "Kết nối ESP32" / "Ngắt kết nối".
    - Hộp hướng dẫn ghép đôi SPP trong cài đặt hệ điều hành.
  - Thẻ thông tin phiên gần nhất (`_buildSessionCard`):
    - Badge trạng thái: `✓ Hoàn thành` (xanh) hoặc `⚠ Dừng sớm` (đỏ).
    - Thời gian làm việc (phút), thời gian nghỉ (phút).
    - Số lần tạm dừng (pauses), phiên số mấy (#session), thời điểm nhận dữ liệu.
  - Thẻ AI Phân Tích (`_buildFeedbackCard`):
    - Tiêu đề kèm icon bộ não.
    - Spinner "Đang phân tích..." khi đang gọi API Backend.
    - Nội dung lời nhận xét từ AI Feedback Engine Backend.
- **Hành vi người dùng & Xử lý sự kiện:**
  - Bấm "Kết nối ESP32": `spp.connectToEsp32()`.
  - Bấm "Ngắt kết nối": `spp.disconnect()`.
  - Tự động nhận stream byte từ ESP32 qua BLE -> `SppService._handleJsonPayload` -> parse `PomodoroSessionData` -> gọi API `_syncToBackend`.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `POST /api/v1/pomodoro/sync`: Gửi payload gồm `hardware_data` + `phone_data`. Yêu cầu Bearer token.
  - Endpoint `GET /api/v1/pomodoro/history/{user_id}` tồn tại trên Backend nhưng màn hình này **chưa có UI danh sách lịch sử** để hiển thị.
- **Trạng thái thực tế:** **MỘT PHẦN (Partial)**
- **Khiếm khuyết phát hiện:**
  - Màn hình chỉ hoạt động thụ động: đợi đồng hồ gửi tin lên, không có nút bấm bắt đầu/hủy phiên Pomodoro trực tiếp trên điện thoại.
  - Số lần mở khóa điện thoại `unlock_count` trong [spp_service.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/core/bluetooth/spp_service.dart) dòng 164 đang bị mock tính theo số lần pause: `(session.pauses * 1.5).round()`.
  - Chưa tận dụng API lấy lịch sử phiên (`/history/{user_id}`).

---

### SCR-04: Trung Tâm AI Năng Suất (AI Productivity Hub)
- **ID định danh:** `SCR-04-AIHUB`
- **Tên màn hình:** AI Hub Screen (`AiHubScreen`)
- **Tuyến đường (Route):** `/ai-hub`
- **Mục đích:** Trung tâm tổng hợp các dịch vụ phân tích AI: Gợi ý chu kỳ Pomodoro thích ứng theo Q-Learning, Đánh giá rủi ro kiệt sức (Burnout Risk BRIX), Lời khuyên huấn luyện viên hàng ngày, và Tổng hợp thời tiết - ngữ cảnh.
- **Tập tin nguồn:** [ai_hub_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/ai_hub/ai_hub_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập (Bearer token hợp lệ).
- **Thành phần UI trực quan:**
  - SliverAppBar với tiêu đề "AI Productivity Hub", lời chào cá nhân hóa "Xin chào, {Tên}!", nút Refresh góc phải.
  - Thẻ Thời tiết & Ngữ cảnh (`_ContextCard`):
    - Nhiệt độ hiện tại, icon thời tiết, mô tả tình trạng khí hậu, độ ẩm.
    - Hộp lời khuyên năng suất tương ứng với thời tiết.
  - Khối Adaptive Pomodoro:
    - Thanh trượt điều chỉnh Điểm tập trung hiện tại (0 - 100).
    - Bộ chọn loại công việc (Task Type): `Chung`, `Code`, `Đọc`, `Họp`.
    - Nút bấm "Lấy Gợi Ý AI".
    - Thẻ kết quả gợi ý (`_RecommendationCard`): Thời lượng làm việc (phút), thời lượng nghỉ (phút), độ tự tin (%), lý do giải thích từ thuật toán Reinforcement Learning.
  - Thẻ Huấn luyện viên AI hôm nay (`_CoachCard`):
    - Badge trạng thái "Cá Nhân Hóa" hoặc "Tổng Quát".
    - Lời khuyên chi tiết và các chỉ số thống kê (Tập trung TB, Bỏ qua break, Hoàn thành).
  - Thẻ Đo lường Nguy cơ Kiệt sức (`_BurnoutCard`):
    - Đồng hồ đo tiến trình tròn (0 - 100), mã màu động (Xanh lá -> Vàng -> Cam -> Đỏ).
    - Cảnh báo mức độ: THẤP / TRUNG BÌNH / CAO / NGUY HIỂM.
    - Lời khuyên an toàn sức khỏe và danh sách các dấu hiệu phát hiện từ dữ liệu 15 ngày.
  - Nút nổi mở Chatbot: `FloatingActionButton.extended` với nhãn "Live AI Coach".
- **Hành vi người dùng & Xử lý sự kiện:**
  - Kéo thanh trượt điểm tập trung -> cập nhật `_concScore`.
  - Chọn chip loại task -> cập nhật `_taskType`.
  - Bấm "Lấy Gợi Ý AI" hoặc nút Refresh trên AppBar -> Gọi song song 4 API qua `Future.wait`.
  - Bấm nút nổi "Live AI Coach" -> Điều hướng sang `AIAssistantScreen`.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `GET /api/v1/ai/pomodoro/recommend` (Query: `concentration_score`, `task_type`)
  - `GET /api/v1/ai/burnout/risk`
  - `GET /api/v1/ai/coach/daily-advice`
  - `GET /api/v1/context/today` (Query: `lat`, `lon`)
  - `GET /api/v1/auth/me`
- **Trạng thái thực tế:** **ĐÃ HOÀN THÀNH (Implemented)**
- **Khiếm khuyết phát hiện:** Tọa độ GPS đang gán mặc định TP.HCM (`lat=10.762622, lon=106.660172`), chưa lấy tọa độ GPS thực tế từ cảm biến điện thoại.

---

### SCR-05: Trợ Lý Trực Tiếp & Lịch Trình Thông Minh (Live AI Coach & Assistant)
- **ID định danh:** `SCR-05-COACH`
- **Tên màn hình:** AI Assistant Screen (`AIAssistantScreen`)
- **Tuyến đường (Route):** Mở dạng modal route từ `AiHubScreen`
- **Mục đích:** Trò chuyện ngữ cảnh trực tiếp với AI Coach (Gemini/OpenAI), tự động gọi công cụ (Tool Calling: đặt chu kỳ Pomodoro, đặt báo thức, gửi thông báo), sinh lịch trình làm việc thông minh và chấm điểm biểu đồ số Digital Twin.
- **Tập tin nguồn:** [ai_assistant_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/ai_hub/ai_assistant_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập, có kết nối mạng tới Backend.
- **Thành phần UI trực quan:**
  - AppBar: Tiêu đề "AI Coach & Digital Twin", nhãn trạng thái kết nối phần cứng đồng hồ, nút kết nối nhanh BLE.
  - Bảng biểu đồ Digital Twin (`DigitalTwinDashboard`):
    - RadarChart 4 trục: Focus, Stress, Break, Efficiency.
    - Thanh đo tiến trình Burnout Risk và phân loại HIGH / NORMAL.
  - Danh sách tin nhắn trò chuyện (User bóng tím xanh góc phải, AI bóng tối có viền góc trái).
  - Chip hiển thị công cụ phần cứng đã thực thi (`SET_POMO`, `SET_ALARM`, `SHOW_NOTIF`).
  - Thẻ Lịch Trình Thông Minh (`_ScheduleCard`):
    - Huy hiệu điểm số chất lượng (Grade: A+, A, B, C...) và nhận xét.
    - Thống kê tổng phút làm, phút nghỉ, số phiên.
    - Dòng thời gian Timeline biểu diễn từng block công việc có icon chuyên biệt.
    - Hộp cảnh báo an toàn kiệt sức.
    - Các nút hành động: "Sync Đồng Hồ", "Bắt đầu ngay", "Lưu lịch trình".
  - Thanh nhập lệnh Prompt ở đáy màn hình kèm nút Send.
- **Hành vi người dùng & Xử lý sự kiện:**
  - Nhập prompt (ví dụ: "Lên lịch làm việc ngày mai", "Tôi mệt quá") -> gửi tới Backend.
  - Nhận phản hồi AI -> tự động phân tích Tool Calls -> gửi lệnh JSON xuống ESP32 qua BLE.
  - Bấm "Sync Đồng Hồ" trên lịch trình: Duyệt từng block làm việc -> gửi lệnh `SET_ALARM` qua BLE xuống ESP32.
  - Bấm "Bắt đầu ngay": Gửi lệnh `SET_POMO` phiên đầu tiên xuống đồng hồ.
  - Bấm "Lưu lịch trình": Gửi dữ liệu lên API `POST /api/v1/ai/schedule/save`.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `POST /api/v1/ai/coach/chat` (Payload: `user_prompt`, `watch_connected`)
  - `POST /api/v1/ai/schedule/save`
- **Trạng thái thực tế:** **MỘT PHẦN (Partial)**
- **Khiếm khuyết phát hiện:**
  - Thành phần [digital_twin_dashboard.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/ai_hub/digital_twin_dashboard.dart) đang được gọi với `const DigitalTwinDashboard()`, sử dụng 100% dữ liệu giả lập mặc định (Focus 82, Stress 40, Break 75, Efficiency 80, Burnout 25%), không nhận dữ liệu Digital Twin thực tế từ Backend.
  - Khi mở màn hình, ứng dụng không gọi `GET /api/v1/ai/schedule/latest` để khôi phục lịch trình đã tạo trước đó.

---

### SCR-06: Sức Khỏe Số & Giám Sát Điện Thoại (Digital Wellbeing)
- **ID định danh:** `SCR-06-WELLBEING`
- **Tên màn hình:** Wellbeing Screen (`WellbeingScreen`)
- **Tuyến đường (Route):** `/wellbeing`
- **Mục đích:** Theo dõi thời gian sử dụng điện thoại, phát hiện xao nhãng mở app mạng xã hội trong phiên Pomodoro, tính toán điểm tập trung Focus Score và đồng bộ lên AI Backend.
- **Tập tin nguồn:** [wellbeing_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/digital_wellbeing/wellbeing_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Quyền truy cập dữ liệu sử dụng hệ thống Android (`Usage Access Permission`).
- **Thành phần UI trực quan:**
  - *Khi chưa cấp quyền:* Giao diện giải thích minh bạch chính sách bảo mật (các dữ liệu thu thập & KHÔNG thu thập) kèm nút "Đồng ý & Bật theo dõi".
  - *Khi đã cấp quyền:*
    - Vòng tròn động Focus Score (0 - 100) kèm danh hiệu đánh giá.
    - Ba thẻ số liệu chính: Tổng thời gian màn hình (Screen Time), Số lần mở khóa (Unlocks), Số lần mất tập trung (Mất TT).
    - Thẻ Top ứng dụng dùng nhiều nhất trong ngày kèm thanh tiến độ màu theo danh mục (Productivity, Social, Games...).
    - Biểu đồ tròn FlChart PieChart phân bổ tỷ lệ phần trăm các nhóm ứng dụng.
    - Thẻ AI Insight phân tích thói quen và đưa ra khuyến nghị giảm thời gian mạng xã hội.
- **Hành vi người dùng & Xử lý sự kiện:**
  - Bấm yêu cầu cấp quyền -> Mở cài đặt hệ thống Android qua Platform Channel.
  - Kéo vuốt để tải lại (Pull-to-refresh) -> Truy vấn `UsageStats` native và tự động đồng bộ lên Backend.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `POST /api/v1/usage/daily-summary` (Gửi tổng hợp ngày)
- **Trạng thái thực tế:** **ĐÃ HOÀN THÀNH TRÊN ANDROID (Implemented)**
- **Khiếm khuyết phát hiện:**
  - Các API chi tiết đã viết trên Backend gồm `POST /api/v1/usage/events` (upload batch event chi tiết), `GET /api/v1/usage/analytics`, và `GET /api/v1/usage/distractions` chưa được màn hình này khai thác.
  - Trên nền tảng Web hoặc iOS không hỗ trợ API hệ thống Android nên hiển thị trạng thái chưa có dữ liệu.

---

### SCR-07: Đấu Trường Năng Suất & Thi Đua Nhóm (Productivity Competition)
- **ID định danh:** `SCR-07-COMPETITION`
- **Tên màn hình:** Competition Screen (`CompetitionScreen`)
- **Tuyến đường (Route):** `/competition`
- **Mục đích:** Cho phép người dùng tạo nhóm thi đua, tham gia phòng qua mã số (6 ký tự), thi đấu tích điểm PRS từ các phiên Pomodoro và xem Bảng xếp hạng trực tiếp.
- **Tập tin nguồn:** [competition_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/competition/competition_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập.
- **Thành phần UI trực quan:**
  - *Giao diện sảnh chờ (Lobby):*
    - Biểu tượng cúp vàng lớn và tiêu đề "Thi Đua Làm Việc".
    - Trường nhập Tên hiển thị người dùng.
    - Khối Tạo Phòng: Nhập tên phòng thi đua, chọn thời hạn (7 ngày / 30 ngày), nút "Tạo Phòng Mới".
    - Khối Tham Gia: Nhập mã phòng 6 chữ số, nút "Vào Phòng".
  - *Giao diện đấu trường (Arena):*
    - Header phòng thi đua màu vàng: Tên phòng, Mã phòng lớn, thời hạn và cảnh báo khi hết hạn.
    - Các nút: "Làm mới", "Test Cộng Điểm" (mô phỏng nộp phiên 25 phút).
    - Bộ lọc thời gian: "Hôm nay", "Tuần này", "Tháng này", "Tất cả".
    - Danh sách Bảng xếp hạng (Leaderboard): Huy chương Vàng, Bạc, Đồng cho Top 3, điểm số PRS, tổng số phút học, tổng số phiên hoàn thành.
    - Nút "Quay lại sảnh chờ".
- **Hành vi người dùng & Xử lý sự kiện:**
  - Nhập thông tin và tạo phòng -> Nhận mã phòng -> Tự động tham gia.
  - Nhập mã phòng và tham gia -> Load bảng xếp hạng.
  - Bấm chọn các tab thời gian -> Lọc bảng xếp hạng tương ứng.
  - Bấm "Test Cộng Điểm" -> Gửi request tính điểm PRS lên Backend.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `POST /api/v1/competition/groups`
  - `POST /api/v1/competition/groups/join`
  - `GET /api/v1/competition/leaderboard/{room_code}`
  - `POST /api/v1/competition/submit`
- **Trạng thái thực tế:** **ĐÃ HOÀN THÀNH (Implemented)**
- **Khiếm khuyết phát hiện:**
  - Màn hình sử dụng thư viện `http` trực tiếp, không sử dụng class trung tâm `ApiClient`, không tự động đính kèm JWT Bearer Token.
  - Tên người dùng `_userIdController` đang để mặc định cứng là `"user_bao"` thay vì tự động lấy mã ID người dùng đăng nhập từ `AuthApi.getUserId()`.

---

### SCR-08: Lịch Nhắc Nhở Tuần (Weekly Schedule Screen)
- **ID định danh:** `SCR-08-SCHEDULE`
- **Tên màn hình:** Weekly Schedule Screen (`WeeklyScheduleScreen`)
- **Tuyến đường (Route):** `/schedule`
- **Mục đích:** Quản lý thời khóa biểu 7 ngày trong tuần, cấu hình ghi chú và khung giờ hiển thị để đồng bộ xuống màn hình đồng hồ E-ink.
- **Tập tin nguồn:** [weekly_schedule_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/schedule/weekly_schedule_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập.
- **Thành phần UI trực quan:**
  - Banner hướng dẫn trên cùng màu vàng cam.
  - Danh sách thẻ 7 ngày (Thứ Hai đến Chủ Nhật):
    - Huy hiệu màu riêng biệt cho từng thứ trong tuần (T2, T3... CN).
    - Huy hiệu nổi bật "Hôm nay" đối với ngày hiện tại.
    - Dòng xem trước nội dung ghi chú.
    - Công tắc bật/tắt (Switch).
    - Khối mở rộng: Ô nhập ghi chú (tối đa 120 ký tự), Bộ chọn Slot hiển thị (Slot 1 đến 5), Bộ chọn thời gian hiển thị (TimePicker).
  - Nút bấm cố định dưới chân: "Lưu & Đồng bộ lên đồng hồ".
- **Hành vi người dùng & Xử lý sự kiện:**
  - Chạm vào thẻ ngày -> đóng/mở khối chi tiết.
  - Bật/tắt công tắc -> kích hoạt hoặc vô hiệu hóa lịch nhắc.
  - Nhập ghi chú, chọn slot, chọn giờ hiển thị.
  - Bấm nút Lưu: Duyệt danh sách các ngày được bật -> Gửi request đồng bộ lên máy chủ.
- **Yêu cầu API & Phụ thuộc Backend:**
  - Khởi tạo: `GET /api/schedules/`
  - Đồng bộ: `POST /api/schedules/`
- **Trạng thái thực tế:** **HỎNG KẾT NỐI (Broken Integration)**
- **Bằng chứng khiếm khuyết:**
  - **Sai đường dẫn Endpoint:** Dòng 59 và dòng 105 đang gọi `${AppConstants.baseUrl}/api/schedules/`. Trong khi Backend [main.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/main.py) khai báo router với prefix chuẩn là `/api/v1/schedules`. Do đó mọi request từ màn hình này đều nhận mã lỗi `404 Not Found`.
  - **Lệch cấu trúc dữ liệu (Schema Mismatch):** Frontend gửi `{user_id, title, time, days_of_week, is_active}`, trong khi Backend [schedule_router.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/api/v1/schedule_router.py) lại yêu cầu `{day_of_week, hour, minute, label, is_active}`.

---

### SCR-09: Bộ Sưu Tập Giao Diện Đồng Hồ (Clock Mode & Themes)
- **ID định danh:** `SCR-09-CLOCKMODE`
- **Tên màn hình:** Clock Mode Screen (`ClockModeScreen`)
- **Tuyến đường (Route):** `/clock_mode`
- **Mục đích:** Cung cấp bộ sưu tập các mặt hiển thị đồng hồ (Flip Clock, Cyberpunk Neon, Sunset Minimal, Pomodoro Ring, Hourglass, Sand Timer...) và truyền lệnh BLE để thay đổi giao diện trên màn hình phần cứng.
- **Tập tin nguồn:** [clock_mode_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/clock_mode/clock_mode_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Kết nối Bluetooth với ESP32.
- **Thành phần UI trực quan:**
  - AppBar tiêu đề kèm đèn báo kết nối BLE.
  - Khung xem trước thời gian thực (`_LivePreview`): Mô phỏng trung thực tỉ lệ màn hình đồng hồ với chuyển động kim giây, đồng hồ lật hoặc hoạt họa cát chảy.
  - Bộ sưu tập chia theo nhóm: `Đồng Hồ`, `Pomodoro`, `Đếm Ngược`.
  - Lưới hiển thị các thẻ chủ đề (Theme Cards).
  - Thanh dưới cùng: Tên giao diện đang chọn và nút "Áp dụng lên đồng hồ".
- **Hành vi người dùng & Xử lý sự kiện:**
  - Chọn thẻ chủ đề -> Cập nhật màn hình xem trước thời gian thực.
  - Bấm "Áp dụng":
    - Gửi lệnh BLE `SET_MODE` kèm mã chế độ (0=Clock, 1=Pomodoro, 2=Timer).
    - Gửi lệnh BLE `SET_THEME` kèm mã theme, mã màu hex RRGGBB và cờ hoạt họa.
    - Lưu mã theme đã chọn vào `SharedPreferences` (`clock_theme_id`).
- **Yêu cầu API & Phụ thuộc Backend:** Không gọi Backend API (chỉ giao tiếp BLE trực tiếp với ESP32 và lưu SharedPreferences).
- **Trạng thái thực tế:** **ĐÃ HOÀN THÀNH (Implemented)**

---

### SCR-10: Cài Đặt Hệ Thống Thiết Bị (General Settings)
- **ID định danh:** `SCR-10-SETTINGS`
- **Tên màn hình:** General Settings Screen (`GeneralSettingsScreen`)
- **Tuyến đường (Route):** `/settings`
- **Mục đích:** Cấu hình các thông số vận hành phần cứng: đồng bộ giờ RTC, hiệu chỉnh sai số thạch anh, hẹn giờ tiết kiệm pin (Deep Sleep), đặt báo thức phần cứng và khôi phục cài đặt gốc.
- **Tập tin nguồn:** [general_settings_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/general_settings/general_settings_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Kết nối Bluetooth BLE.
- **Thành phần UI trực quan:**
  - Thẻ `Set time`: Đồng hồ điện tử chạy live, nút "Lưu thời gian".
  - Thẻ `Hiệu chỉnh thời gian`: Dropdown chọn chế độ hiệu chỉnh nhanh/chậm, ô nhập chu kỳ giờ, nút "Lưu thiết lập".
  - Thẻ `Tiết kiệm pin`: Hai dòng chọn giờ bắt đầu/kết thúc ngủ, nút "Lưu chế độ ngủ".
  - Thẻ `Báo thức`: Chọn giờ báo thức, nút "Lưu báo thức", sơ đồ nối dây loa chíp trên bo mạch.
  - Thẻ `Dữ liệu đếm ngược`: Đếm lùi/đếm tiến số ngày, nút "Lưu thiết lập".
  - Thẻ `Khôi phục cài đặt gốc`: Nút đỏ "Khôi phục ngay" và hộp thoại Dialog xác nhận.
- **Hành vi người dùng & Xử lý sự kiện:**
  - Bấm "Lưu thời gian": Gọi `ble.syncTime()` gửi lệnh BLE `SET_TIME` xuống ESP32.
  - Bấm các nút Lưu khác: Chỉ hiện SnackBar thông báo cục bộ.
- **Yêu cầu API & Phụ thuộc Backend:** Không gọi Backend API.
- **Trạng thái thực tế:** **MỘT PHẦN / GIẢ LẬP (Partial / Mocked)**
- **Bằng chứng khiếm khuyết:** Ngoài nút "Lưu thời gian" thực sự gửi lệnh Bluetooth, tất cả 5 nút lưu còn lại (Hiệu chỉnh, Ngủ, Báo thức, Đếm ngược, Khôi phục gốc) đều chỉ hiển thị `showSuccessSnackbar` giả lập, chưa gửi lệnh BLE xuống phần cứng cũng như không lưu cấu hình lên Backend API `PUT /api/v1/auth/me/preferences`.

---

### SCR-11: Thông Tin Thiết Bị & Cập Nhật Firmware (Device Info & OTA)
- **ID định danh:** `SCR-11-INFO`
- **Tên màn hình:** Info Screen (`InfoScreen`)
- **Tuyến đường (Route):** `/info`
- **Mục đích:** Hiển thị thông số kỹ thuật của đồng hồ E-ink, kiểm tra phiên bản Firmware mới trên server và cung cấp tính năng nâng cấp OTA qua WiFi.
- **Tập tin nguồn:** [info_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/info/info_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập.
- **Thành phần UI trực quan:**
  - Header Gradient màu tím: Icon đồng hồ, phiên bản ứng dụng V123, ngày cập nhật.
  - Thẻ thông báo cập nhật Firmware (`_FirmwareUpdateCard`):
    - Hiện phiên bản mới nhất và nội dung cập nhật.
    - Nút bấm màu xanh: "Cập nhật Firmware qua WiFi".
  - Thẻ "Thiết bị E-Ink": Danh sách đặc tính phần cứng.
  - Thẻ "Tính năng ứng dụng": Mô tả năng lực thiết kế và kết nối.
  - Thẻ bản quyền chân trang.
- **Hành vi người dùng & Xử lý sự kiện:**
  - Khi mở màn hình: Gọi HTTP GET kiểm tra bản firmware mới.
  - Bấm "Cập nhật Firmware qua WiFi": Hiện SnackBar "Đang gửi lệnh cập nhật OTA...".
- **Yêu cầu API & Phụ thuộc Backend:**
  - `GET /api/firmware/latest`
- **Trạng thái thực tế:** **HỎNG KẾT NỐI (Broken Integration)**
- **Bằng chứng khiếm khuyết:**
  - **Sai đường dẫn Endpoint:** Dòng 273 gọi `${AppConstants.baseUrl}/api/firmware/latest`. Trong khi Backend [main.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/main.py) định tuyến tại `/api/v1/firmware/latest`. Kết quả trả về lỗi `404 Not Found`.
  - **Lệch trường dữ liệu:** Frontend đọc `data['description']`, trong khi Backend Entity [firmware_entity.py](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Backend_EXE401/domain/entities/firmware_entity.py) định nghĩa trường nội dung là `changelog`.
  - Nút bấm cập nhật OTA chưa thực thi gửi lệnh BLE kích hoạt WiFi trên ESP32.

---

### SCR-12: Quản Lý Các Màn Hình Hiển Thị (Interfaces Screen)
- **ID định danh:** `SCR-12-INTERFACES`
- **Tên màn hình:** Interfaces Screen (`InterfacesScreen`)
- **Tuyến đường (Route):** `/interfaces`
- **Mục đích:** Cấu hình thời gian luân chuyển giữa 5 giao diện mặc định của nhà sản xuất và 4 giao diện tự thiết kế trên đồng hồ E-ink.
- **Tập tin nguồn:** [interfaces_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/interfaces/interfaces_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập.
- **Thành phần UI trực quan:**
  - AppBar tiêu đề "Các giao diện", icon download trên thanh tác vụ.
  - Dòng text mô tả nguyên lý xoay vòng giao diện.
  - Danh sách 9 thẻ giao diện (5 mặc định nền xanh, 4 slot tự thiết kế nền xám).
  - Mỗi thẻ gồm: Tên giao diện, checkbox kích hoạt, thanh trượt Slider chọn thời gian hiển thị từ 0 đến 30 phút.
  - Nút bấm dưới chân: "Lưu cài đặt".
- **Hành vi người dùng & Xử lý sự kiện:**
  - Check/uncheck giao diện.
  - Kéo thanh trượt thời gian.
  - Bấm "Lưu cài đặt": Hiện SnackBar thông báo.
- **Yêu cầu API & Phụ thuộc Backend:** Không kết nối Backend.
- **Trạng thái thực tế:** **BỊ CÔ LẬP / CHƯA ĐẤU NỐI (Unreachable / Mocked)**
- **Bằng chứng khiếm khuyết:**
  - Màn hình này không có nút bấm điều hướng từ `HomeScreen`.
  - Dữ liệu 9 giao diện là danh sách cứng trong bộ nhớ RAM của widget.
  - Nút "Lưu cài đặt" chỉ hiển thị SnackBar, chưa gửi lệnh BLE xuống đồng hồ và chưa lưu vào database.

---

### SCR-13: Thiết Kế Màn Hình E-Ink 212x104 (Design Studio Screen)
- **ID định danh:** `SCR-13-DESIGN`
- **Tên màn hình:** Design Screen (`DesignScreen`)
- **Tuyến đường (Route):** `/design`
- **Mục đích:** Bộ công cụ đồ họa trực quan (Studio) cho phép người dùng tự vẽ giao diện đồng hồ E-ink: kéo thả đồng hồ, văn bản động, hình học, ảnh bitmap, lịch tháng và siêu văn bản, sau đó lưu cục bộ hoặc upload lên Chợ hiệu ứng.
- **Tập tin nguồn:** [design_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/design/design_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Không yêu cầu quyền đặc biệt.
- **Thành phần UI trực quan:**
  - AppBar với các nút: Quay lại, Đăng lên Chợ hiệu ứng, Lưu cục bộ.
  - Vùng Canvas 212x104 px (màu kem E-ink, có thể xoay dọc 104x212 px).
  - Thanh công cụ đối tượng (`_ObjectStrip`): Các icon đối tượng đang có trên canvas, nút Xóa, nút Thêm (+), nút Cài đặt chung (bánh răng).
  - BottomSheet "Thêm đối tượng": Đồng hồ, Văn bản, Hình học, Hình ảnh, Lịch, Siêu văn bản.
  - Bảng điều khiển thuộc tính (`_PropertiesPanel`): Cỡ chữ, nội dung macro (`@h:@m`, `@d/@M/@y`), đảo màu (Invert), độ dày nét, hình tròn/chữ nhật.
  - Cụm điều hướng 4 hướng (`_DPad`): Lên, Xuống, Trái, Phải để di chuyển đối tượng từng pixel.
  - Bảng thao tác tệp (`_FileOperationsPanel`): Bật/tắt khung bao, Xoay hướng màn hình, Lưu vào điện thoại, Nạp từ điện thoại, Đổi kích thước màn hình E-ink (2.13" 212x104, 2.13" 250x122, 4.2" 400x300).
- **Hành vi người dùng & Xử lý sự kiện:**
  - Thêm, xóa, di chuyển, chỉnh sửa thuộc tính các phần tử canvas.
  - Bấm "Lưu cục bộ": Lưu chuỗi JSON vào `SharedPreferences` key `saved_design`.
  - Bấm "Nạp từ điện thoại": Đọc JSON từ `saved_design` vẽ lại lên canvas.
  - Bấm "Đăng lên Chợ hiệu ứng": Gọi API POST gửi template lên server.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `POST /api/market/`
- **Trạng thái thực tế:** **BỊ CÔ LẬP & LỆCH API (Unreachable & Broken API)**
- **Bằng chứng khiếm khuyết:**
  - Không có liên kết trực tiếp từ `HomeScreen` (chỉ mở được khi bấm vào thẻ trong `MarketScreen`).
  - **Hardcode IP và sai URL:** Dòng 171 gán cứng `http://192.168.1.18:8000` trên Android và gọi endpoint `/api/market/` thay vì `/api/v1/market/`, dẫn tới request thất bại.

---

### SCR-14: Chợ Hiệu Ứng E-Ink Cộng Đồng (Marketplace Screen - Active)
- **ID định danh:** `SCR-14-MARKET`
- **Tên màn hình:** Market Screen (`MarketScreen` - monolithic)
- **Tuyến đường (Route):** `/market`
- **Mục đích:** Duyệt và tải các mẫu thiết kế màn hình E-ink do cộng đồng người dùng chia sẻ, chọn mẫu để mở sang màn hình thiết kế hoặc tự tải mẫu của mình lên.
- **Tập tin nguồn:** [market_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/market/market_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập.
- **Thành phần UI trực quan:**
  - AppBar tiêu đề "Chợ hiệu ứng".
  - Banner chia sẻ trên cùng (`_UploadBanner`): Nút "Upload" và nút "Hoặc chọn file từ máy để upload".
  - Lưới giao diện cộng đồng 2 cột (`GridView`): Hiển thị hình ảnh mô phỏng màn E-ink, tên tác giả, thời gian tải lên.
  - Nút bấm "Tải thêm hiệu ứng".
- **Hành vi người dùng & Xử lý sự kiện:**
  - Khi mở màn hình: Tự động gọi API lấy danh sách template.
  - Chạm vào một mẫu thẻ: Điều hướng sang `/design` kèm tham số `preview`.
  - Bấm "Upload": Gửi mẫu thiết kế mẫu lên server.
  - Bấm "Chọn file": Mở bộ chọn ảnh ImagePicker.
  - Bấm "Tải thêm hiệu ứng": Tạo dữ liệu giả lập thêm 10 phần tử vào danh sách.
- **Yêu cầu API & Phụ thuộc Backend:**
  - `GET /api/market/`
  - `POST /api/market/`
- **Trạng thái thực tế:** **BỊ CÔ LẬP & LỆCH API (Unreachable & Broken API)**
- **Bằng chứng khiếm khuyết:**
  - Bị cô lập: Không có đường dẫn vào từ `HomeScreen`.
  - **Sai Endpoint & Hardcode IP:** Gọi `/api/market/` (lỗi 404 vì Backend là `/api/v1/market`). Dòng 199 hardcode IP `http://192.168.1.18:8000`.

---

### SCR-15: Chợ Hiệu Ứng Kiến Trúc Chuẩn (Clean-Arch Market Screen - Inactive)
- **ID định danh:** `SCR-15-MARKET-CLEAN`
- **Tên màn hình:** Market Screen Clean Architecture (`presentation/screens/market_screen.dart`)
- **Tuyến đường (Route):** Chưa khai báo trong `main.dart`
- **Mục đích:** Phiên bản tách lớp chuẩn Clean Architecture của Chợ hiệu ứng, sử dụng `MarketProvider` và `MarketRepositoryImpl`.
- **Tập tin nguồn:** [features/market/presentation/screens/market_screen.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/features/market/presentation/screens/market_screen.dart)
- **Điều kiện truy cập / Quyền hạn:** Đã đăng nhập.
- **Thành phần UI trực quan:** Tương tự `SCR-14` nhưng được bọc trong `Consumer<MarketProvider>` với xử lý trạng thái Loading, Empty, Error có nút "Thử lại".
- **Hành vi người dùng & Xử lý sự kiện:** Gọi `provider.fetchTemplates()`, `provider.uploadTemplate()`, `provider.loadMore()`.
- **Yêu cầu API & Phụ thuộc Backend:**
  - Gọi qua `MarketRepositoryImpl` dùng `AppConstants.marketEndpoint` (`/api/v1/market`).
- **Trạng thái thực tế:** **CHƯA ĐẤU NỐI (Unwired)**
- **Bằng chứng khiếm khuyết:** File code hoàn chỉnh nhưng [main.dart](file:///c:/EXE401_WEDAPP_PROJECT_REPORT/App_EXE401/Frontend_EXE401/lib/main.dart) vẫn đang import và sử dụng file cũ `features/market/market_screen.dart`, đồng thời `MultiProvider` tại `main.dart` chưa khai báo `MarketProvider`.

---

## 3. BẢNG TỔNG HỢP TRẠNG THÁI KIỂM KÊ MÀN HÌNH

| Screen ID | Tên Màn Hình | Tuyến Đường | File Nguồn Chính | Phụ Thuộc API Backend | Trạng Thái Thực Tế | Ghi Chú Rủi Ro |
|---|---|---|---|---|---|---|
| **SCR-01** | Đăng Nhập & Đăng Ký | `/login` | `features/auth/login_screen.dart` | `POST /api/v1/auth/login`<br/>`POST /api/v1/auth/register` | ✅ Implemented | Hardcode text IP `192.168.1.18` ở footer |
| **SCR-02** | Trang Chủ Dashboard | `/` | `features/home/home_screen.dart` | Không (dùng `BleService`) | ✅ Implemented | Thiếu menu dẫn tới 3 màn hình SCR-12, 13, 14 |
| **SCR-03** | Pomodoro ESP32 | `/pomodoro` | `features/pomodoro/pomodoro_screen.dart` | `POST /api/v1/pomodoro/sync` | 🟡 Partial | Mock unlock_count; thiếu UI xem lịch sử |
| **SCR-04** | AI Productivity Hub | `/ai-hub` | `features/ai_hub/ai_hub_screen.dart` | `GET /api/v1/ai/pomodoro/recommend`<br/>`GET /api/v1/ai/burnout/risk`<br/>`GET /api/v1/ai/coach/daily-advice`<br/>`GET /api/v1/context/today` | ✅ Implemented | GPS đang fix cứng tọa độ TP.HCM |
| **SCR-05** | Live AI Coach & Assistant | Sub-route modal | `features/ai_hub/ai_assistant_screen.dart` | `POST /api/v1/ai/coach/chat`<br/>`POST /api/v1/ai/schedule/save` | 🟡 Partial | Digital Twin radar chart đang dùng mock data |
| **SCR-06** | Digital Wellbeing | `/wellbeing` | `features/digital_wellbeing/wellbeing_screen.dart` | `POST /api/v1/usage/daily-summary` | ✅ Implemented | Hoạt động đầy đủ trên Android; Web/iOS không có UsageStats |
| **SCR-07** | Đấu Trường Thi Đua | `/competition` | `features/competition/competition_screen.dart` | `POST /api/v1/competition/groups`<br/>`POST /api/v1/competition/groups/join`<br/>`GET /api/v1/competition/leaderboard/{code}`<br/>`POST /api/v1/competition/submit` | ✅ Implemented | Dùng http trực tiếp (không token); mock user_id "user_bao" |
| **SCR-08** | Lịch Nhắc Nhở Tuần | `/schedule` | `features/schedule/weekly_schedule_screen.dart` | `GET /api/schedules/`<br/>`POST /api/schedules/` | ❌ Broken | Lỗi 404 (sai endpoint thiếu `/v1`) & lệch Schema |
| **SCR-09** | Giao Diện Đồng Hồ | `/clock_mode` | `features/clock_mode/clock_mode_screen.dart` | Không (BLE trực tiếp) | ✅ Implemented | Điều khiển BLE ESP32 & SharedPreferences |
| **SCR-10** | Cài Đặt Chung | `/settings` | `features/general_settings/general_settings_screen.dart` | Không (BLE trực tiếp) | 🟡 Partial | Chỉ có syncTime hoạt động thật; 5 nút lưu còn lại là mock snackbar |
| **SCR-11** | Thông Tin & Firmware | `/info` | `features/info/info_screen.dart` | `GET /api/firmware/latest` | ❌ Broken | Lỗi 404 (thiếu `/v1`); lệch trường `description` vs `changelog` |
| **SCR-12** | Các Giao Diện | `/interfaces` | `features/interfaces/interfaces_screen.dart` | Không | ⛔ Unreachable | Không có lối vào từ Home; dữ liệu mock hoàn toàn |
| **SCR-13** | Thiết Kế 212x104 | `/design` | `features/design/design_screen.dart` | `POST /api/market/` | ⛔ Unreachable / Broken | Không có lối vào từ Home; hardcode IP; URL thiếu `/v1` |
| **SCR-14** | Chợ Hiệu Ứng (Cũ) | `/market` | `features/market/market_screen.dart` | `GET /api/market/`<br/>`POST /api/market/` | ⛔ Unreachable / Broken | Không có lối vào từ Home; hardcode IP; URL thiếu `/v1` |
| **SCR-15** | Chợ Hiệu Ứng (Clean) | Chưa đấu nối | `features/market/presentation/screens/market_screen.dart` | `GET /api/v1/market`<br/>`POST /api/v1/market` | ⚪ Unwired | Đã viết theo Clean Architecture nhưng chưa đấu vào main.dart |
