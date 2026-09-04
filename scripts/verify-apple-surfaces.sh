#!/bin/bash
# Verify the platform-gated Apple code that `swift build` on macOS does not reach.
#
# Why this exists: `swift build` succeeding on macOS is NOT evidence that the
# Apple app targets compile. Two hard compile errors sat undetected in
# AppleSurfaces.swift because every local build skipped the file:
#
#   - the file is gated on `#if canImport(SwiftUI) && (os(iOS) || os(watchOS))`,
#     and neither os() condition is true on macOS;
#   - a type error inside an INACTIVE `#if` branch is invisible to both
#     `swiftc -parse` and `swiftc -typecheck`. Only making the branch active
#     catches it.
#
# Run this before claiming an Apple-surface change is verified.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SDK=$(xcrun --sdk macosx --show-sdk-path)
FRAMEWORKS="$SDK/System/iOSSupport/System/Library/Frameworks"
SWIFT_LIBS="$SDK/System/iOSSupport/usr/lib/swift"
status=0

if [ ! -d "$FRAMEWORKS" ]; then
  echo "SKIP: no Catalyst iOSSupport in $SDK — cannot compile the os(iOS) code here."
  exit 0
fi

echo "==> 1/3  macOS (Domain, Application, AI adapters, SwiftUI surfaces)"
if swift build; then
  echo "    ok"
else
  echo "    FAILED"
  status=1
fi

# The Command Line Tools macOS SDK bundles Catalyst iOSSupport, including
# HealthKit, WatchConnectivity and PhotosUI. A macabi triple makes os(iOS)
# true, which compiles the Watch/iPhone capture surfaces and the
# WatchConnectivity transport for the first time.
echo "==> 2/3  iOS via Catalyst triple (os(iOS) code: capture surfaces, WatchConnectivity)"
if swift build --triple x86_64-apple-ios18.0-macabi \
  -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
  -Xswiftc -I -Xswiftc "$SWIFT_LIBS"; then
  echo "    ok"
else
  echo "    FAILED"
  status=1
fi

# No triple available on a Command Line Tools installation makes os(watchOS)
# true, so the watch-only branches are compiled by nobody. Temporarily force
# them active and build for macOS, where SwiftUI is real. This catches SwiftUI
# type errors — it does NOT validate watchOS-only APIs, which still require a
# real watchOS SDK and a signed device.
echo "==> 3/3  watchOS-only SwiftUI branches (forced active, type-check only)"
GATED="Sources/LineWiseAppleAdapters/AppleSurfaces.swift"
BACKUP=$(mktemp)
cp "$GATED" "$BACKUP"
# shellcheck disable=SC2064
trap "cp '$BACKUP' '$GATED'; rm -f '$BACKUP'" EXIT

python3 - "$GATED" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("#if canImport(SwiftUI) && (os(iOS) || os(watchOS))", "#if canImport(SwiftUI)", 1)
s = s.replace("#if os(watchOS)", "#if true")
open(p, "w").write(s)
PY

# Capture the build output once. `swift build` writes diagnostics to stderr, so
# the redirect is load-bearing: without it the pipe sees nothing and every
# error slips through as a pass.
FORCED_LOG=$(mktemp)
swift build >"$FORCED_LOG" 2>&1
if grep -q 'error:' "$FORCED_LOG"; then
  echo "    FAILED — errors in the watchOS-only branches:"
  grep 'error:' "$FORCED_LOG" | sed 's/^/      /' | sort -u | head -20
  status=1
else
  echo "    ok"
fi
rm -f "$FORCED_LOG"

cp "$BACKUP" "$GATED"
rm -f "$BACKUP"
trap - EXIT

echo
if [ "$status" -eq 0 ]; then
  echo "All reachable Apple configurations compile."
  echo "STILL OPEN: watchOS-only APIs (HKWorkoutSession / HKLiveWorkoutBuilder are"
  echo "unavailable in Mac Catalyst) and every runtime behaviour. Those need a full"
  echo "Xcode installation and a signed, paired iPhone and Apple Watch."
else
  echo "One or more configurations failed. See above."
fi
exit "$status"
