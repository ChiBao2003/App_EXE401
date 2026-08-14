/// features/market/presentation/providers/market_provider.dart
/// Tầng Presentation - Provider quản lý state cho trang Chợ hiệu ứng.
/// Không chứa bất kỳ code HTTP hay logic nghiệp vụ nào.

import 'package:flutter/foundation.dart';
import '../../domain/entities/market_item.dart';
import '../../domain/repositories/market_repository.dart';
import '../../data/repositories/market_repository_impl.dart';

/// Trạng thái loading của Provider
enum MarketStatus { initial, loading, loaded, error }

class MarketProvider extends ChangeNotifier {
  final MarketRepository _repository;

  MarketProvider({MarketRepository? repository})
      : _repository = repository ?? MarketRepositoryImpl();

  // ============================================================
  // State
  // ============================================================
  MarketStatus _status = MarketStatus.initial;
  List<MarketItem> _items = [];
  String _errorMessage = '';

  // ============================================================
  // Getters
  // ============================================================
  MarketStatus get status => _status;
  List<MarketItem> get items => _items;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == MarketStatus.loading;

  // ============================================================
  // Actions
  // ============================================================

  /// Tải danh sách mẫu thiết kế từ API
  Future<void> fetchTemplates() async {
    _status = MarketStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _items = await _repository.getAllTemplates();
      _status = MarketStatus.loaded;
    } catch (e) {
      _errorMessage = 'Không thể tải dữ liệu: $e';
      _status = MarketStatus.error;
      debugPrint('[MarketProvider] fetchTemplates error: $e');
    }
    notifyListeners();
  }

  /// Tải thêm mẫu thiết kế (mock thêm item)
  Future<void> loadMore() async {
    if (_status != MarketStatus.loaded) return;

    final mockItems = List.generate(
      10,
      (i) => MarketItem(
        id: 'mock_${_items.length + i}',
        author: ['Dev_${i + 1}', 'Maker_${i + 1}'][i % 2],
        timestamp: '2026-08-09 ${(8 + i).toString().padLeft(2, '0')}:00:00',
        thumbnailUrl: 'images/market_${(i % 4) + 1}.png',
        designJson: const {},
        likes: (i + 1) * 10,
      ),
    );

    _items.addAll(mockItems);
    notifyListeners();
  }

  /// Upload mẫu thiết kế mới
  Future<bool> uploadTemplate({
    required String author,
    required String thumbnailUrl,
    required Map<String, dynamic> designJson,
  }) async {
    try {
      await _repository.uploadTemplate(
        author: author,
        thumbnailUrl: thumbnailUrl,
        designJson: designJson,
      );
      await fetchTemplates(); // Reload sau khi upload
      return true;
    } catch (e) {
      _errorMessage = 'Upload thất bại: $e';
      notifyListeners();
      return false;
    }
  }
}
