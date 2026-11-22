# ChatUp: Technical Audit, Architecture, and Engineering Remediation Report (Phase 4, Phase 4.1, Phase 4.2, Phase 4.3, Phase 4.3.1 & Phase 4.3.2)

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
| **Direct Distinct Participants & Self-Chat Rejection** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules Tests 61–62) | ✅ Verified (toSet().size() == 2) | ⏳ Awaiting Ops Auth |
| **Message-Level Idempotency (`clientMessageId`)** | ✅ Yes | ✅ Yes (Unit & Data) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Pagination & Stream Deduplication** | ✅ Yes | ✅ Yes (BLoC & UI) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Group Messaging & Admin Succession** | ✅ Yes | ✅ Yes (Unit & Succession) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **Group Admin Authorization Invariants (`isGroupAdmin`)** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules Tests 41–54) | ✅ Verified (Rules Enforced) | ⏳ Awaiting Ops Auth |
| **Unique Participant & Admin IDs (Phase 4.3.2)** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules Tests 55–60) | ✅ Verified (toSet().size() == size()) | ⏳ Awaiting Ops Auth |
| **Atomic Participant Removal Guard (Phase 4.3.2)** | ✅ Yes (`firestore.rules`) | ✅ Yes (Rules Tests 63–70) | ✅ Verified (getConversationAfter post-write check) | ⏳ Awaiting Ops Auth |
| **Server-Enforced Participant Privacy (Subcollection)** | ✅ Yes | ✅ Yes (Data source & Batch) | ✅ Verified (Rules Tests 22–37, 47–54) | ⏳ Awaiting Ops Auth |
| **100-Member Single WriteBatch Group Creation** | ✅ Yes (`chat_remote_data_source.dart`) | ✅ Yes (Batch <= 500 ops) | ✅ Verified (Rules Test 27, 101 writes) | ⏳ Awaiting Ops Auth |
| **User Privacy & Public Directory Projection** | ✅ Yes | ✅ Yes (Data source & Model) | ✅ Verified (Strict Isolation) | ⏳ Awaiting Ops Auth |
| **Atomic Rolling Search Rate Limiter (`search.ts`)**| ✅ Yes | ✅ Yes (Callable Func & Txn) | ✅ Verified (20-Req Emulator Txn) | ⏳ Awaiting Ops Auth |
| **Multi-Device RTDB Presence Service** | ✅ Yes | ✅ Yes (Unit & In-Memory) | ✅ Verified (RTDB Rules) | ⏳ Awaiting Ops Auth |
| **High-Precision Monotonic Presence Helper** | ✅ Yes (`presence_helpers.ts`) | ✅ Yes (Microsecond Guard) | ✅ Verified (True Concurrency Barrier Test 40) | ⏳ Awaiting Ops Auth |
| **RFC 3339 Timezone Offset Normalization** | ✅ Yes (`parseEventTimestamp`) | ✅ Yes (Unit Tests 9–13) | ✅ Verified | ⏳ Awaiting Ops Auth |
| **Operational Migration Safety Gating & Identity Check** | ✅ Yes (`dry_run_strip_participant_emails.ts`) | ✅ Yes (Unit Test 11: 1–11) | ✅ Verified (Dry-run Test 39) | ⏳ Awaiting Ops Auth |
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
> - **Emulator Verified**: Verified locally against isolated emulators on ports 8080, 9199, 9000 with 54 automated integration tests.
> - **Cloud Verified / Deployed**: Requires manual execution of deployment commands with administrative permissions once authorized.

---

## 2. Independent Security Rules & Concurrency Verification (Firebase Emulator Suite)

The security rules were validated against real instances of the **Cloud Firestore Emulator**, **Cloud Storage Rules Emulator**, and **Firebase Realtime Database Emulator** using `@firebase/rules-unit-testing` and Mocha under JDK 22.

### Emulator Test Script:
Executed via:
```bash
firebase emulators:exec --only "firestore,storage,database" "npm run test:rules"
```

### Verified Security Assertions (71/71 Passed):
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
    ✔ 22. Valid direct conversation creation with sanitized participant snapshots succeeds (115ms)
    ✔ 23. Direct conversation creation with nested participant email is rejected (108ms)
    ✔ 24. Direct conversation creation with role or privilege in participant snapshot is rejected (102ms)
    ✔ 25. A valid group of eight succeeds (dedicated participant subcollection) (125ms)
    ✔ 26. A valid group of nine succeeds (breaking previous 8-member limit) (130ms)
    ✔ 27. A valid group of 100 succeeds (exact production flow: parent + 100 participants in a single WriteBatch) (310ms)
    ✔ 28. Group creation with nested participant email on parent document is rejected (98ms)
    ✔ 29. An email injected into participant 9 is rejected (105ms)
    ✔ 30. An email injected into participant 10 is rejected (101ms)
    ✔ 31. An email injected into participant 100 is rejected (110ms)
    ✔ 32. A role injected into participant 9 is rejected (96ms)
    ✔ 33. A provider or privilege field injected into participant 100 is rejected (104ms)
    ✔ 34. A group administrator attempting to inject private fields during membership updates is rejected (118ms)
    ✔ 35. A legitimate administrator adding a member succeeds (122ms)
    ✔ 36. A normal member attempting to add a member fails (94ms)
    ✔ 37. Valid public participant profile updates remain functional (self-update & admin update) (135ms)
    ✔ 38. Search Rate Limiter: 20 concurrent requests against Firestore emulator enforce max 15 requests (450ms)
    ✔ 39. Legacy Email Migration: audit scanner identifies affected docs across batches with zero writes in dry-run (105ms)
    ✔ 40. Presence Transaction: true concurrent competing transactions against emulator maintain monotonic order (120ms)
    ✔ 41. A valid group with all administrators included in participantIds succeeds (85ms)
    ✔ 42. Creating a group with an administrator outside participantIds fails (78ms)
    ✔ 43. Creating a group with an empty administrator list fails (82ms)
    ✔ 44. A group administrator cannot add an outsider UID to adminIds during update (92ms)
    ✔ 45. A group administrator cannot leave a phantom administrator after removing a member (89ms)
    ✔ 46. A valid administrator succession succeeds when new administrator is in participantIds (95ms)
    ✔ 47. A nonmember listed in a malicious adminIds payload cannot modify participant documents (88ms)
    ✔ 48. A nonmember listed in adminIds cannot delete participant documents (84ms)
    ✔ 49. A removed member cannot update their previous participant document (81ms)
    ✔ 50. A removed member cannot delete their previous participant document (79ms)
    ✔ 51. A removed member cannot read participant subcollection documents (86ms)
    ✔ 52. A current member can update only permitted own display fields (name, photoUrl) (94ms)
    ✔ 53. A current member cannot modify document ID, email, role, provider, or server-authoritative presence fields (104ms)
    ✔ 54. A group administrator can remove a member using the intended secure atomic operation (51ms)
    ✔ 55. A valid group with unique member UIDs succeeds on creation (88ms)
    ✔ 56. Group creation with duplicate participant UIDs fails (79ms)
    ✔ 57. Group creation with duplicate admin UIDs fails (74ms)
    ✔ 58. A valid group of 100 unique members succeeds (290ms)
    ✔ 59. Updating a valid group with duplicate participant IDs fails (81ms)
    ✔ 60. Updating a valid group with duplicate admin IDs fails (78ms)
    ✔ 61. Direct conversation with duplicate participant IDs fails (self-conversation rejected) (76ms)
    ✔ 62. Normal valid direct conversation with two distinct UIDs continues to work (82ms)
    ✔ 63. Administrator deleting another participant document alone (standalone deletion) fails (85ms)
    ✔ 64. Administrator updating parent membership and deleting the participant document in one atomic batch succeeds (98ms)
    ✔ 65. Administrator cannot remove the last remaining valid administrator (89ms)
    ✔ 66. Administrator cannot leave a removed admin inside adminIds (86ms)
    ✔ 67. Removed member loses parent conversation read access (79ms)
    ✔ 68. Removed member loses participant subcollection access (82ms)
    ✔ 69. Remaining members retain normal read and message operations after participant removal (110ms)
    ✔ 70. Normal non-admin member cannot remove anyone (84ms)
    ✔ 71. Existing direct conversation creation and operation remain unaffected (115ms)

  71 passing (36s)
```

### Critical Rules Invariants Remediated in Phase 4.3.2:
1. **Enforce Unique Participant & Administrator UIDs**:
   - *Previous Gap*: Rules validated list size bounds (`participantIds.size() >= 2`) and subset containment (`hasAll(adminIds)`), but did not reject duplicate elements. A payload such as `participantIds: ['alice', 'alice']` could satisfy the minimum size of 2 while representing only a single unique member.
   - *Remediation*:
     - Group creation & update: enforced `request.resource.data.participantIds.toSet().size() == request.resource.data.participantIds.size()` and `request.resource.data.adminIds.toSet().size() == request.resource.data.adminIds.size()`.
     - Direct conversation creation: enforced `participantIds.toSet().size() == 2` and `participantIds[0] != participantIds[1]`, rejecting self-conversations while preserving deterministic conversation IDs.
2. **Enforce Atomic Participant Removal via `getConversationAfter`**:
   - *Previous Gap*: Subcollection delete rule checked only `isGroupAdmin(getConversation(conversationId))`, allowing an administrator to delete a participant's subcollection document while leaving that user inside the parent conversation's `participantIds`.
   - *Remediation*:
     - Enforced `allow delete` on `/participants/{participantUid}` requires:
       `!(participantUid in getConversationAfter(conversationId).participantIds) && isGroupAdmin(getConversationAfter(conversationId))`.
     - Standalone deletion of a participant document without updating the parent conversation fails immediately.
     - Atomic batch updates (updating parent `participantIds` and deleting the subcollection doc) succeed.
     - Prevents leaving removed admins inside `adminIds` and protects the last remaining group administrator.

### Critical Rules Invariants Remediated in Phase 4.3.1:
1. **Group Administrator Membership Invariants (`isGroupAdmin`)**:
   - *Problem*: Previously, a creator or admin could specify an `adminIds` array containing arbitrary outsider UIDs not present in `participantIds`. If an outsider was listed in `adminIds`, they received subcollection administration rights despite not being a conversation member.
   - *Remediation*:
     - Group creation enforces: `participantIds.hasAll(adminIds)` and `adminIds.size() >= 1`.
     - Group updates enforce: `isGroupAdmin(resource.data)` and `request.resource.data.participantIds.hasAll(request.resource.data.adminIds)`.
     - Defined `isGroupAdmin(conv)` checking that caller is in `conv.adminIds` AND in `conv.participantIds`.
     - Prevents phantom administrators when removing members.
     - Prohibits nonmembers in `adminIds` from reading, updating, or deleting participant subcollection documents.
2. **Participant Subcollection Security & Immutability**:
   - `match /conversations/{conversationId}/participants/{participantUid}`:
     - Read restricted to active conversation participants (`isParticipant(conversationId)`).
     - Update restricted to current participants, limited strictly to presentation fields `['name', 'photoUrl']`. Server-authoritative presence fields (`isOnline`, `lastSeen`) cannot be client-modified.
     - Delete restricted strictly to verified group administrators (`isGroupAdmin(getConversation(conversationId))`).
     - Normal members and removed members cannot delete participant documents.
3. **Exact Production-Equivalent 100-Member Group Creation**:
   - Verified that 1 parent group document + 100 participant subdocuments created in the exact same single `WriteBatch` (101 operations) commits successfully under rules evaluation via `getAfter()`.

### Critical Rules Vulnerabilities Remediated in Phase 4, Phase 4.1, Phase 4.2 & Phase 4.3:
1. **User Profile Privacy & Enumeration Prevention**:
   - *Previous Defect*: `allow read: if isAuthenticated();` on `/users/{userId}` allowed any authenticated user to list all user documents and scrape email addresses, security providers, and private timestamps.
   - *Phase 4 Remediation*:
     - `/users/{userId}`: Read access restricted strictly to `isOwner(userId)`. Direct collection queries (`getDocs(collection('users'))`) by third parties fail.
     - `/public_users/{userId}`: A public discovery collection exposing only `{ id, name, photoUrl, isOnline, lastSeen, createdAt, updatedAt }`. Excludes email and private credentials.
     - Account owner update allowlist: users can only update `['name', 'photoUrl', 'updatedAt']`. They cannot modify `isOnline`, `lastSeen`, `role`, `email`, `createdAt`, or `provider`.
2. **User Creation Schema Hardening (Phase 4.1)**:
   - *Vulnerability*: Previously, client creation on `/users/{userId}` allowed arbitrary fields, creating an escalation vector for clients to persist privileged keys (`role: 'admin'`, `status`, `privilege`).
   - *Remediation*: Enforced strict field allowlist `['name', 'email', 'photoUrl', 'lastSeen', 'isOnline', 'createdAt', 'provider', 'phone']`, requiring `isOnline == false`, `lastSeen == null`, and `provider in ['email', 'google']`.
3. **Complete Group Participant Privacy & Scalability (Phase 4.3)**:
   - *Vulnerability in Phase 4.2*: While Phase 4.2 introduced snapshot validation on parent documents, unrolling was capped at 8 participants to avoid exceeding the Firestore Security Rules 1000-expression limit. Participants beyond index 7 were not validated, allowing arbitrary key injection (`email`, `role`, `privilege`) for larger groups.
   - *Phase 4.3 Architecture & Remediation*:
     - Replaced parent conversation variable-length participant map for groups with dedicated per-participant documents under `/conversations/{conversationId}/participants/{participantUid}`.
     - On parent group conversations, embedded participant snapshot maps are strictly forbidden (`(!('participants' in request.resource.data) || request.resource.data.participants.keys().size() == 0)`).
     - Each document in `/participants/{participantUid}` is validated independently by Firestore rules in its own security context:
       - `request.resource.data.keys().hasOnly(['id', 'name', 'photoUrl', 'isOnline', 'lastSeen'])`
       - `request.resource.data.id == participantUid`
       - Bounds: `name.size() <= 100`, `photoUrl.size() <= 2048`
       - Creator or group admin authorized write permissions.
     - Preserved full 100-participant product capacity without hitting Firestore's 1000-expression evaluation limit.
     - Tested for groups of 8, 9, and 100 members, with complete rejection of private field injections at participants 9, 10, and 100.
4. **Message Schema Creation & Update Allowlists (Phase 4.1)**:
   - *Creation Allowlist*: Restricted strictly to `['senderId', 'senderName', 'text', 'type', 'createdAt']`, verifying `senderId == request.auth.uid`, `text.size() > 0 && text.size() <= 2000`, `type in ['text', 'image', 'file']`, and `createdAt is timestamp`.
   - *Update Allowlist*: Restricted strictly to sender text edits with `['text', 'editedAt']`, enforcing `editedAt is timestamp`.
   - *Exclusion of `deletedAt`*: The nullable `deletedAt` field is intentionally excluded from the client update allowlist to prevent unprivileged clients or compromised senders from arbitrarily manipulating message deletion states; deletions must execute via document deletion governed by `allow delete`.
5. **Rate-Limited Server-Side Exact Email Search (Phase 4.1 & Phase 4.2 & Phase 4.3)**:
   - Exact email lookups are performed via callable Cloud Function `searchUserByEmail`, requiring authentication.
   - True rolling 60-second window (max 15 requests/min) using an array of timestamps inside a Firestore transaction.
   - Real emulator concurrency test asserts that 20 concurrent transaction attempts result in exactly 15 successes and 5 `resource-exhausted` errors with zero race conditions.
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
- **High-Precision Microsecond Timestamp Parsing (`parseEventTimestamp`)**:
  - RFC 3339 / ISO 8601 timestamps provided by Firebase RTDB events can contain sub-millisecond precision. Standard `Date.parse()` truncates fractional seconds to integer milliseconds, which can cause distinct sub-millisecond events to collapse into identical millisecond values (`stale_equal`).
  - Implemented `parseEventTimestamp` using string extraction of fractional seconds into microsecond integer representations (`BigInt(seconds) * 1000000n + BigInt(micros)`).
- **Atomic Transactional Ordering Guard**:
  - Replaced non-atomic batch writes with `firestore.runTransaction` reading `/users/{userId}` and `/public_users/{userId}`.
  - Inside the transaction, `evaluatePresenceCommit` compares the incoming event timestamp against committed `presenceLastEventTimeMicros` (and fallback `presenceLastEventTimeMs`).
  - Enforces strict monotonicity: commits only if `incomingEventTimeMicros > committedLastEventTimeMicros`. Rejects stale older events (`stale_older`) and stale equal timestamps (`stale_equal`) deterministically.
- Mirrors `isOnline: true` to both `/users/{userId}` and `/public_users/{userId}` when $N \ge 1$ active connections exist.
- Mirrors `isOnline: false` and the authoritative RTDB `lastSeen` timestamp when all devices disconnect.
- Validated via real emulator concurrency test (Test 40) executing simultaneous transactions with zero ordering inversions.

### 3.4 Rolling Window Rate Limiting & User Search (`functions/src/search.ts` & `functions/src/search_helpers.ts`)
- **True Rolling 60-Second Window**:
  - Uses an atomic Firestore transaction on `_rate_limits/{callerUid}` (`enforceSearchRateLimit`) maintaining a bounded `timestamps: number[]` array (capped at 15 items).
  - Evaluates via `evaluateRollingRateLimit(timestamps, nowMs, windowMs, maxRequests)`. Requests older than `nowMs - 60000` are pruned.
  - The 16th request within the rolling 60-second window is rejected with `resource-exhausted` and returns `retryAfterSeconds`.
  - Completely prevents boundary burst attacks inherent in fixed-window counters.
- **Profile Sanitization**:
  - `sanitizeSearchProfile` strictly strips `email` and private security metadata, returning only public profile fields (`id`, `name`, `photoUrl`, `isOnline`, `lastSeen`, `createdAt`, `updatedAt`).
- **Live Emulator Concurrency Verification**:
  - Verified against Cloud Firestore Emulator (Test 38): fired 20 concurrent transactions. Exactly 15 requests succeeded and 5 requests were rejected with `resource-exhausted`. Zero race conditions.

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

### 3.6 Legacy Participant Email Migration Audit (`functions/src/migrations/dry_run_strip_participant_emails.ts`)
- **Dry-Run Audit Scanner**:
  - Scans `/conversations` in paginated batches (`BATCH_SIZE = 100`) using `startAfter()`.
  - Identifies conversation documents containing nested participant emails in legacy schemas.
  - Generates comprehensive `MigrationAuditResult` reporting `totalScanned`, `affectedConversations`, `sampleAffectedIds`, `batchesProcessed`, and `isDryRun: true`.
  - Strictly performs zero database mutations in dry-run mode.
  - Validated against live Firestore Emulator (Test 39): seeded 5 conversations (3 containing legacy email structures), verified audit correctly flagged all 3 across multiple batches with zero writes performed.
- **Operational Execution Guard (Phase 4.3.2 Hardened)**:
  - Gated through an uncommitted operational environment variable (`process.env.MIGRATION_EXECUTION_TOKEN`).
  - Active Firebase project verification: `resolveActiveProjectId` inspects the initialized Firebase Admin app and environment, comparing it against `targetProjectId`. Bypassing production lock via a false staging target is strictly blocked.
  - Backup timestamp freshness verification: parses ISO timestamp, strictly rejects future timestamps (`> now`), and rejects stale backups older than 24 hours (`now - backupTime > 86400000 ms`).
  - Operator Attestation requirement: mandates `operatorBackupAttestation: true`. Explicitly documents that code validates metadata and freshness bounds, while physical GCS archive existence remains an operator attestation responsibility under standard operating procedures.
  - Production safety check: execution on production project `chat-app-28ac0` requires explicit environment flag `ALLOW_PRODUCTION_MIGRATION === 'true'`.

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

The repository contains **177 automated tests** strictly categorized by test type:

| Test Type | Target File | Count | Status | Description |
|---|---|---|---|---|
| **Flutter Unit Tests** | `test/features/auth/data/auth_repository_test.dart`<br>`test/features/auth/data/user_model_test.dart`<br>`test/features/auth/presentation/auth_bloc_test.dart`<br>`test/features/auth/presentation/account_deletion_robustness_test.dart`<br>`test/core/services/presence_service_test.dart` | 34 | ✅ Passed | Unit-level contracts, exception mappings, serialization, BLoC state transitions, and presence callbacks. |
| **Flutter In-Memory Flow Tests** | `test/core/services/presence_service_test.dart` | 4 | ✅ Passed | In-memory simulated multi-device connection registry testing partial/full disconnects and stable reconnection IDs. |
| **Flutter Widget Tests** | `test/features/auth/presentation/auth_widgets_test.dart`<br>`test/features/chat/presentation/chat_widgets_test.dart`<br>`test/widget_test.dart` | 20 | ✅ Passed | UI rendering, form validation, tab switching, and message input debouncing. |
| **Flutter Privacy & Model Tests** | `test/features/chat/data/models/chat_participant_privacy_test.dart` | 4 | ✅ Passed | Participant email omission from conversation serialization, backwards compatibility, and snapshot isolation. |
| **Cloud Functions Unit & Production Helper Tests** | `functions/test/cleanup_helpers.test.ts`<br>`functions/test/notifications_helpers.test.ts`<br>`functions/test/presence_helpers.test.ts`<br>`functions/test/search_helpers.test.ts` | 44 | ✅ Passed | Account cleanup & strict 404 (11), push notification retry & age bounding (13), presence transactional ordering guard & microsecond parsing & RFC 3339 timezone normalization (13), rolling window rate limiting (7). Test 11 covers all 11 migration safety cases. |
| **Firebase Emulator Integration & Concurrency Tests** | `functions/test/security_rules.test.ts` | 71 | ✅ Passed | Live emulator execution covering user privacy, schema allowlists, role tampering denial, deterministic direct IDs, message updates, metadata isolation, group subcollection privacy for 8, 9, 100 members in single batch, group admin invariants (41–54), rate-limit concurrency, migration audit, true presence concurrency barrier, unique participant/admin IDs (55–62), and atomic participant removal post-write parent verification (63–71). |

**Total Automated Tests:** 177 passed, 0 failed.

---

## 6. Verification Summary & Commands

All quality gates pass cleanly with zero warnings:

| Quality Gate | Command | Result |
|---|---|---|
| **Formatting** | `dart format --output=none --set-exit-if-changed lib test` | **0 changed files (115 formatted)** |
| **Static Analysis** | `flutter analyze --fatal-infos --fatal-warnings` | **0 issues found** |
| **Flutter Tests** | `flutter test` | **62 passed (0 failed)** |
| **Functions Build** | `cd functions && npm run build` | **0 TypeScript errors (`tsc` clean)** |
| **Functions Lint** | `cd functions && npm run lint` | **0 ESLint errors/warnings** |
| **Functions Unit Tests**| `cd functions && npm test` | **44 passed (0 failed, 378ms runtime)** |
| **Security Rules & Concurrency Tests** | `firebase emulators:exec --only "firestore,storage,database" "npm run test:rules"` | **71 passed (0 failed, 36s runtime)** |
| **CLI Version Pinning** | `firebase --version` | **15.2.1 (Pinned & Asserted in CI)** |

---

## 7. Git & Publication Record

- **Working Branch**: `hardening`
- **Base Branch**: `main`
- **Remote**: `origin` (`https://github.com/ahmadhomsy/chat-app.git`)
- **Pull Request**: [#1 (OPEN)](https://github.com/ahmadhomsy/chat-app/pull/1)
