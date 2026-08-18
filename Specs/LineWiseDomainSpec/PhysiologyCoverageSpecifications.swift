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
