#!/bin/sh
# Archive the iOS app on this Mac and upload it to TestFlight.
#
# Xcode Cloud can't build this fork: it requires access to every package repository,
# and GitHub only grants that for repositories you own. Signing uses the Apple ID
# signed in to Xcode (Settings > Accounts). Each upload needs a new build number,
# so it is taken from the current time.
set -eu

cd "$(dirname "$0")"
build_number="$(date +%Y%m%d%H%M)"
archive="../build-testflight/Flare-$build_number.xcarchive"

xcodegen generate --spec project.yml
xcodebuild archive \
    -project Flare.xcodeproj -scheme iOS -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$archive" \
    -allowProvisioningUpdates -skipPackagePluginValidation -skipMacroValidation \
    CURRENT_PROJECT_VERSION="$build_number"
xcodebuild -exportArchive \
    -archivePath "$archive" -exportOptionsPlist ExportOptions.plist \
    -exportPath "../build-testflight/export-$build_number" -allowProvisioningUpdates
echo "Uploaded build $build_number. It appears in TestFlight once Apple finishes processing."
