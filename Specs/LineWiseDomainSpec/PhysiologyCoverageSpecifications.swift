import Foundation
import LineWiseDomain

// The heart-rate coverage accumulator turns the timestamps of collected
// heart-rate samples into HealthKitWorkoutSummary.heartRateCoverage — the
// fraction of a workout for which the Watch actually produced heart-rate data.
// Coverage is context only and non-diagnostic; it exists so the UI can be
// honest about how complete the optional sensor stream was.

func physiologyCoverageSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "coverage measures the time heart-rate data was collected, not the span between samples",
      coverageMeasuresCollectedTimeNotSampleSpan
    ),
    (
      "a sensor dropout stays uncovered no matter how far apart the surrounding samples are",
      sensorDropoutStaysUncovered
    ),
    (
      "a continuously sampled workout still reports full coverage",
      continuouslySampledWorkoutReportsFullCoverage
    ),
    (
      "overlapping and adjacent sample windows are merged before measuring coverage",
      overlappingSampleWindowsAreMerged
    ),
    (
      "an instantaneous collection window still counts as collected data",
      instantaneousWindowCountsAsCollectedData
    ),
    (
      "coverage clamps to one and reports zero when no samples arrive",
      coverageClampsAndHandlesEmptyStream
    ),
    (
      "accumulated coverage produces a summary the physiology contract accepts",
      accumulatedCoverageProducesValidSummary
    ),
    (
      "non-finite heart-rate, energy, effort and duration values are rejected",
      nonFiniteHealthValuesAreRejected
    ),
    (
      "an accepted physiology context survives save and reopen",
      acceptedPhysiologyContextSurvivesSaveAndReopen
    ),
    (
      "an entirely skipped subjective check-in is not recorded as a user report",
      emptySubjectiveCheckInIsNotAUserReport
    ),
    (
      "one unusable sensor reading does not discard the readings around it",
      oneUnusableReadingDoesNotDiscardTheOthers
    ),
  ]
}

private func coverageMeasuresCollectedTimeNotSampleSpan() throws {
  // Two readings 100 seconds apart are two readings, not 100 seconds of data.
  var sparse = HeartRateCoverageAccumulator()
  sparse.observeSample(at: 0, bpm: 120)
  sparse.observeSample(at: 100, bpm: 140)

  let sparseCoverage = sparse.coverage(overWorkoutDurationSeconds: 100)
  try expect(
    sparseCoverage < 0.2,
    "two isolated readings must not report most of the workout as covered"
  )

  // Coverage must never be inflated by adding samples inside already covered
  // windows: the truthfully covered time here is 20s of 100s.
  var mixed = HeartRateCoverageAccumulator()
  mixed.observeWindow(startSeconds: 0, endSeconds: 10, bpm: 110)
  mixed.observeWindow(startSeconds: 90, endSeconds: 100, bpm: 150)
  mixed.observeSample(at: 5, bpm: 115)
  mixed.observeSample(at: 95, bpm: 148)

  let mixedCoverage = mixed.coverage(overWorkoutDurationSeconds: 100)
  try expect(
    mixedCoverage < 0.4,
    "samples inside collected windows must not bridge the gap between those windows"
  )
}

private func sensorDropoutStaysUncovered() throws {
  // A 600s session where the Watch produced readings only during the first and
  // last ten seconds: the 580s hole is missing data, not covered data.
  var accumulator = HeartRateCoverageAccumulator()
  for second in stride(from: 0.0, through: 10.0, by: 1) {
    accumulator.observeSample(at: second, bpm: 120)
  }
  for second in stride(from: 590.0, through: 600.0, by: 1) {
    accumulator.observeSample(at: second, bpm: 130)
  }

  let coverage = accumulator.coverage(overWorkoutDurationSeconds: 600)
  try expect(
    coverage < 0.1,
    "a 580 second sensor dropout must be reported as missing, not covered"
  )
  try expect(
    coverage > 0,
    "the seconds that did produce readings must still count as covered"
  )
}

private func continuouslySampledWorkoutReportsFullCoverage() throws {
  // The honest counterpart: an uninterrupted stream at the Watch's workout
  // cadence must still read as complete, otherwise the quality gate would hide
  // avg/max for every real session.
  var accumulator = HeartRateCoverageAccumulator()
  for second in stride(from: 0.0, through: 100.0, by: 5) {
    accumulator.observeSample(at: second, bpm: 135)
  }

  try expect(
    accumulator.coverage(overWorkoutDurationSeconds: 100) >= 0.95,
    "an uninterrupted heart-rate stream must report essentially full coverage"
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

private func instantaneousWindowCountsAsCollectedData() throws {
  // A heart-rate reading covers one instant, so the window a sensor reports for
  // it can start and end at the same second. That is still data the Watch
  // produced: a stream of such readings must not read as "no data at all".
  var instant = HeartRateCoverageAccumulator()
  instant.observeWindow(startSeconds: 30, endSeconds: 30, bpm: 132)
  try expect(
    instant.coverage(overWorkoutDurationSeconds: 100) > 0,
    "a zero-length collection window is still a reading, not missing data"
  )

  var stream = HeartRateCoverageAccumulator()
  for second in stride(from: 0.0, through: 100.0, by: 5) {
    stream.observeWindow(startSeconds: second, endSeconds: second, bpm: 130)
  }
  try expect(
    stream.coverage(overWorkoutDurationSeconds: 100) >= 0.95,
    "an uninterrupted stream of instant readings must report essentially full coverage"
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

private func nonFiniteSummary(
  durationSeconds: Double = 100,
  averageHeartRateBPM: Double? = nil,
  maximumHeartRateBPM: Double? = nil,
  heartRateCoverage: Double? = nil,
  activeEnergyKilocalories: Double? = nil,
  workoutEffortScore: Double? = nil,
  workoutEffortSource: WorkoutEffortSource? = nil
) -> HealthKitWorkoutSummary {
  HealthKitWorkoutSummary(
    durationSeconds: durationSeconds,
    averageHeartRateBPM: averageHeartRateBPM,
    maximumHeartRateBPM: maximumHeartRateBPM,
    heartRateCoverage: heartRateCoverage,
    activeEnergyKilocalories: activeEnergyKilocalories,
    workoutEffortScore: workoutEffortScore,
    workoutEffortSource: workoutEffortSource,
    sourceVersion: "healthkit-live-workout-v1"
  )
}

private func nonFiniteHealthValuesAreRejected() throws {
  let cases: [(String, HealthKitWorkoutSummary, PhysiologyContextRejection)] = [
    (
      "a NaN average heart rate", nonFiniteSummary(averageHeartRateBPM: .nan), .invalidHeartRate
    ),
    (
      "an infinite average heart rate",
      nonFiniteSummary(averageHeartRateBPM: .infinity), .invalidHeartRate
    ),
    (
      "a NaN maximum heart rate", nonFiniteSummary(maximumHeartRateBPM: .nan), .invalidHeartRate
    ),
    (
      "a NaN heart-rate coverage",
      nonFiniteSummary(heartRateCoverage: .nan), .invalidHeartRateCoverage
    ),
    (
      "an infinite active energy",
      nonFiniteSummary(activeEnergyKilocalories: .infinity), .invalidActiveEnergy
    ),
    (
      "a NaN active energy",
      nonFiniteSummary(activeEnergyKilocalories: .nan), .invalidActiveEnergy
    ),
    (
      "a NaN workout effort score",
      nonFiniteSummary(workoutEffortScore: .nan, workoutEffortSource: .perceived),
      .invalidWorkoutEffort
    ),
    (
      "a NaN workout duration", nonFiniteSummary(durationSeconds: .nan), .invalidWorkoutDuration
    ),
    (
      "an infinite workout duration",
      nonFiniteSummary(durationSeconds: .infinity), .invalidWorkoutDuration
    ),
  ]

  for (description, summary, expectedRejection) in cases {
    let outcome = PhysiologyContextService.build(
      contextID: PhysiologyContextID("non-finite"),
      visitID: GymVisitID("non-finite-visit"),
      subjective: nil,
      healthKitSummary: summary,
      recordedAt: Instant(millisecondsSince1970: 1_000)
    )
    try expect(
      outcome == .rejected(expectedRejection),
      "\(description) must be rejected as unusable sensor context, not accepted"
    )
  }
}

private func acceptedPhysiologyContextSurvivesSaveAndReopen() throws {
  // The archive is JSON, and JSONEncoder refuses non-finite Doubles. Any context
  // the service accepts must therefore still be encodable, or accepting it once
  // would stop the whole visit from ever persisting again.
  var accumulator = HeartRateCoverageAccumulator()
  accumulator.observeSample(at: 5, bpm: 118)
  accumulator.observeSample(at: 55, bpm: 150)

  let outcome = PhysiologyContextService.build(
    contextID: PhysiologyContextID("encodable-context"),
    visitID: GymVisitID("encodable-visit"),
    subjective: SubjectivePhysiologyCheckIn(
      sessionEffort1To10: 6,
      wholeBodyFatigue0To10: 4,
      forearmPumpOverall: .moderate
    ),
    healthKitSummary: nonFiniteSummary(
      averageHeartRateBPM: accumulator.averageBPM,
      maximumHeartRateBPM: accumulator.maximumBPM,
      heartRateCoverage: accumulator.coverage(overWorkoutDurationSeconds: 100)
    ),
    recordedAt: Instant(millisecondsSince1970: 1_000)
  )
  guard case .built(let context) = outcome else {
    throw SpecFailure.expected("a finite accumulated summary should build")
  }
  let reopened = try JSONDecoder().decode(
    PhysiologyContextSnapshot.self,
    from: JSONEncoder().encode(context)
  )
  try expect(reopened == context, "an accepted physiology context must survive save and reopen")

  // And the same must hold for a summary carrying a value the sensor could not
  // produce: rejecting it is what keeps the archive writable.
  let poisoned = PhysiologyContextService.build(
    contextID: PhysiologyContextID("poisoned-context"),
    visitID: GymVisitID("encodable-visit"),
    subjective: nil,
    healthKitSummary: nonFiniteSummary(averageHeartRateBPM: .nan),
    recordedAt: Instant(millisecondsSince1970: 2_000)
  )
  guard case .built(let poisonedContext) = poisoned else { return }
  _ = try? JSONEncoder().encode(poisonedContext)
  throw SpecFailure.expected(
    "a non-finite health value must never be accepted into a JSON-encodable archive"
  )
}

private func emptySubjectiveCheckInIsNotAUserReport() throws {
  // A check-in where the climber skipped every question is not a report.
  let empty = SubjectivePhysiologyCheckIn(
    sessionEffort1To10: nil,
    wholeBodyFatigue0To10: nil,
    forearmPumpOverall: nil
  )

  let aloneOutcome = PhysiologyContextService.build(
    contextID: PhysiologyContextID("empty-subjective"),
    visitID: GymVisitID("empty-subjective-visit"),
    subjective: empty,
    healthKitSummary: nil,
    recordedAt: Instant(millisecondsSince1970: 1_000)
  )
  try expect(
    aloneOutcome == .rejected(.noContextProvided),
    "an entirely skipped check-in with no HealthKit summary is no context at all"
  )

  let withSupportingContext = PhysiologyContextService.build(
    contextID: PhysiologyContextID("empty-subjective-with-healthkit"),
    visitID: GymVisitID("empty-subjective-visit"),
    subjective: empty,
    healthKitSummary: nonFiniteSummary(
      averageHeartRateBPM: 132,
      maximumHeartRateBPM: 171,
      heartRateCoverage: 0.8
    ),
    recordedAt: Instant(millisecondsSince1970: 2_000)
  )
  guard case .built(let context) = withSupportingContext else {
    throw SpecFailure.expected("an optional HealthKit summary should remain usable context")
  }
  try expect(
    context.primarySource == .none,
    "a skipped check-in must not be labelled a subjective report the user never made"
  )
  try expect(
    context.reportedSessionEffort1To10 == nil
      && context.reportedWholeBodyFatigue0To10 == nil
      && context.reportedForearmPumpOverall == nil,
    "no subjective value should be readable from a skipped check-in"
  )
  try expect(
    context.healthKitRole == .optionalSupportingContext,
    "HealthKit must remain supporting context on its own"
  )
}

private func oneUnusableReadingDoesNotDiscardTheOthers() throws {
  // The optical sensor can hand back a reading that is not a number at all. One
  // such reading must not silently destroy the average and maximum computed from
  // the good readings around it: the archive is JSON, so a non-finite value there
  // makes the whole visit unsavable, and the honest answer for a stream that did
  // produce usable readings is those readings, not "no data".
  var accumulator = HeartRateCoverageAccumulator()
  accumulator.observeSample(at: 0, bpm: 120)
  accumulator.observeSample(at: 3, bpm: .nan)
  accumulator.observeSample(at: 6, bpm: 150)

  try expect(
    accumulator.averageBPM?.isFinite == true,
    "one unusable reading must not make the average unreportable"
  )
  try expect(
    accumulator.maximumBPM?.isFinite == true,
    "one unusable reading must not make the maximum unreportable"
  )
  try expect(
    approximatelyEqual(accumulator.averageBPM ?? -1, 135),
    "the average must be taken over the readings that were usable (120 and 150)"
  )
  try expect(
    accumulator.maximumBPM == 150,
    "the maximum must be the highest usable reading"
  )
  try expect(
    accumulator.coverage(overWorkoutDurationSeconds: 100) > 0,
    "a reading with an unusable value still attests that the sensor reported"
  )

  // A reading that arrives before any good one must not poison the maximum
  // either, since max(nan, x) is nan.
  var nanFirst = HeartRateCoverageAccumulator()
  nanFirst.observeWindow(startSeconds: 0, endSeconds: 5, bpm: .infinity)
  nanFirst.observeWindow(startSeconds: 5, endSeconds: 10, bpm: 130)
  try expect(
    nanFirst.maximumBPM == 130,
    "an unusable first reading must not become the reported maximum"
  )

  // A stream of nothing but unusable values has no reportable rate at all —
  // reporting nil is the honest answer, not a fabricated number.
  var allUnusable = HeartRateCoverageAccumulator()
  allUnusable.observeSample(at: 10, bpm: .nan)
  try expect(
    allUnusable.averageBPM == nil && allUnusable.maximumBPM == nil,
    "a stream with no usable reading must report no rate rather than a made-up one"
  )

  // And whatever the accumulator reports must be something the contract accepts,
  // because that is the only path these values reach the archive by.
  let outcome = PhysiologyContextService.build(
    contextID: PhysiologyContextID("unusable-reading"),
    visitID: GymVisitID("unusable-reading-visit"),
    subjective: nil,
    healthKitSummary: nonFiniteSummary(
      averageHeartRateBPM: accumulator.averageBPM,
      maximumHeartRateBPM: accumulator.maximumBPM,
      heartRateCoverage: accumulator.coverage(overWorkoutDurationSeconds: 100)
    ),
    recordedAt: Instant(millisecondsSince1970: 3_000)
  )
  guard case .built(let context) = outcome else {
    throw SpecFailure.expected("a summary built from usable readings should be accepted")
  }
  _ = try JSONEncoder().encode(context)
}
