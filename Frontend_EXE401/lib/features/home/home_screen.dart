import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/api/auth_api.dart';

/// Màn hình Trang Chủ Dashboard & IoT Hub (Screen 2)
/// Được trích xuất và ánh xạ 1:1 từ Google Stitch Screen: c7f4c282459b4d468d8d2abde17beca3
/// Hệ thống thiết kế: Aether Synapse (Dark Modern Glassmorphism + Bento Grid).
/// Bảo toàn toàn bộ tích hợp phần cứng BleService, xác thực AuthApi, và điều hướng routing.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
<<<<<<< HEAD
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
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.indigo,
                  title: 'Giới Thiệu & Thông Tin',
                  subtitle: 'Thông số thiết bị & hệ sinh thái',
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
=======
  State<HomeScreen> createState() => _HomeScreenState();
>>>>>>> thang
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayName = "Bạn";
  bool _isSyncing = false;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString("user_name");
    if (name != null && name.trim().isNotEmpty) {
      if (mounted) setState(() => _displayName = name.trim());
    }
  }

  Future<void> _handleManualSync(BleService ble) async {
    if (!ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng kết nối đồng hồ trước khi đồng bộ!"),
          backgroundColor: AppColors.stitchSurfaceHigh,
        ),
      );
      return;
    }
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Đã đồng bộ thời gian và dữ liệu Pomodoro xuống ESP32!",
          ),
          backgroundColor: Color(0xFF008259),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.stitchSurfaceLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Đăng xuất",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Bạn có chắc muốn đăng xuất khỏi ứng dụng không?",
          style: GoogleFonts.inter(color: AppColors.stitchOnSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Hủy",
              style: GoogleFonts.inter(color: AppColors.stitchOutline),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Đăng xuất",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthApi.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        // Already on Home
        break;
      case 1:
        Navigator.pushNamed(context, '/schedule');
        break;
      case 2:
        Navigator.pushNamed(context, '/pomodoro');
        break;
      case 3:
        Navigator.pushNamed(context, '/clock_mode');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: Stack(
        children: [
          // Ambient Aura Orbs (Aether Synapse Theme)
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.stitchPrimaryContainer.withValues(
                      alpha: 0.15,
                    ),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 320,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.stitchSecondaryContainer.withValues(
                  alpha: 0.08,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.stitchSecondaryContainer.withValues(
                      alpha: 0.12,
                    ),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                _buildTopAppBar(ble),

                // Main Scrollable Dashboard Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Greeting Header Row
                        _buildGreetingHeader(),
                        const SizedBox(height: 16),

                        // Hero Hardware Connection Card (ESP32 Live BLE & TFT LCD Dial Preview)
                        _buildHeroHardwareCard(ble),
                        const SizedBox(height: 24),

                        // SECTION 1: NĂNG SUẤT & HỌC TẬP (BENTO SUITE)
                        _buildSectionHeader(
                          "Năng suất & Học tập",
                          "BENTO SUITE",
                          AppColors.stitchPrimaryContainer,
                        ),
                        const SizedBox(height: 12),
                        _buildProductivityBento(context),
                        const SizedBox(height: 24),

                        // SECTION 2: TRỢ LÝ THÔNG MINH & WELLBEING (INSIGHTS)
                        _buildSectionHeader(
                          "Trợ lý thông minh & Wellbeing",
                          "INSIGHTS",
                          AppColors.stitchSecondaryContainer,
                        ),
                        const SizedBox(height: 12),
                        _buildIntelligenceBento(context),
                        const SizedBox(height: 24),

                        // SECTION 3: HỆ THỐNG & PHẦN CỨNG (OTA READY)
                        _buildSectionHeader(
                          "Hệ thống & Phần cứng",
                          "OTA READY",
                          AppColors.stitchTertiary,
                        ),
                        const SizedBox(height: 12),
                        _buildHardwareSystemBento(context),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),

                // Bottom Navigation Bar
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TOP APP BAR ───────────────────────────────────────────────
  Widget _buildTopAppBar(BleService ble) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLowest.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/pomo_smart_mascot.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ble.isConnected
                                  ? AppColors.stitchTertiary
                                  : AppColors.stitchOutline,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ble.isConnected ? "ESP32 LIVE" : "DISCONNECTED",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: ble.isConnected
                                  ? AppColors.stitchTertiary
                                  : AppColors.stitchOutline,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "POMO SMART",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (ble.isConnected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.stitchTertiary,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "98%",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Bạn có 2 gợi ý tối ưu học tập từ AI Coach!",
                      ),
                      backgroundColor: AppColors.stitchSurfaceHigh,
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.stitchOnSurface,
                        size: 18,
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.stitchOutline,
                  size: 20,
                ),
                tooltip: "Đăng xuất",
                onPressed: _handleLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── GREETING HEADER ───────────────────────────────────────────
  Widget _buildGreetingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      "Xin chào, $_displayName!",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stitchOnSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text("👋", style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "Hệ thống AI & Đồng hồ TFT LCD sẵn sàng",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.stitchOutline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── HERO HARDWARE CONNECTION CARD ─────────────────────────────
  Widget _buildHeroHardwareCard(BleService ble) {
    final isConnected = ble.isConnected;
    final isScanning = ble.isScanning;
    final deviceName = ble.device?.platformName.isNotEmpty == true
        ? ble.device!.platformName
        : "ESP32_Pomodoro_Data";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Beacon Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected
                          ? AppColors.stitchTertiary
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected
                        ? "BLE KẾT NỐI TRỰC TIẾP"
                        : "CHƯA KẾT NỐI BLUETOOTH",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isConnected
                          ? AppColors.stitchTertiary
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.battery_charging_full_rounded,
                        color: AppColors.stitchTertiary,
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        "85%",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Device Name & Signal Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? deviceName : "Đồng Hồ TFT LCD Smartwatch",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stitchOnSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isConnected
                              ? Icons.wifi_tethering_rounded
                              : Icons.bluetooth_searching_rounded,
                          size: 14,
                          color: isConnected
                              ? AppColors.stitchSecondary
                              : AppColors.stitchOutline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isConnected
                                ? "-54 dBm • Tín hiệu rất tốt"
                                : "Bấm nút bên để quét & kết nối",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.stitchOutline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  backgroundColor: isConnected
                      ? AppColors.stitchSurfaceHighest
                      : AppColors.stitchPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: isConnected
                    ? () async => await ble.disconnect()
                    : isScanning
                    ? null
                    : () async => await ble.startScan(),
                child: isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isConnected ? "Ngắt kết nối" : "Quét & Kết nối",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isConnected
                              ? AppColors.stitchOnSurfaceVariant
                              : Colors.white,
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Live Monochromatic TFT LCD Dial Preview Sub-module
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                // Inverted TFT LCD Dial Graphic
                Container(
                  width: 70,
                  height: 70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E9ED), // TFT LCD matte whitTFT LCD
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              "INK-V3",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "⚡85%",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _getFormattedCurrentTime(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        height: 3,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.75,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mặt số TFT LCD Đồng bộ",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                      Text(
                        "16 mức xám dithered mượt mà",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.stitchOutline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 12,
                            color: isConnected
                                ? AppColors.stitchSecondary
                                : AppColors.stitchOutline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isConnected
                                  ? "Đã đồng bộ thời gian thực"
                                  : "Chờ đồng bộ kết nối",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: isConnected
                                    ? AppColors.stitchSecondary
                                    : AppColors.stitchOutline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.stitchSecondary,
                          ),
                        )
                      : const Icon(
                          Icons.sync_rounded,
                          color: AppColors.stitchSecondary,
                          size: 20,
                        ),
                  tooltip: "Đồng bộ thủ công",
                  onPressed: () => _handleManualSync(ble),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION 1: PRODUCTIVITY BENTO CLUSTER ─────────────────────
  Widget _buildProductivityBento(BuildContext context) {
    return Column(
      children: [
        // Pomodoro Card (Span 2)
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/pomodoro'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.stitchPrimaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.timer_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "25 phút tập trung",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.stitchOnSurface,
                                  ),
                                ),
                                Text(
                                  "Phiên Pomodoro AI thích ứng • Mục tiêu: 6 phiên",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.stitchOutline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Mini Circular Arc Progress
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(
                            value: 0.60,
                            strokeWidth: 3.5,
                            backgroundColor: AppColors.stitchSurfaceHigh,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.stitchPrimaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          "60%",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.stitchOnSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.stitchSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Chế độ Deep Work sẵn sàng",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.stitchOutline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.stitchPrimaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/pomodoro'),
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        "Bắt đầu ngay",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Grid 2 Columns: Competition & Schedule
        Row(
          children: [
            // Thi Đua Năng Suất (Competition)
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/competition'),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 150,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.military_tech_rounded,
                              color: AppColors.stitchSecondary,
                              size: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "HẠNG #2",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stitchSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Thi Đua Năng Suất",
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchOnSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Streak: 7 ngày 🔥",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.stitchSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Lịch Nhắc Nhở (Weekly Schedule)
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/schedule'),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 150,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.stitchSecondary,
                              size: 18,
                            ),
                          ),
                          Text(
                            "3 PHIÊN",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchOutline,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TIẾP THEO • 14:00",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Lịch Nhắc Nhở",
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchOnSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── SECTION 2: INTELLIGENCE & WELLBEING BENTO CLUSTER ─────────
  Widget _buildIntelligenceBento(BuildContext context) {
    return Column(
      children: [
        // AI Hub & Coach Card (Span 2)
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/ai-hub'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.stitchSurfaceContainer,
                  AppColors.stitchSurfaceHigh,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.stitchPrimary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.psychology_rounded,
                              color: Color(0xFF20005F),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "AI Coach Trực Tiếp",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.stitchOnSurface,
                                  ),
                                ),
                                Text(
                                  "Sẵn sàng tối ưu lịch học",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.stitchSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceLowest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.stitchTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "BURNOUT: 22%",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceLowest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "“Chu kỳ nhịp sinh học đang ở đỉnh cao năng lượng. Bạn có thể kéo dài phiên Pomodoro tiếp theo lên 35 phút.”",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.stitchOnSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Grid 2 Columns: Wellbeing & Clock Mode
        Row(
          children: [
            // Digital Wellbeing Card
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/wellbeing'),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 155,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.self_improvement_rounded,
                              color: AppColors.stitchPrimary,
                              size: 18,
                            ),
                          ),
                          Text(
                            "TỐT",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stitchTertiary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "82",
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.stitchOnSurface,
                                  ),
                                ),
                                TextSpan(
                                  text: "/100",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.stitchOutline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Điểm Tập Trung",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.stitchOnSurface,
                            ),
                          ),
                          Text(
                            "Screen Time: 2h 45m",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.stitchOutline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Mặt Đồng Hồ (Clock Mode)
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/clock_mode'),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 155,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.watch_rounded,
                              color: AppColors.stitchSecondary,
                              size: 18,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.stitchOutline,
                            size: 16,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceLowest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "MINIMAL",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.stitchOnSurface,
                                  ),
                                ),
                                Text(
                                  "v3.2",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    color: AppColors.stitchSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Mặt Đồng Hồ",
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchOnSurface,
                            ),
                          ),
                          Text(
                            "3 giao diện đã lưu",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.stitchOutline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── SECTION 3: HARDWARE & SYSTEM BENTO STRIP ──────────────────
  Widget _buildHardwareSystemBento(BuildContext context) {
    return Column(
      children: [
        // OTA Firmware Strip
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/info'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AppColors.stitchTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Firmware ESP32",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.stitchTertiary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "v2.4.1 Mới nhất",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stitchTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Đồng bộ OTA qua BLE 5.0 tự động",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.stitchOutline,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.stitchOutline,
                  size: 14,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Quick Grid for Settings, Interfaces, Design & Market (Solves unreachable routes)
        Row(
          children: [
            _buildQuickActionTile(
              context,
              icon: Icons.settings_rounded,
              title: "Cài Đặt",
              route: "/settings",
            ),
            const SizedBox(width: 8),
            _buildQuickActionTile(
              context,
              icon: Icons.dashboard_customize_rounded,
              title: "Màn Hình",
              route: "/interfaces",
            ),
            const SizedBox(width: 8),
            _buildQuickActionTile(
              context,
              icon: Icons.brush_rounded,
              title: "Studio TFT LCD",
              route: "/design",
            ),
            const SizedBox(width: 8),
            _buildQuickActionTile(
              context,
              icon: Icons.storefront_rounded,
              title: "Chợ Mẫu",
              route: "/market",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.stitchSecondary, size: 18),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.stitchOnSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SECTION HEADER ────────────────────────────────────────────
  Widget _buildSectionHeader(String title, String badge, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.stitchOnSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          badge,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: AppColors.stitchOutline,
          ),
        ),
      ],
    );
  }

  // ─── BOTTOM NAVIGATION BAR ─────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLowest.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildNavItem(0, Icons.dashboard_rounded, "Trang chủ"),
          ),
          Expanded(
            child: _buildNavItem(
              1,
              Icons.calendar_view_week_rounded,
              "Lịch tuần",
            ),
          ),
          Expanded(child: _buildNavItem(2, Icons.timer_rounded, "Pomodoro")),
          Expanded(child: _buildNavItem(3, Icons.hub_rounded, "Thiết bị")),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () => _onBottomNavTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.stitchSurfaceHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.stitchSecondary
                  : AppColors.stitchOutline,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.stitchSecondary
                    : AppColors.stitchOutline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFormattedCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }
}
