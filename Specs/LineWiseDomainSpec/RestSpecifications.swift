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
    (
      "a rest left running in an ended visit does not block the next visit",
      {
        // The user starts a rest, then ends the visit without stopping it — the
        // ordinary way a session finishes. Nothing reconciles the two, so the
        // rest stays active forever. At the next visit the rest timer is refused
        // outright, and `elapsedMilliseconds` keeps ticking across the gap, so the
        // Watch renders an unbounded rest time from days ago.
        let firstVisitID = GymVisitID("visit-rest-orphan-first")
        let secondVisitID = GymVisitID("visit-rest-orphan-second")
        var visitState = VisitState()
        for command in [
          VisitCommand.startVisit(
            actionID: ActionID("action-start-rest-orphan-first"),
            visitID: firstVisitID,
            occurredAt: Instant(millisecondsSince1970: 1_000),
            source: .watch
          ),
          .endVisit(
            actionID: ActionID("action-end-rest-orphan-first"),
            visitID: firstVisitID,
            occurredAt: Instant(millisecondsSince1970: 3_000),
            source: .watch
          ),
        ] {
          visitState = try acceptedState(VisitMemory.apply(command, to: visitState))
        }
        // Start the rest while the first visit is still open, then end that visit.
        var openState = VisitState()
        openState = try acceptedState(
          VisitMemory.apply(
            .startVisit(
              actionID: ActionID("action-start-rest-orphan-open"),
              visitID: firstVisitID,
              occurredAt: Instant(millisecondsSince1970: 1_000),
              source: .watch
            ),
            to: openState
          )
        )
        let orphaned = RestMemory.apply(
          .start(
            actionID: ActionID("action-start-rest-orphan"),
            restID: RestIntervalID("rest-orphan"),
            visitID: firstVisitID,
            afterAttemptID: nil,
            occurredAt: Instant(millisecondsSince1970: 2_000)
          ),
          visitSnapshot: openState.snapshot,
          to: RestState()
        )
        try expect(orphaned.outcome == .accepted, "expected the rest to start in an open visit")

        // Now the next session begins; the first visit is ended in this snapshot.
        visitState = try acceptedState(
          VisitMemory.apply(
            .startVisit(
              actionID: ActionID("action-start-rest-orphan-second"),
              visitID: secondVisitID,
              occurredAt: Instant(millisecondsSince1970: 10_000),
              source: .watch
            ),
            to: visitState
          )
        )
        let nextVisitRest = RestMemory.apply(
          .start(
            actionID: ActionID("action-start-rest-orphan-next"),
            restID: RestIntervalID("rest-orphan-next"),
            visitID: secondVisitID,
            afterAttemptID: nil,
            occurredAt: Instant(millisecondsSince1970: 11_000)
          ),
          visitSnapshot: visitState.snapshot,
          to: orphaned.state
        )
        try expect(
          nextVisitRest.outcome == .accepted,
          """
          a rest abandoned in an ended visit blocked the new visit's rest timer \
          (\(nextVisitRest.outcome)); a stale interval from a finished session must \
          not disable rest tracking for every session afterwards
          """
        )
        try expect(
          nextVisitRest.state.snapshot.activeRest?.id == RestIntervalID("rest-orphan-next"),
          "the active rest must be the one in the visit the user is actually in"
        )
      }
    ),
  ]
}
