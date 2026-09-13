import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../sms_payment/sms_key_sync_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

// ── Design tokens (matches home_screen.dart / login_screen.dart) ─
const _bg = Color(0xFFF7F6F2);
const _surface = Colors.white;
const _textPrimary = Color(0xFF1A1A1A);
const _textSecondary = Color(0xFF6B6B68);
const _border = Color(0xFFE9E7E1);

const _purple = Color(0xFF534AB7);
const _purpleDark = Color(0xFF26215C);
const _purpleLight = Color(0xFFEEEDFE);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      _showAlert("Error", "All fields required");
      return;
    }

    if (phone.length < 10) {
      _showAlert("Error", "Enter valid phone number");
      return;
    }

    if (password.length < 8) {
      _showAlert("Error", "Password must be at least 8 characters");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final normalized = phone.startsWith('+') ? phone : '+91$phone';

      final result = await auth.register(name, email, password, normalized);

      if (!mounted) return;

      if (result["success"] != true) {
        _showAlert("Error", result["message"] ?? "Registration failed");
        return;
      }
      await SmsKeySyncService.syncIfNeeded();

      if (!mounted) return;

      await _showAlert("Success", "Account created!");

      if (!mounted) return;

      // Pop register screen; AppRoot now shows the PIN setup flow first
      // (new account, no PIN yet), then HomeScreen once that's done.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAlert(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // BRAND
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/icon/app_icon.png', // 👈 update this path
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "ZeroBars",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Create your account",
                      style: TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // FORM CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Create account",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Set up your wallet in seconds",
                            style:
                            TextStyle(fontSize: 13, color: _textSecondary),
                          ),
                          const SizedBox(height: 22),

                          _fieldLabel("Full name"),
                          _inputField(
                            icon: Icons.person_outline_rounded,
                            controller: _nameController,
                            hint: "Your full name",
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel("Email"),
                          _inputField(
                            icon: Icons.mail_outline_rounded,
                            controller: _emailController,
                            hint: "you@email.com",
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel("Phone"),
                          _inputField(
                            icon: Icons.smartphone_outlined,
                            controller: _phoneController,
                            hint: "10-digit mobile number",
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          const SizedBox(height: 16),

                          _fieldLabel("Password"),
                          _inputField(
                            icon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            hint: "Min 8 characters",
                            obscure: !_showPassword,
                            trailing: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                child: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // REGISTER BUTTON
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isLoading ? null : _handleRegister,
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Create account",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // DIVIDER
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: _border, thickness: 1)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "or",
                            style: TextStyle(
                                fontSize: 12, color: _textSecondary),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: _border, thickness: 1)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // LOGIN LINK
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _purpleLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Center(
                            child: Text(
                              "Already have an account",
                              style: TextStyle(
                                color: _purpleDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                "© 2025 Built by moinworksonlocalhost",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textSecondary,
        ),
      ),
    );
  }

  Widget _inputField({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(icon, size: 18, color: _textSecondary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              autocorrect: false,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
