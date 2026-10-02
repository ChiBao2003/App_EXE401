import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/usage_tracking/usage_tracker_service.dart';
import '../../core/usage_tracking/models.dart';

/// Digital Wellbeing Dashboard — Theo dõi sức khỏe số
/// Hiển thị Focus Score, Screen Time, Top Apps, AI Insight
class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({super.key});
  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen>
    with TickerProviderStateMixin {
  final _tracker = UsageTrackerService();
  bool _loading = true;
  bool _hasPermission = false;
  DailyUsageSummary? _summary;
  List<AppUsageInfo> _allApps = [];

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

  Future<void> _checkAndLoad() async {
    setState(() => _loading = true);
    try {
      _hasPermission = await _tracker.hasPermission();
      if (_hasPermission) {
        await _loadData();
      }
    } catch (e) {
      debugPrint('[Wellbeing] Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadData() async {
    final summary = await _tracker.getDailySummary();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final allApps = await _tracker.getUsageStats(
      start: startOfDay,
      end: now,
    );
    
    // Đẩy data lên Backend
    await _tracker.syncToBackend(summary);

    if (mounted) {
      setState(() {
        _summary = summary;
        _allApps = allApps;
      });
      // Animate focus score
      _scoreAnim = Tween<double>(begin: 0, end: summary.focusScore).animate(
        CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeOutCubic),
      );
      _scoreAnimCtrl.forward(from: 0);
    }
  }

  Future<void> _requestPermission() async {
    await _tracker.requestPermission();
    // Show dialog reminding user to come back
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Cấp quyền Usage Access',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Bật quyền cho "Eink Clock" trong danh sách, sau đó quay lại app.',
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _checkAndLoad();
              },
              child: Text('Đã cấp xong',
                  style: GoogleFonts.outfit(color: const Color(0xFF00E5FF))),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Digital Wellbeing',
            style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          if (_hasPermission)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
              onPressed: _checkAndLoad,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
          : !_hasPermission
              ? _buildPermissionRequest()
              : _buildDashboard(),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PERMISSION REQUEST SCREEN
  // ══════════════════════════════════════════════════════════
  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C4DFF).withOpacity(0.3),
                    const Color(0xFF00E5FF).withOpacity(0.1),
                  ],
                ),
              ),
              child: const Icon(Icons.phone_android_rounded,
                  size: 48, color: Color(0xFF7C4DFF)),
            ),
            const SizedBox(height: 24),

            Text('Theo dõi sử dụng điện thoại',
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),

            Text(
              'Tính năng này giúp bạn hiểu thói quen sử dụng điện thoại '
              'và cải thiện khả năng tập trung trong các phiên Pomodoro.',
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF9E9EC2)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // What we collect
            _PrivacyItem(icon: Icons.check_circle, color: const Color(0xFF00E676),
                text: 'Thời gian sử dụng từng ứng dụng'),
            _PrivacyItem(icon: Icons.check_circle, color: const Color(0xFF00E676),
                text: 'Số lần bật/tắt màn hình'),
            _PrivacyItem(icon: Icons.check_circle, color: const Color(0xFF00E676),
                text: 'Phát hiện mất tập trung trong Pomodoro'),
            const SizedBox(height: 12),

            // What we DON'T collect
            _PrivacyItem(icon: Icons.cancel, color: const Color(0xFFFF5252),
                text: 'KHÔNG đọc tin nhắn, mật khẩu'),
            _PrivacyItem(icon: Icons.cancel, color: const Color(0xFFFF5252),
                text: 'KHÔNG truy cập ảnh, video, GPS'),
            const SizedBox(height: 32),

            // CTA Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _requestPermission,
                child: Text('Đồng ý & Bật theo dõi',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // MAIN DASHBOARD
  // ══════════════════════════════════════════════════════════
  Widget _buildDashboard() {
    final summary = _summary;
    if (summary == null) {
      return Center(
        child: Text('Chưa có dữ liệu hôm nay',
            style: GoogleFonts.outfit(color: const Color(0xFF9E9EC2))),
      );
    }

    return RefreshIndicator(
      onRefresh: _checkAndLoad,
      color: const Color(0xFF7C4DFF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Focus Score Ring ──
            _buildFocusScoreCard(summary),
            const SizedBox(height: 16),

            // ── Stats Row ──
            _buildStatsRow(summary),
            const SizedBox(height: 16),

            // ── Top Apps ──
            _buildTopAppsCard(),
            const SizedBox(height: 16),

            // ── Category Pie Chart ──
            _buildCategoryChart(summary),
            const SizedBox(height: 16),

            // ── AI Insight ──
            _buildAiInsightCard(summary),
          ],
        ),
      ),
    );
  }

  // ── Focus Score Card ──
  Widget _buildFocusScoreCard(DailyUsageSummary summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A3E), Color(0xFF0D0D2B)],
        ),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        children: [
          Text('FOCUS SCORE',
              style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: const Color(0xFF9E9EC2), letterSpacing: 2)),
          const SizedBox(height: 16),

          // Animated Score Ring
          SizedBox(
            width: 160, height: 160,
            child: AnimatedBuilder(
              animation: _scoreAnim,
              builder: (context, child) {
                final score = _scoreAnim.value;
                final color = _getScoreColor(score);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160, height: 160,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 12,
                        backgroundColor: const Color(0xFF2A2A4A),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(score.toInt().toString(),
                            style: GoogleFonts.outfit(
                                fontSize: 48, fontWeight: FontWeight.w800,
                                color: color)),
                        Text('/100',
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: const Color(0xFF9E9EC2))),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          Text(_getScoreMessage(summary.focusScore),
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Stats Row ──
  Widget _buildStatsRow(DailyUsageSummary summary) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon: Icons.phone_android_rounded,
          iconColor: const Color(0xFF00E5FF),
          label: 'Screen Time',
          value: summary.totalScreenTimeText,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          icon: Icons.lock_open_rounded,
          iconColor: const Color(0xFFFFAB40),
          label: 'Unlocks',
          value: summary.totalUnlocks.toString(),
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFFF5252),
          label: 'Mất TT',
          value: summary.totalDistractions.toString(),
        )),
      ],
    );
  }

  // ── Top Apps ──
  Widget _buildTopAppsCard() {
    final topApps = _allApps.take(5).toList();
    if (topApps.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxTime = topApps.first.foregroundTimeMs.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF12122A),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apps_rounded, color: Color(0xFF7C4DFF), size: 20),
              const SizedBox(width: 8),
              Text('Top ứng dụng hôm nay',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          ...topApps.map((app) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Category indicator
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getCategoryColor(app.category),
                  ),
                ),
                const SizedBox(width: 10),

                // App name
                Expanded(
                  flex: 3,
                  child: Text(app.appName,
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                ),

                // Duration text
                SizedBox(
                  width: 48,
                  child: Text(app.durationText,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: const Color(0xFF9E9EC2)),
                      textAlign: TextAlign.right),
                ),
                const SizedBox(width: 10),

                // Progress bar
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxTime > 0 ? app.foregroundTimeMs / maxTime : 0,
                      backgroundColor: const Color(0xFF2A2A4A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _getCategoryColor(app.category)),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Category Pie Chart ──
  Widget _buildCategoryChart(DailyUsageSummary summary) {
    // Group apps by category
    final Map<AppCategory, int> categoryTimes = {};
    for (final app in _allApps) {
      if (app.category == AppCategory.system) continue;
      categoryTimes[app.category] =
          (categoryTimes[app.category] ?? 0) + app.foregroundTimeMs;
    }
    if (categoryTimes.isEmpty) return const SizedBox.shrink();

    final total = categoryTimes.values.fold(0, (a, b) => a + b);
    final entries = categoryTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF12122A),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              Text('Phân bổ thời gian',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                // Pie
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: entries.map((e) {
                        final pct = (e.value / total * 100);
                        return PieChartSectionData(
                          value: pct,
                          color: _getCategoryColor(e.key),
                          radius: 50,
                          title: '${pct.toInt()}%',
                          titleStyle: GoogleFonts.outfit(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.take(5).map((e) {
                    final mins = e.value ~/ 60000;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getCategoryColor(e.key),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${e.key.label} ${mins}m',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: const Color(0xFFCCCCDD))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Insight Card ──
  Widget _buildAiInsightCard(DailyUsageSummary summary) {
    // Tạo insight message dựa trên data thực tế
    String insight;
    if (summary.focusScore >= 85) {
      insight = '🎉 Tuyệt vời! Hôm nay bạn tập trung rất tốt. '
          'Thời gian productive chiếm ${summary.productiveTimeText}. Tiếp tục phát huy!';
    } else if (summary.focusScore >= 60) {
      insight = '💪 Khá tốt! Bạn có thể cải thiện thêm bằng cách giảm '
          '${summary.distractedTimeText} dùng app giải trí. '
          'Thử đặt giới hạn thời gian cho social media nhé!';
    } else {
      insight = '⚠️ Hôm nay bạn dùng app giải trí khá nhiều '
          '(${summary.distractedTimeText}). Hãy thử tắt notification '
          'của các app social media khi chạy Pomodoro!';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7C4DFF).withOpacity(0.15),
            const Color(0xFF00E5FF).withOpacity(0.05),
          ],
        ),
        border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD740), size: 20),
              const SizedBox(width: 8),
              Text('AI Insight',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Text(insight,
              style: GoogleFonts.outfit(
                  fontSize: 14, height: 1.5, color: const Color(0xFFCCCCDD))),
        ],
      ),
    );
  }

  // ── Helpers ──
  Color _getScoreColor(double score) {
    if (score >= 80) return const Color(0xFF00E676);
    if (score >= 60) return const Color(0xFFFFAB40);
    if (score >= 40) return const Color(0xFFFF9100);
    return const Color(0xFFFF5252);
  }

  String _getScoreMessage(double score) {
    if (score >= 80) return '🏆 Xuất sắc! Bạn tập trung rất tốt hôm nay';
    if (score >= 60) return '💪 Khá tốt! Còn có thể cải thiện thêm';
    if (score >= 40) return '😐 Trung bình. Hãy thử giảm dùng social media';
    return '😰 Cần cải thiện. Thử bật Focus Mode nhé!';
  }

  Color _getCategoryColor(AppCategory category) {
    switch (category) {
      case AppCategory.productivity: return const Color(0xFF00E676);
      case AppCategory.education: return const Color(0xFF40C4FF);
      case AppCategory.communication: return const Color(0xFFFFAB40);
      case AppCategory.socialMedia: return const Color(0xFFFF5252);
      case AppCategory.entertainment: return const Color(0xFFFF6E40);
      case AppCategory.games: return const Color(0xFFE040FB);
      case AppCategory.system: return const Color(0xFF78909C);
      case AppCategory.other: return const Color(0xFF9E9EC2);
    }
  }
}

// ══════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════

class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _PrivacyItem({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon, required this.iconColor,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF12122A),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF9E9EC2)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
