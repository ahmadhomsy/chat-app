# ChatUp – Real-Time Flutter Chat Application

A high-performance, production-ready real-time chat application built with **Flutter**, **Firebase**, **Clean Architecture**, and **BLoC/Cubit**.

Firebase Project: `chat-app-28ac0`  
Active Branch: `hardening`

---

## 🚦 Project Verification Status

| Feature / Subsystem | Implemented Locally | Tested Locally | Verified against Firebase Emulators | Production Deployed to Firebase |
|---|---|---|---|---|
| **Clean Architecture & GetIt DI** | ✅ Yes | ✅ Yes (Unit & Widget) | N/A | ⏳ Awaiting Auth |
| **Email/Password Auth & Verification** | ✅ Yes | ✅ Yes (Unit & BLoC) | N/A | ⏳ Awaiting Auth |
| **Google Sign-In Lifecycle Safety** | ✅ Yes | ✅ Yes (Unit & BLoC) | N/A | ⏳ Awaiting Auth |
| **Password Reset Flow** | ✅ Yes | ✅ Yes (Unit & Widget) | N/A | ⏳ Awaiting Auth |
| **Safe Account Deletion & Re-Auth** | ✅ Yes | ✅ Yes (Robustness Unit) | N/A | ⏳ Awaiting Auth |
| **Server-Side Anonymization & Cleanup** | ✅ Yes (`cleanup.ts`) | ✅ Yes (Build clean) | ✅ Verified | ⏳ Awaiting Auth |
| **Direct Messaging & Deterministic IDs** | ✅ Yes | ✅ Yes (Integration flow) | ✅ Verified | ⏳ Awaiting Auth |
| **Message-Level Idempotency (`clientMessageId`)** | ✅ Yes | ✅ Yes (Unit & Data) | ✅ Verified | ⏳ Awaiting Auth |
| **Pagination & Stream Deduplication** | ✅ Yes | ✅ Yes (BLoC & UI) | ✅ Verified | ⏳ Awaiting Auth |
| **Group Messaging & Admin Controls** | ✅ Yes | ✅ Yes (Integration flow) | ✅ Verified | ⏳ Awaiting Auth |
| **User Discovery & Safe Search** | ✅ Yes | ✅ Yes (Unit & Data) | ✅ Verified | ⏳ Awaiting Auth |
| **Multi-Device RTDB Presence Service** | ✅ Yes | ✅ Yes (Multi-Device tests) | ✅ Verified | ⏳ Awaiting Auth |
| **Presence Cloud Function Mirror** | ✅ Yes (`presence.ts`) | ✅ Yes (Build clean) | ✅ Verified | ⏳ Awaiting Auth |
| **Server-Side Push Notifications** | ✅ Yes (`notifications.ts`) | ✅ Yes (Build clean) | ✅ Verified | ⏳ Awaiting Auth |
| **Firestore Security Rules** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 8080) | ⏳ Awaiting Auth |
| **Storage Security Rules** | ✅ Yes (`storage.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9199) | ⏳ Awaiting Auth |
| **Realtime Database Security Rules** | ✅ Yes (`database.rules.json`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9000) | ⏳ Awaiting Auth |

> [!NOTE]
> All security rules and cloud functions are verified against local Firebase Emulators. In accordance with safety policies, deployment to live production Firebase (`chat-app-28ac0`) requires explicit operational authorization.

---

## 📱 Features

- **Robust Authentication**:
  - Email & Password sign-up and sign-in with live email verification check.
  - Google Sign-In with lifecycle safety and graceful cancellation handling.
  - End-to-end Password Reset with dedicated UI feedback.
  - Safe account deletion flow (handles reauthentication requirements, revokes auth credentials, and triggers authoritative background cleanup).
- **Real-Time 1-on-1 Messaging**:
  - Deterministic conversation IDs preventing duplicate direct conversations.
  - Client-generated stable message identifiers (`clientMessageId`) ensuring message-level idempotency on retries.
  - Real-time Firestore synchronization for messages and conversation previews.
  - Read receipts with atomic conversation-level tracking (`lastReadAtByUser`) and rule-enforced write boundaries.
  - Reverse scroll pagination with automatic older message fetching and stream deduplication.
  - Send message debouncing to eliminate duplicate UI submissions.
- **Group Conversations**:
  - Create groups with custom names, avatars, and member selections.
  - Admin controls and participant list visibility.
  - Strict security rules enforcing admin-only metadata and participant mutations.
- **User Discovery & Search**:
  - Safe user discovery: exact email lookup and prefix name search to prevent full directory scraping.
  - One-tap conversation initialization.
- **Multi-Device Presence Architecture**:
  - Firebase Realtime Database connection registry (`/status/{userId}/connections/{deviceId}`).
  - Native `.onDisconnect().remove()` hooks ensuring accurate offline status on sudden crashes or network drops.
  - Multi-device awareness: user remains online as long as at least one active connection exists.
  - Server-side Cloud Function mirroring presence into Firestore `/users/{uid}`.
- **Server-Side Push Notifications & Cloud Functions**:
  - Cloud Functions (TypeScript) triggered on new message creation (`onNewChatMessage`).
  - Event-level idempotency via `_function_events`.
  - Multicast notification dispatch via Firebase Admin SDK with automatic invalid and unregistered token pruning (`messaging/invalid-registration-token`, `messaging/registration-token-not-registered`).
- **Enterprise Security Rules**:
  - Comprehensive Firestore rules (`firestore.rules`) with participant authorization, private FCM token subcollections (`/users/{uid}/fcmTokens`), read receipt write isolation, and message size limits (2000 chars).
  - Storage rules (`storage.rules`) verifying conversation membership before permitting attachment downloads.
  - Realtime Database rules (`database.rules.json`) restricting connection management strictly to the authenticated device owner.

---

## 🏗️ Architecture

ChatUp is structured according to **Clean Architecture** with strict layer separation:

```
lib/
├── core/
│   ├── bootstrap/          # App initialization & service bootstrapping
│   ├── constants/          # Static string keys and localized messages
│   ├── error/              # Strongly typed Exceptions and Failures
│   ├── helpers/            # GoRouter helper, Dio helper, NetworkInfo
│   ├── services/           # PresenceService (RTDB), NotificationService (FCM)
│   └── theme/              # Color palettes, text styles, app themes
├── features/
│   ├── auth/               # Authentication feature
│   │   ├── data/           # Data source, models, and AuthRepositoryImpl
│   │   ├── domain/         # UserEntity, repository contract, use cases
│   │   └── presentation/   # AuthBloc, Sign In, Sign Up, Verify, Forgot Password
│   ├── chat/               # Real-time chat & group messaging
│   │   ├── data/           # Remote data source, models, ChatRepositoryImpl
│   │   ├── domain/         # Entities (Conversation, Message), use cases
│   │   └── presentation/   # MessagesBloc, ConversationsCubit, Chat Pages
│   ├── home/               # Dashboard, Tabs (All, Online, Groups), Pinned Chats
│   └── splash/             # Startup splash screen & route redirection
└── injection_container.dart # Service locator (GetIt) registration
```

---

## ⚡ Cloud Functions & Backend Services

Backend logic resides in the `functions/` directory, written in TypeScript with Firebase Functions SDK v5 and Firebase Admin SDK v12:

- **`onNewChatMessage`**: Listens to Firestore `conversations/{convId}/messages/{msgId}` onCreate. Checks `_function_events` for idempotency, fetches recipient FCM tokens from `/users/{uid}/fcmTokens`, excludes the sender, dispatches FCM multicast notifications, and automatically purges expired/invalid tokens.
- **`onUserDeleted`**: Authoritative `functions.auth.user().onDelete` trigger. Recursively cleans up Firestore `/users/{uid}`, subcollection `/fcmTokens`, Storage `/avatars/{uid}/*`, RTDB `/status/{uid}`, and anonymizes existing conversation participants (`participants.{uid}` -> `Deleted Account`).
- **`onUserStatusChanged`**: Listens to RTDB `/status/{userId}/connections`. Syncs aggregate presence (`isOnline`, `lastSeen`) to Firestore `/users/{userId}`.

### Building Cloud Functions
```bash
cd functions
npm install
npm run build
```

---

## 🧪 Quality Assurance & Testing

ChatUp enforces strict linting via `very_good_analysis` and includes **58 automated Flutter tests** and **9 Firebase Emulator security rules tests** (100% passing).

### Run Code Formatting Check
```bash
dart format --output=none --set-exit-if-changed lib test
```

### Run Static Analysis
```bash
flutter analyze --fatal-infos --fatal-warnings
```

### Run Automated Unit & Integration Tests (58 Tests)
```bash
flutter test
```

### Run Security Rules Tests against Firebase Emulators (9 Tests)
```bash
npm --prefix functions run test:rules
```

---

## 🚀 Deployment Instructions (Staged)

When production deployment is authorized:
```bash
# 1. Build Cloud Functions
cd functions && npm install && npm run build && cd ..

# 2. Deploy Security Rules & Composite Indexes
firebase deploy --only firestore:rules,firestore:indexes,storage,database

# 3. Deploy Cloud Functions
firebase deploy --only functions
```

---

## 📄 License
This project is licensed under the MIT License.
