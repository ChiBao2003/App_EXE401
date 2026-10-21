import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/bluetooth/spp_service.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL — 9 THEMES (PRESERVING FIRMWARE CONTRACT)
// ─────────────────────────────────────────────────────────────────────────────

class ClockTheme {
  final int id;
  final String name;
  final String description;
  final int mode; // 0=Clock, 1=Pomodoro, 2=Timer
  final Color primary;
  final Color bg;
  final String fontStyle; // 'digital','minimal','retro','bold'
  final bool hasAnimation;
  final IconData icon;
  final String tag;
  final String previewDisplay;

  const ClockTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.mode,
    required this.primary,
    required this.bg,
    required this.fontStyle,
    this.hasAnimation = false,
    required this.icon,
    required this.tag,
    required this.previewDisplay,
  });
}

const List<ClockTheme> kThemes = [
  // ── ĐỒNG HỒ (Mode 0) ──────────────────────────────────────────────────────
  ClockTheme(
    id: 0,
    mode: 0,
    name: 'Flip Clock',
    description: 'Hai thẻ giờ và phút trên LCD màu',
    primary: Color(0xFF00FF88),
    bg: Colors.black,
    fontStyle: 'digital',
    icon: Icons.watch_rounded,
    tag: 'Đồng Hồ',
    previewDisplay: '14:28',
  ),
  ClockTheme(
    id: 1,
    mode: 0,
    name: 'Analog + Digital',
    description: 'Kim đồng hồ và giờ số trên LCD màu',
    primary: Color(0xFF00E5FF),
    bg: Color(0xFF050510),
    fontStyle: 'digital',
    icon: Icons.terminal_rounded,
    tag: 'Nhị phân',
    previewDisplay: '1011 01',
  ),
  ClockTheme(
    id: 2,
    mode: 0,
    name: 'Sunset',
    description: 'Mặt số trên nền màu hoàng hôn',
    primary: Color(0xFFFF6B35),
    bg: Color(0xFF1A0A00),
    fontStyle: 'minimal',
    icon: Icons.wb_sunny_rounded,
    tag: 'Thiên văn',
    previewDisplay: '06:42 ☀️',
  ),

  // ── POMODORO (Mode 1) ─────────────────────────────────────────────────────
  ClockTheme(
    id: 3,
    mode: 1,
    name: 'Focus Ring',
    description: 'Vòng tròn xoay thể hiện tiến độ phiên',
    primary: Color(0xFF7C4DFF),
    bg: Color(0xFF0A0015),
    fontStyle: 'bold',
    hasAnimation: true,
    icon: Icons.circle_outlined,
    tag: 'Vòng tròn',
    previewDisplay: '25:00',
  ),
  ClockTheme(
    id: 4,
    mode: 1,
    name: 'Hourglass Focus',
    description: 'Hạt pixel TFT LCD rớt động theo phút',
    primary: Color(0xFFFFD93D),
    bg: Color(0xFF1A1400),
    fontStyle: 'retro',
    hasAnimation: true,
    icon: Icons.hourglass_full_rounded,
    tag: 'Pomodoro',
    previewDisplay: '25:00',
  ),
  ClockTheme(
    id: 5,
    mode: 1,
    name: 'Deep Ocean',
    description: 'Sóng biển nhấp nhô theo từng phút',
    primary: Color(0xFF0099FF),
    bg: Color(0xFF000D1A),
    fontStyle: 'minimal',
    hasAnimation: true,
    icon: Icons.waves_rounded,
    tag: 'Sóng biển',
    previewDisplay: '25:00',
  ),

  // ── ĐẾM NGƯỢC (Mode 2) ───────────────────────────────────────────────────
  ClockTheme(
    id: 6,
    mode: 2,
    name: 'Pulse Blast',
    description: 'Số đếm ngược to, nảy theo nhịp tim',
    primary: Color(0xFFFF6B6B),
    bg: Color(0xFF1A0000),
    fontStyle: 'bold',
    hasAnimation: true,
    icon: Icons.favorite_rounded,
    tag: 'Nhịp đập',
    previewDisplay: '05:00',
  ),
  ClockTheme(
    id: 7,
    mode: 2,
    name: 'Sand Timer',
    description: 'Cát chảy từ trên xuống đến khi hết giờ',
    primary: Color(0xFFE8A87C),
    bg: Color(0xFF1A0E00),
    fontStyle: 'retro',
    hasAnimation: true,
    icon: Icons.hourglass_bottom_rounded,
    tag: 'Cát chảy',
    previewDisplay: '05:00',
  ),
  ClockTheme(
    id: 8,
    mode: 2,
    name: 'Matrix Drop',
    description: 'Số rơi kiểu ma trận, đếm ngược giây',
    primary: Color(0xFF39FF14),
    bg: Colors.black,
    fontStyle: 'digital',
    hasAnimation: true,
    icon: Icons.data_array_rounded,
    tag: 'Ma trận',
    previewDisplay: '05:00',
  ),
];

enum ScreenColorMode { mono, gray, amber }

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ClockModeScreen extends StatefulWidget {
  const ClockModeScreen({super.key});

  @override
  State<ClockModeScreen> createState() => _ClockModeScreenState();
}

class _ClockModeScreenState extends State<ClockModeScreen>
    with TickerProviderStateMixin {
  int _selectedId = 0;
  int _selectedCategory = 0; // 0=Clock, 1=Pomodoro, 2=Countdown
  ScreenColorMode _colorMode = ScreenColorMode.mono;
  bool _sending = false;
  XFile? _pickedCustomImage;

  late final AnimationController _liveAnim;
  late final AnimationController _pulseAnim;

  ClockTheme get _selected =>
      kThemes.firstWhere((t) => t.id == _selectedId, orElse: () => kThemes[0]);

  @override
  void initState() {
    super.initState();
    _liveAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('clock_theme_id') ?? 0;
    if (mounted) {
      setState(() {
        _selectedId = savedId;
        _selectedCategory = _selected.mode;
      });
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clock_theme_id', _selectedId);
  }

  Future<void> _apply(SppService spp) async {
    if (!spp.isConnected) {
      _showSnack(
        'Chưa kết nối ESP32! Vào Pomodoro để kết nối BLE trước.',
        AppColors.stitchError,
      );
      return;
    }

    setState(() => _sending = true);

    try {
      // 1. Gửi chế độ hiển thị
      await spp.setMode(_selected.mode);
      await Future.delayed(const Duration(milliseconds: 200));

      // Firmware currently implements three clock faces (IDs 0..2).
      if (_selectedId > 2) {
        await _savePrefs();
        if (mounted) {
          setState(() => _sending = false);
          _showSnack(
            'Đã chuyển chế độ; hiệu ứng mẫu này chưa có trong firmware TFT.',
            AppColors.stitchTertiary,
          );
        }
        return;
      }

      // 2. Gửi theme ID và màu hex
      final c = _selected.primary;
      final hexColor =
          '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';

      await spp.setTheme(
        _selectedId,
        hexColor: hexColor,
        anim: _selected.hasAnimation,
      );

      await _savePrefs();

      if (mounted) {
        setState(() => _sending = false);
        _showSnack(
          '✓ Đã đồng bộ giao diện ${_selected.name} sang đồng hồ TFT',
          AppColors.stitchTertiary,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _showSnack('Lỗi truyền tải qua BLE: $e', AppColors.stitchError);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        setState(() => _pickedCustomImage = image);
        _showSnack(
          'Đã chọn ảnh. Mở Canvas Studio để chuyển ảnh thành bitmap và nạp TFT.',
          AppColors.stitchTertiary,
        );
      }
    } catch (e) {
      _showSnack('Không thể chọn ảnh: $e', AppColors.stitchError);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        backgroundColor: color.withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _liveAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SppService>(
      builder: (ctx, spp, _) {
        return Scaffold(
          backgroundColor: AppColors.stitchSurface,
          appBar: _buildHeader(spp),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status Pill & Title
                _buildHeaderInfo(spp),
                const SizedBox(height: 16),

                // 2. Hero Mockup Preview Card (320×240 px)
                _buildHeroPreviewCard(spp),
                const SizedBox(height: 24),

                // 3. Category Tabs & Theme Gallery
                _buildThemeGallerySection(),
                const SizedBox(height: 24),

                // 4. Custom Image Upload & Floyd-Steinberg Dithering
                _buildDitheringUploadSection(),
                const SizedBox(height: 24),

                // 5. Bottom Main Action Trigger
                _buildBottomSyncAction(spp),
                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. APP BAR HEADER (Aether Synapse)
  // ───────────────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildHeader(SppService spp) {
    final isConnected = spp.isConnected;

    return AppBar(
      backgroundColor: AppColors.stitchSurface.withValues(alpha: 0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.stitchOnSurface,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.stitchPrimaryContainer.withValues(
                    alpha: 0.25,
                  ),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.memory_rounded,
              color: AppColors.stitchPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Synapse',
                    style: GoogleFonts.outfit(
                      color: AppColors.stitchOnSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.stitchPrimaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'AI',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.stitchPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, _) => Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? AppColors.stitchTertiary
                            : AppColors.stitchOutlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isConnected ? 'TFT LCD RGB565' : 'ESP32 OFFLINE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Battery status pill
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.watch_rounded,
                color: AppColors.stitchSecondary,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                isConnected ? '98%' : '--',
                style: GoogleFonts.outfit(
                  color: AppColors.stitchSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // User Avatar
        Container(
          margin: const EdgeInsets.only(right: 14),
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.stitchPrimary,
          ),
          child: const Center(
            child: Icon(
              Icons.person,
              color: AppColors.stitchSurfaceLowest,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. HEADER INFO & STATUS PILL
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderInfo(SppService spp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, _) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stitchTertiary.withValues(
                        alpha: 0.5 + 0.5 * _pulseAnim.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'TFT LCD ENGINE 4.2 ACTIVE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.stitchTertiary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt,
                    color: AppColors.stitchSecondary,
                    size: 13,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '0.8% pin/24h',
                    style: GoogleFonts.outfit(
                      color: AppColors.stitchSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Màn Hình Chờ TFT LCD',
          style: GoogleFonts.outfit(
            color: AppColors.stitchOnSurface,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bộ sưu tập 9 giao diện tiết kiệm năng lượng cực hạn & bộ chuyển dithering lượng tử.',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.stitchOnSurfaceVariant,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.stitchPrimary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Màn hình màu ILI9341 • RGB565 16-bit',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.stitchOnSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. HERO MOCKUP PREVIEW CARD (320×240 px)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeroPreviewCard(SppService spp) {
    Color screenBg;
    Color screenFg;

    switch (_colorMode) {
      case ScreenColorMode.mono:
        screenBg = Colors.black;
        screenFg = Colors.white;
        break;
      case ScreenColorMode.gray:
        screenBg = Colors.black;
        screenFg = Colors.cyan;
        break;
      case ScreenColorMode.amber:
        screenBg = Colors.black;
        screenFg = Colors.orange;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header of card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.watch_rounded,
                    color: AppColors.stitchPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mô Phỏng Trực Tiếp (320×240 px)',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.stitchOnSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stitchPrimaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'LIVE 1:1',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.stitchOnPrimaryContainer,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Smartwatch Bezel & TFT LCD Viewport
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.stitchOutlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: AspectRatio(
              aspectRatio: 320 / 240,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: screenBg,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Stack(
                  children: [
                    // Pixel stipple grain
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DitherPixelGrainPainter(color: screenFg),
                      ),
                    ),
                    // Screen contents
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top status bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bedtime_rounded,
                                  color: screenFg,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SYNAPSE STANDBY',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: screenFg,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  spp.isConnected ? '88%' : '--%',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: screenFg,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.sim_card_download_rounded,
                                  color: screenFg,
                                  size: 11,
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Center clock display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selected.previewDisplay,
                                  style: GoogleFonts.outfit(
                                    color: screenFg,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.wb_sunny_rounded,
                                      color: screenFg,
                                      size: 11,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '28°C NẮNG NHẸ • THỨ SÁU',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: screenFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Mini Pomodoro Gauge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'FOCUS SESSION',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w800,
                                    color: screenFg.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: List.generate(6, (i) {
                                    final isActive = i < 3;
                                    return Container(
                                      margin: const EdgeInsets.only(left: 2.5),
                                      width: 6.5,
                                      height: 6.5,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? screenFg
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: screenFg,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          1.5,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'POMO 3/6 • 18M LẠI',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: screenFg,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Bottom telemetry ribbon
                        Container(
                          padding: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: screenFg.withValues(alpha: 0.25),
                                width: 0.7,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                spp.isConnected
                                    ? 'BLE CONNECTED'
                                    : 'LATENCY: -- (OFFLINE)',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                  color: screenFg.withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                'THEME: ${_selected.name.toUpperCase()}',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                  color: screenFg.withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                'DITHER: ${_colorMode.name.toUpperCase()}',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w600,
                                  color: screenFg.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Mode Selector Controls (Mono / Gray / Amber)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildModeTab(
                  mode: ScreenColorMode.mono,
                  title: 'Trắng',
                  icon: Icons.contrast_rounded,
                ),
                _buildModeTab(
                  mode: ScreenColorMode.gray,
                  title: 'Cyan',
                  icon: Icons.gradient_rounded,
                ),
                _buildModeTab(
                  mode: ScreenColorMode.amber,
                  title: 'Cam',
                  icon: Icons.light_mode_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required ScreenColorMode mode,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _colorMode == mode;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _colorMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.stitchSurfaceHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.stitchOnSurface
                    : AppColors.stitchOnSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.stitchOnSurface
                      : AppColors.stitchOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. THEME GALLERY SECTION & CATEGORY TABS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildThemeGallerySection() {
    final filteredThemes = kThemes
        .where((t) => t.mode == _selectedCategory)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Thư Viện Giao Diện',
              style: GoogleFonts.outfit(
                color: AppColors.stitchOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Tất cả (9)',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Category Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryPill(
                categoryIndex: 0,
                title: 'Đồng hồ (3)',
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(width: 8),
              _buildCategoryPill(
                categoryIndex: 1,
                title: 'Pomodoro (3)',
                icon: Icons.timer_rounded,
              ),
              const SizedBox(width: 8),
              _buildCategoryPill(
                categoryIndex: 2,
                title: 'Đếm ngược (3)',
                icon: Icons.hourglass_bottom_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2-Column Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredThemes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (ctx, index) {
            final theme = filteredThemes[index];
            final isSelected = theme.id == _selectedId;

            return _buildThemeCard(theme, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryPill({
    required int categoryIndex,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedCategory == categoryIndex;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = categoryIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.stitchPrimary
              : AppColors.stitchSurfaceContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.stitchPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.stitchSurfaceLowest
                  : AppColors.stitchOnSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.stitchSurfaceLowest
                    : AppColors.stitchOnSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(ClockTheme theme, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedId = theme.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.stitchSurfaceHigh
              : AppColors.stitchSurfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.stitchPrimary
                : AppColors.stitchOutlineVariant.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.stitchPrimary.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top tag & status icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.stitchTertiaryContainer
                        : AppColors.stitchSurfaceHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isSelected ? 'Đang dùng' : theme.tag,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.stitchTertiary
                          : AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isSelected
                      ? AppColors.stitchPrimary
                      : AppColors.stitchOutline,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Miniature Canvas Preview
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFDFE2D6)
                      : const Color(0xFF14181F),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SUN 88%',
                          style: GoogleFonts.spaceMono(
                            fontSize: 7,
                            color: isSelected
                                ? const Color(0xFF1C1F19)
                                : Colors.white54,
                          ),
                        ),
                        Text(
                          '12ms',
                          style: GoogleFonts.spaceMono(
                            fontSize: 7,
                            color: isSelected
                                ? const Color(0xFF1C1F19)
                                : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        theme.previewDisplay,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFF0D0F0C)
                              : theme.primary,
                        ),
                      ),
                    ),
                    Container(
                      height: 2,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1C1F19).withValues(alpha: 0.3)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1C1F19)
                              : theme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Name & subtitle
            Text(
              theme.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: AppColors.stitchOnSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              theme.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchOnSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),

            // Button trigger
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.stitchSurfaceLowest
                    : AppColors.stitchSurfaceHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  isSelected ? 'Đang chạy' : 'Áp dụng',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.stitchPrimary
                        : AppColors.stitchOnSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. CUSTOM IMAGE UPLOAD & FLOYD-STEINBERG DITHERING PREVIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDitheringUploadSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_b_and_w_rounded,
                          color: AppColors.stitchSecondaryContainer,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tải Ảnh & Dithering 1-Bit',
                          style: GoogleFonts.outfit(
                            color: AppColors.stitchOnSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Thuật toán Floyd-Steinberg tối ưu hóa cho màn hình TFT LCD 320×240 pixel không vỡ nét.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.stitchOnSurfaceVariant,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.stitchSecondaryContainer.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'AI CORE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.stitchSecondaryContainer,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dual Comparison (Original vs Dithered)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Original RGB
                Expanded(
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_pickedCustomImage != null)
                                Image.file(
                                  File(_pickedCustomImage!.path),
                                  fit: BoxFit.cover,
                                )
                              else
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF2E0854),
                                        Color(0xFF003852),
                                        Color(0xFF8A2BE2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_rounded,
                                      color: Colors.white70,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Gốc Màu (RGB)',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pickedCustomImage != null
                            ? 'Ảnh tải lên (${(_pickedCustomImage!.name)})'
                            : 'Ảnh mẫu (2.4MB)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.stitchOnSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Dithered 1-Bit
                Expanded(
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: const Color(0xFFD8DCCE),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(painter: _DitherMatrixSimPainter()),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.landscape_rounded,
                                      color: Color(0xFF121410),
                                      size: 26,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'DITHERED 1-BIT',
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF121410),
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF121410),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'TFT LCD Output (14KB)',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFD8DCCE),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            color: AppColors.stitchTertiary,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              'Bitmap 1-bit trên nền TFT màu',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.stitchTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Upload Trigger Box
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.stitchOutlineVariant.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stitchPrimaryContainer.withValues(
                        alpha: 0.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: AppColors.stitchPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tải ảnh từ máy (JPG, PNG, WebP)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dùng Canvas Studio để chuyển ảnh và nạp bitmap tối đa 128 byte',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. BOTTOM MAIN ACTION TRIGGER (BLE SYNC)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBottomSyncAction(SppService spp) {
    final isConnected = spp.isConnected;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isConnected
                    ? const [
                        AppColors.stitchPrimaryContainer,
                        AppColors.stitchSecondaryContainer,
                      ]
                    : [
                        AppColors.stitchSurfaceHighest,
                        AppColors.stitchSurfaceContainer,
                      ],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: AppColors.stitchPrimaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: _sending ? null : () => _apply(spp),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_sending)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(
                      isConnected
                          ? Icons.bluetooth_drive_rounded
                          : Icons.bluetooth_disabled_rounded,
                      color: isConnected
                          ? AppColors.stitchOnPrimaryContainer
                          : AppColors.stitchOutline,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _sending
                        ? 'Đang truyền tải BLE (Packet 4/12)...'
                        : isConnected
                        ? "Cài Đặt '${_selected.name}' (Gửi BLE 2.8s)"
                        : 'Cài Đặt Màn Hình Chờ (Chưa kết nối)',
                    style: GoogleFonts.outfit(
                      color: isConnected
                          ? AppColors.stitchOnPrimaryContainer
                          : AppColors.stitchOutline,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_clock_rounded,
              color: AppColors.stitchOnSurfaceVariant,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              'Bộ nhớ đệm ROM đồng hồ còn 14/16 slots lưu trữ offline',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchOnSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS: DITHER GRAIN & FLOYD-STEINBERG SIMULATION
// ─────────────────────────────────────────────────────────────────────────────

class _DitherPixelGrainPainter extends CustomPainter {
  final Color color;
  _DitherPixelGrainPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 0.8;

    const step = 4.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if ((x + y).toInt() % 8 == 0) {
          canvas.drawCircle(Offset(x, y), 0.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DitherPixelGrainPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DitherMatrixSimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF121410).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final rng = math.Random(1337);
    for (int i = 0; i < 400; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
