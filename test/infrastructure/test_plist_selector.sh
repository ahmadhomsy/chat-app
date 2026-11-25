#!/bin/sh
set -e

# ChatUp iOS Firebase Plist Selector & Identity Validation Test Suite
# Tests ios/scripts/select_firebase_plist.sh under standard POSIX /bin/sh.
# Asserts strict flavor enforcement, Xcode configuration inference, plist identity validation,
# mandatory authoritative storage bucket checks, and zero cross-environment fallback.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SELECTOR_SCRIPT="$REPO_ROOT/ios/scripts/select_firebase_plist.sh"

if [ ! -f "$SELECTOR_SCRIPT" ]; then
    echo "ERROR: Selector script not found at $SELECTOR_SCRIPT" >&2
    exit 1
fi

TEST_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t 'plist_test')
trap 'rm -rf "$TEST_TMP"' EXIT

PROJECT_DIR="$TEST_TMP/ios"
BUILT_PRODUCTS_DIR="$TEST_TMP/build"
PRODUCT_NAME="Runner"
mkdir -p "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app"
mkdir -p "$PROJECT_DIR/Runner/Firebase/Production"
mkdir -p "$PROJECT_DIR/Runner/Firebase/Staging"

# Synthetic test fixture bucket
TEST_FIXTURE_STAGING_BUCKET="study-buddy-54266.firebasestorage.app"

# Helpers to write mock plist fixtures (without real credentials)
write_staging_plist() {
    _path="$1"
    _proj_id="${2:-study-buddy-54266}"
    _sender_id="${3:-194789753908}"
    _bundle_id="${4:-com.example.chatApp.staging}"
    _app_id="${5:-1:194789753908:ios:mockstagingappid123}"
    _bucket="${6:-$TEST_FIXTURE_STAGING_BUCKET}"
    _api_key="${7:-AIzaSy_MOCK_STAGING_API_KEY_VALID_123}"

    cat <<EOF > "$_path"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PROJECT_ID</key>
	<string>$_proj_id</string>
	<key>GCM_SENDER_ID</key>
	<string>$_sender_id</string>
	<key>BUNDLE_ID</key>
	<string>$_bundle_id</string>
	<key>GOOGLE_APP_ID</key>
	<string>$_app_id</string>
	<key>STORAGE_BUCKET</key>
	<string>$_bucket</string>
	<key>API_KEY</key>
	<string>$_api_key</string>
</dict>
</plist>
EOF
}

write_staging_plist_raw() {
    _path="$1"
    _content="$2"
    cat <<EOF > "$_path"
$_content
EOF
}

write_production_plist() {
    _path="$1"
    _proj_id="${2:-chat-app-28ac0}"
    _sender_id="${3:-639830188590}"
    _bundle_id="${4:-com.example.chatApp}"
    _app_id="${5:-1:639830188590:ios:mockproductionappid123}"
    _bucket="${6:-chat-app-28ac0.firebasestorage.app}"
    _api_key="${7:-AIzaSy_MOCK_PRODUCTION_API_KEY_VALID_456}"

    cat <<EOF > "$_path"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PROJECT_ID</key>
	<string>$_proj_id</string>
	<key>GCM_SENDER_ID</key>
	<string>$_sender_id</string>
	<key>BUNDLE_ID</key>
	<string>$_bundle_id</string>
	<key>GOOGLE_APP_ID</key>
	<string>$_app_id</string>
	<key>STORAGE_BUCKET</key>
	<string>$_bucket</string>
	<key>API_KEY</key>
	<string>$_api_key</string>
</dict>
</plist>
EOF
}

setup_standard_fixtures() {
    write_staging_plist "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist"
    write_production_plist "$PROJECT_DIR/Runner/Firebase/Production/GoogleService-Info.plist"
}

run_test_selector() {
    _flavor="$1"
    _config="$2"
    if [ $# -ge 3 ]; then
        _expected_bucket="$3"
    else
        _expected_bucket="$TEST_FIXTURE_STAGING_BUCKET"
    fi
    _dest="$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    rm -f "$_dest"

    env FLUTTER_FLAVOR="$_flavor" \
        CONFIGURATION="$_config" \
        EXPECTED_STAGING_STORAGE_BUCKET="$_expected_bucket" \
        PROJECT_DIR="$PROJECT_DIR" \
        BUILT_PRODUCTS_DIR="$BUILT_PRODUCTS_DIR" \
        PRODUCT_NAME="$PRODUCT_NAME" \
        PLIST_DEST="$_dest" \
        sh "$SELECTOR_SCRIPT"
}

run_test_selector_no_bucket() {
    _flavor="$1"
    _config="$2"
    _dest="$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    rm -f "$_dest"

    env -u EXPECTED_STAGING_STORAGE_BUCKET \
        FLUTTER_FLAVOR="$_flavor" \
        CONFIGURATION="$_config" \
        PROJECT_DIR="$PROJECT_DIR" \
        BUILT_PRODUCTS_DIR="$BUILT_PRODUCTS_DIR" \
        PRODUCT_NAME="$PRODUCT_NAME" \
        PLIST_DEST="$_dest" \
        sh "$SELECTOR_SCRIPT"
}

assert_destination_contains() {
    _needle="$1"
    _dest="$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    if [ ! -f "$_dest" ]; then
        echo "FAIL: Destination plist was not created at $_dest" >&2
        exit 1
    fi
    if ! grep -q "$_needle" "$_dest"; then
        echo "FAIL: Expected '$_needle' in destination plist, but content was:" >&2
        cat "$_dest" >&2
        exit 1
    fi
}

echo "Running Plist Selector & Identity Validation Tests..."
setup_standard_fixtures

# 1. Debug-staging selects Staging
run_test_selector "" "Debug-staging"
assert_destination_contains "study-buddy-54266"
echo "  [PASS] 1. Debug-staging selects Staging"

# 2. Profile-staging selects Staging
run_test_selector "" "Profile-staging"
assert_destination_contains "study-buddy-54266"
echo "  [PASS] 2. Profile-staging selects Staging"

# 3. Release-staging selects Staging
run_test_selector "" "Release-staging"
assert_destination_contains "study-buddy-54266"
echo "  [PASS] 3. Release-staging selects Staging"

# 4. Debug selects Production
run_test_selector "" "Debug"
assert_destination_contains "chat-app-28ac0"
echo "  [PASS] 4. Debug selects Production"

# 5. Profile selects Production
run_test_selector "" "Profile"
assert_destination_contains "chat-app-28ac0"
echo "  [PASS] 5. Profile selects Production"

# 6. Release selects Production
run_test_selector "" "Release"
assert_destination_contains "chat-app-28ac0"
echo "  [PASS] 6. Release selects Production"

# 7. FLUTTER_FLAVOR=staging selects Staging
run_test_selector "staging" ""
assert_destination_contains "study-buddy-54266"
echo "  [PASS] 7. FLUTTER_FLAVOR=staging selects Staging"

# 8. FLUTTER_FLAVOR=production selects Production
run_test_selector "production" ""
assert_destination_contains "chat-app-28ac0"
echo "  [PASS] 8. FLUTTER_FLAVOR=production selects Production"

# 9. FLUTTER_FLAVOR=development with Debug fails closed immediately
if run_test_selector "development" "Debug" 2>/dev/null; then
    echo "FAIL: Test 9 expected error when FLUTTER_FLAVOR=development with CONFIGURATION=Debug" >&2
    exit 1
fi
echo "  [PASS] 9. FLUTTER_FLAVOR=development with Debug fails closed"

# 10. Unknown non-empty flavor fails closed
if run_test_selector "custom_flavor" "Release" 2>/dev/null; then
    echo "FAIL: Test 10 expected error on unknown flavor" >&2
    exit 1
fi
echo "  [PASS] 10. Unknown non-empty flavor fails closed"

# 11. Unknown Configuration fails closed
if run_test_selector "" "UnknownConfiguration" 2>/dev/null; then
    echo "FAIL: Test 11 expected error on UnknownConfiguration" >&2
    exit 1
fi
echo "  [PASS] 11. Unknown Configuration fails closed"

# 12. Missing Staging plist fails without Production fallback
rm -f "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist"
if run_test_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 12 expected error on missing Staging plist" >&2
    exit 1
fi
if [ -f "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist" ]; then
    echo "FAIL: Test 12 Staging fell back to Production plist!" >&2
    exit 1
fi
echo "  [PASS] 12. Missing Staging plist fails without Production fallback"

# 13. Missing Production plist fails without Staging fallback
setup_standard_fixtures
rm -f "$PROJECT_DIR/Runner/Firebase/Production/GoogleService-Info.plist"
if run_test_selector "" "Release" 2>/dev/null; then
    echo "FAIL: Test 13 expected error on missing Production plist" >&2
    exit 1
fi
if [ -f "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist" ]; then
    echo "FAIL: Test 13 Production fell back to Staging plist!" >&2
    exit 1
fi
echo "  [PASS] 13. Missing Production plist fails without Staging fallback"

# 14. Plist with mismatched Project ID fails validation
setup_standard_fixtures
write_staging_plist "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist" "wrong-project-id"
if run_test_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 14 expected error on mismatched Staging Project ID" >&2
    exit 1
fi
echo "  [PASS] 14. Plist with mismatched Project ID fails validation"

# 15. Plist with mismatched Bundle ID fails validation
setup_standard_fixtures
write_staging_plist "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist" "study-buddy-54266" "194789753908" "com.example.wrongBundle"
if run_test_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 15 expected error on mismatched Staging Bundle ID" >&2
    exit 1
fi
echo "  [PASS] 15. Plist with mismatched Bundle ID fails validation"

# 16. Plist with placeholder API key fails validation
setup_standard_fixtures
write_staging_plist "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist" "study-buddy-54266" "194789753908" "com.example.chatApp.staging" "1:194789753908:ios:app123" "$TEST_FIXTURE_STAGING_BUCKET" "STAGING_IOS_API_KEY_PLACEHOLDER"
if run_test_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 16 expected error on placeholder API key" >&2
    exit 1
fi
echo "  [PASS] 16. Plist with placeholder API key fails validation"

# 17. Plist with Production storage bucket in Staging fails validation
setup_standard_fixtures
write_staging_plist "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist" "study-buddy-54266" "194789753908" "com.example.chatApp.staging" "1:194789753908:ios:app123" "chat-app-28ac0.firebasestorage.app" "valid-key-123"
if run_test_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 17 expected error on Production storage bucket in Staging plist" >&2
    exit 1
fi
echo "  [PASS] 17. Plist with Production storage bucket in Staging fails validation"

# 18. Mandatory Storage Bucket: Missing EXPECTED_STAGING_STORAGE_BUCKET fails
setup_standard_fixtures
if run_test_selector_no_bucket "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 18 expected error when EXPECTED_STAGING_STORAGE_BUCKET is unset" >&2
    exit 1
fi
echo "  [PASS] 18. Missing EXPECTED_STAGING_STORAGE_BUCKET fails"

# 19. Mandatory Storage Bucket: Empty EXPECTED_STAGING_STORAGE_BUCKET fails
setup_standard_fixtures
if run_test_selector "" "Debug-staging" "" 2>/dev/null; then
    echo "FAIL: Test 19 expected error when EXPECTED_STAGING_STORAGE_BUCKET is empty" >&2
    exit 1
fi
echo "  [PASS] 19. Empty EXPECTED_STAGING_STORAGE_BUCKET fails"

# 20. Mandatory Storage Bucket: Missing plist STORAGE_BUCKET key fails
setup_standard_fixtures
write_staging_plist_raw "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist" '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PROJECT_ID</key>
	<string>study-buddy-54266</string>
	<key>GCM_SENDER_ID</key>
	<string>194789753908</string>
	<key>BUNDLE_ID</key>
	<string>com.example.chatApp.staging</string>
	<key>GOOGLE_APP_ID</key>
	<string>1:194789753908:ios:app123</string>
	<key>API_KEY</key>
	<string>valid-key-123</string>
</dict>
</plist>'
if run_test_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 20 expected error on missing plist STORAGE_BUCKET" >&2
    exit 1
fi
echo "  [PASS] 20. Missing plist STORAGE_BUCKET fails"

# 21. Mandatory Storage Bucket: Empty plist STORAGE_BUCKET value fails
setup_standard_fixtures
write_staging_plist "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist" "study-buddy-54266" "194789753908" "com.example.chatApp.staging" "1:194789753908:ios:app123" "   " "valid-key-123"
if run_test_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 21 expected error on empty plist STORAGE_BUCKET" >&2
    exit 1
fi
echo "  [PASS] 21. Empty plist STORAGE_BUCKET fails"

# 22. Mandatory Storage Bucket: Non-production but incorrect bucket fails
setup_standard_fixtures
write_staging_plist "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist" "study-buddy-54266" "194789753908" "com.example.chatApp.staging" "1:194789753908:ios:app123" "wrong-bucket.firebasestorage.app" "valid-key-123"
if run_test_selector "" "Debug-staging" "$TEST_FIXTURE_STAGING_BUCKET" 2>/dev/null; then
    echo "FAIL: Test 22 expected error on mismatched storage bucket" >&2
    exit 1
fi
echo "  [PASS] 22. Non-production but incorrect bucket fails"

# 23. Mandatory Storage Bucket: Matching explicitly supplied expected bucket succeeds
setup_standard_fixtures
run_test_selector "" "Debug-staging" "$TEST_FIXTURE_STAGING_BUCKET"
assert_destination_contains "$TEST_FIXTURE_STAGING_BUCKET"
echo "  [PASS] 23. Matching explicitly supplied expected bucket succeeds"

echo "All 23 Plist Selector & Identity Validation Tests PASSED!"
