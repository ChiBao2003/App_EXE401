import 'package:flutter/material.dart';
import '../general_settings/general_settings_screen.dart';

/// InfoScreen — Đã hợp nhất vào GeneralSettingsScreen theo thiết kế Google Stitch Screen 10:
/// "General Settings & Firmware OTA" (Design System: Aether Synapse).
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Giới Thiệu & Thông Tin', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: Column(
          children: [
            // === Header Gradient Card ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Watch icon avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.watch_rounded, size: 40, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'AI PRODUCTIVITY WATCH',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đồng Hồ Pomodoro AI & Loa Bluetooth',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Phiên bản 1.0.0 (Chính thức)',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Cập nhật: 16/10/2026',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _FirmwareUpdateCard(),
            const SizedBox(height: 16),

            // === Phần Cứng Đồng Hồ Card ===
            _InfoCard(
              icon: Icons.memory_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Phần Cứng Smartwatch ESP32',
              children: const [
                _BulletItem(
                  boldPrefix: 'Vi điều khiển ESP32:',
                  text: 'Dual-Core Tensilica Xtensa LX6 240MHz, RAM 520KB, Flash 4MB tích hợp Wi-Fi & Bluetooth kép.',
                ),
                _BulletItem(
                  boldPrefix: 'Màn hình hiển thị:',
                  text: 'Màn hình màu TFT LCD cảm ứng, hiển thị thời gian, bộ đếm Pomodoro và lịch biểu tuần.',
                ),
                _BulletItem(
                  boldPrefix: 'Thời gian thực RTC DS3231:',
                  text: 'Chip RTC I2C tích hợp pin nuôi độc lập, đảm bảo thời gian chạy chính xác tuyệt đối.',
                ),
                _BulletItem(
                  boldPrefix: 'Âm thanh Loa ngoài I2S DAC:',
                  text: 'Mạch giải mã âm thanh số I2S chất lượng cao kết hợp Còi Buzzer tần số cao báo chu kỳ.',
                ),
                _BulletItem(
                  boldPrefix: 'Dual-Mode Bluetooth:',
                  text: 'Hỗ trợ song song Bluetooth A2DP Sink (phát nhạc từ điện thoại) và Bluetooth SPP / BLE (truyền dữ liệu từ App).',
                ),
                _BulletItem(
                  boldPrefix: 'Phím cơ học vật lý:',
                  text: 'Hệ thống 3 nút bấm chuyển nhanh các chế độ Clock, Pomodoro, Timer và tương tác trực tiếp.',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // === Tính năng ứng dụng Card ===
            _InfoCard(
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Hệ Sinh Thái Tính Năng AI',
              children: [
                Text(
                  'Ứng dụng AI Productivity Watch đồng bộ và quản lý toàn diện đồng hồ thông minh, mang đến không gian làm việc tập trung khoa học, tăng cường kỷ luật và cải thiện năng suất học tập:',
                  style: GoogleFonts.nunito(
                    fontSize: 13.5,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const _BulletItem(
                  boldPrefix: '🍅 Pomodoro AI Thông Minh:',
                  text: 'Quản lý chu kỳ làm việc & nghỉ ngơi khoa học, đồng bộ bộ đếm ngược trực tiếp lên màn hình đồng hồ và chuông báo.',
                ),
                const _BulletItem(
                  boldPrefix: '🏆 Thi Đua Năng Suất (Competition):',
                  text: 'Bảng xếp hạng thời gian thực, phòng thi đua cùng bạn bè, biểu đồ cột 7 ngày chuẩn phong cách Smartwatch.',
                ),
                const _BulletItem(
                  boldPrefix: '📅 Lịch Nhắc Nhở Tuần (Schedule):',
                  text: 'Lập kế hoạch việc cần làm T2 đến CN, hẹn giờ sáng sớm tự động hiển thị thông báo lên màn hình đồng hồ.',
                ),
                const _BulletItem(
                  boldPrefix: '🤖 Trợ Lý Ảo AI Coach (Gemini):',
                  text: 'Phân tích dữ liệu học tập cá nhân, đánh giá nhịp tập trung và đưa ra chiến lược nâng cao hiệu suất.',
                ),
                const _BulletItem(
                  boldPrefix: '🎵 Loa Bluetooth Phát Nhạc Tập Trung:',
                  text: 'Kết nối âm thanh không dây A2DP phát nhạc Lo-Fi, White Noise hoặc bài giảng trực tiếp ra loa đồng hồ.',
                ),
                const _BulletItem(
                  boldPrefix: '❤️ Digital Wellbeing:',
                  text: 'Giám sát thói quen số, theo dõi tiến độ hoàn thành mục tiêu và cân bằng năng lượng mỗi ngày.',
                ),
                const _BulletItem(
                  boldPrefix: '🔄 Đồng Bộ Không Dây Thời Gian Thực:',
                  text: 'Đồng bộ thời gian tức thì từ điện thoại sang RTC, cập nhật thiết lập và hỗ trợ Firmware OTA.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // === Footer Card ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'AI PRODUCTIVITY WATCH • EXE401',
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Phát triển với ',
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                      ),
                      const Text('❤️', style: TextStyle(fontSize: 14)),
                      Text(
                        ' cho học tập & làm việc',
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dự án Khởi nghiệp Đồ án Công nghệ EXE401',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Đại học FPT Cần Thơ',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '© 2026 AI Productivity Watch. All rights reserved.',
                    style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final String? boldPrefix;
  const _BulletItem({required this.text, this.boldPrefix});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
                children: [
                  if (boldPrefix != null)
                    TextSpan(
                      text: '$boldPrefix ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirmwareUpdateCard extends StatefulWidget {
  const _FirmwareUpdateCard();
  @override
  State<_FirmwareUpdateCard> createState() => _FirmwareUpdateCardState();
}

class _FirmwareUpdateCardState extends State<_FirmwareUpdateCard> {
  bool _isLoading = true;
  String? _latestVersion;
  String? _description;

  @override
  void initState() {
    super.initState();
    _checkFirmware();
  }

  Future<void> _checkFirmware() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/firmware/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['version'] != null) {
          setState(() {
            _latestVersion = data['version'];
            _description = data['description'];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Lỗi fetch firmware: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.btnOrange)));
    }
    if (_latestVersion == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF81C784), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Color(0xFF388E3C), size: 28),
              const SizedBox(width: 10),
              Text('Có bản cập nhật mới!', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF2E7D32))),
            ],
          ),
          const SizedBox(height: 10),
          Text('Phiên bản mới nhất: $_latestVersion', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_description ?? '', style: GoogleFonts.nunito(fontSize: 14, color: Colors.black87, height: 1.5)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang gửi lệnh cập nhật OTA xuống đồng hồ qua BLE...')));
            },
            icon: const Icon(Icons.cloud_download_rounded, color: Colors.white),
            label: Text('Cập nhật Firmware qua WiFi', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 45)
            ),
          )
        ],
      ),
    );
  }
}

=======
    return const GeneralSettingsScreen();
  }
}
>>>>>>> thang
