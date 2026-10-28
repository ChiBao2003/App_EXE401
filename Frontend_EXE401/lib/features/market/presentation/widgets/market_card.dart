import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/bluetooth/spp_service.dart';
import '../../../../core/display/tft_layout.dart';
import '../../domain/entities/market_item.dart';
import '../providers/market_provider.dart';

class MarketCard extends StatefulWidget {
  final MarketItem item;
  final int displayIndex;
  const MarketCard({super.key, required this.item, required this.displayIndex});
  @override
  State<MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends State<MarketCard> {
  bool _uploading = false;
  Future<void> _install() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    final progress = ValueNotifier<double>(0);
    try {
      final spp = context.read<SppService>();
      final items = tftTemplateItems(widget.item.designJson);
      if (!spp.isConnected) throw StateError('Chưa kết nối ESP32 qua BLE');
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final sheet = showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, value, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Đang nạp TFT: ${(value * 100).round()}%'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: value),
                ],
              ),
            ),
          ),
        ),
      );
      try {
        await spp.uploadTftLayout(
          items,
          backgroundBitmapHex: widget.item.designJson['background_bitmap'] as String?,
          backgroundColor: parseTftColor(
            widget.item.designJson['background'] ??
                widget.item.designJson['bg_color'],
            0,
          ),
          onProgress: (done, total) => progress.value = done / total,
        );
      } finally {
        if (navigator.mounted) navigator.pop();
        await sheet;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ESP32 đã xác nhận lưu giao diện TFT.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể cài đặt: $e')));
      }
    } finally {
      progress.dispose();
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: constraints.maxWidth * 0.75, child: TftPreview(design: item.designJson)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              item.title.isEmpty ? 'Giao diện TFT' : item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '@${item.author} · ${item.likes} lượt thích',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _uploading ? null : _install,
                  child: const Text('Cài đặt'),
                ),
              ),
              IconButton(
                tooltip: 'Thích',
                onPressed: () =>
                    context.read<MarketProvider>().toggleLike(item.id),
                icon: const Icon(Icons.favorite_border, size: 18),
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/design',
              arguments: {'template': item.designJson},
            ),
            child: const Text('Mở trong Canvas Studio'),
          ),
        ],
      ))),
    );
  }
}
