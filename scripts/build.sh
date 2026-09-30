#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build_dir="${TOMATOBAR_BUILD_DIR:-/tmp/TomatoBar-personal-build}"
# Signing contract since the Widget round: project-level Automatic signing with the
# free Personal Team (W37XN6F9LP → Z9PY2WFY9C). App-Groups entitlements make xcodebuild
# reject ad-hoc/Manual plans outright, so identity comes from the cached development
# profile; -allowProvisioningUpdates refreshes it when Xcode's 7-day free profiles roll.
xcodebuild -project TomatoBar.xcodeproj -scheme TomatoBar -configuration Release \
  -derivedDataPath "$build_dir" -allowProvisioningUpdates clean build
codesign --verify --deep --strict "$build_dir/Build/Products/Release/TomatoBar Personal.app"
