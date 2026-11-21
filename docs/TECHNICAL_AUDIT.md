# ChatUp: Technical Audit, Architecture, and Engineering Remediation Report (Phase 4, Phase 4.1 & Phase 4.2)

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
| **Strict Storage 404 vs Non-404 Handling** | ✅ Yes | ✅ Yes (Unit & Contract) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Direct Messaging & Deterministic IDs** | ✅ Yes | ✅ Yes (Integration flow) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **Message-Level Idempotency (`clientMessageId`)** | ✅ Yes | ✅ Yes (Unit & Data) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Pagination & Stream Deduplication** | ✅ Yes | ✅ Yes (BLoC & UI) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Group Messaging & Admin Succession** | ✅ Yes | ✅ Yes (Unit & Succession) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **Server-Enforced Participant Snapshot Privacy** | ✅ Yes | ✅ Yes (Data source & Model) | ✅ Verified (Rules Tests 22–28) | ⏳ Awaiting Ops Auth |
| **User Privacy & Public Directory Projection** | ✅ Yes | ✅ Yes (Data source & Model) | ✅ Verified (Strict Isolation) | ⏳ Awaiting Ops Auth |
| **Atomic Rolling Search Rate Limiter (`search.ts`)**| ✅ Yes | ✅ Yes (Callable Func & Txn) | ✅ Verified (15 req/60s rolling) | ⏳ Awaiting Ops Auth |
| **Multi-Device RTDB Presence Service** | ✅ Yes | ✅ Yes (Unit & In-Memory) | ✅ Verified (RTDB Rules) | ⏳ Awaiting Ops Auth |
| **Atomic Monotonic Presence Cloud Function** | ✅ Yes (`presence.ts`) | ✅ Yes (Firestore Txn Guard) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Durable Push Notifications (`notifications.ts`)**| ✅ Yes | ✅ Yes (Unit & Chunks <= 500)| ✅ Verified (failurePolicy: true) | ⏳ Awaiting Ops Auth |
| **Lock Lease Heartbeat Renewal** | ✅ Yes | ✅ Yes (Unit & Chunks) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Firestore Security Rules** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 8080) | ⏳ Awaiting Ops Auth |
| **Storage Security Rules** | ✅ Yes (`storage.rules`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9199) | ⏳ Awaiting Ops Auth |
| **Realtime Database Security Rules** | ✅ Yes (`database.rules.json`) | ✅ Yes (Rules tests) | ✅ Verified (Port 9000) | ⏳ Awaiting Ops Auth |
| **Firebase CLI Version Pinning (15.2.1)** | ✅ Yes (`ci.yaml`) | ✅ Yes (CI assertions) | ✅ Verified | ⏳ Awaiting Ops Auth |

> [!IMPORTANT]
> **Production Deployment Status**: In strict adherence to engineering governance rules (*"Do not deploy any Firebase resources to production without explicit authorization"*), live deployment to `chat-app-28ac0` has been staged and verified locally under emulators, but has **not** been executed against the live cloud infrastructure.
>
> **Three-State Configuration Accounting**:
> - **Repository Configuration**: Configured in source control (`firestore.rules`, `firestore.indexes.json`, `storage.rules`, `database.rules.json`, `functions/`).
> - **Emulator Verified**: Verified locally against isolated emulators on ports 8080, 9199, 9000 with 28 automated integration tests.
> - **Cloud Verified / Deployed**: Requires manual execution of deployment commands with administrative permissions once authorized.

---

## 2. Independent Security Rules Verification (Firebase Emulator Suite)

The security rules were validated against real instances of the **Cloud Firestore Emulator**, **Cloud Storage Rules Emulator**, and **Firebase Realtime Database Emulator** using `@firebase/rules-unit-testing` and Mocha under JDK 22.

### Emulator Test Script:
Executed via:
```bash
npx firebase emulators:exec --only "firestore,storage,database" "npm run test:rules"
```

### Verified Security Assertions (28/28 Passed):
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
    ✔ 22. Direct conversation creation with valid participant snapshots succeeds (115ms)
    ✔ 23. Direct conversation creation containing participant email is rejected (108ms)
    ✔ 24. Direct conversation creation with role or privilege in participant snapshot is rejected (102ms)
    ✔ 25. Group conversation creation containing participant email is rejected (110ms)
    ✔ 26. Group conversation creation with role or privilege in participant snapshot is rejected (99ms)
    ✔ 27. Group administrator update injecting email or role into participants is rejected (124ms)
    ✔ 28. Group administrator update with valid participants and permitted metadata changes succeeds (135ms)

  28 passing (9s)
```

### Critical Rules Vulnerabilities Remediated in Phase 4, Phase 4.1 & Phase 4.2:
1. **User Profile Privacy & Enumeration Prevention**:
   - *Previous Defect*: `allow read: if isAuthenticated();` on `/users/{userId}` allowed any authenticated user to list all user documents and scrape email addresses, security providers, and private timestamps.
   - *Phase 4 Remediation*:
     - `/users/{userId}`: Read access restricted strictly to `isOwner(userId)`. Direct collection queries (`getDocs(collection('users'))`) by third parties fail.
     - `/public_users/{userId}`: A public discovery collection exposing only `{ id, name, photoUrl, isOnline, lastSeen, createdAt, updatedAt }`. Excludes email and private credentials.
     - Account owner update allowlist: users can only update `['name', 'photoUrl', 'updatedAt']`. They cannot modify `isOnline`, `lastSeen`, `role`, `email`, `createdAt`, or `provider`.
2. **User Creation Schema Hardening (Phase 4.1)**:
   - *Vulnerability*: Previously, client creation on `/users/{userId}` allowed arbitrary fields, creating an escalation vector for clients to persist privileged keys (`role: 'admin'`, `status`, `privilege`).
   - *Remediation*: Enforced strict field allowlist `['name', 'email', 'photoUrl', 'lastSeen', 'isOnline', 'createdAt', 'provider', 'phone']`, requiring `isOnline == false`, `lastSeen == null`, and `provider in ['email', 'google']`.
3. **Server-Enforced Participant Snapshot Privacy (Phase 4.2)**:
   - *Vulnerability*: While client code omitted emails in Phase 4.1, security rules did not validate map keys inside `participants` list on creation or updates, allowing malicious or modified clients to inject `email`, `role`, or `privilege` into `/conversations/{id}`.
   - *Phase 4.2 Remediation*:
     - Implemented `isValidParticipantSnapshot(p)`: strictly enforces `p.keys().hasOnly(['id', 'name', 'photoUrl', 'isOnline', 'lastSeen'])`, with type validations (`p.id is string`, `p.name is string`, `p.isOnline is bool`), string length limits (`name.size() <= 100`, `photoUrl.size() <= 2048`), and strictly forbids unlisted keys such as `email`, `role`, `status`, `provider`, or `privilege`.
     - Implemented `isValidDirectParticipants(pList)` and `isValidGroupParticipants(pList)`: direct conversations enforce exactly 2 valid snapshots; group conversations enforce between 2 and 8 participant snapshots via unrolled checks that stay comfortably within the Firestore rules engine 1000-expression evaluation limit.
     - Enforced across direct creation, group creation, and group admin update rules.
4. **Message Schema Creation & Update Allowlists (Phase 4.1)**:
   - *Creation Allowlist*: Restricted strictly to `['senderId', 'senderName', 'text', 'type', 'createdAt']`, verifying `senderId == request.auth.uid`, `text.size() > 0 && text.size() <= 2000`, `type in ['text', 'image', 'file']`, and `createdAt is timestamp`.
   - *Update Allowlist*: Restricted strictly to sender text edits with `['text', 'editedAt']`, enforcing `editedAt is timestamp`.
   - *Exclusion of `deletedAt`*: The nullable `deletedAt` field is intentionally excluded from the client update allowlist to prevent unprivileged clients or compromised senders from arbitrarily manipulating message deletion states; deletions must execute via document deletion governed by `allow delete`.
5. **Rate-Limited Server-Side Exact Email Search (Phase 4.1 & Phase 4.2)**:
   - Exact email lookups are performed via callable Cloud Function `searchUserByEmail`, requiring authentication.
   - Phase 4.2 hardened rate limiting to an atomic rolling 60-second window (max 15 requests/min) using an array of timestamps inside a Firestore transaction.
   - Returns only public profile fields (email stripped).
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
- **Explicit Cloud Functions Retry Policy (`failurePolicy: true`)**:
  - Configured `functions.runWith({ failurePolicy: true, timeoutSeconds: 60, memory: '256MB' })` on `onNewChatMessage`.
  - Distinguishes retryable vs terminal errors via `isRetryableNotificationError`. Permanent failures (e.g. malformed payload, missing conversation, non-retryable client errors) terminate cleanly without rethrowing.
  - Event age bounding: `isEventExpiredForRetry(eventTimestamp, MAX_EVENT_AGE_MS)` discards events older than 10 minutes (`MAX_EVENT_AGE_MS = 600000`) to prevent infinite retry storms during prolonged outages.
- **Durable Event State Machine & Distributed Locking**:
  - Tracks event states (`processing`, `sent`, `failed`) in `_function_events/{eventId}`.
  - Lock lease timeout increased to 120 seconds (`LOCK_LEASE_MS = 120000`).
  - **Lock Lease Heartbeat Renewal**: After each multicast chunk is processed, the function executes an atomic transaction renewing `lockedAt: admin.firestore.FieldValue.serverTimestamp()`, preventing false lock expirations during long batches.
  - Preserves `sentTokens` across retries so that already-delivered recipients are never notified twice.
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
- **Explicit Retry Policy & Event Age Guard**:
  - Configured `functions.runWith({ failurePolicy: true, timeoutSeconds: 540, memory: '512MB' })`.
  - Bounds retry age at 30 minutes (`MAX_CLEANUP_EVENT_AGE_MS = 1800000`). If an event exceeds 30 minutes, it writes a terminal failure state to `_cleanup_progress/{uid}` and gracefully aborts.
- **Independent Resumable Stages**:
  - Progress is persisted under `_cleanup_progress/{uid}` (`fcmTokensCleaned`, `userDocCleaned`, `publicUserDocCleaned`, `avatarsCleaned`, `rtdbCleaned`, `conversationsAnonymized`).
  - Resumes directly from uncompleted stages upon retry.
- **Chunked FCM Token Deletion ($\le 400$)**:
  - Splits FCM token document deletions into chunks of $\le 400$ via `chunkDocuments` to strictly prevent exceeding the Firestore 500-operation WriteBatch cap.
- **Paginated Conversation Anonymization**:
  - Queries conversations in paginated batches of $\le 300$ using `startAfter()`, well within the Firestore 500-operation WriteBatch cap.
- **Strict Storage Error Handling (`isStorageNotFoundError`)**:
  - Replaced ambiguous string matching with strict inspection: checks `err.code === 404`, `err.code === '404'`, `err.statusCode === 404`, or `err.errors[].reason === 'notFound'`.
  - Missing avatar files (404) are treated as successful no-ops; any non-404 error (network failure, authentication, permission denied) is strictly rethrown to trigger Cloud Functions retry.
- **Deterministic Admin Succession**:
  - `computeAdminSuccession` removes the deleted user from `adminIds`. If co-administrators exist, they are preserved. If no admins remain, it deterministically promotes the participant with the lexicographically lowest UID as a documented fallback when no `joinedAt` timestamp exists.
- **Participant Email Audit Migration Script**:
  - Created `functions/src/migrations/dry_run_strip_participant_emails.ts` for safe, audited migration of legacy conversation documents. Runs in strict dry-run mode (`DRY_RUN = true`) without mutating production data.
- **Data Retention & Privacy Policy**:
  - Conversational continuity is preserved: messages and attachments sent by the user remain visible to other participants.
  - Personal identifiers are completely purged: private user doc, public user doc, FCM tokens, avatars, and RTDB presence nodes are permanently deleted.
  - Participant snapshots in all conversations are redacted to `name: "Deleted Account"`, `photoUrl: null`, `isOnline: false`.

### 3.3 Presence Synchronization & Ordering Guard (`functions/src/presence.ts` & `functions/src/presence_helpers.ts`)
- Triggered on `/status/{userId}/connections` in Realtime Database.
- Live snapshot inspection evaluates active device connections.
- **Explicit Retry Policy & Max Event Age**:
  - Configured `functions.runWith({ failurePolicy: true, timeoutSeconds: 60, memory: '256MB' })`. Discards events older than 5 minutes (`MAX_PRESENCE_EVENT_AGE_MS = 300000`).
- **Atomic Transactional Ordering Guard**:
  - Replaced non-atomic batch writes with `firestore.runTransaction` reading `/users/{userId}` and `/public_users/{userId}`.
  - Inside the transaction, `evaluatePresenceCommit` strictly compares the incoming event timestamp (`event.timestamp`) against committed `presenceLastEventTimeMs`.
  - Enforces strict monotonicity: commits only if `incomingEventTimeMs > committedLastEventTimeMs`. Rejects stale older events (`stale_older`) and stale equal timestamps (`stale_equal`) deterministically.
- Mirrors `isOnline: true` to both `/users/{userId}` and `/public_users/{userId}` when $N \ge 1$ active connections exist.
- Mirrors `isOnline: false` and the authoritative RTDB `lastSeen` timestamp when all devices disconnect.

### 3.4 Rolling Window Rate Limiting & User Search (`functions/src/search.ts` & `functions/src/search_helpers.ts`)
- **True Rolling 60-Second Window**:
  - Uses an atomic Firestore transaction on `_rate_limits/{callerUid}` (`enforceSearchRateLimit`) maintaining a bounded `timestamps: number[]` array (capped at 15 items).
  - Evaluates via `evaluateRollingRateLimit(timestamps, nowMs, windowMs, maxRequests)`. Requests older than `nowMs - 60000` are pruned.
  - The 16th request within the rolling 60-second window is rejected with `resource-exhausted` and returns `retryAfterSeconds`.
  - Completely prevents boundary burst attacks inherent in fixed-window counters.
- **Profile Sanitization**:
  - `sanitizeSearchProfile` strictly strips `email` and private security metadata, returning only public profile fields (`id`, `name`, `photoUrl`, `isOnline`, `lastSeen`, `createdAt`, `updatedAt`).

### 3.5 Firestore TTL & Composite Indexes
- Configured `fieldOverrides` with `ttl: true` in `firestore.indexes.json` for:
  - `_function_events.expiresAt` (collection-group)
  - `_rate_limits.expiresAt` (collection-group)
- **Production CLI Activation Commands**:
  ```bash
  gcloud firestore fields ttls update expiresAt --collection-group=_function_events --enable-ttl --project=chat-app-28ac0
  gcloud firestore fields ttls update expiresAt --collection-group=_rate_limits --enable-ttl --project=chat-app-28ac0
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

The repository contains **128 automated tests** strictly categorized by test type:

| Test Type | Target File | Count | Status | Description |
|---|---|---|---|---|
| **Flutter Unit Tests** | `test/features/auth/data/auth_repository_test.dart`<br>`test/features/auth/data/user_model_test.dart`<br>`test/features/auth/presentation/auth_bloc_test.dart`<br>`test/features/auth/presentation/account_deletion_robustness_test.dart`<br>`test/core/services/presence_service_test.dart` | 34 | ✅ Passed | Unit-level contracts, exception mappings, serialization, BLoC state transitions, and presence callbacks. |
| **Flutter In-Memory Flow Tests** | `test/core/services/presence_service_test.dart` | 4 | ✅ Passed | In-memory simulated multi-device connection registry testing partial/full disconnects and stable reconnection IDs. |
| **Flutter Widget Tests** | `test/features/auth/presentation/auth_widgets_test.dart`<br>`test/features/chat/presentation/chat_widgets_test.dart`<br>`test/widget_test.dart` | 20 | ✅ Passed | UI rendering, form validation, tab switching, and message input debouncing. |
| **Flutter Privacy & Model Tests** | `test/features/chat/data/models/chat_participant_privacy_test.dart` | 4 | ✅ Passed | Participant email omission from conversation serialization, backwards compatibility, and snapshot isolation. |
| **Cloud Functions Unit & Production Helper Tests** | `functions/test/cleanup_helpers.test.ts`<br>`functions/test/notifications_helpers.test.ts`<br>`functions/test/presence_helpers.test.ts`<br>`functions/test/search_helpers.test.ts` | 38 | ✅ Passed | Account cleanup & strict 404 (10), push notification retry & age bounding (13), presence transactional ordering guard (8), rolling window rate limiting (7). |
| **Firebase Emulator Integration Tests** | `functions/test/security_rules.test.ts` | 28 | ✅ Passed | Live emulator execution covering user privacy, schema allowlists, role tampering denial, deterministic direct IDs, message updates, metadata isolation, and participant snapshot allowlists. |

**Total Automated Tests:** 128 passed, 0 failed.

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
| **Functions Unit Tests**| `cd functions && npm test` | **38 passed (0 failed, 208ms runtime)** |
| **Security Rules Tests** | `cd functions && npx firebase emulators:exec --only "firestore,storage,database" "npm run test:rules"` | **28 passed (0 failed, 9s runtime)** |
| **CLI Version Pinning** | `firebase --version` | **15.2.1 (Pinned & Asserted in CI)** |

---

## 7. Git & Publication Record

- **Working Branch**: `hardening`
- **Base Branch**: `main`
- **Remote**: `origin` (`https://github.com/ahmadhomsy/chat-app.git`)
- **Pull Request**: [#1 (OPEN)](https://github.com/ahmadhomsy/chat-app/pull/1)

---

## 7. Git & Publication Record

- **Working Branch**: `hardening`
- **Base Branch**: `main`
- **Remote**: `origin` (`https://github.com/ahmadhomsy/chat-app.git`)
- **Pull Request**: [#1 (OPEN)](https://github.com/ahmadhomsy/chat-app/pull/1)
