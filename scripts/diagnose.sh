#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
swiftc -swift-version 5 -module-cache-path .build/module-cache -target arm64-apple-macosx13.0 Sources/Core/Gamma.swift Sources/BrighterDisplay/Display.swift Diagnostics/main.swift -o .build/xdrlift-diagnostic
exec .build/xdrlift-diagnostic
