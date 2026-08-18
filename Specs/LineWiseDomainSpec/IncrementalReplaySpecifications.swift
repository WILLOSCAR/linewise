import Foundation
import LineWiseDomain

// These specifications pin the safety contract for compacting replay work:
// an incremental, checkpointed replayer must produce EXACTLY the same projected
// VisitState as a naive full replay of every event, for any delivery order —
// including a late event whose business time sorts before an existing
// checkpoint. Compaction may reduce recomputation; it must never change history.

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
  ]
}

private func incrementalReplayMatchesFullReplayOnAppend() throws {
  let events = sampleEnvelopes()
  var replay = IncrementalVisitReplay(checkpointInterval: 2)
  for event in events {
    replay.insert(event)
  }
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
  for event in withoutLate {
    replay.insert(event)
  }
  replay.insert(late)

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
  for index in order {
    replay.insert(all[index])
  }
  try expectStatesEqual(
    replay.state,
    fullReplayState(of: all),
    "shuffled delivery must converge to the same projected state"
  )
}

// MARK: - Independent source of truth

private func fullReplayState(of envelopes: [DeviceEventEnvelope]) -> VisitState {
  var state = VisitState()
  for envelope in envelopes.sorted(by: DeviceEventEnvelope.replayOrder) {
    state = VisitMemory.apply(envelope.command, to: state).state
  }
  return state
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
