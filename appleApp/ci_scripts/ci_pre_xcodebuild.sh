#!/bin/sh
# Xcode Cloud pre-xcodebuild hook.
#
# TestFlight rejects a reused build number, and Version.xcconfig takes it from the
# upstream versionCode, which stays fixed between upstream releases. Use Xcode Cloud's
# per-workflow build counter instead; it only ever increases.
set -eu

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
    printf '\nCURRENT_PROJECT_VERSION = %s\n' "$CI_BUILD_NUMBER" >> "$CI_PRIMARY_REPOSITORY_PATH/appleApp/Version.xcconfig"
    echo "Build number set to $CI_BUILD_NUMBER"
fi
