import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:fl_chart/fl_chart.dart";
import "../../core/api/ai_api.dart";
import "../../core/api/auth_api.dart";
import "../../core/api/api_client.dart";
import "ai_assistant_screen.dart";

/// AI Hub - Man hinh trung tam cua tat ca tinh nang AI:
/// - Adaptive Pomodoro Recommendation
/// - Daily Coach Advice
/// - Burnout Risk Gauge
/// - Context (Thoi tiet + Loi khuyen)
class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});
  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> {
  AiRecommendation? _recommendation;
  BurnoutRisk? _burnout;
  CoachAdvice? _coach;
  Map<String, dynamic>? _context;
  bool _loading = true;
  String _userName = "Ban";
  double _concScore = 65;
  String _taskType = "general";

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      _userName = await AuthApi.getUserName();
      final results = await Future.wait([
        AiApi.getPomodoroRecommendation(
          concentrationScore: _concScore, taskType: _taskType),
        AiApi.getBurnoutRisk(),
        AiApi.getDailyAdvice(),
        AiApi.getTodayContext(),
      ]);
      setState(() {
        _recommendation = results[0] as AiRecommendation;
        _burnout = results[1] as BurnoutRisk;
        _coach = results[2] as CoachAdvice;
        _context = results[3] as Map<String, dynamic>;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Loi API: ${e.message}"), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Khong ket noi duoc Backend"),
            backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7C4DFF),
        icon: const Icon(Icons.psychology_rounded, color: Colors.white),
        label: Text("Live AI Coach", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIAssistantScreen()),
          );
        },
      ),
      body: CustomScrollView(slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 120,
          backgroundColor: const Color(0xFF050510),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("AI Productivity Hub",
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700,
                    color: Colors.white)),
                Text("Xin chao, $_userName!",
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9E9EC2))),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
              onPressed: _loadAll,
            ),
            const SizedBox(width: 8),
          ],
        ),

        if (_loading)
          const SliverFillRemaining(child: Center(
            child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
          ))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // ============================================================
              // 1. Context Card (Thoi tiet)
              // ============================================================
              if (_context != null) _ContextCard(ctx: _context!),
              const SizedBox(height: 16),

              // ============================================================
              // 2. Concentration Slider + AI Recommendation
              // ============================================================
              _SectionTitle(icon: Icons.timer_rounded, title: "Adaptive Pomodoro"),
              const SizedBox(height: 10),
              _ConcentrationSlider(
                value: _concScore,
                taskType: _taskType,
                onConcentrationChanged: (v) => setState(() => _concScore = v),
                onTaskTypeChanged: (t) => setState(() => _taskType = t),
                onRefresh: _loadAll,
              ),
              const SizedBox(height: 10),
              if (_recommendation != null) _RecommendationCard(rec: _recommendation!),
              const SizedBox(height: 20),

              // ============================================================
              // 3. Daily Coach Advice
              // ============================================================
              _SectionTitle(icon: Icons.psychology_rounded, title: "AI Coach Hom Nay"),
              const SizedBox(height: 10),
              if (_coach != null) _CoachCard(coach: _coach!),
              const SizedBox(height: 20),

              // ============================================================
              // 4. Burnout Risk Gauge
              // ============================================================
              _SectionTitle(icon: Icons.favorite_border_rounded, title: "Nguy Co Burnout"),
              const SizedBox(height: 10),
              if (_burnout != null) _BurnoutCard(risk: _burnout!),
              const SizedBox(height: 32),
            ])),
          ),
      ]),
    );
  }
}

// ============================================================
// Widget: Section Title
// ============================================================
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: const Color(0xFF7C4DFF), size: 18),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.outfit(
      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
  ]);
}

// ============================================================
// Widget: Context (Weather) Card
// ============================================================
class _ContextCard extends StatelessWidget {
  final Map<String, dynamic> ctx;
  const _ContextCard({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final weather = ctx["weather"] as Map<String, dynamic>? ?? {};
    final advice = ctx["productivity_advice"] as String? ?? "";
    final temp = weather["temp_c"] ?? "--";
    final desc = weather["description"] ?? "Khong co du lieu";
    final humidity = weather["humidity"] ?? "--";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0D1B3E), const Color(0xFF0D0D2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFB300), size: 20),
          const SizedBox(width: 8),
          Text("Thoi Tiet & Ngu Canh", style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9E9EC2))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text("$temp°C", style: GoogleFonts.outfit(
            fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc.toString().toUpperCase(), style: GoogleFonts.outfit(
              fontSize: 11, color: const Color(0xFF9E9EC2), letterSpacing: 0.5)),
            Text("Do am: $humidity%", style: GoogleFonts.outfit(
              fontSize: 12, color: const Color(0xFF9E9EC2))),
          ])),
        ]),
        if (advice.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.15)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(advice, style: GoogleFonts.outfit(
                fontSize: 12, color: const Color(0xFFB0BEC5), height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ============================================================
// Widget: Concentration Slider + Task Type
// ============================================================
class _ConcentrationSlider extends StatelessWidget {
  final double value;
  final String taskType;
  final ValueChanged<double> onConcentrationChanged;
  final ValueChanged<String> onTaskTypeChanged;
  final VoidCallback onRefresh;

  const _ConcentrationSlider({
    required this.value, required this.taskType,
    required this.onConcentrationChanged, required this.onTaskTypeChanged,
    required this.onRefresh,
  });

  static const _tasks = [
    ("general", "Chung"), ("coding", "Code"),
    ("reading", "Doc"), ("meeting", "Hop"),
  ];

  @override
  Widget build(BuildContext context) {
    final color = value >= 68 ? const Color(0xFF43A047)
                : value >= 34 ? const Color(0xFFFFB300)
                : const Color(0xFFE53935);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E3A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Diem Tap Trung Hien Tai", style: GoogleFonts.outfit(
            fontSize: 13, color: const Color(0xFF9E9EC2))),
          Text("${value.round()}/100",
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ]),
        Slider(
          value: value, min: 0, max: 100, divisions: 20,
          activeColor: color,
          inactiveColor: const Color(0xFF1E1E3A),
          onChanged: onConcentrationChanged,
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text("Loai Task: ", style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9E9EC2))),
          const SizedBox(width: 8),
          ...(_tasks.map((t) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onTaskTypeChanged(t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: taskType == t.$1 ? const Color(0xFF7C4DFF) : const Color(0xFF1A1A3E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(t.$2, style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: taskType == t.$1 ? Colors.white : const Color(0xFF9E9EC2),
                )),
              ),
            ),
          ))),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
          label: Text("Lay Goi Y AI", style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600, color: Colors.white)),
          onPressed: onRefresh,
        )),
      ]),
    );
  }
}

// ============================================================
// Widget: AI Recommendation Card
// ============================================================
class _RecommendationCard extends StatelessWidget {
  final AiRecommendation rec;
  const _RecommendationCard({required this.rec});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A0533), Color(0xFF0A1628)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.4)),
      boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.1),
        blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.psychology_rounded, color: Color(0xFF7C4DFF), size: 18),
        const SizedBox(width: 8),
        Text("Goi y cua AI (${(rec.confidence * 100).round()}% tu tin)",
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9E9EC2))),
      ]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _StatPill("Lam Viec", "${rec.workMin} phut", const Color(0xFF00E5FF)),
        _StatPill("Nghi Ngoi", "${rec.breakMin} phut", const Color(0xFF7C4DFF)),
      ]),
      const SizedBox(height: 12),
      Text(rec.reason, style: GoogleFonts.outfit(
        fontSize: 12, color: const Color(0xFFB0BEC5), height: 1.5)),
    ]),
  );
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.outfit(
      fontSize: 28, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9E9EC2))),
  ]);
}

// ============================================================
// Widget: Coach Advice Card
// ============================================================
class _CoachCard extends StatelessWidget {
  final CoachAdvice coach;
  const _CoachCard({required this.coach});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D2A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.tips_and_updates_rounded,
            color: Color(0xFF00E5FF), size: 18),
        ),
        const SizedBox(width: 10),
        Text(coach.personalized ? "Ca Nhan Hoa" : "Tong Quat",
          style: GoogleFonts.outfit(fontSize: 12,
            color: coach.personalized ? const Color(0xFF00E5FF) : const Color(0xFF9E9EC2))),
      ]),
      const SizedBox(height: 12),
      Text(coach.advice, style: GoogleFonts.outfit(
        fontSize: 14, color: Colors.white, height: 1.6)),
      if (coach.stats.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: coach.stats.entries.map((e) =>
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A3E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text("${_statLabel(e.key)}: ${e.value}",
              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF9E9EC2))),
          )
        ).toList()),
      ],
    ]),
  );

  String _statLabel(String key) {
    switch (key) {
      case "avg_concentration_score": return "Tap trung TB";
      case "break_skip_rate": return "Bo qua break";
      case "completion_rate": return "Hoan thanh";
      default: return key;
    }
  }
}

// ============================================================
// Widget: Burnout Risk Card
// ============================================================
class _BurnoutCard extends StatelessWidget {
  final BurnoutRisk risk;
  const _BurnoutCard({required this.risk});

  @override
  Widget build(BuildContext context) {
    final levelColors = {
      "low": const Color(0xFF43A047),
      "medium": const Color(0xFFFFB300),
      "high": const Color(0xFFFF6F00),
      "critical": const Color(0xFFE53935),
    };
    final c = levelColors[risk.riskLevel] ?? const Color(0xFF43A047);
    final levelLabels = {
      "low": "Thap", "medium": "Trung Binh", "high": "Cao", "critical": "Nguy Hiem",
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Score + Level
        Row(children: [
          SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: risk.riskScore / 100,
              backgroundColor: c.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(c),
              strokeWidth: 7,
            ),
            Text("${risk.riskScore.round()}",
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
          ])),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("MUC DO: ${(levelLabels[risk.riskLevel] ?? "").toUpperCase()}",
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
            ),
            const SizedBox(height: 8),
            Text(risk.advice, style: GoogleFonts.outfit(
              fontSize: 12, color: const Color(0xFFB0BEC5), height: 1.4)),
          ])),
        ]),
        if (risk.indicators.isNotEmpty &&
            !(risk.indicators.length == 1 && risk.indicators[0].contains("Tat ca"))) ...[
          const SizedBox(height: 14),
          Text("Dau hieu phat hien:", style: GoogleFonts.outfit(
            fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF9E9EC2))),
          const SizedBox(height: 6),
          ...risk.indicators.map((ind) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.circle, color: c, size: 6),
              const SizedBox(width: 8),
              Expanded(child: Text(ind, style: GoogleFonts.outfit(
                fontSize: 12, color: const Color(0xFFB0BEC5)))),
            ]),
          )),
        ],
      ]),
    );
  }
}
