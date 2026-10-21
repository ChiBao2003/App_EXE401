import 'package:flutter/material.dart';
import '../general_settings/general_settings_screen.dart';

/// InfoScreen — Đã hợp nhất vào GeneralSettingsScreen theo thiết kế Google Stitch Screen 10:
/// "General Settings & Firmware OTA" (Design System: Aether Synapse).
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GeneralSettingsScreen();
  }
}
