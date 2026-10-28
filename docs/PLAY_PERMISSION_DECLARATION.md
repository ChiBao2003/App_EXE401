# Giải trình quyền PACKAGE_USAGE_STATS (Play Console)

`PACKAGE_USAGE_STATS` là quyền đặc biệt do người dùng tự bật trong **Cài đặt → Truy cập dữ liệu sử dụng**.
Google có thể hỏi mục đích và yêu cầu video demo. Nội dung dưới đây dùng để trả lời.

## Mục đích (dán vào ô giải trình)

> POMO SMART là ứng dụng quản lý thời gian Pomodoro đi kèm đồng hồ thông minh. Tính năng cốt lõi
> "Digital Wellbeing" hiển thị cho người dùng thời gian họ dùng từng ứng dụng trên điện thoại trong ngày/tuần,
> giúp nhận ra các ứng dụng gây xao nhãng trong phiên làm việc, và đưa ra gợi ý nghỉ ngơi/cân bằng.
> Quyền PACKAGE_USAGE_STATS chỉ được dùng để đọc số liệu thời gian sử dụng ứng dụng (UsageStatsManager) và
> sự kiện chuyển ứng dụng phục vụ tính năng này. Ứng dụng cũng nhận sự kiện màn hình khi đang chạy để hỗ trợ thống kê.
> Bản tóm tắt hằng ngày và một số sự kiện xao nhãng, gồm tên ứng dụng và thời lượng, được đồng bộ tới máy chủ
> để hiển thị thống kê và hỗ trợ gợi ý AI. Ứng dụng không đọc nội dung trong ứng dụng khác, không bán dữ liệu
> và không dùng cho quảng cáo. Người dùng được giải thích rõ trước khi chuyển tới màn hình cài đặt hệ thống,
> và có thể thu hồi quyền bất cứ lúc nào.

## Điểm cần đảm bảo trong app trước khi nộp
- [ ] Có màn hình **giải thích trước** (prominent disclosure) nói rõ ứng dụng đọc thời gian dùng app, để làm gì, rồi mới mở màn hình cài đặt.
- [ ] Khi người dùng không cấp quyền, các tính năng khác vẫn dùng được.
- [ ] Chính sách quyền riêng tư có nhắc đến dữ liệu này (đã có trong `PRIVACY_POLICY.md`).

## Kịch bản video demo (30–60 giây)
1. Mở app → vào màn hình **Digital Wellbeing** khi chưa cấp quyền → hiện lời giải thích.
2. Bấm cấp quyền → chuyển tới **Truy cập dữ liệu sử dụng** → bật cho POMO SMART.
3. Quay lại app → hiển thị biểu đồ thời gian dùng app trong ngày.
4. Chỉ ra phần gợi ý/cảnh báo xao nhãng dựa trên dữ liệu đó.
5. Quay lại Cài đặt, tắt quyền → mở app → app vẫn chạy, báo cần cấp quyền để xem thống kê.

Nếu Play Console yêu cầu video, tải lên YouTube (chế độ **Không công khai**) và dán link vào biểu mẫu.

## Giải trình Bluetooth/thiết bị lân cận

> POMO SMART quét và kết nối đồng hồ ESP32 tương thích qua Bluetooth LE để đồng bộ trạng thái Pomodoro,
> lịch nhắc và thiết kế mặt đồng hồ. Ứng dụng yêu cầu `BLUETOOTH_SCAN` và `BLUETOOTH_CONNECT` trên
> Android 12 trở lên; `BLUETOOTH`, `BLUETOOTH_ADMIN` và quyền vị trí chỉ trên Android 11 trở xuống
> theo yêu cầu của nền tảng khi quét BLE. Dữ liệu quét Bluetooth không dùng để suy ra vị trí địa lý,
> quảng cáo hoặc theo dõi người dùng. Người dùng có thể từ chối quyền; tính năng kết nối đồng hồ sẽ không hoạt động.

Không phải mọi quyền Bluetooth đều có form khai báo riêng. Dùng đoạn trên nếu Console hỏi về chức năng thiết bị
lân cận hoặc khi reviewer yêu cầu giải trình. `neverForLocation` trong manifest phải khớp với hành vi thực tế.

## Phương án dự phòng
Nếu Google từ chối: tạm ẩn Digital Wellbeing ở bản phát hành đầu (bỏ quyền khỏi manifest, ẩn màn hình),
sau đó bổ sung lại ở bản cập nhật khi có thêm thông tin.
