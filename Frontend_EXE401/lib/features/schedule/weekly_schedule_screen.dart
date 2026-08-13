import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';

class DaySchedule {
  final String dayName;
  final String dayShort;
  final Color color;
  String note;
  bool isEnabled;
  int selectedSlot;
  TimeOfDay displayTime;

  DaySchedule({
    required this.dayName,
    required this.dayShort,
    required this.color,
    this.note = '',
    this.isEnabled = false,
    this.selectedSlot = 1,
    this.displayTime = const TimeOfDay(hour: 6, minute: 0),
  });
}

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  int? _expandedIndex;

  final List<DaySchedule> _days = [
    DaySchedule(dayName: 'Thứ Hai', dayShort: 'T2', color: const Color(0xFFFFD54F)),
    DaySchedule(dayName: 'Thứ Ba', dayShort: 'T3', color: const Color(0xFF80DEEA)),
    DaySchedule(dayName: 'Thứ Tư', dayShort: 'T4', color: const Color(0xFFA5D6A7)),
    DaySchedule(dayName: 'Thứ Năm', dayShort: 'T5', color: const Color(0xFFCE93D8)),
    DaySchedule(dayName: 'Thứ Sáu', dayShort: 'T6', color: const Color(0xFFFFAB91)),
    DaySchedule(dayName: 'Thứ Bảy', dayShort: 'T7', color: const Color(0xFF80CBC4)),
    DaySchedule(dayName: 'Chủ Nhật', dayShort: 'CN', color: const Color(0xFFF48FB1)),
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedulesFromBackend();
  }

  Future<void> _loadSchedulesFromBackend() async {
    String baseUrl = "http://127.0.0.1:8000";
    if (!kIsWeb && Platform.isAndroid) baseUrl = "http://10.0.2.2:8000";

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/schedules/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          for (var item in data) {
            // days_of_week chứa số (2=T2, 8=CN)
            List<dynamic> days = item['days_of_week'] ?? [];
            for (var d in days) {
              if (d >= 2 && d <= 8) {
                int index = d - 2; // T2 -> index 0
                _days[index].isEnabled = item['is_active'] ?? true;
                _days[index].note = item['title'] ?? '';
                
                String timeStr = item['time'] ?? '06:00';
                List<String> parts = timeStr.split(':');
                if (parts.length == 2) {
                  _days[index].displayTime = TimeOfDay(
                    hour: int.tryParse(parts[0]) ?? 6,
                    minute: int.tryParse(parts[1]) ?? 0,
                  );
                }
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Lỗi fetch lịch: $e");
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int get _todayWeekday => DateTime.now().weekday; // 1=Mon, 7=Sun

  bool _isSaving = false;

  Future<void> _saveSchedulesToBackend() async {
    setState(() => _isSaving = true);
    final activeDays = _days.where((d) => d.isEnabled && d.note.isNotEmpty).toList();
    
    String baseUrl = "http://127.0.0.1:8000";
    if (!kIsWeb && Platform.isAndroid) baseUrl = "http://10.0.2.2:8000";

    try {
      // Xóa lịch cũ trên backend nếu làm tính năng đồng bộ 2 chiều (bỏ qua bước này ở MVP)
      for (var day in activeDays) {
        await http.post(
          Uri.parse('$baseUrl/api/schedules/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "user_id": "DEFAULT_USER",
            "title": day.note,
            "time": _formatTime(day.displayTime),
            "days_of_week": [_days.indexOf(day) + 2], // 2 = Mon
            "is_active": true
          }),
        );
      }
      if (mounted) showSuccessSnackbar(context, 'Đã đồng bộ ${activeDays.length} nhắc nhở lên Database!');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Lỗi kết nối máy chủ!');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lịch nhắc nhở tuần',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // === Header info ===
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFCC02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Điền ghi chú cho từng ngày, khi đến sáng hôm đó đồng hồ sẽ hiển thị lên nhắc bạn!',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // === Day list ===
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _days.length,
              itemBuilder: (context, index) {
                final day = _days[index];
                final isToday = index + 1 == _todayWeekday;
                final isExpanded = _expandedIndex == index;
                return _DayCard(
                  day: day,
                  isToday: isToday,
                  isExpanded: isExpanded,
                  onTap: () => setState(() {
                    _expandedIndex = isExpanded ? null : index;
                  }),
                  onEnabledChanged: (v) => setState(() => day.isEnabled = v),
                  onNoteChanged: (v) => day.note = v,
                  onSlotChanged: (v) => setState(() => day.selectedSlot = v),
                  onTimePick: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: day.displayTime,
                    );
                    if (picked != null) setState(() => day.displayTime = picked);
                  },
                  formatTime: _formatTime,
                );
              },
            ),
          ),
        ],
      ),

      // === Bottom Save Button ===
      bottomNavigationBar: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: EinkButton(
          label: _isSaving ? 'Đang lưu...' : 'Lưu & Đồng bộ lên đồng hồ',
          icon: Icons.sync_rounded,
          backgroundColor: AppColors.btnOrange,
          onPressed: _isSaving
              ? () {}
              : () {
                  final active = _days.where((d) => d.isEnabled && d.note.isNotEmpty).length;
                  if (active == 0) {
                    showSuccessSnackbar(context, 'Chưa có ngày nào được bật và điền ghi chú!');
                    return;
                  }
                  _saveSchedulesToBackend();
                },
        ),
      ),
    );
  }
}

// =====================
// _DayCard Widget
// =====================
class _DayCard extends StatefulWidget {
  final DaySchedule day;
  final bool isToday;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<int> onSlotChanged;
  final VoidCallback onTimePick;
  final String Function(TimeOfDay) formatTime;

  const _DayCard({
    required this.day,
    required this.isToday,
    required this.isExpanded,
    required this.onTap,
    required this.onEnabledChanged,
    required this.onNoteChanged,
    required this.onSlotChanged,
    required this.onTimePick,
    required this.formatTime,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.day.note);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isExpanded ? day.color.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: widget.isToday
            ? Border.all(color: const Color(0xFFFF7043), width: 2)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // === Header row ===
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Day badge
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: day.color,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        day.dayShort,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Day name + preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              day.dayName,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (widget.isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7043),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Hôm nay',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          day.note.isEmpty
                              ? 'Chưa có lịch'
                              : day.note.length > 30
                                  ? '${day.note.substring(0, 30)}...'
                                  : day.note,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: day.note.isEmpty
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle
                  Switch(
                    value: day.isEnabled,
                    onChanged: widget.onEnabledChanged,
                    activeColor: const Color(0xFF43A047),
                  ),
                  Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // === Expanded content ===
          if (widget.isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Note field
                  Text(
                    'Ghi chú / kế hoạch hôm đó:',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    maxLength: 120,
                    onChanged: widget.onNoteChanged,
                    style: GoogleFonts.nunito(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Họp team lúc 9h, đi gym buổi chiều...',
                      hintStyle: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.black26,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: day.color, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: day.color, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFF7043), width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Slot selector
                  Text(
                    'Hiển thị tại slot:',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final slot = i + 1;
                      final selected = day.selectedSlot == slot;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onSlotChanged(slot),
                          child: Container(
                            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? day.color : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? Colors.black26 : Colors.black12,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Slot',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                                Text(
                                  '$slot',
                                  style: GoogleFonts.nunito(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Time picker
                  Text(
                    'Giờ bắt đầu hiển thị:',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: widget.onTimePick,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: day.color, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.alarm_rounded, color: day.color, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Hiển thị từ ${widget.formatTime(day.displayTime)}',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Đổi',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
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
}
