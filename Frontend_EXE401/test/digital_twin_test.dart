import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/api/ai_api.dart';
import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/usage_tracking/models.dart';
import 'package:eink_clock/features/ai_hub/digital_twin_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 15: FLOW Formula & Boundary Value Unit Tests', () {
    test('Standard FLOW formula evaluates correctly on Stitch sample', () {
      // Formula: (0.35 * F + 0.25 * E + 0.20 * B + 0.20 * R) - (0.10 * S)
      // F=85, E=90, B=75, R=80, S=30:
      // (29.75 + 22.50 + 15.00 + 16.00) - 3.00 = 83.25 - 3.00 = 80.25 => round() = 80
      final score = DigitalTwinProfile.computeReadinessScore(
        focus: 85.0,
        efficiency: 90.0,
        breakScore: 75.0,
        resilience: 80.0,
        stressLevel: 30.0,
      );
      expect(score, 80);
      expect(score, equals(DigitalTwinProfile.fallbackStitch.readinessScore));
    });

    test('Upper boundary: All 100 positive axes, 0 stress => 100', () {
      final score = DigitalTwinProfile.computeReadinessScore(
        focus: 100.0,
        efficiency: 100.0,
        breakScore: 100.0,
        resilience: 100.0,
        stressLevel: 0.0,
      );
      expect(score, 100);
      expect(
        DigitalTwinProfile.computeReadinessStatus(score),
        contains('Peak Flow'),
      );
    });

    test('Lower boundary: All 0 positive axes, 100 stress => clamped to 0', () {
      // Raw: (0 + 0 + 0 + 0) - (0.10 * 100) = -10.0 => clamped to 0
      final score = DigitalTwinProfile.computeReadinessScore(
        focus: 0.0,
        efficiency: 0.0,
        breakScore: 0.0,
        resilience: 0.0,
        stressLevel: 100.0,
      );
      expect(score, 0);
      expect(
        DigitalTwinProfile.computeReadinessStatus(score),
        contains('Fatigue Risk'),
      );
    });

    test('Zero boundary: All 0 axes including stress => 0', () {
      final score = DigitalTwinProfile.computeReadinessScore(
        focus: 0.0,
        efficiency: 0.0,
        breakScore: 0.0,
        resilience: 0.0,
        stressLevel: 0.0,
      );
      expect(score, 0);
    });

    test('Full positive with full stress penalty => 90', () {
      // Raw: (100*0.35 + 100*0.25 + 100*0.20 + 100*0.20) - (100*0.10) = 100 - 10 = 90
      final score = DigitalTwinProfile.computeReadinessScore(
        focus: 100.0,
        efficiency: 100.0,
        breakScore: 100.0,
        resilience: 100.0,
        stressLevel: 100.0,
      );
      expect(score, 90);
    });

    test('Readiness status thresholds categorized accurately', () {
      expect(
        DigitalTwinProfile.computeReadinessStatus(80),
        contains('Peak Flow'),
      );
      expect(
        DigitalTwinProfile.computeReadinessStatus(79),
        contains('Steady Flow'),
      );
      expect(
        DigitalTwinProfile.computeReadinessStatus(65),
        contains('Steady Flow'),
      );
      expect(
        DigitalTwinProfile.computeReadinessStatus(64),
        contains('Moderate'),
      );
      expect(
        DigitalTwinProfile.computeReadinessStatus(50),
        contains('Moderate'),
      );
      expect(
        DigitalTwinProfile.computeReadinessStatus(49),
        contains('Fatigue Risk'),
      );
    });
  });

  group('Task 15: DigitalTwinProfile Model & Data Integrity Tests', () {
    test(
      'Calculates 5 axes and readiness core score accurately from real sources',
      () {
        final burnout = BurnoutRisk(
          riskScore: 24.0,
          riskLevel: 'low',
          indicators: ['Độ tập trung cao', 'Nhịp sinh học ổn định'],
          advice: 'Nghỉ ngơi đều đặn 5 phút sau mỗi 25 phút Pomodoro',
        );

        final coach = CoachAdvice(
          advice: 'Duy trì phong độ tập trung tốt',
          source: 'rule_based',
          personalized: true,
          stats: {
            'avg_concentration_score': 88.0,
            'break_skip_rate': 15.0,
            'completion_rate': 90.0,
          },
        );

        final usage = DailyUsageSummary(
          date: DateTime.now(),
          totalScreenTimeMs: 7200000,
          totalUnlocks: 15,
          totalDistractions: 3,
          productiveTimeMs: 5400000,
          distractedTimeMs: 600000,
          topApps: [],
          focusScore: 85.0,
        );

        final profile = DigitalTwinProfile.fromSources(
          burnout: burnout,
          coach: coach,
          usage: usage,
          timeWindow: '24h',
        );

        expect(profile.focusScore, 88.0);
        expect(profile.breakScore, 85.0); // 100 - 15
        expect(profile.stressLevel, 24.0);
        // Resilience is the exact behavioral inverse of Burnout Risk:
        expect(profile.resilience, 76.0); // 100 - 24
        expect(profile.burnoutRisk, 24.0);
        // Efficiency = 88 * 0.6 + 90 * 0.4 = 52.8 + 36.0 = 88.8
        expect(profile.efficiency, 88.8);

        // Raw readiness = (88 * 0.35) + (88.8 * 0.25) + (85 * 0.20) + (76 * 0.20) - (24 * 0.10)
        // = 30.8 + 22.2 + 17.0 + 15.2 - 2.4 = 82.8 => 83
        expect(profile.readinessScore, 83);
        expect(profile.readinessStatus, contains('Peak Flow'));
        expect(profile.hasEnoughData, isTrue);
        expect(profile.isFallback, isFalse);
        expect(profile.isOffline, isFalse);
        expect(profile.recommendations.length, 2);
      },
    );

    test(
      'Gracefully handles missing / null / malformed stats in CoachAdvice',
      () {
        final coachEmpty = CoachAdvice(
          advice: '',
          source: 'rule_based',
          personalized: false,
          stats: {},
        );

        final profile = DigitalTwinProfile.fromSources(coach: coachEmpty);

        expect(profile.focusScore, 75.0);
        expect(profile.breakScore, 75.0);
        expect(profile.stressLevel, 30.0);
        expect(profile.resilience, 70.0); // 100 - 30
        expect(profile.hasEnoughData, isFalse);
      },
    );

    test('Gracefully handles string-encoded values in stats map', () {
      final coachString = CoachAdvice(
        advice: 'Tập trung tốt',
        source: 'rule_based',
        personalized: true,
        stats: {
          'avg_concentration_score': '92.5',
          'break_skip_rate': '10',
          'completion_rate': '95',
        },
      );

      final profile = DigitalTwinProfile.fromSources(coach: coachString);

      expect(profile.focusScore, 92.5);
      expect(profile.breakScore, 90.0); // 100 - 10
      expect(profile.hasEnoughData, isTrue);
    });

    test(
      'Fallback profile is marked as isFallback and hasEnoughData=false',
      () {
        const fallback = DigitalTwinProfile.fallbackStitch;
        expect(fallback.isFallback, isTrue);
        expect(fallback.hasEnoughData, isFalse);
        expect(fallback.readinessScore, 80);
        expect(fallback.resilience, 80.0);
        expect(fallback.burnoutRisk, 22.0);
      },
    );
  });

  group('Task 15: Digital Twin Screen UI & Widget Tests', () {
    late BleService fakeBle;

    setUp(() {
      fakeBle = BleService();
    });

    Widget createScreen({DigitalTwinProfile? initialProfile, BleService? ble}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<BleService>.value(value: ble ?? fakeBle),
        ],
        child: MaterialApp(
          home: DigitalTwinScreen(
            initialProfile: initialProfile ?? DigitalTwinProfile.fallbackStitch,
          ),
          routes: {
            '/digital_twin': (_) => const DigitalTwinScreen(
              initialProfile: DigitalTwinProfile.fallbackStitch,
            ),
          },
        ),
      );
    }

    testWidgets(
      'Renders header, Aether Synapse context badge and title correctly',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        expect(find.text('Chi Tiết Thiết Bị'), findsOneWidget);
        expect(find.text('AETHER NEURAL TELEMETRY'), findsOneWidget);
        expect(find.text('Hồ Sơ Năng Suất Digital Twin'), findsOneWidget);
        expect(find.textContaining('Bản sao nhận thức số hóa'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders 5-Axis Spider Radar Card and synchronized center FLOW score 80',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        expect(find.text('Mạng Lưới Thần Kinh 5 Trục'), findsOneWidget);
        expect(find.text('Mô phỏng nhận thức theo chu kỳ 24h'), findsOneWidget);
        expect(find.text('Peak Flow'), findsWidgets);

        // Verify CustomPaint for SpiderRadarPainter is rendered
        expect(find.byType(CustomPaint), findsWidgets);

        // Verify the readiness strip below radar matches computeReadinessScore 80
        expect(find.textContaining('80/100'), findsOneWidget);
        expect(find.textContaining('Khả năng ghi nhớ tối ưu'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders 2x2 Bento grid synchronized with Radar and proxy disclosure',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        expect(find.text('Focus Score'), findsOneWidget);
        expect(find.text('85'), findsWidgets);

        expect(find.text('Stress Level'), findsOneWidget);
        expect(find.text('30'), findsWidgets);
        expect(find.text('Proxy hành vi (BRIX)'), findsOneWidget);

        expect(find.text('Break Norm'), findsOneWidget);
        expect(find.text('75'), findsWidgets);

        expect(find.text('Burnout Risk'), findsOneWidget);
        expect(find.text('22'), findsWidgets);

        // Subtitle shows inverse Resilience link to Burnout Risk
        expect(find.text('Độ bền: 80% (Nghịch đảo)'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders E-Ink Smartwatch Mirror Module synchronized with FLOW 80',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        expect(find.text('Mô Phỏng E-ink Smartwatch'), findsOneWidget);
        expect(find.text('AETHER MATRIX v2.4'), findsOneWidget);
        expect(find.text('TRẠNG THÁI'), findsOneWidget);
        expect(find.text('DEEP SESSION'), findsOneWidget);
        // Synchronized with readinessScore 80
        expect(find.text('FLOW 80'), findsWidgets);
      },
    );

    testWidgets('Shows fallback notice banner for fallbackStitch', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Đang hiển thị hồ sơ mẫu minh họa'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Shows low data notice banner when hasEnoughData is false and not fallback',
      (tester) async {
        const lowDataProfile = DigitalTwinProfile(
          focusScore: 60,
          stressLevel: 45,
          breakScore: 50,
          efficiency: 60,
          resilience: 55,
          burnoutRisk: 45,
          readinessScore: 58,
          readinessStatus: 'Moderate',
          hasEnoughData: false,
          isFallback: false,
        );

        await tester.pumpWidget(createScreen(initialProfile: lowDataProfile));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Dữ liệu chưa đủ chu kỳ phân tích'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'khuyến nghị ≥ 5 phiên Pomodoro theo thuật toán BRIX',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Shows offline notice banner when isOffline is true', (
      tester,
    ) async {
      const offlineProfile = DigitalTwinProfile(
        focusScore: 78,
        stressLevel: 35,
        breakScore: 70,
        efficiency: 75,
        resilience: 65,
        burnoutRisk: 35,
        readinessScore: 70,
        readinessStatus: 'Steady Flow',
        hasEnoughData: true,
        isOffline: true,
      );

      await tester.pumpWidget(createScreen(initialProfile: offlineProfile));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Máy chủ AI offline. Đang hiển thị dữ liệu lưu từ phiên trước',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Time window filter chips update selection and show filter disclosure',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        expect(find.text('24 Giờ Qua'), findsOneWidget);
        expect(find.text('7 Ngày Qua'), findsOneWidget);
        expect(find.text('15 Ngày Qua'), findsOneWidget);

        // Tap '7 Ngày Qua'
        await tester.tap(find.text('7 Ngày Qua'));
        await tester.pump();

        // Disclosure banner for 7d appears
        expect(find.textContaining('Bộ lọc 7 Ngày Qua'), findsOneWidget);
        expect(
          find.textContaining('Backend AI tính toán theo cửa sổ chuẩn'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Renders AI Recommendations and Hardware Action Section', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(find.text('Đề Xuất Tối Ưu Hóa AI'), findsOneWidget);
      expect(find.textContaining('Tăng thời lượng giải lao'), findsOneWidget);
      expect(find.text('Khóa thông báo trên đồng hồ E-ink'), findsOneWidget);

      expect(
        find.text('Cập nhật mô hình Digital Twin vào bộ nhớ ESP32'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Tapping Hardware Sync Button when BLE disconnected shows SnackBar warning',
      (tester) async {
        await tester.pumpWidget(createScreen());
        await tester.pumpAndSettle();

        final syncBtn = find.text(
          'Cập nhật mô hình Digital Twin vào bộ nhớ ESP32',
        );
        await tester.scrollUntilVisible(
          syncBtn,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(syncBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Chưa kết nối ESP32 qua BLE'),
          findsOneWidget,
        );
      },
    );
  });

  group('Task 15: Backwards Compatibility & Route Tests', () {
    testWidgets('DigitalTwinDashboard renders correctly with fl_chart', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DigitalTwinDashboard(
              focusScore: 80,
              stressLevel: 30,
              breakScore: 85,
              efficiency: 88,
              burnoutRisk: 20,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Digital Twin Productivity Profile'), findsOneWidget);
      expect(find.textContaining('Burnout Risk: 20%'), findsOneWidget);
    });

    testWidgets(
      'App route /digital_twin mounts DigitalTwinScreen without error',
      (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BleService>(create: (_) => BleService()),
            ],
            child: MaterialApp(
              initialRoute: '/',
              routes: {
                '/': (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(ctx, '/digital_twin'),
                    child: const Text('Open'),
                  ),
                ),
                '/digital_twin': (_) => const DigitalTwinScreen(
                  initialProfile: DigitalTwinProfile.fallbackStitch,
                ),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(DigitalTwinScreen), findsOneWidget);
        expect(find.text('Hồ Sơ Năng Suất Digital Twin'), findsOneWidget);
      },
    );
  });
}
