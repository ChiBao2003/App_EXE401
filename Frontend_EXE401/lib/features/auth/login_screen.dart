import "dart:async";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:google_sign_in/google_sign_in.dart";
import "../../core/auth/google_button_stub.dart"
    if (dart.library.js_interop) "../../core/auth/google_button_web.dart"
    as google_web;
import "package:google_fonts/google_fonts.dart";
import "../../core/api/auth_api.dart";
import "../../core/api/api_client.dart";
import "../../core/auth/google_auth_service.dart";
import "../../core/theme/app_colors.dart";

/// Màn hình Đăng Nhập / Đăng Ký (Authentication & Onboarding)
/// Được trích xuất và ánh xạ 1:1 từ Google Stitch Screen: 182e329559b44a62b4140998e9eeed49
/// Bảo toàn toàn bộ hợp đồng API AuthApi.login() và AuthApi.register().
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmPassC = TextEditingController();
  final _nameC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _googleReady = false;
  String? _googleSetupError;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() => _error = null);
      }
    });
    _initializeGoogle();
  }

  Future<void> _initializeGoogle() async {
    try {
      await GoogleAuthService.initialize();
      if (!mounted) return;
      _googleEvents = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (kIsWeb && event is GoogleSignInAuthenticationEventSignIn) {
            _completeGoogleLogin(event.user);
          }
        },
      );
      setState(() => _googleReady = true);
    } catch (error) {
      if (mounted) {
        setState(() => _googleSetupError = error is StateError
            ? error.message
            : 'Không thể khởi tạo đăng nhập Google.');
      }
    }
  }

  Future<void> _signInGoogle() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      await GoogleAuthService.initialize();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw StateError('Đăng nhập Google chưa được hỗ trợ trên thiết bị này.');
      }
      await GoogleSignIn.instance.signOut();
      final user = await GoogleSignIn.instance.authenticate();
      await _completeGoogleLogin(user);
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = 'Không thể đăng nhập Google. Kiểm tra cấu hình OAuth và thử lại.');
      }
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể đăng nhập Google. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeGoogleLogin(GoogleSignInAccount user) async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final idToken = user.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google không cung cấp ID token.');
      }
      await AuthApi.loginWithGoogle(idToken);
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể kết nối máy chủ. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _googleEvents?.cancel();
    _tab.dispose();
    _emailC.dispose();
    _passC.dispose();
    _confirmPassC.dispose();
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_tab.index == 0) {
        await AuthApi.login(
          email: _emailC.text.trim(),
          password: _passC.text,
        );
      } else {
        await AuthApi.register(
          email: _emailC.text.trim(),
          password: _passC.text,
          displayName: _nameC.text.trim().isNotEmpty
              ? _nameC.text.trim()
              : _emailC.text.trim().split('@')[0],
        );
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/");
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.statusCode == 409
            ? "Email này đã được đăng ký. Vui lòng dùng email khác hoặc đăng nhập."
            : e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Không thể kết nối Backend. Kiểm tra kết nối mạng hoặc máy chủ.");
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _continueAsGuest() {
    Navigator.pushReplacementNamed(context, "/");
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _tab.index == 1;

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: Stack(
        children: [
          // Subtle Ambient Glow Orbs (Design tokens from Stitch Aether Synapse)
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width / 2 - 140,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.25),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 180,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.stitchSecondaryContainer.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.stitchSecondaryContainer.withValues(alpha: 0.15),
                    blurRadius: 90,
                    spreadRadius: 15,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Header & Telemetry Status Beacon
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.stitchSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "POMO SMART v2.5".toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.stitchSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // POMO SMART logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/pomo_smart_mascot.png',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // App Title & Subtitle
                  Text(
                    "POMO SMART",
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stitchOnSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Smart Pomodoro & IoT Watch Companion",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.stitchOutline,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Segmented Auth Pill Switcher (Login / Register)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceLowest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tab.animateTo(0);
                              setState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: !isRegister
                                    ? AppColors.stitchPrimaryContainer
                                    : Colors.transparent,
                                boxShadow: !isRegister
                                    ? [
                                        BoxShadow(
                                          color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.login_rounded,
                                    size: 16,
                                    color: !isRegister
                                        ? AppColors.stitchOnPrimaryContainer
                                        : AppColors.stitchOutline,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Đăng nhập",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: !isRegister
                                          ? AppColors.stitchOnPrimaryContainer
                                          : AppColors.stitchOutline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tab.animateTo(1);
                              setState(() {});
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: isRegister
                                    ? AppColors.stitchPrimaryContainer
                                    : Colors.transparent,
                                boxShadow: isRegister
                                    ? [
                                        BoxShadow(
                                          color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_rounded,
                                    size: 16,
                                    color: isRegister
                                        ? AppColors.stitchOnPrimaryContainer
                                        : AppColors.stitchOutline,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Đăng ký",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isRegister
                                          ? AppColors.stitchOnPrimaryContainer
                                          : AppColors.stitchOutline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Form Bento Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name (Only when Register)
                          if (isRegister) ...[
                            _buildFieldLabel("Họ và tên", isRequired: true),
                            const SizedBox(height: 6),
                            _buildTextInput(
                              controller: _nameC,
                              hintText: "Alex Nguyễn",
                              prefixIcon: Icons.badge_outlined,
                              validator: (v) => isRegister && (v == null || v.trim().length < 2)
                                  ? "Vui lòng nhập ít nhất 2 ký tự"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Field
                          _buildFieldLabel("Tài khoản TFT LCD Cloud ID / Email", isRequired: true),
                          const SizedBox(height: 6),
                          _buildTextInput(
                            controller: _emailC,
                            hintText: "name@TFT LCD-sync.ai",
                            prefixIcon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            suffixWidget: const Tooltip(
                              message: "Đã mã hóa E2E",
                              child: Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.stitchTertiary,
                                size: 18,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return "Vui lòng nhập email";
                              if (!v.contains("@") || !v.contains(".")) return "Email không hợp lệ";
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Password Field
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildFieldLabel("Mật khẩu bảo mật", isRequired: true),
                              if (!isRegister)
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Vui lòng liên hệ quản trị viên để khôi phục mật khẩu."),
                                        backgroundColor: AppColors.stitchSurfaceHigh,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Quên mật khẩu?",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.stitchSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildTextInput(
                            controller: _passC,
                            hintText: "••••••••••••",
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            suffixWidget: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.stitchOutline,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Vui lòng nhập mật khẩu";
                              if (v.length < 6) return "Mật khẩu ít nhất 6 ký tự";
                              return null;
                            },
                          ),

                          if (isRegister) ...[
                            const SizedBox(height: 16),
                            _buildFieldLabel("Xác nhận mật khẩu", isRequired: true),
                            const SizedBox(height: 6),
                            _buildTextInput(
                              controller: _confirmPassC,
                              hintText: "Nhập lại mật khẩu",
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirm,
                              suffixWidget: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.stitchOutline,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return "Vui lòng xác nhận mật khẩu";
                                }
                                if (v != _passC.text) {
                                  return "Mật khẩu xác nhận không khớp";
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Live Hardware Status Widget
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bluetooth_searching_rounded,
                                  color: AppColors.stitchSecondaryContainer,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "TFT LCD Chrono X Sync",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.stitchOnSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.stitchTertiaryContainer.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    "Sẵn sàng kết nối",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.stitchTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Error Banner
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF93000A).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFB4AB).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFFB4AB), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFFB4AB),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Primary Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const StadiumBorder(),
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: _loading ? null : _submit,
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.stitchPrimaryContainer,
                                      Color(0xFF5E35B1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.stitchPrimaryContainer.withValues(alpha: 0.4),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              !isRegister ? "Đăng nhập ngay" : "Tạo tài khoản & Ghép đôi",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Social Auth Divider
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.stitchSurfaceHighest)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  "HOẶC TIẾP TỤC VỚI",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: AppColors.stitchOutline,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: AppColors.stitchSurfaceHighest)),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Web requires the Google Identity Services button.
                          if (kIsWeb)
                            _googleReady
                                ? Center(child: google_web.renderButton())
                                : Text(
                                    _googleSetupError ?? 'Đang tải đăng nhập Google...',
                                    style: const TextStyle(color: AppColors.stitchOutline),
                                  )
                          else
                            Row(children: [
                              _buildSocialButton(
                                label: "Google",
                                icon: Icons.g_mobiledata_rounded,
                                iconColor: Colors.redAccent,
                                onTap: _loading ? () {} : _signInGoogle,
                              ),
                            ]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Ambient TFT LCD Hardware Feature Micro-Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceLow.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.sync_rounded,
                            color: AppColors.stitchSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TFT LCD Low Power Companion",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.stitchOnSurface,
                                ),
                              ),
                              Text(
                                "Đồng bộ Widget AI & To-do 0.02s latency",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.stitchOutline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.battery_charging_full_rounded,
                              color: AppColors.stitchTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "14d",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.stitchOnSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Guest Access Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      backgroundColor: AppColors.stitchSurfaceLow.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _continueAsGuest,
                    icon: const Icon(
                      Icons.sensor_occupied_rounded,
                      size: 16,
                      color: AppColors.stitchOutline,
                    ),
                    label: Text(
                      "Khởi động nhanh với Chế độ Khách (Guest)",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.stitchOutline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Dữ liệu cục bộ được lưu trên đồng hồ và thiết bị của bạn.",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.stitchOutline.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.stitchOutline,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            "*",
            style: TextStyle(
              color: AppColors.stitchSecondaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixWidget,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.stitchSurfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.inter(
          color: AppColors.stitchOnSurface,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            color: AppColors.stitchOutline.withValues(alpha: 0.45),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: AppColors.stitchOutline,
            size: 18,
          ),
          suffixIcon: suffixWidget != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixWidget,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.stitchPrimaryContainer,
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: const Color(0xFFFFB4AB).withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFFFB4AB),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.stitchOnSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
