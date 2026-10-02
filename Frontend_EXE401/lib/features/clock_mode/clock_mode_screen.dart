import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/bluetooth/spp_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ClockTheme {
  final int id;
  final String name;
  final String description;
  final int mode;           // 0=Clock, 1=Pomodoro, 2=Timer, 3=BT
  final Color primary;
  final Color bg;
  final String fontStyle;  // 'digital','minimal','retro','bold'
  final bool hasAnimation;
  final IconData icon;

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
  });
}

const List<ClockTheme> kThemes = [
  // ── ĐỒNG HỒ ────────────────────────────────────────────────────────────────
  ClockTheme(
    id: 0, mode: 0, name: 'Midnight Digital',
    description: 'Đồng hồ số kiểu máy tính cổ điển',
    primary: Color(0xFF00FF88), bg: Colors.black,
    fontStyle: 'digital', icon: Icons.watch_rounded,
  ),
  ClockTheme(
    id: 1, mode: 0, name: 'Neon Cyber',
    description: 'Phong cách cyberpunk với màu sắc neon',
    primary: Color(0xFF00E5FF), bg: Color(0xFF050510),
    fontStyle: 'bold', icon: Icons.bolt_rounded,
  ),
  ClockTheme(
    id: 2, mode: 0, name: 'Sunset Minimal',
    description: 'Đơn giản, ấm áp như hoàng hôn',
    primary: Color(0xFFFF6B35), bg: Color(0xFF1A0A00),
    fontStyle: 'minimal', icon: Icons.wb_sunny_rounded,
  ),
  // ── POMODORO ────────────────────────────────────────────────────────────────
  ClockTheme(
    id: 3, mode: 1, name: 'Focus Ring',
    description: 'Vòng tròn xoay thể hiện tiến độ phiên học',
    primary: Color(0xFF7C4DFF), bg: Color(0xFF0A0015),
    fontStyle: 'bold', hasAnimation: true, icon: Icons.circle_outlined,
  ),
  ClockTheme(
    id: 4, mode: 1, name: 'Hourglass',
    description: 'Đồng hồ cát chảy — cảm giác thời gian trôi',
    primary: Color(0xFFFFD93D), bg: Color(0xFF1A1400),
    fontStyle: 'retro', hasAnimation: true, icon: Icons.hourglass_full_rounded,
  ),
  ClockTheme(
    id: 5, mode: 1, name: 'Deep Ocean',
    description: 'Sóng biển nhấp nhô theo từng phút tập trung',
    primary: Color(0xFF0099FF), bg: Color(0xFF000D1A),
    fontStyle: 'minimal', hasAnimation: true, icon: Icons.waves_rounded,
  ),
  // ── ĐẾM NGƯỢC ──────────────────────────────────────────────────────────────
  ClockTheme(
    id: 6, mode: 2, name: 'Pulse Blast',
    description: 'Số đếm ngược to, nảy theo nhịp tim',
    primary: Color(0xFFFF6B6B), bg: Color(0xFF1A0000),
    fontStyle: 'bold', hasAnimation: true, icon: Icons.favorite_rounded,
  ),
  ClockTheme(
    id: 7, mode: 2, name: 'Sand Timer',
    description: 'Cát chảy từ trên xuống đến khi hết giờ',
    primary: Color(0xFFE8A87C), bg: Color(0xFF1A0E00),
    fontStyle: 'retro', hasAnimation: true, icon: Icons.hourglass_bottom_rounded,
  ),
  ClockTheme(
    id: 8, mode: 2, name: 'Matrix Drop',
    description: 'Số rơi kiểu ma trận, đếm ngược theo giây',
    primary: Color(0xFF39FF14), bg: Colors.black,
    fontStyle: 'digital', hasAnimation: true, icon: Icons.terminal_rounded,
  ),
];

const Map<int, String> kModeName = {
  0: 'Đồng Hồ', 1: 'Pomodoro', 2: 'Đếm Ngược',
};
const Map<int, Color> kModeColor = {
  0: Color(0xFF00E5FF), 1: Color(0xFF7C4DFF), 2: Color(0xFFFF6B6B),
};

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
  bool _sending = false;
  late final AnimationController _liveAnim;
  late final AnimationController _shimmer;

  ClockTheme get _selected =>
      kThemes.firstWhere((t) => t.id == _selectedId, orElse: () => kThemes[0]);

  @override
  void initState() {
    super.initState();
    _liveAnim = AnimationController(vsync: this,
        duration: const Duration(seconds: 3))..repeat();
    _shimmer = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedId = prefs.getInt('clock_theme_id') ?? 0;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clock_theme_id', _selectedId);
  }

  Future<void> _apply(SppService spp) async {
    if (!spp.isConnected) {
      _showSnack('Chưa kết nối ESP32! Vào Pomodoro để kết nối trước.', Colors.redAccent);
      return;
    }
    setState(() => _sending = true);
    // Gửi cả mode lẫn theme ID
    await spp.sendJsonCommand('SET_MODE', {'mode': _selected.mode});
    await Future.delayed(const Duration(milliseconds: 200));

    // Gửi màu dạng hex string 6 ký tự "RRGGBB" để ESP32 parse dễ, tránh overflow
    final c = _selected.primary;
    final hexColor =
        '${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}';

    await spp.sendJsonCommand('SET_THEME', {
      'theme_id': _selectedId,
      'color': hexColor,
      'anim': _selected.hasAnimation,
    });
    await _savePrefs();
    setState(() => _sending = false);
    _showSnack('✓ Đã áp dụng: ${_selected.name}', const Color(0xFF4CAF50));
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _liveAnim.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SppService>(
      builder: (ctx, spp, _) => Scaffold(
        backgroundColor: const Color(0xFF050510),
        appBar: _buildAppBar(spp),
        body: Column(children: [
          // ── Live Watch Preview ──────────────────────────────────
          _LivePreview(
            theme: _selected,
            anim: _liveAnim,
          ),
          // ── Category Tabs + Theme Grid ──────────────────────────
          Expanded(child: _ThemeGallery(
            themes: kThemes,
            selectedId: _selectedId,
            shimmer: _shimmer,
            onSelect: (id) => setState(() => _selectedId = id),
          )),
          // ── Apply Button ─────────────────────────────────────────
          _ApplyBar(
            theme: _selected,
            sending: _sending,
            connected: spp.isConnected,
            onApply: () => _apply(spp),
          ),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SppService spp) {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Giao Diện Đồng Hồ',
            style: GoogleFonts.outfit(color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 18)),
        AnimatedBuilder(
          animation: _shimmer,
          builder: (_, __) => Text(
            spp.isConnected ? '● Đã kết nối ESP32' : '○ Chưa kết nối',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: spp.isConnected
                  ? Color.lerp(const Color(0xFF4CAF50),
                      const Color(0xFF80E080), _shimmer.value)!
                  : Colors.white38,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE PREVIEW — mô phỏng màn hình 320×240 đồng hồ
// ─────────────────────────────────────────────────────────────────────────────

class _LivePreview extends StatelessWidget {
  final ClockTheme theme;
  final AnimationController anim;
  const _LivePreview({
    required this.theme,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: theme.primary.withOpacity(0.15), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(children: [
          // Background
          Positioned.fill(child: _GradientBg(theme: theme)),
          // Nội dung theo theme
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) => _ThemeContent(theme: theme, anim: anim),
          ),
          // Nhãn chế độ
          Positioned(top: 6, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.primary.withOpacity(0.4)),
              ),
              child: Text(kModeName[theme.mode] ?? '',
                  style: GoogleFonts.outfit(
                      color: theme.primary, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GradientBg extends StatelessWidget {
  final ClockTheme theme;
  const _GradientBg({required this.theme});
  @override
  Widget build(BuildContext context) {
    // Theme 0: dark gray (flip clock)
    if (theme.id == 0) {
      return Container(color: const Color(0xFF111111));
    }
    // Theme 1: pure black (analog)
    if (theme.id == 1) {
      return Container(color: Colors.black);
    }
    // Theme 2: sunset gradient
    if (theme.id == 2) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFDD00), Color(0xFFFFA500), Color(0xFFFF4500),
              Color(0xFF8B0057), Color(0xFF1a003a), Color(0xFF000820),
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
      );
    }
    // Default gradient
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center, radius: 1.2,
          colors: [theme.primary.withOpacity(0.08), theme.bg],
        ),
      ),
    );
  }
}

class _ThemeContent extends StatelessWidget {
  final ClockTheme theme;
  final AnimationController anim;
  const _ThemeContent({required this.theme, required this.anim});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    switch (theme.mode) {
      case 0: return _ClockContent(theme: theme, now: now, anim: anim);
      case 1: return _PomodoroContent(theme: theme, anim: anim);
      case 2: return _TimerContent(theme: theme, anim: anim);
      default: return const SizedBox.shrink();
    }
  }
}

// Clock content variants — preview matching actual ESP32 themes
class _ClockContent extends StatelessWidget {
  final ClockTheme theme;
  final DateTime now;
  final AnimationController anim;
  const _ClockContent({required this.theme, required this.now, required this.anim});

  @override
  Widget build(BuildContext context) {
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');

    // ── Theme 0: FLIP CLOCK ──────────────────────────────────
    if (theme.id == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('FRI  ${now.day}/${now.month}/${now.year}',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF555566), fontSize: 10)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FlipCard(value: h, color: Colors.white),
                const SizedBox(width: 6),
                _FlipCard(value: m, color: Colors.white),
              ],
            ),
            const SizedBox(height: 4),
            Text('PM • :$s',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF444455), fontSize: 9)),
          ],
        ),
      );
    }

    // ── Theme 1: ANALOG + DIGITAL ────────────────────────────
    if (theme.id == 1) {
      return Row(
        children: [
          // Bảng số bên trái
          Expanded(
            flex: 42,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h, style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 34,
                      fontWeight: FontWeight.w900, height: 1.0)),
                  AnimatedBuilder(
                    animation: anim,
                    builder: (_, __) => Opacity(
                      opacity: (now.second % 2 == 0) ? 1.0 : 0.0,
                      child: Text(':',
                          style: GoogleFonts.outfit(
                              color: Colors.white38, fontSize: 18,
                              fontWeight: FontWeight.w900, height: 0.6)),
                    ),
                  ),
                  Text(m, style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 34,
                      fontWeight: FontWeight.w900, height: 1.0)),
                  const SizedBox(height: 6),
                  Text('T.Sáu  ${now.day}/${now.month}',
                      style: GoogleFonts.outfit(
                          color: Colors.white38, fontSize: 9)),
                ],
              ),
            ),
          ),
          // Phân cách dọc
          Container(width: 1, height: double.infinity,
              color: const Color(0xFF2A2A2A)),
          // Mặt đồng hồ analog
          Expanded(
            flex: 58,
            child: Center(
              child: AnimatedBuilder(
                animation: anim,
                builder: (_, __) => CustomPaint(
                  size: const Size(120, 120),
                  painter: _AnalogFacePainter(
                    hour: now.hour, minute: now.minute, second: now.second,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Theme 2: SUNSET GRADIENT ─────────────────────────────
    if (theme.id == 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('T.Sáu  ${now.day}/${now.month}/${now.year}',
                style: GoogleFonts.outfit(
                    color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 2),
            Text('$h:$m',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 44,
                    fontWeight: FontWeight.w300, height: 1.1)),
            Row(children: [
              const Icon(Icons.wb_sunny_rounded,
                  color: Color(0xFFFFDD00), size: 14),
              const SizedBox(width: 4),
              Text('33°C',
                  style: GoogleFonts.outfit(
                      color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(':$s',
                  style: GoogleFonts.outfit(
                      color: Colors.white38, fontSize: 12)),
            ]),
          ],
        ),
      );
    }

    // Fallback — generic digital
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$h:$m', style: GoogleFonts.orbitron(
          color: theme.primary, fontSize: 34, fontWeight: FontWeight.bold)),
      Text(s, style: GoogleFonts.outfit(
          color: theme.primary.withOpacity(0.6), fontSize: 14)),
      Text('${now.day}/${now.month}/${now.year}',
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
    ]));
  }
}

// Flip card widget (theme 0)
class _FlipCard extends StatelessWidget {
  final String value;
  final Color color;
  const _FlipCard({required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 66,
      decoration: BoxDecoration(
        color: const Color(0xFF222230),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF444455), width: 1),
      ),
      child: Center(
        child: Text(value,
            style: GoogleFonts.outfit(
                color: color, fontSize: 36, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

// Analog clock face painter
class _AnalogFacePainter extends CustomPainter {
  final int hour, minute, second;
  _AnalogFacePainter({required this.hour, required this.minute, required this.second});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    // Face
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A0A18));
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white24 ..style = PaintingStyle.stroke ..strokeWidth = 1.5);

    // Tick marks
    for (int i = 0; i < 60; i++) {
      final a = (i * 6 - 90) * math.pi / 180;
      final isH = i % 5 == 0;
      final r0 = isH ? r - 4 : r - 3;
      final r1 = isH ? r - 12 : r - 7;
      canvas.drawLine(
        Offset(c.dx + r0 * math.cos(a), c.dy + r0 * math.sin(a)),
        Offset(c.dx + r1 * math.cos(a), c.dy + r1 * math.sin(a)),
        Paint()..color = isH ? Colors.white70 : Colors.white24
          ..strokeWidth = isH ? 1.5 : 0.8,
      );
    }

    // Hour hand
    final hA = ((hour % 12) + minute / 60.0) * 30 * math.pi / 180 - math.pi / 2;
    canvas.drawLine(c,
      Offset(c.dx + r * 0.48 * math.cos(hA), c.dy + r * 0.48 * math.sin(hA)),
      Paint()..color = Colors.white ..strokeWidth = 3 ..strokeCap = StrokeCap.round);

    // Minute hand
    final mA = (minute + second / 60.0) * 6 * math.pi / 180 - math.pi / 2;
    canvas.drawLine(c,
      Offset(c.dx + r * 0.70 * math.cos(mA), c.dy + r * 0.70 * math.sin(mA)),
      Paint()..color = Colors.white70 ..strokeWidth = 2 ..strokeCap = StrokeCap.round);

    // Second hand
    final sA = second * 6 * math.pi / 180 - math.pi / 2;
    canvas.drawLine(
      Offset(c.dx - r * 0.15 * math.cos(sA), c.dy - r * 0.15 * math.sin(sA)),
      Offset(c.dx + r * 0.82 * math.cos(sA), c.dy + r * 0.82 * math.sin(sA)),
      Paint()..color = Colors.red ..strokeWidth = 1.2 ..strokeCap = StrokeCap.round);

    // Center dot
    canvas.drawCircle(c, 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(c, 2, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(_AnalogFacePainter o) =>
    o.hour != hour || o.minute != minute || o.second != second;
}


// Pomodoro content variants
class _PomodoroContent extends StatelessWidget {
  final ClockTheme theme;
  final AnimationController anim;
  const _PomodoroContent({required this.theme, required this.anim});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, height: double.infinity,
      color: Colors.black, // Nền đen chuẩn ESP32
      child: Stack(children: [
        // Khung viền ngoài
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
        ),
        // Chữ LÀM VIỆC
        Positioned(
          top: 10, left: 14,
          child: Text('LÀM VIỆC', style: GoogleFonts.outfit(
            color: theme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        // Số đếm ngược
        Center(
          child: Text('25:00', style: GoogleFonts.outfit(
            color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
        ),
        // Thanh tiến độ ngang
        Positioned(
          bottom: 15, left: 14, right: 14,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) => FractionallySizedBox(
                widthFactor: anim.value,
                child: Container(color: theme.primary),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// Timer content variants
class _TimerContent extends StatelessWidget {
  final ClockTheme theme;
  final AnimationController anim;
  const _TimerContent({required this.theme, required this.anim});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, height: double.infinity,
      color: Colors.black,
      child: Stack(children: [
        // Chữ ĐẾM NGƯỢC
        Positioned(
          top: 10, left: 14,
          child: Text('TIMER', style: GoogleFonts.outfit(
            color: theme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        // Số đếm ngược siêu to giữa màn hình
        Center(
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Opacity(
              opacity: (anim.value * 10).toInt() % 2 == 0 ? 1.0 : 0.6,
              child: Text('05:00', style: GoogleFonts.orbitron(
                color: theme.primary, fontSize: 52, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        // Vòng cung tiến độ mỏng bên ngoài (mô phỏng)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: CustomPaint(
              painter: _RingPainter(progress: anim.value, color: theme.primary),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    final track = Paint()..color = color.withOpacity(0.15)
      ..strokeWidth = 8 ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final arc = Paint()..color = color..strokeWidth = 8
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, 2 * math.pi * progress, false, arc);
    // Spinning dot
    final angle = -math.pi / 2 + 2 * math.pi * progress;
    final dot = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle)), 4, dot);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}

class _HourglassPainter extends CustomPainter {
  final double progress;
  final Color color;
  _HourglassPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final frame = Paint()..color = color.withOpacity(0.4)
      ..strokeWidth = 2..style = PaintingStyle.stroke;
    final w = size.width; final h = size.height;

    // Hourglass frame
    final path = Path()
      ..moveTo(0, 0)..lineTo(w, 0)..lineTo(w / 2, h / 2)
      ..lineTo(w, h)..lineTo(0, h)..lineTo(w / 2, h / 2)..close();
    canvas.drawPath(path, frame);

    // Sand top (draining)
    final topH = (h / 2) * (1 - progress);
    if (topH > 0) {
      final topPath = Path()
        ..moveTo(0, 0)..lineTo(w, 0)
        ..lineTo(w / 2 + (w / 2) * (topH / (h / 2)), topH)
        ..lineTo(w / 2 - (w / 2) * (topH / (h / 2)), topH)..close();
      canvas.drawPath(topPath, p);
    }
    // Sand bottom (filling)
    final botH = (h / 2) * progress;
    if (botH > 0) {
      final botPath = Path()
        ..moveTo(w / 2, h / 2)
        ..lineTo(w / 2 + (w / 2) * (botH / (h / 2)), h - botH + botH)
        ..lineTo(w / 2 - (w / 2) * (botH / (h / 2)), h - botH + botH)..close();
      canvas.drawPath(botPath, p..color = color.withOpacity(0.7));
    }
  }

  @override
  bool shouldRepaint(_HourglassPainter o) => o.progress != progress;
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.25)..style = PaintingStyle.fill;
    final wave = Path();
    final fillH = size.height * (1 - 0.3 - 0.4 * progress);
    wave.moveTo(0, fillH);
    for (double x = 0; x <= size.width; x += 2) {
      wave.lineTo(x, fillH +
          8 * math.sin((x / size.width * 2 * math.pi) + progress * 2 * math.pi) +
          4 * math.sin((x / size.width * 4 * math.pi) + progress * 3 * math.pi));
    }
    wave.lineTo(size.width, size.height);
    wave.lineTo(0, size.height);
    wave.close();
    canvas.drawPath(wave, p);
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.progress != progress;
}

class _SandPainter extends CustomPainter {
  final double progress;
  final Color color;
  _SandPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final p = Paint()..color = color;
    final particlesBottom = (progress * 40).round();
    for (int i = 0; i < particlesBottom; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width,
            size.height * 0.6 + rng.nextDouble() * size.height * 0.4),
        1.5, p..color = color.withOpacity(0.8),
      );
    }
    // Falling stream
    if (progress < 1) {
      canvas.drawCircle(
        Offset(size.width / 2,
            size.height * 0.3 + (size.height * 0.3) * (progress % 1)),
        2, p..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SandPainter o) => o.progress != progress;
}

class _MatrixPainter extends CustomPainter {
  final double progress;
  final Color color;
  _MatrixPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const chars = '0123456789';
    final rng = math.Random(12);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int col = 0; col < 12; col++) {
      final x = col * (size.width / 12);
      final dropY = (progress * size.height * (1 + rng.nextDouble())) % size.height;
      for (int row = 0; row < 5; row++) {
        final y = (dropY - row * 14) % size.height;
        final opacity = 1.0 - row / 5;
        tp.text = TextSpan(
          text: chars[rng.nextInt(chars.length)],
          style: GoogleFonts.orbitron(
              color: color.withOpacity(opacity * 0.6), fontSize: 10),
        );
        tp.layout();
        tp.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(_MatrixPainter o) => o.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME GALLERY
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeGallery extends StatefulWidget {
  final List<ClockTheme> themes;
  final int selectedId;
  final AnimationController shimmer;
  final ValueChanged<int> onSelect;
  const _ThemeGallery({
    required this.themes, required this.selectedId,
    required this.shimmer, required this.onSelect,
  });
  @override
  State<_ThemeGallery> createState() => _ThemeGalleryState();
}

class _ThemeGalleryState extends State<_ThemeGallery>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final List<int> _modes = [0, 1, 2];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _modes.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Tab bar
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D2A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [
                Color(0xFF7C4DFF), Color(0xFF00E5FF)]),
            ),
            labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: _modes.map((m) => Tab(text: kModeName[m] ?? '')).toList(),
          ),
        ),
      ),
      const SizedBox(height: 8),
      // Theme cards
      Expanded(child: TabBarView(
        controller: _tab,
        children: _modes.map((mode) {
          final modeThemes = widget.themes.where((t) => t.mode == mode).toList();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: modeThemes.length,
            itemBuilder: (_, i) {
              final t = modeThemes[i];
              final isSelected = t.id == widget.selectedId;
              return _ThemeCard(
                theme: t,
                isSelected: isSelected,
                shimmer: widget.shimmer,
                onTap: () => widget.onSelect(t.id),
              );
            },
          );
        }).toList(),
      )),
    ]);
  }
}

class _ThemeCard extends StatelessWidget {
  final ClockTheme theme;
  final bool isSelected;
  final AnimationController shimmer;
  final VoidCallback onTap;
  const _ThemeCard({
    required this.theme, required this.isSelected,
    required this.shimmer, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isSelected
              ? LinearGradient(colors: [
                  theme.primary.withOpacity(0.2),
                  theme.bg.withOpacity(0.8),
                ])
              : LinearGradient(colors: [
                  const Color(0xFF0D0D2A), const Color(0xFF0A0A1A),
                ]),
          border: Border.all(
            color: isSelected ? theme.primary : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.primary.withOpacity(0.2), blurRadius: 12)]
              : [],
        ),
        child: Row(children: [
          // Thumbnail
          Container(
            width: 56, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.bg,
              border: Border.all(color: theme.primary.withOpacity(0.4)),
            ),
            child: Center(child: Icon(theme.icon, color: theme.primary, size: 20)),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(theme.name,
                    style: GoogleFonts.outfit(
                        color: isSelected ? theme.primary : Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 13)),
                if (theme.hasAnimation) ...[
                  const SizedBox(width: 6),
                  AnimatedBuilder(
                    animation: shimmer,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.1 + 0.1 * shimmer.value),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: theme.primary.withOpacity(0.4)),
                      ),
                      child: Text('ĐỘNG',
                          style: GoogleFonts.outfit(
                              color: theme.primary, fontSize: 8,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(theme.description,
                  style: GoogleFonts.outfit(
                      color: Colors.white38, fontSize: 11)),
            ],
          )),
          // Selected indicator
          if (isSelected)
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primary.withOpacity(0.2),
                border: Border.all(color: theme.primary),
              ),
              child: Icon(Icons.check, color: theme.primary, size: 14),
            )
          else
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPLY BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ApplyBar extends StatelessWidget {
  final ClockTheme theme;
  final bool sending;
  final bool connected;
  final VoidCallback onApply;
  const _ApplyBar({
    required this.theme, required this.sending,
    required this.connected, required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              connected ? theme.primary : Colors.grey.shade700,
              (connected ? theme.primary : Colors.grey.shade700).withOpacity(0.6),
            ]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: connected ? [
              BoxShadow(color: theme.primary.withOpacity(0.3),
                  blurRadius: 16, offset: const Offset(0, 4))
            ] : [],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: sending ? null : onApply,
            icon: sending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(
              sending ? 'Đang gửi xuống đồng hồ...'
                  : connected
                      ? 'Áp Dụng Lên Đồng Hồ — ${theme.name}'
                      : 'Cần kết nối BLE trước',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
