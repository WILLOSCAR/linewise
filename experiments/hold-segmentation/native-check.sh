#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: native-check.sh <private-cases.json> <Tiny-models-directory>" >&2
  exit 2
fi
task_script_dir=$(cd "$(dirname "$0")" && pwd)
task_repo=$(cd "$task_script_dir/../.." && pwd)
task_output="$task_script_dir/.build/native-check"
mkdir -p "$(dirname "$task_output")"

# Compile the actual App inference/domain sources, not the September prototype algorithm.
xcrun swiftc -O -parse-as-library \
  "$task_repo/app/LineWise/Domain/Hold.swift" \
  "$task_repo/app/LineWise/Domain/HoldContour.swift" \
  "$task_repo/app/LineWise/Services/HoldPointSegmenting.swift" \
  "$task_repo/app/LineWise/Services/SAMModelCatalog.swift" \
  "$task_repo/app/LineWise/Services/SAMMaskContour.swift" \
  "$task_repo/app/LineWise/Services/SAMPointSegmenter.swift" \
  "$task_script_dir/native-check/main.swift" -o "$task_output"
"$task_output" "$1" "$2"
