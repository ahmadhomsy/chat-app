#!/bin/sh
set -e

# POSIX Shell Plist Selector Test Suite
# Validates portable POSIX shell logic without Bash-specific constructs

TEST_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'plist_test')
trap 'rm -rf "$TEST_DIR"' EXIT

PROJECT_DIR="$TEST_DIR"
BUILT_PRODUCTS_DIR="$TEST_DIR/build"
PRODUCT_NAME="Runner"
mkdir -p "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app"
mkdir -p "$PROJECT_DIR/Runner/Firebase/Production"
mkdir -p "$PROJECT_DIR/Runner/Firebase/Staging"

echo "MOCK_PRODUCTION_PLIST" > "$PROJECT_DIR/Runner/Firebase/Production/GoogleService-Info.plist"
echo "MOCK_STAGING_PLIST" > "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist"

run_selector() {
    FLUTTER_FLAVOR="$1"
    CONFIGURATION="$2"
    
    PLIST_DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    rm -f "$PLIST_DEST"

    TARGET_ENV=""

    if [ "$FLUTTER_FLAVOR" = "staging" ]; then
        TARGET_ENV="staging"
    elif [ "$FLUTTER_FLAVOR" = "production" ]; then
        TARGET_ENV="production"
    else
        case "$CONFIGURATION" in
            *staging*|*Staging*)
                TARGET_ENV="staging"
                ;;
            Debug|Profile|Release|*production*|*Production*)
                TARGET_ENV="production"
                ;;
            *)
                echo "error: Unrecognized build configuration '$CONFIGURATION' or flavor '$FLUTTER_FLAVOR'." >&2
                return 1
                ;;
        esac
    fi

    PLIST_SRC=""

    case "$TARGET_ENV" in
        staging)
            if [ -f "${PROJECT_DIR}/Runner/Firebase/Staging/GoogleService-Info.plist" ]; then
                PLIST_SRC="${PROJECT_DIR}/Runner/Firebase/Staging/GoogleService-Info.plist"
            elif [ -f "${PROJECT_DIR}/Firebase/GoogleService-Info-staging.plist" ]; then
                PLIST_SRC="${PROJECT_DIR}/Firebase/GoogleService-Info-staging.plist"
            fi

            if [ -z "$PLIST_SRC" ]; then
                echo "error: Staging GoogleService-Info.plist not found!" >&2
                return 1
            fi
            ;;
        production)
            if [ -f "${PROJECT_DIR}/Runner/Firebase/Production/GoogleService-Info.plist" ]; then
                PLIST_SRC="${PROJECT_DIR}/Runner/Firebase/Production/GoogleService-Info.plist"
            elif [ -f "${PROJECT_DIR}/Firebase/GoogleService-Info-production.plist" ]; then
                PLIST_SRC="${PROJECT_DIR}/Firebase/GoogleService-Info-production.plist"
            elif [ -f "${PROJECT_DIR}/Runner/GoogleService-Info.plist" ]; then
                PLIST_SRC="${PROJECT_DIR}/Runner/GoogleService-Info.plist"
            fi

            if [ -z "$PLIST_SRC" ]; then
                echo "error: Production GoogleService-Info.plist not found!" >&2
                return 1
            fi
            ;;
        *)
            echo "error: Invalid target environment '$TARGET_ENV'" >&2
            return 1
            ;;
    esac

    cp -f "$PLIST_SRC" "$PLIST_DEST"
    return 0
}

echo "Running Plist Selector Portability Tests..."

# Test 1: Staging configuration selects staging plist
run_selector "" "Debug-staging"
CONTENT=$(cat "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist")
if [ "$CONTENT" != "MOCK_STAGING_PLIST" ]; then
    echo "FAIL: Test 1 expected MOCK_STAGING_PLIST, got $CONTENT"
    exit 1
fi
echo "  [PASS] 1. Debug-staging selects Staging plist"

# Test 2: Release-staging selects staging plist
run_selector "" "Release-staging"
CONTENT=$(cat "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist")
if [ "$CONTENT" != "MOCK_STAGING_PLIST" ]; then
    echo "FAIL: Test 2 expected MOCK_STAGING_PLIST, got $CONTENT"
    exit 1
fi
echo "  [PASS] 2. Release-staging selects Staging plist"

# Test 3: FLUTTER_FLAVOR=staging selects staging plist
run_selector "staging" ""
CONTENT=$(cat "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist")
if [ "$CONTENT" != "MOCK_STAGING_PLIST" ]; then
    echo "FAIL: Test 3 expected MOCK_STAGING_PLIST, got $CONTENT"
    exit 1
fi
echo "  [PASS] 3. FLUTTER_FLAVOR=staging selects Staging plist"

# Test 4: Debug configuration selects production plist
run_selector "" "Debug"
CONTENT=$(cat "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist")
if [ "$CONTENT" != "MOCK_PRODUCTION_PLIST" ]; then
    echo "FAIL: Test 4 expected MOCK_PRODUCTION_PLIST, got $CONTENT"
    exit 1
fi
echo "  [PASS] 4. Debug selects Production plist"

# Test 5: Release configuration selects production plist
run_selector "" "Release"
CONTENT=$(cat "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist")
if [ "$CONTENT" != "MOCK_PRODUCTION_PLIST" ]; then
    echo "FAIL: Test 5 expected MOCK_PRODUCTION_PLIST, got $CONTENT"
    exit 1
fi
echo "  [PASS] 5. Release selects Production plist"

# Test 6: Unknown configuration terminates with exit 1
if run_selector "" "UnknownConfiguration" 2>/dev/null; then
    echo "FAIL: Test 6 expected error on UnknownConfiguration"
    exit 1
fi
echo "  [PASS] 6. Unknown configuration terminates with error"

# Test 7: Missing Staging plist terminates with exit 1 and never falls back to Production
rm -f "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist"
if run_selector "" "Debug-staging" 2>/dev/null; then
    echo "FAIL: Test 7 expected error on missing Staging plist"
    exit 1
fi
if [ -f "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist" ]; then
    echo "FAIL: Test 7 Staging fell back to Production plist!"
    exit 1
fi
echo "  [PASS] 7. Missing Staging plist terminates and never falls back to Production"

# Test 8: Missing Production plist terminates with exit 1 and never falls back to Staging
echo "MOCK_STAGING_PLIST" > "$PROJECT_DIR/Runner/Firebase/Staging/GoogleService-Info.plist"
rm -f "$PROJECT_DIR/Runner/Firebase/Production/GoogleService-Info.plist"
if run_selector "" "Release" 2>/dev/null; then
    echo "FAIL: Test 8 expected error on missing Production plist"
    exit 1
fi
if [ -f "$BUILT_PRODUCTS_DIR/${PRODUCT_NAME}.app/GoogleService-Info.plist" ]; then
    echo "FAIL: Test 8 Production fell back to Staging plist!"
    exit 1
fi
echo "  [PASS] 8. Missing Production plist terminates and never falls back to Staging"

echo "All 8 Plist Selector Portability Tests PASSED!"
