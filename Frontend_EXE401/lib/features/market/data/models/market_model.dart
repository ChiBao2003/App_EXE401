/// features/market/data/models/market_model.dart
/// Tầng Data - Data model biết cách fromJson/toJson.
/// Extend MarketItem entity để thêm serialization.
library market_model;

import '../../domain/entities/market_item.dart';

class MarketModel extends MarketItem {
  const MarketModel({
    required super.id,
    required super.author,
    required super.timestamp,
    required super.thumbnailUrl,
    required super.designJson,
    required super.likes,
  });

  /// Chuyển JSON từ API → MarketModel
  factory MarketModel.fromJson(Map<String, dynamic> json) {
    // Xử lý timestamp
    String timeStr = json['timestamp']?.toString() ?? '';
    if (timeStr.contains('T')) {
      timeStr = timeStr.replaceAll('T', ' ');
      if (timeStr.length > 19) timeStr = timeStr.substring(0, 19);
    }

    // Xu ly thumbnail URL - Flutter Image.asset can nhan dung dinh dang
    // VD: 'assets/images/market_1.png' → giu nguyen
    // VD: 'images/market_1.png' → giu nguyen (errorBuilder se xu ly)
    String thumbUrl = json['thumbnail_url']?.toString() ?? 'assets/images/market_1.png';
    // Dam bao path khong bi double 'assets/assets/'
    if (thumbUrl.startsWith('assets/assets/')) {
      thumbUrl = thumbUrl.replaceFirst('assets/', '');
    }
    // Neu chi co 'images/...' thi them 'assets/' vao truoc
    if (!thumbUrl.startsWith('assets/') && !thumbUrl.startsWith('http')) {
      thumbUrl = 'assets/$thumbUrl';
    }

    return MarketModel(
      id: json['_id']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Unknown',
      timestamp: timeStr,
      thumbnailUrl: thumbUrl,
      designJson: Map<String, dynamic>.from(json['design_json'] ?? {}),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Chuyển MarketModel → JSON để gửi lên API
  Map<String, dynamic> toJson() => {
        'author': author,
        'thumbnail_url': thumbnailUrl,
        'design_json': designJson,
        'likes': likes,
      };
}
