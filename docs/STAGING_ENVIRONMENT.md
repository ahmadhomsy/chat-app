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
- Automated Build Phase Run Script in Xcode (`Runner.xcodeproj/project.pbxproj` invoking `ios/scripts/select_firebase_plist.sh`):
  Deterministic POSIX shell script selecting the appropriate flavor plist based on `$FLUTTER_FLAVOR` or `$CONFIGURATION` and failing closed (`exit 1`) if the configuration is unknown, if the flavor is unsupported (e.g. `development`), or if the requested plist does not exist or fails identity validation (verifies `PROJECT_ID`, `GCM_SENDER_ID`, `BUNDLE_ID`, `GOOGLE_APP_ID`, and `STORAGE_BUCKET`). Staging never falls back to Production.
  - **Xcode Build Phase Storage Bucket Propagation:**
    The mandatory `EXPECTED_STAGING_STORAGE_BUCKET` reaches the `select_firebase_plist.sh` build phase through invocation environment inheritance:
    - *CI/CD Pipelines:* Exported in the shell environment prior to executing `flutter build ios` or `xcodebuild` (e.g., via GitHub Actions `env.EXPECTED_STAGING_STORAGE_BUCKET` or Fastlane environment). Xcode Run Script build phases inherit all environment variables from the parent invocation shell.
    - *Local Xcode Development:* Configured in Xcode under Scheme Environment Variables (`Product` -> `Scheme` -> `Edit Scheme...` -> `Run` -> `Arguments` -> `Environment Variables`: add `EXPECTED_STAGING_STORAGE_BUCKET`), or supplied in a build configuration `.xcconfig`.
    - *Fail-Closed Enforcement:* If `EXPECTED_STAGING_STORAGE_BUCKET` is unset or empty during a Staging build, `select_firebase_plist.sh` immediately fails closed with `exit 1` (`FATAL: EXPECTED_STAGING_STORAGE_BUCKET is required for staging flavor verification`), ensuring unverified configurations cannot produce an iOS binary.

### Post-IAM Provisioning Procedure & Activation Runbook
Because Firebase IAM access to `study-buddy-54266` currently returns `403 PERMISSION_DENIED`, Staging is intentionally held in a **fail-closed** unconfigured state (`DefaultFirebaseOptionsStaging.authoritativeStorageBucket = null`). Running `flutterfire configure` alone is **not sufficient** to enable Staging while `authoritativeStorageBucket` is null.

Once an authorized administrator grants `roles/firebase.admin` on project `study-buddy-54266`, execute the following sequential runbook:

1. **Register Applications in Firebase Project:**
   Register the respective client applications in Firebase project `study-buddy-54266`:
   - Android: `com.example.chat_app.staging`
   - iOS: `com.example.chatApp.staging`

2. **Obtain Authoritative Storage Bucket:**
   Retrieve the genuine Storage Bucket from the Google Cloud SDK CLI:
   ```bash
   gcloud storage buckets list --project=study-buddy-54266
   ```
   Alternatively, query the Firebase Storage Management REST API:
   `GET https://firebasestorage.googleapis.com/v1beta/projects/study-buddy-54266/buckets`
   Do not guess the bucket name from the project ID.

3. **Generate Staging FlutterFire Options:**
   Generate the raw FlutterFire configuration stub:
   ```bash
   flutterfire configure \
     --project=study-buddy-54266 \
     --out=lib/firebase_options_staging.generated.dart \
     --android-package-name=com.example.chat_app.staging \
     --ios-bundle-id=com.example.chatApp.staging
   ```

4. **Update Authoritative Storage Bucket in Runtime Wrapper:**
   In `lib/firebase_options_staging.dart`, update the immutable constant:
   ```dart
   static const String? authoritativeStorageBucket = '<VERIFIED_STAGING_STORAGE_BUCKET>';
   ```
   This single trusted constant allows `isConfigured` to evaluate to `true` after verifying the generated options via `validateStagingOptions`.

5. **Supply Matching GitHub Environment Secret:**
   In GitHub repository settings under Environment `staging`, configure secret:
   - `STAGING_STORAGE_BUCKET`: `<VERIFIED_STAGING_STORAGE_BUCKET>`
   Also supply:
   - `STAGING_GOOGLE_SERVICES_JSON_BASE64`
   - `STAGING_FIREBASE_OPTIONS_BASE64`
   - `STAGING_FIREBASE_APP_ID`

6. **Validate Cross-File Consistency:**
   Run the preflight consistency check across all staging configuration files:
   ```bash
   EXPECTED_STAGING_STORAGE_BUCKET="<VERIFIED_STAGING_STORAGE_BUCKET>" node tool/validate_staging_cross_file_consistency.js
   ```

7. **Execute Staging Build and Distribution:**
   Trigger `.github/workflows/staging_distribution.yaml` manually via GitHub Actions `workflow_dispatch` only after all prior verification steps pass cleanly.

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

### Production Distribution Workflow (`.github/workflows/flutter_ci.yaml`)
- Bound to Production Firebase environment (`chat-app-28ac0`).
- Triggered exclusively via explicit manual `workflow_dispatch` (manual production release gate), preventing unintended automated distribution on every push/merge to `main`.
- Setup Ruby toolchain explicitly pinned to `3.2.11` (compatible with `ubuntu-latest` / `ubuntu-26.04` runner images).

### Dedicated GitHub Actions Workflow (`.github/workflows/staging_distribution.yaml`)
- Bound to GitHub Environment: `staging`.
- Triggered exclusively on `workflow_dispatch` (manual).
- Authenticates using Google Cloud Workload Identity Federation (OIDC) without long-lived tokens or `FIREBASE_TOKEN`.
- Setup Ruby toolchain explicitly pinned to `3.2.11` (compatible with `ubuntu-latest` / `ubuntu-26.04` runner images).
- Consumes environment secrets:
  - `GCP_WORKLOAD_IDENTITY_PROVIDER_STAGING`
  - `GCP_SERVICE_ACCOUNT_STAGING`
  - `STAGING_GOOGLE_SERVICES_JSON_BASE64`
  - `STAGING_FIREBASE_OPTIONS_BASE64`
  - `STAGING_FIREBASE_APP_ID`
  - `STAGING_STORAGE_BUCKET`
  - `STAGING_TESTERS`
