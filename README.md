# ChatUp – Real-Time Flutter Chat Application

A high-performance, production-ready real-time chat application built with **Flutter**, **Firebase**, **Clean Architecture**, and **BLoC/Cubit**.

---

## 📱 Features

- **Robust Authentication**:
  - Email & Password sign-up and sign-in with live email verification check.
  - Google Sign-In with lifecycle safety and graceful cancellation handling.
  - End-to-end Password Reset with dedicated UI feedback.
  - Safe account deletion flow (revokes authentication before deleting user data).
- **Real-Time 1-on-1 Messaging**:
  - Deterministic conversation IDs preventing duplicate direct conversations.
  - Real-time Firestore synchronization for messages and previews.
  - Read receipts and unread conversation indicators.
  - Reverse scroll pagination with automatic older message fetching.
- **Group Conversations**:
  - Create groups with custom names, avatars, and member selections.
  - Admin controls and participant list visibility.
- **User Discovery & Search**:
  - Instant user directory search by name or email.
  - One-tap conversation initialization.
- **Presence & Activity**:
  - Lifecycle-aware online/offline presence tracking (`AppLifecycleListener`).
  - `lastSeen` server timestamps.
- **Push Notification Integration**:
  - Firebase Cloud Messaging token synchronization.
  - Foreground notifications and deep linking to conversations on tap.
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
│   ├── services/           # PresenceService, NotificationService
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
3. **Typed Functional Error Handling**: Repositories wrap data operations using `dartz` `Either<Failure, T>`. Raw exceptions never reach presentation widgets.
4. **Testability**: Dependencies are injected through `GetIt`, enabling mocking and unit testing without network dependencies.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `^3.24.0` (Recommended: `3.41.x` stable)
- **Dart SDK**: `^3.5.0` (Recommended: `3.11.x`)
- **Node.js** & **Firebase CLI**: `npm install -g firebase-tools`
- **FlutterFire CLI**: `dart pub global activate flutterfire_cli`

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

### 3. Deploy Firestore Rules and Indexes
To deploy the security rules and composite indexes:
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
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

ChatUp enforces strict linting via `very_good_analysis` and includes 39 unit, BLoC, and widget tests.

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
