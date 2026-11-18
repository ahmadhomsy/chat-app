# ChatUp – Real-Time Flutter Chat Application

A high-performance, production-ready real-time chat application built with **Flutter**, **Firebase**, **Clean Architecture**, and **BLoC/Cubit**.

Firebase Project: `chat-app-28ac0`

---

## 📱 Features

- **Robust Authentication**:
  - Email & Password sign-up and sign-in with live email verification check.
  - Google Sign-In with lifecycle safety and graceful cancellation handling.
  - End-to-end Password Reset with dedicated UI feedback.
  - Safe account deletion flow (handles reauthentication requirements, revokes auth credentials, and triggers authoritative background cleanup).
- **Real-Time 1-on-1 Messaging**:
  - Deterministic conversation IDs preventing duplicate direct conversations.
  - Self-chat prevention guards.
  - Real-time Firestore synchronization for messages and conversation previews.
  - Read receipts with atomic conversation-level tracking (`lastReadAtByUser`).
  - Reverse scroll pagination with automatic older message fetching and stream deduplication.
  - Send message debouncing to eliminate duplicate message submissions.
- **Group Conversations**:
  - Create groups with custom names, avatars, and member selections.
  - Admin controls and participant list visibility.
  - Strict security rules enforcing admin-only metadata and participant mutations.
- **User Discovery & Search**:
  - Safe user discovery: exact email lookup and case-sensitive prefix search to prevent full directory scraping.
  - One-tap conversation initialization.
- **Multi-Device Presence Architecture**:
  - Firebase Realtime Database connection registry (`/status/{userId}/connections/{deviceId}`).
  - Native `.onDisconnect().remove()` hooks ensuring accurate offline status on sudden crashes or network drops.
  - Multi-device awareness: user remains online as long as at least one active connection exists.
  - Server-side Cloud Function mirroring presence into Firestore `/users/{uid}`.
- **Server-Side Push Notifications & Cloud Functions**:
  - Cloud Functions (TypeScript) triggered on new message creation (`onNewChatMessage`).
  - Multicast notification dispatch via Firebase Admin SDK with automatic invalid token pruning.
  - Foreground notification presentation and direct conversation routing on tap.
- **Enterprise Security Rules**:
  - Comprehensive Firestore rules (`firestore.rules`) with participant authorization, private FCM token subcollections (`/users/{uid}/fcmTokens`), and message size limits (2000 chars).
  - Storage rules (`storage.rules`) verifying conversation membership before permitting attachment downloads.
  - Realtime Database rules (`database.rules.json`) restricting connection management to owner.
- **Modern Dark UI**:
  - Elegant `#0E1621` dark navy theme with blue accent colors and responsive layout via `flutter_screenutil`.

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

### Architectural Guarantees:
1. **Separation of Concerns**: Presentation widgets never communicate directly with Firebase. All interactions flow through BLoC/Cubit -> Use Cases -> Repositories -> Data Sources.
2. **Predictable State Flow**: Feature state is managed exclusively using BLoC and Cubit.
3. **Typed Functional Error Handling**: Repositories wrap data operations using `dartz` `Either<Failure, T>`. Raw exceptions never escape repository boundaries.
4. **Testability**: Dependencies are injected through `GetIt`, enabling mocking and unit testing without network dependencies.

---

## ⚡ Cloud Functions & Backend Services

Backend logic resides in the `functions/` directory, written in TypeScript with Firebase Functions SDK v5 and Firebase Admin SDK v12:

- **`onNewChatMessage`**: Listens to Firestore `conversations/{convId}/messages/{msgId}` onCreate. Fetches recipient FCM tokens from `/users/{uid}/fcmTokens`, excludes the sender, dispatches FCM multicast notifications, and automatically purges expired tokens (`messaging/invalid-registration-token`).
- **`onUserDeleted`**: Authoritative `functions.auth.user().onDelete` trigger. Recursively cleans up Firestore `/users/{uid}`, subcollection `/fcmTokens`, Storage `/avatars/{uid}/*`, and RTDB `/status/{uid}`.
- **`onUserStatusChanged`**: Listens to RTDB `/status/{userId}/connections`. Syncs aggregate presence (`isOnline`, `lastSeen`) to Firestore `/users/{userId}`.

### Building Cloud Functions
```bash
cd functions
npm install
npm run build
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `^3.24.0` (Recommended: `3.41.x` stable)
- **Dart SDK**: `^3.5.0` (Recommended: `3.11.x`)
- **Node.js** (v18 or v20) & **Firebase CLI**: `npm install -g firebase-tools`
- **FlutterFire CLI**: `dart pub global activate flutterfire_cli`
- **JDK 17** for Android Gradle builds; **JDK 21+** if running local Firebase Java emulators (`firebase emulators:start`).

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/ahmadhomsy/chat-app.git
cd chat_app
flutter pub get
```

### 2. Configure Firebase (Project ID: `chat-app-28ac0`)
The repository excludes private credentials and generated Firebase configuration files. Configure your local environment using FlutterFire CLI:

```bash
# Log in to Firebase
firebase login

# Configure FlutterFire for chat-app-28ac0
flutterfire configure --project=chat-app-28ac0 \
  --platforms=android,ios \
  --out=lib/firebase_options.dart
```

This command automatically generates:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 3. Deploy Security Rules, Indexes & Cloud Functions
To deploy security rules, composite indexes, Realtime Database rules, and Cloud Functions to `chat-app-28ac0`:
```bash
# Build Cloud Functions
cd functions && npm install && npm run build && cd ..

# Deploy all services
firebase deploy --only firestore:rules,firestore:indexes,storage,database,functions
```

---

## 🏃‍♂️ Running the Application

ChatUp supports `development` and `production` product flavors:

### Development Flavor
```bash
flutter run --flavor development --target lib/main_development.dart
```

### Production Flavor
```bash
flutter run --flavor production --target lib/main_production.dart
```

---

## 🧪 Quality Assurance & Testing

ChatUp enforces strict linting via `very_good_analysis` and includes **55 automated unit, BLoC, widget, and integration tests** (100% passing).

### Run Code Formatting Check
```bash
dart format --output=none --set-exit-if-changed .
```

### Format Codebase
```bash
dart format .
```

### Run Static Analysis
```bash
flutter analyze --fatal-infos --fatal-warnings
```

### Run Automated Tests
```bash
flutter test
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Run Backend Security Rules & Functions Tests
```bash
cd functions
npm test
```
*(Note: requires local Firebase emulators running on JDK 21+)*

---

## 🔄 CI/CD Pipeline

The repository includes a dedicated Continuous Integration workflow at `.github/workflows/ci.yaml`:
- Triggers on all pull requests and pushes to `main`.
- Runs `flutter pub get`, `dart format`, `flutter analyze`, and `flutter test`.
- Operates independently of Firebase distribution secrets, ensuring that community PRs and automated checks pass reliably without credential dependencies.

---

## 🔐 Android Release Signing

In `android/app/build.gradle.kts`, release builds default to debug signing for ease of initial development. 

For production release builds:
1. Generate an upload keystore:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (ignored by `.gitignore`):
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<path/to/upload-keystore.jks>
   ```
3. Update `android/app/build.gradle.kts` to load `key.properties` and assign `signingConfig = signingConfigs.getByName("release")`.

---

## 📄 License
This project is licensed under the MIT License.
