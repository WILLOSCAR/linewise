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

echo "==> 1/4  macOS (Domain, Application, AI adapters, SwiftUI surfaces)"
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
echo "==> 2/4  iOS via Catalyst triple (os(iOS) code: capture surfaces, WatchConnectivity)"
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
echo "==> 3/4  watchOS-only SwiftUI branches (forced active, type-check only)"
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

# The HealthKit recorder is gated on os(watchOS) and cannot be reached by any
# triple here. Two of the APIs it calls are API_UNAVAILABLE(macCatalyst) outright:
# HKWorkoutSession.init(healthStore:configuration:) and
# associatedWorkoutBuilder(). Everything else in the file type-checks against
# Catalyst once a deployment target new enough for the live-workout types is
# declared, so this stage compiles it and tolerates exactly those two — any THIRD
# error is a real defect that nothing else here would catch.
echo "==> 4/4  HealthKit recorder (Catalyst type-check, 2 known-unavailable APIs)"
HK_GATED="Sources/LineWiseAppleAdapters/AppleAdapters.swift"
HK_BACKUP=$(mktemp)
cp "$HK_GATED" "$HK_BACKUP"
# shellcheck disable=SC2064
trap "cp '$HK_BACKUP' '$HK_GATED'; rm -f '$HK_BACKUP'" EXIT

python3 - "$HK_GATED" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("#if canImport(HealthKit) && os(watchOS)", "#if canImport(HealthKit)", 1)
s = s.replace(
    "  public final class HealthKitWorkoutRecorder: NSObject, WorkoutRecording, @unchecked Sendable {",
    "  @available(macCatalyst 26.0, *)\n"
    "  public final class HealthKitWorkoutRecorder: NSObject, WorkoutRecording, @unchecked Sendable {",
    1,
)
s = s.replace(
    "  extension HealthKitWorkoutRecorder: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {",
    "  @available(macCatalyst 26.0, *)\n"
    "  extension HealthKitWorkoutRecorder: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {",
    1,
)
open(p, "w").write(s)
PY

HK_LOG=$(mktemp)
swift build --triple x86_64-apple-ios26.0-macabi \
  -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
  -Xswiftc -I -Xswiftc "$SWIFT_LIBS" >"$HK_LOG" 2>&1
UNEXPECTED=$(grep -oE '^/.*error: .*' "$HK_LOG" \
  | grep -v "init(healthStore:configuration:)' is unavailable in Mac Catalyst" \
  | grep -v "associatedWorkoutBuilder()' is unavailable in Mac Catalyst" \
  | sort -u)
if [ -n "$UNEXPECTED" ]; then
  echo "    FAILED — errors beyond the two known-unavailable APIs:"
  echo "$UNEXPECTED" | sed 's/^/      /' | head -20
  status=1
else
  echo "    ok (only the 2 expected Catalyst-unavailable APIs remain)"
fi
rm -f "$HK_LOG"

cp "$HK_BACKUP" "$HK_GATED"
rm -f "$HK_BACKUP"
trap - EXIT

echo
if [ "$status" -eq 0 ]; then
  echo "All reachable Apple configurations compile."
  echo "STILL OPEN: HKWorkoutSession creation itself (unavailable in Mac Catalyst,"
  echo "so only a real watchOS SDK compiles it) and every runtime behaviour. Those"
  echo "need a full Xcode installation and a signed, paired iPhone and Apple Watch."
else
  echo "One or more configurations failed. See above."
fi
exit "$status"
