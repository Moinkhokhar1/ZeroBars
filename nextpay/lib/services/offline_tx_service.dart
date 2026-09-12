// import 'dart:convert';

// import '../models/transaction.dart';
// import '../models/wallet_transaction.dart';
// import '../providers/auth_provider.dart';
// import '../services/api_service.dart';
// import '../services/contact_cache_service.dart';
// import '../services/storage_service.dart';

// /// Loads wallet transactions from the API, local cache, and pending offline queue.
// class OfflineTxService {
//   OfflineTxService._();

//   // ---------------------------------------------------------------------------
//   // Resolve the currently logged-in user's canonical ID.
//   // ---------------------------------------------------------------------------

//   static String? resolveUserId(AuthProvider auth) {
//     final user = auth.user;

//     if (user == null) return null;

//     final walletUserId = user.wallet?.extra['user_id'];

//     if (walletUserId != null &&
//         walletUserId.toString().isNotEmpty) {
//       return walletUserId.toString();
//     }

//     final userIdExtra = user.extra['user_id'];

//     if (userIdExtra != null &&
//         userIdExtra.toString().isNotEmpty) {
//       return userIdExtra.toString();
//     }

//     if (user.id.isNotEmpty) {
//       return user.id;
//     }

//     return null;
//   }

//   // ---------------------------------------------------------------------------
//   // Convert an offline transaction into the common WalletTransaction model.
//   // ---------------------------------------------------------------------------

//   static WalletTransaction fromOfflineTx(
//       OfflineTransaction ot, {
//         String senderName = 'Unknown',
//         String receiverName = 'Unknown',
//         String note = '',
//       }) {
//     return WalletTransaction(
//       id: ot.txId,
//       senderId: ot.sender,
//       receiverId: ot.receiver,
//       senderName: senderName,
//       receiverName: receiverName,
//       amount: ot.amount,
//       isOffline: true,
//       status: ot.status.isNotEmpty
//           ? ot.status
//           : 'Pending',
//       extra: {
//         'created_at':
//         DateTime.fromMillisecondsSinceEpoch(
//           ot.timestamp,
//         ).toUtc().toIso8601String(),
//         'nonce': ot.nonce,
//         if (note.isNotEmpty) 'note': note,
//       },
//     );
//   }

//   // ---------------------------------------------------------------------------
//   // Load pending offline transactions belonging to one account.
//   // ---------------------------------------------------------------------------

//   static Future<List<WalletTransaction>> _pendingForUser(
//       String ownerUserId,
//       ) async {
//     if (ownerUserId.isEmpty) {
//       return [];
//     }

//     final raw = await StorageService.getItem(
//       'pending_transactions_$ownerUserId',
//     );

//     if (raw == null || raw.isEmpty) {
//       return [];
//     }

//     final List<dynamic> list;

//     try {
//       list = jsonDecode(raw) as List<dynamic>;
//     } catch (e) {
//       return [];
//     }

//     final cache = ContactCacheService.instance;

//     final result = <WalletTransaction>[];

//     for (final item in list) {
//       try {
//         final ot =
//         OfflineTransaction.fromJson(
//           Map<String, dynamic>.from(item),
//         );

//         // IMPORTANT:
//         // ContactCacheService now uses account-scoped named arguments.
//         final senderCached = await cache.get(
//           ownerUserId: ownerUserId,
//           userId: ot.sender,
//         );

//         final receiverCached = await cache.get(
//           ownerUserId: ownerUserId,
//           userId: ot.receiver,
//         );

//         result.add(
//           fromOfflineTx(
//             ot,
//             senderName:
//             senderCached?['name']?.isNotEmpty == true
//                 ? senderCached!['name']!
//                 : 'Unknown',
//             receiverName:
//             receiverCached?['name']?.isNotEmpty == true
//                 ? receiverCached!['name']!
//                 : 'Unknown',
//           ),
//         );
//       } catch (e) {
//         // Do not let one malformed pending transaction prevent
//         // the rest of the account's history from loading.
//         continue;
//       }
//     }

//     return result;
//   }

//   // ---------------------------------------------------------------------------
//   // Load all transactions:
//   //
//   // 1. API when online
//   // 2. Account-specific transaction cache when offline
//   // 3. Account-specific pending offline transactions
//   // ---------------------------------------------------------------------------

//   static Future<List<WalletTransaction>> loadAll(
//       AuthProvider auth,
//       ) async {
//     final merged =
//     <String, WalletTransaction>{};

//     final userId =
//     resolveUserId(auth);

//     if (userId == null ||
//         userId.isEmpty) {
//       return [];
//     }

//     final transactionCacheKey =
//         'cached_transactions_$userId';

//     // -------------------------------------------------------------------------
//     // Online API / offline local cache
//     // -------------------------------------------------------------------------

//     try {
//       final response =
//       await ApiService.instance.get(
//         '/wallet/transactions',
//       );

//       final List<dynamic> data =
//       response.data is List
//           ? List<dynamic>.from(response.data)
//           : [];

//       // IMPORTANT:
//       // Cache transactions under the currently logged-in account.
//       await StorageService.setItem(
//         transactionCacheKey,
//         jsonEncode(data),
//       );

//       for (final item in data) {
//         try {
//           final tx =
//           WalletTransaction.fromJson(
//             Map<String, dynamic>.from(item),
//           );

//           merged[tx.id] = tx;
//         } catch (_) {
//           // Ignore malformed individual transactions.
//         }
//       }
//     } catch (_) {
//       // -----------------------------------------------------------------------
//       // Offline fallback
//       // -----------------------------------------------------------------------

//       try {
//         final cached =
//         await StorageService.getItem(
//           transactionCacheKey,
//         );

//         if (cached != null &&
//             cached.isNotEmpty) {
//           final List<dynamic> data =
//           jsonDecode(cached);

//           for (final item in data) {
//             try {
//               final tx =
//               WalletTransaction.fromJson(
//                 Map<String, dynamic>.from(item),
//               );

//               merged[tx.id] = tx;
//             } catch (_) {
//               // Ignore malformed cached transactions.
//             }
//           }
//         }
//       } catch (_) {
//         // No usable local transaction cache.
//       }
//     }

//     // -------------------------------------------------------------------------
//     // Merge pending offline transactions.
//     // -------------------------------------------------------------------------

//     final pending =
//     await _pendingForUser(userId);

//     for (final tx in pending) {
//       merged[tx.id] = tx;
//     }

//     // -------------------------------------------------------------------------
//     // Sort newest first.
//     // -------------------------------------------------------------------------

//     final list =
//     merged.values.toList()
//       ..sort(
//             (a, b) =>
//             b.createdAt.compareTo(
//               a.createdAt,
//             ),
//       );

//     return list;
//   }

//   // ---------------------------------------------------------------------------
//   // Load transactions involving one specific contact.
//   // ---------------------------------------------------------------------------

//   static Future<List<WalletTransaction>> loadForContact(
//       AuthProvider auth,
//       String contactId,
//       ) async {
//     if (contactId.isEmpty) {
//       return [];
//     }

//     final all =
//     await loadAll(auth);

//     final result = all
//         .where(
//           (tx) =>
//       tx.senderId == contactId ||
//           tx.receiverId == contactId,
//     )
//         .toList();

//     result.sort(
//           (a, b) =>
//           a.createdAt.compareTo(
//             b.createdAt,
//           ),
//     );

//     return result;
//   }
// }
import 'dart:convert';
import '../models/transaction.dart';
import '../models/wallet_transaction.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/contact_cache_service.dart';
import '../services/storage_service.dart';

/// Loads wallet transactions from the API, local cache, and pending offline queue.
class OfflineTxService {
  OfflineTxService._();

  static String? resolveUserId(AuthProvider auth) {
    final user = auth.user;
    if (user == null) return null;
    final walletUserId = user.wallet?.extra['user_id'];
    if (walletUserId != null) return walletUserId.toString();
    final userIdExtra = user.extra['user_id'];
    if (userIdExtra != null) return userIdExtra.toString();
    return user.id;
  }

  static WalletTransaction fromOfflineTx(
    OfflineTransaction ot, {
    String senderName = 'Unknown',
    String receiverName = 'Unknown',
    String note = '',
  }) {
    return WalletTransaction(
      id: ot.txId,
      senderId: ot.sender,
      receiverId: ot.receiver,
      senderName: senderName,
      receiverName: receiverName,
      amount: ot.amount,
      isOffline: true,
      status: ot.status.isNotEmpty ? ot.status : 'Pending',
      extra: {
        'created_at':
            DateTime.fromMillisecondsSinceEpoch(ot.timestamp).toUtc().toIso8601String(),
        'nonce': ot.nonce,
        if (note.isNotEmpty) 'note': note,
      },
    );
  }

  static Future<List<WalletTransaction>> _pendingForUser(
      String ownerUserId) async {
    final raw = await StorageService.getItem('pending_transactions_$ownerUserId');
    if (raw == null) return [];

    final List<dynamic> list = jsonDecode(raw);
    final cache = ContactCacheService.instance;
    final result = <WalletTransaction>[];

    for (final item in list) {
      final ot = OfflineTransaction.fromJson(Map<String, dynamic>.from(item));
      final senderCached = await cache.get(ownerUserId, ot.sender);
      final receiverCached = await cache.get(ownerUserId, ot.receiver);
      result.add(fromOfflineTx(
        ot,
        senderName: senderCached?['name'] ?? 'Unknown',
        receiverName: receiverCached?['name'] ?? 'Unknown',
      ));
    }
    return result;
  }

  static Future<List<WalletTransaction>> loadAll(AuthProvider auth) async {
    final merged = <String, WalletTransaction>{};

    // FIX: resolve the current user FIRST and scope the fallback cache key
    // to them. This used to be a single global 'cached_transactions' key
    // shared by every account on the device — so the moment the live API
    // call failed (e.g. no internet), whoever was logged in would see the
    // PREVIOUS account's cached transactions, and by extension their
    // contacts in the People row and contact history.
    final userId = resolveUserId(auth);
    final cacheKey =
        userId != null ? 'cached_transactions_$userId' : 'cached_transactions';

    try {
      final response = await ApiService.instance.get('/wallet/transactions');
      final List<dynamic> data = response.data;
      await StorageService.setItem(cacheKey, jsonEncode(data));
      for (final item in data) {
        final tx = WalletTransaction.fromJson(Map<String, dynamic>.from(item));
        merged[tx.id] = tx;
      }
    } catch (_) {
      final cached = await StorageService.getItem(cacheKey);
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        for (final item in data) {
          final tx =
              WalletTransaction.fromJson(Map<String, dynamic>.from(item));
          merged[tx.id] = tx;
        }
      }
    }

    if (userId != null) {
      for (final tx in await _pendingForUser(userId)) {
        merged[tx.id] = tx;
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<List<WalletTransaction>> loadForContact(
    AuthProvider auth,
    String contactId,
  ) async {
    final all = await loadAll(auth);
    return all
        .where((tx) => tx.senderId == contactId || tx.receiverId == contactId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
}