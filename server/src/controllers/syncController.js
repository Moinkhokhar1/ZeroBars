const prisma = require("../config/db");
const crypto = require("crypto");

// Historically this verified against a single hardcoded string
// ("offline-payment-secret") shared by every client install. Since that
// value ships inside the public APK, anyone who decompiled the app could
// extract it and forge a validly "signed" transaction moving funds out of
// *any* user's offline balance — the signature didn't actually prove who
// authorized the transfer.
//
// It now verifies against the sender's own per-user secret (the same
// randomly generated, device-created key already used and synced by the
// SMS payment path — see sms_routes.js / sms_crypto_util.dart). A forged
// transaction now requires the real sender's device-generated secret,
// which the server only has because that specific user's device synced
// it — not a constant readable out of the app package.
function verifySignature(originalPayload, signature, secretKey) {
  const expected = crypto
    .createHash("sha256")
    .update(JSON.stringify(originalPayload) + secretKey)
    .digest("hex");

  const expectedBuf = Buffer.from(expected, "hex");
  const receivedBuf = Buffer.from(String(signature ?? ""), "hex");

  return (
    expectedBuf.length === receivedBuf.length &&
    crypto.timingSafeEqual(expectedBuf, receivedBuf)
  );
}

const syncTransactions = async (req, res) => {
  try {
    const { transactions } = req.body;

    if (!Array.isArray(transactions)) {
      return res.status(400).json({ message: "transactions must be an array" });
    }

    const results = [];

    for (const tx of transactions) {
      if (!tx.sender || !tx.receiver) {
        results.push({ txId: tx.txId, status: "invalid_transaction" });
        continue;
      }

      // Check duplicate tx
      const existingTx = await prisma.transaction.findUnique({ where: { id: tx.txId } });

      if (existingTx) {
        results.push({ txId: tx.txId, status: "duplicate" });
        continue;
      }

      // The signature is only meaningful if it was produced with the
      // claimed sender's own secret key — look that up rather than
      // trusting a shared constant.
      const signer = await prisma.user.findUnique({
        where: { id: tx.sender },
        select: { sms_secret_key: true },
      });

      if (!signer || !signer.sms_secret_key) {
        results.push({ txId: tx.txId, status: "invalid_signature" });
        continue;
      }

      const originalPayload = {
        txId: tx.txId,
        sender: tx.sender,
        receiver: tx.receiver,
        amount: tx.amount,
        timestamp: tx.timestamp,
        nonce: tx.nonce,
        status: tx.status,
        synced: false,
      };

      if (!verifySignature(originalPayload, tx.signature, signer.sms_secret_key)) {
        results.push({ txId: tx.txId, status: "invalid_signature" });
        continue;
      }

      // Fetch sender wallet
      const senderWallet = await prisma.wallet.findUnique({ where: { user_id: tx.sender } });

      if (!senderWallet) {
        results.push({ txId: tx.txId, status: "invalid_transaction" });
        continue;
      }

      // The sender's main `balance` was already debited when they
      // recharged their offline wallet — NOT now. What we're checking
      // here is whether their offline pool actually covers this spend.
      // (It always should, if the client enforced its own cap correctly,
      // but we never trust the client — re-check server-side.)
      if (senderWallet.offline_balance < tx.amount) {
        results.push({ txId: tx.txId, status: "insufficient_offline_balance" });
        continue;
      }

      // Settlement
      await prisma.$transaction([
        prisma.wallet.update({
          where: { user_id: tx.sender },
          data: {
            offline_balance: { decrement: tx.amount },
            locked_balance: { decrement: Math.min(tx.amount, senderWallet.locked_balance) },
          },
        }),
        prisma.wallet.update({
          where: { user_id: tx.receiver },
          data: {
            balance: { increment: tx.amount },
          },
        }),
        prisma.transaction.create({
          data: {
            id: tx.txId,
            sender_id: tx.sender,
            receiver_id: tx.receiver,
            amount: tx.amount,
            status: "completed",
            nonce: tx.nonce,
            signature: tx.signature,
            is_offline: true,
          },
        }),
      ]);

      results.push({ txId: tx.txId, status: "synced" });
    }

    res.status(200).json({ success: true, results });
  } catch (error) {
    console.error("SYNC ERROR:", error);
    res.status(500).json({ message: "Sync failed" });
  }
};

module.exports = { syncTransactions };
