#!/bin/sh
# Native macOS QA, with its own process name, defaults domain and temporary records.
set -eu
cd "$(dirname "$0")/.."
products="${TOMATOBAR_BUILD_DIR:-/tmp/TomatoBar-personal-build}/Build/Products/Release"
if pgrep -x "Tomy Desktop QA" >/dev/null 2>&1; then
  echo "请先正常退出现有 Tomy Desktop QA，再启动新预览，避免看到旧代码。" >&2
  exit 1
fi
[ -f "$products/KeyboardShortcuts.o" ] || { echo "先运行 scripts/build.sh" >&2; exit 1; }
qa_dir=$(mktemp -d -t tomy-desktop-qa)
qa_app="$qa_dir/Tomy Desktop QA.app"
mkdir -p "$qa_app/Contents/MacOS" "$qa_app/Contents/Resources"
sed '/^@main$/d' TomatoBar/App.swift > "$qa_dir/App.swift"
xcrun swiftc -I "$products" \
  TomatoBar/State.swift TomatoBar/Log.swift TomatoBar/Analytics.swift \
  TomatoBar/Timer.swift TomatoBar/View.swift TomatoBar/MainWindow.swift \
  TomatoBar/FocusCharts.swift TomatoBar/DesktopPet.swift TomatoBar/PetMotion.swift \
  TomatoBar/CompactDesktopPet.swift TomatoBar/Notifications.swift TomatoBar/LaunchContext.swift \
  "$qa_dir/App.swift" Tests/DesktopPetPreview/main.swift \
  "$products/KeyboardShortcuts.o" "$products/LaunchAtLogin.o" -o "$qa_app/Contents/MacOS/Tomy Desktop QA"
cp "$products/TomatoBar Personal.app/Contents/Resources/Assets.car" "$qa_app/Contents/Resources/Assets.car"
cat > "$qa_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Tomy Desktop QA</string>
<key>CFBundleIdentifier</key><string>com.dilyar.TomatoBarPersonal.PetQA20261009</string>
<key>CFBundleName</key><string>Tomy Desktop QA</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$qa_app"
echo "$qa_app"
open "$qa_app"
