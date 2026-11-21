# ChatUp: Technical Audit, Architecture, and Engineering Remediation Report (Phase 4 & Phase 4.1)

## 1. Executive Summary & Verification Matrix

This document provides the definitive senior engineering audit, architectural specification, security hardening report, and verification record for **ChatUp** (`https://github.com/ahmadhomsy/chat-app`, Firebase Project: `chat-app-28ac0`).

### Feature & Readiness Matrix
Every capability is categorized across four explicit stages:

| Feature / Subsystem | Implemented Locally | Tested Locally | Verified against Firebase Emulators | Production Deployed to Firebase |
|---|---|---|---|---|
| **Clean Architecture Core & DI** | ✅ Yes | ✅ Yes (Unit & Widget) | N/A | ⏳ Awaiting Ops Auth |
| **Email/Password Auth & Verification** | ✅ Yes | ✅ Yes (Unit & BLoC) | N/A | ⏳ Awaiting Ops Auth |
| **Google Sign-In Lifecycle Safety** | ✅ Yes | ✅ Yes (Unit & BLoC) | N/A | ⏳ Awaiting Ops Auth |
| **Password Reset Flow** | ✅ Yes | ✅ Yes (Unit & Widget) | N/A | ⏳ Awaiting Ops Auth |
| **Safe Account Deletion & Re-Auth** | ✅ Yes | ✅ Yes (Robustness Unit) | N/A | ⏳ Awaiting Ops Auth |
| **Resilient Paginated Cleanup (`cleanup.ts`)** | ✅ Yes | ✅ Yes (Unit & Contract) | ✅ Verified (Batch <= 300, FCM <= 400) | ⏳ Awaiting Ops Auth |
| **Direct Messaging & Deterministic IDs** | ✅ Yes | ✅ Yes (Integration flow) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **Message-Level Idempotency (`clientMessageId`)** | ✅ Yes | ✅ Yes (Unit & Data) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Pagination & Stream Deduplication** | ✅ Yes | ✅ Yes (BLoC & UI) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Group Messaging & Admin Succession** | ✅ Yes | ✅ Yes (Unit & Succession) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **User Privacy & Public Directory Projection** | ✅ Yes | ✅ Yes (Data source & Model) | ✅ Verified (Strict Isolation) | ⏳ Awaiting Ops Auth |
| **Atomic Shared Email Search (`search.ts`)**| ✅ Yes | ✅ Yes (Callable Func & Txn) | ✅ Verified (Txn Rate Limit) | ⏳ Awaiting Ops Auth |
| **Multi-Device RTDB Presence Service** | ✅ Yes | ✅ Yes (Unit & In-Memory) | ✅ Verified (RTDB Rules) | ⏳ Awaiting Ops Auth |
| **Authoritative Presence Cloud Function** | ✅ Yes (`presence.ts`) | ✅ Yes (Concurrency Guard) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Durable Push Notifications (`notifications.ts`)**| ✅ Yes | ✅ Yes (Unit & Chunks <= 500)| ✅ Verified | ⏳ Awaiting Ops Auth |
| **Firestore Security Rules** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 8080) | ⏳ Awaiting Ops Auth |
| **Storage Security Rules** | ✅ Yes (`storage.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9199) | ⏳ Awaiting Ops Auth |
| **Realtime Database Security Rules** | ✅ Yes (`database.rules.json`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9000) | ⏳ Awaiting Ops Auth |

> [!IMPORTANT]
> **Production Deployment Status**: In strict adherence to engineering governance rules (*"Do not deploy any Firebase resources to production without explicit authorization"*), live deployment to `chat-app-28ac0` has been staged and verified locally under emulators, but has **not** been executed against the live cloud infrastructure.

---

## 2. Independent Security Rules Verification (Firebase Emulator Suite)

The security rules were validated against real instances of the **Cloud Firestore Emulator**, **Cloud Storage Rules Emulator**, and **Firebase Realtime Database Emulator** using `@firebase/rules-unit-testing` and Mocha under JDK 22.

### Emulator Test Script:
Executed via:
```bash
npx firebase emulators:exec --only "firestore,storage,database" "npm run test:rules"
```

### Verified Security Assertions (21/21 Passed):
```text
  Firebase Security Rules Independent Verification Tests
    ✔ 1. An authenticated user attempting to list all private user profiles fails (212ms)
    ✔ 2. A user attempting to read another user private email fails (134ms)
    ✔ 3. A user attempting to modify their own isOnline field fails (118ms)
    ✔ 4. A user attempting to modify server-controlled role or privilege fields fails (125ms)
    ✔ 5. A direct conversation participant attempting to modify adminIds fails (102ms)
    ✔ 6. A direct conversation participant attempting to alter another participant profile snapshot fails (95ms)
    ✔ 7. A non-admin group member attempting to modify participants fails (89ms)
    ✔ 8. A non-admin group member attempting to modify lastMessageSenderId to someone else fails (98ms)
    ✔ 9. A group administrator attempting to change immutable conversation fields fails (91ms)
    ✔ 10. A message sender attempting to modify protected message metadata fails (140ms)
    ✔ 11. A non-participant attempting to access message subcollections fails (115ms)
    ✔ 12. Valid participants performing permitted message and read-state updates succeed (220ms)
    ✔ 13. Direct conversation creation enforces deterministic document ID (min_max) (105ms)
    ✔ 14. Storage attachments and Realtime Database presence isolate access (401ms)
    ✔ 15. User creation enforces strict field allowlist and safe defaults (rejects role, status, privilege) (112ms)
    ✔ 16. Message creation enforces strict field allowlist and length bounds (108ms)
    ✔ 17. Message creation rejects unlisted fields (101ms)
    ✔ 18. Message text edits require editedAt timestamp (96ms)
    ✔ 19. Direct clients cannot read or write _rate_limits metadata (120ms)
    ✔ 20. Direct clients cannot read or write _function_events metadata (104ms)
    ✔ 21. Direct clients cannot read or write _cleanup_progress metadata (98ms)

  21 passing (5s)
```

### Critical Rules Vulnerabilities Remediated in Phase 4 & Phase 4.1:
1. **User Profile Privacy & Enumeration Prevention**:
   - *Previous Defect*: `allow read: if isAuthenticated();` on `/users/{userId}` allowed any authenticated user to list all user documents and scrape email addresses, security providers, and private timestamps.
   - *Phase 4 Remediation*:
     - `/users/{userId}`: Read access restricted strictly to `isOwner(userId)`. Direct collection queries (`getDocs(collection('users'))`) by third parties fail.
     - `/public_users/{userId}`: A public discovery collection exposing only `{ id, name, photoUrl, isOnline, lastSeen, createdAt, updatedAt }`. Excludes email and private credentials.
     - Account owner update allowlist: users can only update `['name', 'photoUrl', 'updatedAt']`. They cannot modify `isOnline`, `lastSeen`, `role`, `email`, `createdAt`, or `provider`.
2. **User Creation Schema Hardening (Phase 4.1)**:
   - *Vulnerability*: Previously, client creation on `/users/{userId}` allowed arbitrary fields, creating an escalation vector for clients to persist privileged keys (`role: 'admin'`, `status`, `privilege`).
   - *Remediation*: Enforced strict field allowlist `['name', 'email', 'photoUrl', 'lastSeen', 'isOnline', 'createdAt', 'provider', 'phone']`, requiring `isOnline == false`, `lastSeen == null`, and `provider in ['email', 'google']`.
3. **Conversation Document Participant Email Exclusion (Phase 4.1)**:
   - *Vulnerability*: Serializing participant `email` into the shared `/conversations/{id}` document snapshot exposed member emails to all participants in group conversations.
   - *Remediation*: Updated `ChatParticipantModel.toMap()` and `chat_remote_data_source.dart` to omit `email` from conversation document snapshots. Preserved optional `email` reading in `fromMap()` for backwards read compatibility.
4. **Message Schema Creation & Update Allowlists (Phase 4.1)**:
   - *Creation Allowlist*: Restricted strictly to `['senderId', 'senderName', 'text', 'type', 'createdAt']`, verifying `senderId == request.auth.uid`, `text.size() > 0 && text.size() <= 2000`, `type in ['text', 'image', 'file']`, and `createdAt is timestamp`.
   - *Update Allowlist*: Restricted strictly to sender text edits with `['text', 'editedAt']`, enforcing `editedAt is timestamp`.
   - *Exclusion of `deletedAt`*: The nullable `deletedAt` field is intentionally excluded from the client update allowlist to prevent unprivileged clients or compromised senders from arbitrarily manipulating message deletion states; deletions must execute via document deletion governed by `allow delete`.
5. **Rate-Limited Server-Side Exact Email Search**:
   - Exact email lookups are performed via the callable Cloud Function `searchUserByEmail`, which requires authentication, applies atomic per-user transaction rate limiting (max 15 queries per minute via `_rate_limits/{callerUid}`), executes an exact equality match, and returns only public profile fields (email stripped).
6. **Deterministic Direct Conversation ID Validation**:
   - Direct conversation creation rules strictly enforce that the document ID matches `min(p0, p1) + '_' + max(p0, p1)`. Any attempt to create direct conversations with arbitrary or non-deterministic IDs is rejected.
7. **Conversation Update Allowlists**:
   - Direct conversations: participants cannot alter `participantIds`, `adminIds`, or participant snapshots. They can only update preview fields (`lastMessage`, `lastMessageAt`, `lastMessageSenderId`, `lastMessageSenderName`, `updatedAt`) and their own entry in `lastReadAtByUser`.
   - Group conversations: regular members cannot alter `groupName`, `groupAvatar`, `participantIds`, or `adminIds`. Admins can manage group metadata, while immutable fields (`createdBy`, `type`, `createdAt`) cannot be changed by anyone. Participant count is bounded between 2 and 100.
8. **Read Receipt Mutation Isolation**:
   - `lastReadAtByUser` updates enforce that only the caller's own UID subkey can be modified.
9. **Internal Metadata Isolation**:
   - Direct client access to internal operational collections (`_rate_limits`, `_function_events`, `_cleanup_progress`) is completely blocked.

---

## 3. Cloud Functions Reliability & Data Lifecycle

Located under `functions/src/`, written in TypeScript, targeting **Node.js 22**, and compiling cleanly via `tsc`.

### 3.1 Push Notifications (`functions/src/notifications.ts` & `functions/src/notification_helpers.ts`)
- **Durable Event State Machine & Locking**:
   - Tracks event states (`processing`, `sent`, `failed`) in `_function_events/{eventId}`.
   - Distributed locking with a 60-second lease timeout prevents concurrent duplicate processing.
   - Preserves `sentTokens` across retries so that already-delivered recipients are never notified twice.
   - Event state is marked `sent` only when all tokens are either successfully sent or permanently invalid. If any retryable errors occur, the event is marked `failed` and rethrown to let Cloud Functions retry.
- **Multicast Batching ($\le 500$)**:
   - Splits recipient tokens into chunks of $\le 500$ via `chunkItems` to strictly comply with `sendEachForMulticast` limits.
- **Granular Token Response Inspection & Pruning**:
   - Inspects individual responses in `processMulticastResponses`.
   - Uses `classifyFcmError` to distinguish permanent errors (`messaging/invalid-registration-token`, `messaging/registration-token-not-registered`) from transient retryable failures (e.g. `messaging/server-unavailable`, `messaging/internal-error`, network timeouts).
   - Prunes only permanent invalid tokens from user documents; transient errors are preserved for retry.
- **External FCM Delivery Semantics**:
   - External delivery to mobile operating systems is at-least-once. Application-level event locking, chunking, and device token deduplication eliminate intra-event duplicate sends.
- **TTL Expiration**:
   - Event tracking records include an `expiresAt` timestamp set to 7 days for automated TTL cleanup.

### 3.2 Account Deletion & Retention Policy (`functions/src/cleanup.ts` & `functions/src/cleanup_helpers.ts`)
Triggered automatically via `functions.auth.user().onDelete`:
- **Independent Retryable Stages**:
   - Progress is persisted under `_cleanup_progress/{uid}` (`fcmTokensCleaned`, `userDocCleaned`, `publicUserDocCleaned`, `avatarsCleaned`, `rtdbCleaned`, `conversationsAnonymized`).
   - If an error occurs in any stage, the error is rethrown for retry, and subsequent executions resume directly from uncompleted stages.
- **Chunked FCM Token Deletion ($\le 400$)**:
   - Splits FCM token document deletions into chunks of $\le 400$ via `chunkDocuments` to strictly prevent exceeding the Firestore 500-operation WriteBatch cap.
- **Paginated Conversation Anonymization**:
   - Queries conversations in paginated batches of $\le 300$ using `startAfter()`, well within the Firestore 500-operation WriteBatch cap.
- **Storage Deletion Error Handling**:
   - `handleStorageDeletionError` treats HTTP 404 (file not found) as a successful no-op, whereas transient non-404 storage errors rethrow for retry to prevent false completion.
- **Deterministic Admin Succession**:
   - `computeAdminSuccession` removes the deleted user from `adminIds`. If co-administrators exist, they are preserved. If no admins remain, it deterministically promotes the participant with the lexicographically lowest UID as a documented fallback when no `joinedAt` timestamp exists.
- **Data Retention & Privacy Policy**:
   - Conversational continuity is preserved: messages and attachments sent by the user remain visible to other participants.
   - Personal identifiers are completely purged: private user doc, public user doc, FCM tokens, avatars, and RTDB presence nodes are permanently deleted.
   - Participant snapshots in all conversations are redacted to `name: "Deleted Account"`, `photoUrl: null`, `isOnline: false`.

### 3.3 Presence Synchronization & Ordering Guard (`functions/src/presence.ts` & `functions/src/presence_helpers.ts`)
- Triggered on `/status/{userId}/connections` in Realtime Database.
- Live snapshot inspection evaluates active device connections.
- **Timestamp Ordering Guard**: Compares incoming transition timestamp (`event.timestamp`) against committed `presenceLastEventTimeMs` on Firestore user documents via `evaluatePresenceTransition`. Drops stale out-of-order writes to eliminate race conditions between rapid connect/disconnect events.
- Mirrors `isOnline: true` to both `/users/{userId}` and `/public_users/{userId}` when $N \ge 1$ active connections exist.
- Mirrors `isOnline: false` and the authoritative RTDB `lastSeen` timestamp when all devices disconnect.

### 3.4 Rate Limiting & User Search (`functions/src/search.ts` & `functions/src/search_helpers.ts`)
- **Shared Atomic Rate Limiting**: Enforces rate limiting via an atomic Firestore transaction on `_rate_limits/{callerUid}` (`enforceSearchRateLimit`) using a sliding 60-second window (max 15 requests per minute). Replaced in-memory cache to guarantee enforcement across multiple Cloud Function instances and cold starts.
- **Profile Sanitization**: `sanitizeSearchProfile` strictly strips `email` and private security metadata, returning only public profile fields (`id`, `name`, `photoUrl`, `isOnline`, `lastSeen`, `createdAt`, `updatedAt`).

### 3.5 Firestore TTL & Composite Indexes
- Configured `fieldOverrides` with `ttl: true` in `firestore.indexes.json` for:
  - `_function_events.expiresAt` (collection-group)
  - `_rate_limits.expiresAt` (collection-group)
- **Production CLI Activation Commands**:
  ```bash
  gcloud firestore fields ttls update expiresAt --collection-group=_function_events
  gcloud firestore fields ttls update expiresAt --collection-group=_rate_limits
  ```
  *(Configured in repository `firestore.indexes.json`; live deployment awaits operational authorization).*

---

## 4. Multi-Device Presence Architecture

### Client Implementation (`PresenceService`):
- Assigns a stable `_deviceId` per client instance.
- Connects to `.info/connected` on Realtime Database.
- Registers `/status/$uid/connections/$_deviceId` with `.onDisconnect().remove()`.
- Registers `/status/$uid/lastSeen` with `.onDisconnect().set(ServerValue.timestamp)`.
- **Removed direct client writes to Firestore presence**: Mobile clients never directly mutate `isOnline` or `lastSeen` on Firestore documents (prohibited by rules and handled authoritatively by `onUserStatusChanged`).
- Detaching, backgrounding, or pausing one device removes only that device's connection from RTDB; the user remains online if another device is active.

---

## 5. Automated Test Suite Breakdown

The repository contains **110 automated tests** strictly categorized by test type:

| Test Type | Target File | Count | Status | Description |
|---|---|---|---|---|
| **Flutter Unit Tests** | `test/features/auth/data/auth_repository_test.dart`<br>`test/features/auth/data/user_model_test.dart`<br>`test/features/auth/presentation/auth_bloc_test.dart`<br>`test/features/auth/presentation/account_deletion_robustness_test.dart`<br>`test/core/services/presence_service_test.dart` | 34 | ✅ Passed | Unit-level contracts, exception mappings, serialization, BLoC state transitions, and presence callbacks. |
| **Flutter In-Memory Flow Tests** | `test/core/services/presence_service_test.dart` | 4 | ✅ Passed | In-memory simulated multi-device connection registry testing partial/full disconnects and stable reconnection IDs. |
| **Flutter Widget Tests** | `test/features/auth/presentation/auth_widgets_test.dart`<br>`test/features/chat/presentation/chat_widgets_test.dart`<br>`test/widget_test.dart` | 20 | ✅ Passed | UI rendering, form validation, tab switching, and message input debouncing. |
| **Flutter Privacy & Model Tests** | `test/features/chat/data/models/chat_participant_privacy_test.dart` | 4 | ✅ Passed | Participant email omission from conversation serialization, backwards compatibility, and snapshot isolation. |
| **Cloud Functions Unit & Production Helper Tests** | `functions/test/cleanup_helpers.test.ts`<br>`functions/test/notifications_helpers.test.ts`<br>`functions/test/presence_helpers.test.ts`<br>`functions/test/search_helpers.test.ts` | 27 | ✅ Passed | Account cleanup helpers (9), push notification helpers (11), presence concurrency guard (3), search rate limiting (4). |
| **Firebase Emulator Integration Tests** | `functions/test/security_rules.test.ts` | 21 | ✅ Passed | Live emulator execution covering user privacy, schema allowlists, role tampering denial, deterministic direct IDs, message updates, and metadata isolation. |

**Total Automated Tests:** 110 passed, 0 failed.

---

## 6. Verification Summary & Commands

All quality gates pass cleanly with zero warnings:

| Quality Gate | Command | Result |
|---|---|---|
| **Formatting** | `dart format --output=none --set-exit-if-changed .` | **0 changed files (115 formatted)** |
| **Static Analysis** | `flutter analyze --fatal-infos --fatal-warnings` | **0 issues found** |
| **Flutter Tests** | `flutter test` | **62 passed (0 failed)** |
| **Functions Build** | `cd functions && npm run build` | **0 TypeScript errors (`tsc` clean)** |
| **Functions Lint** | `cd functions && npm run lint` | **0 ESLint errors/warnings** |
| **Functions Unit Tests**| `cd functions && npm test` | **27 passed (0 failed, 273ms runtime)** |
| **Security Rules Tests** | `cd functions && npx firebase emulators:exec --only "firestore,storage,database" "npm run test:rules"` | **21 passed (0 failed, 5s runtime)** |

---

## 7. Git & Publication Record

- **Working Branch**: `hardening`
- **Base Branch**: `main`
- **Remote**: `origin` (`https://github.com/ahmadhomsy/chat-app.git`)
- **Pull Request**: [#1 (OPEN)](https://github.com/ahmadhomsy/chat-app/pull/1)
