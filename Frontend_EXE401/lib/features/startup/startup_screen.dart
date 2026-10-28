import 'package:flutter/material.dart';

import '../../core/api/auth_api.dart';
import '../../core/theme/app_colors.dart';

/// Draws the first frame immediately while the saved login is checked.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key, this.verifySession});

  final Future<bool> Function()? verifySession;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _openInitialPage();
  }

  Future<void> _openInitialPage() async {
    bool hasSession;
    try {
      hasSession = await (widget.verifySession ?? AuthApi.verifySession)();
    } catch (_) {
      hasSession = false;
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(hasSession ? '/' : '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 56,
              color: AppColors.stitchPrimary,
            ),
            SizedBox(height: 16),
            Text(
              'POMO SMART',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.stitchPrimary),
          ],
        ),
      ),
    );
  }
}
