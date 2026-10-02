import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../core/api/auth_api.dart";
import "../../core/api/api_client.dart";

/// Man hinh dang nhap / dang ky.
/// Hien thi khi chua co JWT token hop le.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _emailC = TextEditingController();
  final _passC  = TextEditingController();
  final _nameC  = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailC.dispose();
    _passC.dispose();
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_tab.index == 0) {
        await AuthApi.login(email: _emailC.text.trim(), password: _passC.text);
      } else {
        await AuthApi.register(
          email: _emailC.text.trim(),
          password: _passC.text,
          displayName: _nameC.text.trim(),
        );
      }
      if (mounted) Navigator.pushReplacementNamed(context, "/");
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = "Khong the ket noi Backend. Kiem tra IP trong api_client.dart");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Stack(children: [
        // Background gradient blob
        Positioned(top: -80, right: -60, child: _GlowBlob(color: const Color(0xFF7C4DFF).withOpacity(0.3), size: 280)),
        Positioned(bottom: -60, left: -40, child: _GlowBlob(color: const Color(0xFF00E5FF).withOpacity(0.2), size: 220)),

        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 40),
            // Logo + Title
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                  ),
                ),
                child: const Icon(Icons.watch_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("AI Watch", style: GoogleFonts.outfit(
                  fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white,
                )),
                Text("Productivity Ecosystem", style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFF9E9EC2),
                )),
              ]),
            ]),

            const SizedBox(height: 48),
            Text("Chao mung tro lai!", style: GoogleFonts.outfit(
              fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white,
            )),
            const SizedBox(height: 6),
            Text("Dang nhap de truy cap AI Coach & Pomodoro thich ung.",
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF9E9EC2))),

            const SizedBox(height: 36),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                  ),
                ),
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                unselectedLabelColor: const Color(0xFF9E9EC2),
                labelColor: Colors.white,
                tabs: const [Tab(text: "Dang Nhap"), Tab(text: "Dang Ky")],
              ),
            ),

            const SizedBox(height: 28),

            Form(key: _formKey, child: Column(children: [
              AnimatedBuilder(animation: _tab, builder: (_, __) {
                if (_tab.index == 1) {
                  return _InputField(
                    controller: _nameC,
                    label: "Ten hien thi",
                    icon: Icons.person_outline,
                    validator: (v) => (v?.length ?? 0) < 2 ? "Nhap it nhat 2 ky tu" : null,
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: 16),
              _InputField(
                controller: _emailC,
                label: "Email",
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v?.contains("@") == true) ? null : "Email khong hop le",
              ),
              const SizedBox(height: 16),
              _InputField(
                controller: _passC,
                label: "Mat khau",
                icon: Icons.lock_outline,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                validator: (v) => (v?.length ?? 0) >= 6 ? null : "It nhat 6 ky tu",
              ),
            ])),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Text(_error!, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 28),

            // Submit button
            SizedBox(width: double.infinity, height: 52, child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : AnimatedBuilder(animation: _tab, builder: (_, __) => Text(
                      _tab.index == 0 ? "Dang Nhap" : "Tao Tai Khoan",
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    )),
              ),
            )),

            const SizedBox(height: 24),
            Center(child: Text(
              "Buoc nay can Backend dang chay tai\nhttp://192.168.1.18:8000",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9E9EC2)),
            )),
          ]),
        )),
      ]),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color,
      boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 20)]),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller, required this.label, required this.icon,
    this.obscure = false, this.onToggleObscure, this.validator, this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9E9EC2)),
        prefixIcon: Icon(icon, color: const Color(0xFF7C4DFF), size: 20),
        suffixIcon: onToggleObscure != null
          ? IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF9E9EC2), size: 20),
              onPressed: onToggleObscure,
            )
          : null,
        filled: true,
        fillColor: const Color(0xFF0D0D2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E1E3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E1E3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
