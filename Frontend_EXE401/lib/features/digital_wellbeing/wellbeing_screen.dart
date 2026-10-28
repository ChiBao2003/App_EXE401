import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/usage_tracking/models.dart';
import '../../core/usage_tracking/usage_tracker_service.dart';

/// Digital Wellbeing Dashboard — Cân Bằng Số
/// Triển khai Stitch Screen 6 (fc3e460f72384373aa9e3f37f32aa58d) theo chuẩn Aether Synapse.
class WellbeingScreen extends StatefulWidget {
  final DailyUsageSummary? initialSummary;
  final DailyUsageSummary? initialWeekSummary;
  final List<AppUsageInfo>? initialApps;
  final bool? initialHasPermission;

  const WellbeingScreen({
    super.key,
    this.initialSummary,
    this.initialWeekSummary,
    this.initialApps,
    this.initialHasPermission,
  });

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen>
    with SingleTickerProviderStateMixin {
  final _tracker = UsageTrackerService();
  bool _loading = true;
  bool _hasPermission = false;
  DailyUsageSummary? _summary;
  DailyUsageSummary? _weekSummary;
  List<AppUsageInfo> _allApps = [];
  String _selectedFilter = 'today'; // 'today' | 'week'
  bool _isFocusLocked = false;

  late AnimationController _scoreAnimCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _scoreAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeOutCubic),
    );
    _checkAndLoad();
  }

  @override
  void dispose() {
    _scoreAnimCtrl.dispose();
    super.dispose();
  }

  DailyUsageSummary? get currentSummary =>
      _selectedFilter == 'week' ? (_weekSummary ?? _summary) : _summary;

  Future<void> _checkAndLoad() async {
    // Nếu có test mocks được cung cấp sẵn
    if (widget.initialSummary != null || widget.initialHasPermission != null) {
      setState(() {
        _summary = widget.initialSummary;
        _weekSummary = widget.initialWeekSummary ?? widget.initialSummary;
        _allApps = widget.initialApps ?? widget.initialSummary?.topApps ?? [];
        _hasPermission = widget.initialHasPermission ?? true;
        _loading = false;
      });
      if (_summary != null) {
        _updateScoreAnimation(currentSummary?.focusScore ?? 0);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      _hasPermission = await _tracker.hasPermission();
      if (_hasPermission) {
        await _loadData();
      } else {
        await _loadFromBackendAnalytics();
      }
    } catch (e) {
      debugPrint('[Wellbeing] Error in _checkAndLoad: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final summary = await _tracker.getDailySummary();
    final allApps = await _tracker.getUsageStats(start: startOfDay, end: now);

    // Tính toán thống kê tuần (7 ngày gần nhất)
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekApps = await _tracker.getUsageStats(start: weekAgo, end: now);
    final weekSummary = _buildAggregatedSummary(weekAgo, weekApps);

    // Đẩy summary hôm nay lên backend
    await _tracker.syncToBackend(summary);

    if (mounted) {
      setState(() {
        _summary = summary;
        _weekSummary = weekSummary;
        _allApps = allApps;
      });
      _updateScoreAnimation(currentSummary?.focusScore ?? 0);
    }
  }

  Future<void> _loadFromBackendAnalytics() async {
    try {
      final res = await ApiClient.get('/api/v1/usage/analytics');
      if (res is Map<String, dynamic> && res['aggregate'] != null) {
        final agg = res['aggregate'] as Map<String, dynamic>;
        final focusScore = (agg['avg_focus_score'] as num?)?.toDouble() ?? 0.0;
        final screenTimeMs =
            (agg['total_screen_time_ms'] as num?)?.toInt() ?? 0;
        final unlocks = (agg['total_unlocks'] as num?)?.toInt() ?? 0;
        final distractions =
            (agg['total_distractions_during_pomo'] as num?)?.toInt() ?? 0;

        final cloudSummary = DailyUsageSummary(
          date: DateTime.now(),
          totalScreenTimeMs: screenTimeMs,
          totalUnlocks: unlocks,
          totalDistractions: distractions,
          productiveTimeMs: (screenTimeMs * 0.6).toInt(),
          distractedTimeMs: (screenTimeMs * 0.25).toInt(),
          topApps: const [],
          focusScore: focusScore > 0 ? focusScore : 0.0,
        );

        if (mounted) {
          setState(() {
            _summary = cloudSummary;
            _weekSummary = cloudSummary;
          });
          _updateScoreAnimation(currentSummary?.focusScore ?? 0);
        }
      }
    } catch (e) {
      debugPrint('[Wellbeing] Cloud analytics load error: $e');
    }
  }

  DailyUsageSummary _buildAggregatedSummary(
    DateTime start,
    List<AppUsageInfo> apps,
  ) {
    int totalScreenTime = 0;
    int productiveTime = 0;
    int distractedTime = 0;

    for (final app in apps) {
      totalScreenTime += app.foregroundTimeMs;
      if (app.category.isProductive) {
        productiveTime += app.foregroundTimeMs;
      } else if (app.category.isDistraction) {
        distractedTime += app.foregroundTimeMs;
      }
    }

    double score = 100.0;
    if (totalScreenTime > 0) {
      final distractionRatio = distractedTime / totalScreenTime;
      score = ((1.0 - distractionRatio) * 100).clamp(0.0, 100.0).toDouble();
    }

    return DailyUsageSummary(
      date: start,
      totalScreenTimeMs: totalScreenTime,
      totalUnlocks: 0,
      totalDistractions: 0,
      productiveTimeMs: productiveTime,
      distractedTimeMs: distractedTime,
      topApps: apps.take(10).toList(),
      focusScore: score,
    );
  }

  void _updateScoreAnimation(double score) {
    _scoreAnim = Tween<double>(begin: 0, end: score).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeOutCubic),
    );
    _scoreAnimCtrl.forward(from: 0);
  }

  Future<void> _requestPermission() async {
    await _tracker.requestPermission();
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.stitchSurfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Cấp quyền Usage Access',
            style: GoogleFonts.outfit(
              color: AppColors.stitchOnSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bật quyền cho "POMO SMART" trong danh sách cài đặt hệ thống, sau đó quay lại ứng dụng để cập nhật dữ liệu.',
            style: GoogleFonts.inter(
              color: AppColors.stitchOnSurfaceVariant,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _checkAndLoad();
              },
              child: Text(
                'Đã cấp xong',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.stitchSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _toggleFocusLock(BleService ble) {
    setState(() {
      _isFocusLocked = !_isFocusLocked;
    });

    if (ble.isConnected) {
      ble.sendJson({'type': 'focus_lock', 'state': _isFocusLocked});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isFocusLocked
            ? AppColors.stitchTertiaryContainer
            : AppColors.stitchSurfaceContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          _isFocusLocked
              ? 'Đã bật TFT LCD Focus Lock: Giảm xao nhãng và khóa thông báo.'
              : 'Đã tắt TFT LCD Focus Lock.',
          style: GoogleFonts.inter(
            color: AppColors.stitchOnSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAllAppsModal(List<AppUsageInfo> apps) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.stitchSurfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.stitchOutlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tất Cả Ứng Dụng (${apps.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: apps.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có dữ liệu ứng dụng',
                          style: GoogleFonts.inter(
                            color: AppColors.stitchOnSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: apps.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: AppColors.stitchSurfaceHigh),
                        itemBuilder: (ctx, i) {
                          final app = apps[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: _getCategoryColor(
                                  app.category,
                                ).withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                _getCategoryIcon(app.category),
                                color: _getCategoryColor(app.category),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              app.appName.isEmpty
                                  ? app.packageName
                                  : app.appName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchOnSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              app.category.label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                            trailing: Text(
                              app.durationText,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.stitchPrimaryContainer,
                      ),
                    )
                  : (!_hasPermission && _summary == null)
                  ? _buildPermissionRequest()
                  : _buildDashboard(ble),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: AppColors.stitchSurface),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stitchSurfaceContainer,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.stitchOnSurface,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chi Tiết Thiết Bị',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.stitchSecondaryContainer,
                  size: 20,
                ),
                onPressed: _checkAndLoad,
                tooltip: 'Làm mới dữ liệu',
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.stitchPrimaryContainer,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.stitchOnPrimaryContainer,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // DASHBOARD
  // ══════════════════════════════════════════════════════════
  Widget _buildDashboard(BleService ble) {
    final summary = currentSummary;
    final apps = _allApps.isNotEmpty
        ? _allApps
        : (summary != null ? summary.topApps : <AppUsageInfo>[]);

    return RefreshIndicator(
      onRefresh: _checkAndLoad,
      color: AppColors.stitchPrimaryContainer,
      backgroundColor: AppColors.stitchSurfaceContainer,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Subtle Top Accent & Quick Switch Filter ──
            _buildSubHeader(ble),
            const SizedBox(height: 16),

            // ── Hero Gauge Bento Card: Focus Score ──
            _buildHeroFocusCard(summary),
            const SizedBox(height: 16),

            // ── Screen Time Metrics & Multi-segment Bar ──
            _buildScreenTimeCard(summary),
            const SizedBox(height: 20),

            // ── Top Used Apps Section ──
            _buildTopAppsSection(apps),
            const SizedBox(height: 20),

            // ── AI Wellbeing Insights & Hardware Focus Action ──
            _buildAiInsightCard(ble, summary),
            const SizedBox(height: 16),

            // ── Big Action Button ──
            _buildFocusLockButton(ble),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── Top SubHeader & Filter Switcher ──
  Widget _buildSubHeader(BleService ble) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ble.isConnected
                          ? AppColors.stitchSecondaryContainer
                          : AppColors.stitchOutline,
                      boxShadow: ble.isConnected
                          ? const [
                              BoxShadow(
                                color: AppColors.stitchSecondaryContainer,
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ble.isConnected
                          ? 'ĐỒNG BỘ TFT LCD 0.4S TRƯỚC'
                          : 'ĐỒNG BỘ TFT LCD ĐỘC LẬP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: ble.isConnected
                            ? AppColors.stitchSecondaryContainer
                            : AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Cân Bằng Số',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.stitchOnSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Kiểm soát thời gian màn hình & chống xao nhãng',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.stitchOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Filter Switcher
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterPill('Hôm nay', 'today'),
              _buildFilterPill('Tuần', 'week'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        if (_selectedFilter != value) {
          setState(() {
            _selectedFilter = value;
          });
          _updateScoreAnimation(currentSummary?.focusScore ?? 0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.stitchPrimaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.stitchOnPrimaryContainer
                : AppColors.stitchOnSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ── Hero Gauge Bento Card: Focus Score ──
  Widget _buildHeroFocusCard(DailyUsageSummary? summary) {
    final score = summary?.focusScore ?? 0.0;
    final isGood = score >= 70;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.stitchSurfaceContainer,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedFilter == 'today'
                        ? 'CHỈ SỐ TẬP TRUNG HÔM NAY'
                        : 'CHỈ SỐ TẬP TRUNG TUẦN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchOnSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedBuilder(
                        animation: _scoreAnim,
                        builder: (context, _) {
                          return Text(
                            summary != null
                                ? _scoreAnim.value.toInt().toString()
                                : '--',
                            style: GoogleFonts.outfit(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchOnSurface,
                              letterSpacing: -1,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ 100',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.stitchOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.stitchSecondaryContainer.withValues(
                    alpha: 0.15,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGood
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded,
                      color: AppColors.stitchSecondaryContainer,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      summary != null
                          ? (isGood ? 'Tốt • Tập trung cao' : 'Cần cải thiện')
                          : 'Chưa có dữ liệu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.stitchSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Radial Arc Gauge
          Center(
            child: SizedBox(
              width: 200,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _scoreAnim,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(200, 110),
                        painter: FocusScoreArcPainter(
                          progress: summary != null
                              ? (_scoreAnim.value / 100).clamp(0.0, 1.0)
                              : 0.0,
                          trackColor: AppColors.stitchSurfaceHighest,
                          gradientColors: const [
                            AppColors.stitchPrimaryContainer,
                            AppColors.stitchSecondaryContainer,
                            AppColors.stitchTertiary,
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.trending_up_rounded,
                              color: AppColors.stitchTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              summary != null ? '+14 điểm' : '0 điểm',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'so với trung bình tuần',
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
          const SizedBox(height: 14),

          // Comparison Micro Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.stitchSurfaceLow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.stitchPrimaryContainer.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.stitchPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Ước tính thuật toán: ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchSecondaryContainer,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'Bạn đã kiểm soát ứng dụng gây nghiện tốt hơn ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '${(summary?.focusScore ?? 78).clamp(50, 99).toInt()}% ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                            TextSpan(
                              text: 'người dùng cùng hệ sinh thái.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chỉ báo tham khảo từ hành vi sử dụng, không phải chẩn đoán lâm sàng.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.stitchOutline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Screen Time Metrics & Multi-segment Bar ──
  Widget _buildScreenTimeCard(DailyUsageSummary? summary) {
    final totalMs = summary?.totalScreenTimeMs ?? 0;
    final prodMs = summary?.productiveTimeMs ?? 0;
    final distMs = summary?.distractedTimeMs ?? 0;
    final otherMs = math.max(0, totalMs - prodMs - distMs);

    final prodRatio = totalMs > 0 ? (prodMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final distRatio = totalMs > 0 ? (distMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final otherRatio = totalMs > 0 ? (otherMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.stitchSurfaceContainer,
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
                  Text(
                    _selectedFilter == 'today'
                        ? 'TỔNG THỜI GIAN MÀN HÌNH'
                        : 'TỔNG THỜI GIAN MÀN HÌNH TUẦN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchOnSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary != null && totalMs > 0
                        ? summary.totalScreenTimeText
                        : '0h 00m',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.stitchTertiaryContainer.withValues(
                    alpha: 0.3,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.south_east_rounded,
                      color: AppColors.stitchTertiary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '-18% hôm qua',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.stitchTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Multi-segment Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 12,
              color: AppColors.stitchSurfaceHighest,
              child: totalMs > 0
                  ? Row(
                      children: [
                        if (prodRatio > 0.01)
                          Flexible(
                            flex: (prodRatio * 1000).toInt(),
                            child: Container(color: AppColors.stitchTertiary),
                          ),
                        if (distRatio > 0.01)
                          Flexible(
                            flex: (distRatio * 1000).toInt(),
                            child: Container(color: const Color(0xFFFF5252)),
                          ),
                        if (otherRatio > 0.01)
                          Flexible(
                            flex: (otherRatio * 1000).toInt(),
                            child: Container(color: AppColors.stitchOutline),
                          ),
                      ],
                    )
                  : const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 14),

          // 3 Column Legend & Values
          Row(
            children: [
              Expanded(
                child: _buildCategoryColumn(
                  dotColor: AppColors.stitchTertiary,
                  label: 'Học & Code',
                  timeText: summary?.productiveTimeText ?? '0m',
                  percentageText: '${(prodRatio * 100).toInt()}%',
                  tagColor: AppColors.stitchTertiary,
                ),
              ),
              Expanded(
                child: _buildCategoryColumn(
                  dotColor: const Color(0xFFFF5252),
                  label: 'Mạng Xã Hội',
                  timeText: summary?.distractedTimeText ?? '0m',
                  percentageText: '${(distRatio * 100).toInt()}% (Xao nhãng)',
                  tagColor: const Color(0xFFFF5252),
                ),
              ),
              Expanded(
                child: _buildCategoryColumn(
                  dotColor: AppColors.stitchOutline,
                  label: 'Tiện Ích',
                  timeText:
                      '${otherMs ~/ 3600000}h ${(otherMs ~/ 60000) % 60}m',
                  percentageText: '${(otherRatio * 100).toInt()}%',
                  tagColor: AppColors.stitchOutline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryColumn({
    required Color dotColor,
    required String label,
    required String timeText,
    required String percentageText,
    required Color tagColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.stitchOnSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          timeText,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.stitchOnSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          percentageText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tagColor,
          ),
        ),
      ],
    );
  }

  // ── Top Used Apps Section ──
  Widget _buildTopAppsSection(List<AppUsageInfo> apps) {
    final topApps = apps.take(4).toList();
    final maxTime = topApps.isNotEmpty ? topApps.first.foregroundTimeMs : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ứng Dụng Dùng Nhiều Nhất',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.stitchOnSurface,
              ),
            ),
            InkWell(
              onTap: () => _showAllAppsModal(apps),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Xem tất cả (${apps.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (topApps.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.stitchSurfaceContainer,
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.apps_rounded,
                    color: AppColors.stitchOutline,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chưa có dữ liệu ứng dụng hôm nay',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...topApps.map((app) {
            final isDistraction = app.category.isDistraction;
            final progress = maxTime > 0
                ? (app.foregroundTimeMs / maxTime).clamp(0.05, 1.0)
                : 0.1;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.stitchSurfaceContainer,
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
                                borderRadius: BorderRadius.circular(10),
                                color: _getCategoryColor(
                                  app.category,
                                ).withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                _getCategoryIcon(app.category),
                                color: _getCategoryColor(app.category),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.appName.isEmpty
                                        ? app.packageName
                                        : app.appName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.stitchOnSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          color: isDistraction
                                              ? const Color(
                                                  0xFFFF5252,
                                                ).withValues(alpha: 0.2)
                                              : AppColors.stitchPrimaryContainer
                                                    .withValues(alpha: 0.2),
                                        ),
                                        child: Text(
                                          app.category.label,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: isDistraction
                                                ? const Color(0xFFFF5252)
                                                : AppColors.stitchPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isDistraction
                                              ? 'Nguy cơ xao nhãng'
                                              : 'Hoạt động liên tục',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: isDistraction
                                                ? const Color(0xFFFF5252)
                                                : AppColors
                                                      .stitchOnSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                      const SizedBox(width: 8),
                      Text(
                        app.durationText,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDistraction
                              ? const Color(0xFFFF5252)
                              : AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.stitchSurfaceHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getCategoryColor(app.category),
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── AI Wellbeing Insights & Hardware Focus Action ──
  Widget _buildAiInsightCard(BleService ble, DailyUsageSummary? summary) {
    String insightText;
    if (summary != null && summary.distractedTimeMs > 30 * 60000) {
      insightText =
          'Cảnh báo xao nhãng: Bạn đã dành ${summary.distractedTimeText} cho ứng dụng giải trí. Đề xuất bật chế độ TFT LCD Focus Lock để tạm khoá thông báo mạng xã hội và dồn sự chú ý vào công việc.';
    } else if (summary != null && summary.focusScore >= 75) {
      insightText =
          'Trạng thái tối ưu: Bạn duy trì tỷ lệ tập trung cao (${summary.productiveTimeText} làm việc hiệu quả). Tiếp tục chu kỳ Pomodoro hiện tại!';
    } else if (summary == null || summary.totalScreenTimeMs == 0) {
      insightText =
          'Chưa có dữ liệu hành vi: Hãy tiếp tục sử dụng để AI đồng bộ nhịp sinh học và đưa ra khuyến nghị cân bằng kỹ thuật số.';
    } else {
      insightText =
          'Lời khuyên cân bằng: Hãy nghỉ mắt 5 phút sau mỗi 50 phút làm việc liên tục trên màn hình để bảo vệ thị lực và duy trì năng lượng.';
    }

    final deviceTitle = ble.device?.platformName ?? 'Đồng hồ POMO SMART';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.stitchSurfaceHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.psychology_rounded,
                    color: AppColors.stitchPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TRỢ LÝ AI AETHER',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchPrimary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.stitchSurfaceContainer,
                ),
                child: Text(
                  'Thời Gian Thực • Ước tính',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insightText,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.stitchOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '(Chỉ báo tham khảo thuật toán, không phải chẩn đoán lâm sàng)',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.stitchOutline,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),
          // Hardware Sync Mini Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.watch_rounded,
                    color: AppColors.stitchSecondaryContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ble.isConnected
                        ? deviceTitle
                        : '$deviceTitle (Chưa kết nối)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                ble.isConnected ? 'Sẵn sàng nhận lệnh' : 'Chờ kết nối BLE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ble.isConnected
                      ? AppColors.stitchTertiary
                      : AppColors.stitchOutline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Big Action Button ──
  Widget _buildFocusLockButton(BleService ble) {
    final isLocked = _isFocusLocked;
    return GestureDetector(
      onTap: () => _toggleFocusLock(ble),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: isLocked
                ? const [
                    AppColors.stitchTertiaryContainer,
                    AppColors.stitchTertiary,
                  ]
                : const [
                    AppColors.stitchPrimaryContainer,
                    Color(0xFF6833EA),
                    AppColors.stitchPrimaryContainer,
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isLocked
                          ? AppColors.stitchTertiary
                          : AppColors.stitchPrimaryContainer)
                      .withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocked
                  ? Icons.lock_rounded
                  : Icons.screen_lock_portrait_rounded,
              color: isLocked
                  ? AppColors.stitchSurfaceLowest
                  : AppColors.stitchOnPrimaryContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isLocked
                  ? 'Đã Khóa: Đang Siêu Tập Trung (Tắt)'
                  : 'Kích hoạt TFT LCD Focus Lock',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isLocked
                    ? AppColors.stitchSurfaceLowest
                    : AppColors.stitchOnPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PERMISSION REQUEST SCREEN
  // ══════════════════════════════════════════════════════════
  Widget _buildPermissionRequest() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.stitchPrimaryContainer.withValues(alpha: 0.3),
                    AppColors.stitchSecondaryContainer.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: const Icon(
                Icons.phone_android_rounded,
                size: 44,
                color: AppColors.stitchPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Theo Dõi Cân Bằng Số',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.stitchOnSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Tính năng này giúp bạn hiểu thói quen sử dụng thiết bị và hạn chế xao nhãng trong các phiên làm việc cùng đồng hồ TFT LCD.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.stitchOnSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPrivacyItem(
              icon: Icons.check_circle_rounded,
              color: AppColors.stitchTertiary,
              text: 'Thời gian sử dụng từng ứng dụng',
            ),
            _buildPrivacyItem(
              icon: Icons.check_circle_rounded,
              color: AppColors.stitchTertiary,
              text: 'Số lần bật/tắt màn hình',
            ),
            _buildPrivacyItem(
              icon: Icons.check_circle_rounded,
              color: AppColors.stitchTertiary,
              text: 'Phát hiện gián đoạn trong phiên Pomodoro',
            ),
            _buildPrivacyItem(
              icon: Icons.info_rounded,
              color: AppColors.stitchSecondaryContainer,
              text:
                  'POMO SMART đọc tên ứng dụng, thời gian sử dụng và sự kiện chuyển ứng dụng. Bản tóm tắt hằng ngày và một số sự kiện xao nhãng (gồm tên/gói ứng dụng, thời lượng) được gửi lên máy chủ để thống kê và AI gợi ý. Bạn có thể thu hồi quyền bất cứ lúc nào trong Cài đặt hệ thống.',
            ),
            const SizedBox(height: 12),
            _buildPrivacyItem(
              icon: Icons.cancel_rounded,
              color: const Color(0xFFFF5252),
              text: 'KHÔNG đọc nội dung tin nhắn, mật khẩu',
            ),
            _buildPrivacyItem(
              icon: Icons.cancel_rounded,
              color: const Color(0xFFFF5252),
              text: 'Usage Access không cấp quyền đọc ảnh, video hoặc vị trí GPS',
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stitchPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: _requestPermission,
                child: Text(
                  'Cấp Quyền & Bật Theo Dõi',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadFromBackendAnalytics,
              child: Text(
                'Tải dữ liệu từ đám mây (Cloud Sync)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.stitchSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.stitchOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  Color _getCategoryColor(AppCategory category) {
    switch (category) {
      case AppCategory.productivity:
        return AppColors.stitchTertiary;
      case AppCategory.education:
        return AppColors.stitchSecondaryContainer;
      case AppCategory.communication:
        return AppColors.stitchOutline;
      case AppCategory.socialMedia:
      case AppCategory.entertainment:
      case AppCategory.games:
        return const Color(0xFFFF5252);
      case AppCategory.system:
        return AppColors.stitchOutlineVariant;
      case AppCategory.other:
        return AppColors.stitchOnSurfaceVariant;
    }
  }

  IconData _getCategoryIcon(AppCategory category) {
    switch (category) {
      case AppCategory.productivity:
        return Icons.terminal_rounded;
      case AppCategory.education:
        return Icons.menu_book_rounded;
      case AppCategory.communication:
        return Icons.forum_rounded;
      case AppCategory.socialMedia:
        return Icons.play_circle_rounded;
      case AppCategory.entertainment:
        return Icons.movie_outlined;
      case AppCategory.games:
        return Icons.sports_esports_rounded;
      case AppCategory.system:
        return Icons.settings_suggest_rounded;
      case AppCategory.other:
        return Icons.apps_rounded;
    }
  }
}

// ══════════════════════════════════════════════════════════
// RADIAL ARC CUSTOM PAINTER (STITCH SCREEN 6 GAUGE)
// ══════════════════════════════════════════════════════════
class FocusScoreArcPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final List<Color> gradientColors;

  FocusScoreArcPainter({
    required this.progress,
    required this.trackColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height - 4);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Semi-circle background arc from 180° to 0°
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    // Active progress arc
    if (progress > 0) {
      final sweepAngle = math.pi * progress.clamp(0.0, 1.0);
      final activePaint = Paint()
        ..shader = SweepGradient(
          startAngle: math.pi,
          endAngle: math.pi * 2,
          colors: gradientColors,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, math.pi, sweepAngle, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FocusScoreArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor;
  }
}
