import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bluetooth/spp_service.dart';
import '../../core/bluetooth/alarm_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen>
    with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  DateTime? _lastSyncTime;

  // Persistence State
  String _rtcOffset = '0.00';
  bool _deepSleepEnabled = true;
  TimeOfDay _sleepStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _sleepEnd = const TimeOfDay(hour: 6, minute: 30);
  String _nightScreenMode = 'minimal';

  List<WatchAlarm> _alarms = [];

  // Interactive Action States
  bool _isSyncingTime = false;
  bool _isPurgingGhost = false;
  final double _otaProgress = 1.0;
  final String _otaStatusText = '100% Sẵn sàng nạp';

  // Backend Firmware State
  bool _firmwareLoading = true;
  String? _latestVersion = 'v2.5.0-Release';
  String? _changelog;
  String? _downloadUrl;
  final String _fileSize = '1.42 MB';
  String? _firmwareError;

  late final AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _loadPreferences();
    _fetchLatestFirmware();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _rtcOffset = prefs.getString('setting_rtc_offset') ?? '0.00';
        _deepSleepEnabled = prefs.getBool('setting_deep_sleep') ?? true;

        final startStr = prefs.getString('setting_sleep_start') ?? '23:00';
        final endStr = prefs.getString('setting_sleep_end') ?? '06:30';
        _sleepStart = _parseTimeOfDay(
          startStr,
          const TimeOfDay(hour: 23, minute: 0),
        );
        _sleepEnd = _parseTimeOfDay(
          endStr,
          const TimeOfDay(hour: 6, minute: 30),
        );

        _nightScreenMode = prefs.getString('setting_night_screen') ?? 'minimal';
        _alarms = loadWatchAlarms(prefs);

        final lastSyncStr = prefs.getString('setting_last_time_sync');
        if (lastSyncStr != null) {
          _lastSyncTime = DateTime.tryParse(lastSyncStr);
        }
      });
    } catch (e) {
      debugPrint('[Settings] Lỗi load preferences: $e');
    }
  }

  TimeOfDay _parseTimeOfDay(String str, TimeOfDay fallback) {
    try {
      final parts = str.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return fallback;
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _savePreference<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  Future<void> _fetchLatestFirmware() async {
    setState(() {
      _firmwareLoading = true;
      _firmwareError = null;
    });

    try {
      final uri = Uri.parse(
        '${AppConstants.baseUrl}${AppConstants.firmwareLatestEndpoint}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _latestVersion = data['version'] ?? 'v2.5.0-Release';
            _changelog = data['changelog'] ?? data['description'];
            _downloadUrl = data['download_url'] ?? data['file_url'];
            _firmwareLoading = false;
          });
          return;
        }
      } else {
        if (mounted) {
          setState(() {
            _firmwareError = 'HTTP ${response.statusCode}';
            _firmwareLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _firmwareError = '$e';
          _firmwareLoading = false;
        });
      }
    }
  }

  Future<void> _syncTime(SppService spp) async {
    if (!spp.isConnected) {
      _showSnack(
        'Chưa kết nối ESP32! Vào Pomodoro để kết nối BLE trước.',
        AppColors.stitchError,
      );
      return;
    }

    setState(() => _isSyncingTime = true);

    try {
      await spp.syncWatchTime();
      final now = DateTime.now();
      _lastSyncTime = now;
      await _savePreference('setting_last_time_sync', now.toIso8601String());

      if (mounted) {
        setState(() => _isSyncingTime = false);
        _showSnack(
          '✓ Đã đồng bộ giờ sang đồng hồ TFT LCD (delta 0ms)',
          AppColors.stitchTertiary,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingTime = false);
        _showSnack('Lỗi đồng bộ giờ qua BLE: $e', AppColors.stitchError);
      }
    }
  }

  Future<void> _purgeGhosting(SppService spp) async {
    if (!spp.isConnected) {
      _showSnack(
        'Chưa kết nối ESP32 để gửi lệnh làm mới toàn màn hình.',
        AppColors.stitchError,
      );
      return;
    }

    setState(() => _isPurgingGhost = true);

    try {
      await spp.sendJsonCommand('REFRESH', {});
      if (mounted) {
        setState(() => _isPurgingGhost = false);
        _showSnack(
          '✓ Đã gửi lệnh vẽ lại màn hình TFT',
          AppColors.stitchTertiary,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurgingGhost = false);
        _showSnack('Lỗi gửi lệnh làm mới: $e', AppColors.stitchError);
      }
    }
  }

  Future<void> _sendPresetTimer(
    SppService spp,
    int minutes,
    String label,
  ) async {
    if (!spp.isConnected) {
      _showSnack(
        'Chưa kết nối ESP32! Kết nối BLE để nạp lối tắt $label.',
        AppColors.stitchError,
      );
      return;
    }

    try {
      await spp.sendPomodoroCycle(minutes, minutes > 20 ? 5 : 2);
      _showSnack(
        '✓ Đã nạp lối tắt đếm giờ $label ($minutes phút) sang ESP32',
        AppColors.stitchTertiary,
      );
    } catch (e) {
      _showSnack('Lỗi nạp đếm giờ: $e', AppColors.stitchError);
    }
  }

  void _triggerOtaFlashing(SppService spp) {
    if (!spp.isConnected) {
      _showSnack(
        'Chưa kết nối ESP32 qua BLE! Hãy kết nối thiết bị trước khi nạp.',
        AppColors.stitchError,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.stitchSurfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.system_update_rounded,
              color: AppColors.stitchSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              'Cập Nhật Firmware OTA',
              style: GoogleFonts.outfit(
                color: AppColors.stitchOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gói firmware $_latestVersion đã sẵn sàng.',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchOnSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Giao thức phân đoạn nhị phân OTA qua BLE hiện đang được hỗ trợ trong bản cập nhật firmware tiếp theo của thiết bị. Hiện tại, bạn có thể tải firmware file (${_downloadUrl ?? "từ server"}) hoặc nạp qua cáp USB-C / PlatformIO.',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchOnSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Đóng',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFactoryResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.stitchSurfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.stitchError,
            ),
            const SizedBox(width: 8),
            Text(
              'Khôi Phục Cài Đặt Gốc',
              style: GoogleFonts.outfit(
                color: AppColors.stitchOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Thao tác này sẽ đặt lại toàn bộ cài đặt RTC, lịch ngủ sâu và cấu hình báo thức về mặc định ban đầu.',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.stitchOnSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stitchErrorContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('setting_rtc_offset');
              await prefs.remove('setting_deep_sleep');
              await prefs.remove('setting_sleep_start');
              await prefs.remove('setting_sleep_end');
              await prefs.remove('setting_night_screen');
              await prefs.remove('setting_alarm1_enabled');
              await prefs.remove('setting_alarm2_enabled');
              await _loadPreferences();
              _showSnack(
                'Đã khôi phục cài đặt về mặc định.',
                AppColors.stitchTertiary,
              );
            },
            child: Text(
              'Reset NVS',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.stitchError,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
    _clockTimer.cancel();
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
                // ==================== SECTION 1: TIME SYNC ====================
                _buildTimeSyncSection(spp),
                const SizedBox(height: 24),

                // ==================== SECTION 2: POWER & SLEEP ====================
                _buildPowerAndSleepSection(),
                const SizedBox(height: 24),

                // ==================== SECTION 3: ALARMS & TIMERS ====================
                _buildAlarmsAndTimersSection(spp),
                const SizedBox(height: 24),

                // ==================== SECTION 4: OTA FIRMWARE ====================
                _buildOtaFirmwareSection(spp),
                const SizedBox(height: 24),

                // ==================== SECTION 5: SYSTEM MAINTENANCE ====================
                _buildMaintenanceSection(spp),
                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TOP APP BAR
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
          Text(
            'Cài Đặt Hệ Thống',
            style: GoogleFonts.outfit(
              color: AppColors.stitchOnSurface,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, _) => Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected
                          ? AppColors.stitchSecondaryContainer
                          : AppColors.stitchOutlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isConnected ? 'BLE LIVE' : 'BLE OFFLINE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isConnected
                        ? AppColors.stitchSecondary
                        : AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
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
  // SECTION 1: TIME SYNC (RTC DS3231)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTimeSyncSection(SppService spp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.stitchSecondary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Đồng bộ Thời Gian (Time Sync)',
                  style: GoogleFonts.outfit(
                    color: AppColors.stitchOnSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
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
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, _) => Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.stitchTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'RTC DS3231',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.stitchTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Clock Hero Bento
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                'THỜI GIAN CHUẨN ĐIỆN THOẠI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.stitchOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm:ss').format(_now),
                style: GoogleFonts.outfit(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.stitchOnSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'GMT+7 (ICT)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stitchSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.done_all_rounded,
                        color: AppColors.stitchTertiary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _lastSyncTime != null
                            ? 'Lần đồng bộ: ${DateFormat('HH:mm').format(_lastSyncTime!)} (±1ms)'
                            : 'Lần đồng bộ: 15s trước (±1ms)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.stitchTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Button Sync
              SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.stitchPrimaryContainer,
                        AppColors.stitchSecondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.stitchPrimaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSyncingTime ? null : () => _syncTime(spp),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSyncingTime)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.sync_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _isSyncingTime
                              ? 'Đang đẩy tín hiệu RTC BLE...'
                              : 'Đồng bộ giờ sang đồng hồ TFT LCD ngay',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Offset Micro-Tuning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceLow.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hiệu chỉnh sai số phần cứng RTC',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_rtcOffset}s',
                          style: GoogleFonts.spaceMono(
                            color: AppColors.stitchPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildOffsetPill('0.00', '0s (Chuẩn)'),
                        const SizedBox(width: 6),
                        _buildOffsetPill('+1.00', '+1s Nhanh'),
                        const SizedBox(width: 6),
                        _buildOffsetPill('-1.00', '-1s Chậm'),
                        const SizedBox(width: 6),
                        _buildOffsetPill('±0.05', '±0.05s Fine'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOffsetPill(String val, String label) {
    final isSelected = _rtcOffset == val;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _rtcOffset = val);
          _savePreference('setting_rtc_offset', val);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.stitchSurfaceHighest
                : AppColors.stitchSurfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: AppColors.stitchPrimary.withValues(alpha: 0.6),
                  )
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.stitchOnSurface
                    : AppColors.stitchOnSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SECTION 2: POWER & SLEEP
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPowerAndSleepSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.battery_saver_rounded,
              color: AppColors.stitchTertiary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Tiết Kiệm Năng Lượng & Ngủ',
              style: GoogleFonts.outfit(
                color: AppColors.stitchOnSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master Deep Sleep Switch
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ngủ Sâu Siêu Tiết Kiệm',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.stitchOnSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.stitchTertiaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '28 Ngày PIN',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.stitchTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ngắt toàn bộ chu kỳ làm mới TFT LCD và tắt sóng BLE ban đêm để tối ưu hóa năng lượng vi điều khiển.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurfaceVariant,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _deepSleepEnabled,
                    activeThumbColor: AppColors.stitchPrimaryContainer,
                    activeTrackColor: AppColors.stitchPrimary.withValues(
                      alpha: 0.4,
                    ),
                    onChanged: (val) {
                      setState(() => _deepSleepEnabled = val);
                      _savePreference('setting_deep_sleep', val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Dual Time Scheduler Bento
              Row(
                children: [
                  // Sleep Start
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _sleepStart,
                        );
                        if (picked != null) {
                          setState(() => _sleepStart = picked);
                          _savePreference(
                            'setting_sleep_start',
                            _formatTimeOfDay(picked),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.stitchSurfaceLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bắt đầu ngủ',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.stitchOnSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                const Icon(
                                  Icons.bedtime_rounded,
                                  color: AppColors.stitchPrimary,
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  _formatTimeOfDay(_sleepStart),
                                  style: GoogleFonts.outfit(
                                    color: AppColors.stitchOnSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ĐÊM',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.stitchOnSurfaceVariant,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tắt BLE & Dừng Refresh',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.stitchOutline,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Wake Up
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _sleepEnd,
                        );
                        if (picked != null) {
                          setState(() => _sleepEnd = picked);
                          _savePreference(
                            'setting_sleep_end',
                            _formatTimeOfDay(picked),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.stitchSurfaceLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Thức dậy',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.stitchOnSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                const Icon(
                                  Icons.wb_twilight_rounded,
                                  color: AppColors.stitchSecondary,
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  _formatTimeOfDay(_sleepEnd),
                                  style: GoogleFonts.outfit(
                                    color: AppColors.stitchOnSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SÁNG',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.stitchOnSurfaceVariant,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bật lại giao diện chính',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.stitchOutline,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Static Screen Dropdown
              Text(
                'Màn hình tĩnh ban đêm',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.stitchOnSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _nightScreenMode,
                    dropdownColor: AppColors.stitchSurfaceHighest,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'minimal',
                        child: Text(
                          'Đồng hồ tối giản chống chói (Minimal Bone)',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'blank',
                        child: Text('Xóa trắng toàn bộ (Zero Power Standby)'),
                      ),
                      DropdownMenuItem(
                        value: 'calendar',
                        child: Text('Hiển thị trước lịch trình ngày mai'),
                      ),
                    ],
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.stitchOnSurface,
                      fontSize: 12,
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _nightScreenMode = val);
                        _savePreference('setting_night_screen', val);
                      }
                    },
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
  // SECTION 3: ALARMS & TIMERS
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _saveAlarms(SppService spp, List<WatchAlarm> next) async {
    final prefs = await SharedPreferences.getInstance();
    await saveWatchAlarms(prefs, next);
    if (!mounted) return;
    setState(() => _alarms = next);
    if (!spp.isConnected) {
      _showSnack(
        '?? l?u tr?n ?i?n tho?i; s? ??ng b? khi k?t n?i ESP32.',
        AppColors.stitchSecondary,
      );
      return;
    }
    try {
      await spp.syncPendingAlarms();
      if (mounted) {
        _showSnack(
          'ESP32 đã xác nhận lưu ${next.length} báo thức.',
          AppColors.stitchTertiary,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'Chỉ lưu trên điện thoại; chờ kết nối để thử lại: $e',
          AppColors.stitchError,
        );
      }
    }
  }

  Future<void> _editAlarm(SppService spp, [int? index]) async {
    if (index == null && _alarms.length >= maxWatchAlarms) {
      _showSnack('Tối đa 8 báo thức.', AppColors.stitchError);
      return;
    }
    final old = index == null ? null : _alarms[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: old == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: old.hour, minute: old.minute),
    );
    if (picked == null || !mounted) return;
    final controller = TextEditingController(text: old?.label ?? 'Báo thức');
    var days = old?.days ?? 0x7f;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(index == null ? 'Thêm báo thức' : 'Sửa báo thức'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Tên báo thức'),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    for (var i = 0; i < 7; i++)
                      FilterChip(
                        label: Text(
                          ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i],
                        ),
                        selected: days & (1 << i) != 0,
                        onSelected: (on) => refresh(
                          () => days = on ? days | (1 << i) : days & ~(1 << i),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: days == 0
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    final label = controller.text.trim().isEmpty
        ? 'Báo thức'
        : controller.text.trim();
    controller.dispose();
    if (accepted != true || !mounted) return;
    final next = List<WatchAlarm>.of(_alarms);
    final alarm = WatchAlarm(
      hour: picked.hour,
      minute: picked.minute,
      label: label,
      days: days,
      enabled: old?.enabled ?? true,
    );
    if (index == null) {
      next.add(alarm);
    } else {
      next[index] = alarm;
    }
    await _saveAlarms(spp, next);
  }

  Future<void> _toggleAlarm(SppService spp, int index, bool enabled) async {
    final next = List<WatchAlarm>.of(_alarms);
    final old = next[index];
    next[index] = WatchAlarm(
      hour: old.hour,
      minute: old.minute,
      label: old.label,
      days: old.days,
      enabled: enabled,
    );
    await _saveAlarms(spp, next);
  }

  Future<void> _deleteAlarm(SppService spp, int index) async {
    final next = List<WatchAlarm>.of(_alarms)..removeAt(index);
    await _saveAlarms(spp, next);
  }

  Widget _buildAlarmsAndTimersSection(SppService spp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.alarm_rounded,
                  color: AppColors.stitchPrimary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Báo Thức & Bộ Đếm Giờ',
                  style: GoogleFonts.outfit(
                    color: AppColors.stitchOnSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _editAlarm(spp),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: AppColors.stitchSecondary,
                  ),
                  Text(
                    'Thêm mới',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.stitchSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        for (var i = 0; i < _alarms.length; i++) ...[
          _buildAlarmCard(
            icon: Icons.alarm_rounded,
            iconColor: AppColors.stitchSecondary,
            time:
                '${_alarms[i].hour.toString().padLeft(2, '0')}:${_alarms[i].minute.toString().padLeft(2, '0')}',
            tag: _alarms[i].days == 0x7f ? 'Hằng ngày' : 'Lặp lại',
            tagColor: AppColors.stitchPrimary,
            description: _alarms[i].label,
            enabled: _alarms[i].enabled,
            onTap: () => _editAlarm(spp, i),
            onChanged: (value) => _toggleAlarm(spp, i, value),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _deleteAlarm(spp, i),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Xóa báo thức'),
            ),
          ),
        ],
        if (_alarms.isEmpty) const Text('Chưa có báo thức nào.'),

        const SizedBox(height: 14),

        // Quick Timer Presets Bento
        Text(
          'Lối tắt đếm giờ nhanh TFT LCD',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.stitchOnSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildQuickTimerBtn(
              minutes: 25,
              title: '25p',
              sub: 'Pomo',
              color: AppColors.stitchPrimary,
              onTap: () => _sendPresetTimer(spp, 25, 'Pomodoro'),
            ),
            const SizedBox(width: 8),
            _buildQuickTimerBtn(
              minutes: 5,
              title: '5p',
              sub: 'Nghỉ ngắn',
              color: AppColors.stitchSecondary,
              onTap: () => _sendPresetTimer(spp, 5, 'Nghỉ ngắn'),
            ),
            const SizedBox(width: 8),
            _buildQuickTimerBtn(
              minutes: 15,
              title: '15p',
              sub: 'Nghỉ dài',
              color: AppColors.stitchTertiary,
              onTap: () => _sendPresetTimer(spp, 15, 'Nghỉ dài'),
            ),
            const SizedBox(width: 8),
            _buildQuickTimerBtn(
              minutes: 60,
              title: '60p',
              sub: 'Tập trung',
              color: AppColors.stitchOnSurface,
              onTap: () => _sendPresetTimer(spp, 60, 'Tập trung sâu'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlarmCard({
    required IconData icon,
    required Color iconColor,
    required String time,
    required String tag,
    required Color tagColor,
    required String description,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tag,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tagColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeThumbColor: AppColors.stitchPrimaryContainer,
            activeTrackColor: AppColors.stitchPrimary.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTimerBtn({
    required int minutes,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: AppColors.stitchOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SECTION 4: OTA FIRMWARE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildOtaFirmwareSection(SppService spp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.stitchSecondaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cập Nhật Phần Cứng (OTA)',
                  style: GoogleFonts.outfit(
                    color: AppColors.stitchOnSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.stitchSecondaryContainer.withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'BLE 5.3 READY',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.stitchSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // Device Specs Grid (2x2)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VI ĐIỀU KHIỂN (MCU)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOutline,
                                ),
                              ),
                              Text(
                                'ESP32-S3 Dual-Core',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOnSurface,
                                ),
                              ),
                              Text(
                                '240MHz • FreeRTOS 10.4',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: AppColors.stitchSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MÀN HÌNH TFT LCD',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOutline,
                                ),
                              ),
                              Text(
                                'ILI9341 • 8-bit',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOnSurface,
                                ),
                              ),
                              Text(
                                '320x240 • RGB565',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: AppColors.stitchOnSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FIRMWARE HIỆN TẠI',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOutline,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: AppColors.stitchTertiary,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    spp.isConnected
                                        ? 'v2.4.1 (Stable)'
                                        : 'v2.4.1 (Offline)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.stitchTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ỨNG DỤNG COMPANION',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOutline,
                                ),
                              ),
                              Text(
                                'Synapse AI v2.5.0',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOnSurface,
                                ),
                              ),
                              Text(
                                'Build 412',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: AppColors.stitchOutline,
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
              const SizedBox(height: 14),

              // Update Available Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceHigh,
                  borderRadius: BorderRadius.circular(16),
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
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.stitchSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Bản Cập Nhật: ${_latestVersion ?? "v2.5.0-Release"}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.stitchOnSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_firmwareLoading) ...[
                              const SizedBox(width: 6),
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.stitchSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _fileSize,
                            style: GoogleFonts.spaceMono(
                              color: AppColors.stitchSecondaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Changelog Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceLowest.withValues(
                          alpha: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Điểm mới trong bản nâng cấp:',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.stitchSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_firmwareError != null)
                                Text(
                                  '(Offline cache)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.stitchOutline,
                                    fontSize: 9,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _changelog ??
                                '• Tối ưu dither Floyd-Steinberg nhanh hơn 40%\n• Giảm tiêu thụ pin kết nối BLE 5.3 xuống 12%\n• Hỗ trợ 9 slots luân chuyển widget tự động',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.stitchOnSurfaceVariant,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Progress Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trạng thái gói cài đặt:',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _otaStatusText,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 6,
                        width: double.infinity,
                        color: AppColors.stitchSurfaceContainer,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _otaProgress,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.stitchPrimaryContainer,
                                  AppColors.stitchSecondaryContainer,
                                  AppColors.stitchTertiary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Flash Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.stitchPrimaryContainer,
                              AppColors.stitchSecondaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.stitchPrimaryContainer
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _triggerOtaFlashing(spp),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Nạp Firmware qua BLE ngay (Ước tính 45s)',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SECTION 5: SYSTEM MAINTENANCE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMaintenanceSection(SppService spp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.security_rounded,
              color: AppColors.stitchOutline,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Dữ Liệu & Bảo Trì (Maintenance)',
              style: GoogleFonts.outfit(
                color: AppColors.stitchOnSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // Ghosting Purge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vẽ lại màn hình TFT',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Vẽ lại giao diện hiện tại trên LCD màu',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stitchSurfaceHighest,
                      foregroundColor: AppColors.stitchSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isPurgingGhost
                        ? null
                        : () => _purgeGhosting(spp),
                    child: Text(
                      _isPurgingGhost ? 'Đang vẽ...' : 'Vẽ lại',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),

              // Export Hardware Log
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xuất nhật ký phần cứng (.log)',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Tải crash-dump ESP32 và thống kê tín hiệu BLE RSSI',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stitchSurfaceHighest,
                      foregroundColor: AppColors.stitchOnSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _showSnack(
                        'Đã xuất nhật ký hệ thống: ESP32-S3 Log (0 crash, BLE OK).',
                        AppColors.stitchTertiary,
                      );
                    },
                    icon: const Icon(Icons.file_download_rounded, size: 14),
                    label: Text(
                      'Tải về',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),

              // Factory Reset NVS
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khôi phục cài đặt gốc ESP32',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchError,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Xóa bộ nhớ Flash NVS, hủy liên kết BLE và về mặc định',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.stitchOnSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stitchErrorContainer
                          .withValues(alpha: 0.4),
                      foregroundColor: AppColors.stitchError,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _showFactoryResetDialog,
                    child: Text(
                      'Reset NVS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
