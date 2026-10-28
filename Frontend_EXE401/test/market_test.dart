import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/market/data/models/market_model.dart';
import 'package:eink_clock/features/market/domain/entities/market_item.dart';
import 'package:eink_clock/features/market/domain/repositories/market_repository.dart';
import 'package:eink_clock/features/market/presentation/providers/market_provider.dart';
import 'package:eink_clock/features/market/presentation/screens/market_screen.dart';

class MockMarketRepository implements MarketRepository {
  List<MarketItem>? itemsToReturn;
  Completer<List<MarketItem>>? completer;
  bool shouldThrow = false;
  String errorMessage = 'Lỗi kết nối máy chủ';
  int fetchCallCount = 0;

  @override
  Future<List<MarketItem>> getAllTemplates() async {
    fetchCallCount++;
    if (completer != null) {
      return completer!.future;
    }
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return itemsToReturn ?? [];
  }

  @override
  Future<void> uploadTemplate({
    required String author,
    required String thumbnailUrl,
    required Map<String, dynamic> designJson,
  }) async {}
}

void main() {
  late MockMarketRepository mockRepo;
  late MarketProvider marketProvider;

  setUp(() {
    mockRepo = MockMarketRepository();
    marketProvider = MarketProvider(repository: mockRepo);
  });

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget buildTestWidget({
    MarketProvider? provider,
    Widget? home,
    Map<String, WidgetBuilder>? routes,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
        ),
        ChangeNotifierProvider<MarketProvider>.value(
          value: provider ?? marketProvider,
        ),
      ],
      child: MaterialApp(
        home: home ?? const MarketScreen(),
        routes:
            routes ??
            {
              '/market': (_) => const MarketScreen(),
              '/design': (_) =>
                  const Scaffold(body: Text('Design Screen Mock')),
            },
      ),
    );
  }

  final testItems = [
    const MarketItem(
      id: 'chrono_1',
      author: 'alex_embedded',
      timestamp: '2026-10-15 10:00:00',
      thumbnailUrl: 'assets/images/market_1.png',
      designJson: {
        'title': 'Chronos Data Stream',
        'elements': [
          {'content': '14:52'},
        ],
      },
      likes: 842,
    ),
    const MarketItem(
      id: 'pixel_2',
      author: 'zen_coder',
      timestamp: '2026-10-14 12:00:00',
      thumbnailUrl: 'assets/images/market_2.png',
      designJson: {
        'title': 'Komorebi Pixel Art',
        'elements': [
          {'content': '10:45'},
        ],
      },
      likes: 1200,
    ),
    const MarketItem(
      id: 'terminal_3',
      author: 'viet_hardware',
      timestamp: '2026-10-13 14:00:00',
      thumbnailUrl: 'assets/images/market_3.png',
      designJson: {
        'title': 'Bento Dev Terminal',
        'elements': [
          {'content': '03:14'},
        ],
      },
      likes: 630,
    ),
  ];

  testWidgets(
    'MarketScreen renders top header with Synapse AI and Aether Synapse theme',
    (tester) async {
      setupViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      mockRepo.itemsToReturn = testItems;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Synapse'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('E-INK SYNC 12MS'), findsOneWidget);
      expect(find.text('98%'), findsOneWidget);
      expect(find.byIcon(Icons.watch_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'MarketScreen renders search input and all category filter chips',
    (tester) async {
      setupViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      mockRepo.itemsToReturn = testItems;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('Tìm kiếm mặt đồng hồ E-ink, tác giả, tag...'),
        findsOneWidget,
      );
      expect(find.text('Phổ biến nhất'), findsOneWidget);
      expect(find.text('Mới nhất'), findsOneWidget);
      expect(find.text('Tối giản (Minimal)'), findsOneWidget);
      expect(find.text('Anime & Pixel'), findsOneWidget);
      expect(find.text('Kỹ thuật số (Digital)'), findsOneWidget);
      expect(find.text('Được chứng nhận AI'), findsOneWidget);
    },
  );

  testWidgets(
    'MarketScreen renders Featured Spotlight banner with Cyberpunk theme',
    (tester) async {
      setupViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      mockRepo.itemsToReturn = testItems;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SPOTLIGHT DROP'), findsOneWidget);
      expect(find.text('Bộ Sưu Tập Cyberpunk E-Paper 2025'), findsOneWidget);
      expect(find.text('3 Mặt Đồng Hồ'), findsOneWidget);
      expect(find.text('Miễn Phí'), findsOneWidget);
      expect(find.text('Khám phá ngay'), findsOneWidget);

      // Tapping "Khám phá ngay" opens Spotlight dialog
      await tester.tap(find.text('Khám phá ngay'));
      await tester.pumpAndSettle();

      expect(find.text('Bộ Sưu Tập Cyberpunk 2025'), findsOneWidget);
      expect(find.text('Khám phá'), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'MarketScreen renders community section, items grid, and SDK callout box',
    (tester) async {
      setupViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      mockRepo.itemsToReturn = testItems;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cộng đồng sáng chế'), findsOneWidget);
      expect(find.text('3 designs'), findsOneWidget);
      expect(find.text('Bộ lọc'), findsOneWidget);

      expect(find.text('Chronos Data Stream'), findsOneWidget);
      expect(find.text('@alex_embedded'), findsOneWidget);
      expect(find.text('Komorebi Pixel Art'), findsOneWidget);
      expect(find.text('@zen_coder'), findsOneWidget);

      expect(find.text('Synapse Watch SDK v2.4'), findsOneWidget);
      expect(find.text('Đăng tải thiết kế'), findsOneWidget);
    },
  );

  testWidgets('MarketScreen handles loading state correctly', (tester) async {
    setupViewport(tester);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    final completer = Completer<List<MarketItem>>();
    final slowRepo = MockMarketRepository()..completer = completer;
    final slowProvider = MarketProvider(repository: slowRepo);

    await tester.pumpWidget(buildTestWidget(provider: slowProvider));
    await tester.pump(); // Trigger post frame callback fetchTemplates()
    await tester.pump(); // Re-render with MarketStatus.loading

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Đang đồng bộ mặt đồng hồ E-ink...'), findsOneWidget);

    completer.complete(testItems);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Chronos Data Stream'), findsOneWidget);
  });

  testWidgets('MarketScreen handles empty state when repo returns 0 items', (
    tester,
  ) async {
    setupViewport(tester);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    mockRepo.itemsToReturn = [];

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('0 designs'), findsOneWidget);
    expect(find.text('Chưa có mẫu mặt đồng hồ nào phù hợp.'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('MarketScreen handles error state with retry button', (
    tester,
  ) async {
    setupViewport(tester);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    mockRepo.shouldThrow = true;
    mockRepo.errorMessage = 'Máy chủ đang bảo trì (503)';

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.textContaining('Máy chủ đang bảo trì (503)'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    // Bấm Thử lại sau khi server phục hồi
    mockRepo.shouldThrow = false;
    mockRepo.itemsToReturn = testItems;

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    expect(find.text('Chronos Data Stream'), findsOneWidget);
  });

  testWidgets('Search query dynamically filters items list', (tester) async {
    setupViewport(tester);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    mockRepo.itemsToReturn = testItems;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Chronos Data Stream'), findsOneWidget);
    expect(find.text('Komorebi Pixel Art'), findsOneWidget);

    // Nhập tìm kiếm "zen"
    await tester.enterText(find.byType(TextField), 'zen');
    await tester.pumpAndSettle();

    expect(find.text('Komorebi Pixel Art'), findsOneWidget);
    expect(find.text('Chronos Data Stream'), findsNothing);
    expect(find.text('1 designs'), findsOneWidget);

    // Xóa tìm kiếm
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Chronos Data Stream'), findsOneWidget);
    expect(find.text('3 designs'), findsOneWidget);
  });

  testWidgets('Selecting category filter chips filters and sorts correctly', (
    tester,
  ) async {
    setupViewport(tester);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    mockRepo.itemsToReturn = testItems;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Chọn "Anime & Pixel"
    await tester.tap(find.text('Anime & Pixel'));
    await tester.pumpAndSettle();

    expect(find.text('Komorebi Pixel Art'), findsOneWidget);
    expect(find.text('Chronos Data Stream'), findsNothing);

    // Chọn lại "Phổ biến nhất"
    await tester.tap(find.text('Phổ biến nhất'));
    await tester.pumpAndSettle();

    expect(find.text('Chronos Data Stream'), findsOneWidget);
    expect(find.text('Komorebi Pixel Art'), findsOneWidget);
  });

  testWidgets('Tapping like button increments like count interactively', (
    tester,
  ) async {
    setupViewport(tester);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    mockRepo.itemsToReturn = testItems;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('842'), findsOneWidget);

    // Bấm nút Like của card đầu tiên
    await tester.tap(find.text('842'));
    await tester.pumpAndSettle();

    expect(find.text('843'), findsOneWidget);
  });

  testWidgets(
    'Tapping install button when BLE is offline warns honestly without fake success',
    (tester) async {
      setupViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      mockRepo.itemsToReturn = testItems;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tìm và bấm nút Cài đặt đầu tiên
      final installButtons = find.text('Cài đặt');
      expect(installButtons, findsWidgets);

      await tester.tap(installButtons.first);
      await tester.pump(); // Show snackbar

      expect(find.textContaining('Chưa kết nối ESP32 qua BLE'), findsOneWidget);
    },
  );

  testWidgets('Tapping FAB navigates to /design screen', (tester) async {
    setupViewport(tester);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    mockRepo.itemsToReturn = testItems;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng tải thiết kế'));
    await tester.pumpAndSettle();

    expect(find.text('Design Screen Mock'), findsOneWidget);
  });

  testWidgets(
    'MarketModel serialization parses safely with corrupted/missing JSON fields',
    (tester) async {
      // Test empty JSON
      final emptyModel = MarketModel.fromJson(const {});
      expect(emptyModel.author, 'Unknown');
      expect(emptyModel.likes, 0);
      expect(emptyModel.thumbnailUrl, 'assets/images/market_1.png');
      expect(emptyModel.previewText, '12:00');

      // Test malformed timestamp and double assets/
      final sampleModel = MarketModel.fromJson({
        '_id': 'mock_99',
        'author': 'Tester',
        'timestamp': '2026-10-15T15:30:45.123456Z',
        'thumbnail_url': 'assets/assets/images/sample.png',
        'likes': 42,
        'design_json': {
          'title': 'Test Face',
          'elements': [
            {'content': '07:15'},
          ],
        },
      });

      expect(sampleModel.id, 'mock_99');
      expect(sampleModel.author, 'Tester');
      expect(sampleModel.timestamp, '2026-10-15 15:30:45');
      expect(sampleModel.thumbnailUrl, 'assets/images/sample.png');
      expect(sampleModel.likes, 42);
      expect(sampleModel.title, 'Test Face');
      expect(sampleModel.previewText, '07:15');

      final json = sampleModel.toJson();
      expect(json['author'], 'Tester');
      expect(json['likes'], 42);
    },
  );

  testWidgets(
    'Route /market opens MarketScreen successfully from MaterialApp',
    (tester) async {
      setupViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      mockRepo.itemsToReturn = testItems;

      await tester.pumpWidget(
        buildTestWidget(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.pushNamed(ctx, '/market'),
                child: const Text('Open Market'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Market'), findsOneWidget);
      await tester.tap(find.text('Open Market'));
      await tester.pumpAndSettle();

      expect(find.text('Synapse'), findsOneWidget);
      expect(find.text('Cộng đồng sáng chế'), findsOneWidget);
    },
  );
}
