# Tên Nhiệm Vụ: Triển Khai Luồng Đồng Bộ Dữ Liệu Bluetooth Từ ESP32 (Đồng Hồ) -> Điện Thoại -> Backend -> AI

## 1. Ngữ cảnh dự án (Context)
Dự án là một hệ thống Đồng hồ Pomodoro Thông minh. Nó bao gồm 4 phần:
1. **Phần cứng ESP32 (`codeesp`)**: Đóng vai trò là đồng hồ đếm giờ Pomodoro và loa Bluetooth.
2. **Frontend (`Frontend_EXE401`)**: App di động bằng Flutter.
3. **Backend (`Backend_EXE401`)**: API xử lý dữ liệu và lưu trữ.
4. **AI Automation (`AI_automation`)**: Agentic AI dùng Graph RAG và Function Calling để phân tích hiệu suất làm việc.

## 2. Mục tiêu (Objective)
Cần xây dựng một luồng dữ liệu thông suốt dựa trên kết nối Bluetooth:
- ESP32 theo dõi phiên Pomodoro và gửi dữ liệu qua Bluetooth.
- App Flutter nhận dữ liệu, gộp với dữ liệu sử dụng điện thoại, và gửi lên Backend.
- Backend lưu trữ và AI phân tích dữ liệu đó.

## 3. Các bước triển khai chi tiết (Action Plan)
Hãy thực hiện tuần tự các bước sau và cập nhật code ở từng dự án tương ứng:

### Bước 1: Cập nhật code ESP32 (`codeesp`)
**Yêu cầu:** Thêm chức năng truyền dữ liệu qua Bluetooth (sử dụng thư viện `BluetoothSerial` song song với `BluetoothA2DPSink` nếu có thể, hoặc dùng cấu hình tối ưu nhất cho ESP32 để không ngốn RAM).
**Logic cần thêm:**
- Khởi tạo kết nối Bluetooth Serial: `SerialBT.begin("ESP32_Pomodoro_Data");`
- Khai báo các biến đếm: `PauseCount` (mỗi lần người dùng bấm nút pause tăng 1).
- Bắt sự kiện khi kết thúc hoặc bỏ dở phiên Pomodoro (trong hàm `advancePomoPhase` hoặc `resetPomodoro`).
- Đóng gói dữ liệu thành chuỗi JSON: 
  `{"WorkDuration": 1500, "BreakDuration": 300, "PauseCount": 2, "Completed": true}`
- Gửi chuỗi JSON qua Bluetooth: `SerialBT.println(jsonString);`

### Bước 2: Cập nhật App Điện thoại (`Frontend_EXE401`)
**Yêu cầu:** Bắt dữ liệu Bluetooth từ ESP32 và tổng hợp thêm dữ liệu điện thoại.
**Logic cần thêm:**
- Sử dụng thư viện `flutter_bluetooth_serial` để duy trì kết nối và lắng nghe stream dữ liệu từ thiết bị ESP32.
- Khi nhận được JSON từ ESP32, thực hiện lấy thêm dữ liệu local của điện thoại trong khoảng thời gian phiên đó diễn ra (cần Mock các biến `UnlockCount`, `PhoneFreeTime` nếu chưa có native channel).
- Gộp thành 1 Payload hoàn chỉnh:
  ```json
  {
    "user_id": "user123",
    "session": {
      "WorkDuration": 1500,
      "BreakDuration": 300,
      "PauseCount": 2,
      "Completed": true,
      "UnlockCount": 3,
      "PhoneFreeTime": 1200
    }
  }
  ```
- Dùng `http` package để gọi phương thức POST gửi Payload này lên Backend.

### Bước 3: Cập nhật Backend API (`Backend_EXE401`)
**Yêu cầu:** Cung cấp Endpoint để App gửi dữ liệu lên.
**Logic cần thêm:**
- Tạo một Router mới (VD: `POST /api/v1/pomodoro/sync`).
- Schema Pydantic để Validate payload từ App Flutter.
- Lưu dữ liệu này vào CSDL (MongoDB).
- (Tùy chọn) Kích hoạt Kafka Event hoặc gọi trực tiếp sang API của module AI để báo rằng có 1 session mới cần phân tích.

### Bước 4: Xử lý bên AI Automation (`AI_automation`)
**Yêu cầu:** AI đọc Dataset mới và đánh giá.
**Logic cần thêm:**
- Khi nhận được dữ liệu (hoặc khi được Backend trigger), AI Agent (đã được cấu hình Tools) sẽ được cấp ngữ cảnh: *"Phiên làm việc vừa xong kéo dài 25p, user tạm dừng 2 lần ở đồng hồ, và mở khóa điện thoại 3 lần"*.
- AI dùng `AnalyzeFocusBehaviorTool` để phân tích.
- Trả về Feedback (Ví dụ: *"Tôi thấy bạn mở điện thoại 3 lần, lần sau hãy bật chế độ máy bay nhé!"*) để hiển thị ngược lại trên App Flutter.

## 4. Ràng buộc (Constraints) & Yêu cầu chất lượng
- Đảm bảo xử lý lỗi (Exception Handling) ở luồng Bluetooth bên Flutter (khi mất kết nối đột ngột).
- Code ESP32 phải tối ưu bộ nhớ vì vừa chạy âm thanh (I2S) vừa chạy Bluetooth data.
- Các API phải có xác thực (JWT Token).
- Cung cấp các đoạn code mẫu (Mock Code) cho phần lấy `UnlockCount` ở Flutter nếu chưa có plugin native hỗ trợ ngay.

--- 
**Bắt đầu đi, hãy triển khai code cho Bước 1 (ESP32) trước.**
