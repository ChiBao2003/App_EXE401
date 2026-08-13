import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';

class InterfaceItem {
  final String name;
  final bool isDefault;
  bool isEnabled;
  double displayMinutes;

  InterfaceItem({
    required this.name,
    required this.isDefault,
    this.isEnabled = true,
    this.displayMinutes = 5,
  });
}

class InterfacesScreen extends StatefulWidget {
  const InterfacesScreen({super.key});

  @override
  State<InterfacesScreen> createState() => _InterfacesScreenState();
}

class _InterfacesScreenState extends State<InterfacesScreen> {
  final List<InterfaceItem> _interfaces = [
    InterfaceItem(name: 'Giao diện mặc định 1', isDefault: true, isEnabled: true, displayMinutes: 5),
    InterfaceItem(name: 'Giao diện mặc định 2', isDefault: true, isEnabled: true, displayMinutes: 5),
    InterfaceItem(name: 'Giao diện mặc định 3', isDefault: true, isEnabled: true, displayMinutes: 5),
    InterfaceItem(name: 'Giao diện mặc định 4', isDefault: true, isEnabled: true, displayMinutes: 5),
    InterfaceItem(name: 'Giao diện mặc định 5', isDefault: true, isEnabled: true, displayMinutes: 5),
    InterfaceItem(name: 'Màn hình tự thiết kế\nSlot2', isDefault: false, isEnabled: false, displayMinutes: 0),
    InterfaceItem(name: 'Màn hình tự thiết kế\nSlot3', isDefault: false, isEnabled: false, displayMinutes: 0),
    InterfaceItem(name: 'Màn hình tự thiết kế\nSlot4', isDefault: false, isEnabled: false, displayMinutes: 0),
    InterfaceItem(name: 'Màn hình tự thiết kế\nSlot5', isDefault: false, isEnabled: false, displayMinutes: 0),
  ];

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
        title: Text('Các giao diện', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => showSuccessSnackbar(context, 'Đang tải giao diện mẫu...'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Đồng hồ sẽ tự động chuyển đổi qua lại giữa các giao diện, có 5 giao diện mặc định và 5 giao diện do bạn nạp vào',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: _interfaces.length,
              itemBuilder: (context, index) {
                final item = _interfaces[index];
                return _InterfaceCard(
                  item: item,
                  onEnabledChanged: (v) => setState(() => item.isEnabled = v),
                  onMinutesChanged: (v) => setState(() => item.displayMinutes = v),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: EinkButton(
          label: 'Lưu cài đặt',
          icon: Icons.save_rounded,
          backgroundColor: AppColors.btnOrange,
          onPressed: () => showSuccessSnackbar(context, 'Đã lưu cài đặt giao diện!'),
        ),
      ),
    );
  }
}

class _InterfaceCard extends StatelessWidget {
  final InterfaceItem item;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<double> onMinutesChanged;

  const _InterfaceCard({
    required this.item,
    required this.onEnabledChanged,
    required this.onMinutesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDefault = item.isDefault;
    final bgColor = isDefault ? AppColors.cardBlue : AppColors.cardGrayLight;
    final iconBg = isDefault ? AppColors.iconBgBlue : AppColors.iconBgGray;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Checkbox(
                value: item.isEnabled,
                onChanged: (v) => onEnabledChanged(v ?? false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                side: BorderSide(
                  color: isDefault ? AppColors.sliderActive : AppColors.iconBgGray,
                  width: 2,
                ),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isDefault ? AppColors.sliderActive : AppColors.iconBgGray;
                  }
                  return Colors.transparent;
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Thời gian hiển thị: ${item.displayMinutes.toInt()} phút',
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDefault ? AppColors.sliderActive : AppColors.iconBgGray,
              thumbColor: isDefault ? AppColors.sliderActive : AppColors.iconBgGray,
              inactiveTrackColor: Colors.white,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: item.displayMinutes,
              min: 0,
              max: 30,
              divisions: 30,
              onChanged: onMinutesChanged,
            ),
          ),
        ],
      ),
    );
  }
}
