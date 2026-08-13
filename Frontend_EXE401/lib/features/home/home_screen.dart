import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                child: Text(
                  'Eink Clock',
                  style: GoogleFonts.nunito(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Status Card
              const _StatusCard(),

              const SizedBox(height: 20),

              // Menu Items
              _MenuItem(
                color: AppColors.cardYellow,
                icon: Icons.access_time_rounded,
                label: 'Cài đặt chung',
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                color: AppColors.cardBlue,
                icon: Icons.monitor_rounded,
                label: 'Các giao diện',
                onTap: () => Navigator.pushNamed(context, '/interfaces'),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                color: AppColors.cardPink,
                icon: Icons.brush_rounded,
                label: 'Thiết kế',
                onTap: () => Navigator.pushNamed(context, '/design'),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                color: AppColors.cardPurple,
                icon: Icons.info_outline_rounded,
                label: 'Cập nhật firmware',
                onTap: () => Navigator.pushNamed(context, '/info'),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                color: AppColors.cardTeal,
                icon: Icons.calendar_month_rounded,
                label: 'Lịch nhắc nhở tuần',
                onTap: () => Navigator.pushNamed(context, '/schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, ble, _) {
        final bool isConnected = ble.isConnected;
        final bool isScanning = ble.isScanning;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isConnected ? AppColors.online : AppColors.offlineBorder,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isConnected ? AppColors.online : AppColors.offline).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isConnected ? AppColors.online : AppColors.offline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isConnected ? 'DEVICE ONLINE' : 'DEVICE OFFLINE',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isConnected ? AppColors.online : AppColors.offline,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: isConnected
                        ? () async => await ble.disconnect()
                        : isScanning
                            ? null
                            : () async => await ble.startScan(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.textPrimary, width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isScanning) ...[
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            const Icon(Icons.bluetooth_searching_rounded, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            isConnected ? 'Ngắt kết nối' : isScanning ? 'Đang quét...' : 'Scan',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isConnected
                    ? ble.device?.platformName ?? 'Eink Clock'
                    : 'Chưa kết nối',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isConnected ? AppColors.online : AppColors.offline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isConnected
                    ? 'Thiết bị đã kết nối thành công'
                    : 'Ấn Scan để tìm đồng hồ e-ink gần bạn',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }
}
