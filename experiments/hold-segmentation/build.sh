#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p .build
xcrun swiftc -O shared.swift compare/main.swift -o .build/proto
xcrun swiftc -O shared.swift auto/main.swift -o .build/autoroute
xcrun swiftc -O shared.swift wall/main.swift -o .build/wallseg
