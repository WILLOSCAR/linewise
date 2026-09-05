import Foundation
import LineWiseDomain

/// Decisions the HealthKit workout recorder makes, extracted from behind its
/// platform gate.
///
/// `HealthKitWorkoutRecorder` sits inside `#if canImport(HealthKit) && os(watchOS)`
/// because `HKWorkoutSession.init(healthStore:configuration:)` and
/// `associatedWorkoutBuilder()` are marked unavailable in Mac Catalyst, and no
/// triple available on a Command Line Tools installation makes `os(watchOS)` true.
/// That gate is unavoidable for the calls into HealthKit's own types — but it was
/// also swallowing ordinary logic that has nothing to do with HealthKit, leaving it
/// reachable by no build and no specification.
///
/// What lives here is only the reasoning: how a sharing status becomes a product
/// state, and how collected readings become a `HealthKitWorkoutSummary`. The
/// recorder passes HealthKit's values in and uses what comes back, so this logic is
/// compiled and specified on every platform while the gate keeps only the parts
/// that genuinely require the framework.
public enum WorkoutCapability {
  /// Maps a HealthKit sharing authorization into the app's capability state.
  ///
  /// - Parameter isAuthorized: `nil` when the status is undetermined — the user has
  ///   not been asked yet. That is deliberately distinct from `false`, an explicit
  ///   refusal: collapsing the two would either nag someone who already declined or
  ///   silently skip asking someone who never saw the prompt.
  public static func state(
    healthDataAvailable: Bool,
    isAuthorized: Bool?
  ) -> OptionalCapabilityState {
    guard healthDataAvailable else { return .unavailable }
    guard let isAuthorized else { return .authorizationRequired }
    return isAuthorized ? .ready : .denied
  }
}

/// Builds the optional workout summary a completed recording contributes.
public enum WorkoutSummaryBuilder {
  public static let sourceVersion = "healthkit-live-workout-v1"

  /// Assembles the summary from the readings HealthKit actually produced.
  ///
  /// Absent readings stay absent: a missing average heart rate is unknown, never
  /// zero, because `PhysiologyContextService` treats a zero reading as invalid and
  /// because claiming a measurement that was not taken is the kind of quiet
  /// overstatement this product exists to avoid.
  public static func summary(
    startedAt: Date,
    endedAt: Date,
    coverageAccumulator: HeartRateCoverageAccumulator,
    averageHeartRateBPM: Double?,
    maximumHeartRateBPM: Double?,
    activeEnergyKilocalories: Double?
  ) -> HealthKitWorkoutSummary {
    // A clock adjustment mid-session can put the end before the start. Clamp rather
    // than emit a negative duration, which the physiology contract would reject and
    // which would discard the whole context.
    let elapsed = max(0, endedAt.timeIntervalSince(startedAt))
    // With no elapsed time there is no denominator, so coverage is unknown rather
    // than zero — reporting 0 would assert the sensor produced nothing.
    let coverage =
      elapsed > 0
      ? coverageAccumulator.coverage(overWorkoutDurationSeconds: elapsed)
      : nil
    return HealthKitWorkoutSummary(
      durationSeconds: elapsed,
      averageHeartRateBPM: averageHeartRateBPM,
      maximumHeartRateBPM: maximumHeartRateBPM,
      heartRateCoverage: coverage,
      activeEnergyKilocalories: activeEnergyKilocalories,
      // Effort is a user report, never inferred from sensors.
      workoutEffortScore: nil,
      workoutEffortSource: nil,
      sourceVersion: sourceVersion
    )
  }
}
