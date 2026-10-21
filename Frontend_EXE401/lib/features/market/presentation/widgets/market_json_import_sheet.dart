import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/bluetooth/spp_service.dart';
import '../../../../core/display/tft_layout.dart';

class MarketJsonImportSheet extends StatefulWidget {
  const MarketJsonImportSheet({super.key});

  @override
  State<MarketJsonImportSheet> createState() => _MarketJsonImportSheetState();
}

class _MarketJsonImportSheetState extends State<MarketJsonImportSheet> {
  static const _fileChannel = MethodChannel('smarttime/json_document');
  final _controller = TextEditingController();
  Map<String, dynamic>? _design;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse(String source) {
    try {
      final design = validateTftDesign(jsonDecode(source));
      setState(() {
        _design = design;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _design = null;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final content = await _fileChannel.invokeMethod<String>('openJson');
      if (content == null || !mounted) return;
      if (!mounted) return;
      _controller.text = content;
      _parse(content);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không đọc được tệp JSON: $e');
    }
  }

  Future<void> _install() async {
    final design = _design;
    if (design == null || _busy) return;
    setState(() => _busy = true);
    try {
      final spp = context.read<SppService>();
      if (!spp.isConnected) throw StateError('Chưa kết nối ESP32 qua BLE');
      await spp.uploadTftLayout(
        tftTemplateItems(design),
        backgroundColor: design['background'] as int,
        backgroundBitmapHex: design['background_bitmap'] as String?,
      );
      if (mounted) setState(() => _error = 'ESP32 đã xác nhận nạp giao diện.');
    } catch (e) {
      if (mounted) setState(() => _error = 'Nạp thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLocal() async {
    final design = _design;
    if (design == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('personal_tft_designs') ?? [];
    saved.add(jsonEncode(design));
    await prefs.setStringList('personal_tft_designs', saved);
    if (mounted) setState(() => _error = 'Đã lưu vào bộ nhớ điện thoại.');
  }

  Future<void> _exportFile() async {
    final design = _design;
    if (design == null || _busy) return;
    setState(() => _busy = true);
    try {
      final saved = await _fileChannel.invokeMethod<String>('saveJson', {
        'name': 'smarttime_design.json',
        'content': jsonEncode(design),
      });
      if (mounted && saved != null) {
        setState(() => _error = 'Đã xuất tệp JSON vào vị trí đã chọn.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Không xuất được tệp JSON: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('personal_tft_designs') ?? [];
    if (!mounted) return;
    if (saved.isEmpty) {
      setState(() => _error = 'Chưa có mặt đồng hồ nào đã lưu.');
      return;
    }
    final index = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mặt đồng hồ đã lưu'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: saved.length,
            itemBuilder: (_, i) {
              final data = jsonDecode(saved[i]) as Map;
              return ListTile(
                title: Text(
                  (data['title'] ?? 'Mặt đồng hồ ${i + 1}').toString(),
                ),
                onTap: () => Navigator.pop(dialogContext, i),
              );
            },
          ),
        ),
      ),
    );
    if (index == null || !mounted) return;
    _controller.text = saved[index];
    _parse(saved[index]);
  }

  Future<void> _loadSample(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      if (!mounted) return;
      _controller.text = content;
      _parse(content);
      if (_design != null && context.read<SppService>().isConnected) {
        await _install();
      } else if (_design != null && mounted) {
        setState(() => _error = 'Đã mở mẫu. Kết nối ESP32 để nạp ngay.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Không thể nạp tệp mẫu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = _design;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nhập mặt đồng hồ JSON',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Chọn tệp .json'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSaved,
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: const Text('Mặt đồng hồ đã lưu'),
                  ),
                  for (final sample in const [
                    ('Pikachu', 'pokemon_clock.json'),
                    ('Naruto', 'naruto_clock.json'),
                    ('Gojo', 'gojo_clock.json'),
                    ('Hàn Lập', 'han_li_clock.json'),
                    ('Vương Lâm', 'wang_lin_clock.json'),
                  ])
                    ActionChip(
                      label: Text('Nạp ${sample.$1}'),
                      onPressed: () => _loadSample('assets/samples/${sample.$2}'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                onChanged: _parse,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Hoặc dán mã JSON',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              if (design != null) ...[
                const SizedBox(height: 12),
                Text(design['title'] as String),
                SizedBox(height: 210, child: TftPreview(design: design)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _install,
                      child: Text(_busy ? 'Đang nạp…' : 'Nạp ngay vào ESP32'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        final route = Navigator.of(context);
                        route.pop();
                        route.pushNamed(
                          '/design',
                          arguments: {'template': design},
                        );
                      },
                      child: const Text('Mở trong Studio'),
                    ),
                    OutlinedButton(
                      onPressed: _saveLocal,
                      child: const Text('Lưu vào máy'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _exportFile,
                      child: const Text('Xuất tệp .json'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: jsonEncode(design)),
                        );
                        if (mounted) {
                          setState(() => _error = 'Đã sao chép JSON.');
                        }
                      },
                      child: const Text('Sao chép JSON'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
