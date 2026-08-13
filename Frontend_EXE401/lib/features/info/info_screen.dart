import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/app_colors.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Thông tin', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
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
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Clock icon avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.watch_rounded, size: 40, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'EINK CLOCK',
                    style: GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phiên bản App V123',
                    style: GoogleFonts.nunito(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cập nhật: 09/07/2026',
                    style: GoogleFonts.nunito(fontSize: 13, color: Colors.white60),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _FirmwareUpdateCard(),
            const SizedBox(height: 16),

            // === Thiết bị E-Ink Card ===
            _InfoCard(
              icon: Icons.memory_rounded,
              iconColor: AppColors.btnGreen,
              title: 'Thiết bị E-Ink',
              children: const [
                _BulletItem(text: 'Màn hình E-Ink'),
                _BulletItem(text: 'Giao tiếp Bluetooth Low Energy'),
                _BulletItem(text: 'Hỗ trợ nhiều màn hình hiển thị'),
                _BulletItem(text: 'Hỗ trợ màn hình tự thiết kế'),
                _BulletItem(text: 'Hiển thị thời gian và lịch'),
                _BulletItem(text: 'Chế độ ngủ tiết kiệm năng lượng'),
                _BulletItem(text: 'Nạp thiết kế từ điện thoại'),
                SizedBox(height: 8),
                Text(
                  '(Kết nối với device sẽ hiện nút cập nhật ở đây)',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // === Tính năng ứng dụng Card ===
            _InfoCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFA000),
              title: 'Tính năng ứng dụng',
              children: [
                Text(
                  'Ứng dụng EINK CLOCK cho phép người dùng kết nối và điều khiển đồng hồ E-Ink thông qua Bluetooth BLE. Toàn bộ giao diện hiển thị trên màn hình E-Ink có thể được thiết kế trực tiếp trên điện thoại và nạp xuống thiết bị chỉ với một vài thao tác.',
                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 12),
                const _BulletItem(text: 'Kết nối Bluetooth BLE'),
                const _BulletItem(text: 'Đồng bộ thời gian thực từ điện thoại'),
                const _BulletItem(text: 'Thiết kế giao diện E-Ink trực quan'),
                const _BulletItem(text: 'Đồng hồ số và đồng hồ kim'),
                const _BulletItem(text: 'Văn bản động với biến thời gian'),
                const _BulletItem(text: 'Hình học, biểu tượng pin'),
                const _BulletItem(text: 'Hiển thị lịch dương lịch và âm lịch'),
                const _BulletItem(text: 'Nạp hình ảnh đen trắng Mono'),
                const _BulletItem(text: 'Lưu và mở file thiết kế .eink'),
                const _BulletItem(text: 'Bộ sưu tập giao diện mẫu'),
                const _BulletItem(text: 'Nạp thiết kế vào các Slot tùy chỉnh'),
              ],
            ),

            const SizedBox(height: 16),

            // === Footer Card ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CC),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Text(
                    '< >',
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Developed with ',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const Text('❤️', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EINK CLOCK V100',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '© 2026 VUONGCHIBAO IOT47',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
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
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
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
      String baseUrl = "http://127.0.0.1:8000";
      if (!kIsWeb && Platform.isAndroid) baseUrl = "http://10.0.2.2:8000";

      final response = await http.get(Uri.parse('$baseUrl/api/firmware/latest'));
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

