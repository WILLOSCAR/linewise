import Foundation

/// Compacts the *work* of replaying a visit event log without altering history.
///
/// A naive `VisitRepository` re-folds every event through `VisitMemory.apply`
/// on each mutation, so replay cost grows linearly with total history. This
/// type keeps the same deterministic `replayOrder` fold but caches periodic
/// checkpoints of settled prefixes, so an appended event only re-folds the
/// tail after the latest checkpoint.
///
/// Safety contract: `state` is ALWAYS identical to a full replay of every
/// contained event in `replayOrder`. A late event whose business time sorts
/// before an existing checkpoint invalidates every checkpoint at or after its
/// insertion point and re-folds from an earlier one — so out-of-order and
/// late delivery still reproject earlier state. Compaction never truncates the
/// event log; it only bounds recomputation.
public struct IncrementalVisitReplay: Sendable {
  private struct Checkpoint: Sendable {
    /// Number of leading events (in sorted order) folded into `state`.
    let eventCount: Int
    let state: VisitState
  }

  private var sortedEvents: [DeviceEventEnvelope]
  private var checkpoints: [Checkpoint]
  /// The fold of every event in `sortedEvents`, kept separately from the
  /// checkpoint cache so the cache never has to hold a tail entry per insert.
  private var currentState: VisitState
  private let checkpointInterval: Int

  /// - Parameter checkpointInterval: how many additional sorted events to fold
  ///   between cached checkpoints. Must be >= 1; larger values cache less and
  ///   recompute more. This only affects performance, never the result.
  public init(checkpointInterval: Int = 64) {
    precondition(checkpointInterval >= 1, "checkpoint interval must be positive")
    sortedEvents = []
    checkpoints = []
    currentState = VisitState()
    self.checkpointInterval = checkpointInterval
  }

  public init(
    events: [DeviceEventEnvelope],
    checkpointInterval: Int = 64
  ) {
    self.init(checkpointInterval: checkpointInterval)
    for event in events {
      insert(event)
    }
  }

  /// The projected state of every inserted event, folded in `replayOrder`.
  public var state: VisitState {
    currentState
  }

  public var events: [DeviceEventEnvelope] {
    sortedEvents
  }

  /// How many checkpoints are currently cached.
  ///
  /// Exposed so the compaction contract itself is testable: the cache must stay
  /// bounded by `checkpointInterval` as history grows, because each entry
  /// retains a full `VisitState` copy. Without this, a cache that grows once per
  /// event is indistinguishable from a correct one — every projection still
  /// matches a full replay while the memory cost quietly exceeds the naive
  /// replay this type replaced.
  public var checkpointCount: Int {
    checkpoints.count
  }

  /// Inserts one event into its `replayOrder` position and reprojects only the
  /// suffix that follows the latest still-valid checkpoint. Returns the outcome
  /// recorded for this event during the fold — identical to what a full replay
  /// would record for it. Re-inserting an event with an existing `eventID` is a
  /// no-op that reports `.duplicate` (mirroring the inbox's idempotency).
  @discardableResult
  public mutating func insert(_ envelope: DeviceEventEnvelope) -> CommandOutcome {
    if sortedEvents.contains(where: { $0.eventID == envelope.eventID }) {
      return .duplicate
    }
    let index = insertionIndex(for: envelope)
    sortedEvents.insert(envelope, at: index)

    // Every checkpoint that folded `index` or more events is now stale, because
    // a new event landed at or before its boundary.
    checkpoints.removeAll { $0.eventCount > index }

    return rebuildCheckpoints(from: checkpoints.last, capturing: envelope.eventID)
  }

  private func insertionIndex(for envelope: DeviceEventEnvelope) -> Int {
    var low = 0
    var high = sortedEvents.count
    while low < high {
      let mid = (low + high) / 2
      if DeviceEventEnvelope.replayOrder(sortedEvents[mid], envelope) {
        low = mid + 1
      } else {
        high = mid
      }
    }
    return low
  }

  @discardableResult
  private mutating func rebuildCheckpoints(
    from checkpoint: Checkpoint?,
    capturing eventID: ActionID? = nil
  ) -> CommandOutcome {
    var state = checkpoint?.state ?? VisitState()
    var index = checkpoint?.eventCount ?? 0
    var capturedOutcome: CommandOutcome = .accepted

    while index < sortedEvents.count {
      let envelope = sortedEvents[index]
      let transition = VisitMemory.apply(envelope.command, to: state)
      state = transition.state
      if let eventID, envelope.eventID == eventID {
        capturedOutcome = transition.outcome
      }
      index += 1
      // Only interval boundaries are cached. The tail is held in
      // `currentState`, so appending never grows the cache — with a tail
      // checkpoint per insert the cache would grow 1:1 with history and each
      // entry retains a full VisitState copy.
      if index % checkpointInterval == 0 {
        checkpoints.append(Checkpoint(eventCount: index, state: state))
      }
    }

    currentState = state
    if sortedEvents.isEmpty {
      checkpoints = []
    }
    return capturedOutcome
  }
}
