import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../sms_payment/sms_crypto_util.dart';

/// Signs offline P2P transactions.
///
/// IMPORTANT: this used to sign with a single hardcoded string shared by
/// every install of the app (`offline-payment-secret`). Because that
/// value ships inside the public APK, anyone who decompiled the app could
/// extract it and forge a validly "signed" transaction moving funds out
/// of *any* user's offline balance — the signature proved nothing about
/// who actually authorized the transfer.
///
/// Signing now uses the same per-user, randomly generated secret that the
/// SMS payment path already establishes and syncs to the server via
/// `SmsCryptoUtil` (see server/src/routes/sms_routes.js — POST
/// /users/sync-sms-key). The server verifies against that same per-user
/// key (see server/src/controllers/syncController.js), so a forged
/// transaction now requires the actual sender's device-generated secret,
/// not a constant anyone can read out of the app package.
num normalizeTxAmount(dynamic amount) {
  final n = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
  return n % 1 == 0 ? n.toInt() : n;
}

Map<String, dynamic> buildSigningPayload({
  required String txId,
  required String sender,
  required String receiver,
  required dynamic amount,
  required int timestamp,
  required int nonce,
  String status = 'pending',
}) {
  return {
    'txId': txId,
    'sender': sender,
    'receiver': receiver,
    'amount': normalizeTxAmount(amount),
    'timestamp': timestamp,
    'nonce': nonce,
    'status': status,
    'synced': false,
  };
}

/// Signs with the given sender's per-user secret key. `senderId` must be
/// the transaction's `sender` field — the signature is only meaningful as
/// proof that *that* user's device produced it.
Future<String> signPayloadMap(
  Map<String, dynamic> payloadMap, {
  required String senderId,
}) async {
  final secretKey = await SmsCryptoUtil.getOrCreateSecretKey(userId: senderId);
  final payload = jsonEncode(payloadMap);
  return sha256.convert(utf8.encode(payload + secretKey)).toString();
}

Future<String> signTransaction(Map<String, dynamic> tx) {
  final sender = tx['sender'].toString();
  return signPayloadMap(
    buildSigningPayload(
      txId: tx['txId'] as String,
      sender: sender,
      receiver: tx['receiver'].toString(),
      amount: tx['amount'],
      timestamp: tx['timestamp'] as int,
      nonce: tx['nonce'] as int,
      status: (tx['status'] as String?) ?? 'pending',
    ),
    senderId: sender,
  );
}
