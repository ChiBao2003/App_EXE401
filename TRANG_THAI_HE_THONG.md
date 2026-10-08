# 📋 TRẠNG THÁI HỆ THỐNG — EXE401 Pomodoro AI
> Cập nhật: **08/10/2026**

---

## 🌐 Thông tin mạng hiện tại

| Thành phần | Giá trị |
|---|---|
| IP Máy tính (LAN) | `10.10.79.241` *(thay mỗi khi đổi mạng WiFi)* |
| IP Điện thoại (LAN) | `10.10.79.255` |
| Backend Port | `8000` |
| Device ID Android | `25069PTEBG` (`com.daonguyen.iot47.eink_clock`) |
| ESP32 Bluetooth Name | `ESP32_Pomodoro_Data` |
| NDK Version | `28.2.13676358` |

---

## 🚀 KHỞI CHẠY NHANH (Mỗi lần dùng)

### Terminal 1 — Backend FastAPI

`powershell
cd "C:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Backend_EXE401"
.\venv\Scripts\Activate.ps1
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
`

### Terminal 2 — Flutter App (Wireless ADB)

`powershell
# B1: Thêm ADB vào PATH
C:/Users/Admin/.gemini/antigravity-ide/bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Windows\System32\OpenSSH\;C:\Program Files\Git\cmd;C:\Program Files (x86)\Microsoft SQL Server\170\Tools\Binn\;C:\Program Files\Microsoft SQL Server\170\Tools\Binn\;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\;C:\Program Files\Microsoft SQL Server\170\DTS\Binn\;C:\Program Files\nodejs\;C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\;C:\Users\Admin\.local\bin;C:\Users\Admin\AppData\Local\Programs\Python\Python313\Scripts\;C:\Users\Admin\AppData\Local\Programs\Python\Python313\;C:\Users\Admin\AppData\Local\Microsoft\WindowsApps;C:\Users\Admin\AppData\Local\Programs\Microsoft VS Code\bin;C:\Users\Admin\AppData\Local\Programs\Antigravity IDE\bin;C:\Users\Admin\AppData\Local\Programs\mongosh\;C:\Users\Admin\AppData\Local\Programs\Python\Python313;C:\Users\Admin\AppData\Local\Programs\Python\Python313\Scripts;C:\Users\Admin\AppData\Roaming\npm;C:\Users\Admin\develop\flutter\bin;C:\Users\Admin\AppData\Local\Android\Sdk\platform-tools; += ";C:\Users\Admin\AppData\Local\Android\Sdk\platform-tools"
# B2: Ghép nối bằng mã (chỉ làm lần đầu hoặc khi đổi máy tính)
adb pair 10.10.79.255:<CỔNG_GHÉP_NỐI> <MÃ_6_SỐ>
# B3: Kết nối ADB
adb connect 10.10.79.255:<CỔNG_NGOÀI>
# B4 (nếu cần debug): Chạy Flutter
cd "C:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Frontend_EXE401"
flutter run -d 10.10.79.255:<CỔNG_NGOÀI> --android-skip-build-dependency-validation
`

> 💡 Nếu APK đã cài sẵn: chỉ cần mở App trực tiếp bằng tay.

---

## ⚙️ Khi đổi mạng WiFi

1. Kiểm tra IP mới: `ipconfig | Select-String "IPv4"`
2. Sửa file `Frontend_EXE401/lib/core/constants/app_constants.dart`:
   `defaultValue: '10.10.79.241'` → đổi thành IP mới
3. Nhấn `Shift+R` trong Flutter terminal để Hot Restart.

---

## 🤖 Cấu hình AI (Gemini)

File: `Backend_EXE401/.env` → `GEMINI_API_KEY=AQ.Ab8RN...`

Model Fallback Chain (đã sửa 08/10/2026):
- Primary: `models/gemini-2.5-flash`
- Fallback 1: `models/gemini-flash-latest`
- Fallback 2: `models/gemini-2.5-flash-lite`

⚠️ LỖI CŨ: Dùng tên model sai (thiếu prefix `models/`) → AI trả lời rule-based. ĐÃ SỬA.

---

## 🩺 Trạng thái các thành phần (08/10/2026)

| Thành phần | Trạng thái | Ghi chú |
|---|---|---|
| ✅ Backend FastAPI | Hoạt động | Port 8000, reload mode |
| ✅ MongoDB | Kết nối OK | Pomodoro_App database |
| ✅ Flutter App | Chạy trên điện thoại | APK đã cài sẵn |
| ✅ ADB Wireless | Kết nối OK | IP 10.10.79.255 |
| ✅ JWT Auth | Hoạt động | Token 7 ngày |
| ✅ Bluetooth ESP32 | Kết nối OK | BLE GATT_SUCCESS |
| ✅ Gemini AI API | ĐÃ SỬA 08/10 | Model URL format đúng |
| ✅ OpenWeatherMap | Hoạt động | Key ff68060f... |

---

## 📝 Lịch sử sửa lỗi

| Ngày | Lỗi | Giải pháp |
|---|---|---|
| 08/10/2026 | No route to host khi đổi WiFi | Cập nhật backendLanIp → 10.10.79.241 |
| 08/10/2026 | Token 401 Unauthorized | Đăng xuất/đăng nhập lại sau Backend restart |
| 08/10/2026 | Gemini 404 - AI trả lời rule-based | Sửa model URL: thêm prefix models/ |

## 🔧 Phím tắt Flutter Terminal

| Phím | Chức năng |
|---|---|
| r | Hot Reload |
| R (Shift+R) | Hot Restart |
| q | Tắt app |
