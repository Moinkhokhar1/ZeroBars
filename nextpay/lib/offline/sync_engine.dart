import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'tx_signing.dart';
import 'wallet_engine.dart';

class SyncEngine {
  final AuthProvider authProvider;
  final WalletEngine walletEngine;

  SyncEngine(this.authProvider, this.walletEngine);

  Future<void> _waitForHydration() async {
    if (authProvider.hydrated) return;
    final completer = Completer<void>();
    void listener() {
      if (authProvider.hydrated) {
        authProvider.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }
    authProvider.addListener(listener);
    Timer(const Duration(seconds: 4), () {
      authProvider.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  // Resolves the correct sender ID — same logic as TransactionEngine
  // TransactionEngine uses wallet.extra['user_id'] as senderId
  String? _resolveSenderId() {
    final user = authProvider.user;
    if (user == null) return null;

    // Priority 1: wallet user_id (same as TransactionEngine uses)
    final walletUserId = user.wallet?.extra['user_id'];
    if (walletUserId != null) return walletUserId.toString();

    // Priority 2: user.id
    return user.id;
  }

  Future<Map<String, dynamic>> syncPendingTransactions() async {
    try {
      await _waitForHydration();

      // Use same ID resolution as TransactionEngine to find the right key
      final senderId = _resolveSenderId();

      if (senderId == null) {
        return {"success": false, "message": "User not found"};
      }

      // This must match the key used in TransactionEngine:
      // "pending_transactions_$senderId"
      final storageKey = "pending_transactions_$senderId";

      debugPrint("SYNC STORAGE KEY: $storageKey");

      final data = await StorageService.getItem(storageKey);
      final List<dynamic> transactions = data != null ? jsonDecode(data) : [];

      debugPrint("SYNC TXS COUNT: ${transactions.length}");

      if (transactions.isEmpty) {
        return {"success": false, "message": "No pending transactions"};
      }

      // Re-sign with the server-compatible SHA256 scheme so older pending
      // txs (e.g. signed with Ed25519) can still sync after a client update.
      final resignedTransactions = <Map<String, dynamic>>[];
      for (final tx in transactions) {
        final map = Map<String, dynamic>.from(tx as Map);
        map['signature'] = await signTransaction(map);
        resignedTransactions.add(map);
      }

      await StorageService.setItem(storageKey, jsonEncode(resignedTransactions));

      final response = await ApiService.instance.post(
        "/sync/transactions",
        data: {"transactions": resignedTransactions},
      );

      debugPrint("SYNC RESPONSE: ${response.data}");

      final results = response.data["results"] as List<dynamic>;

      final syncedTxIds = results
          .where((tx) => tx["status"] == "synced")
          .map((tx) => tx["txId"] as String)
          .toList();

      debugPrint("SYNCED TX IDs: $syncedTxIds");

      if (syncedTxIds.isNotEmpty) {
        final syncedTransactions = resignedTransactions
            .where((tx) => syncedTxIds.contains(tx["txId"]))
            .toList();

        // Unlock balance for each synced transaction
        for (final tx in syncedTransactions) {
          final amount = num.tryParse(tx["amount"].toString()) ?? 0;
          debugPrint("UNLOCKING FOR TX: ${tx['txId']} AMOUNT: $amount");
          await walletEngine.unlockBalance(amount);
        }

        final remainingTransactions = resignedTransactions
            .where((tx) => !syncedTxIds.contains(tx["txId"]))
            .toList();

        if (remainingTransactions.isEmpty) {
          await StorageService.removeItem(storageKey);
          await StorageService.removeItem("local_wallet");
          debugPrint("All transactions synced — storage cleared");
        } else {
          await StorageService.setItem(storageKey, jsonEncode(remainingTransactions));
        }
      }

      return {"success": true, "data": response.data};
    } catch (error) {
      debugPrint("SYNC FULL ERROR: $error");
      return {"success": false, "message": "Sync failed"};
    }
  }
}