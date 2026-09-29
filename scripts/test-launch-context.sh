#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
probe_dir=$(mktemp -d -t tomatobar-launch-checks)
trap 'rm -rf "$probe_dir"' EXIT
xcrun swiftc TomatoBar/LaunchContext.swift Tests/LaunchContext/main.swift -o "$probe_dir/probe"
"$probe_dir/probe"
