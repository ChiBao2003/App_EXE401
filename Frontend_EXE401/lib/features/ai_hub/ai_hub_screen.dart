import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/ai_api.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/api_client.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/bluetooth/spp_service.dart';
import '../../core/theme/app_colors.dart';
import 'ai_assistant_screen.dart';

/// Screen 4: AI Productivity Hub (Stitch ID: 750a06f0f1294031a05c7061df73c278)
/// Design System: Aether Synapse
class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen>
    with SingleTickerProviderStateMixin {
  AiRecommendation? _recommendation;
  BurnoutRisk? _burnout;
  CoachAdvice? _coach;
  Map<String, dynamic>? _contextData;
  bool _loading = true;
  String? _errorMessage;
  String _userName = "Bạn";

  // Interactive Concentration & Task Type
  double _concScore = 65;
  String _taskType = "general";
  bool _isPlayingBinaural = false;
  bool _isSyncingToWatch = false;

  late AnimationController _spinController;

  static const _tasks = [
    ("general", "Chung"),
    ("coding", "Code"),
    ("reading", "Đọc"),
    ("meeting", "Họp"),
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    _spinController.repeat();

    try {
      _userName = await AuthApi.getUserName();
      final results = await Future.wait([
        AiApi.getPomodoroRecommendation(
          concentrationScore: _concScore,
          taskType: _taskType,
        ),
        AiApi.getBurnoutRisk(),
        AiApi.getDailyAdvice(),
        AiApi.getTodayContext(),
      ]);

      if (mounted) {
        setState(() {
          _recommendation = results[0] as AiRecommendation;
          _burnout = results[1] as BurnoutRisk;
          _coach = results[2] as CoachAdvice;
          _contextData = results[3] as Map<String, dynamic>;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi API AI: ${e.message}"),
            backgroundColor: AppColors.stitchErrorContainer,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Không thể kết nối Backend AI ($e)");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể kết nối đến máy chủ AI"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        _spinController.reset();
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _applyCycleToWatch(SppService spp) async {
    if (_isSyncingToWatch) return;
    setState(() => _isSyncingToWatch = true);

    final workMin = _recommendation?.workMin ?? 45;
    final breakMin = _recommendation?.breakMin ?? 10;

    if (spp.isConnected) {
      await spp.sendPomodoroCycle(workMin, breakMin);
      await spp.sendNotification(
        "AI Synapse",
        "Đã áp dụng chu kỳ tập trung AI: ${workMin}m/${breakMin}m",
      );
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isSyncingToWatch = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              spp.isConnected
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: spp.isConnected ? AppColors.stitchTertiary : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                spp.isConnected
                    ? "Đã đồng bộ chu kỳ ${workMin}m/${breakMin}m lên ESP32!"
                    : "Chưa kết nối đồng hồ ESP32 (Vui lòng bật Bluetooth)",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.stitchSurfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleBinauralBeats() {
    setState(() => _isPlayingBinaural = !_isPlayingBinaural);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPlayingBinaural
              ? "Bật Binaural Beats 40Hz: Sóng Gamma kích hoạt tập trung sâu 🎧"
              : "Đã tạm dừng Binaural Beats 40Hz",
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: AppColors.stitchSurfaceHigh,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spp = context.watch<SppService>();
    final ble = context.watch<BleService>();
    final isConnected = spp.isConnected || ble.isConnected;

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient Aura Glows
            Positioned(
              top: -50,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.stitchPrimaryContainer.withValues(
                    alpha: 0.12,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.stitchTertiaryContainer.withValues(
                    alpha: 0.10,
                  ),
                ),
              ),
            ),

            // Main Content
            Column(
              children: [
                _buildTopHeader(context, isConnected),
                Expanded(
                  child: _loading && _recommendation == null && _burnout == null
                      ? _buildLoadingState()
                      : _errorMessage != null && _recommendation == null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadAll,
                          color: AppColors.stitchPrimary,
                          backgroundColor: AppColors.stitchSurfaceHigh,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSubHeader(),
                                const SizedBox(height: 16),

                                // 1. Hero Card: Burnout Risk Gauge
                                _buildBurnoutGaugeHeroCard(),
                                const SizedBox(height: 16),

                                // 2. Adaptive Pomodoro Recommendation
                                _buildAdaptivePomodoroCard(spp),
                                const SizedBox(height: 16),

                                // 3. Daily Coach Advice Card
                                _buildCoachAdviceCard(),
                                const SizedBox(height: 16),

                                // 4. Weather & Context Awareness Card
                                _buildWeatherContextCard(),
                                const SizedBox(height: 16),

                                // 5. Interactive AI Coach Chat Banner
                                _buildAiCoachBanner(context),
                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
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
                    width: 36,
                    height: 36,
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
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.watch_rounded,
                    color: AppColors.stitchPrimary,
                    size: 20,
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "SYNAPSE OS",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                  Text(
                    "Ai Hub",
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? AppColors.stitchTertiary
                            : AppColors.stitchOutline,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? "SYNC 98%" : "OFFLINE",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: isConnected
                            ? AppColors.stitchTertiary
                            : AppColors.stitchOutline,
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

  // ─── Component: Sub Header ────────────────────────────────────
  Widget _buildSubHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stitchSecondaryContainer,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00E3FD),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Cognitive State v2.4",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.stitchSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "AI Productivity Hub",
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.stitchOnSurface,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                "Trung tâm Nhận thức & Ngăn ngừa Kiệt sức • $_userName",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.stitchOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loadAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                RotationTransition(
                  turns: _spinController,
                  child: const Icon(
                    Icons.sync_rounded,
                    color: AppColors.stitchPrimary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "Làm mới",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Component: Hero Card: Burnout Risk Gauge ─────────────────
  Widget _buildBurnoutGaugeHeroCard() {
    final riskScore = _burnout?.riskScore ?? 24.0;
    final riskLevel = _burnout?.riskLevel ?? "low";
    final advice = _burnout?.advice.isNotEmpty == true
        ? _burnout!.advice
        : "Bạn đã hoàn thành 3 phiên tập trung chất lượng. Khuyến nghị nghỉ ngơi 10 phút trước phiên tiếp theo.";

    final levelColor = _burnout?.levelColor ?? AppColors.stitchTertiary;
    final levelText = _getRiskLevelText(riskLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
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
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.speed_rounded,
                      color: levelColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Chỉ số Nguy cơ Kiệt sức",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                      Text(
                        levelText,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: levelColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceLowest.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: levelColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Realtime",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: levelColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Speedometer Semi-Circular Arc
          SizedBox(
            width: 210,
            height: 115,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(210, 115),
                  painter: _SpeedometerArcPainter(
                    percentage: (riskScore / 100.0).clamp(0.0, 1.0),
                    activeColor: levelColor,
                    trackColor: AppColors.stitchSurfaceHighest,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "${riskScore.round()}",
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.stitchOnSurface,
                          ),
                        ),
                        Text(
                          "%",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: levelColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _getRiskSubLabel(riskLevel),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Micro Biometric Telemetry Strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTelemetryItem(
                    icon: Icons.visibility_rounded,
                    iconColor: AppColors.stitchSecondary,
                    label: "Mỏi mắt",
                    value: "15%",
                    status: "Bình thường",
                    statusColor: AppColors.stitchTertiary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                Expanded(
                  child: _buildTelemetryItem(
                    icon: Icons.psychology_rounded,
                    iconColor: AppColors.stitchPrimary,
                    label: "Năng lượng",
                    value: "88%",
                    status: "Tối ưu",
                    statusColor: AppColors.stitchPrimary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                Expanded(
                  child: _buildTelemetryItem(
                    icon: Icons.favorite_rounded,
                    iconColor: AppColors.stitchTertiary,
                    label: "HRV",
                    value: "76ms",
                    status: "Đồng pha",
                    statusColor: AppColors.stitchTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Warning & Context Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceHigh.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.stitchSecondaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    advice,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String status,
    required Color statusColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.stitchOnSurface,
          ),
        ),
        Text(
          status,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  // ─── Component: Adaptive Pomodoro Recommendation ──────────────
  Widget _buildAdaptivePomodoroCard(SppService spp) {
    final workMin = _recommendation?.workMin ?? 45;
    final breakMin = _recommendation?.breakMin ?? 10;
    final reason = _recommendation?.reason.isNotEmpty == true
        ? _recommendation!.reason
        : "Khuyến nghị từ Q-Learning dựa trên điểm tập trung hiện tại.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.dynamic_form_rounded,
                      color: AppColors.stitchPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pomodoro Thích Ứng AI",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                      Text(
                        "Theo chu kỳ sóng não & hoạt động",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.stitchOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stitchPrimaryContainer.withValues(
                    alpha: 0.20,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "ĐỀ XUẤT",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.stitchPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Concentration Slider & Task Type Selector
          Container(
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
                      "Mức tập trung hiện tại",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
                    Text(
                      "${_concScore.round()}/100",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stitchPrimary,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.stitchPrimaryContainer,
                    inactiveTrackColor: AppColors.stitchSurfaceHigh,
                    thumbColor: Colors.white,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _concScore,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) => setState(() => _concScore = v),
                    onChangeEnd: (_) => _loadAll(),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "Task: ",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: _tasks.map((t) {
                          final isSelected = _taskType == t.$1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _taskType = t.$1);
                                _loadAll();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.stitchPrimaryContainer
                                      : AppColors.stitchSurfaceHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t.$2,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.stitchOnSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Interval Metric Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.adjust_rounded,
                            color: AppColors.stitchPrimary,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Tập trung sâu",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "$workMin",
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "phút",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Sóng Beta/Gamma cao",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.stitchOutline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.spa_rounded,
                            color: AppColors.stitchTertiary,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Thư giãn hoàn toàn",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "$breakMin",
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "phút",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Phục hồi thụ thể thần kinh",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.stitchOutline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Reason text
          Text(
            reason,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: AppColors.stitchOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Binaural Beats Recommendation Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.stitchSurfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.headphones_rounded,
                          color: AppColors.stitchSecondaryContainer,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Binaural Beats • Focus 40Hz",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                            Text(
                              "Gamma Boost • Kích hoạt tập trung sâu",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.stitchSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _toggleBinauralBeats,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isPlayingBinaural
                          ? AppColors.stitchSecondaryContainer
                          : AppColors.stitchSurfaceHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlayingBinaural
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: _isPlayingBinaural ? Colors.black : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Sync to Watch Button
          GestureDetector(
            onTap: () => _applyCycleToWatch(spp),
            child: Container(
              width: double.infinity,
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
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSyncingToWatch)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.watch_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isSyncingToWatch
                        ? "Đang truyền tới ESP32..."
                        : "Áp dụng cấu hình này vào Đồng hồ",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Component: Daily Coach Advice Card ───────────────────────
  Widget _buildCoachAdviceCard() {
    final advice = _coach?.advice.isNotEmpty == true
        ? _coach!.advice
        : "Buổi sáng từ 09:00 - 11:30 là khung giờ vàng của bạn. Hãy tận dụng giải quyết các thuật toán phức tạp.";
    final isPersonalized = _coach?.personalized ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.stitchPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Lời khuyên từ Synapse Coach",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                      Text(
                        isPersonalized
                            ? "Cá nhân hóa theo dữ liệu của bạn"
                            : "Phân tích nhịp sinh học",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.stitchOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(
                Icons.format_quote_rounded,
                color: AppColors.stitchOutline,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "“$advice”",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: AppColors.stitchOnSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
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
                    Text(
                      "Dự đoán năng lượng: Đỉnh điểm lúc 10:15",
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

          if (_coach?.stats.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _coach!.stats.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_formatStatKey(e.key)}: ${e.value}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Component: Weather & Context Awareness Card ──────────────
  Widget _buildWeatherContextCard() {
    final weather = _contextData?["weather"] as Map<String, dynamic>? ?? {};
    final advice =
        _contextData?["productivity_advice"] as String? ??
        "Thời điểm lý tưởng để hoàn thành các task nặng hoặc code logic ESP32.";
    final temp = weather["temp_c"]?.toString() ?? "29";
    final desc = weather["description"]?.toString() ?? "Nắng nhẹ";
    final humidity = weather["humidity"]?.toString() ?? "65";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(24),
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.wb_sunny_rounded,
                        color: AppColors.stitchSecondaryContainer,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Môi trường & Ngữ cảnh",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchOnSurface,
                            ),
                          ),
                          Text(
                            "Cảm biến quang học & Vi khí hậu",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceLowest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "Hà Nội, VN",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.thermostat_rounded,
                        color: AppColors.stitchSecondaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$desc $temp°C",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                            Text(
                              "Độ ẩm $humidity% • Dễ chịu",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.light_mode_rounded,
                        color: AppColors.stitchTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "450 Lux",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                            Text(
                              "Ánh sáng tự nhiên tốt",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.stitchTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: AppColors.stitchPrimary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.stitchOnSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: "Tác động hiệu suất: ",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: AppColors.stitchPrimary,
                          ),
                        ),
                        TextSpan(text: advice),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Component: Interactive AI Coach Chat Banner ─────────────
  Widget _buildAiCoachBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AIAssistantScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.stitchSurfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.stitchPrimaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.stitchTertiary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.stitchSurfaceHigh,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Trò chuyện với AI Coach",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Sẵn sàng phản hồi phân tích tâm lý & điều phối lịch",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.stitchPrimaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Loading & Error States ───────────────────────────────────
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.stitchPrimary,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            "Đang kết nối Cognitive State & AI Agent...",
            style: TextStyle(
              color: AppColors.stitchOnSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            Text(
              "Không thể tải dữ liệu AI",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.stitchOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "Lỗi kết nối",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stitchPrimaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Thử lại"),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Functions ─────────────────────────────────────────
  String _getRiskLevelText(String level) {
    switch (level.toLowerCase()) {
      case "critical":
        return "Nguy hiểm • Cần dừng nghỉ ngay";
      case "high":
        return "Mức cao • Cần nghỉ ngơi sớm";
      case "medium":
        return "Trung bình • Cân bằng tải làm việc";
      default:
        return "An toàn • Trạng thái tối ưu";
    }
  }

  String _getRiskSubLabel(String level) {
    switch (level.toLowerCase()) {
      case "critical":
        return "MỨC NGUY HIỂM";
      case "high":
        return "MỨC CAO";
      case "medium":
        return "MỨC TRUNG BÌNH";
      default:
        return "MỨC THẤP • AN TOÀN";
    }
  }

  String _formatStatKey(String key) {
    switch (key) {
      case "avg_concentration_score":
        return "Tập trung TB";
      case "break_skip_rate":
        return "Bỏ qua nghỉ";
      case "completion_rate":
        return "Hoàn thành";
      default:
        return key;
    }
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
                icon: Icons.psychology_rounded,
                label: "AI Hub",
                isActive: true,
                onTap: () {},
              ),
              _buildBottomNavItem(
                icon: Icons.timer_rounded,
                label: "Pomodoro",
                isActive: false,
                onTap: () => Navigator.of(context).pushNamed('/pomodoro'),
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
            color: isActive ? AppColors.stitchPrimary : AppColors.stitchOutline,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? AppColors.stitchPrimary
                  : AppColors.stitchOutline,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter: Speedometer Arc Display ────────────────────
class _SpeedometerArcPainter extends CustomPainter {
  final double percentage; // 0.0 to 1.0
  final Color activeColor;
  final Color trackColor;

  _SpeedometerArcPainter({
    required this.percentage,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background semi-circle track from pi to 2*pi
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, pi, pi, false, trackPaint);

    if (percentage > 0) {
      final sweepAngle = pi * percentage.clamp(0.0, 1.0);

      final activeGradient = LinearGradient(
        colors: [const Color(0xFF4EDEA3), const Color(0xFF00E3FD), activeColor],
        stops: const [0.0, 0.5, 1.0],
      );

      final activePaint = Paint()
        ..shader = activeGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, pi, sweepAngle, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerArcPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
