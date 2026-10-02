import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/bluetooth/spp_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/api/api_client.dart';
import 'digital_twin_dashboard.dart';

// ============================================================
// Model: ChatMessage (mở rộng với schedulePlan)
// ============================================================
class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> toolCalls;
  /// Dữ liệu lịch trình AI tạo (null nếu message thường)
  final Map<String, dynamic>? schedulePlan;
  /// ID lịch trình (dùng để lưu vào Backend)
  final String? scheduleId;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.toolCalls = const [],
    this.schedulePlan,
    this.scheduleId,
  });
}

// ============================================================
// Screen: AI Assistant Chat
// ============================================================
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Chào bạn! Tôi là Kilo Coach. Tôi đang kết nối với Smart Watch của bạn và sẵn sàng tối ưu năng suất hôm nay. 🚀\n\nBạn có thể yêu cầu tôi "lên lịch làm việc cho ngày mai" để nhận lịch trình thông minh!',
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final spp = Provider.of<SppService>(context, listen: false);

    try {
      final data = await ApiClient.post('/api/v1/ai/coach/chat', {
        'user_prompt': text,
        'watch_connected': spp.isConnected,
      });

      final reply = data['reply'] ?? 'Đã nhận yêu cầu.';
      final rawToolCalls = data['tool_calls'] as List? ?? [];

      // Parse Phase 3 recommendation tracking IDs
      final recId = data['recommendation_id'] as String?;
      final tType = data['task_type'] as String?;
      if (recId != null) spp.currentRecommendationId = recId;
      if (tType != null) spp.currentTaskType = tType;

      // Parse schedule plan (nếu AI gọi generate_work_schedule)
      Map<String, dynamic>? schedulePlan;
      String? scheduleId;

      if (data['schedule_plan'] != null) {
        schedulePlan = Map<String, dynamic>.from(data['schedule_plan']);
        scheduleId = data['schedule_id'] as String?;
      } else {
        // Fallback: tìm trong tool_calls
        for (var tc in rawToolCalls) {
          if (tc['tool'] == 'generate_work_schedule') {
            schedulePlan = Map<String, dynamic>.from(tc['params'] ?? {});
            break;
          }
        }
      }

      List<String> executedTools = [];

      // Xử lý các tool call thông thường (trừ generate_work_schedule)
      final nonScheduleTools = rawToolCalls.where((tc) => tc['tool'] != 'generate_work_schedule').toList();

      if (nonScheduleTools.isNotEmpty && !spp.isConnected) {
        await spp.connectToEsp32();
      }

      for (var tc in nonScheduleTools) {
        final tool = tc['tool'];
        final params = tc['params'] as Map<String, dynamic>? ?? {};

        if (tool == 'set_pomodoro_cycle') {
          final w = params['work_min'] ?? 25;
          final b = params['break_min'] ?? 5;
          await spp.sendPomodoroCycle(w, b);
          executedTools.add('SET_POMO ($w/$b min)');
        } else if (tool == 'sync_watch_alarm') {
          final time = params['time'] ?? '07:00';
          final label = params['label'] ?? 'Alarm';
          await spp.sendAlarm(time, label);
          executedTools.add('SET_ALARM ($time)');
        } else if (tool == 'push_watch_notification') {
          final title = params['title'] ?? 'AI Alert';
          final body = params['body'] ?? '';
          await spp.sendNotification(title, body);
          executedTools.add('SHOW_NOTIF ($title)');
        }
      }

      setState(() {
        _messages.add(ChatMessage(
          text: reply,
          isUser: false,
          toolCalls: executedTools,
          schedulePlan: schedulePlan,
          scheduleId: scheduleId,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Không thể kết nối Backend AI: $e', isUser: false));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spp = Provider.of<SppService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1E),
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Coach & Digital Twin',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(spp.isConnected ? '🟢 Smart Watch kết nối' : '🔴 Chưa kết nối',
              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF9E9EC2))),
          ]),
        ]),
        actions: [
          IconButton(
            icon: Icon(spp.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: spp.isConnected ? const Color(0xFF00E5FF) : const Color(0xFFFF5252)),
            onPressed: () => spp.connectToEsp32(),
          )
        ],
      ),
      body: Column(
        children: [
          // Digital Twin Dashboard (compact)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: DigitalTwinDashboard(),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (ctx, idx) {
                final msg = _messages[idx];
                return _buildMessageBubble(msg, spp);
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(children: [
                const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF))),
                const SizedBox(width: 10),
                Text('AI đang phân tích...', style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFF9E9EC2))),
              ]),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A1E),
              border: Border(top: BorderSide(color: Color(0xFF1E1E3A))),
            ),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12122A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF2A2A5A)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Nhập yêu cầu cho AI Coach...',
                      hintStyle: GoogleFonts.outfit(color: const Color(0xFF5A5A8A), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Widget: Chat Message Bubble
  // ============================================================
  Widget _buildMessageBubble(ChatMessage msg, SppService spp) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF536DFE), Color(0xFF7C4DFF)]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(msg.text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, height: 1.4)),
        ),
      );
    }

    // AI response
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nội dung văn bản
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF12122A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: const Color(0xFF1E1E3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.text, style: GoogleFonts.outfit(
                    color: const Color(0xFFE0E0F0), fontSize: 14, height: 1.5)),
                  if (msg.toolCalls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: msg.toolCalls.map((tc) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.watch_rounded, color: Color(0xFF00E5FF), size: 12),
                          const SizedBox(width: 4),
                          Text(tc, style: GoogleFonts.outfit(
                            fontSize: 10, color: const Color(0xFF00E5FF), fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ).toList()),
                  ],
                ],
              ),
            ),

            // Schedule Card (nếu có)
            if (msg.schedulePlan != null) ...[
              const SizedBox(height: 10),
              _ScheduleCard(
                plan: msg.schedulePlan!,
                scheduleId: msg.scheduleId,
                spp: spp,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Widget: Schedule Card — Lịch trình AI thông minh
// ============================================================
class _ScheduleCard extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String? scheduleId;
  final SppService spp;

  const _ScheduleCard({required this.plan, this.scheduleId, required this.spp});

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _isSaving = false;
  bool _saved = false;
  bool _isSyncing = false;
  bool _synced = false;

  Map<String, dynamic> get plan => widget.plan;

  // Màu sắc theo Grade
  Color get _gradeColor {
    final letter = plan['grade_letter'] ?? 'B';
    if (letter == 'A+' || letter == 'A') return const Color(0xFF00E676);
    if (letter == 'B') return const Color(0xFFFFB300);
    return const Color(0xFFFF5252);
  }

  // Icon theo task_type
  String _taskIcon(String type) {
    switch (type) {
      case 'coding': return '💻';
      case 'reading': return '📖';
      case 'meeting': return '🤝';
      case 'exercise': return '🏃';
      case 'break': return '☕';
      case 'lunch': return '🍽️';
      default: return '📋';
    }
  }

  // ── Sync tất cả alarm lên Smart Watch ──
  Future<void> _syncAlarms() async {
    setState(() { _isSyncing = true; });
    try {
      final blocks = plan['schedule_blocks'] as List? ?? [];
      if (!widget.spp.isConnected) {
        await widget.spp.connectToEsp32();
      }
      for (var block in blocks) {
        if (block['is_break'] == true) continue; // Bỏ qua block nghỉ
        final time = block['start_time'] ?? '';
        final activity = block['activity'] ?? 'Phiên làm việc';
        await widget.spp.sendAlarm(time, activity);
        await Future.delayed(const Duration(milliseconds: 300)); // Chờ BLE xử lý
      }
      setState(() { _synced = true; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Đã đồng bộ ${blocks.where((b) => b['is_break'] != true).length} báo thức lên Smart Watch!'),
          backgroundColor: const Color(0xFF00E676),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Lỗi đồng bộ: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() { _isSyncing = false; });
    }
  }

  // ── Bắt đầu phiên Pomodoro đầu tiên ──
  Future<void> _startFirstSession() async {
    final blocks = plan['schedule_blocks'] as List? ?? [];
    final firstWork = blocks.firstWhere(
      (b) => b['is_break'] != true,
      orElse: () => {'work_min': 25, 'break_min': 5, 'activity': 'Phiên làm việc'},
    );
    final workMin = firstWork['work_min'] ?? 25;
    final breakMin = firstWork['break_min'] ?? 5;
    final activity = firstWork['activity'] ?? 'Phiên làm việc';

    if (!widget.spp.isConnected) {
      await widget.spp.connectToEsp32();
    }
    await widget.spp.sendPomodoroCycle(workMin, breakMin);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🚀 Đã gửi: $activity ($workMin phút làm / $breakMin phút nghỉ)'),
        backgroundColor: const Color(0xFF7C4DFF),
      ));
    }
  }

  // ── Lưu lịch trình vào Backend ──
  Future<void> _saveSchedule() async {
    setState(() { _isSaving = true; });
    try {
      await ApiClient.post('/api/v1/ai/schedule/save', {
        'schedule_id': widget.scheduleId,
        'target_date': plan['target_date'] ?? '',
        'grade_score': plan['grade_score'] ?? 0,
        'grade_letter': plan['grade_letter'] ?? 'B',
        'grade_rationale': plan['grade_rationale'] ?? '',
        'schedule_blocks': plan['schedule_blocks'] ?? [],
        'total_work_minutes': plan['total_work_minutes'] ?? 0,
        'total_break_minutes': plan['total_break_minutes'] ?? 0,
        'burnout_safety_advice': plan['burnout_safety_advice'] ?? '',
      });
      setState(() { _saved = true; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('💾 Đã lưu lịch trình thành công!'),
          backgroundColor: Color(0xFF00E676),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Lỗi lưu: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = plan['schedule_blocks'] as List? ?? [];
    final gradeScore = (plan['grade_score'] ?? 0).toDouble();
    final gradeLetter = plan['grade_letter'] ?? 'B';
    final gradeRationale = plan['grade_rationale'] ?? '';
    final totalWork = plan['total_work_minutes'] ?? 0;
    final totalBreak = plan['total_break_minutes'] ?? 0;
    final burnoutAdvice = plan['burnout_safety_advice'] ?? '';
    final targetDate = plan['target_date'] ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1B3E),
            const Color(0xFF0A0A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gradeColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: _gradeColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Grade Badge ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_gradeColor.withOpacity(0.15), Colors.transparent],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Grade Badge
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_gradeColor, _gradeColor.withOpacity(0.6)],
                    ),
                    boxShadow: [
                      BoxShadow(color: _gradeColor.withOpacity(0.4), blurRadius: 12),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(gradeLetter, style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text('${gradeScore.round()}', style: GoogleFonts.outfit(
                        fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📅 Lịch Trình Thông Minh', style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (targetDate.isNotEmpty)
                      Text('Ngày: $targetDate', style: GoogleFonts.outfit(
                        fontSize: 11, color: const Color(0xFF9E9EC2))),
                    const SizedBox(height: 4),
                    Text(gradeRationale, style: GoogleFonts.outfit(
                      fontSize: 11, color: const Color(0xFFB0BEC5), height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                )),
              ],
            ),
          ),

          // ── Stats Row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatChip(icon: Icons.work_rounded, label: 'Làm việc',
                  value: '${totalWork} phút', color: const Color(0xFF00E5FF)),
                const SizedBox(width: 10),
                _StatChip(icon: Icons.coffee_rounded, label: 'Nghỉ ngơi',
                  value: '${totalBreak} phút', color: const Color(0xFF7C4DFF)),
                const SizedBox(width: 10),
                _StatChip(icon: Icons.format_list_numbered_rounded, label: 'Phiên',
                  value: '${blocks.where((b) => b['is_break'] != true).length}',
                  color: const Color(0xFFFFB300)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Timeline ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              for (int i = 0; i < blocks.length; i++)
                _TimelineBlock(
                  block: Map<String, dynamic>.from(blocks[i]),
                  isLast: i == blocks.length - 1,
                  icon: _taskIcon(blocks[i]['task_type'] ?? 'general'),
                  accentColor: blocks[i]['is_break'] == true
                    ? const Color(0xFF7C4DFF)
                    : const Color(0xFF00E5FF),
                ),
            ]),
          ),

          // ── Burnout Advice ──
          if (burnoutAdvice.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.health_and_safety_rounded, color: Color(0xFFFF5252), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(burnoutAdvice, style: GoogleFonts.outfit(
                      fontSize: 11, color: const Color(0xFFFFAB91), height: 1.4))),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Action Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              // Row 1: Sync Alarms + Start 1st Session
              Row(children: [
                Expanded(child: _ActionButton(
                  icon: _synced ? Icons.check_circle_rounded : Icons.watch_rounded,
                  label: _synced ? 'Đã đồng bộ' : 'Sync Đồng Hồ',
                  color: const Color(0xFF00E5FF),
                  isLoading: _isSyncing,
                  onPressed: _synced ? null : _syncAlarms,
                )),
                const SizedBox(width: 10),
                Expanded(child: _ActionButton(
                  icon: Icons.play_circle_filled_rounded,
                  label: 'Bắt đầu ngay',
                  color: const Color(0xFF00E676),
                  onPressed: _startFirstSession,
                )),
              ]),
              const SizedBox(height: 8),
              // Row 2: Save Schedule
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  icon: _saved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                  label: _saved ? 'Đã lưu lịch trình ✓' : 'Lưu lịch trình',
                  color: const Color(0xFF7C4DFF),
                  isLoading: _isSaving,
                  onPressed: _saved ? null : _saveSchedule,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Widget: Stat Chip (hiển thị thống kê nhỏ)
// ============================================================
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: GoogleFonts.outfit(
          fontSize: 9, color: const Color(0xFF9E9EC2))),
      ]),
    ),
  );
}

// ============================================================
// Widget: Timeline Block (mỗi khung giờ)
// ============================================================
class _TimelineBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  final bool isLast;
  final String icon;
  final Color accentColor;

  const _TimelineBlock({
    required this.block, required this.isLast,
    required this.icon, required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = block['start_time'] ?? '';
    final endTime = block['end_time'] ?? '';
    final activity = block['activity'] ?? '';
    final taskType = block['task_type'] ?? 'general';
    final isBreak = block['is_break'] == true;
    final workMin = block['work_min'];
    final breakMin = block['break_min'];
    final focusPred = block['focus_prediction'];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column (dot + line)
          SizedBox(
            width: 28,
            child: Column(children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isBreak ? const Color(0xFF2A2A5A) : accentColor,
                  border: Border.all(color: accentColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(
                  width: 2,
                  color: const Color(0xFF2A2A5A),
                )),
            ]),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBreak
                  ? const Color(0xFF1A1A3E).withOpacity(0.5)
                  : const Color(0xFF0D1B3E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isBreak
                    ? const Color(0xFF2A2A5A)
                    : accentColor.withOpacity(0.25),
                ),
              ),
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$startTime — $endTime', style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isBreak ? const Color(0xFF9E9EC2) : Colors.white)),
                    const SizedBox(height: 2),
                    Text(activity, style: GoogleFonts.outfit(
                      fontSize: 11, color: const Color(0xFFB0BEC5), height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (workMin != null && !isBreak) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        _MiniTag('$workMin/$breakMin phút', const Color(0xFF00E5FF)),
                        if (focusPred != null) ...[
                          const SizedBox(width: 6),
                          _MiniTag('Focus ${focusPred.toStringAsFixed(0)}%',
                            (focusPred ?? 0) >= 70 ? const Color(0xFF00E676) : const Color(0xFFFFB300)),
                        ],
                      ]),
                    ],
                  ],
                )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Widget: Mini Tag (nhãn nhỏ trong timeline)
// ============================================================
class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniTag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(text, style: GoogleFonts.outfit(
      fontSize: 9, fontWeight: FontWeight.w600, color: color)),
  );
}

// ============================================================
// Widget: Action Button (nút hành động)
// ============================================================
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.icon, required this.label, required this.color,
    this.onPressed, this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: onPressed == null
            ? color.withOpacity(0.05)
            : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onPressed == null
              ? color.withOpacity(0.15)
              : color.withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color))
            else
              Icon(icon, color: onPressed == null ? color.withOpacity(0.5) : color, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: onPressed == null ? color.withOpacity(0.5) : color)),
          ],
        ),
      ),
    ),
  );
}
