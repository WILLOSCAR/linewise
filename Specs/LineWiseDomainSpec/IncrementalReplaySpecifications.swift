import Foundation
import LineWiseDomain

// These specifications pin the safety contract for compacting replay work:
// an incremental, checkpointed replayer must produce EXACTLY the same projected
// VisitState as a naive full replay of every event, for any delivery order —
// including a late event whose business time sorts before an existing
// checkpoint. Compaction may reduce recomputation; it must never change history.
//
// They also pin the per-event OUTCOME contract. `insert` reports the outcome the
// fold recorded for that event, and `VisitRepository.submit`/`receive` hand that
// value straight back to the caller as the result of their action. A command the
// fold recorded as deferred, conflicting or rejected must therefore never be
// reported as accepted — that would tell the user their action was confirmed
// when it is actually unresolved and needs review.

func incrementalReplaySpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "incremental replay matches full replay when events append in order",
      incrementalReplayMatchesFullReplayOnAppend
    ),
    (
      "incremental replay matches full replay when a late event sorts before a checkpoint",
      incrementalReplayMatchesFullReplayOnLateEvent
    ),
    (
      "incremental replay matches full replay under a shuffled batch delivery",
      incrementalReplayMatchesFullReplayUnderShuffle
    ),
    (
      "incremental replay reports deferred conflicting and rejected outcomes to the caller",
      incrementalReplayReportsNonAcceptedOutcomes
    ),
    (
      "contested events converge on the same state and outcomes under shuffled delivery",
      incrementalReplayReportsNonAcceptedOutcomesUnderShuffle
    ),
    (
      "re-inserting an already-recorded event is a duplicate that changes nothing",
      incrementalReplayReportsDuplicateWithoutChangingHistory
    ),
    (
      "the checkpoint cache stays bounded by the interval as history grows",
      checkpointCacheStaysBoundedAsHistoryGrows
    ),
  ]
}

/// Compaction has to bound the cache, not just the fold. The point of a
/// checkpoint interval is that a long visit keeps a handful of cached
/// `VisitState` copies rather than one per event; a cache that grows 1:1 with
/// history costs more memory than the naive full replay it replaced, which
/// inverts the optimization instead of delivering it.
private func checkpointCacheStaysBoundedAsHistoryGrows() throws {
  let interval = 8
  let eventCount = 200
  var engine = IncrementalVisitReplay(checkpointInterval: interval)
  var envelopes: [DeviceEventEnvelope] = []

  for index in 0..<eventCount {
    let sequence = UInt64(index + 1)
    let entry = envelope(
      sequence,
      .createRouteCard(
        actionID: ActionID("bounded-action-\(index)"),
        routeCardID: RouteCardID("bounded-route-\(index)"),
        label: "Route \(index)",
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: Int64(index + 1) * 1_000),
        source: .watch
      )
    )
    envelopes.append(entry)
    engine.insert(entry)
  }

  // One cached checkpoint per interval, plus at most one partial tail.
  let allowed = eventCount / interval + 1
  try expect(
    engine.checkpointCount <= allowed,
    """
    a \(eventCount) event history at interval \(interval) must cache at most \
    \(allowed) checkpoints, not \(engine.checkpointCount) — each retains a full \
    VisitState copy, so a cache that grows per event defeats compaction
    """
  )

  // Bounding the cache must not change the projection it exists to accelerate.
  try expect(
    engine.state.snapshot == fullReplayState(of: envelopes).snapshot,
    "a bounded checkpoint cache must still project exactly the full replay"
  )
}

private func incrementalReplayMatchesFullReplayOnAppend() throws {
  let events = sampleEnvelopes()
  var replay = IncrementalVisitReplay(checkpointInterval: 2)
  try insertReportingFullReplayOutcomes(events, into: &replay)
  try expectStatesEqual(
    replay.state,
    fullReplayState(of: events),
    "in-order incremental replay must equal full replay"
  )
}

private func incrementalReplayMatchesFullReplayOnLateEvent() throws {
  // Deliver the tail first, then a late Attempt whose business time predates the
  // already-checkpointed events. It must re-sort into place and reproject.
  let all = sampleEnvelopes()
  let late = all[2]
  let withoutLate = all.enumerated().filter { $0.offset != 2 }.map(\.element)

  var replay = IncrementalVisitReplay(checkpointInterval: 2)
  try insertReportingFullReplayOutcomes(withoutLate, into: &replay)
  try insertReportingFullReplayOutcomes([late], into: &replay)

  try expectStatesEqual(
    replay.state,
    fullReplayState(of: all),
    "a late event that sorts before a checkpoint must still reproject correctly"
  )
}

private func incrementalReplayMatchesFullReplayUnderShuffle() throws {
  let all = sampleEnvelopes()
  // A fixed, non-trivial permutation (no RNG — deterministic for replayable specs).
  let order = [4, 1, 6, 0, 3, 5, 2]
  var replay = IncrementalVisitReplay(checkpointInterval: 3)
  try insertReportingFullReplayOutcomes(order.map { all[$0] }, into: &replay)
  try expectStatesEqual(
    replay.state,
    fullReplayState(of: all),
    "shuffled delivery must converge to the same projected state"
  )
}

private func incrementalReplayReportsNonAcceptedOutcomes() throws {
  let events = contestedEnvelopes()
  var replay = IncrementalVisitReplay(checkpointInterval: 2)
  try insertReportingFullReplayOutcomes(events, into: &replay)

  // The caller must be able to tell these four apart, because each one means
  // something different to the person who took the action.
  let outcomes = fullReplayOutcomes(of: events)
  try expect(
    outcomes[contestedLateSendActionID] == .deferred(.missingAttempt(contestedAttemptID)),
    "a result arriving before its Attempt must be reported as deferred, not accepted"
  )
  try expect(
    outcomes[contestedSecondVisitActionID] == .rejected(.anotherVisitIsOpen),
    "a second overlapping Visit must be reported as rejected, not accepted"
  )
  try expect(
    outcomes[contestedUndoActionID] == .conflict(.targetHasDependentActions),
    "an Undo with a dependent result must be reported as a conflict, not accepted"
  )
  try expect(
    outcomes[contestedRecordActionID] == .accepted,
    "the plain Record Attempt must still be reported as accepted"
  )

  try expectStatesEqual(
    replay.state,
    fullReplayState(of: events),
    "contested events must project identically to a full replay"
  )
}

private func incrementalReplayReportsNonAcceptedOutcomesUnderShuffle() throws {
  let all = contestedEnvelopes()
  let order = [5, 2, 0, 6, 3, 1, 4]
  var replay = IncrementalVisitReplay(checkpointInterval: 2)
  try insertReportingFullReplayOutcomes(order.map { all[$0] }, into: &replay)

  try expectStatesEqual(
    replay.state,
    fullReplayState(of: all),
    "shuffled contested delivery must converge to the same projected state"
  )
}

private func incrementalReplayReportsDuplicateWithoutChangingHistory() throws {
  let events = contestedEnvelopes()
  var replay = IncrementalVisitReplay(checkpointInterval: 2)
  try insertReportingFullReplayOutcomes(events, into: &replay)
  let settledState = replay.state
  let settledEvents = replay.events

  for event in events {
    let repeated = replay.insert(event)
    try expect(
      repeated == .duplicate,
      "re-delivering \(event.eventID.rawValue) must be reported as a duplicate"
    )
    try expect(
      replay.events.count == settledEvents.count,
      "a duplicate must not append another copy of \(event.eventID.rawValue)"
    )
    try expectStatesEqual(
      replay.state,
      settledState,
      "a duplicate must not change the projected state"
    )
  }
}

// MARK: - Independent source of truth

private func fullReplayState(of envelopes: [DeviceEventEnvelope]) -> VisitState {
  var state = VisitState()
  for envelope in envelopes.sorted(by: DeviceEventEnvelope.replayOrder) {
    state = VisitMemory.apply(envelope.command, to: state).state
  }
  return state
}

/// The outcome a naive full replay records for each event, keyed by event ID.
private func fullReplayOutcomes(
  of envelopes: [DeviceEventEnvelope]
) -> [ActionID: CommandOutcome] {
  var state = VisitState()
  var outcomes: [ActionID: CommandOutcome] = [:]
  for envelope in envelopes.sorted(by: DeviceEventEnvelope.replayOrder) {
    let transition = VisitMemory.apply(envelope.command, to: state)
    state = transition.state
    outcomes[envelope.eventID] = transition.outcome
  }
  return outcomes
}

/// Inserts each event and checks the reported outcome against a full replay of
/// everything delivered so far — the value `VisitRepository` hands to the user.
private func insertReportingFullReplayOutcomes(
  _ envelopes: [DeviceEventEnvelope],
  into replay: inout IncrementalVisitReplay
) throws {
  var delivered = replay.events
  for envelope in envelopes {
    let reported = replay.insert(envelope)
    delivered.append(envelope)
    let expected = fullReplayOutcomes(of: delivered)[envelope.eventID]
    try expect(
      reported == expected,
      "insert must report the fold's outcome for \(envelope.eventID.rawValue): "
        + "reported \(reported), full replay recorded \(String(describing: expected))"
    )
  }
}

private func expectStatesEqual(
  _ actual: VisitState,
  _ expected: VisitState,
  _ message: String
) throws {
  try expect(actual == expected, message)
  try expect(actual.snapshot == expected.snapshot, "\(message) (snapshot)")
}

private func envelope(_ sequence: UInt64, _ command: VisitCommand) -> DeviceEventEnvelope {
  DeviceEventEnvelope(originDeviceID: DeviceID("iphone"), sequence: sequence, command: command)
}

private func sampleEnvelopes() -> [DeviceEventEnvelope] {
  let route = RouteCardID("route-inc")
  let visit = GymVisitID("visit-inc")
  let attempt = AttemptID("attempt-inc")
  return [
    envelope(
      1,
      .createRouteCard(
        actionID: ActionID("a-create"),
        routeCardID: route,
        label: "Green overhang",
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      )),
    envelope(
      2,
      .startVisit(
        actionID: ActionID("a-visit"),
        visitID: visit,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .iPhone
      )),
    envelope(
      3,
      .recordAttempt(
        actionID: ActionID("a-attempt"),
        attemptID: attempt,
        visitID: visit,
        routeCardID: route,
        occurredAt: Instant(millisecondsSince1970: 3_000),
        source: .watch
      )),
    envelope(
      4,
      .markSend(
        actionID: ActionID("a-send"),
        attemptID: attempt,
        occurredAt: Instant(millisecondsSince1970: 3_500),
        source: .watch
      )),
    envelope(
      5,
      .endVisit(
        actionID: ActionID("a-end"),
        visitID: visit,
        occurredAt: Instant(millisecondsSince1970: 4_000),
        source: .iPhone
      )),
    envelope(
      6,
      .beginReview(
        actionID: ActionID("a-begin-review"),
        visitID: visit,
        occurredAt: Instant(millisecondsSince1970: 5_000),
        source: .iPhone
      )),
    envelope(
      7,
      .completeReview(
        actionID: ActionID("a-complete-review"),
        visitID: visit,
        occurredAt: Instant(millisecondsSince1970: 6_000),
        source: .iPhone
      )),
  ]
}

private let contestedAttemptID = AttemptID("attempt-contested")
private let contestedRecordActionID = ActionID("a-contested-record")
private let contestedLateSendActionID = ActionID("a-contested-send")
private let contestedSecondVisitActionID = ActionID("a-contested-second-visit")
private let contestedUndoActionID = ActionID("a-contested-undo")

/// A history that is deliberately NOT happy-path: it contains a result whose
/// Attempt has a later business time, an overlapping second Visit, and an Undo
/// whose target already carries a dependent result. Folding it records one
/// deferred, one rejected and one conflicting outcome alongside the accepted
/// ones.
private func contestedEnvelopes() -> [DeviceEventEnvelope] {
  let route = RouteCardID("route-contested")
  let visit = GymVisitID("visit-contested")
  return [
    envelope(
      1,
      .createRouteCard(
        actionID: ActionID("a-contested-create"),
        routeCardID: route,
        label: "Grey compression",
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      )),
    envelope(
      2,
      .startVisit(
        actionID: ActionID("a-contested-visit"),
        visitID: visit,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .iPhone
      )),
    // Sorts before its own Attempt, so the fold must defer it.
    envelope(
      3,
      .markSend(
        actionID: contestedLateSendActionID,
        attemptID: contestedAttemptID,
        occurredAt: Instant(millisecondsSince1970: 2_500),
        source: .watch
      )),
    envelope(
      4,
      .recordAttempt(
        actionID: contestedRecordActionID,
        attemptID: contestedAttemptID,
        visitID: visit,
        routeCardID: route,
        occurredAt: Instant(millisecondsSince1970: 3_000),
        source: .watch
      )),
    // A second Visit while the first is still open.
    envelope(
      5,
      .startVisit(
        actionID: contestedSecondVisitActionID,
        visitID: GymVisitID("visit-contested-overlap"),
        occurredAt: Instant(millisecondsSince1970: 3_500),
        source: .watch
      )),
    // Undoing the Attempt would orphan the Send that now depends on it.
    envelope(
      6,
      .undo(
        actionID: contestedUndoActionID,
        targetActionID: contestedRecordActionID,
        occurredAt: Instant(millisecondsSince1970: 4_000),
        source: .iPhone
      )),
    envelope(
      7,
      .endVisit(
        actionID: ActionID("a-contested-end"),
        visitID: visit,
        occurredAt: Instant(millisecondsSince1970: 5_000),
        source: .iPhone
      )),
  ]
}
