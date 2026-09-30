#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_binary=$(mktemp -t tomatobar-tests)
trap 'rm -f "$test_binary"' EXIT
xcrun swiftc TomatoBar/State.swift TomatoBar/Log.swift TomatoBar/Analytics.swift TomatoBar/WidgetSnapshot.swift Tests/main.swift -o "$test_binary"
"$test_binary"
