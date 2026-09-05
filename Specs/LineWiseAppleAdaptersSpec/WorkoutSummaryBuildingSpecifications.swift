import Foundation
import LineWiseAppleAdapters
import LineWiseDomain

// The HealthKit recorder cannot be compiled here: HKWorkoutSession's initializer
// and associatedWorkoutBuilder() are marked unavailable in Mac Catalyst, and no
// triple on a Command Line Tools installation makes os(watchOS) true. Everything
// the recorder DECIDES, though, is ordinary logic that happened to live inside
// that gate — so it was reachable by no build and no specification at all.
//
// These pin the decisions themselves. The recorder now delegates to them, which
// leaves only the calls into HealthKit's own types behind the gate.

func workoutSummaryBuildingSpecifications() -> [(String, () async throws -> Void)] {
  [
    (
      "workout authorization state maps every HealthKit sharing status",
      workoutAuthorizationStateMapsEverySharingStatus
    ),
    (
      "a workout summary reports elapsed duration and omits coverage it cannot claim",
      workoutSummaryReportsElapsedDurationAndOmitsUnknownCoverage
    ),
    (
      "a workout summary carries the readings it was given without inventing any",
      workoutSummaryCarriesGivenReadingsWithoutInventing
    ),
  ]
}

private func workoutAuthorizationStateMapsEverySharingStatus() async throws {
  // Denial and "not yet asked" are different product states: one is a decision the
  // user made, the other is a prompt not yet shown. Collapsing them would either
  // nag a user who said no or silently skip asking.
  try expect(
    WorkoutCapability.state(healthDataAvailable: false, isAuthorized: nil) == .unavailable,
    "a device without Health data must report unavailable, not denied"
  )
  try expect(
    WorkoutCapability.state(healthDataAvailable: true, isAuthorized: nil)
      == .authorizationRequired,
    "an undetermined status must ask, not assume refusal"
  )
  try expect(
    WorkoutCapability.state(healthDataAvailable: true, isAuthorized: false) == .denied,
    "an explicit refusal must be preserved as denied"
  )
  try expect(
    WorkoutCapability.state(healthDataAvailable: true, isAuthorized: true) == .ready,
    "an authorized store must be ready to record"
  )
}

private func workoutSummaryReportsElapsedDurationAndOmitsUnknownCoverage() async throws {
  let start = Date(timeIntervalSince1970: 1_000)
  var accumulator = HeartRateCoverageAccumulator()
  accumulator.observeWindow(startSeconds: 0, endSeconds: 30, bpm: 130)

  let summary = WorkoutSummaryBuilder.summary(
    startedAt: start,
    endedAt: start.addingTimeInterval(60),
    coverageAccumulator: accumulator,
    averageHeartRateBPM: 130,
    maximumHeartRateBPM: 150,
    activeEnergyKilocalories: 42
  )
  try expect(summary.durationSeconds == 60, "expected the elapsed workout duration")
  try expect(
    summary.heartRateCoverage == 0.5,
    "30 collected seconds of a 60 second workout is 0.5 coverage, got \(String(describing: summary.heartRateCoverage))"
  )

  // A workout with no elapsed time has no denominator, so coverage is unknown
  // rather than zero — reporting 0 would assert the sensor produced nothing.
  let instant = WorkoutSummaryBuilder.summary(
    startedAt: start,
    endedAt: start,
    coverageAccumulator: accumulator,
    averageHeartRateBPM: nil,
    maximumHeartRateBPM: nil,
    activeEnergyKilocalories: nil
  )
  try expect(instant.durationSeconds == 0, "a zero-length workout has zero duration")
  try expect(
    instant.heartRateCoverage == nil,
    "coverage over no elapsed time is unknown, not zero"
  )

  // A stop date before the start (clock adjustment mid-session) must not produce a
  // negative duration, which PhysiologyContextService would reject outright.
  let backwards = WorkoutSummaryBuilder.summary(
    startedAt: start,
    endedAt: start.addingTimeInterval(-30),
    coverageAccumulator: accumulator,
    averageHeartRateBPM: nil,
    maximumHeartRateBPM: nil,
    activeEnergyKilocalories: nil
  )
  try expect(
    backwards.durationSeconds == 0,
    "a backwards clock must clamp to zero, got \(backwards.durationSeconds)"
  )
}

private func workoutSummaryCarriesGivenReadingsWithoutInventing() async throws {
  let start = Date(timeIntervalSince1970: 2_000)
  let summary = WorkoutSummaryBuilder.summary(
    startedAt: start,
    endedAt: start.addingTimeInterval(100),
    coverageAccumulator: HeartRateCoverageAccumulator(),
    averageHeartRateBPM: nil,
    maximumHeartRateBPM: nil,
    activeEnergyKilocalories: nil
  )
  try expect(
    summary.averageHeartRateBPM == nil && summary.maximumHeartRateBPM == nil
      && summary.activeEnergyKilocalories == nil,
    "absent readings must stay absent rather than becoming zero"
  )
  try expect(
    summary.heartRateCoverage == 0,
    "an empty accumulator over real elapsed time is genuinely zero coverage"
  )
  try expect(
    summary.workoutEffortScore == nil && summary.workoutEffortSource == nil,
    "the recorder never infers an effort score; that is a user report"
  )
  try expect(
    summary.sourceVersion == "healthkit-live-workout-v1",
    "the summary must identify which recorder produced it"
  )

  // The whole point of the summary: the physiology contract must accept it.
  let outcome = PhysiologyContextService.build(
    contextID: PhysiologyContextID("workout-summary-context"),
    visitID: GymVisitID("workout-summary-visit"),
    subjective: nil,
    healthKitSummary: summary,
    recordedAt: Instant(millisecondsSince1970: 1)
  )
  try expect(
    outcome.isBuilt,
    "a summary the recorder produces must satisfy the physiology contract"
  )
}
