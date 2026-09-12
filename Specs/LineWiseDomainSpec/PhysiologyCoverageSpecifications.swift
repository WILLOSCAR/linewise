import LineWiseDomain

// The heart-rate coverage accumulator turns the timestamps of collected
// heart-rate samples into HealthKitWorkoutSummary.heartRateCoverage — the
// fraction of a workout for which the Watch actually produced heart-rate data.
// Coverage is context only and non-diagnostic; it exists so the UI can be
// honest about how complete the optional sensor stream was.

func physiologyCoverageSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "coverage is the fraction of workout duration spanned by heart-rate samples",
      coverageIsFractionOfDurationSpannedBySamples
    ),
    (
      "overlapping and adjacent sample windows are merged before measuring coverage",
      overlappingSampleWindowsAreMerged
    ),
    (
      "a sensor dropout between windows is excluded from coverage",
      disjointSampleWindowsExcludeTheGap
    ),
    (
      "coverage clamps to one and reports zero when no samples arrive",
      coverageClampsAndHandlesEmptyStream
    ),
    (
      "accumulated coverage produces a summary the physiology contract accepts",
      accumulatedCoverageProducesValidSummary
    ),
  ]
}

private func coverageIsFractionOfDurationSpannedBySamples() throws {
  // A 100s workout with heart-rate samples covering [10s, 60s] => 50s of 100s.
  var accumulator = HeartRateCoverageAccumulator()
  accumulator.observeSample(at: 10, bpm: 120)
  accumulator.observeSample(at: 60, bpm: 140)

  let coverage = accumulator.coverage(overWorkoutDurationSeconds: 100)
  try expect(
    approximatelyEqual(coverage, 0.5),
    "50 covered seconds of a 100 second workout should be 0.5 coverage"
  )
}

private func overlappingSampleWindowsAreMerged() throws {
  // Windows [0,30] and [20,40] overlap => union [0,40] = 40s, not 50s.
  var accumulator = HeartRateCoverageAccumulator()
  accumulator.observeWindow(startSeconds: 0, endSeconds: 30, bpm: 110)
  accumulator.observeWindow(startSeconds: 20, endSeconds: 40, bpm: 115)

  let coverage = accumulator.coverage(overWorkoutDurationSeconds: 80)
  try expect(
    approximatelyEqual(coverage, 0.5),
    "overlapping windows must be unioned to 40s of 80s = 0.5, not double counted"
  )

  // Touching windows [0,20] and [20,40] are contiguous => union [0,40] = 40s.
  var touching = HeartRateCoverageAccumulator()
  touching.observeWindow(startSeconds: 0, endSeconds: 20, bpm: 110)
  touching.observeWindow(startSeconds: 20, endSeconds: 40, bpm: 115)
  try expect(
    approximatelyEqual(touching.coverage(overWorkoutDurationSeconds: 80), 0.5),
    "adjacent windows that touch at a boundary must merge into one 40s span"
  )
}

private func disjointSampleWindowsExcludeTheGap() throws {
  // The reason coverage exists: the Watch dropped out mid-session. Windows
  // [0,10] and [70,80] of a 100s workout cover 20s, so coverage is 0.2 — the
  // span from the first to the last sample (80s) is NOT what was measured.
  var accumulator = HeartRateCoverageAccumulator()
  accumulator.observeWindow(startSeconds: 0, endSeconds: 10, bpm: 112)
  accumulator.observeWindow(startSeconds: 70, endSeconds: 80, bpm: 148)

  try expect(
    approximatelyEqual(accumulator.coverage(overWorkoutDurationSeconds: 100), 0.2),
    "a dropout between two windows must be excluded: 20 covered seconds of 100 is 0.2"
  )

  // Three windows with two gaps, delivered out of order, as repeated collection
  // callbacks arrive: [0,10] + [30,40] + [60,70] = 30s of 100s.
  var outOfOrder = HeartRateCoverageAccumulator()
  outOfOrder.observeWindow(startSeconds: 60, endSeconds: 70, bpm: 150)
  outOfOrder.observeWindow(startSeconds: 0, endSeconds: 10, bpm: 110)
  outOfOrder.observeWindow(startSeconds: 30, endSeconds: 40, bpm: 130)
  try expect(
    approximatelyEqual(outOfOrder.coverage(overWorkoutDurationSeconds: 100), 0.3),
    "several disjoint windows must sum their own lengths regardless of arrival order"
  )

  // A window fully contained inside another adds nothing.
  var nested = HeartRateCoverageAccumulator()
  nested.observeWindow(startSeconds: 0, endSeconds: 40, bpm: 120)
  nested.observeWindow(startSeconds: 10, endSeconds: 20, bpm: 125)
  try expect(
    approximatelyEqual(nested.coverage(overWorkoutDurationSeconds: 80), 0.5),
    "a window nested inside another must not extend or shrink coverage"
  )
}

private func coverageClampsAndHandlesEmptyStream() throws {
  var empty = HeartRateCoverageAccumulator()
  try expect(
    empty.coverage(overWorkoutDurationSeconds: 60) == 0,
    "no samples means zero coverage"
  )
  try expect(
    empty.coverage(overWorkoutDurationSeconds: 0) == 0,
    "a zero-length workout must not divide by zero"
  )

  var overshoot = HeartRateCoverageAccumulator()
  overshoot.observeWindow(startSeconds: 0, endSeconds: 200, bpm: 130)
  try expect(
    overshoot.coverage(overWorkoutDurationSeconds: 100) == 1,
    "covered time beyond the workout duration must clamp to 1"
  )
}

private func accumulatedCoverageProducesValidSummary() throws {
  var accumulator = HeartRateCoverageAccumulator()
  accumulator.observeSample(at: 5, bpm: 118)
  accumulator.observeSample(at: 55, bpm: 150)

  let summary = HealthKitWorkoutSummary(
    durationSeconds: 100,
    averageHeartRateBPM: accumulator.averageBPM,
    maximumHeartRateBPM: accumulator.maximumBPM,
    heartRateCoverage: accumulator.coverage(overWorkoutDurationSeconds: 100),
    activeEnergyKilocalories: nil,
    workoutEffortScore: nil,
    workoutEffortSource: nil,
    sourceVersion: "healthkit-live-workout-v1"
  )

  let outcome = PhysiologyContextService.build(
    contextID: PhysiologyContextID("coverage-summary"),
    visitID: GymVisitID("coverage-visit"),
    subjective: SubjectivePhysiologyCheckIn(
      sessionEffort1To10: 6,
      wholeBodyFatigue0To10: 4,
      forearmPumpOverall: .moderate
    ),
    healthKitSummary: summary,
    recordedAt: Instant(millisecondsSince1970: 1_000)
  )
  try expect(
    outcome.isBuilt,
    "an accumulated coverage summary must satisfy the physiology contract"
  )
  try expect(
    approximatelyEqual(summary.averageHeartRateBPM ?? -1, 134),
    "average of 118 and 150 should be 134"
  )
  try expect(
    summary.maximumHeartRateBPM == 150,
    "maximum heart rate should track the highest observed sample"
  )
}

private func approximatelyEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
  abs(lhs - rhs) <= tolerance
}
