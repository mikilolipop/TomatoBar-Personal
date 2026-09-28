#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build_dir="${TOMATOBAR_BUILD_DIR:-/tmp/TomatoBar-personal-build}"
xcodebuild -project TomatoBar.xcodeproj -scheme TomatoBar -configuration Release \
  -derivedDataPath "$build_dir" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= clean build
codesign --verify --deep --strict "$build_dir/Build/Products/Release/TomatoBar Personal.app"
