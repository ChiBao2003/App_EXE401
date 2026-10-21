import 'dart:math';
// ==========================================
// WEEKLY_SCHEDULE_SCREEN — Aether Synapse (Stitch Screen 8)
// Stitch Project ID: 10749545399411306725
// Stitch Screen ID: 416074673ea847138f00e795fce3d371
// Route: /schedule
// ==========================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/bluetooth/spp_service.dart';
import '../../core/display/tft_layout.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

String get schedulesApiUrl => '${AppConstants.baseUrl}/api/v1/schedules';

/// Entity lưu trữ lịch trình một khung giờ
class ScheduleItem {
  final String id;
  final String dayOfWeek; // 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  final int hour;
  final int minute;
  final String label;
  bool isActive;

  ScheduleItem({
    required this.id,
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
    required this.label,
    this.isActive = true,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      dayOfWeek: json['day_of_week']?.toString() ?? 'Mon',
      hour: (json['hour'] is num) ? json['hour'].toInt() : 8,
      minute: (json['minute'] is num) ? json['minute'].toInt() : 0,
      label: json['label']?.toString() ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'hour': hour,
      'minute': minute,
      'label': label,
    };
  }

  String get timeFormatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Màn hình Lịch Nhắc Nhở Tuần thông minh theo chuẩn Aether Synapse
class WeeklyScheduleScreen extends StatefulWidget {
  final List<dynamic>? initialSchedules;
  final int? initialSelectedDayIndex;
  final http.Client? httpClient;

  const WeeklyScheduleScreen({
    super.key,
    this.initialSchedules,
    this.initialSelectedDayIndex,
    this.httpClient,
  });

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  static const List<String> _dayCodes = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _dayShortNames = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];
  static const List<String> _dayFullNames = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  late int _selectedDayIndex;
  List<ScheduleItem> _allSchedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Toggle state per day
  final Map<int, bool> _dayEnabled = {
    0: true,
    1: true,
    2: true,
    3: true,
    4: true,
    5: true,
    6: true,
  };

  late http.Client _client;

  @override
  void initState() {
    super.initState();
    _client = widget.httpClient ?? http.Client();

    // Default to current weekday (Mon = 0 ... Sun = 6)
    final todayIndex = DateTime.now().weekday - 1;
    _selectedDayIndex =
        widget.initialSelectedDayIndex ??
        (todayIndex >= 0 && todayIndex < 7 ? todayIndex : 2);

    if (widget.initialSchedules != null) {
      _allSchedules = widget.initialSchedules!
          .map(
            (item) => item is ScheduleItem
                ? item
                : ScheduleItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } else {
      _fetchSchedules();
    }
  }

  @override
  void dispose() {
    if (widget.httpClient == null) {
      _client.close();
    }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // BACKEND API CALLS (/api/v1/schedules)
  // ══════════════════════════════════════════════════════════

  Future<Map<String, String>> _headers() async {
    final headers = {'Content-Type': 'application/json'};
    if (widget.httpClient != null) {
      return headers;
    }
    try {
      final token = await ApiClient.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Future<void> _fetchSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _client.get(
        Uri.parse('$schedulesApiUrl/'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _allSchedules = data
              .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      } else {
        setState(() {
          _errorMessage = 'Không thể tải lịch nhắc nhở (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối tới máy chủ khi tải lịch';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createSchedule({
    required String dayOfWeek,
    required int hour,
    required int minute,
    required String label,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.post(
        Uri.parse('$schedulesApiUrl/'),
        headers: await _headers(),
        body: jsonEncode({
          'day_of_week': dayOfWeek,
          'hour': hour,
          'minute': minute,
          'label': label,
        }),
      );

      if (res.statusCode == 200) {
        _showToast('Đã thêm lịch nhắc nhở mới!');
        await _fetchSchedules();
        if (mounted && context.read<BleService>().isConnected) {
          await _syncToEsp32();
        }
      } else {
        _showToast('Không thể tạo lịch (${res.statusCode})', isError: true);
      }
    } catch (e) {
      _showToast('Lỗi kết nối khi tạo lịch', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSchedule(String id) async {
    if (id.isEmpty) return;
    try {
      final res = await _client.delete(
        Uri.parse('$schedulesApiUrl/$id'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        _showToast('Đã xóa khung giờ!');
        setState(() {
          _allSchedules.removeWhere((item) => item.id == id);
        });
        if (mounted && context.read<BleService>().isConnected) {
          await _syncToEsp32();
        }
      } else {
        _showToast('Không thể xóa lịch (${res.statusCode})', isError: true);
      }
    } catch (e) {
      _showToast('Lỗi kết nối khi xóa lịch', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════════
  // HARDWARE BLE SYNC
  // ══════════════════════════════════════════════════════════

  Future<void> _syncToEsp32() async {
    try {
      final spp = context.read<SppService>();
      for (var dayIndex = 0; dayIndex < _dayCodes.length; dayIndex++) {
        final day = _dayCodes[dayIndex];
        final items =
            (_dayEnabled[dayIndex] == false
                  ? <ScheduleItem>[]
                  : _allSchedules
                        .where(
                          (entry) =>
                              entry.dayOfWeek.toLowerCase() ==
                                  day.toLowerCase() &&
                              entry.isActive,
                        )
                        .toList())
              ..sort((a, b) => a.timeFormatted.compareTo(b.timeFormatted));
        await spp.syncSchedule(
          day,
          items.map((entry) => entry.toJson()).toList(),
        );
      }
      if (mounted) {
        _showToast(
          'ESP32 đã xác nhận lưu đủ 7 ngày lịch tuần',
          isSuccessBadge: true,
        );
      }
    } catch (e) {
      if (mounted) _showToast('Không thể đồng bộ: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════

  List<ScheduleItem> get _currentDaySchedules {
    final currentCode = _dayCodes[_selectedDayIndex];
    return _allSchedules
        .where((s) => s.dayOfWeek.toLowerCase() == currentCode.toLowerCase())
        .toList()
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
  }

  void _showToast(
    String message, {
    bool isError = false,
    bool isSuccessBadge = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : isSuccessBadge
                  ? Icons.bolt_rounded
                  : Icons.check_circle_rounded,
              color: isError
                  ? AppColors.stitchError
                  : isSuccessBadge
                  ? AppColors.stitchSecondaryContainer
                  : AppColors.stitchTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.stitchOnSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccessBadge
            ? AppColors.stitchTertiaryContainer
            : AppColors.stitchSurfaceBright,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddSlotDialog() {
    final titleCtrl = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.stitchSurfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final timeStr =
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.stitchOutlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Thêm Khung Giờ Mới',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Khung giờ cho ${_dayFullNames[_selectedDayIndex]}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Label input
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.stitchOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Nội dung nhắc nhở',
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                      hintText: 'Ví dụ: Học môn Hệ điều hành - Phòng B201',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: AppColors.stitchOutline,
                      ),
                      filled: true,
                      fillColor: AppColors.stitchSurfaceLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.stitchPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Time Picker Button
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: AppColors.stitchSecondaryContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Thời gian bắt đầu:',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.stitchOnSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              timeStr,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stitchSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  ElevatedButton(
                    key: const Key('btnConfirmAddSlot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stitchPrimaryContainer,
                      foregroundColor: AppColors.stitchOnPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final label = titleCtrl.text.trim();
                      if (label.isEmpty) {
                        _showToast(
                          'Vui lòng nhập nội dung nhắc nhở',
                          isError: true,
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _createSchedule(
                        dayOfWeek: _dayCodes[_selectedDayIndex],
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                        label: label,
                      );
                    },
                    child: Text(
                      'Lưu Khung Giờ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // UI BUILD METHOD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    BleService? ble;
    try {
      ble = context.watch<BleService>();
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(ble),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.stitchPrimaryContainer,
                backgroundColor: AppColors.stitchSurfaceContainer,
                onRefresh: _fetchSchedules,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Interactive Ambient Aura Card (Hero Bento Card)
                      _buildHeroBentoCard(ble),
                      const SizedBox(height: 16),

                      // 2. Day Selector Horizontal Strip (T2 -> CN)
                      _buildDaySelectorStrip(),
                      const SizedBox(height: 16),

                      // 3. Day Configuration Card (Timeline Slots)
                      _buildDayConfigurationCard(),
                      const SizedBox(height: 16),

                      // 4. Live Simulated TFT LCD Watch Display Preview (320×240)
                      _buildTftWatchPreview(ble),
                      const SizedBox(height: 20),

                      // 5. Primary Push / Sync Action Button
                      _buildPushScheduleButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 1. Top App Bar (Header)
  // ──────────────────────────────────────────────────────────
  Widget _buildTopAppBar(BleService? ble) {
    final isBleOnline = ble?.isConnected ?? false;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.stitchSurface.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppColors.stitchSurfaceLow, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.stitchOnSurface,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.memory_rounded,
                  color: AppColors.stitchSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isBleOnline
                              ? AppColors.stitchSecondaryContainer
                              : AppColors.stitchOutline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBleOnline ? 'ESP32 LIVE' : 'OFFLINE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isBleOnline
                              ? AppColors.stitchSecondary
                              : AppColors.stitchOutline,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Lịch Tuần',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stitchOnSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Battery badge & user avatar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppColors.stitchTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isBleOnline ? '98%' : '--',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.stitchPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: Color(0xFF370096),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 2. Hero Bento Card
  // ──────────────────────────────────────────────────────────
  Widget _buildHeroBentoCard(BleService? ble) {
    final isBleOnline = ble?.isConnected ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isBleOnline
                              ? AppColors.stitchSecondary
                              : AppColors.stitchOutline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isBleOnline ? 'BLE v5.2 Active' : 'BLE Disconnected',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isBleOnline
                              ? AppColors.stitchSecondary
                              : AppColors.stitchOutline,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lịch Nhắc Nhở Tuần',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                ],
              ),
              InkWell(
                key: const Key('quickSyncBtn'),
                onTap: _syncToEsp32,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchPrimaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.stitchPrimaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: AppColors.stitchSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đồng bộ ESP32',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stitchOnPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Telemetry hardware micro-strip
          Row(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.memory_rounded,
                    size: 15,
                    color: AppColors.stitchTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SRAM: 312KB rảnh',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(
                    Icons.wifi_tethering_rounded,
                    size: 15,
                    color: AppColors.stitchSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isBleOnline ? 'RSSI: -58dBm (Tốt)' : 'RSSI: N/A',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 3. Day Selector Horizontal Strip
  // ──────────────────────────────────────────────────────────
  Widget _buildDaySelectorStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CHỌN NGÀY CẬP NHẬT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.stitchOnSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Chu kỳ 7 ngày',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stitchPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(7, (index) {
            final isSelected = _selectedDayIndex == index;
            final shortName = _dayShortNames[index];
            final todayIndex = DateTime.now().weekday - 1;
            final isToday = index == todayIndex;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 6 ? 6 : 0),
                child: InkWell(
                  key: Key('dayTab_$shortName'),
                  onTap: () {
                    setState(() => _selectedDayIndex = index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.stitchPrimary
                          : AppColors.stitchSurfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.stitchPrimary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shortName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF20005F)
                                : isToday
                                ? AppColors.stitchSecondaryContainer
                                : AppColors.stitchOnSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.stitchSecondaryContainer
                                : isToday
                                ? AppColors.stitchSecondaryContainer
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // 4. Day Configuration Card (Timeline Slots)
  // ──────────────────────────────────────────────────────────
  Widget _buildDayConfigurationCard() {
    final dayFullName = _dayFullNames[_selectedDayIndex];
    final todayIndex = DateTime.now().weekday - 1;
    final isToday = _selectedDayIndex == todayIndex;
    final currentSlots = _currentDaySchedules;
    final isDayActive = _dayEnabled[_selectedDayIndex] ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Day Name + Toggle Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isToday ? '$dayFullName (Hôm nay)' : dayFullName,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${currentSlots.length} phiên đồng bộ sẵn sàng',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Switch(
                key: const Key('dayToggle'),
                value: isDayActive,
                activeThumbColor: AppColors.stitchSecondaryContainer,
                activeTrackColor: AppColors.stitchPrimaryContainer,
                inactiveThumbColor: AppColors.stitchOnSurfaceVariant,
                inactiveTrackColor: AppColors.stitchSurfaceHighest,
                onChanged: (val) {
                  setState(() => _dayEnabled[_selectedDayIndex] = val);
                  _showToast(
                    val
                        ? 'Đã bật lịch cho $dayFullName'
                        : 'Đã tắt lịch cho $dayFullName',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Loading / Error or Empty or Slot List
          if (_isLoading && _allSchedules.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                color: AppColors.stitchPrimaryContainer,
              ),
            )
          else if (_errorMessage != null && _allSchedules.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.stitchErrorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.stitchError,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.stitchError,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchSchedules,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else if (currentSlots.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(
                    Icons.event_busy_rounded,
                    color: AppColors.stitchOutline,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chưa có khung giờ nhắc nhở cho $dayFullName',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bấm "Thêm khung giờ mới" bên dưới để thiết lập',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentSlots.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final slot = currentSlots[i];
                return _buildSlotCard(slot);
              },
            ),
          const SizedBox(height: 10),

          // Add New Slot CTA Button
          InkWell(
            key: const Key('btnAddSlot'),
            onTap: _showAddSlotDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 18,
                    color: AppColors.stitchPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Thêm khung giờ mới',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchPrimary,
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

  Widget _buildSlotCard(ScheduleItem slot) {
    // Dynamic styling based on label
    final labelLower = slot.label.toLowerCase();
    Color tagColor = AppColors.stitchPrimaryContainer;
    Color tagTextColor = AppColors.stitchOnPrimaryContainer;
    String tagLabel = 'Lịch học';
    IconData categoryIcon = Icons.menu_book_rounded;
    Color timeColor = AppColors.stitchPrimary;

    if (labelLower.contains('quan trọng') ||
        labelLower.contains('thi') ||
        labelLower.contains('hệ điều hành')) {
      tagColor = AppColors.stitchErrorContainer;
      tagTextColor = const Color(0xFFFFDAD6);
      tagLabel = 'Quan trọng';
      timeColor = AppColors.stitchPrimary;
      categoryIcon = Icons.menu_book_rounded;
    } else if (labelLower.contains('deep') ||
        labelLower.contains('ôn tập') ||
        labelLower.contains('cấu trúc')) {
      tagColor = AppColors.stitchPrimaryContainer;
      tagTextColor = AppColors.stitchOnPrimaryContainer;
      tagLabel = 'Deep Work';
      timeColor = AppColors.stitchSecondary;
      categoryIcon = Icons.psychology_rounded;
    } else if (labelLower.contains('lab') ||
        labelLower.contains('iot') ||
        labelLower.contains('thực hành')) {
      tagColor = AppColors.stitchTertiaryContainer;
      tagTextColor = const Color(0xFFE1FFEC);
      tagLabel = 'Thực hành';
      timeColor = AppColors.stitchTertiary;
      categoryIcon = Icons.terminal_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(categoryIcon, size: 16, color: timeColor),
                  const SizedBox(width: 6),
                  Text(
                    slot.timeFormatted,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: timeColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tagLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: tagTextColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    key: Key('btnDelete_${slot.id}'),
                    onTap: () => _deleteSchedule(slot.id),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            slot.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.stitchOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    size: 13,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Rung 2 nhịp trước 10p',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: AppColors.stitchOutlineVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // 5. Live Simulated TFT LCD Watch Display Preview (320×240)
  // ──────────────────────────────────────────────────────────
  Widget _buildTftWatchPreview(BleService? ble) {
    final items = <Map<String, dynamic>>[
      {
        't': 'text',
        'v': 'LICH ${_dayCodes[_selectedDayIndex]}',
        'x': 12,
        'y': 12,
        'w': 290,
        'h': 24,
        's': 2,
        'c': 0x07ff,
      },
      for (var i = 0; i < _currentDaySchedules.length && i < 7; i++)
        {
          't': 'text',
          'v':
              '${_currentDaySchedules[i].timeFormatted} ${lcdText(_currentDaySchedules[i].label).substring(0, min(35, lcdText(_currentDaySchedules[i].label).length))}',
          'x': 12,
          'y': 48 + i * 24,
          'w': 296,
          'h': 20,
          's': 1,
          'c': _currentDaySchedules[i].isActive ? 0xffff : 0x8410,
        },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Bản xem trước TFT LCD · 320×240 RGB565'),
        const SizedBox(height: 8),
        TftPreview(design: {'background': 0, 'elements': items}),
        const Text(
          'Lịch được lưu trong NVS; RTC DS3231 kích hoạt chuông đến giờ.',
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // 6. Primary Push / Sync Action Button
  // ──────────────────────────────────────────────────────────
  Widget _buildPushScheduleButton() {
    return InkWell(
      key: const Key('pushScheduleBtn'),
      onTap: _syncToEsp32,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.stitchPrimaryContainer,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_sync_rounded,
              size: 24,
              color: AppColors.stitchSecondary,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lưu và nạp vào đồng hồ',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stitchOnPrimaryContainer,
                  ),
                ),
                Text(
                  'Push via BLE • Bộ nhớ NOR Flash 256MB',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stitchSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// WEEKLY_SCHEDULE_SCREEN_END
// ==========================================
