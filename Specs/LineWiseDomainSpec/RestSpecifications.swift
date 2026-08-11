import LineWiseDomain

func restSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "rest starts after an Attempt and stops with a stable duration",
      {
        let visitID = GymVisitID("visit-rest")
        let attemptID = AttemptID("attempt-rest")
        let restID = RestIntervalID("rest-1")
        var visitState = VisitState()
        visitState = try acceptedState(
          VisitMemory.apply(
            .startVisit(
              actionID: ActionID("action-start-visit-rest"),
              visitID: visitID,
              occurredAt: Instant(millisecondsSince1970: 1_000),
              source: .watch
            ),
            to: visitState
          )
        )
        visitState = try acceptedState(
          VisitMemory.apply(
            .recordAttempt(
              actionID: ActionID("action-record-attempt-rest"),
              attemptID: attemptID,
              visitID: visitID,
              routeCardID: nil,
              occurredAt: Instant(millisecondsSince1970: 2_000),
              source: .watch
            ),
            to: visitState
          )
        )

        var restState = RestState()
        let started = RestMemory.apply(
          .start(
            actionID: ActionID("action-start-rest"),
            restID: restID,
            visitID: visitID,
            afterAttemptID: attemptID,
            occurredAt: Instant(millisecondsSince1970: 2_100)
          ),
          visitSnapshot: visitState.snapshot,
          to: restState
        )
        try expect(started.outcome == .accepted, "expected RestInterval to start")
        restState = started.state
        try expect(
          restState.snapshot.activeRest?.elapsedMilliseconds(
            at: Instant(millisecondsSince1970: 3_100)
          ) == 1_000,
          "expected elapsed rest to derive from monotonic business time"
        )

        let stopped = RestMemory.apply(
          .stop(
            actionID: ActionID("action-stop-rest"),
            restID: restID,
            occurredAt: Instant(millisecondsSince1970: 5_100)
          ),
          visitSnapshot: visitState.snapshot,
          to: restState
        )
        try expect(stopped.outcome == .accepted, "expected RestInterval to stop")
        try expect(stopped.state.snapshot.activeRest == nil, "expected no active rest")
        try expect(
          stopped.state.snapshot.intervals.first?.durationMilliseconds == 3_000,
          "expected stable completed duration"
        )
      }
    ),
    (
      "a second active rest in the same visit is rejected",
      {
        let visitID = GymVisitID("visit-rest-overlap")
        var visitState = VisitState()
        visitState = try acceptedState(
          VisitMemory.apply(
            .startVisit(
              actionID: ActionID("action-start-visit-rest-overlap"),
              visitID: visitID,
              occurredAt: Instant(millisecondsSince1970: 1_000),
              source: .watch
            ),
            to: visitState
          )
        )
        let restState = RestMemory.apply(
          .start(
            actionID: ActionID("action-start-rest-overlap-1"),
            restID: RestIntervalID("rest-overlap-1"),
            visitID: visitID,
            afterAttemptID: nil,
            occurredAt: Instant(millisecondsSince1970: 2_000)
          ),
          visitSnapshot: visitState.snapshot,
          to: RestState()
        ).state
        let rejected = RestMemory.apply(
          .start(
            actionID: ActionID("action-start-rest-overlap-2"),
            restID: RestIntervalID("rest-overlap-2"),
            visitID: visitID,
            afterAttemptID: nil,
            occurredAt: Instant(millisecondsSince1970: 2_100)
          ),
          visitSnapshot: visitState.snapshot,
          to: restState
        )
        try expect(
          rejected.outcome == .rejected(.restAlreadyActive),
          "expected overlapping rest to be explicit"
        )
        try expect(rejected.state == restState, "expected rejection to preserve current rest")
      }
    ),
  ]
}
