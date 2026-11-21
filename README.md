# ChatUp – Real-Time Flutter Chat Application

A high-performance, production-ready real-time chat application built with **Flutter**, **Firebase**, **Clean Architecture**, and **BLoC/Cubit**.

Firebase Project: `chat-app-28ac0`  
Working Branch: `hardening`  
Target Base Branch: `main`  
Pull Request: [#1 (OPEN)](https://github.com/ahmadhomsy/chat-app/pull/1)

---

## 🚦 Project Verification Status

| Feature / Subsystem | Implemented Locally | Tested Locally | Verified against Firebase Emulators | Production Deployed to Firebase |
|---|---|---|---|---|
| **Clean Architecture & GetIt DI** | ✅ Yes | ✅ Yes (Unit & Widget) | N/A | ⏳ Awaiting Ops Auth |
| **Email/Password Auth & Verification** | ✅ Yes | ✅ Yes (Unit & BLoC) | N/A | ⏳ Awaiting Ops Auth |
| **Google Sign-In Lifecycle Safety** | ✅ Yes | ✅ Yes (Unit & BLoC) | N/A | ⏳ Awaiting Ops Auth |
| **Password Reset Flow** | ✅ Yes | ✅ Yes (Unit & Widget) | N/A | ⏳ Awaiting Ops Auth |
| **Safe Account Deletion & Re-Auth** | ✅ Yes | ✅ Yes (Robustness Unit) | N/A | ⏳ Awaiting Ops Auth |
| **Resilient Paginated Cleanup (`cleanup.ts`)** | ✅ Yes | ✅ Yes (Unit & Contract) | ✅ Verified (Batch <= 300) | ⏳ Awaiting Ops Auth |
| **Direct Messaging & Deterministic IDs** | ✅ Yes | ✅ Yes (Widget & Model) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **Message-Level Idempotency (`clientMessageId`)** | ✅ Yes | ✅ Yes (Unit & Data) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Pagination & Stream Deduplication** | ✅ Yes | ✅ Yes (BLoC & UI) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Group Messaging & Admin Succession** | ✅ Yes | ✅ Yes (Unit & Succession) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **User Privacy & Public Directory Projection** | ✅ Yes | ✅ Yes (Data source) | ✅ Verified (Strict Isolation) | ⏳ Awaiting Ops Auth |
| **Rate-Limited Server Email Search (`search.ts`)**| ✅ Yes | ✅ Yes (Callable Func) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Multi-Device RTDB Presence Service** | ✅ Yes | ✅ Yes (Unit & In-Memory) | ✅ Verified (RTDB Rules) | ⏳ Awaiting Ops Auth |
| **Authoritative Presence Cloud Function** | ✅ Yes (`presence.ts`) | ✅ Yes (Build clean) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Durable Push Notifications (`notifications.ts`)**| ✅ Yes | ✅ Yes (Unit & Chunks <= 500)| ✅ Verified | ⏳ Awaiting Ops Auth |
| **Firestore Security Rules** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 8080) | ⏳ Awaiting Ops Auth |
| **Storage Security Rules** | ✅ Yes (`storage.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9199) | ⏳ Awaiting Ops Auth |
| **Realtime Database Security Rules** | ✅ Yes (`database.rules.json`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9000) | ⏳ Awaiting Ops Auth |

> [!NOTE]
> All security rules, backend functions, and integration boundaries are verified against local Firebase Emulators (JDK 22). In strict accordance with safety guidelines, deployment to production Firebase (`chat-app-28ac0`) has not been executed and requires manual operational authorization.

---

## 📱 Features

- **Robust Authentication**:
  - Email & Password sign-up and sign-in with live email verification check.
  - Google Sign-In with lifecycle safety and graceful cancellation handling.
  - Password Reset flow with dedicated UI feedback.
  - Safe account deletion flow (handles reauthentication requirements, revokes auth credentials, and triggers authoritative background cleanup).
- **Strict User Privacy & Discovery Architecture**:
  - Complete isolation between private user documents (`/users/{userId}`, read restricted strictly to account owner) and public discovery documents (`/public_users/{userId}`).
  - Prevents email scraping and directory enumeration through Firestore rules.
  - Server-side callable Cloud Function `searchUserByEmail` with per-user rate limiting (max 15/min) and exact-match search.
  - Profile update allowlist: users cannot alter `isOnline`, `lastSeen`, `role`, `email`, `createdAt`, or `provider`.
- **Real-Time 1-on-1 Messaging**:
  - Deterministic conversation IDs (`min(uid1, uid2) + '_' + max(uid1, uid2)`) enforced directly by Firestore Security Rules.
  - Client-generated stable message identifiers (`clientMessageId`) ensuring message-level idempotency on retries.
  - Read receipts with atomic conversation-level tracking (`lastReadAtByUser`) restricted by rules so users can only update their own read timestamp.
  - Reverse scroll pagination with automatic older message fetching and stream deduplication.
  - Message schema validation: length 1–2000 chars, senderId match, allowed types (`text`, `image`, `file`), immutable creation metadata, and sender-only text edits.
- **Group Conversations & Governance**:
  - Create groups with custom names, avatars, and member selections (2 to 100 participants).
  - Admin controls: regular members cannot alter group name, avatar, or participants; admins cannot alter immutable conversation fields (`type`, `createdBy`, `createdAt`).
  - Automatic admin succession on account deletion: promotes the oldest remaining participant if no admins remain.
- **Multi-Device Presence Architecture**:
  - Firebase Realtime Database connection registry (`/status/{userId}/connections/{deviceId}`) is the sole source of truth for active device connections.
  - Native `.onDisconnect().remove()` and `.onDisconnect().set(ServerValue.timestamp)`.
  - Closing or backgrounding one device never marks the user offline while another active connection exists.
  - Server-side Cloud Function (`onUserStatusChanged`) authoritatively aggregates presence and mirrors `isOnline` and `lastSeen` to both `/users/{uid}` and `/public_users/{uid}`.
  - Mobile clients never directly write presence to Firestore (enforced by Security Rules).
- **Durable Push Notifications & Cloud Functions**:
  - Node.js 22 runtime with Firebase Functions SDK v5 and Firebase Admin SDK v12.
  - Event-level distributed locking with 60-second lease timeout in `_function_events` preventing concurrent duplicate processing.
  - Multicast batching in chunks of $\le 500$ tokens to strictly comply with Firebase Admin limits.
  - Token deduplication across multiple user devices.
  - Automatic pruning of invalid and unregistered tokens (`messaging/invalid-registration-token`, `messaging/registration-token-not-registered`).
  - Partial delivery tracking in `sentTokens` so retries skip already-delivered recipients.
  - Documented at-least-once external FCM delivery semantics.
- **Resilient Account Deletion & Anonymization**:
  - Triggered automatically via `functions.auth.user().onDelete`.
  - Independent retryable stages tracked in `_cleanup_progress/{uid}`.
  - Paginated conversation processing in batches of $\le 300$ updates to strictly respect the Firestore 500-operation WriteBatch cap.
  - Retention policy: conversational continuity preserved (messages and attachments retained); personal identifiers, avatars, FCM tokens, and presence nodes permanently deleted; participant profiles anonymized to `Deleted Account`.

---

## 🏗️ Architecture

ChatUp follows **Clean Architecture** with strict layer separation:

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

Backend logic resides in the `functions/` directory, written in TypeScript targeting **Node.js 22**:

- **`onNewChatMessage`**: Triggers on Firestore `conversations/{convId}/messages/{msgId}` onCreate. Distributed lease locking via `_function_events`, chunked multicast ($\le 500$), partial progress persistence, and automatic token pruning.
- **`onUserDeleted`**: Triggered via `functions.auth.user().onDelete`. Multi-stage resilient cleanup with `_cleanup_progress`, paginated conversation updates ($\le 300$), and admin succession.
- **`onUserStatusChanged`**: Triggers on RTDB `/status/{userId}/connections`. Live snapshot inspection, multi-device aggregation, and mirror to `/users/{userId}` and `/public_users/{userId}`.
- **`searchUserByEmail`**: HTTPS callable function for exact email search with authentication, per-user rate limiting (max 15/min), and public profile projection.

### Building Cloud Functions
```bash
cd functions
npm ci
npm run build
```

---

## 🧪 Quality Assurance & Test Breakdown

The test suite contains **81 automated tests** across four distinct categories:

1. **Flutter Unit Tests (34 tests)**:
   - Auth repository error mapping and offline detection.
   - User model serialization and null timestamp resilience.
   - Account deletion robustness (re-auth, offline, server failures).
   - Auth BLoC state transitions (SignIn, SignUp, ResetPassword, Logout).
   - PresenceService unit baseline (callbacks and unauthenticated handling).
2. **Flutter In-Memory Flow Tests (4 tests)**:
   - Multi-device RTDB connection registry simulation.
   - Simultaneous connections, partial disconnects, full disconnects, and stable reconnection IDs.
3. **Flutter Widget Tests (20 tests)**:
   - Sign-in form rendering and input validation.
   - Forgot password screen UI.
   - Home tabs switching (All, Online, Groups).
   - Conversation page message bubbles, header, and input debouncing.
   - App theme and logo smoke test.
4. **Cloud Functions Unit & Logic Tests (9 tests)**:
   - Token chunking ($\le 500$).
   - Event concurrency guard and 60-second lease timeout.
   - Retry filtering with `previouslySentTokens`.
   - Prunable error code classification.
   - Group admin succession and co-admin preservation.
   - Participant anonymization.
   - Firestore batch write safety ($\le 300 \le 500$).
   - Stage tracking idempotency.
5. **Firebase Emulator Integration Tests (14 tests)**:
   - Unauthenticated access denial (Firestore, RTDB, Storage).
   - Private FCM token isolation.
   - User profile enumeration denial (`getDocs(collection('users'))` fails).
   - Private email read denial and public profile read allowance.
   - Server-authoritative presence tamper denial (`isOnline`).
   - Server-controlled role and email tamper denial.
   - Direct conversation `adminIds` and participant snapshot tamper denial.
   - Non-admin group member modification denial.
   - Non-admin `lastMessageSenderId` spoofing denial.
   - Group admin immutable field tamper denial (`type`, `createdBy`).
   - Message metadata tamper denial (`senderId`, `createdAt`).
   - Non-participant message subcollection access denial.
   - Valid participant message creation, text editing, and read-receipt updates.
   - Deterministic direct conversation ID enforcement (`min_max`).
   - Storage attachment and RTDB presence authorization boundaries.

### Run Verification Commands

```bash
# 1. Code Formatting
dart format --output=none --set-exit-if-changed .

# 2. Static Code Analysis (Zero warnings/infos)
flutter analyze --fatal-infos --fatal-warnings

# 3. Flutter Automated Tests (58 tests)
flutter test

# 4. Cloud Functions Build & Unit Tests (9 tests)
cd functions && npm run build && npm test && cd ..

# 5. Firebase Security Rules Tests against Live Emulators (14 tests)
cd functions && npx firebase emulators:exec --only "firestore,storage,database" "npm run test:rules" && cd ..
```

---

## 🚀 Deployment Instructions (Staged)

When production deployment is explicitly authorized:
```bash
# 1. Build Cloud Functions
cd functions && npm ci && npm run build && cd ..

# 2. Deploy Security Rules & Composite Indexes
firebase deploy --only firestore:rules,firestore:indexes,storage,database

# 3. Deploy Cloud Functions
firebase deploy --only functions
```

---

## 📄 License
This project is licensed under the MIT License.
