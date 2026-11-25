#!/bin/sh
set -e

# ChatUp iOS Firebase Plist Selector and Identity Validator
# Resolves, validates, and copies the environment-specific GoogleService-Info.plist into the built application bundle.

# Resolve PROJECT_DIR if not set by Xcode
if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fi

if [ -z "$PRODUCT_NAME" ]; then
    PRODUCT_NAME="Runner"
fi

if [ -z "$PLIST_DEST" ]; then
    if [ -n "$BUILT_PRODUCTS_DIR" ]; then
        PLIST_DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    else
        echo "error: Neither PLIST_DEST nor BUILT_PRODUCTS_DIR is set." >&2
        exit 1
    fi
fi

# 1. Target Environment Inference
TARGET_ENV=""

if [ -n "$FLUTTER_FLAVOR" ]; then
    case "$FLUTTER_FLAVOR" in
        staging)
            TARGET_ENV="staging"
            ;;
        production)
            TARGET_ENV="production"
            ;;
        *)
            echo "error: Unsupported FLUTTER_FLAVOR '$FLUTTER_FLAVOR'. Only 'staging' and 'production' are supported on iOS." >&2
            exit 1
            ;;
    esac
else
    case "$CONFIGURATION" in
        Debug-staging|Profile-staging|Release-staging)
            TARGET_ENV="staging"
            ;;
        Debug|Profile|Release)
            TARGET_ENV="production"
            ;;
        *)
            echo "error: Unrecognized build configuration '$CONFIGURATION' and no FLUTTER_FLAVOR specified. Expected staging (Debug-staging, Profile-staging, Release-staging) or production (Debug, Profile, Release)." >&2
            exit 1
            ;;
    esac
fi

# 2. Locate Source Plist File
PLIST_SRC=""

case "$TARGET_ENV" in
    staging)
        if [ -f "${PROJECT_DIR}/Runner/Firebase/Staging/GoogleService-Info.plist" ]; then
            PLIST_SRC="${PROJECT_DIR}/Runner/Firebase/Staging/GoogleService-Info.plist"
        elif [ -f "${PROJECT_DIR}/Firebase/GoogleService-Info-staging.plist" ]; then
            PLIST_SRC="${PROJECT_DIR}/Firebase/GoogleService-Info-staging.plist"
        fi

        if [ -z "$PLIST_SRC" ]; then
            echo "error: Staging GoogleService-Info.plist not found! Provide it at ios/Runner/Firebase/Staging/GoogleService-Info.plist or ios/Firebase/GoogleService-Info-staging.plist" >&2
            exit 1
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
            echo "error: Production GoogleService-Info.plist not found! Provide it at ios/Runner/Firebase/Production/GoogleService-Info.plist or ios/Runner/GoogleService-Info.plist" >&2
            exit 1
        fi
        ;;
    *)
        echo "error: Invalid target environment '$TARGET_ENV'" >&2
        exit 1
        ;;
esac

# 3. Plist Identity & Contract Validation
extract_plist_string() {
    awk -v key="$2" '
        BEGIN { found = 0 }
        $0 ~ "<key>" key "</key>" { found = 1; next }
        found && /<string>.*<\/string>/ {
            sub(/.*<string>/, "")
            sub(/<\/string>.*/, "")
            print
            exit
        }
        found && /<key>/ { exit }
    ' "$1"
}

validate_plist_identity() {
    _file="$1"
    _env="$2"

    _proj_id=$(extract_plist_string "$_file" "PROJECT_ID")
    _sender_id=$(extract_plist_string "$_file" "GCM_SENDER_ID")
    _bundle_id=$(extract_plist_string "$_file" "BUNDLE_ID")
    _app_id=$(extract_plist_string "$_file" "GOOGLE_APP_ID")
    _bucket=$(extract_plist_string "$_file" "STORAGE_BUCKET")
    _api_key=$(extract_plist_string "$_file" "API_KEY")

    if [ "$_env" = "staging" ]; then
        if [ "$_proj_id" != "study-buddy-54266" ]; then
            echo "error: Staging plist validation failed: PROJECT_ID '$_proj_id' != 'study-buddy-54266'" >&2
            exit 1
        fi
        if [ "$_sender_id" != "194789753908" ]; then
            echo "error: Staging plist validation failed: GCM_SENDER_ID '$_sender_id' != '194789753908'" >&2
            exit 1
        fi
        if [ "$_bundle_id" != "com.example.chatApp.staging" ]; then
            echo "error: Staging plist validation failed: BUNDLE_ID '$_bundle_id' != 'com.example.chatApp.staging'" >&2
            exit 1
        fi
        case "$_app_id" in
            1:194789753908:ios:*)
                ;;
            *)
                echo "error: Staging plist validation failed: GOOGLE_APP_ID '$_app_id' does not match prefix '1:194789753908:ios:'" >&2
                exit 1
                ;;
        esac

        # Fail closed on placeholder values
        case "$_api_key" in
            *PLACEHOLDER*|"")
                echo "error: Staging plist validation failed: API_KEY is empty or placeholder." >&2
                exit 1
                ;;
        esac

        # Mandatory Staging Storage Bucket validation
        if [ -z "$EXPECTED_STAGING_STORAGE_BUCKET" ] || [ -z "$(printf "%s" "$EXPECTED_STAGING_STORAGE_BUCKET" | tr -d ' ')" ]; then
            echo "error: Staging plist validation failed: EXPECTED_STAGING_STORAGE_BUCKET is required but missing or empty." >&2
            exit 1
        fi

        if [ "$EXPECTED_STAGING_STORAGE_BUCKET" = "chat-app-28ac0.firebasestorage.app" ] || \
           [ "$EXPECTED_STAGING_STORAGE_BUCKET" = "chat-app-28ac0.appspot.com" ]; then
            echo "error: Staging plist validation failed: EXPECTED_STAGING_STORAGE_BUCKET cannot be a Production bucket!" >&2
            exit 1
        fi

        if [ -z "$_bucket" ] || [ -z "$(printf "%s" "$_bucket" | tr -d ' ')" ]; then
            echo "error: Staging plist validation failed: STORAGE_BUCKET in plist is missing or empty." >&2
            exit 1
        fi

        if [ "$_bucket" != "$EXPECTED_STAGING_STORAGE_BUCKET" ]; then
            echo "error: Staging plist validation failed: STORAGE_BUCKET '$_bucket' does not match authoritative expected bucket '$EXPECTED_STAGING_STORAGE_BUCKET'" >&2
            exit 1
        fi

        # Absolute Production Isolation: Never allow Production values in Staging plist
        if [ "$_proj_id" = "chat-app-28ac0" ] || \
           [ "$_sender_id" = "639830188590" ] || \
           [ "$_bundle_id" = "com.example.chatApp" ] || \
           [ "$_bucket" = "chat-app-28ac0.firebasestorage.app" ] || \
           [ "$_bucket" = "chat-app-28ac0.appspot.com" ]; then
            echo "error: Staging plist validation failed: Production credentials detected in Staging plist!" >&2
            exit 1
        fi
    elif [ "$_env" = "production" ]; then
        if [ "$_proj_id" != "chat-app-28ac0" ]; then
            echo "error: Production plist validation failed: PROJECT_ID '$_proj_id' != 'chat-app-28ac0'" >&2
            exit 1
        fi
        if [ "$_sender_id" != "639830188590" ]; then
            echo "error: Production plist validation failed: GCM_SENDER_ID '$_sender_id' != '639830188590'" >&2
            exit 1
        fi
        if [ "$_bundle_id" != "com.example.chatApp" ]; then
            echo "error: Production plist validation failed: BUNDLE_ID '$_bundle_id' != 'com.example.chatApp'" >&2
            exit 1
        fi
        case "$_app_id" in
            1:639830188590:ios:*)
                ;;
            *)
                echo "error: Production plist validation failed: GOOGLE_APP_ID '$_app_id' does not match prefix '1:639830188590:ios:'" >&2
                exit 1
                ;;
        esac

        # Never allow Staging values in Production plist
        if [ "$_proj_id" = "study-buddy-54266" ] || \
           [ "$_sender_id" = "194789753908" ] || \
           [ "$_bundle_id" = "com.example.chatApp.staging" ]; then
            echo "error: Production plist validation failed: Staging credentials detected in Production plist!" >&2
            exit 1
        fi
    fi
}

validate_plist_identity "$PLIST_SRC" "$TARGET_ENV"

echo "Validated and selected $TARGET_ENV Firebase configuration from $PLIST_SRC"
mkdir -p "$(dirname "$PLIST_DEST")"
cp -f "$PLIST_SRC" "$PLIST_DEST"
