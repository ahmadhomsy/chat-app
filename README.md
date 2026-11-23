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
  - Strict user document creation allowlist in `firestore.rules`: client creation permits only `['name', 'email', 'photoUrl', 'lastSeen', 'isOnline', 'createdAt', 'provider', 'phone']`, requiring `isOnline == false`, `lastSeen == null`, and `provider in ['email', 'google']`, preventing client injection of privileged fields (`role`, `status`, `privilege`, etc.).
- **Strict User Privacy & Discovery Architecture**:
  - Complete isolation between private user documents (`/users/{userId}`, read restricted strictly to account owner) and public discovery documents (`/public_users/{userId}`).
  - Prevents email scraping and directory enumeration through Firestore rules.
  - Server-side callable Cloud Function `searchUserByEmail` with atomic Firestore transaction-based rate limiting (max 15/min via `_rate_limits/{callerUid}`) and exact-match search. The response strictly sanitizes profiles, excluding email and security metadata.
  - Conversation participant privacy: `ChatParticipantModel.toMap()` omits `email` so participant snapshots in shared conversation documents never expose email addresses to other members.
  - Profile update allowlist: users cannot alter `isOnline`, `lastSeen`, `role`, `email`, `createdAt`, or `provider`.
- **Real-Time 1-on-1 Messaging**:
  - Deterministic conversation IDs (`min(uid1, uid2) + '_' + max(uid1, uid2)`) enforced directly by Firestore Security Rules.
  - Client-generated stable message identifiers (`clientMessageId`) ensuring message-level idempotency on retries.
  - Read receipts with atomic conversation-level tracking (`lastReadAtByUser`) restricted by rules so users can only update their own read timestamp.
  - Reverse scroll pagination with automatic older message fetching and stream deduplication.
  - Message schema validation: creation allowlist strictly bounded to `['senderId', 'senderName', 'text', 'type', 'createdAt']`, length 1–2000 chars, senderId match, and allowed types (`text`, `image`, `file`).
  - Sender-only text edits requiring `editedAt is timestamp` and diff restricted to `['text', 'editedAt']`.
  - Soft deletion (`deletedAt`) is excluded from the client update allowlist to prevent unprivileged tampering; message deletion is restricted to document-level deletion via `allow delete`.
- **Group Conversations & Governance**:
  - Create groups with custom names, avatars, and member selections (2 to 100 participants).
  - Admin controls: regular members cannot alter group name, avatar, or participants; admins cannot alter immutable conversation fields (`type`, `createdBy`, `createdAt`).
  - Automatic admin succession on account deletion: promotes existing co-admins or deterministically falls back to the lexicographically lowest participant UID if no admins remain.
- **Multi-Device Presence Architecture**:
  - Firebase Realtime Database connection registry (`/status/{userId}/connections/{deviceId}`) is the sole source of truth for active device connections.
  - Native `.onDisconnect().remove()` and `.onDisconnect().set(ServerValue.timestamp)`.
  - Closing or backgrounding one device never marks the user offline while another active connection exists.
  - Server-side Cloud Function (`onUserStatusChanged`) authoritatively aggregates presence and mirrors `isOnline` and `lastSeen` to both `/users/{uid}` and `/public_users/{uid}`.
  - Mobile clients never directly write presence to Firestore (enforced by Security Rules).
  - Timestamp-based ordering guard (`presenceLastEventTimeMs`) prevents out-of-order race conditions from overwriting fresh state.
- **Durable Push Notifications & Cloud Functions**:
  - Node.js 22 runtime with Firebase Functions SDK v5 and Firebase Admin SDK v12.
  - Event-level distributed locking with 60-second lease timeout in `_function_events` preventing concurrent duplicate processing.
  - Multicast batching in chunks of $\le 500$ tokens to strictly comply with Firebase Admin limits.
  - Token deduplication across multiple user devices.
  - Individual token error classification: permanent token errors (`messaging/invalid-registration-token`, `messaging/registration-token-not-registered`) are pruned; transient errors are recorded and rethrown so Cloud Functions can retry.
  - An event is never prematurely marked `sent` while retryable failures remain.
  - Partial delivery tracking in `sentTokens` so retries skip already-delivered recipients.
  - Documented at-least-once external FCM delivery semantics.
- **Resilient Account Deletion & Anonymization**:
  - Triggered automatically via `functions.auth.user().onDelete`.
  - Independent retryable stages tracked in `_cleanup_progress/{uid}`.
  - FCM token deletion chunked in batches of $\le 400$ to strictly respect the Firestore 500-operation WriteBatch cap.
  - Paginated conversation processing in batches of $\le 300$ updates.
  - Storage deletion error handling: 404 (not found) is treated as a successful no-op, whereas transient non-404 errors rethrow for retry.
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

### Building & Linting Cloud Functions
```bash
cd functions
npm ci
npm run build
npm run lint
```

---

## 🧪 Quality Assurance & Test Breakdown

The test suite contains **160 automated tests** across six distinct test suites:

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
4. **Flutter Privacy & Participant Model Tests (4 tests)**:
   - Verification that `ChatParticipantModel.toMap()` excludes participant email.
   - Legacy backward compatibility parsing optional `email` in `fromMap()`.
   - Direct and group conversation participant snapshot privacy isolation.
5. **Cloud Functions Unit & Production Helper Tests (44 tests)**:
   - **Account Cleanup Helpers (`cleanup_helpers.test.ts`, 11 tests)**: Token chunking ($\le 400$), conversation query limit ($\le 300 \le 500$), strict 404 error classification (`isStorageNotFoundError`), non-404 error rethrow, deterministic admin succession fallback, co-admin preservation, stage tracking idempotency, retry safety, migration dry-run audit (`auditLegacyParticipantEmails`), operational execution safety guard with uncommitted token & backup confirmation.
   - **Push Notification Helpers (`notifications_helpers.test.ts`, 13 tests)**: All-tokens success, permanent invalid token pruning, transient token retryability, multi-chunk dispatch ($\le 500$), retry filtering with `previouslySentTokens`, progress persistence errors, concurrency lease lock contention and recovery, non-premature completion checks, error code classification, retry window bounding (`isEventExpiredForRetry`), failure retryability classification (`isRetryableNotificationError`).
   - **Presence High-Precision Ordering & Timezone Normalization (`presence_helpers.test.ts`, 13 tests)**: Millisecond differing events, sub-millisecond fractional precision preservation without collapsing, equal timestamp deterministic rejection, older connect/disconnect rejection, competing transactions, multi-device online aggregation, reconnection state restoration, RFC 3339 UTC parsing, positive timezone offset normalization to UTC, negative timezone offset normalization, fractional microsecond padding/truncation, and invalid input rejection.
   - **Search Rate Limiting & Privacy Helpers (`search_helpers.test.ts`, 7 tests)**: Strict profile sanitization, rolling 60-second window acceptance (15 reqs), 16th request rejection, expired timestamp roll-off, boundary burst prevention, atomic transaction concurrency safety, complete window reset.
6. **Firebase Emulator Security Rules & Concurrency Tests (54 tests)**:
   - Unauthenticated access denial (Firestore, RTDB, Storage).
   - Private FCM token isolation.
   - User profile enumeration denial (`getDocs(collection('users'))` fails).
   - Private email read denial and public profile read allowance.
   - Server-authoritative presence tamper denial (`isOnline`).
   - Server-controlled role and privilege tamper denial.
   - Strict user creation field allowlist enforcement (rejects `role`, `status`, `privilege`).
   - Direct conversation `adminIds` and participant snapshot tamper denial.
   - Non-admin group member modification denial.
   - Non-admin `lastMessageSenderId` spoofing denial.
   - Group admin immutable field tamper denial (`type`, `createdBy`).
   - Message metadata tamper denial (`senderId`, `createdAt`).
   - Message creation strict schema allowlist and length bounds enforcement.
   - Message update allowlist (only sender can edit `text` and `editedAt`).
   - Non-participant message subcollection access denial.
   - Valid participant message creation, text editing, and read-receipt updates.
   - Deterministic direct conversation ID enforcement (`min_max`).
   - Storage attachment and RTDB presence authorization boundaries.
   - Internal metadata collections protection (`_rate_limits`, `_function_events`, `_cleanup_progress`).
   - **Participant Privacy & Subcollection Scaling (Phase 4.2 & Phase 4.3)**:
     - Valid direct conversation creation with sanitized participant snapshots succeeds.
     - Direct conversation creation with nested participant email or role/privilege is rejected.
     - Valid group of 8 succeeds via dedicated `/participants/{uid}` subcollection.
     - Valid group of 9 succeeds (breaking the former 8-member AST limit).
     - Valid group of 100 succeeds in a single WriteBatch (exact production flow: 1 parent + 100 participants in 1 batch).
     - Group creation with nested participant email on parent document is rejected.
     - Email injection into participant 9, 10, or 100 in subcollection is rejected.
     - Role, provider, or privilege injection into participant 9 or 100 is rejected.
     - Group administrator attempting to inject private fields during updates is rejected.
     - Legitimate administrator adding a member succeeds.
     - Normal member attempting to add a member fails.
     - Valid public participant profile updates remain functional (self-update & admin update).
   - **Group Administrator Authorization & Membership Invariants (Phase 4.3.1)**:
     - Valid group with all administrators in `participantIds` succeeds.
     - Group creation with administrator outside `participantIds` is rejected.
     - Group creation with empty administrator list is rejected.
     - Group administrator cannot add an outsider UID to `adminIds`.
     - Group administrator cannot leave a phantom administrator after removing a member.
     - Valid administrator succession succeeds when new administrator is in `participantIds`.
     - Nonmember listed in malicious `adminIds` cannot modify participant documents.
     - Nonmember listed in `adminIds` cannot delete participant documents.
     - Removed member cannot update their previous participant document.
     - Removed member cannot delete their previous participant document.
     - Removed member cannot read participant subcollection documents.
     - Current member can update only permitted own display fields (`name`, `photoUrl`).
     - Current member cannot modify document ID, email, role, provider, or server-authoritative presence fields (`isOnline`, `lastSeen`).
     - Group administrator can remove a member using the intended secure atomic operation (parent update + subdoc delete).
     - Normal member cannot delete a participant document or perform administrator operations.
   - **Unique Participant IDs & Membership Integrity (Phase 4.3.2)**:
     - Valid group with unique member UIDs succeeds on creation.
     - Group creation with duplicate participant UIDs is rejected (`toSet().size() == size()`).
     - Group creation with duplicate admin UIDs is rejected (`toSet().size() == size()`).
     - Group creation with 100 unique members succeeds.
     - Group updates with duplicate participant or admin IDs are rejected.
     - Direct conversation with duplicate participant IDs fails (self-conversation rejected; `toSet().size() == 2` & `pIds[0] != pIds[1]`).
     - Normal valid direct conversation with two distinct UIDs continues to work with deterministic ID (`min_max`).
   - **Atomic Participant Removal Guard (Phase 4.3.2)**:
     - Standalone deletion of a participant subcollection document alone fails.
     - Atomic batch updating parent membership and deleting participant document succeeds.
     - Administrator cannot remove the last remaining valid administrator.
     - Administrator cannot leave a removed admin inside `adminIds`.
     - Removed member loses parent conversation read access and subcollection access.
     - Remaining members retain normal read and message operations.
   - **Non-Bypassable Migration Guard & UID Element Audit (Phase 4.3.3, Phase 4.3.4 & Phase 4.3.4.1)**:
     - Multi-source project identity consensus: `resolveActiveProjectId` inspects Admin App (with safe exact-name matching), `GCLOUD_PROJECT`, and `FIREBASE_CONFIG` independently; conflicts, empty/whitespace, and malformed configs fail closed.
     - Strict ISO 8601 backup timestamp format & calendar semantics: `validateBackupTimestampFreshness` enforces ISO regex, timezone, and calendar validity via `isValidCalendarDateTime`, strictly rejecting impossible dates (e.g. Feb 31, non-leap Feb 29) normalized by JavaScript `Date.parse`.
     - Group administrator usability & succession guard: `isValidAdminList` guarantees `adminIds[0]` is a bounded string UID in `participantIds`, protecting the last usable administrator against non-string abandonment while preserving clean succession.
     - Explicit administrator bounds checking for indexes 0–7; entries beyond index 7 cannot authenticate or escalate privileges.
     - Direct conversation creation strictly rejects non-string IDs, empty IDs, and oversized IDs (> 128 chars).
     - Participant subcollection documents strictly enforce string type and length bounds on participant IDs.
     - Non-string parent list elements confirmed completely inert against string `request.auth.uid`.
   - **Live Emulator Concurrency & Migration Verification (Phase 4.3, Phase 4.3.1, Phase 4.3.2, Phase 4.3.3, Phase 4.3.4 & Phase 4.3.4.1)**:
     - Search Rate Limiter: 20 concurrent requests against Firestore emulator enforce max 15 requests, 5 get `resource-exhausted`, timestamps array bounded.
     - Legacy Email Migration: audit scanner identifies affected docs across batches with zero writes in dry-run mode against emulator.
     - True Presence Concurrency Barrier: competing transactions execute concurrently against emulator with synchronized latch; monotonic microsecond ordering guarantees newer state commits while older transition aborts without state inversion.
     - Operational Migration Guard: non-bypassable project identity resolution, 24-hour backup freshness bounds against real clock, and operator attestation requirements.

### Run Verification Commands

```bash
# 1. Code Formatting
dart format --output=none --set-exit-if-changed lib test

# 2. Static Code Analysis (Zero warnings/infos)
flutter analyze --fatal-infos --fatal-warnings

# 3. Flutter Automated Tests (62 tests)
flutter test

# 4. Cloud Functions Build, Lint & Unit Tests (44 tests)
cd functions && npm run build && npm run lint && npm test && cd ..

# 5. Firebase Security Rules & Concurrency Tests against Live Emulators (82 tests)
cd functions && firebase emulators:exec --project chat-app-28ac0 --only "firestore,storage,database" "npm run test:rules" && cd ..
```

---

## ⚙️ Firestore TTL & Composite Indexes

Firestore TTL policies are defined in `firestore.indexes.json` using `fieldOverrides` with `ttl: true`:
- `_function_events.expiresAt` (collection-group)
- `_rate_limits.expiresAt` (collection-group)

### Production CLI Activation
When operational deployment is authorized, execute:
```bash
gcloud firestore fields ttls update expiresAt --collection-group=_function_events --enable-ttl --project=chat-app-28ac0
gcloud firestore fields ttls update expiresAt --collection-group=_rate_limits --enable-ttl --project=chat-app-28ac0
```

> [!IMPORTANT]
> **TTL Lifecycle Distinction**:
> 1. **Repository Configuration**: TTL field overrides for `_function_events` and `_rate_limits` are committed in `firestore.indexes.json`.
> 2. **Firebase Rules & Index Deployment**: Staged for deployment via `firebase deploy --only firestore:indexes`.
> 3. **Cloud Production Activation**: Requires the `gcloud firestore fields ttls update ... --enable-ttl` command. In strict compliance with governance rules, this has **not** been executed against production project `chat-app-28ac0`.

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
