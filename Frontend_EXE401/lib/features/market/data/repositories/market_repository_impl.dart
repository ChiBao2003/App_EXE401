/// features/market/data/repositories/market_repository_impl.dart
/// Tầng Data - Implement MarketRepository thật bằng cách gọi API.
/// Đây là nơi DUY NHẤT chứa code HTTP gọi API Market.
library market_repository_impl;

import 'package:flutter/foundation.dart';
import '../../domain/entities/market_item.dart';
import '../../domain/repositories/market_repository.dart';
import '../models/market_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

class MarketRepositoryImpl implements MarketRepository {
  final ApiClient _api;

  MarketRepositoryImpl({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient.instance;

  @override
  Future<List<MarketItem>> getAllTemplates() async {
    final data = await _api.get(AppConstants.marketEndpoint);
    final list = data as List<dynamic>;
    return list
        .map((json) => MarketModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> uploadTemplate({
    required String author,
    required String thumbnailUrl,
    required Map<String, dynamic> designJson,
  }) async {
    await _api.post(AppConstants.marketEndpoint, {
      'author': author,
      'thumbnail_url': thumbnailUrl,
      'design_json': designJson,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'likes': 0,
    });
  }
}
