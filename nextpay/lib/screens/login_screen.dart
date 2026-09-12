import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'otp_input_field.dart';
import '../widgets/app_feedback.dart';

// ── Design tokens (matches home_screen.dart) ───────────────────
const _bg = Color(0xFFF7F6F2);
const _surface = Colors.white;
const _textPrimary = Color(0xFF1A1A1A);
const _textSecondary = Color(0xFF6B6B68);
const _border = Color(0xFFE9E7E1);

const _purple = Color(0xFF534AB7);
const _purpleDark = Color(0xFF26215C);

// Accent used specifically for the mobile-number / OTP step, matching the
// updated design.
const _accent = Color(0xFF4A2FCC);
const _accentDark = Color(0xFFBBA4FF);

const _otpLength = 6;
const _resendSeconds = 30;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();

  final OtpInputController _otp = OtpInputController();
  String _otpValue = ''; // kept in sync via the field's onCompleted callback

  bool _otpSent = false;
  bool _isLoading = false;

  Timer? _resendTimer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    return trimmed.startsWith('+') ? trimmed : '+91$trimmed';
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showAlert("Error", "Enter your mobile number");
      return;
    }

    if (phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      _showAlert("Error", "Enter a valid 10-digit mobile number");
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final result = await auth.sendOtp(_normalizePhone(phone));

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result["success"] == true) {
      _otp.clear(); // reset the boxes, refocuses the first one on (re)send
      setState(() {
        _otpSent = true;
        _otpValue = '';
      });
      _startResendTimer();

      final devOtp = result["devOtp"];
      if (devOtp != null) {
        _showAlert("OTP sent (dev mode)", "Your OTP is: $devOtp");
      }
    } else {
      _showAlert("Error", result["message"] ?? "Failed to send OTP");
    }
  }

  Future<void> _handleVerifyOtp({String? otpOverride}) async {
    if (_isLoading) return; // the field auto-submits on fill and the button both call this

    final phone = _phoneController.text.trim();
    final otp = otpOverride ?? _otpValue;

    if (phone.isEmpty || otp.length < _otpLength) {
      _showAlert("Error", "Enter the complete OTP");
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final result = await auth.loginWithOtp(
      _normalizePhone(phone),
      otp,
      // Correct code: mark the boxes green *before* the provider publishes
      // the session. Committing user+token flips the auth gate in
      // main.dart, which disposes this screen.
      beforeCommit: () async => _otp.showSuccess(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result["success"] != true) {
      // Wrong code: red border + shake, then clears and refocuses the row.
      await _otp.shakeError();
      if (!mounted) return;
      setState(() => _otpValue = '');
      _showAlert("Error", result["message"] ?? "Login failed");
      return;
    }

    // Success: auth.user/token are already committed at this point, so
    // AppRoot (main.dart) has already rebuilt to OnboardingGate/HomeScreen
    // internally. If this screen was reached via a pushed route (e.g. from
    // the onboarding intro's "Sign In" link) rather than AppRoot's own
    // inline build, that updated tree is sitting underneath us on the
    // stack and stays invisible until we pop back to it — mirrors
    // RegisterScreen's success handling.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _handleChangeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _secondsLeft = 0;
      _otpValue = '';
    });
    _otp.clear();
  }

  void _showAlert(String title, String message) {
    final isError = title.toLowerCase().contains("error");
    AppDialog.show(
      context,
      title: title,
      message: message,
      type: isError ? AppDialogType.error : AppDialogType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _otpSent ? _buildOtpStep() : _buildPhoneStep(),
        ),
      ),
    );
  }

  // ── STEP 1: Phone number ─────────────────────────────────────
  Widget _buildPhoneStep() {
    return Padding(
      key: const ValueKey('phone-step'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            "Enter your mobile number\nto get started",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            "Mobile Number",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _accentDark),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent, width: 1.4),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  child: Row(
                    children: [
                      Text("🇮🇳", style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        "+91",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: _border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autocorrect: false,
                      enabled: !_isLoading,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary),
                      decoration: const InputDecoration(
                        hintText: "9876543210",
                        hintStyle: TextStyle(color: _textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _primaryButton(
            label: "GET OTP",
            onTap: _handleSendOtp,
            loading: _isLoading,
            color: _accent,
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: _textSecondary),
              children: [
                const TextSpan(text: "By clicking, I accept the "),
                TextSpan(
                  text: "Terms & Conditions",
                  style: const TextStyle(
                      color: _purple, decoration: TextDecoration.underline),
                ),
                const TextSpan(text: " and "),
                TextSpan(
                  text: "Privacy Policy.",
                  style: const TextStyle(
                      color: _purple, decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("New here? ",
                  style: TextStyle(fontSize: 13, color: _textSecondary)),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text(
                  "Create account",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _purpleDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── STEP 2: OTP entry ────────────────────────────────────────
  Widget _buildOtpStep() {
    final phone = _phoneController.text.trim();
    return Padding(
      key: const ValueKey('otp-step'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _isLoading ? null : _handleChangeNumber,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _textPrimary),
            ),
          ),
          const SizedBox(height: 28),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                height: 1.3,
              ),
              children: [
                const TextSpan(text: "Enter the OTP sent to\n"),
                TextSpan(text: "+91 $phone  "),
                TextSpan(
                  text: "(Change)",
                  style: const TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w700,
                      fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OtpInputField(
            length: _otpLength,
            controller: _otp,
            enabled: !_isLoading,
            accent: _accent,
            onCompleted: (otp) {
              setState(() => _otpValue = otp);
              _handleVerifyOtp(otpOverride: otp);
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: _secondsLeft > 0
                ? Text(
              "Didn't receive your OTP? Resend in ${_secondsLeft}s",
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            )
                : GestureDetector(
              onTap: _isLoading ? null : _handleSendOtp,
              child: const Text(
                "Didn't receive your OTP? Resend OTP",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _accent),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _primaryButton(
            label: "LOG IN",
            onTap: () => _handleVerifyOtp(),
            loading: _isLoading,
            enabled: _otpValue.length == _otpLength,
            color: _accent,
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
    bool loading = false,
    bool enabled = true,
    Color color = _purple,
  }) {
    final active = enabled && !loading;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: active ? onTap : null,
          child: Center(
            child: loading
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}