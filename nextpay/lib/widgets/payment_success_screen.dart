import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../providers/theme_provider.dart';
import 'celebration.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String amount;
  final String receiverName;
  final String transactionId;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.receiverName,
    this.transactionId = '',
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _navigated = false;
  bool _shown = false;

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    // showGeneralDialog needs a Navigator above this widget, so fire it
    // right after the first frame instead of during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebration());
  }

  void _showCelebration() {
    if (_shown || !mounted) return;
    _shown = true;

    final theme = context.read<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);
    const mode = 'Wallet Transfer';
    final isOffline = mode.toLowerCase() == 'offline';

    showPaymentSuccessCelebration(
      context,
      amount: widget.amount,
      receiverName: widget.receiverName,
      transactionId: widget.transactionId.isNotEmpty
          ? widget.transactionId
          : 'TXN${DateTime.now().millisecondsSinceEpoch}',
      mode: mode,
      timestamp: DateTime.now().toLocal().toString(),
      modeColor: isOffline ? c.amber : c.teal,
      modeBgColor: isOffline ? c.amberLight : c.tealLight,
      // No dedicated "success green" in AppColors yet — teal reads as
      // a fine stand-in. Swap in a real field here if you add one.
      accentColor: c.teal,
      onDone: _goHome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);

    // The celebration is a full-screen dialog painted on top of this;
    // this scaffold is only visible for the single frame before it opens.
    return Scaffold(
      backgroundColor: c.bg,
      body: const SizedBox.shrink(),
    );
  }
}