import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../app_colors.dart';
import '../services/app_lock_service.dart';
import '../widgets/app_feedback.dart';

/// Shown after PIN is set. Asks the user if they want to enable biometrics.
/// Calls [onDone] either way — biometric choice is optional.
class BiometricPromptScreen extends StatefulWidget {
  final VoidCallback onDone;
  const BiometricPromptScreen({super.key, required this.onDone});

  @override
  State<BiometricPromptScreen> createState() => _BiometricPromptScreenState();
}

class _BiometricPromptScreenState extends State<BiometricPromptScreen> {
  bool _loading = false;
  bool _canUseBio = false;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  Future<void> _checkBio() async {
    final ok = await AppLockService.instance.canUseBiometrics();
    if (mounted) setState(() => _canUseBio = ok);
  }

  Future<void> _enableBio() async {
    setState(() => _loading = true);
    // Trigger a biometric prompt so the user confirms it works
    final ok = await AppLockService.instance.authenticateWithBiometrics();
    if (!mounted) return;
    if (ok) {
      await AppLockService.instance.setBiometricEnabled(true);
      widget.onDone();
    } else {
      setState(() => _loading = false);
      AppSnack.show(
        context,
        'Biometric auth failed — try again or skip',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _skip() async {
    await AppLockService.instance.setBiometricEnabled(false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Icon ──────────────────────────────────────────────
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: c.purpleLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fingerprint, size: 44, color: c.purple),
              ),

              const SizedBox(height: 28),

              Text(
                'Enable Biometrics?',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary),
              ),

              const SizedBox(height: 12),

              Text(
                _canUseBio
                    ? 'Use Face ID or fingerprint to unlock the app instantly instead of typing your PIN every time.'
                    : 'Your device doesn\'t support biometric authentication, or none are enrolled in settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
              ),

              const Spacer(flex: 2),

              // ── Buttons ───────────────────────────────────────────
              if (_canUseBio) ...[
                _PrimaryButton(
                  label: _loading ? 'Enabling…' : 'Enable Biometrics',
                  icon: _loading ? null : Icons.fingerprint,
                  loading: _loading,
                  onTap: _loading ? null : _enableBio,
                  c: c,
                ),
                const SizedBox(height: 14),
              ],

              _SecondaryButton(
                label: _canUseBio ? 'Skip for now' : 'Continue with PIN',
                onTap: _loading ? null : _skip,
                c: c,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable button widgets ───────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;
  final AppColors c;

  const _PrimaryButton({
    required this.label,
    required this.c,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: onTap != null ? c.purple : c.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child:
                CircularProgressIndicator(strokeWidth: 2, color: c.surface),
              )
            else if (icon != null)
              Icon(icon, size: 18, color: c.surface),
            if (!loading && icon != null) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.surface),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppColors c;

  const _SecondaryButton(
      {required this.label, required this.c, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textSecondary),
        ),
      ),
    );
  }
}