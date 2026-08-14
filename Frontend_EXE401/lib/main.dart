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

// Clean Architecture: Import từ đúng presentation layer
import 'features/market/presentation/screens/market_screen.dart';
import 'features/market/presentation/providers/market_provider.dart';

import 'features/schedule/weekly_schedule_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MultiProvider(
      providers: [
        // BLE Service (đã có)
        ChangeNotifierProvider(create: (_) => BleService()),
        // Market Provider (Clean Architecture mới)
        ChangeNotifierProvider(create: (_) => MarketProvider()),
      ],
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
