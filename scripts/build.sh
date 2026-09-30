#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build_dir="${TOMATOBAR_BUILD_DIR:-/tmp/TomatoBar-personal-build}"
# Signing contract: project-level Automatic signing with the free Personal Team
# (Team Z9PY2WFY9C). The local CLI build uses Xcode-managed development signing;
# -allowProvisioningUpdates refreshes the short-lived free profile when needed.
xcodebuild -project TomatoBar.xcodeproj -scheme TomatoBar -configuration Release \
  -derivedDataPath "$build_dir" -allowProvisioningUpdates clean build
codesign --verify --deep --strict "$build_dir/Build/Products/Release/TomatoBar Personal.app"
