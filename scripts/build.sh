#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build_dir="${TOMATOBAR_BUILD_DIR:-/tmp/TomatoBar-personal-build}"
# Signing contract: project-level Automatic signing with the free Personal Team
# (Team Z9PY2WFY9C). The local CLI build uses Xcode-managed development signing;
# -allowProvisioningUpdates refreshes the short-lived free profile when needed.
# Build both architectures so local installation and release packages use one product.
xcodebuild -project TomatoBar.xcodeproj -scheme TomatoBar -configuration Release \
  -derivedDataPath "$build_dir" -allowProvisioningUpdates \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build
codesign --verify --deep --strict "$build_dir/Build/Products/Release/TomatoBar Personal.app"
