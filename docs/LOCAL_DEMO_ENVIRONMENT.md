# ChatUp — Local Portfolio Demo Environment (Zero Billing)

## Overview

This guide provides instructions for setting up and running a completely isolated, zero-cost demonstration environment for **ChatUp** using the **Firebase Local Emulator Suite**.

ChatUp is configured to run fully offline for portfolio demonstrations and local evaluations:
- **Zero Blaze Plan Requirement**: Runs 100% locally on the free emulator suite.
- **Zero Billing Impact**: No credit card, billing account, or cloud resource consumption required.
- **Strict Environment Isolation**: Uses dedicated offline project ID `demo-chatup`, preventing any network traffic or credentials from touching Production (`chat-app-28ac0`) or Staging (`study-buddy-54266`).
- **Initial Portfolio Scope**: Text-only 1-on-1 messaging, group messaging, real-time presence, user search, and authentication.

---

## 🛠️ Required Tooling

Ensure your workstation meets the following prerequisites:

| Tool | Recommended Version | Verification Command | Notes |
|---|---|---|---|
| **Flutter SDK** | `3.41.9` (stable) | `flutter --version` | Framework runtime |
| **Dart SDK** | Included with Flutter | `dart --version` | Programming language runtime |
| **Node.js** | `v22.x` | `node -v` | Required for Cloud Functions & Emulators |
| **Java JDK** | `21` or `22` (Temurin / Oracle) | `java -version` | Required by Firebase Local Emulator Suite |
| **Firebase CLI** | `15.2.1` | `firebase --version` | Install via `npm install -g firebase-tools@15.2.1` |
| **Android Studio / SDK** | API 34+ | `flutter doctor` | Android Virtual Device (AVD) management |

---

## 📐 Architecture & Port Allocation

The Local Demo Environment uses dedicated local ports mapped in `firebase.json`:

| Service | Port | Host (Host OS) | Host (Android AVD) | Description |
|---|---|---|---|---|
| **Authentication** | `9099` | `127.0.0.1:9099` | `10.0.2.2:9099` | Local account creation, email verification |
| **Cloud Firestore** | `8080` | `127.0.0.1:8080` | `10.0.2.2:8080` | User profiles, chats, messages |
| **Realtime Database** | `9000` | `127.0.0.1:9000` | `10.0.2.2:9000` | Multi-device online presence |
| **Cloud Functions** | `5001` | `127.0.0.1:5001` | `10.0.2.2:5001` | Server search, presence aggregation |
| **Cloud Storage** | `9199` | `127.0.0.1:9199` | `10.0.2.2:9199` | Local mock bucket (`demo-chatup.appspot.com`) |
| **Emulator Suite UI** | `4000` | `http://127.0.0.1:4000` | N/A | Interactive web console to view data |

---

## 🚀 Step-by-Step Local Run Instructions

### 1. Build Cloud Functions

From the repository root in PowerShell:

```powershell
cd functions
npm install
npm run build
cd ..
```

### 2. Start Firebase Local Emulator Suite

Launch the emulator suite targeting the offline demo project `demo-chatup`:

```powershell
firebase emulators:start --project demo-chatup
```

> [!TIP]
> To preserve emulator state across restarts during long demonstration sessions, you can optionally supply an export directory:
> ```powershell
> firebase emulators:start --project demo-chatup --import=./emulator-data --export-on-exit
> ```

Open `http://127.0.0.1:4000` in your web browser to view the **Firebase Emulator Suite UI**.

### 3. Launch Android Virtual Devices (AVDs)

For interactive demonstration of real-time messaging, launch two separate AVD instances:

1. Open Android Studio → **Device Manager**.
2. Start two virtual devices (e.g., `Pixel_7_API_34` and `Pixel_6_API_34`).
3. Verify connected devices:
   ```powershell
   flutter devices
   ```

### 4. Run the Flutter App in Development Flavor

In terminal window 1 (Device A):
```powershell
flutter run -d <DEVICE_ID_1> --flavor development -t lib/main_development.dart
```

In terminal window 2 (Device B):
```powershell
flutter run -d <DEVICE_ID_2> --flavor development -t lib/main_development.dart
```

---

## 👥 Interactive Demonstration Scenarios

### Scenario A: Account Creation & Local Email Verification

1. On **Device A**, tap **Sign Up**:
   - Name: `Alice Walker`
   - Email: `alice@example.com`
   - Password: `Password123!`
2. On **Device B**, tap **Sign Up**:
   - Name: `Bob Vance`
   - Email: `bob@example.com`
   - Password: `Password123!`
3. Verify Email in the Emulator UI:
   - Navigate to `http://127.0.0.1:4000/auth` in your browser.
   - For `alice@example.com` and `bob@example.com`, toggle or click **Verify Email** (or use the verification link printed in the terminal).
4. Tap **I have verified my email** or log in on both devices.

### Scenario B: 1-on-1 Text Messaging

1. On **Device A**, tap the search icon and search for `bob@example.com`.
2. Select Bob from the search results to open the conversation.
3. Send a message: `"Hello Bob, welcome to ChatUp demo!"`.
4. Observe on **Device B**:
   - The message appears in real time.
   - Read receipt indicators update when Bob views the chat.
   - Type a response: `"Hi Alice! Real-time local sync works!"`.

### Scenario C: Multi-Device Real-Time Presence

1. Observe the green online indicator next to Alice's profile on Bob's screen.
2. Background or close Device A:
   - Within seconds, Alice's status transitions to offline with an accurate `lastSeen` timestamp in Realtime Database and Firestore.
3. Bring Device A back to foreground:
   - Status instantly updates back to online.

### Scenario D: Group Messaging

1. On **Device A**, tap **New Group**:
   - Group Name: `Portfolio Review Team`
   - Add participant: `Bob Vance`
2. Send messages to the group.
3. Confirm that both Alice and Bob receive all group messages instantly with participant names and timestamps.

---

## 🔒 Security & Isolation Guarantees

1. **Hard Fail-Closed Guards in Code**:
   - `Bootstrap.validateConfiguration()` in `lib/core/bootstrap/bootstrap.dart` enforces that `useEmulators: true` rejects Production (`chat-app-28ac0`) or Staging (`study-buddy-54266`) options, throwing an uncatchable `StateError`.
2. **Native Android Flavor Isolation**:
   - `android/app/src/development/google-services.json` configures `package_name: com.example.chat_app.dev` against `demo-chatup`.
   - `android/app/build.gradle.kts` enforces that `src/development/google-services.json` must exist before Gradle executes any development build tasks, preventing silent fallback to production credentials.
3. **Telemetry & Push Deactivation**:
   - `android/app/src/development/AndroidManifest.xml` deactivates Google Analytics, Crashlytics, and Performance collection.
   - `Bootstrap.init` skips push notification initialization when `useEmulators: true`, preventing FCM network calls.
4. **Authoritative Staging Preservation**:
   - Staging configurations in `lib/firebase_options_staging.dart` (`authoritativeStorageBucket = null`) remain untouched and safe.
