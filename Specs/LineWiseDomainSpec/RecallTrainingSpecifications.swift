import LineWiseDomain

private enum RecallTrainingSpecificationFailure: Error {
  case expected(String)
}

private func recallExpect(
  _ condition: @autoclosure () -> Bool,
  _ message: String
) throws {
  guard condition() else {
    throw RecallTrainingSpecificationFailure.expected(message)
  }
}

private func emptyVisitSnapshot() -> VisitSnapshot {
  VisitSnapshot(
    visits: [],
    attempts: [],
    routeCards: [],
    projects: [],
    pendingActionIDs: [],
    reconciliationIssues: []
  )
}

private func visitSnapshotWithAttempt(
  outcome: AttemptOutcome,
  recordState: AttemptRecordState = .active,
  routeCardID: RouteCardID = RouteCardID("route-failure")
) -> VisitSnapshot {
  VisitSnapshot(
    visits: [],
    attempts: [
      AttemptSnapshot(
        id: AttemptID("attempt-failure"),
        visitID: GymVisitID("visit-failure"),
        routeCardID: routeCardID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        recordedBy: .watch,
        recordState: recordState,
        outcome: outcome
      )
    ],
    routeCards: [],
    projects: [],
    pendingActionIDs: [],
    reconciliationIssues: []
  )
}

private func activeProjectVisitSnapshot(
  openVisitID: GymVisitID? = nil
) -> VisitSnapshot {
  let routeID = RouteCardID("route-failure")
  let visits: [GymVisitSnapshot]
  if let openVisitID {
    visits = [
      GymVisitSnapshot(
        id: openVisitID,
        startedAt: Instant(millisecondsSince1970: 10_000),
        endedAt: nil,
        startedBy: .iPhone,
        captureState: .open,
        reviewState: .notReady
      )
    ]
  } else {
    visits = []
  }
  return VisitSnapshot(
    visits: visits,
    attempts: visitSnapshotWithAttempt(outcome: .notSent).attempts,
    routeCards: [
      RouteCardSnapshot(
        id: routeID,
        label: "Blue slab",
        recordVisibility: .active,
        availability: .present,
        mergedIntoRouteCardID: nil,
        successorRouteCardID: nil,
        createdAt: Instant(millisecondsSince1970: 100)
      )
    ],
    projects: [
      ProjectSnapshot(
        id: ProjectID("project-failure"),
        routeCardID: routeID,
        state: .active,
        startedAt: Instant(millisecondsSince1970: 200),
        closedAt: nil,
        supportingAttemptID: nil
      )
    ],
    pendingActionIDs: [],
    reconciliationIssues: []
  )
}

private func reviewInboxSupportsPendingSnoozedResolvedAndDismissed() throws {
  let visitID = GymVisitID("visit-review")
  let attemptID = AttemptID("attempt-review")
  let firstItemID = ReviewInboxItemID("inbox-first")
  var state = RecallTrainingState()

  var transition = RecallTraining.apply(
    .enqueueReviewItem(
      actionID: ActionID("enqueue-first"),
      itemID: firstItemID,
      sourceKey: "attempt:attempt-review:outcome",
      visitID: visitID,
      kind: .unresolvedAttempt(attemptID),
      occurredAt: Instant(millisecondsSince1970: 1_000)
    ),
    visitSnapshot: emptyVisitSnapshot(),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "a new inbox item should be accepted")
  state = transition.state
  try recallExpect(
    state.snapshot.reviewItems.first?.status == .pending,
    "a new inbox item should start pending"
  )

  transition = RecallTraining.apply(
    .snoozeReviewItem(
      actionID: ActionID("snooze-first"),
      itemID: firstItemID,
      until: Instant(millisecondsSince1970: 5_000),
      occurredAt: Instant(millisecondsSince1970: 2_000)
    ),
    visitSnapshot: emptyVisitSnapshot(),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "a pending item should be snoozable")
  state = transition.state
  try recallExpect(
    state.snapshot.reviewItems.first?.status == .snoozed
      && state.snapshot.reviewItems.first?.snoozedUntil
        == Instant(millisecondsSince1970: 5_000),
    "snooze should retain its due time"
  )

  transition = RecallTraining.apply(
    .resolveReviewItem(
      actionID: ActionID("resolve-first"),
      itemID: firstItemID,
      occurredAt: Instant(millisecondsSince1970: 6_000)
    ),
    visitSnapshot: emptyVisitSnapshot(),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "a snoozed item should be resolvable")
  state = transition.state
  try recallExpect(
    state.snapshot.reviewItems.first?.status == .resolved,
    "resolved should be a visible terminal state"
  )

  let dismissedItemID = ReviewInboxItemID("inbox-dismissed")
  state =
    RecallTraining.apply(
      .enqueueReviewItem(
        actionID: ActionID("enqueue-dismissed"),
        itemID: dismissedItemID,
        sourceKey: "attempt:attempt-review:route",
        visitID: visitID,
        kind: .unassignedAttempt(attemptID),
        occurredAt: Instant(millisecondsSince1970: 7_000)
      ),
      visitSnapshot: emptyVisitSnapshot(),
      to: state
    ).state
  state =
    RecallTraining.apply(
      .dismissReviewItem(
        actionID: ActionID("dismiss-item"),
        itemID: dismissedItemID,
        occurredAt: Instant(millisecondsSince1970: 8_000)
      ),
      visitSnapshot: emptyVisitSnapshot(),
      to: state
    ).state

  transition = RecallTraining.apply(
    .enqueueReviewItem(
      actionID: ActionID("recreate-dismissed"),
      itemID: ReviewInboxItemID("inbox-recreated"),
      sourceKey: "attempt:attempt-review:route",
      visitID: visitID,
      kind: .unassignedAttempt(attemptID),
      occurredAt: Instant(millisecondsSince1970: 9_000)
    ),
    visitSnapshot: emptyVisitSnapshot(),
    to: state
  )
  try recallExpect(
    transition.outcome == .rejected(.dismissedReviewSource),
    "a dismissed source must not be recreated by a background rule"
  )
}

private func confirmedFailureRequiresAnActiveNotSentAttempt() throws {
  let command = RecallTrainingCommand.confirmFailureEpisode(
    actionID: ActionID("confirm-failure"),
    episodeID: FailureEpisodeID("failure-confirmed"),
    attemptID: AttemptID("attempt-failure"),
    routeCardID: RouteCardID("route-failure"),
    primaryBlocker: .footwork,
    locationNote: "third move",
    occurredAt: Instant(millisecondsSince1970: 2_000)
  )

  var transition = RecallTraining.apply(
    command,
    visitSnapshot: visitSnapshotWithAttempt(outcome: .unresolved),
    to: RecallTrainingState()
  )
  try recallExpect(
    transition.outcome == .rejected(.confirmedFailureRequiresActiveNotSentAttempt),
    "an unresolved attempt cannot support a confirmed FailureEpisode"
  )

  transition = RecallTraining.apply(
    command,
    visitSnapshot: visitSnapshotWithAttempt(outcome: .notSent, recordState: .retracted),
    to: RecallTrainingState()
  )
  try recallExpect(
    transition.outcome == .rejected(.confirmedFailureRequiresActiveNotSentAttempt),
    "a retracted attempt cannot support a confirmed FailureEpisode"
  )

  transition = RecallTraining.apply(
    command,
    visitSnapshot: visitSnapshotWithAttempt(outcome: .notSent),
    to: RecallTrainingState()
  )
  try recallExpect(transition.outcome == .accepted, "an active not-sent attempt should qualify")
  try recallExpect(
    transition.state.snapshot.failureEpisodes.first
      == FailureEpisodeSnapshot(
        id: FailureEpisodeID("failure-confirmed"),
        attemptID: AttemptID("attempt-failure"),
        routeCardID: RouteCardID("route-failure"),
        primaryBlocker: .footwork,
        locationNote: "third move",
        status: .userConfirmed,
        suggestionProvenance: nil,
        createdAt: Instant(millisecondsSince1970: 2_000),
        updatedAt: Instant(millisecondsSince1970: 2_000)
      ),
    "the confirmed episode should preserve its attempt and route anchors"
  )
}

private func suggestedFailureStaysSuggestedUntilTheUserConfirmsIt() throws {
  let episodeID = FailureEpisodeID("failure-suggested")
  let provenance = SuggestionProvenance(
    suggestionID: "suggestion-42",
    source: .model,
    sourceReference: "route-read-7",
    sourceVersion: "model-v3",
    confidence: 0.62,
    decision: .pending
  )
  var transition = RecallTraining.apply(
    .suggestFailureEpisode(
      actionID: ActionID("suggest-failure"),
      episodeID: episodeID,
      attemptID: AttemptID("attempt-failure"),
      routeCardID: RouteCardID("route-failure"),
      primaryBlocker: .bodyPosition,
      locationNote: nil,
      provenance: provenance,
      occurredAt: Instant(millisecondsSince1970: 2_000)
    ),
    visitSnapshot: visitSnapshotWithAttempt(outcome: .unresolved),
    to: RecallTrainingState()
  )
  try recallExpect(transition.outcome == .accepted, "an unresolved attempt may carry a suggestion")
  var state = transition.state
  try recallExpect(
    state.snapshot.failureEpisodes.first?.status == .suggested
      && state.snapshot.failureEpisodes.first?.suggestionProvenance == provenance,
    "a suggestion must retain its source, version, confidence, and pending decision"
  )

  transition = RecallTraining.apply(
    .acceptFailureSuggestion(
      actionID: ActionID("accept-failure"),
      episodeID: episodeID,
      blockerOverride: .footwork,
      occurredAt: Instant(millisecondsSince1970: 3_000)
    ),
    visitSnapshot: visitSnapshotWithAttempt(outcome: .notSent),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "the user should be able to correct and accept")
  state = transition.state
  try recallExpect(
    state.snapshot.failureEpisodes.first?.status == .userConfirmed
      && state.snapshot.failureEpisodes.first?.primaryBlocker == .footwork
      && state.snapshot.failureEpisodes.first?.suggestionProvenance?.decision == .edited,
    "the user's blocker should win while the original suggestion remains traceable"
  )
}

private func acceptingAFailureSuggestionRequiresTheAttemptToStayOnTheSameRoute() throws {
  let episodeID = FailureEpisodeID("failure-route-moved")
  let suggested = RecallTraining.apply(
    .suggestFailureEpisode(
      actionID: ActionID("suggest-route-moved"),
      episodeID: episodeID,
      attemptID: AttemptID("attempt-failure"),
      routeCardID: RouteCardID("route-failure"),
      primaryBlocker: .bodyPosition,
      locationNote: nil,
      provenance: SuggestionProvenance(
        suggestionID: "suggestion-route-moved",
        source: .model,
        sourceReference: "route-read-9",
        sourceVersion: "model-v3",
        confidence: 0.5,
        decision: .pending
      ),
      occurredAt: Instant(millisecondsSince1970: 2_000)
    ),
    visitSnapshot: visitSnapshotWithAttempt(outcome: .unresolved),
    to: RecallTrainingState()
  )
  try recallExpect(
    suggested.outcome == .accepted,
    "an unresolved attempt on the suggested route may carry a suggestion"
  )

  // The user then corrects the Attempt onto a different RouteCard and confirms it Not Sent.
  // The episode is still anchored to the original route, so its only Attempt evidence now
  // lives on another route and can no longer confirm this episode.
  let afterRouteCorrection = RecallTraining.apply(
    .acceptFailureSuggestion(
      actionID: ActionID("accept-route-moved"),
      episodeID: episodeID,
      blockerOverride: nil,
      occurredAt: Instant(millisecondsSince1970: 3_000)
    ),
    visitSnapshot: visitSnapshotWithAttempt(
      outcome: .notSent,
      routeCardID: RouteCardID("route-somewhere-else")
    ),
    to: suggested.state
  )
  try recallExpect(
    afterRouteCorrection.outcome == .rejected(.attemptRouteDoesNotMatch),
    "an Attempt reassigned to another RouteCard must not confirm this episode"
  )
  try recallExpect(
    afterRouteCorrection.state.snapshot.failureEpisodes.first?.status == .suggested,
    "the episode must stay a suggestion the user can review, not become confirmed evidence"
  )

  let onOriginalRoute = RecallTraining.apply(
    .acceptFailureSuggestion(
      actionID: ActionID("accept-route-unchanged"),
      episodeID: episodeID,
      blockerOverride: nil,
      occurredAt: Instant(millisecondsSince1970: 4_000)
    ),
    visitSnapshot: visitSnapshotWithAttempt(outcome: .notSent),
    to: suggested.state
  )
  try recallExpect(
    onOriginalRoute.outcome == .accepted
      && onOriginalRoute.state.snapshot.failureEpisodes.first?.status == .userConfirmed,
    "an Attempt still on the episode RouteCard should confirm normally"
  )

  // The user can also clear an Attempt's route entirely. An Attempt with no RouteCard
  // carries no route evidence, so it must not confirm a route-anchored episode.
  let unassignedRoute = RecallTraining.apply(
    .acceptFailureSuggestion(
      actionID: ActionID("accept-route-cleared"),
      episodeID: episodeID,
      blockerOverride: nil,
      occurredAt: Instant(millisecondsSince1970: 5_000)
    ),
    visitSnapshot: VisitSnapshot(
      visits: [],
      attempts: [
        AttemptSnapshot(
          id: AttemptID("attempt-failure"),
          visitID: GymVisitID("visit-failure"),
          routeCardID: nil,
          occurredAt: Instant(millisecondsSince1970: 1_000),
          recordedBy: .watch,
          recordState: .active,
          outcome: .notSent
        )
      ],
      routeCards: [],
      projects: [],
      pendingActionIDs: [],
      reconciliationIssues: []
    ),
    to: suggested.state
  )
  try recallExpect(
    unassignedRoute.outcome == .rejected(.attemptRouteDoesNotMatch),
    "an Attempt with no RouteCard must not confirm a route-anchored episode"
  )

  // A RouteCard merge is not a route change: an Attempt now filed under the canonical
  // successor is still the same physical route and remains valid confirmation.
  let afterMerge = RecallTraining.apply(
    .acceptFailureSuggestion(
      actionID: ActionID("accept-after-merge"),
      episodeID: episodeID,
      blockerOverride: nil,
      occurredAt: Instant(millisecondsSince1970: 6_000)
    ),
    visitSnapshot: VisitSnapshot(
      visits: [],
      attempts: visitSnapshotWithAttempt(
        outcome: .notSent,
        routeCardID: RouteCardID("route-canonical")
      ).attempts,
      routeCards: [
        RouteCardSnapshot(
          id: RouteCardID("route-failure"),
          label: "Blue slab",
          recordVisibility: .merged,
          availability: .present,
          mergedIntoRouteCardID: RouteCardID("route-canonical"),
          successorRouteCardID: nil,
          createdAt: Instant(millisecondsSince1970: 100)
        ),
        RouteCardSnapshot(
          id: RouteCardID("route-canonical"),
          label: "Blue slab (canonical)",
          recordVisibility: .active,
          availability: .present,
          mergedIntoRouteCardID: nil,
          successorRouteCardID: nil,
          createdAt: Instant(millisecondsSince1970: 90)
        ),
      ],
      projects: [],
      pendingActionIDs: [],
      reconciliationIssues: []
    ),
    to: suggested.state
  )
  try recallExpect(
    afterMerge.outcome == .accepted,
    "a RouteCard merge must not block confirmation of evidence on the canonical route"
  )
}

private func moveCueBecomesANextSessionCueAndReopensAtTheNextVisit() throws {
  let failureID = FailureEpisodeID("failure-chain")
  let moveCueID = MoveCueID("move-cue-chain")
  let nextCueID = NextSessionCueID("next-cue-chain")
  let projectID = ProjectID("project-failure")
  var state = RecallTraining.apply(
    .confirmFailureEpisode(
      actionID: ActionID("confirm-chain-failure"),
      episodeID: failureID,
      attemptID: AttemptID("attempt-failure"),
      routeCardID: RouteCardID("route-failure"),
      primaryBlocker: .footwork,
      locationNote: "third move",
      occurredAt: Instant(millisecondsSince1970: 2_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(),
    to: RecallTrainingState()
  ).state

  var transition = RecallTraining.apply(
    .createMoveCue(
      actionID: ActionID("create-move-cue"),
      moveCueID: moveCueID,
      failureEpisodeID: failureID,
      text: "Left foot high before right hand.",
      occurredAt: Instant(millisecondsSince1970: 3_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "a confirmed failure should accept a MoveCue")
  state = transition.state

  transition = RecallTraining.apply(
    .createNextSessionCue(
      actionID: ActionID("create-next-cue"),
      cueID: nextCueID,
      projectID: projectID,
      failureEpisodeID: failureID,
      moveCueID: moveCueID,
      nextAction: "Try the high foot before pulling.",
      occurredAt: Instant(millisecondsSince1970: 4_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "an active project should accept a recall cue")
  state = transition.state

  state =
    RecallTraining.apply(
      .completeNextSessionCue(
        actionID: ActionID("complete-next-cue"),
        cueID: nextCueID,
        occurredAt: Instant(millisecondsSince1970: 5_000)
      ),
      visitSnapshot: activeProjectVisitSnapshot(),
      to: state
    ).state
  try recallExpect(
    state.snapshot.nextSessionCues.first?.status == .completed,
    "completion should remain visible until a later reopen"
  )

  let nextVisitID = GymVisitID("visit-next")
  transition = RecallTraining.apply(
    .reopenNextSessionCue(
      actionID: ActionID("reopen-next-cue"),
      cueID: nextCueID,
      visitID: nextVisitID,
      occurredAt: Instant(millisecondsSince1970: 11_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(openVisitID: nextVisitID),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "a cue should reopen in a later active visit")
  try recallExpect(
    transition.state.snapshot.nextSessionCues.first?.status == .ready
      && transition.state.snapshot.nextSessionCues.first?.reopenedInVisitID == nextVisitID,
    "reopen should record the visit where the user sees the cue again"
  )
}

private func aDismissedCueOnlyReturnsThroughAnExplicitReopen() throws {
  let projectID = ProjectID("project-failure")
  let failureID = FailureEpisodeID("failure-cue-decision")
  let moveCueID = MoveCueID("move-cue-decision")
  let cueID = NextSessionCueID("next-cue-decision")
  var state =
    RecallTraining.apply(
      .confirmFailureEpisode(
        actionID: ActionID("confirm-cue-decision-failure"),
        episodeID: failureID,
        attemptID: AttemptID("attempt-failure"),
        routeCardID: RouteCardID("route-failure"),
        primaryBlocker: .footwork,
        locationNote: nil,
        occurredAt: Instant(millisecondsSince1970: 2_000)
      ),
      visitSnapshot: activeProjectVisitSnapshot(),
      to: RecallTrainingState()
    ).state
  state =
    RecallTraining.apply(
      .createMoveCue(
        actionID: ActionID("create-cue-decision-move-cue"),
        moveCueID: moveCueID,
        failureEpisodeID: failureID,
        text: "Left foot high before right hand.",
        occurredAt: Instant(millisecondsSince1970: 3_000)
      ),
      visitSnapshot: activeProjectVisitSnapshot(),
      to: state
    ).state
  state =
    RecallTraining.apply(
      .createNextSessionCue(
        actionID: ActionID("create-cue-decision-next-cue"),
        cueID: cueID,
        projectID: projectID,
        failureEpisodeID: failureID,
        moveCueID: moveCueID,
        nextAction: "Try the high foot before pulling.",
        occurredAt: Instant(millisecondsSince1970: 4_000)
      ),
      visitSnapshot: activeProjectVisitSnapshot(),
      to: state
    ).state

  let dismissal = RecallTraining.apply(
    .dismissNextSessionCue(
      actionID: ActionID("dismiss-cue-decision"),
      cueID: cueID,
      occurredAt: Instant(millisecondsSince1970: 5_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(),
    to: state
  )
  try recallExpect(dismissal.outcome == .accepted, "the user should be able to ignore a cue")
  state = dismissal.state

  let laterCompletion = RecallTraining.apply(
    .completeNextSessionCue(
      actionID: ActionID("complete-after-dismiss-cue-decision"),
      cueID: cueID,
      occurredAt: Instant(millisecondsSince1970: 6_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(),
    to: state
  )
  try recallExpect(
    laterCompletion.outcome == .rejected(.nextSessionCueIsClosed)
      && laterCompletion.state.snapshot.nextSessionCues.first?.status == .dismissed,
    "an ignored cue must not be reclassified as practiced"
  )

  let laterDeferral = RecallTraining.apply(
    .deferNextSessionCue(
      actionID: ActionID("defer-after-dismiss-cue-decision"),
      cueID: cueID,
      until: Instant(millisecondsSince1970: 9_000),
      occurredAt: Instant(millisecondsSince1970: 6_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(),
    to: state
  )
  try recallExpect(
    laterDeferral.outcome == .rejected(.nextSessionCueIsClosed),
    "an ignored cue must not slip back into the deferred queue"
  )

  // The one legitimate way back is an explicit reopen tied to a later open Visit, which
  // records where the user saw the cue again.
  let nextVisitID = GymVisitID("visit-cue-decision-next")
  let reopened = RecallTraining.apply(
    .reopenNextSessionCue(
      actionID: ActionID("reopen-cue-decision"),
      cueID: cueID,
      visitID: nextVisitID,
      occurredAt: Instant(millisecondsSince1970: 11_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(openVisitID: nextVisitID),
    to: state
  )
  try recallExpect(
    reopened.outcome == .accepted
      && reopened.state.snapshot.nextSessionCues.first?.status == .ready
      && reopened.state.snapshot.nextSessionCues.first?.reopenedInVisitID == nextVisitID,
    "an explicit reopen in a later Visit should make the cue actionable again"
  )

  let completion = RecallTraining.apply(
    .completeNextSessionCue(
      actionID: ActionID("complete-reopened-cue-decision"),
      cueID: cueID,
      occurredAt: Instant(millisecondsSince1970: 12_000)
    ),
    visitSnapshot: activeProjectVisitSnapshot(openVisitID: nextVisitID),
    to: reopened.state
  )
  try recallExpect(
    completion.outcome == .accepted
      && completion.state.snapshot.nextSessionCues.first?.status == .completed,
    "a reopened cue should accept a fresh decision"
  )
}

private func setterLensSuggestionPreservesEvidenceAndUserCorrection() throws {
  let readingID = SetterLensReadingID("setter-reading")
  let provenance = SuggestionProvenance(
    suggestionID: "setter-suggestion",
    source: .model,
    sourceReference: "bounded-evidence-bundle-1",
    sourceVersion: "lens-v1",
    confidence: 0.55,
    decision: .pending
  )
  var transition = LearningLoop.apply(
    .suggestSetterLensReading(
      actionID: ActionID("suggest-setter-reading"),
      readingID: readingID,
      routeCardID: RouteCardID("route-learning"),
      evidence: [
        SetterLensEvidence(
          id: "evidence-user-report",
          kind: .userReport,
          version: "1",
          summary: "User reports cutting feet on the third move."
        )
      ],
      interpretation: "The move may reward earlier hip rotation.",
      alternativeInterpretation: "The hand sequence may instead be the limiting constraint.",
      provenance: provenance,
      occurredAt: Instant(millisecondsSince1970: 1_000)
    ),
    visitSnapshot: emptyVisitSnapshot(),
    recallSnapshot: RecallTrainingState().snapshot,
    catalog: ApprovedMicroDrillCatalog(drills: []),
    to: LearningLoopState()
  )
  try recallExpect(transition.outcome == .accepted, "bounded evidence should yield a suggestion")
  var state = transition.state
  try recallExpect(
    state.snapshot.setterLensReadings.first?.status == .suggested
      && state.snapshot.setterLensReadings.first?.evidence.first?.kind == .userReport,
    "evidence and inference should remain separate and visible"
  )

  transition = LearningLoop.apply(
    .acceptSetterLensReading(
      actionID: ActionID("accept-setter-reading"),
      readingID: readingID,
      interpretationOverride: "Rotate the hip before initiating the reach.",
      occurredAt: Instant(millisecondsSince1970: 2_000)
    ),
    visitSnapshot: emptyVisitSnapshot(),
    recallSnapshot: RecallTrainingState().snapshot,
    catalog: ApprovedMicroDrillCatalog(drills: []),
    to: state
  )
  try recallExpect(transition.outcome == .accepted, "the user should be able to correct a reading")
  state = transition.state
  try recallExpect(
    state.snapshot.setterLensReadings.first?.status == .userConfirmed
      && state.snapshot.setterLensReadings.first?.interpretation
        == "Rotate the hip before initiating the reach."
      && state.snapshot.setterLensReadings.first?.originallySuggestedInterpretation
        == "The move may reward earlier hip rotation."
      && state.snapshot.setterLensReadings.first?.suggestionProvenance.decision == .edited,
    "user correction should win without erasing the suggestion"
  )
}

private func learningRecallSnapshot(
  failureStatus: FailureEpisodeStatus = .userConfirmed
) -> RecallTrainingSnapshot {
  let routeID = RouteCardID("route-learning")
  let failureID = FailureEpisodeID("failure-learning")
  let moveCueID = MoveCueID("move-learning")
  return RecallTrainingSnapshot(
    reviewItems: [],
    failureEpisodes: [
      FailureEpisodeSnapshot(
        id: failureID,
        attemptID: AttemptID("attempt-learning"),
        routeCardID: routeID,
        primaryBlocker: .bodyPosition,
        locationNote: "third move",
        status: failureStatus,
        suggestionProvenance: failureStatus == .suggested
          ? SuggestionProvenance(
            suggestionID: "unconfirmed-trigger",
            source: .model,
            sourceReference: "route-read",
            sourceVersion: "v1",
            confidence: 0.7,
            decision: .pending
          ) : nil,
        createdAt: Instant(millisecondsSince1970: 1_000),
        updatedAt: Instant(millisecondsSince1970: 1_000)
      )
    ],
    moveCues: [
      MoveCueSnapshot(
        id: moveCueID,
        failureEpisodeID: failureID,
        routeCardID: routeID,
        text: "Rotate the hip before reaching.",
        status: .userAuthored,
        suggestionProvenance: nil,
        createdAt: Instant(millisecondsSince1970: 2_000),
        updatedAt: Instant(millisecondsSince1970: 2_000)
      )
    ],
    nextSessionCues: [
      NextSessionCueSnapshot(
        id: NextSessionCueID("next-learning"),
        projectID: ProjectID("project-learning"),
        routeCardID: routeID,
        failureEpisodeID: failureID,
        moveCueID: moveCueID,
        nextAction: "Try the cue on the third move.",
        status: .ready,
        deferredUntil: nil,
        reopenedInVisitID: nil,
        createdAt: Instant(millisecondsSince1970: 3_000),
        updatedAt: Instant(millisecondsSince1970: 3_000)
      )
    ]
  )
}

private func approvedDrillCatalog() -> ApprovedMicroDrillCatalog {
  ApprovedMicroDrillCatalog(
    drills: [
      MicroDrill(
        id: MicroDrillID("drill-hip-rotation"),
        title: "Quiet-foot hip rotation",
        target: "Hip rotation before the hand move",
        routeContext: "Two easy moves with stable feet",
        instructions: "Pause, rotate the hip, then reach without moving the supporting foot.",
        successCriterion: "The supporting foot stays in place during the reach.",
        source: .lineWiseEditorial,
        sourceReference: "catalog/hip-rotation",
        version: "1",
        approvalState: .approved
      )
    ]
  )
}

/// Capture evidence a TrainingPath on `route-learning` can be proven against: one later
/// Attempt on the same route, one Attempt on a different route, and one retracted Attempt.
private func learningVisitSnapshot(
  laterAttemptRouteCardID: RouteCardID = RouteCardID("route-learning"),
  laterAttemptRecordState: AttemptRecordState = .active,
  laterAttemptOccurredAt: Instant = Instant(millisecondsSince1970: 5_500),
  routeCards: [RouteCardSnapshot] = [
    RouteCardSnapshot(
      id: RouteCardID("route-learning"),
      label: "Learning route",
      recordVisibility: .active,
      availability: .present,
      mergedIntoRouteCardID: nil,
      successorRouteCardID: nil,
      createdAt: Instant(millisecondsSince1970: 100)
    ),
    RouteCardSnapshot(
      id: RouteCardID("route-other"),
      label: "Other route",
      recordVisibility: .active,
      availability: .present,
      mergedIntoRouteCardID: nil,
      successorRouteCardID: nil,
      createdAt: Instant(millisecondsSince1970: 110)
    ),
  ]
) -> VisitSnapshot {
  VisitSnapshot(
    visits: [],
    attempts: [
      AttemptSnapshot(
        id: AttemptID("attempt-learning"),
        visitID: GymVisitID("visit-learning"),
        routeCardID: RouteCardID("route-learning"),
        occurredAt: Instant(millisecondsSince1970: 900),
        recordedBy: .iPhone,
        recordState: .active,
        outcome: .notSent
      ),
      AttemptSnapshot(
        id: AttemptID("attempt-learning-later"),
        visitID: GymVisitID("visit-learning-next"),
        routeCardID: laterAttemptRouteCardID,
        occurredAt: laterAttemptOccurredAt,
        recordedBy: .iPhone,
        recordState: laterAttemptRecordState,
        outcome: .unresolved
      ),
    ],
    routeCards: routeCards,
    projects: [],
    pendingActionIDs: [],
    reconciliationIssues: []
  )
}

private func activeLearningPath(
  pathID: TrainingPathID,
  visitSnapshot: VisitSnapshot
) throws -> LearningLoopState {
  let draft = LearningLoop.apply(
    .draftTrainingPath(
      actionID: ActionID("draft-\(pathID.rawValue)"),
      pathID: pathID,
      failureEpisodeID: FailureEpisodeID("failure-learning"),
      moveCueID: MoveCueID("move-learning"),
      microDrillID: MicroDrillID("drill-hip-rotation"),
      nextSessionCueID: NextSessionCueID("next-learning"),
      proofQuestion: "Did the supporting foot stay in place?",
      occurredAt: Instant(millisecondsSince1970: 4_000)
    ),
    visitSnapshot: visitSnapshot,
    recallSnapshot: learningRecallSnapshot(),
    catalog: approvedDrillCatalog(),
    to: LearningLoopState()
  )
  try recallExpect(draft.outcome == .accepted, "expected a draft from the confirmed recall chain")
  let activated = LearningLoop.apply(
    .activateTrainingPath(
      actionID: ActionID("activate-\(pathID.rawValue)"),
      pathID: pathID,
      occurredAt: Instant(millisecondsSince1970: 5_000)
    ),
    visitSnapshot: visitSnapshot,
    recallSnapshot: learningRecallSnapshot(),
    catalog: approvedDrillCatalog(),
    to: draft.state
  )
  try recallExpect(activated.outcome == .accepted, "expected the user to activate the draft")
  return activated.state
}

private func proofCheckRequiresALaterRouteMatchedAttempt() throws {
  func recordProof(
    _ label: String,
    attemptID: AttemptID,
    visitSnapshot: VisitSnapshot
  ) throws -> LearningLoopTransition {
    let pathID = TrainingPathID("path-proof-\(label)")
    let state = try activeLearningPath(pathID: pathID, visitSnapshot: visitSnapshot)
    return LearningLoop.apply(
      .recordProofCheck(
        actionID: ActionID("proof-\(label)"),
        proofCheckID: ProofCheckID("proof-check-\(label)"),
        pathID: pathID,
        attemptID: attemptID,
        outcome: .triedTargetBehaviorChanged,
        decision: .retain,
        note: nil,
        occurredAt: Instant(millisecondsSince1970: 6_000)
      ),
      visitSnapshot: visitSnapshot,
      recallSnapshot: learningRecallSnapshot(),
      catalog: approvedDrillCatalog(),
      to: state
    )
  }

  let fabricated = try recordProof(
    "fabricated",
    attemptID: AttemptID("attempt-that-was-never-recorded"),
    visitSnapshot: learningVisitSnapshot()
  )
  try recallExpect(
    fabricated.outcome == .rejected(.proofCheckAttemptDoesNotExist),
    "a ProofCheck must not bind to an Attempt that was never captured"
  )
  try recallExpect(
    fabricated.state.snapshot.proofChecks.isEmpty
      && fabricated.state.snapshot.trainingPaths.first?.status == .active,
    "a rejected ProofCheck must leave the path active and unproven"
  )

  let retracted = try recordProof(
    "retracted",
    attemptID: AttemptID("attempt-learning-later"),
    visitSnapshot: learningVisitSnapshot(laterAttemptRecordState: .retracted)
  )
  try recallExpect(
    retracted.outcome == .rejected(.proofCheckAttemptDoesNotExist),
    "a retracted Attempt must not prove a TrainingPath"
  )

  let otherRoute = try recordProof(
    "other-route",
    attemptID: AttemptID("attempt-learning-later"),
    visitSnapshot: learningVisitSnapshot(
      laterAttemptRouteCardID: RouteCardID("route-other")
    )
  )
  try recallExpect(
    otherRoute.outcome == .rejected(.proofCheckAttemptRouteMismatch),
    "evidence from another RouteCard must not prove this path"
  )

  let unassignedRoute = try recordProof(
    "unassigned-route",
    attemptID: AttemptID("attempt-learning-later"),
    visitSnapshot: VisitSnapshot(
      visits: [],
      attempts: learningVisitSnapshot().attempts.map { attempt in
        attempt.id == AttemptID("attempt-learning-later")
          ? AttemptSnapshot(
            id: attempt.id,
            visitID: attempt.visitID,
            routeCardID: nil,
            occurredAt: attempt.occurredAt,
            recordedBy: attempt.recordedBy,
            recordState: attempt.recordState,
            outcome: attempt.outcome
          ) : attempt
      },
      routeCards: learningVisitSnapshot().routeCards,
      projects: [],
      pendingActionIDs: [],
      reconciliationIssues: []
    )
  )
  try recallExpect(
    unassignedRoute.outcome == .rejected(.proofCheckAttemptRouteMismatch),
    "an Attempt with no RouteCard yet must not prove a route-anchored path"
  )

  let earlierAttempt = try recordProof(
    "earlier",
    attemptID: AttemptID("attempt-learning"),
    visitSnapshot: learningVisitSnapshot()
  )
  try recallExpect(
    earlierAttempt.outcome == .rejected(.proofCheckAttemptIsNotLaterThanPath),
    "the Attempt that produced the failure must not double as its own proof"
  )

  let accepted = try recordProof(
    "accepted",
    attemptID: AttemptID("attempt-learning-later"),
    visitSnapshot: learningVisitSnapshot()
  )
  try recallExpect(
    accepted.outcome == .accepted
      && accepted.state.snapshot.proofChecks.first?.attemptID
        == AttemptID("attempt-learning-later")
      && accepted.state.snapshot.trainingPaths.first?.status == .retained,
    "a later Attempt on the path RouteCard should support a retained ProofCheck"
  )

  // A RouteCard merge folds the path's route into a canonical successor. The Attempt the
  // user recorded against that successor is still the same physical route, so it must
  // remain valid proof rather than reading as cross-route evidence.
  let mergedRoutes = [
    RouteCardSnapshot(
      id: RouteCardID("route-learning"),
      label: "Learning route",
      recordVisibility: .merged,
      availability: .present,
      mergedIntoRouteCardID: RouteCardID("route-canonical"),
      successorRouteCardID: nil,
      createdAt: Instant(millisecondsSince1970: 100)
    ),
    RouteCardSnapshot(
      id: RouteCardID("route-canonical"),
      label: "Canonical learning route",
      recordVisibility: .active,
      availability: .present,
      mergedIntoRouteCardID: nil,
      successorRouteCardID: nil,
      createdAt: Instant(millisecondsSince1970: 90)
    ),
  ]
  let afterMerge = try recordProof(
    "after-merge",
    attemptID: AttemptID("attempt-learning-later"),
    visitSnapshot: learningVisitSnapshot(
      laterAttemptRouteCardID: RouteCardID("route-canonical"),
      routeCards: mergedRoutes
    )
  )
  try recallExpect(
    afterMerge.outcome == .accepted,
    "a RouteCard merge must not invalidate proof recorded on the canonical route"
  )
}

private func trainingPathRequiresConfirmedTriggerAndProofCanRetainReviseOrReject() throws {
  let draftWithSuggestedTrigger = LearningLoop.apply(
    .draftTrainingPath(
      actionID: ActionID("draft-unconfirmed"),
      pathID: TrainingPathID("path-unconfirmed"),
      failureEpisodeID: FailureEpisodeID("failure-learning"),
      moveCueID: MoveCueID("move-learning"),
      microDrillID: MicroDrillID("drill-hip-rotation"),
      nextSessionCueID: NextSessionCueID("next-learning"),
      proofQuestion: "Did the supporting foot stay in place?",
      occurredAt: Instant(millisecondsSince1970: 4_000)
    ),
    visitSnapshot: emptyVisitSnapshot(),
    recallSnapshot: learningRecallSnapshot(failureStatus: .suggested),
    catalog: approvedDrillCatalog(),
    to: LearningLoopState()
  )
  try recallExpect(
    draftWithSuggestedTrigger.outcome == .rejected(.trainingPathRequiresConfirmedFailure),
    "a suggested blocker must not become a training fact"
  )

  let decisions: [(ProofDecision, TrainingPathStatus)] = [
    (.retain, .retained),
    (.revise, .revisionRequested),
    (.reject, .rejected),
  ]
  for (index, decisionAndStatus) in decisions.enumerated() {
    let pathID = TrainingPathID("path-\(index)")
    let state = try activeLearningPath(pathID: pathID, visitSnapshot: learningVisitSnapshot())
    let transition = LearningLoop.apply(
      .recordProofCheck(
        actionID: ActionID("proof-path-\(index)"),
        proofCheckID: ProofCheckID("proof-\(index)"),
        pathID: pathID,
        attemptID: AttemptID("attempt-learning-later"),
        outcome: .triedTargetBehaviorChanged,
        decision: decisionAndStatus.0,
        note: "Observed by the user on the next visit.",
        occurredAt: Instant(millisecondsSince1970: 6_000)
      ),
      visitSnapshot: learningVisitSnapshot(),
      recallSnapshot: learningRecallSnapshot(),
      catalog: approvedDrillCatalog(),
      to: state
    )
    try recallExpect(transition.outcome == .accepted, "ProofCheck should record a user decision")
    try recallExpect(
      transition.state.snapshot.trainingPaths.first?.status == decisionAndStatus.1
        && transition.state.snapshot.proofChecks.first?.decision == decisionAndStatus.0,
      "retain, revise, and reject must remain distinct path outcomes"
    )
  }
}

private func subjectivePhysiologyIsPrimaryAndHealthKitIsOptionalContext() throws {
  let subjective = SubjectivePhysiologyCheckIn(
    sessionEffort1To10: 7,
    wholeBodyFatigue0To10: 8,
    forearmPumpOverall: .strong
  )
  let healthKit = HealthKitWorkoutSummary(
    durationSeconds: 5_400,
    averageHeartRateBPM: 132,
    maximumHeartRateBPM: 174,
    heartRateCoverage: 0.76,
    activeEnergyKilocalories: 410,
    workoutEffortScore: 6,
    workoutEffortSource: .perceived,
    sourceVersion: "healthkit-query-v1"
  )

  let result = PhysiologyContextService.build(
    contextID: PhysiologyContextID("physiology-1"),
    visitID: GymVisitID("visit-physiology"),
    subjective: subjective,
    healthKitSummary: healthKit,
    recordedAt: Instant(millisecondsSince1970: 2_000)
  )
  guard case .built(let context) = result else {
    throw RecallTrainingSpecificationFailure.expected("valid context should build")
  }
  try recallExpect(
    context.primarySource == .subjectiveReport
      && context.reportedWholeBodyFatigue0To10 == 8
      && context.reportedForearmPumpOverall == .strong,
    "fatigue and pump must remain explicitly user-reported primary inputs"
  )
  try recallExpect(
    context.healthKitRole == .optionalSupportingContext
      && context.healthKitSummary == healthKit
      && context.claimBoundary == .contextOnlyNonDiagnostic,
    "HealthKit must remain supporting context with a non-diagnostic boundary"
  )

  let subjectiveOnly = PhysiologyContextService.build(
    contextID: PhysiologyContextID("physiology-2"),
    visitID: GymVisitID("visit-subjective-only"),
    subjective: subjective,
    healthKitSummary: nil,
    recordedAt: Instant(millisecondsSince1970: 3_000)
  )
  try recallExpect(
    subjectiveOnly.isBuilt,
    "HealthKit denial or absence must not block subjective context"
  )

  let healthKitOnly = PhysiologyContextService.build(
    contextID: PhysiologyContextID("physiology-3"),
    visitID: GymVisitID("visit-healthkit-only"),
    subjective: nil,
    healthKitSummary: healthKit,
    recordedAt: Instant(millisecondsSince1970: 4_000)
  )
  guard case .built(let supportingOnly) = healthKitOnly else {
    throw RecallTrainingSpecificationFailure.expected(
      "HealthKit summary should remain usable context")
  }
  try recallExpect(
    supportingOnly.primarySource == .none
      && supportingOnly.reportedWholeBodyFatigue0To10 == nil
      && supportingOnly.reportedForearmPumpOverall == nil,
    "HealthKit alone must not manufacture fatigue, pump, or muscle judgments"
  )

  let invalid = PhysiologyContextService.build(
    contextID: PhysiologyContextID("physiology-invalid"),
    visitID: GymVisitID("visit-invalid"),
    subjective: SubjectivePhysiologyCheckIn(
      sessionEffort1To10: 11,
      wholeBodyFatigue0To10: 8,
      forearmPumpOverall: .strong
    ),
    healthKitSummary: nil,
    recordedAt: Instant(millisecondsSince1970: 5_000)
  )
  try recallExpect(
    invalid == .rejected(.sessionEffortOutOfRange),
    "invalid subjective scales should be rejected instead of normalized silently"
  )
}

func recallTrainingSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "review inbox supports pending, snoozed, resolved, and dismissed",
      reviewInboxSupportsPendingSnoozedResolvedAndDismissed
    ),
    (
      "confirmed FailureEpisode requires an active not-sent Attempt",
      confirmedFailureRequiresAnActiveNotSentAttempt
    ),
    (
      "suggested FailureEpisode remains suggested until user confirmation",
      suggestedFailureStaysSuggestedUntilTheUserConfirmsIt
    ),
    (
      "accepting a failure suggestion requires the Attempt to stay on the same route",
      acceptingAFailureSuggestionRequiresTheAttemptToStayOnTheSameRoute
    ),
    (
      "MoveCue becomes a NextSessionCue and reopens at the next visit",
      moveCueBecomesANextSessionCueAndReopensAtTheNextVisit
    ),
    (
      "a dismissed NextSessionCue only returns through an explicit reopen",
      aDismissedCueOnlyReturnsThroughAnExplicitReopen
    ),
    (
      "SetterLens preserves evidence and user correction",
      setterLensSuggestionPreservesEvidenceAndUserCorrection
    ),
    (
      "TrainingPath uses confirmed triggers and ProofCheck retain revise reject",
      trainingPathRequiresConfirmedTriggerAndProofCanRetainReviseOrReject
    ),
    (
      "ProofCheck requires a later route-matched Attempt",
      proofCheckRequiresALaterRouteMatchedAttempt
    ),
    (
      "subjective physiology is primary and HealthKit is optional context",
      subjectivePhysiologyIsPrimaryAndHealthKitIsOptionalContext
    ),
  ]
}
