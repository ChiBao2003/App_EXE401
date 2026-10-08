/// features/market/presentation/widgets/market_card.dart
/// Tầng Presentation - Widget hiển thị 1 thẻ mẫu thiết kế.
/// Tách ra file riêng, dễ test và tái sử dụng.
library market_card;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/market_item.dart';

class MarketCard extends StatelessWidget {
  final MarketItem item;
  final int displayIndex;

  const MarketCard({
    super.key,
    required this.item,
    required this.displayIndex,
  });

  Widget _buildMockEinkFace() {
    if (displayIndex % 2 == 0) {
      return Container(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Dương Lịch', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold)),
                Text('09', style: GoogleFonts.sourceCodePro(fontSize: 32, fontWeight: FontWeight.w900, height: 1.0)),
                Text('Th 08\n2026', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('08:30', style: GoogleFonts.sourceCodePro(fontSize: 24, fontWeight: FontWeight.w900, height: 1.0)),
                const SizedBox(height: 2),
                Text('Hoàng Thịnh PRO', style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w900)),
                Text('C.Nhật', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Âm Lịch', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold)),
                Text('27', style: GoogleFonts.sourceCodePro(fontSize: 32, fontWeight: FontWeight.w900, height: 1.0)),
                Text('Th 06\n2026', style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RotatedBox(quarterTurns: 3, child: Text('Tháng 08', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.bold))),
            Text('09', style: GoogleFonts.sourceCodePro(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0)),
            RotatedBox(quarterTurns: 3, child: Text('Chủ Nhật', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w900))),
            Text('27', style: GoogleFonts.sourceCodePro(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0)),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/design',
        arguments: {'preview': item.previewText},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview E-ink mockup
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black26, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildMockEinkFace(),
                    ),
                  ),
                ),
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tác giả: ${item.author}',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 10, color: Colors.redAccent),
                      const SizedBox(width: 3),
                      Text('${item.likes}', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black45)),
                      const Spacer(),
                      Text(item.timestamp, style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black38)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
