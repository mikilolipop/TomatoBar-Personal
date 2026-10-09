#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
probe_dir=$(mktemp -d -t tomatobar-pet-motion)
trap 'rm -rf "$probe_dir"' EXIT
xcrun swiftc TomatoBar/State.swift TomatoBar/Log.swift TomatoBar/Analytics.swift TomatoBar/PetMotion.swift Tests/PetMotion/main.swift -o "$probe_dir/probe"
"$probe_dir/probe"
