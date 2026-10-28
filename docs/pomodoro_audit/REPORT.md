# Pomodoro BLE / Flutter / FastAPI audit

## A. Lỗi thực tế

| File / vùng trước sửa | Nguyên nhân | Ảnh hưởng |
|---|---|---|
| `spp_service.dart`, `_onBleStateChanged`, `_listenToData` | Mỗi emit connected đều cancel rồi subscribe lại, không chờ cancellation; thiếu onError/onDone | Cao: vòng đời listener không ổn định |
| `spp_service.dart`, `_handleJsonPayload` | Chưa có khóa session đang xử lý; duplicate đến trong lúc HTTP đang chờ có thể sync nhiều lần | Cao: request/ACK đồng thời |
| `spp_service.dart`, `_syncToBackend` | Không kiểm tra `status: ok`; gộp flush vào cùng try với persistence và ACK | Cao: lỗi flush bị lẫn với lỗi lưu phiên mới |
| `spp_service.dart`, queue | SharedPreferences không cam kết durability đa nền tảng; retry chỉ sau một phiên mới sync thành công; bỏ kết quả ghi khi xóa queue | Cao: queue có thể nằm mãi hoặc bị coi là đã lưu quá sớm |
| `spp_service.dart`, queue payload | Không lưu đầy đủ request gốc, user và recommendation; retry dựng lại theo tài khoản hiện tại | Cao: sai chủ sở hữu/metadata |
| `ble_service.dart`, notification | Coi một notification là một JSON; giới hạn write cố định 244 byte | Cao: gói dài/MTU nhỏ không tương thích |
| Firmware `sendPomodoroData` | `snprintf` không escape task_type; ID dựa thời gian + session count bị reset, đặc biệt khi không có RTC | Cao: JSON hỏng hoặc phiên mới bị coi là duplicate |
| Firmware `enqueuePomodoro` | Không kiểm tra kết quả ghi NVS | Cao: báo đã xếp queue dù ghi lỗi |
| Firmware `resetPomodoro` | Reset khi đang nghỉ cũng gửi phiên work chưa hoàn thành | Trung bình: dữ liệu phiên sai |

Các điểm đã đúng trước khi sửa: `main.dart` đã có `lazy: false` trên provider SppService; constructor đã gọi đồng bộ trạng thái hiện tại; parser đã giữ được boolean false; dispose đã removeListener và cancel subscription. Không coi các điểm này là lỗi đã sửa.

## B. Thay đổi

- `Frontend_EXE401/lib/main.dart`: làm rõ BleService cũng được tạo eager; giữ SppService ở provider gốc, ngoài các route.
- `lib/core/bluetooth/spp_service.dart`: một subscription, đợi cancel trước reconnect, onError/onDone, khóa in-flight theo session ID, chỉ nhớ backend-confirmed IDs; duplicate offline phải kiểm tra lại outbox. ACK sau backend `status: ok` hoặc sau ghi file và đọc lại thành công. Hủy timer/listener khi dispose và tránh notify sau dispose.
- `lib/core/bluetooth/pomodoro_outbox.dart`: snapshot ghi staging file với `flush: true`, rename thay snapshot, đọc lại kiểm tra. Không biến lỗi đọc thành queue rỗng. SharedPreferences queue cũ được chuyển sang snapshot trước khi xóa key cũ.
- Retry lúc khởi tạo, reconnect và mỗi 30 giây khi app đang chạy, kể cả BLE đang disconnected. Xóa từng entry sau backend xác nhận, đọc lại queue hiện tại dưới khóa để không làm mất phiên mới vừa thêm. Giữ nguyên request đã lưu, không gửi queue của tài khoản khác.
- `lib/core/bluetooth/ble_service.dart`, `ble_json_assembler.dart`: MTU Android 517, giới hạn theo MTU thực tế, ATT long-write cho lệnh lớn, ráp lại notification có header `0x1e, sequence, index, count`; vẫn đọc JSON một gói của firmware cũ.
- `pubspec.yaml`, `pubspec.lock`: khai báo trực tiếp `path_provider` đã có trong dependency graph để tìm application support directory.
- Firmware thực tế sửa tại `C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1\src\Esp32Pj.ino`: ArduinoJson serialize, ID gồm MAC + sequence NVS, chia notification theo MTU không block loop, kiểm tra NVS write, chỉ gửi completed=false khi dừng pha làm việc. Xem `firmware.patch` cho diff đúng lượt sửa này.
- Thêm `spp_service_test.dart`, `ble_json_assembler_test.dart`, `api_client_pomodoro_test.dart`, `test_pomodoro_flutter_contract.py`. Không sửa endpoint backend hoặc ApiClient đang hoạt động đúng.

## C. Kiểm chứng

| Kiểm tra | Kết quả |
|---|---|
| dart format, 8 file Dart thay đổi | PASS |
| flutter analyze --no-pub | FAIL (exit 1): 13 info có sẵn; 0 error, 0 warning; không có diagnostic trong file sửa |
| flutter build apk --debug --no-pub | PASS, app-debug.apk |
| PlatformIO `pio run`, ESP32 DOIT DevKit V1 | PASS, RAM 47,656 byte; flash 1,365,801 byte |
| Flutter tests, 5 file liên quan | PASS: 38/38 |
| FastAPI contract tests | PASS: 5/5, MongoDB mock |
| Tổng test | 43 pass / 0 fail |
| Payload backend | PASS: payload thực từ test SppService được validate strict bằng model FastAPI thật và POST vào endpoint thật qua ASGI |
| Reconnect/listener | PASS trong mock: `starts=2, active=1, max=1` |
| completed=false | PASS: parser, payload, endpoint và write database mock |
| Offline queue + ACK | PASS trong test: success, false return, exception, giả success chưa commit, duplicate, restart, retry định kỳ |

Payload đối chiếu:

| ESP32 | Flutter request FastAPI | Type |
|---|---|---|
| session_id | session_id | string |
| work_min, break_min, pauses | hardware_data cùng tên | int |
| completed | hardware_data.completed | bool, giữ nguyên false |
| session | hardware_data.session_count | int |
| start_time, end_time | hardware_data cùng tên | string/null |
| temperature | hardware_data.temperature | int/null |
| task_type | phone_data.task_type | string |
| App account | user_id | string, bắt buộc; server xác thực chủ sở hữu từ JWT |
| App metadata | phone_data.unlock_count/recommendation_id/timestamp | int/string-null/string-null |

Các log bằng chứng: `flutter-tests.log`, `backend-contract.log`, `flutter-analyze.log`, `android-build.log`. Payload thực xuất từ test: `Frontend_EXE401/build/pomodoro_audit_payloads.json`.

Lệnh chạy lại:

```powershell
# Trong Frontend_EXE401
flutter test --no-pub test/spp_service_test.dart test/ble_json_assembler_test.dart test/api_client_pomodoro_test.dart test/pomodoro_ack_fifo_test.dart test/pomodoro_test.dart --reporter expanded
flutter analyze --no-pub
flutter build apk --debug --no-pub
# Trong Backend_EXE401, sau Flutter tests
.\venv\Scripts\python.exe -m unittest test_pomodoro_flutter_contract -v
# Trong thư mục firmware được nêu ở trên
& 'C:\Users\Admin\.platformio\penv\Scripts\pio.exe' run
```

## D. Giới hạn còn lại

- CHƯA XÁC MINH runtime điện thoại + ESP32 thật: chưa cài APK/nạp firmware, chưa đo MTU, mất Wi-Fi/BLE thực, Hot Restart trên điện thoại, hoặc cắt nguồn khi đang ghi. Test restart là tạo lại service/outbox; test mạng và BLE dùng mock. Test filesystem chạy trên Windows host.
- CHƯA XÁC MINH MongoDB thật/JWT thật trong lượt này. Endpoint thật chạy với dependency auth/database mock; test ApiClient kiểm tra HTTP/JWT header bằng MockClient.
- 13 info analyzer nằm ở app_constants.dart, core/network/api_client.dart, usage_tracking/models.dart và usage_tracker_service.dart. Không mở rộng sửa các file này chỉ để làm sạch lint.
- Firmware còn giới hạn FIFO 5 phiên; đầy queue sẽ báo trên màn hình, không tự tăng dung lượng trong lượt sửa này.
- Queue cũ không có chủ sở hữu không thể khôi phục chủ sở hữu gốc; khi migrate nó dùng tài khoản đang đăng nhập như hành vi cũ. Queue mới lưu chủ sở hữu đầy đủ.
- Retry định kỳ hoạt động khi tiến trình app đang chạy; không phải background service của Android khi app đã bị hệ điều hành kết thúc. Queue được đọc/retry khi app mở lại.
- Dữ liệu còn ở ESP32 sẽ chưa ACK khi app chưa đăng nhập. Cần cập nhật cả app và firmware để dùng phân mảnh notification và session ID mới.

APK: `Frontend_EXE401/build/app/outputs/flutter-apk/app-debug.apk`.
Firmware: `C:\EXE401_WEDAPP_PROJECT_REPORT\260911-122138-esp32doit-devkit-v1\.pio\build\esp32doit-devkit-v1\firmware.bin`.
