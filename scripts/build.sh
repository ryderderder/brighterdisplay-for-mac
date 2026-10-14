#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app='dist/BrighterDisplay for Mac.app'
mkdir -p .build/module-cache "$app/Contents/MacOS"
swiftc -swift-version 5 -O -module-cache-path .build/module-cache -target arm64-apple-macosx13.0 Sources/Core/*.swift Sources/BrighterDisplay/*.swift -o "$app/Contents/MacOS/BrighterDisplay"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
