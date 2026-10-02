import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/bluetooth/spp_service.dart';
import '../../core/theme/app_theme.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Pomodoro ESP32',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<SppService>(
        builder: (context, spp, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // -- Card: Tr?ng thái k?t n?i ----------------------
                _buildConnectionCard(context, spp),
                const SizedBox(height: 20),

                // -- Card: Phiên Pomodoro g?n nh?t -----------------
                if (spp.lastSession != null)
                  _buildSessionCard(spp.lastSession!),
                if (spp.lastSession != null) const SizedBox(height: 20),

                // -- Card: AI Feedback ------------------------------
                if (spp.lastFeedback.isNotEmpty)
                  _buildFeedbackCard(spp),
              ],
            ),
          );
        },
      ),
    );
  }

  // -- Connection Card ----------------------------------------
  Widget _buildConnectionCard(BuildContext context, SppService spp) {
    final Color statusColor = switch (spp.state) {
      SppState.connected => const Color(0xFF4CAF50),
      SppState.connecting || SppState.scanning => const Color(0xFFFFB300),
      SppState.disconnected => const Color(0xFF757575),
    };

    final IconData statusIcon = switch (spp.state) {
      SppState.connected => Icons.bluetooth_connected,
      SppState.connecting || SppState.scanning => Icons.bluetooth_searching,
      SppState.disconnected => Icons.bluetooth_disabled,
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.15),
            const Color(0xFF1A1A2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          // Icon Bluetooth v?i pulse animation khi dang k?t n?i
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              final scale = spp.state == SppState.scanning
                  ? 1.0 + _pulseController.value * 0.1
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: Icon(statusIcon, size: 64, color: statusColor),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            spp.statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: statusColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Nút K?t n?i / Ng?t k?t n?i
          if (spp.state == SppState.disconnected)
            _buildButton(
              label: 'K?t n?i ESP32',
              icon: Icons.bluetooth,
              color: const Color(0xFF2196F3),
              onTap: () => context.read<SppService>().connectToEsp32(),
            )
          else if (spp.state == SppState.scanning ||
              spp.state == SppState.connecting)
            const CircularProgressIndicator(color: Color(0xFFFFB300))
          else
            _buildButton(
              label: 'Ng?t k?t n?i',
              icon: Icons.bluetooth_disabled,
              color: const Color(0xFFF44336),
              onTap: () => context.read<SppService>().disconnect(),
            ),

          // Hu?ng d?n ghép dôi
          if (spp.state == SppState.disconnected) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ghép dôi Bluetooth v?i "ESP32_Pomodoro_Data" trong Settings di?n tho?i tru?c.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -- Session Card ------------------------------------------
  Widget _buildSessionCard(PomodoroSessionData session) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Phiên v?a hoàn thành',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: session.completed
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  session.completed ? '? Hoàn thành' : '?? D?ng s?m',
                  style: TextStyle(
                    color: session.completed ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow('?? Th?i gian làm', '${session.workMin} phút'),
          _buildStatRow('? Ngh?', '${session.breakMin} phút'),
          _buildStatRow('?? S? l?n pause', '${session.pauses} l?n'),
          _buildStatRow('?? Phiên s?', '#${session.session}'),
          _buildStatRow(
            '?? Nh?n lúc',
            '${session.receivedAt.hour}:${session.receivedAt.minute.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // -- Feedback Card -----------------------------------------
  Widget _buildFeedbackCard(SppService spp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Color(0xFF82B1FF), size: 22),
              SizedBox(width: 8),
              Text(
                'AI Phân Tích',
                style: TextStyle(
                  color: Color(0xFF82B1FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (spp.isSyncing)
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF82B1FF),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Ðang phân tích...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            Text(
              spp.lastFeedback,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  // -- Button ------------------------------------------------
  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
