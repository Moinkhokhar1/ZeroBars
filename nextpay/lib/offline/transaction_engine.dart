import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import 'tx_signing.dart';
import 'wallet_engine.dart';

/// Mirrors offline/transactionEngine.js — SHA256 signing must match
/// server/src/controllers/syncController.js exactly.
///
/// IMPORTANT: the offline_balance/lock check in WalletEngine is a
/// client-side UX guard only. The server MUST independently re-derive
/// the sender's real offline_balance at sync time and reject anything
/// that doesn't reconcile — never trust the client's claimed balance
/// for settlement.
///
/// The spending ceiling here comes from WalletEngine, which checks
/// against `offlineBalance` — real money the user explicitly moved out
/// of their main balance via a server-side recharge (see
/// rechargeOfflineWallet on the server, and the "Offline wallet" section
/// in ProfileScreen on the client). That's what makes this a real fix
/// rather than just a self-declared limit: the server already knows
/// about and has debited that money before any offline spend happens.
class TransactionEngine {
  final AuthProvider authProvider;
  final WalletEngine walletEngine;
  static const _uuid = Uuid();
  final FlutterTts _tts = FlutterTts();

  TransactionEngine(this.authProvider, this.walletEngine);

  Future<void> _announcePayment(num amount, String? senderName) async {
    final hindiText = senderName != null
        ? "$senderName se $amount rupaye prapt huye"
        : "$amount rupaye prapt huye";
    final englishText = senderName != null
        ? "$senderName has sent you $amount rupees"
        : "You have received $amount rupees";

    await _tts.setLanguage("hi-IN");
    await _tts.setPitch(1.05);
    await _tts.setSpeechRate(0.92);
    await _tts.speak(hindiText);

    await _tts.setLanguage("en-IN");
    await _tts.speak(englishText);

    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 200);
    }
  }

  /// Cryptographically random nonce — NOT a timestamp. A timestamp is
  /// predictable and reusable; this prevents an attacker from crafting
  /// a plausible-looking replayed payload with an adjusted clock value.
  int _secureNonce() {
    final rand = Random.secure();
    return rand.nextInt(1 << 31) * 2 + rand.nextInt(2);
  }

  Future<Map<String, dynamic>> createOfflineTransaction({
    required String senderId,
    required String receiverId,
    required num amount,
    String? senderName,
  }) async {
    // Client-side UX guard only — NOT the source of truth. Server
    // re-validates the real offline_balance independently at sync time.
    final lockResult = await walletEngine.lockBalance(amount);

    if (lockResult["success"] != true) {
      return {
        "success": false,
        "message": lockResult["message"],
      };
    }

    try {
      final nonce = _secureNonce();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      var transaction = OfflineTransaction(
        txId: _uuid.v4(),
        sender: senderId,
        receiver: receiverId,
        amount: amount,
        timestamp: timestamp,
        nonce: nonce,
        status: "pending",
        synced: false,
      );

      final payloadMap = buildSigningPayload(
        txId: transaction.txId,
        sender: transaction.sender,
        receiver: transaction.receiver,
        amount: transaction.amount,
        timestamp: transaction.timestamp,
        nonce: transaction.nonce,
        status: transaction.status,
      );
      final signature = await signPayloadMap(payloadMap, senderId: senderId);

      transaction = transaction.copyWith(signature: signature);

      if (kDebugMode) {
        debugPrint("TX PAYLOAD (debug only): ${jsonEncode(payloadMap)}");
        debugPrint("TX SIGNATURE (debug only): $signature");
      }

      final storageKey = "pending_transactions_$senderId";
      final existingRaw = await StorageService.getItem(storageKey);
      final List<dynamic> existing =
      existingRaw != null ? jsonDecode(existingRaw) : [];

      existing.add(transaction.toJson());
      await StorageService.setItem(storageKey, jsonEncode(existing));

      final user = authProvider.user;
      if (transaction.receiver == user?.id) {
        await _announcePayment(amount, senderName);
      }

      return {
        "success": true,
        "transaction": transaction,
      };
    } catch (error) {
      // Roll back the local lock if transaction creation failed after
      // the lock succeeded, so funds aren't stuck "locked" forever.
      await walletEngine.unlockBalance(amount);
      if (kDebugMode) {
        debugPrint("TX ERROR: $error");
      }
      return {
        "success": false,
        "message": "Transaction failed",
      };
    }
  }
}