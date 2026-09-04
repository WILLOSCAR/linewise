import Foundation
import LineWiseDomain

private func routeCardRevisionKeepsIdentityAndHistoricalBindings() throws {
  let routeID = RouteCardID("route-revision")
  let visitID = GymVisitID("visit-revision")
  let attemptID = AttemptID("attempt-revision")
  let projectID = ProjectID("project-revision")
  var state = VisitState()

  let commands: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("create-revision-route"),
      routeCardID: routeID,
      label: "Blue slab",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-revision-project"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("start-revision-visit"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    .recordAttempt(
      actionID: ActionID("record-revision-attempt"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .reviseRouteCard(
      actionID: ActionID("revise-route"),
      routeCardID: routeID,
      revisedLabel: "Blue slab · left corner",
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
  ]

  for command in commands {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  try expect(state.snapshot.routeCards.count == 1, "expected revision to keep one RouteCard")
  try expect(
    state.snapshot.routeCards.first?.label == "Blue slab · left corner",
    "expected revised label"
  )
  try expect(
    state.snapshot.attempts.first?.routeCardID == routeID,
    "expected historical Attempt binding to retain RouteCard identity"
  )
  try expect(
    state.snapshot.projects.first?.routeCardID == routeID,
    "expected historical Project binding to retain RouteCard identity"
  )
}

private func routeCardArchiveAndRestoreOnlyChangeSelectionVisibility() throws {
  let routeID = RouteCardID("route-visibility")
  let projectID = ProjectID("project-visibility")
  var state = VisitState()
  for command in [
    VisitCommand.createRouteCard(
      actionID: ActionID("create-visibility-route"),
      routeCardID: routeID,
      label: "Orange roof",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-visibility-project"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .archiveRouteCard(
      actionID: ActionID("archive-route"),
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
  ] {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  try expect(state.snapshot.selectableRouteCards.isEmpty, "expected archived route to be hidden")
  try expect(
    state.snapshot.routeCards.first?.availability == .present,
    "expected archive not to imply gone"
  )
  try expect(
    state.snapshot.projects.first?.state == .active,
    "expected RouteCard archive not to rewrite Project state"
  )

  state = try acceptedState(
    VisitMemory.apply(
      .restoreRouteCard(
        actionID: ActionID("restore-route"),
        routeCardID: routeID,
        occurredAt: Instant(millisecondsSince1970: 4_000),
        source: .iPhone
      ),
      to: state
    )
  )

  try expect(
    state.snapshot.selectableRouteCards.map(\.id) == [routeID],
    "expected restore to return the same RouteCard to normal selection"
  )
  try expect(
    state.snapshot.projects.first?.id == projectID,
    "expected restore not to create or rewrite a Project cycle"
  )
}

private func goneClosesOnlyActiveProjectAndCorrectionDoesNotReopenIt() throws {
  let routeID = RouteCardID("route-availability")
  let visitID = GymVisitID("visit-availability")
  let attemptID = AttemptID("attempt-availability-send")
  let sentProjectID = ProjectID("project-availability-sent")
  let archivedProjectID = ProjectID("project-availability-archived")
  let activeProjectID = ProjectID("project-availability-active")
  var state = VisitState()
  let commands: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("create-availability-route"),
      routeCardID: routeID,
      label: "Green traverse",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("start-availability-visit"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .recordAttempt(
      actionID: ActionID("record-availability-attempt"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("send-availability-attempt"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ),
    .startProject(
      actionID: ActionID("start-sent-project"),
      projectID: sentProjectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
    .closeProjectSent(
      actionID: ActionID("close-sent-project"),
      projectID: sentProjectID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-archived-project"),
      projectID: archivedProjectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 7_000),
      source: .iPhone
    ),
    .archiveProject(
      actionID: ActionID("archive-project"),
      projectID: archivedProjectID,
      occurredAt: Instant(millisecondsSince1970: 8_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-active-project"),
      projectID: activeProjectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 9_000),
      source: .iPhone
    ),
    .correctRouteAvailability(
      actionID: ActionID("mark-route-gone"),
      routeCardID: routeID,
      availability: .gone,
      occurredAt: Instant(millisecondsSince1970: 10_000),
      source: .iPhone
    ),
  ]
  for command in commands {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  var projects = Dictionary(uniqueKeysWithValues: state.snapshot.projects.map { ($0.id, $0) })
  try expect(projects[sentProjectID]?.state == .sent, "expected sent history to stay sent")
  try expect(
    projects[archivedProjectID]?.state == .archived,
    "expected archived history to stay archived"
  )
  try expect(projects[activeProjectID]?.state == .gone, "expected only active cycle to close gone")

  state = try acceptedState(
    VisitMemory.apply(
      .correctRouteAvailability(
        actionID: ActionID("correct-route-present"),
        routeCardID: routeID,
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 11_000),
        source: .iPhone
      ),
      to: state
    )
  )
  projects = Dictionary(uniqueKeysWithValues: state.snapshot.projects.map { ($0.id, $0) })
  try expect(
    projects[activeProjectID]?.state == .gone,
    "expected correcting availability not to reopen a terminal Project cycle"
  )
}

private func confirmedMergeRedirectsWithoutRewritingHistoricalIdentity() throws {
  let duplicateID = RouteCardID("route-merge-duplicate")
  let canonicalID = RouteCardID("route-merge-canonical")
  let visitID = GymVisitID("visit-merge")
  let attemptID = AttemptID("attempt-merge")
  let projectID = ProjectID("project-merge")
  let merge = VisitCommand.confirmRouteCardMerge(
    actionID: ActionID("confirm-merge"),
    duplicateRouteCardID: duplicateID,
    canonicalRouteCardID: canonicalID,
    occurredAt: Instant(millisecondsSince1970: 6_000),
    source: .iPhone
  )
  var state = VisitState()
  for command in [
    VisitCommand.createRouteCard(
      actionID: ActionID("create-merge-duplicate"),
      routeCardID: duplicateID,
      label: "Blue 5",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .createRouteCard(
      actionID: ActionID("create-merge-canonical"),
      routeCardID: canonicalID,
      label: "Blue corner",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-merge-project"),
      projectID: projectID,
      routeCardID: duplicateID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("start-merge-visit"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .iPhone
    ),
    .recordAttempt(
      actionID: ActionID("record-merge-attempt"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: duplicateID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .watch
    ),
    merge,
  ] {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let routes = Dictionary(uniqueKeysWithValues: state.snapshot.routeCards.map { ($0.id, $0) })
  try expect(
    routes[duplicateID]?.recordVisibility == .merged
      && routes[duplicateID]?.mergedIntoRouteCardID == canonicalID,
    "expected a one-hop redirect from duplicate to canonical"
  )
  try expect(
    state.snapshot.canonicalRouteCardID(for: duplicateID) == canonicalID,
    "expected canonical redirect to be queryable"
  )
  try expect(
    state.snapshot.attempts.first?.routeCardID == duplicateID,
    "expected historical Attempt to retain its original RouteCard identity"
  )
  try expect(
    state.snapshot.projects.first?.routeCardID == duplicateID,
    "expected historical Project to retain its original RouteCard identity"
  )
  try expect(
    VisitMemory.apply(merge, to: state).outcome == .duplicate,
    "expected retry to be idempotent"
  )
  try expect(
    VisitMemory.apply(
      .startProject(
        actionID: ActionID("start-canonical-overlap"),
        projectID: ProjectID("project-canonical-overlap"),
        routeCardID: canonicalID,
        occurredAt: Instant(millisecondsSince1970: 7_000),
        source: .iPhone
      ),
      to: state
    ).outcome == .rejected(.activeProjectAlreadyExists),
    "expected canonical group to keep one active Project"
  )
}

private func routeMergeRejectsSelfMergedTargetsAndRedirectChains() throws {
  let routeA = RouteCardID("route-merge-a")
  let routeB = RouteCardID("route-merge-b")
  let routeC = RouteCardID("route-merge-c")
  var state = VisitState()
  for (index, routeID) in [routeA, routeB, routeC].enumerated() {
    state = try acceptedState(
      VisitMemory.apply(
        .createRouteCard(
          actionID: ActionID("create-route-\(index)"),
          routeCardID: routeID,
          label: "Route \(index)",
          availability: .present,
          occurredAt: Instant(millisecondsSince1970: Int64(index + 1)),
          source: .iPhone
        ),
        to: state
      )
    )
  }

  try expect(
    VisitMemory.apply(
      .confirmRouteCardMerge(
        actionID: ActionID("merge-self"),
        duplicateRouteCardID: routeA,
        canonicalRouteCardID: routeA,
        occurredAt: Instant(millisecondsSince1970: 10),
        source: .iPhone
      ),
      to: state
    ).outcome == .rejected(.routeCardCannotMergeIntoSelf),
    "expected self merge to be rejected"
  )

  state = try acceptedState(
    VisitMemory.apply(
      .confirmRouteCardMerge(
        actionID: ActionID("merge-b-into-a"),
        duplicateRouteCardID: routeB,
        canonicalRouteCardID: routeA,
        occurredAt: Instant(millisecondsSince1970: 20),
        source: .iPhone
      ),
      to: state
    )
  )

  try expect(
    VisitMemory.apply(
      .confirmRouteCardMerge(
        actionID: ActionID("merge-c-into-merged-b"),
        duplicateRouteCardID: routeC,
        canonicalRouteCardID: routeB,
        occurredAt: Instant(millisecondsSince1970: 30),
        source: .iPhone
      ),
      to: state
    ).outcome == .rejected(.routeCardIsMerged),
    "expected a merged RouteCard not to be a canonical target"
  )
  try expect(
    VisitMemory.apply(
      .confirmRouteCardMerge(
        actionID: ActionID("merge-a-into-c-chain"),
        duplicateRouteCardID: routeA,
        canonicalRouteCardID: routeC,
        occurredAt: Instant(millisecondsSince1970: 40),
        source: .iPhone
      ),
      to: state
    ).outcome == .rejected(.routeCardMergeWouldCreateChain),
    "expected a canonical source with inbound redirects not to create a chain"
  )
}

private func routeMergePreservesConflictWhenBothSidesHaveActiveProjects() throws {
  let duplicateID = RouteCardID("route-conflicting-duplicate")
  let canonicalID = RouteCardID("route-conflicting-canonical")
  var state = VisitState()
  let setup: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("create-conflicting-duplicate"),
      routeCardID: duplicateID,
      label: "Duplicate",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1),
      source: .iPhone
    ),
    .createRouteCard(
      actionID: ActionID("create-conflicting-canonical"),
      routeCardID: canonicalID,
      label: "Canonical",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 2),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-conflicting-duplicate"),
      projectID: ProjectID("project-conflicting-duplicate"),
      routeCardID: duplicateID,
      occurredAt: Instant(millisecondsSince1970: 3),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-conflicting-canonical"),
      projectID: ProjectID("project-conflicting-canonical"),
      routeCardID: canonicalID,
      occurredAt: Instant(millisecondsSince1970: 4),
      source: .iPhone
    ),
  ]
  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }
  let merge = VisitCommand.confirmRouteCardMerge(
    actionID: ActionID("merge-active-conflict"),
    duplicateRouteCardID: duplicateID,
    canonicalRouteCardID: canonicalID,
    occurredAt: Instant(millisecondsSince1970: 5),
    source: .iPhone
  )
  let first = VisitMemory.apply(merge, to: state)
  let expected = CommandOutcome.conflict(
    .routeMergeHasActiveProjectConflict(
      duplicateRouteCardID: duplicateID,
      canonicalRouteCardID: canonicalID
    )
  )

  try expect(first.outcome == expected, "expected both active Projects to block merge")
  try expect(
    first.state.snapshot.routeCards.allSatisfy { $0.recordVisibility == .active },
    "expected conflict not to pick a canonical route silently"
  )
  try expect(
    VisitMemory.apply(merge, to: first.state).outcome == expected,
    "expected conflict retry to preserve the same meaning"
  )
}

/// At most one Project cycle may be active per RouteCard. `confirmRouteCardMerge`
/// and `correctAttemptRoute` both reproject and then refuse the command if that
/// invariant would break. Unmerge reprojects too, and it changes how route IDs
/// canonicalize — which is exactly what `reprojectProjects` uses to decide whether
/// a closed cycle still has valid support. A cycle closed `.sent` by an Attempt on
/// the other identity loses that support when the identities split, flips back to
/// `.active`, and can join a cycle that is already active on the same route.
private func unmergeCannotLeaveTwoActiveProjectCyclesOnOneRouteCard() throws {
  let duplicateID = RouteCardID("route-unmerge-overlap-duplicate")
  let canonicalID = RouteCardID("route-unmerge-overlap-canonical")
  let visitID = GymVisitID("visit-unmerge-overlap")
  let attemptID = AttemptID("attempt-unmerge-overlap")
  let closedCycleID = ProjectID("project-unmerge-overlap-closed")
  let activeCycleID = ProjectID("project-unmerge-overlap-active")
  var state = VisitState()

  for command in [
    VisitCommand.createRouteCard(
      actionID: ActionID("create-unmerge-overlap-duplicate"),
      routeCardID: duplicateID,
      label: "Duplicate",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1),
      source: .iPhone
    ),
    .createRouteCard(
      actionID: ActionID("create-unmerge-overlap-canonical"),
      routeCardID: canonicalID,
      label: "Canonical",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 2),
      source: .iPhone
    ),
    // A cycle on the duplicate, closed sent by an Attempt recorded on the
    // CANONICAL route. While merged the two resolve alike, so support is valid.
    .startProject(
      actionID: ActionID("start-unmerge-overlap-closed"),
      projectID: closedCycleID,
      routeCardID: duplicateID,
      occurredAt: Instant(millisecondsSince1970: 3),
      source: .iPhone
    ),
    .confirmRouteCardMerge(
      actionID: ActionID("merge-unmerge-overlap"),
      duplicateRouteCardID: duplicateID,
      canonicalRouteCardID: canonicalID,
      occurredAt: Instant(millisecondsSince1970: 4),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("start-unmerge-overlap-visit"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 5),
      source: .iPhone
    ),
    .recordAttempt(
      actionID: ActionID("record-unmerge-overlap-attempt"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: canonicalID,
      occurredAt: Instant(millisecondsSince1970: 6),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("send-unmerge-overlap-attempt"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 7),
      source: .watch
    ),
    .closeProjectSent(
      actionID: ActionID("close-unmerge-overlap-closed"),
      projectID: closedCycleID,
      supportingAttemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 8),
      source: .iPhone
    ),
    // Now a fresh active cycle on the canonical route. Legal: the other one is
    // closed.
    .startProject(
      actionID: ActionID("start-unmerge-overlap-active"),
      projectID: activeCycleID,
      routeCardID: canonicalID,
      occurredAt: Instant(millisecondsSince1970: 9),
      source: .iPhone
    ),
  ] {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let activeBefore = state.snapshot.projects.filter { $0.state == .active }
  try expect(
    activeBefore.map(\.id) == [activeCycleID],
    "expected exactly one active cycle before the unmerge, got \(activeBefore.map(\.id))"
  )

  let unmerged = VisitMemory.apply(
    .unmergeRouteCard(
      actionID: ActionID("unmerge-overlap"),
      mergedRouteCardID: duplicateID,
      occurredAt: Instant(millisecondsSince1970: 10),
      source: .iPhone
    ),
    to: state
  )

  // Either unmerge refuses, or it must not produce two active cycles resolving
  // to one RouteCard. Silently producing the overlap is the defect.
  if case .accepted = unmerged.outcome {
    let closed = unmerged.state.snapshot.projects.first { $0.id == closedCycleID }
    try expect(
      closed?.state == .sent,
      """
      unmerge silently reopened a cycle the user had closed sent: \
      \(closedCycleID.rawValue) is now \(String(describing: closed?.state)). The send \
      really happened and its Attempt is untouched, so splitting a route identity \
      must not un-record it
      """
    )
    try expect(
      closed?.supportingAttemptID == attemptID,
      "the supporting Attempt for a sent cycle must survive an unmerge"
    )
  }
}

private func explicitUnmergeRestoresThePreMergeVisibility() throws {
  let recoveredID = RouteCardID("route-unmerge-recovered")
  let formerCanonicalID = RouteCardID("route-unmerge-canonical")
  var state = VisitState()
  let unmerge = VisitCommand.unmergeRouteCard(
    actionID: ActionID("explicit-unmerge"),
    mergedRouteCardID: recoveredID,
    occurredAt: Instant(millisecondsSince1970: 5),
    source: .iPhone
  )
  for command in [
    VisitCommand.createRouteCard(
      actionID: ActionID("create-unmerge-recovered"),
      routeCardID: recoveredID,
      label: "Archived duplicate",
      availability: .unknown,
      occurredAt: Instant(millisecondsSince1970: 1),
      source: .iPhone
    ),
    .createRouteCard(
      actionID: ActionID("create-unmerge-canonical"),
      routeCardID: formerCanonicalID,
      label: "Survivor",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 2),
      source: .iPhone
    ),
    .archiveRouteCard(
      actionID: ActionID("archive-before-merge"),
      routeCardID: recoveredID,
      occurredAt: Instant(millisecondsSince1970: 3),
      source: .iPhone
    ),
    .confirmRouteCardMerge(
      actionID: ActionID("merge-archived-route"),
      duplicateRouteCardID: recoveredID,
      canonicalRouteCardID: formerCanonicalID,
      occurredAt: Instant(millisecondsSince1970: 4),
      source: .iPhone
    ),
    unmerge,
  ] {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let recovered = state.snapshot.routeCards.first { $0.id == recoveredID }
  try expect(
    recovered?.recordVisibility == .archived && recovered?.mergedIntoRouteCardID == nil,
    "expected unmerge to restore archived visibility and clear redirect"
  )
  try expect(
    state.snapshot.canonicalRouteCardID(for: recoveredID) == recoveredID,
    "expected recovered RouteCard to be its own canonical identity"
  )
  try expect(
    VisitMemory.apply(unmerge, to: state).outcome == .duplicate,
    "expected explicit unmerge retry to be idempotent"
  )
}

private func attemptRouteCorrectionKeepsAuditAndReopensReviewedVisit() throws {
  let wrongRouteID = RouteCardID("route-correction-wrong")
  let correctedRouteID = RouteCardID("route-correction-right")
  let visitID = GymVisitID("visit-route-correction")
  let attemptID = AttemptID("attempt-route-correction")
  var state = VisitState()
  let setup: [VisitCommand] = [
    .createRouteCard(
      actionID: ActionID("create-wrong-route"),
      routeCardID: wrongRouteID,
      label: "Wrong route",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1),
      source: .iPhone
    ),
    .createRouteCard(
      actionID: ActionID("create-right-route"),
      routeCardID: correctedRouteID,
      label: "Right route",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 2),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("start-correction-visit"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3),
      source: .iPhone
    ),
    .recordAttempt(
      actionID: ActionID("record-wrong-route-attempt"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: wrongRouteID,
      occurredAt: Instant(millisecondsSince1970: 4),
      source: .watch
    ),
    .endVisit(
      actionID: ActionID("end-correction-visit"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 5),
      source: .iPhone
    ),
    .beginReview(
      actionID: ActionID("begin-correction-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 6),
      source: .iPhone
    ),
    .completeReview(
      actionID: ActionID("complete-correction-review"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 7),
      source: .iPhone
    ),
  ]
  for command in setup {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  state = try acceptedState(
    VisitMemory.apply(
      .correctAttemptRoute(
        actionID: ActionID("correct-attempt-route"),
        attemptID: attemptID,
        routeCardID: correctedRouteID,
        occurredAt: Instant(millisecondsSince1970: 8),
        source: .iPhone
      ),
      to: state
    )
  )

  try expect(
    state.snapshot.attempts.first?.routeCardID == correctedRouteID,
    "expected current Attempt binding to use the corrected route"
  )
  try expect(
    state.snapshot.attemptRouteCorrections == [
      AttemptRouteCorrectionSnapshot(
        actionID: ActionID("correct-attempt-route"),
        attemptID: attemptID,
        previousRouteCardID: wrongRouteID,
        correctedRouteCardID: correctedRouteID,
        occurredAt: Instant(millisecondsSince1970: 8),
        source: .iPhone
      )
    ],
    "expected correction audit to retain original and corrected bindings"
  )
  try expect(
    state.snapshot.visits.first?.reviewState == .needsRecheck,
    "expected correction after review to require recheck"
  )

  state = try acceptedState(
    VisitMemory.apply(
      .correctAttemptRoute(
        actionID: ActionID("leave-attempt-unassigned"),
        attemptID: attemptID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 9),
        source: .iPhone
      ),
      to: state
    )
  )
  try expect(
    state.snapshot.attempts.first?.routeCardID == nil
      && state.snapshot.attemptRouteCorrections.last?.previousRouteCardID == correctedRouteID,
    "expected explicit unassigned correction to retain its prior binding in audit"
  )
}

private func outOfOrderAttemptRouteCorrectionWaitsForExactSubjects() throws {
  let visitID = GymVisitID("visit-deferred-correction")
  let attemptID = AttemptID("attempt-deferred-correction")
  let targetRouteID = RouteCardID("route-deferred-target")
  let correction = VisitCommand.correctAttemptRoute(
    actionID: ActionID("deferred-route-correction"),
    attemptID: attemptID,
    routeCardID: targetRouteID,
    occurredAt: Instant(millisecondsSince1970: 4),
    source: .iPhone
  )
  var state = try acceptedState(
    VisitMemory.apply(
      .startVisit(
        actionID: ActionID("start-deferred-correction-visit"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1),
        source: .iPhone
      ),
      to: VisitState()
    )
  )

  let beforeAttempt = VisitMemory.apply(correction, to: state)
  try expect(
    beforeAttempt.outcome == .deferred(.missingAttempt(attemptID)),
    "expected correction to wait for its exact Attempt"
  )
  state = try acceptedState(
    VisitMemory.apply(
      .recordAttempt(
        actionID: ActionID("record-deferred-correction-attempt"),
        attemptID: attemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 2),
        source: .watch
      ),
      to: beforeAttempt.state
    )
  )
  try expect(
    state.snapshot.pendingActionIDs == [correction.stableActionID],
    "expected correction to keep waiting for its named RouteCard"
  )

  state = try acceptedState(
    VisitMemory.apply(
      .createRouteCard(
        actionID: ActionID("create-deferred-target-route"),
        routeCardID: targetRouteID,
        label: "Delayed target",
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 3),
        source: .iPhone
      ),
      to: state
    )
  )
  try expect(
    state.snapshot.pendingActionIDs.isEmpty
      && state.snapshot.attempts.first?.routeCardID == targetRouteID,
    "expected exact subjects to drain the deferred correction"
  )
  try expect(
    VisitMemory.apply(correction, to: state).outcome == .duplicate,
    "expected a delivered retry not to create another correction"
  )
}

private func archivedProjectStaysTerminalAndReworkStartsANewCycle() throws {
  let routeID = RouteCardID("route-project-rework")
  let archivedID = ProjectID("project-archived-cycle")
  let reworkID = ProjectID("project-rework-cycle")
  var state = VisitState()
  for command in [
    VisitCommand.createRouteCard(
      actionID: ActionID("create-project-rework-route"),
      routeCardID: routeID,
      label: "Purple compression",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-archived-cycle"),
      projectID: archivedID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2),
      source: .iPhone
    ),
    .archiveProject(
      actionID: ActionID("archive-old-cycle"),
      projectID: archivedID,
      occurredAt: Instant(millisecondsSince1970: 3),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("start-rework-cycle"),
      projectID: reworkID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 4),
      source: .iPhone
    ),
  ] {
    state = try acceptedState(VisitMemory.apply(command, to: state))
  }

  let projects = Dictionary(uniqueKeysWithValues: state.snapshot.projects.map { ($0.id, $0) })
  try expect(
    projects[archivedID]?.state == .archived
      && projects[reworkID]?.state == .active
      && projects.count == 2,
    "expected rework to create a new cycle without reopening archived history"
  )
}

func correctionSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "RouteCard revision keeps identity and historical bindings",
      routeCardRevisionKeepsIdentityAndHistoricalBindings
    ),
    (
      "RouteCard archive and restore only change selection visibility",
      routeCardArchiveAndRestoreOnlyChangeSelectionVisibility
    ),
    (
      "gone closes only active Project and a correction does not reopen it",
      goneClosesOnlyActiveProjectAndCorrectionDoesNotReopenIt
    ),
    (
      "confirmed merge redirects without rewriting historical identity",
      confirmedMergeRedirectsWithoutRewritingHistoricalIdentity
    ),
    (
      "RouteCard merge rejects self merged targets and redirect chains",
      routeMergeRejectsSelfMergedTargetsAndRedirectChains
    ),
    (
      "RouteCard merge preserves conflict when both sides have active Projects",
      routeMergePreservesConflictWhenBothSidesHaveActiveProjects
    ),
    (
      "explicit unmerge restores the pre-merge visibility",
      explicitUnmergeRestoresThePreMergeVisibility
    ),
    (
      "unmerge cannot leave two active Project cycles on one RouteCard",
      unmergeCannotLeaveTwoActiveProjectCyclesOnOneRouteCard
    ),
    (
      "Attempt route correction keeps audit and reopens reviewed visit",
      attemptRouteCorrectionKeepsAuditAndReopensReviewedVisit
    ),
    (
      "out-of-order Attempt route correction waits for exact subjects",
      outOfOrderAttemptRouteCorrectionWaitsForExactSubjects
    ),
    (
      "archived Project stays terminal and rework starts a new cycle",
      archivedProjectStaysTerminalAndReworkStartsANewCycle
    ),
  ]
}
