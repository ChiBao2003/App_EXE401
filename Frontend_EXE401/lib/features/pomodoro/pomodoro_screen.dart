import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/bluetooth/ble_service.dart';
import '../../core/bluetooth/spp_service.dart';
import '../../core/theme/app_colors.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // ─── Local Pomodoro Engine State ─────────────────────────────
  Timer? _timer;
  int _initialSeconds = 25 * 60; // 25 minutes standard
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _hardwareSession = false;
  bool _controlBusy = false;
  bool _pollBusy = false;
  String _selectedTaskType = 'General';
  bool _isBreak = false;
  int _sessionIndex = 1;
  int _tickCount = 0;

  // Peripheral Configuration Switches
  bool _hapticFeedback = true;
  bool _screenLock = true;
  bool _isPushingToWatch = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  // ─── Timer Control Functions ──────────────────────────────────
  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _readHardwareTimer() async {
    if (_pollBusy || !mounted) return;
    final spp = context.read<SppService>();
    if (!spp.isConnected) {
      _timer?.cancel();
      _hardwareSession = false;
      _pauseTimer();
      return;
    }
    _pollBusy = true;
    try {
      await spp.refreshPomodoroState();
      final state = spp.hardwarePomodoro;
      if (mounted && state != null) {
        setState(() {
          _remainingSeconds = state['remaining'] as int;
          _isRunning = state['running'] == true;
          _isBreak = state['phase'] != 0;
        });
      }
    } catch (_) {
      /* Preserve the last confirmed state while BLE recovers. */
    } finally {
      _pollBusy = false;
    }
  }

  Future<void> _toggleTimer() async {
    if (_controlBusy) return;
    final spp = context.read<SppService>();
    if (!spp.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kết nối ESP32 để bắt đầu phiên Pomodoro.'),
        ),
      );
      return;
    }
    _controlBusy = true;
    try {
      if (!_hardwareSession) {
        await spp.refreshPomodoroState();
        final existing = spp.hardwarePomodoro!;
        if (existing['running'] != true &&
            existing['remaining'] == (existing['work_min'] as int) * 60 &&
            existing['phase'] == 0) {
          await spp.sendPomodoroCycle(
            _initialSeconds ~/ 60,
            5,
            taskType: _selectedTaskType,
          );
        }
      }
      await spp.setMode(1);
      await spp.controlPomodoro(_isRunning ? 'pause' : 'start');
      _hardwareSession = true;
      _timer?.cancel();
      await _readHardwareTimer();
      if (!mounted) return;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ESP32 chưa xác nhận: $e')));
      }
    } finally {
      _controlBusy = false;
    }
  }

  Future<void> _stopTimer() async {
    if (_controlBusy) return;
    _controlBusy = true;
    try {
      await context.read<SppService>().controlPomodoro('reset');
      _timer?.cancel();
      _hardwareSession = false;
      if (mounted) {
        setState(() {
          _isRunning = false;
          _isBreak = false;
          _remainingSeconds = _initialSeconds;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể đặt lại: $e')));
      }
    } finally {
      _controlBusy = false;
    }
  }

  void _skipToNextPhase() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ESP32 tự chuyển pha khi kết thúc thời gian.'),
      ),
    );
  }

  void _onTick() {
    if (_hardwareSession) {
      _readHardwareTimer();
      return;
    }
    if (!mounted) return;
    if (_remainingSeconds > 0) {
      setState(() {
        _remainingSeconds--;
        _tickCount++;
      });
    } else {
      _timer?.cancel();
      final spp = context.read<SppService>();
      setState(() {
        _isRunning = false;
        if (!_isBreak) {
          _isBreak = true;
          _initialSeconds = 5 * 60;
          _remainingSeconds = 5 * 60;
          if (spp.isConnected) {
            spp.sendNotification(
              "Pomodoro",
              "Hoàn thành phiên làm việc! Nghỉ giải lao 5 phút.",
            );
          }
        } else {
          _isBreak = false;
          _sessionIndex = (_sessionIndex % 4) + 1;
          _initialSeconds = 25 * 60;
          _remainingSeconds = 25 * 60;
          if (spp.isConnected) {
            spp.sendNotification(
              "Pomodoro",
              "Hết giờ nghỉ! Bắt đầu phiên làm việc mới.",
            );
          }
        }
      });
    }
  }

  String _formatTime(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pushConfigToWatch(SppService spp) async {
    if (_isPushingToWatch) return;
    setState(() => _isPushingToWatch = true);
    try {
      await spp.sendPomodoroCycle(
        _isBreak ? 25 : _initialSeconds ~/ 60,
        5,
        taskType: _selectedTaskType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ESP32 đã xác nhận cấu hình Pomodoro.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể gửi cấu hình: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPushingToWatch = false);
    }
  }

  // ─── Build Method ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: SafeArea(
        child: Consumer<SppService>(
          builder: (context, spp, _) {
            final ble = context.watch<BleService>();
            final isConnected = spp.isConnected || ble.isConnected;

            return Stack(
              children: [
                // ─── Background Ambient Aura Glows ─────────────────────
                Positioned(
                  top: -60,
                  right: -50,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stitchPrimaryContainer.withValues(
                        alpha: 0.14,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stitchSecondaryContainer.withValues(
                        alpha: 0.10,
                      ),
                    ),
                  ),
                ),

                // ─── Scrollable Main Content ───────────────────────────
                Column(
                  children: [
                    _buildTopHeader(context, isConnected),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            // 1. Connection Status Banner
                            _buildConnectionBanner(context, spp, isConnected),
                            const SizedBox(height: 16),

                            // 2. Center Timer Hero Bento Module
                            _buildTimerHeroCard(context, spp),
                            const SizedBox(height: 16),

                            // 3. Last Completed Session Bento Card
                            _buildLastSessionCard(spp),
                            const SizedBox(height: 16),

                            // 4. AI Instant Feedback Card (AI Synapse Coach)
                            _buildAiFeedbackCard(spp),
                            const SizedBox(height: 16),

                            // 5. ESP32 Hardware Remote Sync Bar
                            _buildHardwareSyncCard(spp),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ─── Component: Top Header ────────────────────────────────────
  Widget _buildTopHeader(BuildContext context, bool isConnected) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLowest.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (canPop)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.stitchOnSurface,
                      size: 16,
                    ),
                  ),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.memory_rounded,
                    color: AppColors.stitchSecondaryContainer,
                    size: 20,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected
                              ? AppColors.stitchSecondaryContainer
                              : AppColors.stitchOutline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected ? "ESP32 LIVE" : "DISCONNECTED",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isConnected
                              ? AppColors.stitchSecondaryContainer
                              : AppColors.stitchOutline,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Pomodoro",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Battery chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              // User avatar
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.stitchPrimaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Component: Connection Status Banner ──────────────────────
  Widget _buildConnectionBanner(
    BuildContext context,
    SppService spp,
    bool isConnected,
  ) {
    final ble = context.read<BleService>();
    final deviceName = ble.device?.platformName ?? "ESP32 Watch (v4.2-BLE)";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? AppColors.stitchSecondaryContainer.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = isConnected
                        ? 1.0
                        : (1.0 + _pulseController.value * 0.08);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? AppColors.stitchSecondaryContainer.withValues(
                                  alpha: 0.16,
                                )
                              : AppColors.stitchSurfaceHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_disabled_rounded,
                          color: isConnected
                              ? AppColors.stitchSecondaryContainer
                              : AppColors.stitchOutline,
                          size: 18,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected
                                  ? AppColors.stitchTertiary
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              isConnected ? "SPP LIVE SYNC" : "DISCONNECTED",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isConnected
                                    ? AppColors.stitchSecondaryContainer
                                    : AppColors.stitchOutline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isConnected ? deviceName : "Chưa kết nối phần cứng",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (isConnected) {
                spp.disconnect();
              } else {
                spp.connectToEsp32();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected
                        ? Icons.sync_alt_rounded
                        : Icons.bluetooth_searching_rounded,
                    color: isConnected
                        ? AppColors.stitchSecondaryContainer
                        : Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isConnected ? "12ms" : "Kết nối",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isConnected
                          ? AppColors.stitchOnSurface
                          : AppColors.stitchPrimary,
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

  // ─── Component: Center Timer Hero Bento Module ────────────────
  Widget _buildTimerHeroCard(BuildContext context, SppService spp) {
    final progress = _initialSeconds > 0
        ? (_initialSeconds - _remainingSeconds) / _initialSeconds
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Tag / Phase Context Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _isBreak
                  ? "Phiên Nghỉ Giải Lao • 5 Phút"
                  : "Phiên $_sessionIndex / 4 • 25 Phút Chuẩn",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.stitchPrimary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Circular Countdown Progress Ring
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(230, 230),
                  painter: _TimerProgressPainter(
                    progress: progress,
                    backgroundColor: AppColors.stitchSurfaceHighest.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _isBreak
                            ? AppColors.stitchTertiaryContainer.withValues(
                                alpha: 0.30,
                              )
                            : AppColors.stitchErrorContainer.withValues(
                                alpha: 0.35,
                              ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isBreak
                                ? Icons.coffee_rounded
                                : Icons.local_fire_department_rounded,
                            color: _isBreak
                                ? AppColors.stitchTertiary
                                : const Color(0xFFEF4444),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isRunning
                                ? (_isBreak ? "Đang Nghỉ" : "Đang Tập Trung")
                                : "Tạm Dừng",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _isBreak
                                  ? AppColors.stitchTertiary
                                  : const Color(0xFFEF4444),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Countdown text
                    Text(
                      _formatTime(_remainingSeconds),
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: AppColors.stitchOnSurface,
                      ),
                    ),

                    // Subtitle / ESP32 Tick
                    Text(
                      "ESP32 Tick: #$_tickCount",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.stitchOutline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Action Controls
          Row(
            children: [
              // Primary Toggle Button
              Expanded(
                child: GestureDetector(
                  onTap: _toggleTimer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF7C4DFF,
                          ).withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isRunning
                                ? "Tạm dừng phiên"
                                : (_remainingSeconds == _initialSeconds
                                      ? "Bắt đầu phiên"
                                      : "Tiếp tục phiên"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Skip Break Button
              GestureDetector(
                onTap: _skipToNextPhase,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: const Icon(
                    Icons.skip_next_rounded,
                    color: AppColors.stitchOnSurface,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Stop/Reset Button
              GestureDetector(
                onTap: _stopTimer,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          DropdownButton<String>(
            value: _selectedTaskType,
            items: [
              'General',
              'Coding',
              'Reading',
              'Study',
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: _isRunning || _controlBusy
                ? null
                : (t) => setState(() => _selectedTaskType = t!),
          ),
          // 4. Quick BLE Push Config Action Button
          GestureDetector(
            onTap: () => _pushConfigToWatch(spp),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceHigh.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPushingToWatch)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.stitchSecondaryContainer,
                      ),
                    )
                  else
                    const Icon(
                      Icons.cell_tower_rounded,
                      color: AppColors.stitchSecondaryContainer,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isPushingToWatch
                          ? "Đang truyền sang SPP..."
                          : "Gửi cấu hình sang đồng hồ TFT LCD ngay",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.stitchSecondaryContainer,
                      ),
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

  // ─── Component: Last Completed Session Bento Card ─────────────
  Widget _buildLastSessionCard(SppService spp) {
    final session = spp.lastSession;
    final workMin = session?.workMin ?? 25;
    final breakMin = session?.breakMin ?? 5;
    final pauses = session?.pauses ?? 0;
    final hasRealSession = session != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    const Icon(
                      Icons.history_toggle_off_rounded,
                      color: AppColors.stitchPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Phiên gần nhất",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.stitchTertiaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.stitchTertiary,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasRealSession ? "Xuất sắc 🎯" : "Sẵn sàng",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stitchTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Columns Metric Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  "Làm việc",
                  "$workMin",
                  "ph",
                  AppColors.stitchOnSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  "Nghỉ giải lao",
                  "$breakMin",
                  "ph",
                  AppColors.stitchTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  "Số lần ngắt",
                  "$pauses",
                  "lần",
                  AppColors.stitchSecondaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    String unit,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.stitchOutline,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value.padLeft(2, '0'),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.stitchOutline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Component: AI Instant Feedback Card (AI Synapse Coach) ───
  Widget _buildAiFeedbackCard(SppService spp) {
    final feedbackText = spp.lastFeedback.isNotEmpty
        ? spp.lastFeedback
        : "Nhịp tim và độ tập trung ổn định trong 25 phút qua. Não bộ đang ở dải tần Beta tối ưu cho giải thuật phức tạp và tư duy logic.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.stitchPrimaryContainer.withValues(
                          alpha: 0.25,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: AppColors.stitchPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "POMO SMART Coach",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchPrimary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Vừa phân tích",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.stitchOutline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            feedbackText,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: AppColors.stitchOnSurface,
            ),
          ),
          const SizedBox(height: 14),

          // Mini Neural Frequency Wave Visualizer
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(12, (index) {
                  final phase = (index / 12) * 2 * pi;
                  final heightFactor =
                      (sin(_waveController.value * 2 * pi + phase) + 1) / 2;
                  final barHeight = 6.0 + (heightFactor * 16.0);
                  final isCyan = index % 2 == 0;

                  return Container(
                    width: 6,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isCyan
                          ? AppColors.stitchSecondaryContainer
                          : AppColors.stitchPrimaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Component: ESP32 Hardware Remote Sync Bar ────────────────
  Widget _buildHardwareSyncCard(SppService spp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    const Icon(
                      Icons.watch_rounded,
                      color: AppColors.stitchSecondaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Đồng bộ ngoại vi ESP32",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stitchSecondaryContainer.withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "TFT LCD SYNCED",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.stitchSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Feature 1: Haptic
          _buildHardwareFeatureTile(
            icon: Icons.vibration_rounded,
            iconColor: AppColors.stitchPrimary,
            title: "Rung Phản Hồi",
            subtitle: "Haptic Micro-tap khi đổi pha",
            value: _hapticFeedback,
            onChanged: (val) {
              setState(() => _hapticFeedback = val);
              if (spp.isConnected) {
                spp.sendJsonCommand('SET_CONFIG', {'haptic': val});
              }
            },
          ),
          const SizedBox(height: 10),

          // Feature 2: TFT LCD Screen Lock
          _buildHardwareFeatureTile(
            icon: Icons.screen_lock_portrait_rounded,
            iconColor: AppColors.stitchSecondaryContainer,
            title: "Màn hình TFT LCD",
            subtitle: "Khóa chống phân tâm (Matte Bone)",
            value: _screenLock,
            onChanged: (val) {
              setState(() => _screenLock = val);
              if (spp.isConnected) {
                spp.sendJsonCommand('SET_CONFIG', {'screen_lock': val});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.stitchOutline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.stitchPrimaryContainer,
            inactiveThumbColor: AppColors.stitchOutline,
            inactiveTrackColor: AppColors.stitchSurfaceHigh,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ─── Component: Bottom Navigation Bar ─────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLowest,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.dashboard_rounded,
                label: "Trang chủ",
                isActive: false,
                onTap: () => Navigator.of(context).pushReplacementNamed('/'),
              ),
              _buildBottomNavItem(
                icon: Icons.calendar_view_week_rounded,
                label: "Lịch tuần",
                isActive: false,
                onTap: () => Navigator.of(context).pushNamed('/schedule'),
              ),
              _buildBottomNavItem(
                icon: Icons.timer_rounded,
                label: "Pomodoro",
                isActive: true,
                onTap: () {},
              ),
              _buildBottomNavItem(
                icon: Icons.hub_rounded,
                label: "Thiết bị",
                isActive: false,
                onTap: () => Navigator.of(context).pushNamed('/info'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive
                ? AppColors.stitchSecondaryContainer
                : AppColors.stitchOutline,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? AppColors.stitchSecondaryContainer
                  : AppColors.stitchOutline,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter: Neon Countdown Progress Ring ───────────────
class _TimerProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;

  _TimerProgressPainter({
    required this.progress,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;

    // Background Circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: const [Color(0xFF00DAF3), Color(0xFF7C4DFF), Color(0xFFBDF4FF)],
        stops: const [0.0, 0.6, 1.0],
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
