# Cấu hình đăng nhập Google

Luồng Google dùng Google ID token để lấy JWT của ứng dụng tại
`POST /api/v1/auth/google`. Backend chỉ chấp nhận token có chữ ký hợp lệ,
đúng Web OAuth Client ID và email đã xác minh.

1. Web OAuth Client ID mặc định của dự án là
   `3874930244-45sqv2n9btc1dr6avq428353d4vnlb2f.apps.googleusercontent.com`.
   Backend và Flutter đã dùng cùng ID này. Có thể ghi đè bằng biến môi trường
   `GOOGLE_WEB_CLIENT_ID` ở backend và `--dart-define=GOOGLE_WEB_CLIENT_ID=...`
   khi build Flutter. Client ID là giá trị công khai, không phải Client Secret.
2. Android OAuth client của dự án là
   `3874930244-nbeuc0vvbpf57qkoqlepo2hg7330ddc4.apps.googleusercontent.com`.
   Trong Google Cloud Console, kiểm tra client này có package name
   `EXE401.Project` và SHA-1
   `A4:EB:69:A0:82:C8:93:45:DA:9C:5A:35:CD:9C:30:EB:14:F0:6E:55`.
   Plugin dùng Web Client ID ở bước 1 làm `serverClientId`; không cần nhúng
   Client Secret hay `google-services.json`.
3. Web: thêm origin chính xác của trang chạy Flutter vào **Authorized JavaScript
   origins** của Web OAuth client. Dùng cổng cố định khi phát triển, ví dụ
   `flutter run -d chrome --web-hostname localhost --web-port 7357
   --dart-define=GOOGLE_WEB_CLIENT_ID=<client-id>` và cho phép
   `http://localhost:7357`.
4. iOS: tạo thêm **iOS OAuth client** cho bundle ID của Runner, truyền
   `--dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>` và thêm
   `CFBundleURLTypes` / `CFBundleURLSchemes` với `REVERSED_CLIENT_ID`
   của iOS OAuth client trong `ios/Runner/Info.plist` trước khi chạy trên iOS.

Không đặt Client Secret vào Flutter. Nếu email đã đăng ký bằng mật khẩu,
Google login trả 409 để tránh tự động ghép tài khoản. Tài khoản tạo bằng
Google không có mật khẩu nên không thể đăng nhập bằng mật khẩu hoặc dùng
chức năng đổi mật khẩu.
