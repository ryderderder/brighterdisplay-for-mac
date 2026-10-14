#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
swiftc -swift-version 5 -module-cache-path .build/module-cache Sources/Core/*.swift Tests/main.swift -o .build/core-tests
.build/core-tests
