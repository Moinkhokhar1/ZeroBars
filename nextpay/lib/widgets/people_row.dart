import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../app_colors.dart';
import '../models/wallet_transaction.dart';
import '../services/offline_tx_service.dart';
import '../services/contact_cache_service.dart';
import '../screens/contact_history_screen.dart';

class PeopleRow extends StatefulWidget {
  const PeopleRow({super.key});

  @override
  PeopleRowState createState() => PeopleRowState();
}

class PeopleRowState extends State<PeopleRow> {
  List<_Person> _people = [];
  bool _loading = true;
  bool _expanded = false;

  static const _palette = [
    Color(0xFF4E342E),
    Color(0xFFD6336C),
    Color(0xFF1565C0),
    Color(0xFFD84315),
    Color(0xFF00695C),
    Color(0xFF6A1B9A),
    Color(0xFF2E7D32),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Call after a payment so the most-recent contact moves to the front.
  void refresh() => _load();

  String? _resolveUserId(AuthProvider auth) {
    final user = auth.user;
    if (user == null) return null;
    final walletUserId = user.wallet?.extra['user_id'];
    if (walletUserId != null) return walletUserId.toString();
    final userIdExtra = user.extra['user_id'];
    if (userIdExtra != null) return userIdExtra.toString();
    return user.id;
  }

  String _nameFromTx(WalletTransaction tx, bool isReceiver) {
    final direct = isReceiver ? tx.receiverName : tx.senderName;
    if (direct.isNotEmpty && direct != 'Unknown') return direct;

    final extra = tx.extra;
    final fromExtra = isReceiver
        ? (extra['receiver_name'] ?? extra['receiverName'])
        : (extra['sender_name'] ?? extra['senderName']);
    if (fromExtra != null && fromExtra.toString().isNotEmpty) {
      return fromExtra.toString();
    }
    return '';
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final currentUserId = _resolveUserId(auth);
      if (currentUserId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final txs = await OfflineTxService.loadAll(auth);

      final cache = ContactCacheService.instance;
      final seen = <String>{};
      final people = <_Person>[];

      for (final tx in txs) {
        String contactId;
        String apiName;
        String phone = '';

        if (tx.senderId == currentUserId) {
          contactId = tx.receiverId;
          apiName = _nameFromTx(tx, true);
          phone = tx.extra['receiver_phone']?.toString() ??
              tx.extra['receiverPhone']?.toString() ??
              '';
        } else if (tx.receiverId == currentUserId) {
          contactId = tx.senderId;
          apiName = _nameFromTx(tx, false);
          phone = tx.extra['sender_phone']?.toString() ??
              tx.extra['senderPhone']?.toString() ??
              '';
        } else {
          continue;
        }

        if (seen.contains(contactId)) continue;
        seen.add(contactId);

        final cached = await cache.get(currentUserId, contactId);
        final name = (apiName.isNotEmpty && apiName != 'Unknown')
            ? apiName
            : (cached?['name']?.isNotEmpty == true
            ? cached!['name']!
            : 'User ${contactId.substring(contactId.length - 4)}');

        final resolvedPhone =
        phone.isNotEmpty ? phone : (cached?['phone'] ?? '');

        if (name.isNotEmpty && name != 'Unknown' && !name.startsWith('User ')) {
          await cache.save(
            ownerUserId: currentUserId,
            userId: contactId,
            name: name,
            phone: resolvedPhone,
          );
        }

        people.add(_Person(
          id: contactId,
          name: name,
          phone: resolvedPhone,
        ));
      }

      for (final contact in await cache.getAllContacts(currentUserId)) {
        final id = contact['userId'] ?? '';
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        people.add(_Person(
          id: id,
          name: contact['name']?.isNotEmpty == true
              ? contact['name']!
              : 'User ${id.substring(id.length - 4)}',
          phone: contact['phone'] ?? '',
        ));
      }

      if (mounted) setState(() => _people = people);
    } catch (e) {
      debugPrint("PEOPLE ROW ERROR: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _colorFor(String id) => _palette[id.hashCode.abs() % _palette.length];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = AppColors(isDark: theme.isDark);

    if (_loading) {
      return const SizedBox(height: 110);
    }

    final visiblePeople = _expanded ? _people : _people.take(4).toList();

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'People',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 16,
                children: [
                  for (final p in visiblePeople)
                    _PersonItem(
                      c: c,
                      label: p.name,
                      photoUrl: p.photoUrl,
                      initials: _initials(p.name),
                      avatarColor: _colorFor(p.id),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContactHistoryScreen(
                              contactId: p.id,
                              contactName: p.name,
                              contactPhone: p.phone,
                              contactPhotoUrl: p.photoUrl,
                            ),
                          ),
                        );
                        refresh();
                      },
                    ),
                  if (!_expanded && _people.length > 3)
                    _PersonItem(
                      c: c,
                      label: 'More',
                      icon: Icons.keyboard_arrow_down_rounded,
                      bg: Colors.transparent,
                      fg: c.textSecondary,
                      outlined: true,
                      onTap: () => setState(() => _expanded = true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Person {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  _Person({
    required this.id,
    required this.name,
    this.phone = '',
    this.photoUrl,
  });
}

class _PersonItem extends StatelessWidget {
  final AppColors c;
  final String label;
  final String? photoUrl;
  final String? initials;
  final Color? avatarColor;
  final IconData? icon;
  final Color? bg;
  final Color? fg;
  final bool outlined;
  final bool hasNotification;
  final VoidCallback onTap;

  const _PersonItem({
    required this.c,
    required this.label,
    required this.onTap,
    this.photoUrl,
    this.initials,
    this.avatarColor,
    this.icon,
    this.bg,
    this.fg,
    this.outlined = false,
    this.hasNotification = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: photoUrl != null
                        ? Colors.transparent
                        : (avatarColor ?? bg ?? c.purpleLight),
                    border: outlined
                        ? Border.all(color: c.border, width: 1.5)
                        : null,
                    image: photoUrl != null
                        ? DecorationImage(
                      image: NetworkImage(photoUrl!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: photoUrl != null
                      ? null
                      : (icon != null
                      ? Icon(icon, size: 24, color: fg ?? c.purple)
                      : Text(
                    initials ?? '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )),
                ),
                if (hasNotification)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.blue,
                        border: Border.all(color: c.bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}