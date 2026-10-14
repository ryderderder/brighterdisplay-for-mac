#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache dist/XDRLift.app/Contents/MacOS
swiftc -swift-version 5 -O -module-cache-path .build/module-cache -target arm64-apple-macosx13.0 Sources/Core/*.swift Sources/XDRLift/*.swift -o dist/XDRLift.app/Contents/MacOS/XDRLift
cp Resources/Info.plist dist/XDRLift.app/Contents/Info.plist
codesign --force --sign - dist/XDRLift.app
codesign --verify --strict dist/XDRLift.app
