# Hướng dẫn phát hành POMO SMART lên Google Play

Package name: `com.exe401.pomosmart` (không đổi được sau khi upload lần đầu).

## Trạng thái audit tại 27/10/2026

| Mục | Kết quả |
|---|---|
| `applicationId` / namespace | `com.exe401.pomosmart` |
| `versionCode` / `versionName` | `1` / `1.0.0`, lấy từ `pubspec.yaml` (`1.0.0+1`) |
| `compileSdk` / `targetSdk` | Lấy từ Flutter SDK. FlutterExtension đang cài đặt là **36 / 36**; merged release manifest xác nhận target 36. Đạt yêu cầu API 36 hiện hành. |
| `minSdk` | 24 theo merged release manifest |
| Release signing | Đọc `android/key.properties`, nhưng file và keystore chưa có. Nếu thiếu sẽ ký bằng debug key. **Chưa sẵn sàng upload.** |
| Minify / shrink | `isMinifyEnabled = true`, `isShrinkResources = true` đã bật trong release. |
| URL backend | Không truyền `BACKEND_URL` sẽ rơi về `http://192.168.1.18:8000` trên Android. **Phải truyền URL HTTPS khi build.** |

Manifest đã merge từ plugin còn có `USE_BIOMETRIC` và `USE_FINGERPRINT`. `POST_NOTIFICATIONS` có trong manifest nhưng chưa tìm thấy luồng gửi thông báo trong Dart; cân nhắc bỏ nếu không dùng.

## 1. Tạo upload keystore (làm 1 lần)

```powershell
cd C:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Frontend_EXE401\android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Tạo file `android/key.properties` (đã nằm trong `.gitignore`):

```properties
storePassword=MAT_KHAU
keyPassword=MAT_KHAU
keyAlias=upload
storeFile=../upload-keystore.jks
```

> **Sao lưu `upload-keystore.jks` và mật khẩu** ở nơi an toàn (Google Drive riêng tư, trình quản lý mật khẩu). Không commit lên git.

Lấy SHA-1 để đăng ký Google Sign-In:

```powershell
keytool -list -v -keystore upload-keystore.jks -alias upload
```

## 2. Deploy backend (xem `docs/DEPLOY_BACKEND.md`)

Cần có URL HTTPS, ví dụ `https://pomosmart-api.onrender.com`.

## 3. Google Sign-In cho package mới

Google Cloud Console → APIs & Services → Credentials → **Create credentials → OAuth client ID → Android**:

| Trường | Giá trị |
|---|---|
| Package name | `com.exe401.pomosmart` |
| SHA-1 | SHA-1 của **upload key** (bước 1) |

Sau khi upload bản đầu lên Play, vào **Play Console → Release → Setup → App signing**, lấy **SHA-1 của App signing key** và tạo thêm một Android OAuth client nữa với SHA-1 đó. Người dùng cài từ Play sẽ dùng khóa này.

`GOOGLE_WEB_CLIENT_ID` (Web client) giữ nguyên, app dùng nó làm `serverClientId`.

## 4. Build file AAB

```powershell
cd C:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Frontend_EXE401
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=BACKEND_URL=https://TEN-MIEN-BACKEND
```

Kết quả: `build\app\outputs\bundle\release\app-release.aab`.

Ví dụ PowerShell có kiểm tra đầu vào:

```powershell
$backendUrl = "https://TEN-DICH-VU.onrender.com"
if (-not $backendUrl.StartsWith("https://")) { throw "BACKEND_URL phải là HTTPS" }
if (-not (Test-Path android/key.properties)) { throw "Thiếu android/key.properties" }
flutter build appbundle --release --dart-define="BACKEND_URL=$backendUrl"
```

Nếu cần obfuscate Dart: thêm `--obfuscate --split-debug-info=build/symbols` và giữ symbols ứng với từng build để giải mã crash. R8 minify/shrink đã bật trong Gradle, không có cờ Flutter riêng cần thêm.

- Mỗi lần upload bản mới, tăng số sau dấu `+` trong `pubspec.yaml` (`version: 1.0.0+2`...).
- Nếu chưa có `key.properties`, bản build sẽ ký bằng debug key và **Play sẽ từ chối**.
- Muốn thử trên máy thật trước: `flutter build apk --release --dart-define=BACKEND_URL=...` rồi `adb install`.

Checklist thử bản release trên điện thoại thật:
- [ ] Đăng nhập Google
- [ ] Gọi API (xem dữ liệu Pomodoro/Schedule)
- [ ] Quét và kết nối BLE ESP32
- [ ] Digital Wellbeing (cấp quyền Usage Access)
- [ ] Chọn ảnh ở màn hình Design/Clock

## 5. Tạo tài khoản và app trên Play Console

1. https://play.google.com/console → đăng ký (phí 25 USD, xác minh danh tính).
2. **Create app** → tên, ngôn ngữ, App, Free.
3. Hoàn thành **Dashboard → Set up your app**:
   - **Privacy policy**: URL công khai (nội dung mẫu: `docs/PRIVACY_POLICY.md`).
   - **App access**: nếu cần đăng nhập, cấp tài khoản test cho reviewer.
   - **Ads**: không có quảng cáo.
   - **Content rating**: làm bảng câu hỏi.
   - **Target audience**: 13+ hoặc 18+ (tránh nhóm trẻ em để khỏi yêu cầu Families Policy).
   - **Data safety**: khai báo theo danh sách trong `docs/PRIVACY_POLICY.md`.
   - **Permissions declaration** (PACKAGE_USAGE_STATS): xem `docs/PLAY_PERMISSION_DECLARATION.md`.
4. **Main store listing**: nội dung trong `docs/STORE_LISTING.md`.

## 6. Closed testing (bắt buộc với tài khoản cá nhân mới)

Điều kiện **≥ 12 tester opt-in liên tục 14 ngày** chỉ áp dụng cho tài khoản cá nhân tạo sau 13/11/2023 trước khi xin Production. Tài khoản tổ chức hoặc cá nhân cũ không chịu điều kiện này.

1. **Testing → Closed testing → Create track → Create release** → upload `.aab`, bật Play App Signing.
2. Tạo danh sách tester (email Gmail) hoặc Google Group.
3. Gửi link opt-in cho tester. Ít nhất 12 người phải duy trì opt-in liên tục trong 14 ngày; khuyến khích họ cài và sử dụng app để cung cấp phản hồi.
4. Sau 14 ngày: **Dashboard → Apply for production**, trả lời bảng câu hỏi.
5. **Production → Create release** (có thể chọn lại bản từ closed testing) → **Send for review**.

Thời gian duyệt thường vài giờ đến vài ngày, bản đầu có thể lâu hơn.

## 7. Lỗi hay gặp

| Triệu chứng | Nguyên nhân |
|---|---|
| App mở lên nhưng mọi API lỗi | Quên `--dart-define=BACKEND_URL=...` hoặc URL không phải HTTPS |
| Google Sign-In báo lỗi 10/12500 | Chưa tạo Android OAuth client đúng package/SHA-1 (nhớ cả SHA-1 của App signing key) |
| Play báo "signed in debug mode" | Thiếu `key.properties` khi build |
| Play báo `versionCode` đã dùng | Chưa tăng số build trong `pubspec.yaml` |
| Không quét được BLE trên Android 11 trở xuống | Người dùng chưa cấp quyền vị trí |

## 8. Checklist bàn giao cho chủ Play Console

| Mục | Tệp/thông tin chính xác | Trạng thái |
|---|---|---|
| Bundle release | `Frontend_EXE401/build/app/outputs/bundle/release/app-release.aab` | File hiện tại ký bằng **Android Debug** (đã kiểm tra chứng chỉ bằng keytool), không upload được; phải build lại bằng upload key và URL HTTPS |
| Package/version | `com.exe401.pomosmart`, `1.0.0+1` | Có trong mã; tăng versionCode cho mỗi lần upload |
| Khóa upload | `Frontend_EXE401/android/upload-keystore.jks`, `Frontend_EXE401/android/key.properties` | Chưa tạo; chỉ bàn giao an toàn nếu chủ Console sẽ tự build |
| OAuth Android | SHA-1 upload key và SHA-1 Play App Signing key, cùng package ID | Chưa có khóa; thêm cả hai OAuth client |
| Backend | URL HTTPS công khai, trạng thái health check; thiết lập các biến theo `Backend_EXE401/.env.example` | Chưa deploy; không chuyển secret qua tài liệu công khai |
| Store listing | `docs/STORE_LISTING.md`, icon `docs/store_assets/play_store_icon_512.png`, feature graphic và ít nhất 2 screenshots thật | Icon có; graphic/screenshots chưa thấy |
| Chính sách | `docs/PRIVACY_POLICY.md`, URL công khai; URL yêu cầu xóa tài khoản | Bản nháp có; URL và luồng xóa chưa có |
| App content | Data Safety, App access/test account, Ads, Content rating, Target audience, quyền nhạy cảm | Chủ Console điền/duyệt |
| Giải trình quyền | `docs/PLAY_PERMISSION_DECLARATION.md`, video demo Usage Access/Bluetooth nếu Play yêu cầu | Bản nháp; cần quay video với AAB cuối |
| Nhóm thử | Danh sách ít nhất 12 email Google hoặc Google Group, link opt-in, email nhận phản hồi | Chủ Console chuẩn bị nếu thuộc diện 14 ngày |

**Chặn trước khi nộp:** triển khai xóa tài khoản trong app và trang web yêu cầu xóa; công khai Privacy Policy và thêm liên kết/chính sách ngay trong app (chưa tìm thấy trong Dart); kiểm tra AAB cuối trên thiết bị cài qua Play Internal/Closed Testing, gồm đăng nhập Google bằng SHA-1 App Signing. Không cần gửi upload keystore hay mật khẩu cho chủ Console nếu họ chỉ tải AAB đã ký; người giữ khóa phải sao lưu riêng để build bản cập nhật.

### Ghi chú khai Data Safety

- Khai **Personal info**: email, tên, user ID; **App activity**: tương tác/hoạt động trong ứng dụng; **Installed apps** vì tên gói/tên app được gửi trong một số `usage_events`; **Messages**: tin nhắn nhóm/trực tiếp. Đối chiếu toàn bộ endpoint trước khi chốt form.
- Usage Stats **được thu thập lên máy chủ**; không chọn “chỉ xử lý trên thiết bị”. Đối chiếu định nghĩa “sharing” của Google Play cho nhà cung cấp dịch vụ.
- Ảnh được chọn hiện xử lý trên thiết bị; không đánh dấu “ảnh được tải lên” nếu không có luồng tải ảnh mới.
- Chỉ chọn “data encrypted in transit” sau khi toàn bộ bản release dùng HTTPS và kiểm tra SDK/endpoint liên quan.
- Chỉ khai “người dùng có thể yêu cầu xóa” với URL và quy trình thật, đồng thời hoàn tất luồng xóa tài khoản trong ứng dụng.
