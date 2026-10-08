<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/bluetooth/ble_service.dart';
import 'core/bluetooth/spp_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/general_settings/general_settings_screen.dart';
import 'features/interfaces/interfaces_screen.dart';
import 'features/design/design_screen.dart';
import 'features/info/info_screen.dart';
import 'features/market/market_screen.dart';
import 'features/schedule/weekly_schedule_screen.dart';
<<<<<<< Updated upstream
=======
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "core/bluetooth/ble_service.dart";
import "core/theme/app_theme.dart";
import "features/home/home_screen.dart";
import "features/general_settings/general_settings_screen.dart";
import "features/interfaces/interfaces_screen.dart";
import "features/design/design_screen.dart";
import "features/info/info_screen.dart";

// Clean Architecture: Import tu dung presentation layer
import "features/market/presentation/screens/market_screen.dart";
import "features/market/presentation/providers/market_provider.dart";

import "features/schedule/weekly_schedule_screen.dart";
import "core/bluetooth/spp_service.dart";
import "features/pomodoro/pomodoro_screen.dart";
// Phase 1 - AI Productivity imports
import "core/api/api_client.dart";
import "features/auth/login_screen.dart";
import "features/ai_hub/ai_hub_screen.dart";
import "features/clock_mode/clock_mode_screen.dart";
import "features/digital_wellbeing/wellbeing_screen.dart";
>>>>>>> 8020cfb (feat: AI Coach fallback chain + rule-based V2 + usage tracking)
=======
<<<<<<< Updated upstream
=======
import 'features/pomodoro/pomodoro_screen.dart';
import 'features/ai_hub/ai_hub_screen.dart';
import 'features/clock_mode/clock_mode_screen.dart';
import 'features/digital_wellbeing/wellbeing_screen.dart';
// ==========================================
// THI_DUA_FEATURE_START (By Gemini)
// ==========================================
import 'features/competition/competition_screen.dart';
// ==========================================
// THI_DUA_FEATURE_END
// ==========================================
>>>>>>> Stashed changes
>>>>>>> Stashed changes

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Kiem tra token: neu chua dang nhap, mo LoginScreen
  final hasAuth = await ApiClient.hasToken();
  runApp(EinkClockApp(initialRoute: hasAuth ? "/" : "/login"));
}

class EinkClockApp extends StatelessWidget {
  final String initialRoute;
  const EinkClockApp({super.key, this.initialRoute = "/"});

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return ChangeNotifierProvider(
      create: (_) => BleService(),
=======
    return MultiProvider(
      providers: [
<<<<<<< Updated upstream
        // BLE Service — kênh dữ liệu với ESP32
=======
<<<<<<< Updated upstream
        // BLE Service (đã có)
>>>>>>> Stashed changes
        ChangeNotifierProvider(create: (_) => BleService()),
        // SPP Service — wrapper dùng BleService bên trong
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
        ),
        // Market Provider (Clean Architecture mới)
        ChangeNotifierProvider(create: (_) => MarketProvider()),
=======
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
        ),
>>>>>>> Stashed changes
      ],
>>>>>>> 8020cfb (feat: AI Coach fallback chain + rule-based V2 + usage tracking)
      child: MaterialApp(
        title: "AI Productivity Watch",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
<<<<<<< Updated upstream
        initialRoute: initialRoute,
        routes: {
=======
<<<<<<< Updated upstream
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/settings': (_) => const GeneralSettingsScreen(),
          '/interfaces': (_) => const InterfacesScreen(),
          '/design': (_) => const DesignScreen(),
          '/info': (_) => const InfoScreen(),
          '/market': (_) => const MarketScreen(),
          '/schedule': (_) => const WeeklyScheduleScreen(),
=======
        initialRoute: "/",
        routes: {
>>>>>>> Stashed changes
          "/":          (_) => const HomeScreen(),
          "/settings":  (_) => const GeneralSettingsScreen(),
          "/interfaces":(_) => const InterfacesScreen(),
          "/design":    (_) => const DesignScreen(),
          "/info":      (_) => const InfoScreen(),
          "/market":    (_) => const MarketScreen(),
          "/schedule":  (_) => const WeeklyScheduleScreen(),
          "/pomodoro":  (_) => const PomodoroScreen(),
<<<<<<< Updated upstream
          "/clock_mode": (_) => const ClockModeScreen(),
          // Phase 1 - AI Productivity routes
          "/login":     (_) => const LoginScreen(),
          "/ai-hub":    (_) => const AiHubScreen(),
          "/wellbeing":  (_) => const WellbeingScreen(),
=======
          "/clock_mode":(_) => const ClockModeScreen(),
          "/ai-hub":    (_) => const AiHubScreen(),
          "/wellbeing": (_) => const WellbeingScreen(),
          // ==========================================
          // THI_DUA_FEATURE_START (By Gemini)
          // ==========================================
          "/competition": (_) => const CompetitionScreen(),
          // ==========================================
          // THI_DUA_FEATURE_END
          // ==========================================
>>>>>>> Stashed changes
>>>>>>> Stashed changes
        },
      ),
    );
  }
}
