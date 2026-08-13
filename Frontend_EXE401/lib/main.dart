import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/bluetooth/ble_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/general_settings/general_settings_screen.dart';
import 'features/interfaces/interfaces_screen.dart';
import 'features/design/design_screen.dart';
import 'features/info/info_screen.dart';
import 'features/market/market_screen.dart';
import 'features/schedule/weekly_schedule_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const EinkClockApp());
}

class EinkClockApp extends StatelessWidget {
  const EinkClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BleService(),
      child: MaterialApp(
        title: 'Eink Clock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/settings': (_) => const GeneralSettingsScreen(),
          '/interfaces': (_) => const InterfacesScreen(),
          '/design': (_) => const DesignScreen(),
          '/info': (_) => const InfoScreen(),
          '/market': (_) => const MarketScreen(),
          '/schedule': (_) => const WeeklyScheduleScreen(),
        },
      ),
    );
  }
}
