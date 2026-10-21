import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/bluetooth/spp_service.dart';
import '../../core/display/tft_layout.dart';

class InterfacesScreen extends StatefulWidget {
  const InterfacesScreen({super.key});
  @override
  State<InterfacesScreen> createState() => _InterfacesScreenState();
}

class _InterfacesScreenState extends State<InterfacesScreen> {
  bool _busy = false;
  int _color = 0x07ff;
  Future<void> _apply(Future<void> Function(SppService) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(context.read<SppService>());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<SppService>().isConnected) {
        _apply((s) => s.refreshDisplayState());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spp = context.watch<SppService>();
    final state = spp.displayState;
    const modes = [
      'Đồng hồ chính',
      'Pomodoro',
      'Đếm ngược',
      'Loa Bluetooth A2DP',
    ];
    const themes = ['Flip Clock', 'Analog Dial', 'Sunset Digital'];
    return Scaffold(
      appBar: AppBar(title: const Text('Điều khiển ESP32 TFT')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('ILI9341 · 320×240 · RGB565 · RTC DS3231'),
          Text(spp.isConnected ? 'Đã kết nối BLE' : 'Chưa kết nối ESP32'),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 24),
          const Text('Chế độ hoạt động'),
          for (var i = 0; i < modes.length; i++)
            ListTile(
              title: Text(modes[i]),
              selected: state?['mode'] == i,
              trailing: state?['mode'] == i ? const Icon(Icons.check) : null,
              onTap: !spp.isConnected || _busy
                  ? null
                  : () => _apply((s) => s.setMode(i)),
            ),
          const Divider(),
          const Text('Theme đồng hồ'),
          for (var i = 0; i < themes.length; i++)
            ListTile(
              title: Text(themes[i]),
              selected: state?['theme_id'] == i && state?['custom'] != true,
              onTap: !spp.isConnected || _busy
                  ? null
                  : () => _apply((s) async {
                      await s.setTheme(i, hexColor: rgb565Hex(_color));
                      await s.setMode(0);
                    }),
            ),
          const SizedBox(height: 16),
          const Text('Màu chủ đạo RGB565 (áp dụng khi chọn theme)'),
          Wrap(
            spacing: 8,
            children: [
              for (final color in tftPalette.entries)
                ChoiceChip(
                  label: Text(
                    '${color.key} 0x${color.value.toRadixString(16).padLeft(4, '0').toUpperCase()}',
                  ),
                  avatar: CircleAvatar(
                    backgroundColor: rgb565Color(color.value),
                  ),
                  selected: _color == color.value,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _color = color.value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            state == null
                ? 'Chưa đọc trạng thái NVS'
                : 'Custom Layout: ${state['custom'] == true ? 'đang dùng' : 'không hoạt động'} · ${state['layout_count'] ?? 0} phần tử trong NVS',
          ),
          TextButton(
            onPressed: _busy || !spp.isConnected
                ? null
                : () => _apply((s) => s.refreshDisplayState()),
            child: const Text('Đọc trạng thái từ đồng hồ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/design'),
            child: const Text('Mở Canvas Studio'),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/market'),
            child: const Text('Chợ giao diện'),
          ),
        ],
      ),
    );
  }
}
