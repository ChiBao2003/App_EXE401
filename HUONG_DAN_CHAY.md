# 🚀 HƯỚNG DẪN CHẠY NHANH — EXE401 Eink Clock

---

## ⚡ Mỗi lần muốn chạy, làm theo đúng thứ tự này

---

## 🖥️ BƯỚC 1 — Chạy Backend (Terminal 1)

```powershell
cd "C:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Backend_EXE401"
.\venv\Scripts\Activate.ps1
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

✅ Thành công khi thấy:

```
Uvicorn running on http://0.0.0.0:8000
[OK] Ket noi MongoDB thanh cong (Pomodoro_App)
Application startup complete.
```

> ⚠️ Giữ cửa sổ này **MỞ SUỐT**, không đóng.

---

## 📱 BƯỚC 2 — Kết nối Điện thoại & Chạy Flutter (Terminal 2)

### 2a. Lấy Port mới trên điện thoại

Vào **Cài đặt → Tuỳ chọn nhà phát triển → Gỡ lỗi qua Wi-Fi**
→ Nhìn vào dòng **"Địa chỉ IP và cổng"** → lấy số PORT (VD: `38297`)

### 2b. Chạy lệnh

```powershell
cd "C:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Frontend_EXE401"

# Thêm ADB vào PATH (bắt buộc mỗi lần mở terminal mới)
$env:PATH += ";C:\Users\Admin\AppData\Local\Android\Sdk\platform-tools"

# Kết nối ADB với điện thoại (thay PORT bằng số thực tế)
adb connect 192.168.1.14:<PORT>

# Chạy app
flutter run -d 192.168.1.14:<PORT> --android-skip-build-dependency-validation
```

✅ Thành công khi thấy:

```
Syncing files to device 25069PTEBG...
Flutter run key commands.
```

---

## 🔵 BƯỚC 3 — Kết nối Bluetooth ESP32 trong App

1. Đảm bảo ESP32 đang bật nguồn và đã nạp firmware.
2. Trên điện thoại, vào **Cài đặt → Bluetooth**, tìm và ghép đôi thiết bị **`ESP32_Pomodoro_Data`** (nếu chưa ghép lần nào).
3. Mở App → vào màn hình **Pomodoro** → nhấn **Kết nối**.
4. App sẽ tự động tìm và kết nối.

---

## ✅ Kiểm tra hệ thống hoạt động

Khi đồng hồ ESP32 kết thúc phiên Pomodoro, trong **Terminal 2** (Flutter) bạn sẽ thấy:

```
I/flutter: [SPP] Nhận từ ESP32: {"mode":"pomodoro","work_min":25,...}
I/flutter: [Backend] Feedback: <Phản hồi từ AI>
```

Trong **Terminal 1** (Backend) bạn sẽ thấy:

```
INFO: 192.168.1.14:XXXX - "POST /api/v1/pomodoro/sync HTTP/1.1" 200 OK
```

---

## ⚙️ Thay đổi IP (khi đổi mạng WiFi)

1. Chạy lệnh để xem IP mới của máy tính:
   ```powershell
   ipconfig | Select-String "IPv4"
   ```
2. Mở file app_constants.dart → sửa dòng:
   ```dart
   static const String backendLanIp = '192.168.1.XX'; // đổi thành IP mới
   ```
3. Trong terminal Flutter, bấm **`R`** (Shift+R) để Hot Restart.

---

## 🔧 Lệnh hay dùng trong Flutter Terminal

| Phím | Chức năng                                        |
| ----- | -------------------------------------------------- |
| `r` | Hot Reload (cập nhật UI nhỏ)                    |
| `R` | Hot Restart (cập nhật toàn bộ, kể cả const)  |
| `q` | Tắt app                                           |
| `d` | Tách terminal, app vẫn chạy trên điện thoại |

---

## 📌 Thông tin cố định của dự án

| Thành phần                    | Giá trị               |
| ------------------------------- | ----------------------- |
| IP Máy tính (LAN)             | `192.168.1.20`        |
| IP Điện thoại (LAN)          | `192.168.1.14`        |
| Backend Port                    | `8000`                |
| Tên thiết bị ESP32 Bluetooth | `ESP32_Pomodoro_Data` |
| Device ID Android               | `25069PTEBG`          |
| NDK Version                     | `28.2.13676358`       |

---

*Cập nhật: 15/09/2026*
