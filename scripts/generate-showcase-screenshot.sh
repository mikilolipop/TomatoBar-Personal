#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "1/4 正在生成纯净隔离的演示数据源 (demo/sessions.json)..."
mkdir -p demo
seed_bin=$(mktemp -t seed-showcase)
trap 'rm -f "$seed_bin"' EXIT
xcrun swiftc TomatoBar/State.swift TomatoBar/Log.swift TomatoBar/Analytics.swift scripts/seed-showcase.swift -o "$seed_bin"
"$seed_bin" demo/sessions.json

echo "2/4 正在编译独立隔离的主窗口渲染器..."
products="/tmp/TomatoBar-personal-build/Build/Products/Release"
if [ ! -f "$products/KeyboardShortcuts.o" ]; then
    echo "正在构建依赖库..."
    ./scripts/build.sh
fi

probe_dir=$(mktemp -d -t tomatobar-showcase-capture)
trap 'rm -rf "$probe_dir" "$seed_bin"' EXIT

sed '/^@main$/d' TomatoBar/App.swift > "$probe_dir/App.swift"

xcrun swiftc -I "$products" \
  TomatoBar/State.swift TomatoBar/Log.swift TomatoBar/Analytics.swift \
  TomatoBar/Timer.swift TomatoBar/View.swift TomatoBar/MainWindow.swift \
  TomatoBar/FocusCharts.swift TomatoBar/DesktopPet.swift TomatoBar/Notifications.swift TomatoBar/LaunchContext.swift \
  "$probe_dir/App.swift" scripts/capture-window.swift \
  "$products/KeyboardShortcuts.o" "$products/LaunchAtLogin.o" -o "$probe_dir/capture-host"

echo "3/4 启动隔离窗口并捕捉视网膜截图..."
log_file="$probe_dir/capture.log"
"$probe_dir/capture-host" "$(pwd)/demo/sessions.json" > "$log_file" 2>&1 &
host_pid=$!

# Wait for window ID
win_id=""
for i in {1..30}; do
    if grep -q "SHOWCASE_WINDOW_ID:" "$log_file" 2>/dev/null; then
        win_id=$(grep "SHOWCASE_WINDOW_ID:" "$log_file" | head -1 | cut -d':' -f2)
        break
    fi
    sleep 0.2
done

if [ -z "${win_id}" ]; then
    echo "未能在规定时间内获取窗口 ID。日志："
    cat "$log_file"
    kill "$host_pid" 2>/dev/null || true
    exit 1
fi

echo "捕捉到演示窗口 ID: ${win_id}，正在截图..."
screencapture -l "${win_id}" -o site/hero-day.png
cp site/hero-day.png screenshot.png
kill "$host_pid" 2>/dev/null || true

echo "4/4 截图已更新并与私人数据源彻底分离！"
sips -g pixelWidth -g pixelHeight site/hero-day.png
