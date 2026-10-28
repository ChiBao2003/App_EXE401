# POMO SMART — Flutter app

Ứng dụng di động Pomodoro thông minh, kết nối đồng hồ POMO SMART (ESP32) qua Bluetooth LE.

## Chạy khi phát triển

```powershell
flutter pub get
flutter run --dart-define=BACKEND_IP=192.168.1.XX
```

Backend dev chạy cổng `8000` (xem `../HUONG_DAN_CHAY.md`).

## Build phát hành (Google Play)

```powershell
flutter build appbundle --release --dart-define=BACKEND_URL=https://TEN-MIEN-BACKEND
```

Chi tiết ký ứng dụng, Google Sign-In và đăng bản lên Play Console: `../docs/PLAY_STORE_RELEASE.md`.

## Cấu trúc

- `lib/core/` — hằng số, mạng/API, Bluetooth, theo dõi sử dụng, xác thực
- `lib/features/` — các màn hình theo tính năng
- `android/app/src/main/kotlin/com/exe401/pomosmart/` — code native (Usage Stats, chọn/lưu JSON)
- `assets/` — hình ảnh và file mẫu mặt đồng hồ
