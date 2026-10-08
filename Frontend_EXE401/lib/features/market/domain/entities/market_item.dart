/// features/market/domain/entities/market_item.dart
/// Tầng Domain - Pure Dart entity.
/// Không phụ thuộc vào Flutter Widget hay HTTP package nào.
library market_entity;

class MarketItem {
  final String id;
  final String author;
  final String timestamp;
  final String thumbnailUrl;
  final Map<String, dynamic> designJson;
  final int likes;

  const MarketItem({
    required this.id,
    required this.author,
    required this.timestamp,
    required this.thumbnailUrl,
    required this.designJson,
    required this.likes,
  });

  /// Preview text lấy từ design_json (computed property)
  String get previewText {
    try {
      final elements = designJson['elements'] as List?;
      if (elements != null && elements.isNotEmpty) {
        return elements[0]['content']?.toString() ?? '12:00';
      }
    } catch (_) {}
    return '12:00';
  }
}
