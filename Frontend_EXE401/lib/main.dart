import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "core/bluetooth/ble_service.dart";
import "core/bluetooth/spp_service.dart";
import "core/theme/app_theme.dart";
import "core/theme/app_colors.dart";
import "core/api/api_client.dart";
import "core/api/auth_api.dart";

import "features/home/home_screen.dart";
import "features/general_settings/general_settings_screen.dart";
import "features/interfaces/interfaces_screen.dart";
import "features/design/design_screen.dart";
import "features/info/info_screen.dart";
import "features/market/presentation/screens/market_screen.dart";
import "features/schedule/weekly_schedule_screen.dart";
import "features/pomodoro/pomodoro_screen.dart";
import "features/auth/login_screen.dart";
import "features/ai_hub/ai_hub_screen.dart";
import "features/ai_hub/digital_twin_screen.dart";
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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: AppColors.stitchSurfaceLowest,
      systemNavigationBarDividerColor: AppColors.stitchSurfaceLowest,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  final hasAuth = await AuthApi.verifySession();
  runApp(EinkClockApp(initialRoute: hasAuth ? "/" : "/login"));
}

class EinkClockApp extends StatelessWidget {
  final String initialRoute;
  const EinkClockApp({super.key, this.initialRoute = "/"});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService(), lazy: false),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        navigatorKey: ApiClient.navigatorKey,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: AppColors.stitchSurfaceLowest,
            systemNavigationBarDividerColor: AppColors.stitchSurfaceLowest,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        title: "POMO SMART",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: initialRoute,
        routes: {
          "/": (_) => const HomeScreen(),
          "/settings": (_) => const GeneralSettingsScreen(),
          "/interfaces": (_) => const InterfacesScreen(),
          "/design": (_) => const DesignScreen(),
          "/info": (_) => const InfoScreen(),
          "/market": (_) => const MarketScreen(),
          "/schedule": (_) => const WeeklyScheduleScreen(),
          "/pomodoro": (_) => const PomodoroScreen(),
          "/login": (_) => const LoginScreen(),
          "/ai-hub": (_) => const AiHubScreen(),
          "/digital_twin": (_) => const DigitalTwinScreen(),
          "/clock_mode": (_) => const ClockModeScreen(),
          "/wellbeing": (_) => const WellbeingScreen(),
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
