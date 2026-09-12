import Foundation

/// Accumulates the timing of collected heart-rate samples into a coverage
/// fraction for `HealthKitWorkoutSummary.heartRateCoverage`.
///
/// Coverage answers "for how much of this workout did the Watch actually
/// produce heart-rate data?" as a value in `0...1`. It is context only and
/// explicitly non-diagnostic: low coverage means an incomplete sensor stream,
/// never a health judgment.
///
/// A point sample attests to heart-rate data at one instant, so it is credited
/// with a bounded window around that instant rather than with everything up to
/// the next sample — otherwise two readings an hour apart would claim the whole
/// hour. Explicit windows (e.g. from a statistics query) contribute their own
/// intervals. Overlapping or touching intervals are unioned so overlapping data
/// is never double counted, the union is clipped to the workout window, and the
/// covered total is clamped to the workout duration.
public struct HeartRateCoverageAccumulator: Sendable {
  /// How long a single point sample is credited on each side of its timestamp.
  ///
  /// watchOS delivers workout heart-rate updates every few seconds, so a stream
  /// arriving at that cadence unions into one continuous covered interval, while
  /// a dropout longer than the credited window shows up as missing time.
  private static let pointSampleCreditSeconds: Double = 3

  private struct Interval: Sendable {
    var start: Double
    var end: Double
  }

  private var intervals: [Interval] = []
  private var bpmSum: Double = 0
  private var bpmCount: Int = 0
  private var maximumObservedBPM: Double?

  public init() {}

  /// Records a single heart-rate sample at `seconds` into the workout.
  public mutating func observeSample(at seconds: Double, bpm: Double) {
    intervals.append(
      Interval(
        start: seconds - Self.pointSampleCreditSeconds,
        end: seconds + Self.pointSampleCreditSeconds
      )
    )
    recordBPM(bpm)
  }

  /// Records a contiguous window over which heart-rate data was collected.
  ///
  /// A sensor may report the window for a single reading as a single instant. An
  /// instant is still data the Watch produced, so a collapsed window is credited
  /// exactly like a point sample rather than being discarded as no data.
  public mutating func observeWindow(startSeconds: Double, endSeconds: Double, bpm: Double) {
    let lower = min(startSeconds, endSeconds)
    let upper = max(startSeconds, endSeconds)
    guard upper > lower else {
      observeSample(at: lower, bpm: bpm)
      return
    }
    intervals.append(Interval(start: lower, end: upper))
    recordBPM(bpm)
  }

  public var averageBPM: Double? {
    bpmCount > 0 ? bpmSum / Double(bpmCount) : nil
  }

  public var maximumBPM: Double? {
    maximumObservedBPM
  }

  /// The fraction of `durationSeconds` for which heart-rate data was actually
  /// collected, clamped to `0...1`. Returns 0 for a non-positive duration or no
  /// data.
  public func coverage(overWorkoutDurationSeconds durationSeconds: Double) -> Double {
    guard durationSeconds > 0 else { return 0 }

    let clipped = intervals.compactMap { interval -> Interval? in
      let start = max(interval.start, 0)
      let end = min(interval.end, durationSeconds)
      return end > start ? Interval(start: start, end: end) : nil
    }
    guard !clipped.isEmpty else { return 0 }

    let coveredSeconds = unionLength(of: clipped)
    return min(1, max(0, coveredSeconds / durationSeconds))
  }

  private mutating func recordBPM(_ bpm: Double) {
    // A sensor can hand back a value that is not a number. It still attests that
    // the sensor reported (so the interval already counted toward coverage), but
    // it cannot enter an average or a maximum: one such value would otherwise
    // make both permanently unreportable, and the archive is JSON, which cannot
    // encode a non-finite Double at all.
    guard bpm.isFinite else { return }
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
