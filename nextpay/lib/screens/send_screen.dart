import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../app_colors.dart';
import '../services/api_service.dart';
import '../services/contact_cache_service.dart';
import 'contact_history_screen.dart';
import 'scanner_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../offline/transaction_engine.dart';
import '../offline/wallet_engine.dart';
import '../sms_payment/sms_payment_service.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/app_feedback.dart';

// ─── Success Modal ─────────────────────────────────────────────────────────
class SuccessModal extends StatefulWidget {
  final bool visible;
  final String amount;
  final String successReceiver;
  final String transactionId;
  final String mode;
  final String timestamp;
  final VoidCallback onDone;
  final AppColors c;

  const SuccessModal({
    Key? key,
    required this.visible,
    required this.amount,
    required this.successReceiver,
    required this.transactionId,
    required this.mode,
    required this.timestamp,
    required this.onDone,
    required this.c,
  }) : super(key: key);

  @override
  State<SuccessModal> createState() => _SuccessModalState();
}

class _SuccessModalState extends State<SuccessModal>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late AnimationController _amountController;
  late AnimationController _subtitleController;
  late AnimationController _rippleController;
  late AnimationController _particleController;

  late Animation<double> _checkAnim;
  late Animation<double> _amountAnim;
  late Animation<double> _subtitleAnim;
  late Animation<double> _particleAnim;

  final AudioPlayer _player = AudioPlayer();

  List<Color> get particleColors => [
    widget.c.teal,
    widget.c.purple,
    widget.c.purpleLight,
    widget.c.textPrimary,
    widget.c.textSecondary,
    widget.c.teal,
    widget.c.purple,
    Colors.white,
  ];

  final List<double> particleAngles = [0, 45, 90, 135, 180, 225, 270, 315];

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _checkController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _amountController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _subtitleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _rippleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _particleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _checkAnim =
        CurvedAnimation(parent: _checkController, curve: Curves.easeOut);
    _amountAnim =
        CurvedAnimation(parent: _amountController, curve: Curves.elasticOut);
    _subtitleAnim =
        CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn);
    _particleAnim =
        CurvedAnimation(parent: _particleController, curve: Curves.easeOut);

    if (widget.visible) _startAnimations();
  }

  void _startAnimations() {
    HapticFeedback.heavyImpact();
    _player.play(AssetSource('sounds/success.mp3'));
    Future.delayed(const Duration(milliseconds: 300),
            () => mounted ? HapticFeedback.mediumImpact() : null);
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200),
            () => mounted ? _checkController.forward() : null);
    Future.delayed(const Duration(milliseconds: 300),
            () => mounted ? _particleController.forward() : null);
    Future.delayed(const Duration(milliseconds: 500),
            () => mounted ? _amountController.forward() : null);
    Future.delayed(const Duration(milliseconds: 700),
            () => mounted ? _subtitleController.forward() : null);
  }

  void _resetAnimations() {
    _scaleController.reset();
    _checkController.reset();
    _amountController.reset();
    _subtitleController.reset();
    _particleController.reset();
  }

  @override
  void didUpdateWidget(SuccessModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _resetAnimations();
      _startAnimations();
    } else if (!widget.visible && oldWidget.visible) {
      _resetAnimations();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _scaleController.dispose();
    _checkController.dispose();
    _amountController.dispose();
    _subtitleController.dispose();
    _rippleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Widget _detailRow(String label, String value) {
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: c.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final c = widget.c;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleController,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ...List.generate(3, (i) {
                      return AnimatedBuilder(
                        animation: _rippleController,
                        builder: (_, __) {
                          final offset = i * 0.33;
                          final value =
                              (_rippleController.value + offset) % 1.0;
                          final opacity = value < 0.3
                              ? value / 0.3 * 0.35
                              : (1 - value) / 0.7 * 0.35;
                          return Transform.scale(
                            scale: 0.6 + value * 1.6,
                            child: Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: c.teal, width: 2.5),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    ...List.generate(8, (i) {
                      final angle = particleAngles[i] * pi / 180;
                      const distance = 60.0;
                      return AnimatedBuilder(
                        animation: _particleAnim,
                        builder: (_, __) {
                          final v = _particleAnim.value;
                          return Transform.translate(
                            offset: Offset(
                              cos(angle) * distance * v,
                              sin(angle) * distance * v,
                            ),
                            child: Opacity(
                              opacity: v < 0.5 ? v * 2 : (1 - v) * 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: particleColors[i],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    ScaleTransition(
                      scale: _checkAnim,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: c.successBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded,
                            color: c.successText, size: 40),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 0.4), end: Offset.zero)
                    .animate(_amountController),
                child: FadeTransition(
                  opacity: _amountController,
                  child: Text(
                    '₹${widget.amount}',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FadeTransition(
                opacity: _subtitleAnim,
                child: Column(
                  children: [
                    Text('Payment Successful',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.successText)),
                    const SizedBox(height: 4),
                    Text('To: ${widget.successReceiver}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.textSecondary)),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('TIME', widget.timestamp),
                          const SizedBox(height: 10),
                          _detailRow('TXN ID', widget.transactionId),
                          const SizedBox(height: 10),
                          _detailRow('MODE', widget.mode.toUpperCase()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _subtitleAnim,
                child: SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: c.purple,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: widget.onDone,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('Done',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
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
    );
  }
}

// ─── Send Screen ───────────────────────────────────────────────────────────
class SendScreen extends StatefulWidget {
  final String? receiverId;
  final String? receiverName;
  final String? scannedReceiverId;
  final String? scannedAmount;

  const SendScreen({
    super.key,
    this.receiverId,
    this.receiverName,
    this.scannedReceiverId,
    this.scannedAmount,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Map<String, dynamic>? _selectedUser;
  bool _searchingUser = false;
  String? _receiverId;

  // Minimum transfer amount allowed. Keeping this as a named constant
  // means SendScreen and any other place that validates an amount
  // (e.g. ContactHistoryScreen, ScannerScreen) can reference the same
  // value instead of hardcoding "1" in multiple places.
  static const double kMinTransferAmount = 1.0;

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  bool _showSuccess = false;
  String _successAmount = '';
  String _successReceiver = '';
  String? _confirmationQR;
  String _successTxnId = '';
  String _successMode = '';
  DateTime? _successTimestamp;
  double _balance = 0.0;
  double _lockedBalance = 0.0;
  bool _balanceLoading = true;

  double get availableBalance => _balance - _lockedBalance;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _loadWallet();
    if (widget.receiverId != null) {
      _receiverId = widget.receiverId;

      _selectedUser = {
        "id": widget.receiverId ?? '',
        "name": widget.receiverName ?? "Unknown",
      };
    } else if (widget.scannedReceiverId != null) {
      _mobileController.text = widget.scannedReceiverId!;
    }
    if (widget.scannedAmount != null) {
      _amountController.text = widget.scannedAmount!;
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    final auth = context.read<AuthProvider>();
    try {
      final response = await ApiService.instance.get("/wallet/");
      _safeSetState(() {
        _balance =
            double.tryParse(response.data['balance']?.toString() ?? '0') ??
                0.0;
        _lockedBalance = double.tryParse(
            response.data['locked_balance']?.toString() ?? '0') ??
            0.0;
        _balanceLoading = false;
      });
    } on DioException catch (e) {
      debugPrint("WALLET LOAD OFFLINE (DioException: ${e.type}): $e");
      final wallet = auth.user?.wallet;
      _safeSetState(() {
        _balance = (wallet?.balance ?? 0).toDouble();
        _lockedBalance = (wallet?.lockedBalance ?? 0).toDouble();
        _balanceLoading = false;
      });
    } catch (e) {
      debugPrint("WALLET LOAD ERROR (unexpected): $e");
      final wallet = auth.user?.wallet;
      _safeSetState(() {
        _balance = (wallet?.balance ?? 0).toDouble();
        _lockedBalance = (wallet?.lockedBalance ?? 0).toDouble();
        _balanceLoading = false;
      });
    }
  }

  Future<void> _handleSend() async {
    final receiverId = _receiverId;
    final amountText = _amountController.text.trim();
    if (receiverId == null || amountText.isEmpty) {
      AppSnack.show(context, 'All fields required', type: AppSnackType.error);
      return;
    }
    final numericAmount = double.tryParse(amountText);
    if (numericAmount == null || numericAmount <= 0) {
      AppSnack.show(context, 'Invalid amount', type: AppSnackType.error);
      return;
    }
    if (numericAmount < kMinTransferAmount) {
      AppSnack.show(
        context,
        'Minimum amount is ₹${kMinTransferAmount.toStringAsFixed(0)}',
        type: AppSnackType.error,
      );
      return;
    }
    if (numericAmount > availableBalance) {
      AppSnack.show(context, 'Insufficient balance', type: AppSnackType.error);
      return;
    }
    final auth = context.read<AuthProvider>();
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((r) => r != ConnectivityResult.none);

    if (isOnline) {
      try {
        final response =
        await ApiService.instance.post("/wallet/transfer", data: {
          "receiverId": receiverId,
          "amount": numericAmount,
        });
        if (response.data['success'] == true) {
          if (mounted) FocusScope.of(context).unfocus();
          final smsResult = await SmsPaymentService.instance.sendPayment(
            senderId: auth.user?.wallet?.extra['user_id']?.toString() ??
                auth.user?.id ??
                '',
            receiverId: receiverId,
            amount: numericAmount,
          );
          debugPrint(smsResult.success
              ? 'SMS SENT: ${smsResult.payload}'
              : 'SMS FAILED: ${smsResult.message}');
          _safeSetState(() {
            _successAmount = numericAmount.toStringAsFixed(2);
            _successReceiver = response.data['receiverName'] ?? receiverId;
            _successTxnId =
                response.data['transactionId']?.toString() ?? '-';
            _successMode = 'Online';
            _successTimestamp = response.data['createdAt'] != null
                ? DateTime.parse(response.data['createdAt']).toLocal()
                : DateTime.now();
            _showSuccess = true;
          });
          await auth.fetchWallet();
          await _loadWallet();
        } else {
          if (mounted) {
            AppSnack.show(
              context,
              response.data['message'] ?? 'Transfer failed',
              type: AppSnackType.error,
            );
          }
        }
      } on DioException catch (e) {
        debugPrint("ONLINE SEND DioException (${e.type}): $e");
        if (mounted) {
          AppSnack.show(
            context,
            'Connection lost. Saving as offline transaction...',
            type: AppSnackType.info,
          );
        }
        await _doOfflineSend(auth, receiverId, numericAmount);
      } catch (e) {
        debugPrint("ONLINE SEND ERROR (unexpected): $e");
        if (mounted) {
          AppSnack.show(context, 'Transfer failed. Try again.', type: AppSnackType.error);
        }
      }
    } else {
      await _doOfflineSend(auth, receiverId, numericAmount);
    }
  }

  Future<void> _openContactProfile({
    required String userId,
    required String userName,
    required String userPhone,
  }) async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactHistoryScreen(
          contactId: userId,
          contactName: userName,
          contactPhone: userPhone,
          popOnPaymentSuccess: true,
        ),
      ),
    );

    if (paid == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  String _resolveUserId(AuthProvider auth) {
    final user = auth.user;

    if (user == null) return '';

    final walletUserId = user.wallet?.extra['user_id'];
    if (walletUserId != null) {
      return walletUserId.toString();
    }

    final userIdExtra = user.extra['user_id'];
    if (userIdExtra != null) {
      return userIdExtra.toString();
    }

    return user.id;
  }


  Future<void> _findUserByMobile() async {
    final input = _mobileController.text.trim();

    final auth = context.read<AuthProvider>();
    final ownerUserId = _resolveUserId(auth);

    if (ownerUserId.isEmpty) {
      AppSnack.show(
        context,
        'User session not found. Please login again.',
        type: AppSnackType.error,
      );
      return;
    }

    if (input.isEmpty) {
      AppSnack.show(context, 'Enter mobile number', type: AppSnackType.error);
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
    connectivity.any((r) => r != ConnectivityResult.none);

    setState(() => _searchingUser = true);

    try {
      if (isOnline) {
        final response = await ApiService.instance.get(
          '/auth/users/by-phone/$input',
        );

        final user = Map<String, dynamic>.from(response.data);
        final userId = user['id']?.toString() ?? '';
        final userName = user['name']?.toString() ?? 'Unknown';
        final userPhone = user['phone']?.toString() ?? input;

        await ContactCacheService.instance.save(
          ownerUserId: ownerUserId,
          userId: userId,
          name: userName,
          phone: userPhone,
        );

        if (!mounted) return;
        await _openContactProfile(
          userId: userId,
          userName: userName,
          userPhone: userPhone,
        );
        return;
      }

      // Offline: look up previously saved contact by phone.
      final cached = await ContactCacheService.instance.findByPhone(
        ownerUserId: ownerUserId,
        phone: input,
      );
      if (cached != null && cached['userId']?.isNotEmpty == true) {
        if (!mounted) return;
        await _openContactProfile(
          userId: cached['userId']!,
          userName: cached['name']?.isNotEmpty == true
              ? cached['name']!
              : 'Contact',
          userPhone: cached['phone']?.isNotEmpty == true
              ? cached['phone']!
              : input,
        );
        return;
      }

      // Legacy offline path: input is the receiver wallet / user ID directly.
      final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
      final looksLikePhone = digitsOnly.length >= 10 && digitsOnly.length <= 13;
      if (looksLikePhone) {
        if (mounted) {
          AppSnack.show(
            context,
            'Contact not saved offline. Connect once while online, '
                'or enter the receiver wallet ID.',
            type: AppSnackType.error,
          );
        }
        return;
      }

      if (!mounted) return;
      await _openContactProfile(
        userId: input,
        userName: 'Offline Receiver',
        userPhone: '',
      );

      if (mounted) {
        AppSnack.show(
          context,
          'Offline mode: using wallet ID as receiver.',
          type: AppSnackType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnack.show(context, 'User not found', type: AppSnackType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _searchingUser = false);
      }
    }
  }

  Future<void> _doOfflineSend(
      AuthProvider auth, String receiverId, double numericAmount) async {
    try {
      final walletEngine = WalletEngine(auth);
      final txEngine = TransactionEngine(auth, walletEngine);
      final senderId = auth.user?.wallet?.extra['user_id']?.toString() ??
          auth.user?.id ??
          '';
      if (senderId.isEmpty) {
        if (mounted) {
          AppSnack.show(
            context,
            'User not found. Please login again.',
            type: AppSnackType.error,
          );
        }
        return;
      }
      final result = await txEngine.createOfflineTransaction(
        senderId: senderId,
        receiverId: receiverId,
        amount: numericAmount,
        senderName: auth.user?.name,
      );
      if (result['success'] == true) {
        if (mounted) FocusScope.of(context).unfocus();
        await _loadWallet();
        _safeSetState(() {
          _successAmount = numericAmount.toStringAsFixed(2);
          _successReceiver = receiverId;
          _successTxnId = result['transactionId']?.toString() ??
              result['id']?.toString() ??
              '-';
          _successMode = 'Offline';
          _successTimestamp = DateTime.now();
          _showSuccess = true;
        });
      } else {
        if (mounted) {
          AppSnack.show(
            context,
            result['message'] ?? 'Offline transaction failed',
            type: AppSnackType.error,
          );
        }
      }
    } catch (e) {
      debugPrint("OFFLINE SEND ERROR: $e");
      if (mounted) {
        AppSnack.show(context, 'Something went wrong', type: AppSnackType.error);
      }
    }
  }

  Widget _buildField({
    required AppColors c,
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool autocorrect = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: c.purpleLight,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
                child: Icon(prefixIcon, color: c.purple, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  autocorrect: autocorrect,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: c.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header ───────────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await context.read<AuthProvider>().fetchWallet();
                            if (mounted) Navigator.pop(context, true);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(12),
                              border:
                              Border.all(color: c.border, width: 1),
                            ),
                            child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 16,
                                color: c.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Send Money',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary)),
                              Text('Transfer funds instantly',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ScannerScreen())),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.purpleLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.qr_code_scanner_rounded,
                                size: 20, color: c.purple),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Scrollable content ──────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        // Balance car

                        const SizedBox(height: 20),

                        // Form card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(20),
                            border:
                            Border.all(color: c.border, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildField(
                                c: c,
                                label: 'Mobile Number',
                                hint: 'Enter mobile number',
                                controller: _mobileController,
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Offline banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.amberLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: c.amber.withOpacity(0.3),
                                width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: c.amber, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'If you\'re offline, the transaction will be saved locally and synced when internet is restored.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: c.amber,
                                      height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ── Pinned Go button ──────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    keyboardOpen ? 12 : 24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: c.purple,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _findUserByMobile, // changed here
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _searchingUser
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _searchingUser ? 'Searching...' : 'Go',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Success Modal ─────────────────────────────────────────
            if (_showSuccess)
              MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(viewInsets: EdgeInsets.zero),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: SuccessModal(
                      visible: _showSuccess,
                      amount: _successAmount,
                      successReceiver: _successReceiver,
                      transactionId: _successTxnId,
                      mode: _successMode,
                      timestamp: _successTimestamp != null
                          ? _formatTime(_successTimestamp!)
                          : '-',
                      onDone: () async {
                        setState(() => _showSuccess = false);

                        // update provider first
                        await context.read<AuthProvider>().fetchWallet();

                        if (mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                      c: c,
                    ),
                  ),
                ),
              ),

            // ── Offline QR Modal ──────────────────────────────────────
            if (_confirmationQR != null)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Payment Sent',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Ask vendor to scan this QR',
                            style: TextStyle(
                                fontSize: 13, color: c.textSecondary)),
                        const SizedBox(height: 20),
                        Text('₹${_amountController.text}',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: c.teal)),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: c.purple,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() => _confirmationQR = null);
                                Navigator.pop(context);
                              },
                              child: const Padding(
                                padding:
                                EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text('Done',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
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
    );
  }
}