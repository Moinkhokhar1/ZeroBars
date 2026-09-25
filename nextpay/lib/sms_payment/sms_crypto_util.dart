import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../services/api_service.dart';

/// Handles HMAC signing and verification for SMS payment payloads.
class SmsCryptoUtil {
  static const _secretKeyPref = 'sms_secret_key';

  /// Returns the stored secret key, or generates one on first run.
  static Future<String> getOrCreateSecretKey({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    String? key = prefs.getString(_secretKeyPref);
    if (key == null) {
      key = _generateRandomKey(32);
      await prefs.setString(_secretKeyPref, key);

      // ── Sync to backend so gateway can verify HMAC ──────────
      // NOTE: this must hit the authenticated sync route, not the
      // internal gateway-only lookup route — this was previously
      // posting to '/users/sms-key' (no such route exists; that path
      // is GET-only and requires the internal gateway API key), so
      // this sync silently 404'd and only SmsKeySyncService.syncIfNeeded()
      // (called after login) was actually persisting the key.
      if (userId != null) {
        try {
          await ApiService.instance.post('/users/sync-sms-key', data: {
            'secretKey': key,
          });
        } catch (e) {
          debugPrint('SMS KEY SYNC FAILED: $e');
          // Key is saved locally — will retry next time
        }
      }
    }
    return key;
  }

  /// Generates a cryptographically random hex key.
  static String _generateRandomKey(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Builds and signs the SMS payload.
  /// Format: PAY#senderId#receiverId#amount#timestamp#hmac
  static Future<String> buildPayload({
    required String senderId,
    required String receiverId,
    required double amount,
  }) async {
    final secretKey = await getOrCreateSecretKey(userId: senderId); // ← pass userId
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final amountStr = amount.toStringAsFixed(2);
    final raw = '$senderId:$receiverId:$amountStr:$timestamp';
    final hmac = _sign(raw, secretKey);
    return 'PAY#$senderId#$receiverId#$amountStr#$timestamp#$hmac';
  }

  /// Verifies an incoming payload. Returns parsed fields or null if invalid.
  static Future<Map<String, dynamic>?> verifyPayload(String sms) async {
    try {
      if (!sms.startsWith('PAY#')) return null;
      final parts = sms.split('#');
      if (parts.length != 6) return null;

      final senderId = parts[1];
      final receiverId = parts[2];
      final amount = parts[3];
      final timestamp = int.parse(parts[4]);
      final receivedHmac = parts[5];

      // Reject if older than 120 seconds (replay protection)
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if ((now - timestamp).abs() > 120) return null;

      final secretKey = await getOrCreateSecretKey();
      final raw = '$senderId:$receiverId:$amount:$timestamp';
      final expectedHmac = _sign(raw, secretKey);
      if (expectedHmac != receivedHmac) return null;

      return {
        'senderId': senderId,
        'receiverId': receiverId,
        'amount': double.parse(amount),
        'timestamp': timestamp,
      };
    } catch (_) {
      return null;
    }
  }

  // Must produce a 32-hex-char (128-bit) HMAC — the gateway
  // (gateway/gateway.js, processPaymentSms) computes and compares against
  // .substring(0, 32). This used to truncate to 16 hex chars (64-bit)
  // here, which didn't match the gateway's expected length: every
  // Buffer.from(...) comparison there would fail length-equality before
  // even reaching timingSafeEqual, so gateway-routed SMS payments were
  // always rejected as an invalid signature. Keep both sides at the same
  // length if this ever changes again.
  static String _sign(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(dataBytes).toString().substring(0, 32);
  }
}