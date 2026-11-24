# ChatUp Staging Environment Integration Specification

## 1. Architectural Overview & Environment Separation

ChatUp uses dedicated, isolated Firebase environments to ensure absolute production data safety, zero cross-environment contamination, and deterministic application runtime initialization.

| Environment | Firebase Project ID | Firebase Project Number | Android Application ID | iOS Bundle Identifier | Entry Point | Firebase Options File |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Production** | `chat-app-28ac0` | `639830188590` | `com.example.chat_app` | `com.example.chatApp` | `lib/main_production.dart` | `lib/firebase_options.dart` |
| **Staging** | `study-buddy-54266` | `194789753908` | `com.example.chat_app.staging` | `com.example.chatApp.staging` | `lib/main_staging.dart` | `lib/firebase_options_staging.dart` (wrapper) |
| **Development** | Local Emulators (`fail-closed`) | N/A | `com.example.chat_app.dev` | `Not Configured` (See note)* | `lib/main_development.dart` | `lib/firebase_options.dart` (Emulators) |

*\*Note on Development iOS Flavor: A dedicated Development iOS Xcode scheme and configurations (`com.example.chatApp.dev`) are outside the current scope and are not currently configured in Xcode (`Runner.xcodeproj`). iOS currently configures shared schemes for Production (`Runner.xcscheme`) and Staging (`staging.xcscheme`). To run against local emulators on iOS Simulator, developers execute `flutter run -t lib/main_development.dart`.*

---

## 2. Firebase CLI Configuration (`.firebaserc` & `firebase.json`)

### Explicit Aliases in `.firebaserc`
To prevent unqualified deployments and eliminate any ambiguity about target projects:
```json
{
  "projects": {
    "production": "chat-app-28ac0",
    "staging": "study-buddy-54266"
  }
}
```

### Deployment Rule of Governance
- **Never execute an unqualified `firebase deploy`**.
- Deployments to Staging must explicitly specify:
  ```bash
  firebase deploy --project staging
  ```
- Deployments to Production are restricted and must explicitly target:
  ```bash
  firebase deploy --project production
  ```

---

## 3. Flutter & Platform Build Variants

### Android Product Flavors (`android/app/build.gradle.kts`)
Android derives independent application IDs via flavor dimensions:
```kotlin
flavorDimensions += "default"

productFlavors {
    create("production") {
        dimension = "default"
        resValue(type = "string", name = "app_name", value = "ChatApp_Production")
    }
    create("staging") {
        dimension = "default"
        applicationIdSuffix = ".staging"
        resValue(type = "string", name = "app_name", value = "ChatApp_Staging")
    }
    create("development") {
        dimension = "default"
        applicationIdSuffix = ".dev"
        resValue(type = "string", name = "app_name", value = "ChatApp_Development")
    }
}
```

### Flavor Directory Asset Hierarchy
The Google Services Gradle plugin resolves `google-services.json` per flavor:
- `android/app/src/production/google-services.json` (Production)
- `android/app/src/staging/google-services.json` (Staging)
- `android/app/google-services.json` (Default root fallback)

### iOS Schemes, Configurations & Environment Selection (`ios/Runner.xcodeproj`)
- Production scheme: `Runner.xcscheme` (Bundle ID: `com.example.chatApp`, Production plist)
- Staging scheme: `staging.xcscheme` (Bundle ID: `com.example.chatApp.staging`, Staging plist)
- Development scheme: *Not configured* (Development iOS scheme is outside current scope; see note above).
- Dedicated Xcode Build Configurations:
  - Production: `Debug`, `Profile`, `Release`
  - Staging: `Debug-staging`, `Profile-staging`, `Release-staging`
- CocoaPods Configuration Mapping (`ios/Podfile`):
  ```ruby
  project 'Runner', {
    'Debug' => :debug,
    'Profile' => :release,
    'Release' => :release,

    'Debug-staging' => :debug,
    'Profile-staging' => :release,
    'Release-staging' => :release,
  }
  ```
- Environment-specific plist storage:
  - `ios/Runner/Firebase/Production/GoogleService-Info.plist`
  - `ios/Runner/Firebase/Staging/GoogleService-Info.plist`
- Automated Build Phase Run Script in Xcode (`Runner.xcodeproj/project.pbxproj`):
  Deterministic POSIX shell script selecting the appropriate flavor plist based on `$FLUTTER_FLAVOR` or `$CONFIGURATION` and failing closed (`exit 1`) if the configuration is unknown or if the requested plist does not exist. Staging never falls back to Production.

### Generating Staging Firebase Configuration (Once IAM is Authorized)
When cloud IAM access to project `study-buddy-54266` is granted:
```bash
flutterfire configure \
  --project=study-buddy-54266 \
  --out=lib/firebase_options_staging.generated.dart \
  --android-package-name=com.example.chat_app.staging \
  --ios-bundle-id=com.example.chatApp.staging
```
The wrapper `lib/firebase_options_staging.dart` automatically validates and exposes the generated options via `DefaultFirebaseOptionsStaging`.

---

## 4. Development Emulator Safety (Fail-Closed)

### Fail-Closed Emulator Architecture
Development (`lib/main_development.dart`) initializes via `Bootstrap.init(useEmulators: true)`.
All supported Firebase clients are bound to local emulators:
- Auth (`9099`)
- Firestore (`8080`)
- Realtime Database (`9000`)
- Storage (`9199`)
- Functions (`5001`)

If emulator connection fails, startup **fails closed** throwing a `StateError` to prevent any possibility of falling back to Production. External push notifications are completely disabled in development.

---

## 5. CI/CD & Fastlane Pipeline Separation

### Fastlane Configuration (`android/fastlane/Fastfile`)
- Lane `firebase_distribution`: builds and distributes production APK.
- Lane `firebase_distribution_staging`: builds and distributes staging APK (`app-staging-release.apk`) using Workload Identity Federation / Application Default Credentials (`GOOGLE_APPLICATION_CREDENTIALS`).

### Dedicated GitHub Actions Workflow (`.github/workflows/staging_distribution.yaml`)
- Bound to GitHub Environment: `staging`.
- Triggered exclusively on `workflow_dispatch` (manual).
- Authenticates using Google Cloud Workload Identity Federation (OIDC) without long-lived tokens or `FIREBASE_TOKEN`.
- Consumes environment secrets:
  - `GCP_WORKLOAD_IDENTITY_PROVIDER_STAGING`
  - `GCP_SERVICE_ACCOUNT_STAGING`
  - `STAGING_GOOGLE_SERVICES_JSON_BASE64`
  - `STAGING_FIREBASE_OPTIONS_BASE64`
  - `STAGING_FIREBASE_APP_ID`
  - `STAGING_TESTERS`
