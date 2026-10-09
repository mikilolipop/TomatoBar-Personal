#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Build first: real SwiftPM modules and link objects, no mocks of TBTimer or SwiftUI.
products="${TOMATOBAR_BUILD_DIR:-/tmp/TomatoBar-personal-build}/Build/Products/Release"
probe_dir=$(mktemp -d -t tomatobar-bridge-checks)
trap 'rm -rf "$probe_dir"' EXIT
# Keep every App.swift implementation; replace only the executable entry point.
sed '/^@main$/d' TomatoBar/App.swift > "$probe_dir/App.swift"
xcrun swiftc -I "$products" \
  TomatoBar/State.swift TomatoBar/Log.swift TomatoBar/Analytics.swift \
  TomatoBar/Timer.swift TomatoBar/View.swift TomatoBar/MainWindow.swift \
  TomatoBar/FocusCharts.swift TomatoBar/DesktopPet.swift TomatoBar/PetMotion.swift TomatoBar/CompactDesktopPet.swift TomatoBar/Notifications.swift TomatoBar/LaunchContext.swift \
  "$probe_dir/App.swift" Tests/BridgeReview/main.swift \
  "$products/KeyboardShortcuts.o" "$products/LaunchAtLogin.o" -o "$probe_dir/probe"
"$probe_dir/probe"
