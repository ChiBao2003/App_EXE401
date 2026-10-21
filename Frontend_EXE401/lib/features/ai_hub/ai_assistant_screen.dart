import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/bluetooth/spp_service.dart';
import '../../core/theme/app_colors.dart';
import 'digital_twin_dashboard.dart';

// ─── Model: ChatMessage ─────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> toolCalls;
  final Map<String, dynamic>? schedulePlan;
  final String? scheduleId;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.toolCalls = const [],
    this.schedulePlan,
    this.scheduleId,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─── Screen 5: Live AI Coach & Scheduler (Stitch ID: 6ab40d16445745d5908981e178da03de) ───
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
      text:
          'Chào bạn! Mình nhận thấy chỉ số biến thiên nhịp tim (HRV 78ms) của bạn đang đạt mức tối ưu cho chu kỳ sóng não Beta. Đây là thời điểm vàng để khởi động phiên Deep Work! 🚀\n\nBạn có thể yêu cầu tôi "lên lịch làm việc cho buổi chiều" để nhận lịch trình thông minh!',
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    'Lên lịch ngày mai',
    'Kiểm tra mức độ kiệt sức',
    'Đổi nhạc tập trung 40Hz',
    'Chế độ TFT LCD Minimalist',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

  Future<void> _sendMessage([String? textToSend]) async {
    final text = (textToSend ?? _controller.text).trim();
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

      // Parse recommendation tracking IDs
      final recId = data['recommendation_id'] as String?;
      final tType = data['task_type'] as String?;
      if (recId != null) spp.currentRecommendationId = recId;
      if (tType != null) spp.currentTaskType = tType;

      // Parse schedule plan
      Map<String, dynamic>? schedulePlan;
      String? scheduleId;

      if (data['schedule_plan'] != null) {
        schedulePlan = Map<String, dynamic>.from(data['schedule_plan']);
        scheduleId = data['schedule_id'] as String?;
      } else {
        for (var tc in rawToolCalls) {
          if (tc['tool'] == 'generate_work_schedule') {
            schedulePlan = Map<String, dynamic>.from(tc['params'] ?? {});
            break;
          }
        }
      }

      List<String> executedTools = [];
      final nonScheduleTools = rawToolCalls
          .where((tc) => tc['tool'] != 'generate_work_schedule')
          .toList();

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

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: reply,
              isUser: false,
              toolCalls: executedTools,
              schedulePlan: schedulePlan,
              scheduleId: scheduleId,
            ),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Không thể kết nối Backend AI: $e',
              isUser: false,
            ),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDigitalTwinSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.stitchSurfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      color: AppColors.stitchPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Digital Twin Radar",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stitchOnSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.stitchOutline,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const DigitalTwinDashboard(),
            const SizedBox(height: 16),
          ],
        ),
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
        child: Column(
          children: [
            _buildTopHeader(context, isConnected),
            _buildStatusSubheader(),
            _buildToolInvocationsStrip(),

            // Chat Messages Stream
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _messages.length,
                itemBuilder: (ctx, idx) {
                  final msg = _messages[idx];
                  return _buildMessageBubble(msg, spp);
                },
              ),
            ),

            if (_isLoading) _buildLoadingBar(),

            _buildBottomPanel(),
          ],
        ),
      ),
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
          Expanded(
            child: Row(
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
                Expanded(
                  child: Column(
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
                        "Live AI Coach",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  // ─── Component: Status & Model Subheader ──────────────────────
  Widget _buildStatusSubheader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.stitchPrimaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.stitchTertiary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.stitchSurfaceContainer,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              "Synapse Coach",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.stitchSecondaryContainer,
                            size: 15,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.stitchSurfaceHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Gemini Pro v2.5",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: AppColors.stitchSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Độ trễ: 18ms",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.stitchOnSurfaceVariant,
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
          GestureDetector(
            onTap: _openDigitalTwinSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    color: AppColors.stitchPrimary,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Digital Twin",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.stitchOnSurface,
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

  // ─── Component: Live Autonomous Tool Invocations Strip ────────
  Widget _buildToolInvocationsStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync_rounded,
                    color: AppColors.stitchTertiary,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "Calling: analyze_bio_rhythm()",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.stitchTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.stitchSecondaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "Syncing: ble_esp32_pipeline",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
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

  // ─── Component: Message Bubble ────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg, SppService spp) {
    final timeStr = DateFormat('HH:mm').format(msg.timestamp);

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "$timeStr • Gửi từ ứng dụng",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  color: AppColors.stitchOutline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // AI message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2, right: 8),
              decoration: const BoxDecoration(
                color: AppColors.stitchPrimaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
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
                        Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            color: AppColors.stitchOnSurface,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        if (msg.toolCalls.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: msg.toolCalls.map((tc) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.stitchSecondaryContainer
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.stitchSecondaryContainer
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.watch_rounded,
                                      color: AppColors.stitchSecondaryContainer,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      tc,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            AppColors.stitchSecondaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "$timeStr • Đã đồng bộ cảm biến quang học TFT LCD",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: AppColors.stitchOutline,
                    ),
                  ),

                  // Embedded Schedule Proposal Card
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
          ],
        ),
      ),
    );
  }

  // ─── Component: Loading Bar ───────────────────────────────────
  Widget _buildLoadingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.stitchPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "Synapse Coach đang suy luận & tổng hợp lịch trình...",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.stitchOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Component: Bottom Panel (Carousel & Input) ───────────────
  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLowest,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Quick Prompts Carousel
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _quickPrompts.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: GestureDetector(
                    onTap: () => _sendMessage(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Text(
                        p,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Input Bar Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.mic_none_rounded,
                    color: AppColors.stitchOnSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Micro AI Voice đã sẵn sàng!"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    style: GoogleFonts.inter(
                      color: AppColors.stitchOnSurface,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: "Nhập yêu cầu hoặc câu hỏi cho AI Coach...",
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.stitchOutline,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _sendMessage(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.stitchPrimaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
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
}

// ─── Component: Interactive Schedule Card ───────────────────────
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

  Future<void> _syncToWatch() async {
    setState(() => _isSyncing = true);
    try {
      final blocks = plan['schedule_blocks'] as List? ?? [];
      if (!widget.spp.isConnected) {
        await widget.spp.connectToEsp32();
      }

      for (var block in blocks) {
        if (block['is_break'] == true) continue;
        final time = block['start_time'] ?? '';
        final activity = block['activity'] ?? 'Phiên làm việc';
        await widget.spp.sendAlarm(time, activity);
        await Future.delayed(const Duration(milliseconds: 250));
      }

      setState(() => _synced = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã phát sóng BLE: Cập nhật ${blocks.where((b) => b['is_break'] != true).length} khối lịch vào ESP32 TFT LCD thành công!',
            ),
            backgroundColor: AppColors.stitchTertiaryContainer,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _saveToCalendar() async {
    setState(() => _isSaving = true);
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

      setState(() => _saved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã đồng bộ vào Lịch tuần & Synapse Matrix thành công!',
            ),
            backgroundColor: AppColors.stitchTertiaryContainer,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu lịch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = plan['schedule_blocks'] as List? ?? [];
    final totalWork = plan['total_work_minutes'] ?? 165;
    final workHours = totalWork ~/ 60;
    final workMins = totalWork % 60;
    final targetDate = plan['target_date'] ?? 'Hôm nay';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    color: AppColors.stitchPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Đề xuất Lịch trình ($targetDate)",
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.stitchTertiaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "AI OPTIMIZED",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.stitchTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Schedule Timeline Items
          if (blocks.isNotEmpty)
            ...blocks.map((b) => _buildTimelineTile(b))
          else ...[
            _buildTimelineTile({
              'start_time': '14:00',
              'end_time': '15:15',
              'activity': 'Lập trình Firmware BLE ESP32',
              'duration': '75 phút',
              'tag': 'TẬP TRUNG CAO',
              'is_break': false,
            }),
            _buildTimelineTile({
              'start_time': '15:15',
              'end_time': '15:30',
              'activity': 'Đi bộ thư giãn & Hồi phục năng lượng',
              'duration': '15 phút',
              'tag': 'NGHỈ NGƠI',
              'is_break': true,
            }),
            _buildTimelineTile({
              'start_time': '15:30',
              'end_time': '17:00',
              'activity': 'Review kiến trúc hệ thống & Test TFT LCD',
              'duration': '90 phút',
              'tag': 'SÁNG TẠO',
              'is_break': false,
            }),
          ],
          const SizedBox(height: 10),

          // Quick Metrics Cluster
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "THỜI GIAN TẬP TRUNG",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOutline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workHours > 0
                            ? "${workHours}h ${workMins}m"
                            : "${workMins}m",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchSecondaryContainer,
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
                        "NGUY CƠ KIỆT SỨC",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOutline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            "18%",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "(Rất thấp)",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.stitchTertiary,
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
          const SizedBox(height: 10),

          // ESP32 TFT LCD Mirror status tile
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.stitchSurfaceLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: AppColors.stitchOnSurface,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ESP32 TFT LCD Mirror",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.stitchOnSurface,
                          ),
                        ),
                        Text(
                          "Chuẩn bị payload 256 bytes qua BLE",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.stitchOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSecondaryContainer.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _synced ? "ĐÃ ĐỒNG BỘ" : "SẴN SÀNG",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          GestureDetector(
            onTap: _isSyncing ? null : _syncToWatch,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSyncing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.send_to_mobile_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _synced
                        ? "Đã gửi xuống TFT LCD ✓"
                        : "Gửi xuống màn hình TFT LCD",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: _isSaving ? null : _saveToCalendar,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.stitchSecondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSaving)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  else
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _saved ? "Đã lưu vào Lịch tuần ✓" : "Đồng bộ vào Lịch tuần",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
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

  Widget _buildTimelineTile(Map<dynamic, dynamic> b) {
    final startTime = b['start_time'] ?? '';
    final endTime = b['end_time'] ?? '';
    final activity = b['activity'] ?? '';
    final isBreak = b['is_break'] == true;
    final tag = b['tag'] ?? (isBreak ? 'NGHỈ NGƠI' : 'TẬP TRUNG CAO');
    final duration =
        b['duration'] ??
        (b['work_min'] != null
            ? '${b['work_min']} phút'
            : (b['break_min'] != null ? '${b['break_min']} phút' : ''));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$startTime — $endTime",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isBreak
                      ? AppColors.stitchTertiary
                      : AppColors.stitchSecondaryContainer,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isBreak
                      ? AppColors.stitchTertiaryContainer.withValues(alpha: 0.3)
                      : AppColors.stitchPrimaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: isBreak
                        ? AppColors.stitchTertiary
                        : AppColors.stitchPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  activity,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.stitchOnSurface,
                  ),
                ),
              ),
              if (duration.toString().isNotEmpty)
                Text(
                  duration.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
