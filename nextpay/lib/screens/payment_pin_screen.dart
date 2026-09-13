import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../app_colors.dart';
import '../services/app_lock_service.dart';
import '../widgets/forgot_pin_flow.dart';

const _pinLength = 6;

/// ZeroBars payment PIN gate — reuses the same PIN / biometric the user set
/// during app onboarding. Returns `true` when verified, `false` on cancel.
class PaymentPinScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const PaymentPinScreen({
    super.key,
    this.title = 'Enter ZeroBars PIN',
    this.subtitle = 'Confirm your payment with your 6-digit PIN',
  });

  /// Shows the PIN sheet and returns whether verification succeeded.
  static Future<bool> confirm(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PaymentPinScreen(),
      ),
    );
    return result == true;
  }

  @override
  State<PaymentPinScreen> createState() => _PaymentPinScreenState();
}

class _PaymentPinScreenState extends State<PaymentPinScreen>
    with SingleTickerProviderStateMixin {
  String _input = '';
  String? _error;
  bool _bioAvailable = false;
  bool _checking = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometrics());
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await AppLockService.instance.isBiometricEnabled();
    final canUse = await AppLockService.instance.canUseBiometrics();
    if (!mounted) return;
    if (enabled && canUse) {
      setState(() => _bioAvailable = true);
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await AppLockService.instance.authenticateWithBiometrics();
    if (ok && mounted) Navigator.pop(context, true);
  }

  void _onDigit(String d) {
    if (_input.length >= _pinLength || _checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _input += d;
      _error = null;
    });
    if (_input.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 120), _submit);
    }
  }

  void _onBackspace() {
    if (_input.isEmpty || _checking) return;
    HapticFeedback.lightImpact();
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _onClear() {
    if (_checking) return;
    HapticFeedback.mediumImpact();
    setState(() => _input = '');
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final ok = await AppLockService.instance.verifyPin(_input);
    if (!mounted) return;

    if (ok) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context, true);
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _input = '';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: c.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.purpleLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded, size: 32, color: c.purple),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _input.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 18 : 16,
                    height: filled ? 18 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? c.purple : Colors.transparent,
                      border: Border.all(
                        color: filled ? c.purple : c.border,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _error != null ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: c.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 14, color: c.dangerText),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _error ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.dangerText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: row
                            .map((d) => _DigitKey(
                                  digit: d,
                                  onTap: () => _onDigit(d),
                                  c: c,
                                ))
                            .toList(),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _bioAvailable
                          ? _IconKey(
                              icon: Icons.fingerprint,
                              onTap: _tryBiometric,
                              c: c,
                              color: c.purple,
                            )
                          : const SizedBox(width: 80, height: 72),
                      _DigitKey(digit: '0', onTap: () => _onDigit('0'), c: c),
                      _IconKey(
                        icon: Icons.backspace_outlined,
                        onTap: _onBackspace,
                        onLongPress: _onClear,
                        c: c,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: _checking ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verifying…',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed:
                  _checking ? null : () => showForgotPinFlow(context, popToRoot: true),
              child: Text(
                'Forgot PIN?',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.purple),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  final AppColors c;
  const _DigitKey({required this.digit, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) => _KeyBase(
        onTap: onTap,
        c: c,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
      );
}

class _IconKey extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final AppColors c;
  final Color? color;
  const _IconKey({
    required this.icon,
    required this.onTap,
    required this.c,
    this.onLongPress,
    this.color,
  });

  @override
  Widget build(BuildContext context) => _KeyBase(
        onTap: onTap,
        onLongPress: onLongPress,
        c: c,
        transparent: true,
        child: Icon(icon, size: 26, color: color ?? c.textPrimary),
      );
}

class _KeyBase extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final AppColors c;
  final bool transparent;
  const _KeyBase({
    required this.child,
    required this.onTap,
    required this.c,
    this.onLongPress,
    this.transparent = false,
  });

  @override
  State<_KeyBase> createState() => _KeyBaseState();
}

class _KeyBaseState extends State<_KeyBase> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 80,
        height: 72,
        decoration: BoxDecoration(
          color: widget.transparent
              ? Colors.transparent
              : _pressed
                  ? widget.c.purpleLight
                  : widget.c.surface,
          borderRadius: BorderRadius.circular(16),
          border: widget.transparent
              ? null
              : Border.all(
                  color: _pressed ? widget.c.purple : widget.c.border,
                  width: 1,
                ),
        ),
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
