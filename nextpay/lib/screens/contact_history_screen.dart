import 'package:flutter/material.dart';
import 'package:zerobars/screens/payment_sheet_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../app_colors.dart';
import '../models/wallet_transaction.dart';
import '../models/chat_message.dart';
import '../services/offline_tx_service.dart';
import '../services/message_service.dart';
import 'transaction_detail_screen.dart';
import '../widgets/app_feedback.dart';

/// A single entry in the merged chat + payment timeline.
class _TimelineEntry {
  final DateTime createdAt;
  final WalletTransaction? tx;
  final ChatMessage? message;

  _TimelineEntry.tx(this.tx)
      : createdAt = tx!.createdAt,
        message = null;

  _TimelineEntry.message(this.message)
      : createdAt = message!.createdAt,
        tx = null;
}

class ContactHistoryScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String contactPhone;
  final String? contactPhotoUrl;
  final bool popOnPaymentSuccess;

  const ContactHistoryScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    this.contactPhotoUrl,
    this.popOnPaymentSuccess = false,
  });

  @override
  State<ContactHistoryScreen> createState() => _ContactHistoryScreenState();
}

class _ContactHistoryScreenState extends State<ContactHistoryScreen> {
  List<WalletTransaction> _transactions = [];
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<_TimelineEntry> get _timeline {
    final entries = [
      ..._transactions.map(_TimelineEntry.tx),
      ..._messages.map(_TimelineEntry.message),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final results = await Future.wait([
        OfflineTxService.loadForContact(auth, widget.contactId),
        MessageService.loadThread(widget.contactId),
      ]);

      if (!mounted) return;
      setState(() {
        _transactions = results[0] as List<WalletTransaction>;
        _messages = results[1] as List<ChatMessage>;
      });
      if (_timeline.isNotEmpty) _scrollToLatest();
    } catch (e) {
      debugPrint('CONTACT HISTORY ERROR: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      final sent = await MessageService.send(
        receiverId: widget.contactId,
        content: text,
      );
      if (!mounted) return;
      setState(() => _messages = [..._messages, sent]);
      _scrollToLatest();
    } catch (e) {
      debugPrint('SEND MESSAGE ERROR: $e');
      if (!mounted) return;
      _messageController.text = text;
      AppSnack.show(
        context,
        "Couldn't send message. Try again.",
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _Header(c: c, widget: widget),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.purple))
                : _timeline.isEmpty
                ? Center(
              child: Text('No messages or transactions yet',
                  style: TextStyle(color: c.textSecondary)),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: _timeline.length,
              itemBuilder: (context, index) {
                final entry = _timeline[index];
                final prev = index > 0 ? _timeline[index - 1] : null;
                final showDivider = prev == null ||
                    !_isSameDay(prev.createdAt, entry.createdAt);

                final Widget bubble;
                if (entry.tx != null) {
                  final tx = entry.tx!;
                  // Contact sent to you → left; you sent to contact → right
                  final isReceived = tx.senderId == widget.contactId;
                  bubble = _TxBubble(
                    tx: tx,
                    isReceived: isReceived,
                    contactName: widget.contactName,
                    contactPhone: widget.contactPhone,
                    c: c,
                  );
                } else {
                  final msg = entry.message!;
                  final isReceived = msg.senderId == widget.contactId;
                  bubble = _MessageBubble(
                    message: msg,
                    isReceived: isReceived,
                    c: c,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDivider)
                      _DateDivider(date: entry.createdAt, c: c),
                    bubble,
                  ],
                );
              },
            ),
          ),
          _BottomBar(
            c: c,
            controller: _messageController,
              onPay: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentSheetScreen(
                      receiverId: widget.contactId,
                      receiverName: widget.contactName,
                      receiverPhone: widget.contactPhone,
                    ),
                  ),
                );

                if (result == true && mounted) {
                  await _load();
                  _scrollToLatest();
                  if (widget.popOnPaymentSuccess) {
                    Navigator.pop(context, true);
                  }
                }
              },
            onSend: _sendMessage,
            sending: _sending,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AppColors c;
  final ContactHistoryScreen widget;
  const _Header({required this.c, required this.widget});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: c.purpleLight,
              backgroundImage: widget.contactPhotoUrl != null
                  ? NetworkImage(widget.contactPhotoUrl!)
                  : null,
              child: widget.contactPhotoUrl == null
                  ? Icon(Icons.person, color: c.purple)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contactName,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text(widget.contactPhone,
                      style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.call_outlined, color: c.textSecondary),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: c.textSecondary),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  final AppColors c;
  const _DateDivider({required this.date, required this.c});

  String _label() {
    const weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final weekday = weekdays[date.weekday - 1];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'pm' : 'am';
    return '$weekday, $hour:$minute$ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_label(),
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ),
          Expanded(child: Divider(color: c.border)),
        ],
      ),
    );
  }
}

// ── Transaction bubble ────────────────────────────────────────────────────────

class _TxBubble extends StatelessWidget {
  final WalletTransaction tx;
  final bool isReceived;
  final String contactName;
  final String contactPhone;
  final AppColors c;
  const _TxBubble({
    required this.tx,
    required this.isReceived,
    required this.contactName,
    required this.contactPhone,
    required this.c,
  });

  // String _displayName(String fromTx) =>
  //     (fromTx.isNotEmpty && fromTx != 'Unknown') ? fromTx : contactName;
  String _displayName(String fromTx) {
    if (fromTx.isEmpty ||
        fromTx == 'Unknown' ||
        fromTx.startsWith('User ')) {
      return contactName;
    }
    return fromTx;
  }

  @override
  Widget build(BuildContext context) {
    final otherName = isReceived
        ? _displayName(tx.senderName)
        : _displayName(tx.receiverName);
    final title =
        isReceived ? 'Payment from $otherName' : 'Payment to $otherName';
    final amount = '${isReceived ? '+' : '-'}₹${tx.amount.toStringAsFixed(0)}';
    final amountColor = isReceived ? c.teal : c.textPrimary;

    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransactionDetailScreen(
                    tx: tx,
                    isReceived: isReceived,
                    personName: contactName,
                    personPhone: contactPhone,
                  ),
                ),
              );
            },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isReceived ? c.tealLight : c.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isReceived ? 4 : 18),
                bottomRight: Radius.circular(isReceived ? 18 : 4),
              ),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
                const SizedBox(height: 10),
                Text(amount,
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, color: amountColor)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: c.teal),
                    const SizedBox(width: 6),
                    Text('${tx.status} • ${_shortDate(tx.createdAt)}',
                        style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    if (!isReceived) ...[
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: c.textSecondary),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ── Chat message bubble ────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isReceived;
  final AppColors c;
  const _MessageBubble({
    required this.message,
    required this.isReceived,
    required this.c,
  });

  String _time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute$ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isReceived ? c.surface : c.purpleLight,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isReceived ? 4 : 16),
              bottomRight: Radius.circular(isReceived ? 16 : 4),
            ),
            border: Border.all(color: c.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.content,
                  style: TextStyle(fontSize: 14, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text(_time(message.createdAt),
                  style: TextStyle(fontSize: 10, color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom bar: Pay + message ────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final AppColors c;
  final TextEditingController controller;
  final VoidCallback onPay;
  final VoidCallback onSend;
  final bool sending;

  const _BottomBar({
    required this.c,
    required this.controller,
    required this.onPay,
    required this.onSend,
    this.sending = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            ElevatedButton(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.purpleLight,
                foregroundColor: c.purple,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: TextStyle(color: c.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: c.textSecondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.purple,
                              ),
                            )
                          : Icon(Icons.send_rounded, color: c.purple),
                      onPressed: sending ? null : onSend,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}