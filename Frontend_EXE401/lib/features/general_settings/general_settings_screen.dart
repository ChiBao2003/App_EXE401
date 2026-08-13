import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  // Hiệu chỉnh thời gian
  String _adjustMode = 'Không hiệu chỉnh';
  final _adjustHourCtrl = TextEditingController(text: '0');

  // Tiết kiệm pin
  TimeOfDay _sleepStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _sleepEnd = const TimeOfDay(hour: 0, minute: 0);

  // Báo thức
  TimeOfDay _alarm = const TimeOfDay(hour: 0, minute: 0);

  // Đếm ngược
  final _countDownCtrl = TextEditingController(text: '0');
  final _countUpCtrl = TextEditingController(text: '0');

  final List<String> _adjustModes = ['Không hiệu chỉnh', 'Hiệu chỉnh nhanh', 'Hiệu chỉnh chậm'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _adjustHourCtrl.dispose();
    _countDownCtrl.dispose();
    _countUpCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(TimeOfDay initial, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  String get _dayName {
    const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return days[_now.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Cài đặt chung', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          children: [
            // === Set Time Card ===
            EinkCard(
              backgroundColor: AppColors.cardYellow,
              title: 'Set time',
              icon: const Icon(Icons.access_time_rounded, size: 22),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF80DEEA), Color(0xFFCE93D8), Color(0xFFF48FB1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'THỜI GIAN HIỆN TẠI',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm:ss').format(_now),
                        style: GoogleFonts.nunito(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '$_dayName, ${DateFormat('dd/MM/yyyy').format(_now)}',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                EinkButton(
                  label: 'Lưu thời gian',
                  icon: Icons.sync_rounded,
                  backgroundColor: AppColors.btnOrange,
                  onPressed: () async {
                    final ok = await ble.syncTime();
                    if (context.mounted) {
                      ok
                          ? showSuccessSnackbar(context, 'Đã đồng bộ thời gian!')
                          : showErrorSnackbar(context, 'Chưa kết nối thiết bị!');
                    }
                  },
                ),
              ],
            ),

            // === Hiệu chỉnh thời gian Card ===
            EinkCard(
              backgroundColor: AppColors.cardBlue,
              title: 'Hiệu chỉnh thời gian',
              icon: const Icon(Icons.tune_rounded, size: 22),
              subtitle: 'Chỉ áp dụng cho phiên bản firmware 1.0.2 trở lên',
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _adjustMode,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFFFA000)),
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      onChanged: (v) => setState(() => _adjustMode = v!),
                      items: _adjustModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Sau mỗi', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                EinkTextField(
                  controller: _adjustHourCtrl,
                  suffixText: 'giờ',
                ),
                const SizedBox(height: 12),
                EinkButton(
                  label: 'Lưu thiết lập',
                  icon: Icons.save_rounded,
                  backgroundColor: AppColors.btnBlue,
                  onPressed: () => showSuccessSnackbar(context, 'Đã lưu thiết lập hiệu chỉnh!'),
                ),
              ],
            ),

            // === Tiết kiệm pin Card ===
            EinkCard(
              backgroundColor: AppColors.cardGreen,
              title: 'Tiết kiệm pin',
              icon: const Icon(Icons.battery_saver_rounded, size: 22),
              subtitle: 'Màn hình sẽ không cập nhật giờ trong khi ngủ, cài trùng giờ sẽ không ngủ',
              children: [
                EinkTimeRow(
                  icon: Icons.bedtime_rounded,
                  label: 'Bắt đầu ngủ',
                  time: _formatTime(_sleepStart),
                  onTap: () => _pickTime(_sleepStart, (t) => setState(() => _sleepStart = t)),
                ),
                EinkTimeRow(
                  icon: Icons.alarm_rounded,
                  label: 'Kết thúc ngủ',
                  time: _formatTime(_sleepEnd),
                  onTap: () => _pickTime(_sleepEnd, (t) => setState(() => _sleepEnd = t)),
                ),
                const SizedBox(height: 4),
                EinkButton(
                  label: 'Lưu chế độ ngủ',
                  icon: Icons.nightlight_round,
                  backgroundColor: AppColors.btnTeal,
                  onPressed: () => showSuccessSnackbar(context, 'Đã lưu chế độ ngủ!'),
                ),
              ],
            ),

            // === Báo thức Card ===
            EinkCard(
              backgroundColor: AppColors.cardLime,
              title: 'Báo thức',
              icon: const Icon(Icons.alarm_rounded, size: 22),
              subtitle: 'Cần gắn loa bíp vào TX - GND để báo thức',
              children: [
                EinkTimeRow(
                  icon: Icons.alarm_rounded,
                  label: 'Báo thức',
                  time: _formatTime(_alarm),
                  onTap: () => _pickTime(_alarm, (t) => setState(() => _alarm = t)),
                ),
                const SizedBox(height: 12),
                EinkButton(
                  label: 'Lưu báo thức',
                  icon: Icons.notifications_active_rounded,
                  backgroundColor: AppColors.btnLavender,
                  onPressed: () => showSuccessSnackbar(context, 'Đã lưu báo thức!'),
                ),
                const SizedBox(height: 14),
                // Ảnh hướng dẫn phần cứng
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 120,
                    color: Colors.black12,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            color: const Color(0xFF2D4A3E),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.speaker_rounded, color: Colors.white, size: 36),
                                  SizedBox(height: 6),
                                  Text('GND TX', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(
                            color: const Color(0xFF1A3A2A),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.memory_rounded, color: Colors.white, size: 36),
                                  SizedBox(height: 6),
                                  Text('Kết nối mạch', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // === Dữ liệu đếm ngược Card ===
            EinkCard(
              backgroundColor: AppColors.cardOrangeYellow,
              title: 'Dữ liệu đếm ngược',
              icon: const Icon(Icons.tune_rounded, size: 22),
              subtitle: 'Set lại data đếm ngược',
              children: [
                Text('Đếm lùi ngày', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                EinkTextField(controller: _countDownCtrl, suffixText: 'ngày'),
                const SizedBox(height: 10),
                Text('Đếm tiến ngày', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                EinkTextField(controller: _countUpCtrl, suffixText: 'ngày'),
                const SizedBox(height: 12),
                EinkButton(
                  label: 'Lưu thiết lập',
                  icon: Icons.save_rounded,
                  backgroundColor: AppColors.btnGreen,
                  onPressed: () => showSuccessSnackbar(context, 'Đã lưu dữ liệu đếm ngược!'),
                ),
              ],
            ),

            // === Khôi phục cài đặt gốc Card ===
            EinkCard(
              backgroundColor: const Color(0xFFFFF9E6),
              title: 'Khôi phục cài đặt gốc',
              icon: const Icon(Icons.tune_rounded, size: 22),
              subtitle: 'Xóa hết dữ liệu cài đặt và màn hình tùy chỉnh, trở về trạng thái xuất xưởng. Dùng khi có sự cố.',
              children: [
                EinkButton(
                  label: 'Khôi phục ngay',
                  icon: Icons.save_rounded,
                  backgroundColor: AppColors.btnRed,
                  onPressed: () => _showResetDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xác nhận khôi phục', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'Toàn bộ cài đặt và giao diện tùy chỉnh sẽ bị xóa. Bạn có chắc không?',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.btnRed),
            onPressed: () {
              Navigator.pop(ctx);
              showSuccessSnackbar(context, 'Đã gửi lệnh khôi phục!');
            },
            child: Text('Khôi phục', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
