<!-- # 📱 NextPay — Flutter

> **Offline-first payment app built with Flutter. Send money without internet, sync when connected.**

NextPay is the Flutter mobile client for the OfflinePay ecosystem. It works completely offline using local storage and cryptographic signatures, syncing transactions to the backend when internet is restored.

---

## ✨ Features

### 💳 Wallet
- Real-time balance with locked/available split
- Balance visibility toggle (show/hide)
- Auto-refresh after every transaction

### 💸 Send Money
- Send to any wallet via User ID
- Quick amount chips (₹50, ₹100, ₹200, ₹500)
- QR scanner for instant receiver fill
- Animated success modal with haptic feedback
- Works online and offline

### 📴 Offline Mode
- Transactions signed with SHA256 and saved locally
- Balance locked during offline — prevents overspending
- Pending queue shows all offline transactions
- Auto-sync when internet is restored
- Manual sync via "Sync Transactions" button

### 🔊 SoundBox Integration
- Paired soundbox app announces payments in Hindi & English
- Works via backend polling

### 📜 History
- Full transaction history (sent + received)
- Online/Offline badge per transaction
- Summary strip with totals

### 👤 Profile
- QR code for receiving payments
- Share QR as image
- Member since, email, user ID

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter |
| Language | Dart |
| State Management | Provider |
| HTTP Client | Dio |
| Local Storage | SharedPreferences |
| Cryptography | SHA256 (crypto package) |
| QR Code | qr_flutter, mobile_scanner |
| TTS | flutter_tts |
| Connectivity | connectivity_plus |
| UUID | uuid |
| Haptics | vibration |

---

## 📁 Project Structure

```
lib/
├── main.dart                  # App entry + NetworkMonitor init
├── models/
│   ├── user.dart
│   ├── wallet.dart
│   ├── transaction.dart       # OfflineTransaction model
│   └── wallet_transaction.dart
├── providers/
│   └── auth_provider.dart     # Auth + wallet state
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart       # Dashboard + sync trigger
│   ├── send_screen.dart       # Send money (online + offline)
│   ├── scanner_screen.dart    # QR scanner
│   ├── pending_screen.dart    # Offline queue
│   ├── history_screen.dart    # Transaction history
│   ├── profile_screen.dart    # QR code + user info
│   └── receive_screen.dart
├── services/
│   ├── api_service.dart       # Dio HTTP client
│   ├── auth_service.dart
│   ├── storage_service.dart   # SharedPreferences wrapper
│   ├── sync_service.dart
│   └── wallet_service.dart
└── offline/
    ├── transaction_engine.dart # Create + sign offline txs
    ├── wallet_engine.dart      # Lock/unlock balance locally
    ├── sync_engine.dart        # Sync pending to backend
    └── network_monitor.dart    # Auto-sync on reconnect
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x+
- Dart 3.x+
- Android Studio or Xcode
- Backend server running (see server README)

### 1. Clone the repo
```bash
git clone https://github.com/Moinkhokhar1/NextPay.git
cd NextPay/nextpay
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure API URL

Edit `lib/services/api_service.dart`:
```dart
// For Android emulator
static const String baseUrl = "http://10.0.2.2:8000/api";

// For physical device (use your machine's IP)
static const String baseUrl = "http://192.168.x.x:8000/api";
```

### 4. Run the app
```bash
flutter run
```

---

## 🔄 How Offline Works

```
User sends payment (no internet)
        ↓
Balance locked locally (SharedPreferences)
        ↓
Transaction signed with SHA256
        ↓
Saved to pending_transactions_{userId}
        ↓
Internet restored → NetworkMonitor detects change
        ↓
Auto-sync POST /sync/transactions
        ↓
Server validates SHA256 signature
        ↓
Balance updated — receiver gets funds
        ↓
Local storage cleared
```

---

## 🔐 Offline Security

Every offline transaction is signed before saving:

```dart
final payload = {
  'txId': uuid,
  'sender': senderId,
  'receiver': receiverId,
  'amount': amount,
  'timestamp': timestamp,
  'nonce': nonce,
  'status': 'pending',
  'synced': false,
};
final signature = sha256(jsonEncode(payload) + SECRET_KEY);
```

The backend verifies this signature before processing — tampered transactions are rejected.

---

## 📱 Screenshots

| Home | Send Money | Pending | History |
|------|------------|---------|---------|
| ![Home](screenshots/home.png) | ![Send](screenshots/sendmoney.png) | ![Pending](screenshots/pending.png) | ![History](screenshots/history.png) |

| Login | Profile | QR Scanner | Sign Up |
|-------|---------|------------|---------|
| ![Login](screenshots/login.png) | ![Profile](screenshots/profile.png) | ![QR](screenshots/qrscan.png) | ![Register](screenshots/signup.png) |

---

## ⚙️ Dependencies

```yaml
dependencies:
  provider: ^6.x
  dio: ^5.x
  shared_preferences: ^2.x
  crypto: ^3.x
  uuid: ^4.x
  connectivity_plus: ^6.x
  qr_flutter: ^4.x
  mobile_scanner: ^5.x
  flutter_tts: ^4.x
  vibration: ^2.x
  share_plus: ^10.x
  screenshot: ^3.x
  path_provider: ^2.x
  device_info_plus: ^10.x
```

---

## 🔧 Known Limitations

- iOS 26 simulator not supported (plugin arm64 issue) — use physical device
- Bluetooth offline announcement requires custom build (expo-dev-client)
- QR offline confirmation modal (coming soon)

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

---

## 📄 License

© 2026 moinworksonlocalhost. All rights reserved.

This project is **not open source**. No part of this codebase may be copied, modified, distributed, or used without explicit written permission from the author.

---

<div align="center">

**Built with ❤️ by Moinworksonlocalhost**

*Making payments accessible everywhere, even without internet*

</div> -->
<!-- <div align="center">

# ⚡ NextPay

### Offline-First Payments. No Internet Required.

**Send money over SMS. Sync automatically. Never lose a transaction.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![Prisma](https://img.shields.io/badge/Prisma-PostgreSQL-2D3748?style=for-the-badge&logo=prisma&logoColor=white)](https://www.prisma.io/)
[![Twilio](https://img.shields.io/badge/Twilio-SMS_Gateway-F22F46?style=for-the-badge&logo=twilio&logoColor=white)](https://www.twilio.com/)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](#-license)

<img src="screenshots/home.png" width="200"/> <img src="screenshots/sendmoney.png" width="200"/> <img src="screenshots/qrscan.png" width="200"/> <img src="screenshots/history.png" width="200"/>

</div>

---

## 💡 What is NextPay?

**NextPay** is a full-stack digital wallet ecosystem built for places where the network drops out but the money still needs to move. A user can send funds with **zero internet connection** — the transaction is cryptographically signed and queued locally, then automatically synced the moment connectivity returns. For truly offline scenarios, an **SMS gateway** lets transfers happen over plain text messages, no data plan needed at all.

It's not just an app — it's four coordinated services working together:

| Service | What it does | Stack |
|---|---|---|
| 📱 **`nextpay/`** | The mobile wallet — send, receive, scan, sync | Flutter · Dart |
| 🖥️ **`server/`** | Core API — auth, wallets, transactions, withdrawals | Node.js · Express · Prisma · PostgreSQL |
| 📡 **`gateway/`** | SMS-based payment gateway | Node.js · Twilio · HMAC |
| 🔊 **`soundbox-app/`** | Merchant companion — announces payments aloud | Expo · React Native |

---

## 🧭 Table of Contents

- [Why NextPay](#-why-nextpay)
- [Architecture](#-architecture)
- [Core Features](#-core-features)
- [Tech Stack](#️-tech-stack)
- [Getting Started](#-getting-started)
- [How Offline Sync Works](#-how-offline-sync-works)
- [SMS Payment Flow](#-sms-payment-flow)
- [Security Model](#-security-model)
- [Data Model](#️-data-model)
- [Screenshots](#-screenshots)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Why NextPay

Traditional payment apps assume you always have a connection. NextPay doesn't.

- 🌐 **No signal? No problem.** Transactions are signed and stored on-device, then synced when the network returns.
- 📴 **True SMS fallback.** No data plan at all? Send `PAY#` over text and the gateway handles the rest.
- 🔐 **Tamper-proof by design.** Every offline transaction carries a SHA-256/HMAC signature the backend verifies before it ever touches a balance.
- 🔊 **Audible confirmations.** Merchants get a spoken payment announcement via the SoundBox companion app — Hindi & English.
- ⚡ **Instant when online, resilient when not.** The same wallet, the same balance, the same experience — either way.

---

## 🏗️ Architecture

```
                        ┌───────────────────────┐
                        │   NextPay Mobile App   │
                        │   (Flutter · Dart)     │
                        └──────────┬────────────┘
                                   │ REST (Dio)
                     ┌─────────────┼─────────────┐
                     │                           │
            ┌────────▼────────┐        ┌─────────▼─────────┐
            │   Core Server    │◄──────►│   SMS Gateway      │
            │ Express · Prisma │  HTTP  │ Express · Twilio   │
            │   PostgreSQL     │        │  HMAC-verified     │
            └────────┬─────────┘        └─────────┬─────────┘
                     │                             │
                     │                     ┌────────▼────────┐
                     │                     │   Twilio SMS     │
                     │                     │  "PAY#..." texts │
                     │                     └─────────────────┘
                     │
            ┌────────▼─────────┐
            │  SoundBox App     │
            │ Expo · TTS polling│
            │ 🔊 "Payment of    │
            │    ₹500 received" │
            └───────────────────┘
```

---

## ✨ Core Features

### 💳 Wallet & Payments
- Real-time balance with **locked vs. available** split
- Send to any user via ID or **QR scan**
- Quick-amount chips for fast transfers
- Animated success states with haptic feedback

### 📴 Offline Engine
- Transactions signed with **SHA-256** and stored locally
- Balance auto-locks while offline to prevent overspending
- Pending queue with manual or automatic sync
- `NetworkMonitor` triggers sync the instant connectivity returns

### 📡 SMS Gateway
- Twilio webhook parses `PAY#` formatted messages
- HMAC signature validation before any funds move
- Confirmation SMS sent to both sender and receiver
- Nonce tracking to block replay attacks

### 🔊 SoundBox Companion
- Polls the backend for incoming payments
- Announces amount + sender via text-to-speech
- Bilingual: Hindi & English

### 📜 History & Profile
- Combined online/offline transaction ledger with status badges
- Shareable QR code for receiving payments
- Bank account linking & withdrawal requests

---

## 🛠️ Tech Stack

<table>
<tr>
<td valign="top" width="25%">

**Mobile (`nextpay/`)**
- Flutter / Dart
- Provider
- Dio
- SharedPreferences
- `crypto` (SHA-256)
- qr_flutter · mobile_scanner
- flutter_tts
- connectivity_plus

</td>
<td valign="top" width="25%">

**Backend (`server/`)**
- Node.js · Express 5
- Prisma ORM
- PostgreSQL
- JWT auth
- bcrypt
- Firebase Admin
- Twilio (OTP)

</td>
<td valign="top" width="25%">

**SMS Gateway (`gateway/`)**
- Node.js · Express
- Twilio SDK
- HMAC (crypto)
- Axios
- dotenv

</td>
<td valign="top" width="25%">

**SoundBox (`soundbox-app/`)**
- Expo / React Native
- expo-router
- expo-speech (TTS)
- expo-haptics
- TypeScript

</td>
</tr>
</table>

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x+ & Dart 3.x+
- Node.js 18+ and npm
- PostgreSQL instance
- Twilio account (for SMS gateway)
- Android Studio / Xcode (for mobile builds)

### 1. Clone the repo
```bash
git clone https://github.com/Moinkhokhar1/NextPay.git
cd NextPay
```

### 2. Set up the backend server
```bash
cd server
npm install
cp .env.example .env   # add DATABASE_URL, JWT_SECRET, etc.
npx prisma migrate dev
npm run dev
```

### 3. Set up the SMS gateway (optional)
```bash
cd gateway
npm install
cp .env.example .env   # add TWILIO_* keys + BACKEND_API_URL
npm run dev
```

### 4. Run the mobile app
```bash
cd nextpay
flutter pub get
```
Point it at your backend in `lib/services/api_service.dart`:
```dart
// Android emulator
static const String baseUrl = "http://10.0.2.2:8000/api";
// Physical device
static const String baseUrl = "http://192.168.x.x:8000/api";
```
```bash
flutter run
```

### 5. Run the SoundBox companion (optional)
```bash
cd soundbox-app
npm install
npx expo start
```

---

## 🔄 How Offline Sync Works

```
 User sends payment (no internet)
             │
             ▼
 Balance locked locally (SharedPreferences)
             │
             ▼
 Transaction signed with SHA-256
             │
             ▼
 Saved to pending_transactions_{userId}
             │
             ▼
 Internet restored → NetworkMonitor detects change
             │
             ▼
 Auto-sync: POST /sync/transactions
             │
             ▼
 Server verifies signature
             │
             ▼
 Balance updated · receiver funded · local queue cleared
```

## 📟 SMS Payment Flow

```
 Sender texts:  PAY#<receiverPhone>#<amount>#<nonce>
             │
             ▼
 Twilio webhook → gateway.js  (/sms/incoming)
             │
             ▼
 HMAC signature validated · nonce checked for replay
             │
             ▼
 Gateway calls backend API to execute transfer
             │
             ▼
 Confirmation SMS sent to sender & receiver
```

---

## 🔐 Security Model

Every offline transaction is signed **before** it ever leaves the device:

```dart
final payload = {
  'txId': uuid,
  'sender': senderId,
  'receiver': receiverId,
  'amount': amount,
  'timestamp': timestamp,
  'nonce': nonce,
  'status': 'pending',
  'synced': false,
};
final signature = sha256(jsonEncode(payload) + SECRET_KEY);
```

- ✅ Backend independently re-verifies every signature before crediting a balance
- ✅ Nonces prevent replay of the same transaction twice
- ✅ SMS gateway messages are HMAC-authenticated end-to-end
- ✅ Passwords hashed with `bcrypt`; sessions secured with JWT

---

## 🗄️ Data Model

The core server persists everything through Prisma into PostgreSQL:

| Model | Purpose |
|---|---|
| `User` | Identity, credentials, public key, SMS secret |
| `Wallet` | Balance & locked balance per user |
| `Transaction` | Signed transfer record (online/offline flag) |
| `SyncLog` | Tracks retry attempts for pending syncs |
| `BankAccount` | Linked bank details for withdrawals |
| `Withdrawal` | Withdrawal request lifecycle |
| `Otp` | Phone verification codes |

---

## 📱 Screenshots

| Login | Home | Send Money | QR Scanner |
|:---:|:---:|:---:|:---:|
| ![Login](screenshots/login.png) | ![Home](screenshots/home.png) | ![Send](screenshots/sendmoney.png) | ![QR](screenshots/qrscan.png) |

| Pending Queue | History | Transaction Detail | Profile |
|:---:|:---:|:---:|:---:|
| ![Pending](screenshots/pending.png) | ![History](screenshots/history.png) | ![Detail](screenshots/txdetail.PNG) | ![Profile](screenshots/profile.png) |

---

## 🗺️ Roadmap

- [ ] QR-based offline confirmation modal
- [ ] Bluetooth fallback for SoundBox announcements (custom dev build)
- [ ] iOS 26 simulator support (currently arm64 plugin issue — use physical device)
- [ ] Redis-backed nonce store for the SMS gateway (currently in-memory)

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you'd like to change.

---

## 📄 License

© 2026 moinworksonlocalhost. All rights reserved.

This project is **not open source**. No part of this codebase may be copied, modified, distributed, or used without explicit written permission from the author.

---

<div align="center">

**Built with ❤️ by [Moinworksonlocalhost](https://moinworksonlocalhost.onrender.com/)**

*Making payments accessible everywhere — even without a single bar of signal.*

</div> -->
# NextPay

A peer-to-peer wallet system designed to keep working when the network doesn't. The mobile client can create, sign, and queue a payment entirely offline, then reconcile it with the backend the moment a connection comes back — no failed transfers just because someone stepped into a dead zone.

The repository is organized as three independent projects:

| Folder | What it is | Stack |
|---|---|---|
| [`nextpay/`](./nextpay) | The mobile wallet app | Flutter / Dart |
| [`server/`](./server) | The API the app talks to | Node.js, Express, Prisma, PostgreSQL |
| [`gateway/`](./gateway) | An SMS-based fallback for initiating payments without the app | Node.js, Express, Twilio |

---

## Architecture

```
┌──────────────────────┐          ┌──────────────────────────┐
│   nextpay (Flutter)   │  HTTPS   │   server (Express API)   │
│                       │ ───────► │                           │
│  • signs offline txs  │          │  • auth (JWT)             │
│  • queues while       │  ◄─────  │  • wallet + balances      │
│    offline, syncs     │          │  • transaction sync       │
│    on reconnect       │          │  • messaging              │
└──────────────────────┘          │  • bank/withdrawal         │
                                   └─────────────┬─────────────┘
                                                 │
                                                 ▼
                                   ┌──────────────────────────┐
                                   │   gateway (Twilio SMS)    │
                                   │  lets a transfer be       │
                                   │  triggered by SMS instead │
                                   │  of the app               │
                                   └──────────────────────────┘
```

---

## `nextpay/` — Mobile app

Built with Flutter. The app assumes the network is unreliable rather than treating it as an edge case.

**What it does:**
- Sends and receives money by wallet ID, phone number, or QR code
- Works fully offline: transactions are signed locally and the sent amount is locked out of the available balance immediately, so the same money can't be sent twice before a sync happens
- Automatically re-syncs queued transactions once connectivity returns, and lets you trigger a manual sync too
- App-level security: PIN setup, biometric unlock, and an auto-lock screen
- In-app messaging with a contact, alongside their shared transaction history
- Per-user local caching (contacts, offline transaction queue, profile photo) — every cache key is scoped to the signed-in user so switching accounts on the same device never leaks another user's data
- A small custom in-app notification system (`AppSnack`) used instead of the framework's default snackbars, for consistent success/error/info styling across the app

**Where things live** (`lib/`):
- `screens/` — one file per screen (login, register, home, send, receive, scanner, history, profile, PIN setup, biometric prompt, etc.)
- `services/` — API client, auth, wallet, contact cache, offline transaction store, sync, key management
- `offline/` — the offline engine: transaction signing (`tx_signing.dart`), the sync engine, and a network monitor that watches for reconnection
- `sms_payment/` — a device-side SMS payment path (listening for and sending payment SMS, with its own crypto util and key-sync service)
- `providers/` — app-wide state (auth session, theme)
- `models/`, `widgets/` — data models and shared UI components

**Running it:**
```bash
cd nextpay
flutter pub get
flutter run
```
You'll need the backend (below) running and reachable, and the base URL in `lib/services/api_service.dart` pointed at it (`10.0.2.2` for the Android emulator, your machine's LAN IP for a physical device).

---

## `server/` — Backend API

An Express API with Prisma/PostgreSQL underneath. This is the source of truth: every offline transaction gets re-verified here before it's considered final.

**Data model** (`prisma/schema.prisma`): `User`, `Wallet`, `Transaction`, `SyncLog`, `Message`, `BankAccount`, `Withdrawal`.

**Routes:**
- `authRoutes` — register, login, OTP login, profile, user lookup by phone/id
- `walletRoutes` — balance, wallet operations
- `syncRoutes` — accepts queued offline transactions from the app and reconciles them
- `messageRoutes` — send/fetch messages between two users
- `bank` — link/unlink a bank account, request withdrawals, view withdrawal history
- `sms_routes` — internal endpoints used by the SMS gateway (key exchange, SMS-initiated transfers) plus phone-number registration/sync for the app's own SMS payment path

**Running it:**
```bash
cd server
npm install
# .env needs at least: DATABASE_URL, JWT_SECRET
npx prisma generate
npx prisma migrate dev
npm run dev
```

---

## `gateway/` — SMS gateway

A small Express service sitting in front of Twilio. The idea: someone without the app (or without data) can still send money by texting a specific format to a Twilio number. The gateway validates the message, calls the backend's `sms_routes` transfer endpoint, and texts both parties a confirmation.

**Current state:** the webhook handler in `gateway.js` is written but commented out — it's a working draft, not yet wired into the running service.

**Running it:**
```bash
cd gateway
npm install
# .env needs: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER,
#             BACKEND_API_URL, BACKEND_API_KEY, HMAC_SECRET_STORE_URL
npm run dev
```

---

## The offline flow, end to end

1. App user hits "Send" with no connection.
2. The amount is locked out of their available balance on-device immediately.
3. The transaction is built, signed (SHA-256 over the payload plus a secret), and appended to a local per-user queue.
4. `network_monitor.dart` notices connectivity return and kicks off a sync.
5. The server's `syncRoutes` endpoint re-validates the signature and nonce — a tampered or replayed transaction is rejected here, not just trusted from the client.
6. On success, the local queue entry is cleared and the real balance updates.

---

## License

© 2026 moinworksonlocalhost. All rights reserved. This project is not open source — no part of it may be copied, modified, distributed, or reused without written permission from the author.