/// features/market/domain/repositories/market_repository.dart
/// Tầng Domain - Abstract interface cho Market Repository.
/// Provider sẽ chỉ giao tiếp qua interface này.
library market_repository;

import '../entities/market_item.dart';

abstract class MarketRepository {
  /// Lấy toàn bộ mẫu thiết kế từ API
  Future<List<MarketItem>> getAllTemplates();

  /// Upload mẫu thiết kế mới lên API
  Future<void> uploadTemplate({
    required String author,
    required String thumbnailUrl,
    required Map<String, dynamic> designJson,
  });
}
