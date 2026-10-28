# Chính sách quyền riêng tư — POMO SMART

**Bản nháp để chủ ứng dụng xác nhận trước khi công bố.** Cập nhật: [ngày]. Đơn vị vận hành: [tên cá nhân/pháp nhân], email: [email hỗ trợ]. URL công khai: [URL]. Điền thông tin thật vào các mục trong ngoặc vuông.

POMO SMART hỗ trợ hẹn giờ Pomodoro, phân tích thời gian sử dụng điện thoại và kết nối đồng hồ ESP32 qua Bluetooth.

## Dữ liệu được xử lý

| Loại dữ liệu | Nguồn và mục đích | Nơi lưu/xử lý |
|---|---|---|
| Email, tên hiển thị, mã tài khoản Google (`sub`) | Đăng nhập bằng Google, tạo tài khoản ứng dụng. Máy chủ xác minh Google ID token; không lưu mật khẩu Google. | Cơ sở dữ liệu máy chủ; Google xử lý đăng nhập. |
| Email, tên hiển thị, mật khẩu nếu đăng ký thủ công | Tạo và xác thực tài khoản. Máy chủ lưu mật khẩu ở dạng băm. | Cơ sở dữ liệu máy chủ. |
| Mã người dùng và JWT | Duy trì phiên đăng nhập. | Thông tin phiên lưu cục bộ; thông tin tài khoản lưu trên máy chủ. |
| Phiên Pomodoro, lịch nhắc, điểm năng suất, hoạt động thi đua, tin nhắn nhóm hoặc trực tiếp | Đồng bộ đồng hồ, thống kê và cộng đồng. Người tham gia nhóm hoặc cuộc trò chuyện có thể thấy tên, điểm và nội dung bạn gửi trong phạm vi tính năng đó. | Máy chủ và dữ liệu cục bộ phù hợp từng tính năng. |
| Tên ứng dụng, tên gói, thời gian dùng ứng dụng, thời điểm chuyển ứng dụng và thống kê màn hình | Digital Wellbeing, nhận diện xao nhãng, điểm tập trung và gợi ý năng suất. Chỉ truy cập sau khi bạn tự bật Usage Access trong Cài đặt Android. Bản tóm tắt hằng ngày và một số sự kiện xao nhãng được gửi tới máy chủ. | Thiết bị và cơ sở dữ liệu máy chủ. |
| Thiết bị Bluetooth gần đó và dữ liệu trao đổi với đồng hồ ESP32 | Quét, ghép nối, đồng bộ phiên làm việc, lịch và mặt đồng hồ. | Thiết bị và đồng hồ; một số phiên Pomodoro được đồng bộ lên máy chủ. |
| Ảnh hoặc tệp JSON bạn chủ động chọn | Tạo hoặc nhập mặt đồng hồ, gửi thiết kế đến đồng hồ hoặc lưu tệp theo lựa chọn. | Xử lý trên thiết bị; bản mã hiện tại không chủ động tải ảnh lên máy chủ. |
| Nội dung bạn nhập cho trợ lý AI, ngữ cảnh năng suất liên quan | Tạo câu trả lời và gợi ý. Nếu bật Gemini, máy chủ gửi nội dung cần thiết tới dịch vụ Google Gemini. | Máy chủ và nhà cung cấp AI. |

Ứng dụng hiện dùng tọa độ mặc định phía máy chủ cho tính năng thời tiết; mã Android không đọc vị trí để cung cấp thời tiết. Trên Android 11 trở xuống, hệ điều hành có thể yêu cầu quyền vị trí để quét Bluetooth. Ứng dụng không dùng tín hiệu quét Bluetooth để suy ra vị trí.

## Quyền trên thiết bị

- **Usage Access (`PACKAGE_USAGE_STATS`):** bạn bật trong Cài đặt Android và có thể thu hồi bất cứ lúc nào. Khi thu hồi, thống kê mới trên thiết bị không hoạt động.
- **Bluetooth Scan/Connect; Bluetooth và Bluetooth Admin trên Android cũ:** tìm và kết nối đồng hồ ESP32.
- **Vị trí trên Android 11 trở xuống:** phục vụ quét BLE theo yêu cầu của Android; ứng dụng không thu thập tọa độ qua quyền này.
- **Internet:** đăng nhập, đồng bộ và truy cập dịch vụ trực tuyến.
- **Thông báo:** manifest xin quyền thông báo. Chủ ứng dụng cần xác nhận chức năng thông báo thực tế trước khi công bố mô tả mục đích.

## Chia sẻ và bảo mật

Ứng dụng không bán dữ liệu cá nhân và hiện không tích hợp quảng cáo. Dữ liệu có thể được xử lý bởi Google Sign-In, Google Gemini nếu bật AI, nhà cung cấp hosting [tên], MongoDB Atlas và OpenWeather nếu được cấu hình. Các yêu cầu tới backend phát hành phải dùng HTTPS. Không công bố mật khẩu, khóa API hay JWT.

## Lưu trữ và xóa

Mã máy chủ có tác vụ dọn dữ liệu cũ hơn 15 ngày cho **ba bộ sưu tập**: `pomodoro_sessions`, `productivity_logs`, `daily_summaries`. Tác vụ chạy khi máy chủ hoạt động, khoảng mỗi 6 giờ. Dữ liệu ở các bộ sưu tập khác, gồm tài khoản, lịch, tin nhắn, điểm thi đua và `usage_events`, hiện **không có thời hạn xóa tự động chung**. Quy tắc lưu trữ cụ thể cho các loại dữ liệu này: [điền thời hạn thực tế].

Bạn có thể yêu cầu xóa tài khoản và dữ liệu liên quan qua [email] hoặc [URL yêu cầu xóa]. Quy trình trong ứng dụng và trang web yêu cầu xóa đang cần hoàn tất trước khi phát hành trên Google Play. Sau khi tiếp nhận yêu cầu đã xác minh, [đơn vị vận hành] sẽ xóa dữ liệu theo [thời hạn thực tế], trừ dữ liệu phải giữ theo nghĩa vụ pháp luật được nêu rõ tại đây: [nếu có]. Xóa ứng dụng hoặc đăng xuất không tự xóa dữ liệu trên máy chủ.

## Quyền lựa chọn và liên hệ

Bạn có thể từ chối hoặc thu hồi Usage Access, Bluetooth và thông báo trong Cài đặt thiết bị. Liên hệ [email] để hỏi về dữ liệu, yêu cầu sửa hoặc xóa. Chính sách sẽ được cập nhật nếu cách xử lý dữ liệu thay đổi.

**Trẻ em:** [chủ ứng dụng xác nhận nhóm tuổi mục tiêu theo Play Console].

