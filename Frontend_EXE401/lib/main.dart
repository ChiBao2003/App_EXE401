import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "core/bluetooth/ble_service.dart";
import "core/bluetooth/spp_service.dart";
import "core/theme/app_theme.dart";
import "core/api/api_client.dart";

import "features/home/home_screen.dart";
import "features/general_settings/general_settings_screen.dart";
import "features/interfaces/interfaces_screen.dart";
import "features/design/design_screen.dart";
import "features/info/info_screen.dart";
import "features/market/market_screen.dart";
import "features/schedule/weekly_schedule_screen.dart";
import "features/pomodoro/pomodoro_screen.dart";
import "features/auth/login_screen.dart";
import "features/ai_hub/ai_hub_screen.dart";
import "features/clock_mode/clock_mode_screen.dart";
import "features/digital_wellbeing/wellbeing_screen.dart";
// ==========================================
// THI_DUA_FEATURE_START (By Gemini)
// ==========================================
import "features/competition/competition_screen.dart";
// ==========================================
// THI_DUA_FEATURE_END
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final hasAuth = await ApiClient.hasToken();
  runApp(EinkClockApp(initialRoute: hasAuth ? "/" : "/login"));
}

class EinkClockApp extends StatelessWidget {
  final String initialRoute;
  const EinkClockApp({super.key, this.initialRoute = "/"});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
        ),
      ],
      child: MaterialApp(
        title: "AI Productivity Watch",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: initialRoute,
        routes: {
          "/":            (_) => const HomeScreen(),
          "/settings":    (_) => const GeneralSettingsScreen(),
          "/interfaces":  (_) => const InterfacesScreen(),
          "/design":      (_) => const DesignScreen(),
          "/info":        (_) => const InfoScreen(),
          "/market":      (_) => const MarketScreen(),
          "/schedule":    (_) => const WeeklyScheduleScreen(),
          "/pomodoro":    (_) => const PomodoroScreen(),
          "/login":       (_) => const LoginScreen(),
          "/ai-hub":      (_) => const AiHubScreen(),
          "/clock_mode":  (_) => const ClockModeScreen(),
          "/wellbeing":   (_) => const WellbeingScreen(),
          // ==========================================
          // THI_DUA_FEATURE_START (By Gemini)
          // ==========================================
          "/competition": (_) => const CompetitionScreen(),
          // ==========================================
          // THI_DUA_FEATURE_END
          // ==========================================
        },
      ),
    );
  }
}
