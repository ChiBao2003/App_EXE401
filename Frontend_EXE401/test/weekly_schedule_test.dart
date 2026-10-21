import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/features/schedule/weekly_schedule_screen.dart';

void main() {
  final sampleSchedules = [
    ScheduleItem(
      id: 'sched_1',
      dayOfWeek: 'Wed',
      hour: 8,
      minute: 0,
      label: 'Học môn Hệ điều hành - Phòng B201',
    ),
    ScheduleItem(
      id: 'sched_2',
      dayOfWeek: 'Wed',
      hour: 10,
      minute: 0,
      label: 'Ôn tập Cấu trúc dữ liệu & Giải thuật',
    ),
    ScheduleItem(
      id: 'sched_3',
      dayOfWeek: 'Wed',
      hour: 14,
      minute: 0,
      label: 'Lab Thực hành IoT ESP32 BLE',
    ),
    ScheduleItem(
      id: 'sched_4',
      dayOfWeek: 'Mon',
      hour: 9,
      minute: 30,
      label: 'Toán Rời Rạc',
    ),
  ];

  Widget createScheduleScreen({
    List<dynamic>? initialSchedules,
    int? initialSelectedDayIndex,
    http.Client? httpClient,
  }) {
    return ChangeNotifierProvider(
      create: (_) => BleService(),
      child: MaterialApp(
        home: WeeklyScheduleScreen(
          initialSchedules: initialSchedules,
          initialSelectedDayIndex: initialSelectedDayIndex,
          httpClient: httpClient,
        ),
      ),
    );
  }

  group('WeeklyScheduleScreen Widget Tests', () {
    testWidgets(
      'Renders Weekly Smart Schedule with Aether Synapse theme and items',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createScheduleScreen(
            initialSchedules: sampleSchedules,
            initialSelectedDayIndex: 2, // Wednesday (T4)
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify Top App Bar & Hero Banner
        expect(find.text('Lịch Tuần'), findsOneWidget);
        expect(find.text('OFFLINE'), findsOneWidget);
        expect(find.text('Lịch Nhắc Nhở Tuần'), findsOneWidget);
        expect(find.text('BLE Disconnected'), findsOneWidget);
        expect(find.text('Đồng bộ ESP32'), findsOneWidget);
        expect(find.text('SRAM: 312KB rảnh'), findsOneWidget);

        // 2. Verify Day Selector (T2 ... CN)
        expect(find.byKey(const Key('dayTab_T2')), findsOneWidget);
        expect(find.byKey(const Key('dayTab_T3')), findsOneWidget);
        expect(find.byKey(const Key('dayTab_T4')), findsOneWidget);
        expect(find.byKey(const Key('dayTab_CN')), findsOneWidget);

        // 3. Verify Day Configuration Card for Wednesday
        expect(find.textContaining('Thứ Tư'), findsOneWidget);
        expect(find.text('3 phiên đồng bộ sẵn sàng'), findsOneWidget);
        expect(find.byKey(const Key('dayToggle')), findsOneWidget);

        // 4. Verify Schedule Slots
        expect(find.text('Học môn Hệ điều hành - Phòng B201'), findsOneWidget);
        expect(
          find.text('Ôn tập Cấu trúc dữ liệu & Giải thuật'),
          findsOneWidget,
        );
        expect(find.text('Lab Thực hành IoT ESP32 BLE'), findsOneWidget);
        expect(find.text('08:00'), findsOneWidget);
        expect(find.text('10:00'), findsOneWidget);
        expect(find.text('14:00'), findsOneWidget);
        expect(find.byKey(const Key('btnAddSlot')), findsOneWidget);

        // 5. Verify the current TFT preview.
        expect(find.text('Bản xem trước TFT LCD · 320×240 RGB565'), findsOneWidget);
        expect(find.textContaining('Lịch được lưu trong NVS'), findsOneWidget);

        // 6. Verify Primary Bottom Sync Button
        expect(find.byKey(const Key('pushScheduleBtn')), findsOneWidget);
        expect(find.text('Lưu và nạp vào đồng hồ'), findsOneWidget);
      },
    );

    testWidgets(
      'Toggles between different day tabs and updates slots and E-ink preview',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createScheduleScreen(
            initialSchedules: sampleSchedules,
            initialSelectedDayIndex: 2, // Wednesday
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Monday (T2)
        final t2Tab = find.byKey(const Key('dayTab_T2'));
        await tester.tap(t2Tab);
        await tester.pump(const Duration(milliseconds: 100));

        // Monday has 1 slot: 'Toán Rời Rạc'
        expect(find.textContaining('Thứ Hai'), findsOneWidget);
        expect(find.text('1 phiên đồng bộ sẵn sàng'), findsOneWidget);
        expect(find.text('Toán Rời Rạc'), findsOneWidget);

        // Switch to Sunday (CN)
        final cnTab = find.byKey(const Key('dayTab_CN'));
        await tester.tap(cnTab);
        await tester.pump(const Duration(milliseconds: 100));

        // Sunday has no slots
        expect(find.text('Chủ Nhật'), findsOneWidget);
        expect(find.text('0 phiên đồng bộ sẵn sàng'), findsOneWidget);
        expect(
          find.text('Chưa có khung giờ nhắc nhở cho Chủ Nhật'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Toggles day active switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        createScheduleScreen(
          initialSchedules: sampleSchedules,
          initialSelectedDayIndex: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final switchWidget = find.byKey(const Key('dayToggle'));
      expect(switchWidget, findsOneWidget);

      await tester.tap(switchWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Adds new schedule slot via dialog', (
      WidgetTester tester,
    ) async {
      bool postCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.contains('/api/v1/schedules')) {
          postCalled = true;
          return http.Response(
            jsonEncode({
              'message': 'Tạo lịch thành công!',
              'inserted_id': 'new_id_123',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path.contains('/api/v1/schedules')) {
          return http.Response(
            jsonEncode([
              ...sampleSchedules.map(
                (e) => {
                  '_id': e.id,
                  'day_of_week': e.dayOfWeek,
                  'hour': e.hour,
                  'minute': e.minute,
                  'label': e.label,
                  'is_active': e.isActive,
                },
              ),
              {
                '_id': 'new_id_123',
                'day_of_week': 'Wed',
                'hour': 8,
                'minute': 0,
                'label': 'Lớp học AI nâng cao',
                'is_active': true,
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"detail": "Not found"}', 404);
      });

      await tester.pumpWidget(
        createScheduleScreen(
          initialSchedules: sampleSchedules,
          initialSelectedDayIndex: 2,
          httpClient: mockClient,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Thêm khung giờ mới"
      final addBtn = find.byKey(const Key('btnAddSlot'));
      await tester.ensureVisible(addBtn);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Thêm Khung Giờ Mới'), findsOneWidget);

      // Enter label
      await tester.enterText(find.byType(TextField), 'Lớp học AI nâng cao');
      await tester.pump();

      // Tap confirm button
      await tester.tap(find.byKey(const Key('btnConfirmAddSlot')));
      await tester.pumpAndSettle();

      expect(postCalled, isTrue);
    });

    testWidgets('Deletes schedule slot via delete button', (
      WidgetTester tester,
    ) async {
      bool deleteCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path.contains('/sched_1')) {
          deleteCalled = true;
          return http.Response(
            jsonEncode({'message': 'Xóa thành công!', 'success': true}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"detail": "Not found"}', 404);
      });

      await tester.pumpWidget(
        createScheduleScreen(
          initialSchedules: sampleSchedules,
          initialSelectedDayIndex: 2,
          httpClient: mockClient,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final deleteBtn = find.byKey(const Key('btnDelete_sched_1'));
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(deleteCalled, isTrue);
    });

    testWidgets('Offline sync reports failure instead of fake success', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createScheduleScreen(
          initialSchedules: sampleSchedules,
          initialSelectedDayIndex: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Lưu và nạp vào đồng hồ"
      final pushBtn = find.byKey(const Key('pushScheduleBtn'));
      await tester.ensureVisible(pushBtn);
      await tester.tap(pushBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Không thể đồng bộ:'), findsOneWidget);
    });
  });
}
