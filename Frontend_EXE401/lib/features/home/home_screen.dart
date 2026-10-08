import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/api/auth_api.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7), // Màu nền sáng, dịu mắt
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Trang Chủ',
          style: GoogleFonts.nunito(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await AuthApi.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Trạng thái kết nối (To, rõ ràng)
            const _ConnectionCard(),
            const SizedBox(height: 32),

            // 2. Nhóm Chức năng Năng suất
            _buildSectionTitle('NĂNG SUẤT & HỌC TẬP'),
            _MenuSection(
              children: [
                _ListMenuItem(
                  icon: Icons.timer_rounded,
                  iconColor: Colors.deepOrange,
                  title: 'Pomodoro AI',
                  subtitle: 'Tập trung học tập & làm việc',
                  onTap: () => Navigator.pushNamed(context, '/pomodoro'),
                ),
                _ListMenuItem(
                  icon: Icons.emoji_events_rounded,
                  iconColor: Colors.amber.shade600,
                  title: 'Thi Đua Năng Suất',
                  subtitle: 'Cạnh tranh cùng bạn bè',
                  onTap: () => Navigator.pushNamed(context, '/competition'),
                ),
                _ListMenuItem(
                  icon: Icons.calendar_month_rounded,
                  iconColor: Colors.teal,
                  title: 'Lịch Nhắc Nhở',
                  subtitle: 'Đồng bộ thời khóa biểu',
                  onTap: () => Navigator.pushNamed(context, '/schedule'),
                  showBorder: false,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 3. Nhóm AI & Thông minh
            _buildSectionTitle('TRỢ LÝ THÔNG MINH'),
            _MenuSection(
              children: [
                _ListMenuItem(
                  icon: Icons.psychology_rounded,
                  iconColor: Colors.indigo,
                  title: 'AI Hub & Coach',
                  subtitle: 'Trò chuyện với trợ lý ảo',
                  onTap: () => Navigator.pushNamed(context, '/ai-hub'),
                ),
                _ListMenuItem(
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.pinkAccent,
                  title: 'Digital Wellbeing',
                  subtitle: 'Thống kê sức khỏe số',
                  onTap: () => Navigator.pushNamed(context, '/wellbeing'),
                ),
                _ListMenuItem(
                  icon: Icons.watch_rounded,
                  iconColor: Colors.lightBlue,
                  title: 'Chế độ đồng hồ',
                  subtitle: 'Hiển thị màn hình chờ',
                  onTap: () => Navigator.pushNamed(context, '/clock_mode'),
                  showBorder: false,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 4. Nhóm Cài đặt hệ thống
            _buildSectionTitle('HỆ THỐNG CỦA THIẾT BỊ'),
            _MenuSection(
              children: [
                _ListMenuItem(
                  icon: Icons.settings_rounded,
                  iconColor: Colors.blueGrey,
                  title: 'Cài Đặt Chung',
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                _ListMenuItem(
                  icon: Icons.system_update_rounded,
                  iconColor: Colors.green,
                  title: 'Cập nhật Firmware',
                  onTap: () => Navigator.pushNamed(context, '/info'),
                  showBorder: false,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Thẻ bọc ngoài cho các nhóm chức năng (Bo tròn, đổ bóng nhẹ)
class _MenuSection extends StatelessWidget {
  final List<Widget> children;
  const _MenuSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// Từng dòng menu bên trong nhóm
class _ListMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showBorder;

  const _ListMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: showBorder 
              ? Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)) 
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// Thẻ kết nối Bluetooth ở đầu trang
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, ble, _) {
        final bool isConnected = ble.isConnected;
        final bool isScanning = ble.isScanning;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isConnected ? const Color(0xFF34D399) : const Color(0xFFF87171),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? (ble.device?.platformName ?? 'Eink Clock') : 'Đồng hồ chưa kết nối',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isConnected ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnected ? 'Thiết bị hoạt động ổn định' : 'Bấm Scan để quét Bluetooth',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: isConnected ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: isConnected
                    ? () async => await ble.disconnect()
                    : isScanning
                        ? null
                        : () async => await ble.startScan(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isScanning 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        isConnected ? 'Ngắt kết nối' : 'Quét / Scan',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
