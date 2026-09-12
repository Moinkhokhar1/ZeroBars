require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const twilio = require('twilio');
const axios = require('axios');
const crypto = require('crypto');
const Redis = require('ioredis');

const app = express();
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);
const GATEWAY_NUMBER = process.env.TWILIO_PHONE_NUMBER;
const BACKEND_URL = process.env.BACKEND_API_URL;
const BACKEND_KEY = process.env.BACKEND_API_KEY;
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL;

if (!PUBLIC_BASE_URL) {
  console.error('FATAL: PUBLIC_BASE_URL is not set — Twilio signature verification cannot work without it.');
  process.exit(1);
}

// ─── Redis-backed nonce store (replaces in-memory Set) ────────
const redis = new Redis(process.env.REDIS_URL);
redis.on('error', (err) => console.error('[REDIS ERROR]', err.message));

/**
 * Atomically claims a nonce. Returns true if this is the first time we've
 * seen it (caller should proceed), false if it's a duplicate (caller should
 * reject). SET ... NX is atomic at the Redis level, so two near-simultaneous
 * webhook deliveries for the same nonce cannot both succeed.
 */
async function claimNonce(nonce) {
  const key = `sms:nonce:${nonce}`;
  const result = await redis.set(key, '1', 'EX', 300, 'NX'); // 5 min TTL
  return result === 'OK';
}

// ─── Twilio signature verification middleware ─────────────────
function verifyTwilioSignature(req, res, next) {
  const signature = req.headers['x-twilio-signature'];
  const url = `${PUBLIC_BASE_URL}${req.originalUrl}`;

  const valid =
    !!signature &&
    twilio.validateRequest(process.env.TWILIO_AUTH_TOKEN, signature, url, req.body);

  if (!valid) {
    console.warn(`[SMS] Rejected request with invalid/missing Twilio signature from ${req.ip}`);
    return res.status(403).send('<Response></Response>');
  }
  next();
}

// ─── Main SMS webhook ─────────────────────────────────────────
app.post('/sms/incoming', verifyTwilioSignature, async (req, res) => {
  const from = req.body.From || '';   // sender's phone number
  const body = (req.body.Body || '').trim();

  console.log(`[SMS] From: ${from} | Body: ${body}`);

  // Only process PAY# messages
  if (!body.startsWith('PAY#')) {
    return res.status(200).send('<Response></Response>');
  }

  try {
    const result = await processPaymentSms(from, body);

    if (result.success) {
      // Send confirmation to receiver
      await sendSms(result.receiverPhone, `PAY_CONFIRM#${result.amount}#${result.senderName}`);
      // Send receipt to sender
      await sendSms(from, `RECEIPT#Payment of Rs.${result.amount} sent to ${result.receiverName} successfully.`);
      console.log(`[OK] Payment processed: ${result.amount} from ${result.senderName} to ${result.receiverName}`);
    } else {
      // Notify sender of failure
      await sendSms(from, `FAILED#${result.error}`);
      console.log(`[FAIL] ${result.error}`);
    }
  } catch (err) {
    console.error('[ERROR]', err.message);
    await sendSms(from, 'FAILED#Server error. Please try again.');
  }

  // Always respond 200 to Twilio
  res.status(200).send('<Response></Response>');
});

// ─── Core payment processor ───────────────────────────────────
async function processPaymentSms(fromPhone, smsBody) {
  // 1. Parse payload: PAY#senderId#receiverId#amount#timestamp#hmac
  const parts = smsBody.split('#');
  if (parts.length !== 6) return { success: false, error: 'Invalid payment format.' };

  const [, senderId, receiverId, amountStr, timestampStr, receivedHmac] = parts;
  const amount = parseFloat(amountStr);
  const timestamp = parseInt(timestampStr, 10);

  if (!senderId || !receiverId) return { success: false, error: 'Invalid payment format.' };
  if (senderId === receiverId) return { success: false, error: 'Cannot pay yourself.' };
  if (isNaN(amount) || amount <= 0) return { success: false, error: 'Invalid amount.' };
  if (isNaN(timestamp)) return { success: false, error: 'Invalid payment format.' };

  // 2. Replay protection — reject if older than 120 seconds
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - timestamp) > 120) {
    return { success: false, error: 'Payment expired. Please retry.' };
  }

  // 3. Nonce check — prevent exact duplicate SMS (Redis-backed, atomic claim)
  const nonce = `${senderId}:${receiverId}:${amountStr}:${timestampStr}`;
  let nonceIsNew;
  try {
    nonceIsNew = await claimNonce(nonce);
  } catch (err) {
    // Fail closed: if Redis is unreachable we cannot guarantee replay
    // protection, so reject rather than silently accepting the risk.
    console.error('[NONCE STORE ERROR]', err.message);
    return { success: false, error: 'Server temporarily unavailable. Please retry.' };
  }
  if (!nonceIsNew) {
    return { success: false, error: 'Duplicate transaction detected.' };
  }

  // 4. Fetch sender's secret key from backend
  let senderSecretKey;
  try {
    const keyRes = await axios.get(`${BACKEND_URL}/users/${senderId}/sms-key`, {
      headers: { 'x-api-key': BACKEND_KEY },
    });
    senderSecretKey = keyRes.data.secretKey;
  } catch {
    return { success: false, error: 'Could not verify sender identity.' };
  }

  if (!senderSecretKey) {
    return { success: false, error: 'Could not verify sender identity.' };
  }

  // 5. Verify HMAC — 32 hex chars (128 bits) instead of 16 (64 bits),
  //    compared in constant time to avoid a timing side-channel.
  //    NOTE: the on-device Dart signer must also use .substring(0, 32)
  //    for this to match — update both sides together.
  const raw = `${senderId}:${receiverId}:${amountStr}:${timestampStr}`;
  const expectedHmac = crypto
    .createHmac('sha256', senderSecretKey)
    .update(raw)
    .digest('hex')
    .substring(0, 32);

  const expectedBuf = Buffer.from(expectedHmac, 'hex');
  const receivedBuf = Buffer.from(receivedHmac ?? '', 'hex');

  const hmacValid =
    expectedBuf.length === receivedBuf.length &&
    crypto.timingSafeEqual(expectedBuf, receivedBuf);

  if (!hmacValid) {
    return { success: false, error: 'Invalid signature. Payment rejected.' };
  }

  // 6. Call backend to transfer funds
  let transferRes;
  try {
    transferRes = await axios.post(
      `${BACKEND_URL}/wallet/sms-transfer`,
      { senderId, receiverId, amount },
      { headers: { 'x-api-key': BACKEND_KEY } }
    );
  } catch (err) {
    const msg = err.response?.data?.message || 'Transfer failed.';
    return { success: false, error: msg };
  }

  if (!transferRes.data.success) {
    return { success: false, error: transferRes.data.message || 'Transfer failed.' };
  }

  return {
    success: true,
    amount: amount.toFixed(2),
    senderName: transferRes.data.senderName,
    receiverName: transferRes.data.receiverName,
    receiverPhone: transferRes.data.receiverPhone,
  };
}

// ─── SMS sender helper ────────────────────────────────────────
async function sendSms(to, message) {
  try {
    await twilioClient.messages.create({
      body: message,
      from: GATEWAY_NUMBER,
      to: to,
    });
    console.log(`[SMS SENT] To: ${to} | ${message}`);
  } catch (err) {
    console.error(`[SMS FAIL] To: ${to} | ${err.message}`);
  }
}

// ─── Health check ─────────────────────────────────────────────
app.get('/health', async (_, res) => {
  let redisOk = true;
  try {
    await redis.ping();
  } catch {
    redisOk = false;
  }
  res.json({ status: redisOk ? 'ok' : 'degraded', gateway: GATEWAY_NUMBER, redis: redisOk });
});

// ─── Start ────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`OfflinePay SMS Gateway running on port ${PORT}`);
  console.log(`Gateway number: ${GATEWAY_NUMBER}`);
  console.log(`Twilio webhook URL: POST /sms/incoming`);
});