import Foundation

/// Accumulates the timing of collected heart-rate samples into a coverage
/// fraction for `HealthKitWorkoutSummary.heartRateCoverage`.
///
/// Coverage answers "for how much of this workout did the Watch actually
/// produce heart-rate data?" as a value in `0...1`. It is context only and
/// explicitly non-diagnostic: low coverage means an incomplete sensor stream,
/// never a health judgment.
///
/// Point samples define a covered span between the earliest and latest sample;
/// explicit windows (e.g. from a statistics query) contribute their own
/// intervals. Overlapping or touching intervals are unioned so overlapping
/// data is never double counted, and the covered total is clamped to the
/// workout duration.
public struct HeartRateCoverageAccumulator: Sendable {
  private struct Interval: Sendable {
    var start: Double
    var end: Double
  }

  private var intervals: [Interval] = []
  private var earliestSampleSeconds: Double?
  private var latestSampleSeconds: Double?
  private var bpmSum: Double = 0
  private var bpmCount: Int = 0
  private var maximumObservedBPM: Double?

  public init() {}

  /// Records a single heart-rate sample at `seconds` into the workout.
  public mutating func observeSample(at seconds: Double, bpm: Double) {
    earliestSampleSeconds = earliestSampleSeconds.map { min($0, seconds) } ?? seconds
    latestSampleSeconds = latestSampleSeconds.map { max($0, seconds) } ?? seconds
    recordBPM(bpm)
  }

  /// Records a contiguous window over which heart-rate data was collected.
  public mutating func observeWindow(startSeconds: Double, endSeconds: Double, bpm: Double) {
    let lower = min(startSeconds, endSeconds)
    let upper = max(startSeconds, endSeconds)
    intervals.append(Interval(start: lower, end: upper))
    recordBPM(bpm)
  }

  public var averageBPM: Double? {
    bpmCount > 0 ? bpmSum / Double(bpmCount) : nil
  }

  public var maximumBPM: Double? {
    maximumObservedBPM
  }

  /// The fraction of `durationSeconds` spanned by collected heart-rate data,
  /// clamped to `0...1`. Returns 0 for a non-positive duration or no data.
  public func coverage(overWorkoutDurationSeconds durationSeconds: Double) -> Double {
    guard durationSeconds > 0 else { return 0 }

    var merged = intervals
    if let earliest = earliestSampleSeconds, let latest = latestSampleSeconds {
      merged.append(Interval(start: earliest, end: latest))
    }
    guard !merged.isEmpty else { return 0 }

    let coveredSeconds = unionLength(of: merged)
    return min(1, max(0, coveredSeconds / durationSeconds))
  }

  private mutating func recordBPM(_ bpm: Double) {
    bpmSum += bpm
    bpmCount += 1
    maximumObservedBPM = maximumObservedBPM.map { max($0, bpm) } ?? bpm
  }

  private func unionLength(of intervals: [Interval]) -> Double {
    let sorted = intervals.sorted { $0.start < $1.start }
    var total: Double = 0
    var currentStart = sorted[0].start
    var currentEnd = sorted[0].end

    for interval in sorted.dropFirst() {
      if interval.start <= currentEnd {
        currentEnd = max(currentEnd, interval.end)
      } else {
        total += currentEnd - currentStart
        currentStart = interval.start
        currentEnd = interval.end
      }
    }
    total += currentEnd - currentStart
    return total
  }
}
