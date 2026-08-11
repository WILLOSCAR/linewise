import LineWiseDomain

enum SpecFailure: Error, CustomStringConvertible {
  case expected(String)

  var description: String {
    switch self {
    case .expected(let message): message
    }
  }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else {
    throw SpecFailure.expected(message)
  }
}

func acceptedState(_ transition: VisitTransition) throws -> VisitState {
  try expect(transition.outcome == .accepted, "expected command to be accepted")
  return transition.state
}

func oneRecordAttemptCommandCreatesOneUnresolvedAttempt() throws {
  let visitID = GymVisitID("visit-1")
  let routeID = RouteCardID("route-blue-slab")
  let attemptID = AttemptID("attempt-1")

  var state = VisitState()
  state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      ),
      to: state
    )
  )

  let transition = VisitMemory.apply(
    .recordAttempt(
      actionID: ActionID("action-attempt-1"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    to: state
  )

  try expect(transition.outcome == .accepted, "expected Record Attempt to be accepted")
  try expect(
    transition.state.snapshot.attempts == [
      AttemptSnapshot(
        id: attemptID,
        visitID: visitID,
        routeCardID: routeID,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        recordedBy: .watch,
        recordState: .active,
        outcome: .unresolved
      )
    ],
    "expected exactly one active unresolved Attempt"
  )
}

func retryingTheSameActionIsAnIdempotentDuplicate() throws {
  let visitID = GymVisitID("visit-duplicate")
  let attemptID = AttemptID("attempt-duplicate")
  let command = VisitCommand.recordAttempt(
    actionID: ActionID("action-duplicate"),
    attemptID: attemptID,
    visitID: visitID,
    routeCardID: nil,
    occurredAt: Instant(millisecondsSince1970: 2_000),
    source: .watch
  )

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-duplicate"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(VisitMemory.apply(command, to: state))

  let duplicate = VisitMemory.apply(command, to: state)

  try expect(duplicate.outcome == .duplicate, "expected retry to be reported as duplicate")
  try expect(duplicate.state == state, "expected duplicate retry to leave state unchanged")
  try expect(
    duplicate.state.snapshot.attempts.count == 1, "expected one Attempt after duplicate retry")
}

func reusingAnActionIDForDifferentMeaningIsAConflict() throws {
  let visitID = GymVisitID("visit-conflict")
  let sharedActionID = ActionID("action-reused")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-conflict"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: sharedActionID,
        attemptID: AttemptID("attempt-original"),
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: state
    )
  )

  let conflict = VisitMemory.apply(
    .recordAttempt(
      actionID: sharedActionID,
      attemptID: AttemptID("attempt-different"),
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    to: state
  )

  try expect(
    conflict.outcome == .conflict(.actionIDReused), "expected reused action ID to conflict")
  try expect(conflict.state == state, "expected conflicting command to leave state unchanged")
  try expect(
    conflict.state.snapshot.attempts.count == 1,
    "expected conflicting command not to add an Attempt")
}

func markSendChangesTheExistingAttemptWithoutIncreasingCount() throws {
  let visitID = GymVisitID("visit-send")
  let attemptID = AttemptID("attempt-send")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-send"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("action-record-send"),
        attemptID: attemptID,
        visitID: visitID,
        routeCardID: RouteCardID("route-send"),
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: state
    )
  )

  let sent = VisitMemory.apply(
    .markSend(
      actionID: ActionID("action-mark-send"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 2_100),
      source: .watch
    ),
    to: state
  )

  try expect(sent.outcome == .accepted, "expected Mark Send to be accepted")
  try expect(sent.state.snapshot.attempts.count == 1, "expected Mark Send not to add an Attempt")
  try expect(
    sent.state.snapshot.attempts.first?.outcome == .sent, "expected existing Attempt to become sent"
  )
}

func undoTargetsTheNamedMarkSendEvenAfterANewerAttempt() throws {
  let visitID = GymVisitID("visit-undo-send")
  let firstAttemptID = AttemptID("attempt-undo-send")
  let laterAttemptID = AttemptID("attempt-later")
  let markSendActionID = ActionID("action-send-to-undo")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-undo-send"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("action-first-attempt"),
        attemptID: firstAttemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: state
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .markSend(
        actionID: markSendActionID,
        attemptID: firstAttemptID,
        occurredAt: Instant(millisecondsSince1970: 2_100),
        source: .watch
      ),
      to: state
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("action-later-attempt"),
        attemptID: laterAttemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 3_000),
        source: .watch
      ),
      to: state
    )
  )

  let undone = VisitMemory.apply(
    .undo(
      actionID: ActionID("action-undo-send"),
      targetActionID: markSendActionID,
      occurredAt: Instant(millisecondsSince1970: 3_100),
      source: .watch
    ),
    to: state
  )

  let attempts = Dictionary(
    uniqueKeysWithValues: undone.state.snapshot.attempts.map { ($0.id, $0) })
  try expect(undone.outcome == .accepted, "expected exact-target Undo to be accepted")
  try expect(
    attempts[firstAttemptID]?.outcome == .unresolved,
    "expected targeted Send to return to unresolved")
  try expect(
    attempts[laterAttemptID]?.recordState == .active, "expected newer Attempt to remain active")
}

func undoingRecordAttemptRetractsItAndExcludesItFromActiveCounts() throws {
  let visitID = GymVisitID("visit-undo-attempt")
  let recordActionID = ActionID("action-record-to-undo")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-undo-attempt"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: recordActionID,
        attemptID: AttemptID("attempt-to-retract"),
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: state
    )
  )

  let undone = VisitMemory.apply(
    .undo(
      actionID: ActionID("action-undo-attempt"),
      targetActionID: recordActionID,
      occurredAt: Instant(millisecondsSince1970: 2_100),
      source: .watch
    ),
    to: state
  )

  try expect(undone.outcome == .accepted, "expected Undo Record Attempt to be accepted")
  try expect(
    undone.state.snapshot.attempts.first?.recordState == .retracted,
    "expected Attempt history to show retraction")
  try expect(
    undone.state.snapshot.activeAttempts.isEmpty,
    "expected retracted Attempt to be excluded from active counts")
}

func endingAVisitLeavesAttemptOutcomeUnresolved() throws {
  let visitID = GymVisitID("visit-end-unresolved")
  let attemptID = AttemptID("attempt-end-unresolved")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-end-unresolved"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("action-record-end-unresolved"),
        attemptID: attemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: state
    )
  )

  let ended = VisitMemory.apply(
    .endVisit(
      actionID: ActionID("action-end-unresolved"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(ended.outcome == .accepted, "expected End Visit to be accepted")
  try expect(
    ended.state.snapshot.visits.first?.captureState == .ended,
    "expected visit capture state to be ended")
  try expect(
    ended.state.snapshot.visits.first?.reviewState == .pendingReview,
    "expected ended visit to enter pending review")
  try expect(
    ended.state.snapshot.attempts.first?.outcome == .unresolved,
    "expected End Visit not to invent not-sent")
}

func confirmNotSentIsExplicitAndDoesNotCreateAnotherAttempt() throws {
  let visitID = GymVisitID("visit-not-sent")
  let attemptID = AttemptID("attempt-not-sent")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-not-sent"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("action-record-not-sent"),
        attemptID: attemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: state
    )
  )

  let confirmed = VisitMemory.apply(
    .confirmNotSent(
      actionID: ActionID("action-confirm-not-sent"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(confirmed.outcome == .accepted, "expected explicit Confirm Not Sent to be accepted")
  try expect(
    confirmed.state.snapshot.attempts.count == 1,
    "expected result confirmation not to add an Attempt")
  try expect(
    confirmed.state.snapshot.attempts.first?.outcome == .notSent,
    "expected Attempt to become explicitly not sent")
}

func outOfOrderMarkSendWaitsForItsExactAttempt() throws {
  let visitID = GymVisitID("visit-out-of-order-send")
  let attemptID = AttemptID("attempt-out-of-order-send")
  let markSend = VisitCommand.markSend(
    actionID: ActionID("action-out-of-order-send"),
    attemptID: attemptID,
    occurredAt: Instant(millisecondsSince1970: 2_100),
    source: .watch
  )

  let started = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-out-of-order-send"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )

  let deferred = VisitMemory.apply(markSend, to: started)
  try expect(
    deferred.outcome == .deferred(.missingAttempt(attemptID)),
    "expected Mark Send to wait for its exact missing Attempt"
  )
  try expect(
    deferred.state.snapshot.attempts.isEmpty, "expected deferred Send not to invent an Attempt")

  let arrived = VisitMemory.apply(
    .recordAttempt(
      actionID: ActionID("action-record-out-of-order-send"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    to: deferred.state
  )

  try expect(arrived.outcome == .accepted, "expected arriving Attempt to be accepted")
  try expect(
    arrived.state.snapshot.attempts.count == 1,
    "expected exactly one Attempt after dependency arrives")
  try expect(
    arrived.state.snapshot.attempts.first?.outcome == .sent,
    "expected pending Send to apply to its target")
}

func outOfOrderUndoWaitsForItsExactTarget() throws {
  let visitID = GymVisitID("visit-out-of-order-undo")
  let targetActionID = ActionID("action-target-arrives-late")
  let undoActionID = ActionID("action-undo-arrives-first")

  let started = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-out-of-order-undo"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )

  let deferred = VisitMemory.apply(
    .undo(
      actionID: undoActionID,
      targetActionID: targetActionID,
      occurredAt: Instant(millisecondsSince1970: 2_100),
      source: .watch
    ),
    to: started
  )

  try expect(
    deferred.outcome == .deferred(.missingAction(targetActionID)),
    "expected Undo to wait for named action")
  try expect(
    deferred.state.snapshot.pendingActionIDs == [undoActionID],
    "expected pending Undo to remain visible")

  let targetArrived = VisitMemory.apply(
    .recordAttempt(
      actionID: targetActionID,
      attemptID: AttemptID("attempt-retracted-after-delay"),
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    to: deferred.state
  )

  try expect(
    targetArrived.state.snapshot.pendingActionIDs.isEmpty, "expected pending Undo to resolve")
  try expect(
    targetArrived.state.snapshot.attempts.first?.recordState == .retracted,
    "expected only the named late action to be undone")
  try expect(
    targetArrived.state.snapshot.activeAttempts.isEmpty,
    "expected retracted late Attempt not to count")
}

func lateAttemptAfterCompletedReviewIsPreservedAndNeedsRecheck() throws {
  let visitID = GymVisitID("visit-late-after-review")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-late-review"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .endVisit(
        actionID: ActionID("action-end-late-review"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 4_000),
        source: .watch
      ),
      to: state
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .beginReview(
        actionID: ActionID("action-begin-review"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 5_000),
        source: .iPhone
      ),
      to: state
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .completeReview(
        actionID: ActionID("action-complete-review"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 6_000),
        source: .iPhone
      ),
      to: state
    )
  )

  let late = VisitMemory.apply(
    .recordAttempt(
      actionID: ActionID("action-late-watch-attempt"),
      attemptID: AttemptID("attempt-late-watch"),
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    to: state
  )

  try expect(late.outcome == .accepted, "expected genuine late Attempt to be preserved")
  try expect(late.state.snapshot.attempts.count == 1, "expected late Attempt in history")
  try expect(
    late.state.snapshot.visits.first?.captureState == .ended,
    "expected capture state to remain ended")
  try expect(
    late.state.snapshot.visits.first?.reviewState == .needsRecheck,
    "expected late material event to reopen review attention")
}

func lateResultAfterCompletedReviewNeedsRecheck() throws {
  let visitID = GymVisitID("visit-late-result-review")
  let attemptID = AttemptID("attempt-late-result-review")

  let setup: [VisitCommand] = [
    .startVisit(
      actionID: ActionID("action-start-late-result-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-late-result-review"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    .endVisit(
      actionID: ActionID("action-end-late-result-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .beginReview(
      actionID: ActionID("action-begin-late-result-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .iPhone
    ),
    .completeReview(
      actionID: ActionID("action-complete-late-result-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let lateResult = VisitMemory.apply(
    .markSend(
      actionID: ActionID("action-late-result-review"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 2_500),
      source: .watch
    ),
    to: state
  )

  try expect(lateResult.outcome == .accepted, "expected late result to be preserved")
  try expect(
    lateResult.state.snapshot.attempts.first?.outcome == .sent,
    "expected late result to update the Attempt"
  )
  try expect(
    lateResult.state.snapshot.visits.first?.reviewState == .needsRecheck,
    "expected late result to reopen review attention"
  )
}

func undoAfterCompletedReviewNeedsRecheck() throws {
  let visitID = GymVisitID("visit-late-undo-review")
  let attemptID = AttemptID("attempt-late-undo-review")
  let sendActionID = ActionID("action-send-late-undo-review")

  let setup: [VisitCommand] = [
    .startVisit(
      actionID: ActionID("action-start-late-undo-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-late-undo-review"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    .markSend(
      actionID: sendActionID,
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 2_500),
      source: .watch
    ),
    .endVisit(
      actionID: ActionID("action-end-late-undo-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .beginReview(
      actionID: ActionID("action-begin-late-undo-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .iPhone
    ),
    .completeReview(
      actionID: ActionID("action-complete-late-undo-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let lateUndo = VisitMemory.apply(
    .undo(
      actionID: ActionID("action-late-undo-review"),
      targetActionID: sendActionID,
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(lateUndo.outcome == .accepted, "expected exact-target Undo to be preserved")
  try expect(
    lateUndo.state.snapshot.attempts.first?.outcome == .unresolved,
    "expected late Undo to reproject the Attempt"
  )
  try expect(
    lateUndo.state.snapshot.visits.first?.reviewState == .needsRecheck,
    "expected late Undo to reopen review attention"
  )
}

func anEndedVisitIDCannotBeReused() throws {
  let visitID = GymVisitID("visit-id-reuse")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-visit-id-reuse"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .endVisit(
        actionID: ActionID("action-end-visit-id-reuse"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: state
    )
  )

  let reused = VisitMemory.apply(
    .startVisit(
      actionID: ActionID("action-reuse-ended-visit-id"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(
    reused.outcome == .rejected(.visitAlreadyExists),
    "expected a durable GymVisit identity not to be reused"
  )
  try expect(reused.state == state, "expected rejected ID reuse not to overwrite visit history")
}

func aRouteCardCanStartOneActiveProjectCycle() throws {
  let routeID = RouteCardID("route-project-cycle")
  let projectID = ProjectID("project-cycle-1")

  var state = try acceptedState(
    VisitMemory.apply(
      .createRouteCard(
        actionID: ActionID("action-create-project-route"),
        routeCardID: routeID,
        label: "Blue slab left",
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      ),
      to: VisitState()
    )
  )
  state = try acceptedState(
    VisitMemory.apply(
      .startProject(
        actionID: ActionID("action-start-project-cycle"),
        projectID: projectID,
        routeCardID: routeID,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .iPhone
      ),
      to: state
    )
  )

  try expect(
    state.snapshot.routeCards.first?.id == routeID, "expected RouteCard identity to remain stable")
  try expect(
    state.snapshot.routeCards.first?.availability == .present,
    "expected physical availability to remain separate")
  try expect(
    state.snapshot.projects == [
      ProjectSnapshot(
        id: projectID,
        routeCardID: routeID,
        state: .active,
        startedAt: Instant(millisecondsSince1970: 2_000),
        closedAt: nil,
        supportingAttemptID: nil
      )
    ], "expected one active Project cycle")
}

func aProjectCanCloseSentOnlyWithASentAttemptOnTheSameRoute() throws {
  let routeID = RouteCardID("route-project-send")
  let projectID = ProjectID("project-send")
  let visitID = GymVisitID("visit-project-send")
  let attemptID = AttemptID("attempt-project-send")

  var state = VisitState()
  let setup: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("action-create-route-send"),
      routeCardID: routeID,
      label: "Red overhang",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-start-project-send"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("action-start-visit-project-send"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-project-send"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("action-mark-project-send"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_100),
      source: .watch
    ),
  ]

  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let closed = VisitMemory.apply(
    .closeProjectSent(
      actionID: ActionID("action-close-project-sent"),
      projectID: projectID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(closed.outcome == .accepted, "expected sent Attempt to support Project send")
  try expect(
    closed.state.snapshot.projects.first?.state == .sent, "expected Project cycle to close sent")
  try expect(
    closed.state.snapshot.projects.first?.supportingAttemptID == attemptID,
    "expected supporting Attempt link to remain explicit")
}

func materialResetCreatesASuccessorAndClosesOnlyTheActiveProjectGone() throws {
  let oldRouteID = RouteCardID("route-before-reset")
  let successorRouteID = RouteCardID("route-after-reset")
  let projectID = ProjectID("project-before-reset")

  var state = VisitState()
  for command in [
    VisitCommand.createRouteCard(
      actionID: ActionID("action-create-before-reset"),
      routeCardID: oldRouteID,
      label: "Green cave",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-project-before-reset"),
      projectID: projectID,
      routeCardID: oldRouteID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
  ] {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let reset = VisitMemory.apply(
    .replaceRouteAfterReset(
      actionID: ActionID("action-material-reset"),
      oldRouteCardID: oldRouteID,
      successorRouteCardID: successorRouteID,
      successorLabel: "Orange cave",
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    to: state
  )

  let routes = Dictionary(uniqueKeysWithValues: reset.state.snapshot.routeCards.map { ($0.id, $0) })
  try expect(reset.outcome == .accepted, "expected material reset to be accepted")
  try expect(
    routes[oldRouteID]?.availability == .gone,
    "expected old physical route incarnation to become gone")
  try expect(
    routes[oldRouteID]?.successorRouteCardID == successorRouteID, "expected explicit successor link"
  )
  try expect(
    routes[successorRouteID]?.availability == .present,
    "expected successor to be a new present RouteCard")
  try expect(
    reset.state.snapshot.projects.first?.state == .gone,
    "expected only active Project cycle to close gone")
  try expect(
    reset.state.snapshot.projects.first?.routeCardID == oldRouteID,
    "expected Project history to stay on predecessor")
}

func undoingTheOnlySupportingSendReopensTheProjectCycle() throws {
  let routeID = RouteCardID("route-undo-project-send")
  let projectID = ProjectID("project-undo-project-send")
  let visitID = GymVisitID("visit-undo-project-send")
  let attemptID = AttemptID("attempt-undo-project-send")
  let markSendActionID = ActionID("action-mark-send-for-project-undo")

  let commands: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("action-create-route-project-undo"),
      routeCardID: routeID,
      label: "Purple vertical",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-start-project-undo"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("action-start-visit-project-undo"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-project-undo"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .markSend(
      actionID: markSendActionID,
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_100),
      source: .watch
    ),
    .closeProjectSent(
      actionID: ActionID("action-close-project-before-undo"),
      projectID: projectID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in commands {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let undone = VisitMemory.apply(
    .undo(
      actionID: ActionID("action-undo-supporting-send"),
      targetActionID: markSendActionID,
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(
    undone.outcome == .accepted, "expected correction of supporting Send to remain possible")
  try expect(
    undone.state.snapshot.attempts.first?.outcome == .unresolved,
    "expected Attempt Send to be undone")
  try expect(
    undone.state.snapshot.projects.first?.state == .active,
    "expected Project not to remain sent without support")
  try expect(
    undone.state.snapshot.projects.first?.supportingAttemptID == nil,
    "expected stale supporting Attempt link to clear")
}

func confirmingTheSupportingAttemptNotSentReopensTheProjectCycle() throws {
  let routeID = RouteCardID("route-confirm-project-not-sent")
  let projectID = ProjectID("project-confirm-project-not-sent")
  let visitID = GymVisitID("visit-confirm-project-not-sent")
  let attemptID = AttemptID("attempt-confirm-project-not-sent")

  let commands: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("action-create-route-confirm-not-sent"),
      routeCardID: routeID,
      label: "Yellow slab",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-start-project-confirm-not-sent"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("action-start-visit-confirm-not-sent"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-confirm-not-sent"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("action-mark-confirm-not-sent"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_100),
      source: .watch
    ),
    .closeProjectSent(
      actionID: ActionID("action-close-before-confirm-not-sent"),
      projectID: projectID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in commands {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let corrected = VisitMemory.apply(
    .confirmNotSent(
      actionID: ActionID("action-correct-project-not-sent"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(corrected.outcome == .accepted, "expected explicit result correction to be accepted")
  try expect(
    corrected.state.snapshot.attempts.first?.outcome == .notSent,
    "expected supporting Attempt to become not sent")
  try expect(
    corrected.state.snapshot.projects.first?.state == .active,
    "expected unsupported sent Project to reopen")
  try expect(
    corrected.state.snapshot.projects.first?.supportingAttemptID == nil,
    "expected stale support link to clear")
}

func undoingNotSentCorrectionRestoresTheSentProjectProjection() throws {
  let routeID = RouteCardID("route-undo-not-sent-correction")
  let projectID = ProjectID("project-undo-not-sent-correction")
  let visitID = GymVisitID("visit-undo-not-sent-correction")
  let attemptID = AttemptID("attempt-undo-not-sent-correction")
  let correctionActionID = ActionID("action-not-sent-correction-to-undo")

  let commands: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("action-create-route-undo-not-sent"),
      routeCardID: routeID,
      label: "Green compression",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-start-project-undo-not-sent"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("action-start-visit-undo-not-sent"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-undo-not-sent"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("action-mark-undo-not-sent"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_100),
      source: .watch
    ),
    .closeProjectSent(
      actionID: ActionID("action-close-undo-not-sent"),
      projectID: projectID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
    .confirmNotSent(
      actionID: correctionActionID,
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in commands {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let undone = VisitMemory.apply(
    .undo(
      actionID: ActionID("action-undo-not-sent-correction"),
      targetActionID: correctionActionID,
      occurredAt: Instant(millisecondsSince1970: 7_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(undone.outcome == .accepted, "expected the result correction to be reversible")
  try expect(
    undone.state.snapshot.attempts.first?.outcome == .sent,
    "expected Undo to restore the prior sent outcome"
  )
  try expect(
    undone.state.snapshot.projects.first?.state == .sent,
    "expected the still-active Project close event to be projected again"
  )
  try expect(
    undone.state.snapshot.projects.first?.supportingAttemptID == attemptID,
    "expected restored Project projection to retain its supporting Attempt"
  )
}

func attemptResultProjectionUsesBusinessTimeNotArrivalOrder() throws {
  let visitID = GymVisitID("visit-result-order")
  let attemptID = AttemptID("attempt-result-order")

  var base = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-result-order"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  base = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("action-record-result-order"),
        attemptID: attemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: base
    )
  )

  let earlierSend = VisitCommand.markSend(
    actionID: ActionID("action-earlier-send"),
    attemptID: attemptID,
    occurredAt: Instant(millisecondsSince1970: 2_100),
    source: .watch
  )
  let laterNotSent = VisitCommand.confirmNotSent(
    actionID: ActionID("action-later-not-sent"),
    attemptID: attemptID,
    occurredAt: Instant(millisecondsSince1970: 2_200),
    source: .iPhone
  )

  var chronological = try acceptedState(VisitMemory.apply(earlierSend, to: base))
  chronological = try acceptedState(VisitMemory.apply(laterNotSent, to: chronological))

  var reversedArrival = try acceptedState(VisitMemory.apply(laterNotSent, to: base))
  reversedArrival = try acceptedState(VisitMemory.apply(earlierSend, to: reversedArrival))

  try expect(
    chronological.snapshot == reversedArrival.snapshot,
    "expected the same result events to project identically regardless of arrival order"
  )
  try expect(
    reversedArrival.snapshot.attempts.first?.outcome == .notSent,
    "expected the later business-time correction to remain current"
  )
}

func sameTimeOpposingResultsRequireReconciliation() throws {
  let visitID = GymVisitID("visit-result-ambiguity")
  let attemptID = AttemptID("attempt-result-ambiguity")

  var base = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-result-ambiguity"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  base = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("action-record-result-ambiguity"),
        attemptID: attemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      to: base
    )
  )

  let send = VisitCommand.markSend(
    actionID: ActionID("result-z-send"),
    attemptID: attemptID,
    occurredAt: Instant(millisecondsSince1970: 2_100),
    source: .watch
  )
  let notSent = VisitCommand.confirmNotSent(
    actionID: ActionID("result-a-not-sent"),
    attemptID: attemptID,
    occurredAt: Instant(millisecondsSince1970: 2_100),
    source: .iPhone
  )

  var sendFirst = try acceptedState(VisitMemory.apply(send, to: base))
  sendFirst = try acceptedState(VisitMemory.apply(notSent, to: sendFirst))
  var notSentFirst = try acceptedState(VisitMemory.apply(notSent, to: base))
  notSentFirst = try acceptedState(VisitMemory.apply(send, to: notSentFirst))

  try expect(
    sendFirst == notSentFirst,
    "expected ambiguous result projection and issue identity not to depend on arrival order"
  )
  try expect(
    sendFirst.snapshot.attempts.first?.outcome == .unresolved,
    "expected unknowable result order to remain unresolved"
  )
  try expect(
    sendFirst.snapshot.reconciliationIssues == [
      ReconciliationIssueSnapshot(
        actionID: ActionID("result-z-send"),
        reason: .conflict(.ambiguousAttemptOutcome(attemptID))
      )
    ],
    "expected both opposing same-time results to produce one deterministic review issue"
  )
}

func correctingHistoricalSendCannotCreateTwoActiveProjects() throws {
  let routeID = RouteCardID("route-project-overlap")
  let oldProjectID = ProjectID("project-overlap-old")
  let newProjectID = ProjectID("project-overlap-new")
  let visitID = GymVisitID("visit-project-overlap")
  let attemptID = AttemptID("attempt-project-overlap")

  let setup: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("action-create-route-project-overlap"),
      routeCardID: routeID,
      label: "Blue coordination",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-start-old-project-overlap"),
      projectID: oldProjectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("action-start-visit-project-overlap"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-project-overlap"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("action-mark-project-overlap"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_100),
      source: .watch
    ),
    .closeProjectSent(
      actionID: ActionID("action-close-old-project-overlap"),
      projectID: oldProjectID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-start-new-project-overlap"),
      projectID: newProjectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .iPhone
    ),
    .endVisit(
      actionID: ActionID("action-end-visit-project-overlap"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 6_500),
      source: .watch
    ),
    .beginReview(
      actionID: ActionID("action-begin-review-project-overlap"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 6_600),
      source: .iPhone
    ),
    .completeReview(
      actionID: ActionID("action-complete-review-project-overlap"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 6_700),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let corrected = VisitMemory.apply(
    .confirmNotSent(
      actionID: ActionID("action-correct-historical-project-overlap"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 7_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(
    corrected.outcome == .conflict(.projectCycleWouldOverlap(routeID)),
    "expected historical correction to require coupled Project review"
  )
  try expect(
    corrected.state.snapshot.projects.filter { $0.state == .active }.count == 1,
    "expected at most one active Project for the RouteCard"
  )
  try expect(
    corrected.state.snapshot.attempts.first?.outcome == .sent,
    "expected conflicting correction not to change the current Attempt projection"
  )
  try expect(
    corrected.state.snapshot.visits.first?.reviewState == .needsRecheck,
    "expected the conflict to reopen completed review attention"
  )
  try expect(
    corrected.state.snapshot.reconciliationIssues == [
      ReconciliationIssueSnapshot(
        actionID: ActionID("action-correct-historical-project-overlap"),
        reason: .conflict(.projectCycleWouldOverlap(routeID))
      )
    ],
    "expected the conflicting command to remain visible for reconciliation"
  )

  let duplicateConflict = VisitMemory.apply(
    .confirmNotSent(
      actionID: ActionID("action-correct-historical-project-overlap"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 7_000),
      source: .iPhone
    ),
    to: corrected.state
  )
  try expect(
    duplicateConflict.outcome == corrected.outcome && duplicateConflict.state == corrected.state,
    "expected retrying the same conflicting command to be idempotent"
  )
}

func correctingSendAfterRouteResetKeepsTheProjectGone() throws {
  let oldRouteID = RouteCardID("route-gone-project-replay")
  let successorRouteID = RouteCardID("route-successor-project-replay")
  let projectID = ProjectID("project-gone-project-replay")
  let visitID = GymVisitID("visit-gone-project-replay")
  let attemptID = AttemptID("attempt-gone-project-replay")

  let setup: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("action-create-route-gone-project-replay"),
      routeCardID: oldRouteID,
      label: "White slab before reset",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-start-project-gone-project-replay"),
      projectID: projectID,
      routeCardID: oldRouteID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("action-start-visit-gone-project-replay"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("action-record-gone-project-replay"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: oldRouteID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("action-mark-gone-project-replay"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_100),
      source: .watch
    ),
    .closeProjectSent(
      actionID: ActionID("action-close-gone-project-replay"),
      projectID: projectID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
    .replaceRouteAfterReset(
      actionID: ActionID("action-reset-gone-project-replay"),
      oldRouteCardID: oldRouteID,
      successorRouteCardID: successorRouteID,
      successorLabel: "Orange slab after reset",
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let corrected = VisitMemory.apply(
    .confirmNotSent(
      actionID: ActionID("action-correct-gone-project-replay"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 7_000),
      source: .iPhone
    ),
    to: state
  )

  try expect(corrected.outcome == .accepted, "expected the Attempt correction to be accepted")
  try expect(
    corrected.state.snapshot.attempts.first?.outcome == .notSent,
    "expected the corrected Attempt projection"
  )
  try expect(
    corrected.state.snapshot.projects.first?.state == .gone,
    "expected reset availability to dominate the restored pre-send active state"
  )
  try expect(
    corrected.state.snapshot.projects.first?.closedAt
      == Instant(millisecondsSince1970: 6_000),
    "expected the Project to retain the route-reset closure time"
  )
}

func undoRecordAttemptConflictsWhenALaterResultDependsOnIt() throws {
  let visitID = GymVisitID("visit-undo-dependent")
  let attemptID = AttemptID("attempt-undo-dependent")
  let recordActionID = ActionID("action-record-with-dependent")

  var state = VisitState()
  for command in [
    VisitCommand.startVisit(
      actionID: ActionID("action-start-undo-dependent"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: recordActionID,
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("action-dependent-send"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 2_100),
      source: .iPhone
    ),
  ] {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let conflict = VisitMemory.apply(
    .undo(
      actionID: ActionID("action-undo-record-with-dependent"),
      targetActionID: recordActionID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    to: state
  )

  try expect(
    conflict.outcome == .conflict(.targetHasDependentActions),
    "expected Undo not to orphan a later result silently"
  )
  try expect(
    conflict.state.snapshot.attempts.first?.recordState == .active,
    "expected Attempt to remain active until reviewed")
  try expect(
    conflict.state.snapshot.reconciliationIssues == [
      ReconciliationIssueSnapshot(
        actionID: ActionID("action-undo-record-with-dependent"),
        reason: .conflict(.targetHasDependentActions)
      )
    ],
    "expected dependent-action conflict to preserve both records for review"
  )
}

func lateResultTargetingRetractedAttemptRequiresReview() throws {
  let visitID = GymVisitID("visit-result-retracted-review")
  let attemptID = AttemptID("attempt-result-retracted-review")
  let recordActionID = ActionID("action-record-result-retracted-review")
  let lateResultActionID = ActionID("action-late-result-retracted-review")

  let setup: [VisitCommand] = [
    .startVisit(
      actionID: ActionID("action-start-result-retracted-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    ),
    .recordAttempt(
      actionID: recordActionID,
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    .undo(
      actionID: ActionID("action-undo-result-retracted-review"),
      targetActionID: recordActionID,
      occurredAt: Instant(millisecondsSince1970: 2_100),
      source: .watch
    ),
    .endVisit(
      actionID: ActionID("action-end-result-retracted-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .beginReview(
      actionID: ActionID("action-begin-result-retracted-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .iPhone
    ),
    .completeReview(
      actionID: ActionID("action-complete-result-retracted-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
  ]

  var state = VisitState()
  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let command = VisitCommand.markSend(
    actionID: lateResultActionID,
    attemptID: attemptID,
    occurredAt: Instant(millisecondsSince1970: 2_050),
    source: .watch
  )
  let conflicted = VisitMemory.apply(command, to: state)

  try expect(
    conflicted.outcome == .conflict(.targetIsRetracted(attemptID)),
    "expected a result targeting a retracted Attempt to require review"
  )
  try expect(
    conflicted.state.snapshot.attempts.first?.recordState == .retracted,
    "expected the dependent result not to restore its retracted target"
  )
  try expect(
    conflicted.state.snapshot.visits.first?.reviewState == .needsRecheck,
    "expected the late semantic conflict to reopen completed review"
  )
  try expect(
    conflicted.state.snapshot.reconciliationIssues == [
      ReconciliationIssueSnapshot(
        actionID: lateResultActionID,
        reason: .conflict(.targetIsRetracted(attemptID))
      )
    ],
    "expected the rejected dependent intent to remain visible"
  )

  let retry = VisitMemory.apply(command, to: conflicted.state)
  try expect(
    retry.outcome == conflicted.outcome && retry.state == conflicted.state,
    "expected conflict delivery retry to be idempotent"
  )
}

func deferredCommandConflictRemainsVisibleForReview() throws {
  let visitID = GymVisitID("visit-deferred-conflict")
  let attemptID = AttemptID("attempt-deferred-conflict")
  let recordActionID = ActionID("action-late-record-with-dependents")
  let undoActionID = ActionID("action-pending-undo-conflict")

  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("action-start-deferred-conflict"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      ),
      to: VisitState()
    )
  )
  state =
    VisitMemory.apply(
      .markSend(
        actionID: ActionID("action-pending-send-conflict"),
        attemptID: attemptID,
        occurredAt: Instant(millisecondsSince1970: 2_100),
        source: .watch
      ),
      to: state
    ).state
  state =
    VisitMemory.apply(
      .undo(
        actionID: undoActionID,
        targetActionID: recordActionID,
        occurredAt: Instant(millisecondsSince1970: 2_200),
        source: .watch
      ),
      to: state
    ).state

  let targetArrived = VisitMemory.apply(
    .recordAttempt(
      actionID: recordActionID,
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ),
    to: state
  )

  try expect(
    targetArrived.state.snapshot.attempts.first?.outcome == .sent,
    "expected pending Send to resolve first")
  try expect(
    targetArrived.state.snapshot.reconciliationIssues == [
      ReconciliationIssueSnapshot(
        actionID: undoActionID,
        reason: .conflict(.targetHasDependentActions)
      )
    ], "expected conflicting pending Undo to remain visible for review")
}

let specifications: [(String, () throws -> Void)] = [
  (
    "one Record Attempt command creates one unresolved Attempt",
    oneRecordAttemptCommandCreatesOneUnresolvedAttempt
  ),
  (
    "retrying the same action is an idempotent duplicate",
    retryingTheSameActionIsAnIdempotentDuplicate
  ),
  (
    "reusing an action ID for different meaning is a conflict",
    reusingAnActionIDForDifferentMeaningIsAConflict
  ),
  (
    "Mark Send changes the existing Attempt without increasing count",
    markSendChangesTheExistingAttemptWithoutIncreasingCount
  ),
  (
    "Undo targets the named Mark Send even after a newer Attempt",
    undoTargetsTheNamedMarkSendEvenAfterANewerAttempt
  ),
  (
    "Undo Record Attempt retracts it and excludes it from active counts",
    undoingRecordAttemptRetractsItAndExcludesItFromActiveCounts
  ),
  ("ending a visit leaves Attempt outcome unresolved", endingAVisitLeavesAttemptOutcomeUnresolved),
  (
    "Confirm Not Sent is explicit and does not create another Attempt",
    confirmNotSentIsExplicitAndDoesNotCreateAnotherAttempt
  ),
  ("out-of-order Mark Send waits for its exact Attempt", outOfOrderMarkSendWaitsForItsExactAttempt),
  ("out-of-order Undo waits for its exact target", outOfOrderUndoWaitsForItsExactTarget),
  (
    "late Attempt after completed review is preserved and needs recheck",
    lateAttemptAfterCompletedReviewIsPreservedAndNeedsRecheck
  ),
  (
    "late result after completed review needs recheck",
    lateResultAfterCompletedReviewNeedsRecheck
  ),
  (
    "Undo after completed review needs recheck",
    undoAfterCompletedReviewNeedsRecheck
  ),
  ("an ended GymVisit ID cannot be reused", anEndedVisitIDCannotBeReused),
  ("a RouteCard can start one active Project cycle", aRouteCardCanStartOneActiveProjectCycle),
  (
    "a Project closes sent only with a sent Attempt on the same route",
    aProjectCanCloseSentOnlyWithASentAttemptOnTheSameRoute
  ),
  (
    "material reset creates a successor and closes the active Project gone",
    materialResetCreatesASuccessorAndClosesOnlyTheActiveProjectGone
  ),
  (
    "Undoing the only supporting Send reopens the Project cycle",
    undoingTheOnlySupportingSendReopensTheProjectCycle
  ),
  (
    "Confirming the supporting Attempt not sent reopens the Project cycle",
    confirmingTheSupportingAttemptNotSentReopensTheProjectCycle
  ),
  (
    "Undoing a Not Sent correction restores the sent Project projection",
    undoingNotSentCorrectionRestoresTheSentProjectProjection
  ),
  (
    "Attempt result projection uses business time rather than arrival order",
    attemptResultProjectionUsesBusinessTimeNotArrivalOrder
  ),
  (
    "same-time opposing results require reconciliation",
    sameTimeOpposingResultsRequireReconciliation
  ),
  (
    "correcting a historical Send cannot create two active Projects",
    correctingHistoricalSendCannotCreateTwoActiveProjects
  ),
  (
    "correcting a Send after route reset keeps the Project gone",
    correctingSendAfterRouteResetKeepsTheProjectGone
  ),
  (
    "Undo Record Attempt conflicts when a later result depends on it",
    undoRecordAttemptConflictsWhenALaterResultDependsOnIt
  ),
  (
    "late result targeting a retracted Attempt requires review",
    lateResultTargetingRetractedAttemptRequiresReview
  ),
  (
    "deferred command conflict remains visible for review",
    deferredCommandConflictRemainsVisibleForReview
  ),
]

var failures: [String] = []

for (name, specification) in specifications {
  do {
    try specification()
    print("PASS: \(name)")
  } catch {
    failures.append("FAIL: \(name) — \(error)")
  }
}

if failures.isEmpty {
  print("LineWiseDomainSpec: \(specifications.count) passed")
} else {
  fatalError(failures.joined(separator: "\n"))
}
