import Foundation
import LineWiseApplication
import LineWiseDomain

func learningExperienceSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "editorial MicroDrill catalog is projected and persisted",
      editorialCatalogIsProjectedAndPersisted
    ),
    (
      "SetterLens suggestions require explicit durable decisions",
      setterLensSuggestionsRequireExplicitDurableDecisions
    ),
    (
      "ProofChecks require a real route-matched Attempt and persist completion",
      proofChecksRequireARealRouteMatchedAttemptAndPersistCompletion
    ),
    (
      "learning persistence failure does not leak suggested state",
      persistenceFailureDoesNotLeakSuggestedLearningState
    ),
  ]
}

private func editorialCatalogIsProjectedAndPersisted() throws {
  let store = MemoryExperienceArchiveStore()
  var experience = try PersistentLineWiseExperienceCoordinator(
    store: store,
    microDrillCatalog: .lineWiseEditorialV0
  )

  try learningExperienceExpect(
    experience.projection.approvedMicroDrills.map(\.sourceReference) == [
      "LineWise editorial v0 · movement practice only · not medical or safety guidance"
    ],
    "the public projection should expose only the approved editorial v0 catalog"
  )

  _ = try experience.handle(
    .createRoute(
      actionID: ActionID("catalog-persist-route-action"),
      routeCardID: RouteCardID("catalog-persist-route"),
      label: "Catalog persistence trigger",
      availability: .present,
      occurredAt: learningInstant(1),
      source: .iPhone
    )
  )
  let reopened = try PersistentLineWiseExperienceCoordinator(store: store)
  try learningExperienceExpect(
    reopened.projection.approvedMicroDrills.map(\.id)
      == experience.projection.approvedMicroDrills.map(\.id),
    "the injected catalog should reopen from the same atomic experience archive"
  )

  let legacyEmptyStore = MemoryExperienceArchiveStore(
    archive: LineWiseExperienceArchive(
      microDrillCatalog: ApprovedMicroDrillCatalog(drills: [])
    )
  )
  let upgraded = try PersistentLineWiseExperienceCoordinator(
    store: legacyEmptyStore,
    microDrillCatalog: .lineWiseEditorialV0
  )
  try learningExperienceExpect(
    upgraded.projection.approvedMicroDrills.map(\.id)
      == ApprovedMicroDrillCatalog.lineWiseEditorialV0.approvedDrills.map(\.id),
    "an explicit app bootstrap catalog should not be discarded by an older empty archive"
  )
}

private func setterLensSuggestionsRequireExplicitDurableDecisions() throws {
  let store = MemoryExperienceArchiveStore()
  var experience = try PersistentLineWiseExperienceCoordinator(store: store)
  let evidence = [
    SetterLensEvidence(
      id: "route_scene:setter-lens-scene",
      kind: .routePhoto,
      version: "scene-v1",
      summary: "Pinned editable RouteScene evidence."
    )
  ]
  let pendingProvenance = SuggestionProvenance(
    suggestionID: "setter-lens-suggestion",
    source: .deterministicTemplate,
    sourceReference: "local-qualitative-provider:route-setter-lens",
    sourceVersion: "x0",
    confidence: 0.64,
    decision: .pending
  )
  let acceptedID = SetterLensReadingID("setter-lens-accepted")
  let suggestionOutcome = try trySubmitLearning(
    .suggestSetterLensReading(
      actionID: ActionID("setter-lens-suggest-accepted"),
      readingID: acceptedID,
      routeCardID: RouteCardID("route-setter-lens"),
      evidence: evidence,
      interpretation: "Candidate balance sequence under foot-placement constraint.",
      alternativeInterpretation: "Alternative hip-led sequence.",
      provenance: pendingProvenance,
      occurredAt: learningInstant(2)
    ),
    to: &experience
  )
  try learningExperienceExpect(
    suggestionOutcome == .accepted,
    "expected a valid SetterLens suggestion"
  )
  try learningExperienceExpect(
    experience.projection.learning.setterLensReadings.first?.status == .suggested
      && experience.projection.learning.setterLensReadings.first?.suggestionProvenance.decision
        == .pending,
    "saving an analysis must remain pending until the user acts"
  )

  var reopened = try PersistentLineWiseExperienceCoordinator(store: store)
  let editOutcome = try trySubmitLearning(
    .acceptSetterLensReading(
      actionID: ActionID("setter-lens-edit-accept"),
      readingID: acceptedID,
      interpretationOverride: "My reading: place the right foot first, then stand.",
      occurredAt: learningInstant(3)
    ),
    to: &reopened
  )
  try learningExperienceExpect(
    editOutcome == .accepted,
    "expected an explicit edited acceptance"
  )
  let edited = try learningRequire(
    reopened.projection.learning.setterLensReadings.first,
    "expected the edited SetterLens reading"
  )
  try learningExperienceExpect(
    edited.status == .userConfirmed && edited.suggestionProvenance.decision == .edited
      && edited.interpretation == "My reading: place the right foot first, then stand."
      && edited.originallySuggestedInterpretation
        == "Candidate balance sequence under foot-placement constraint.",
    "edited acceptance should preserve both the suggestion and user correction"
  )

  let rejectedID = SetterLensReadingID("setter-lens-rejected")
  let secondSuggestionOutcome = try trySubmitLearning(
    .suggestSetterLensReading(
      actionID: ActionID("setter-lens-suggest-rejected"),
      readingID: rejectedID,
      routeCardID: RouteCardID("route-setter-lens"),
      evidence: evidence,
      interpretation: "Candidate dynamic sequence.",
      alternativeInterpretation: nil,
      provenance: SuggestionProvenance(
        suggestionID: "setter-lens-rejected-suggestion",
        source: .deterministicTemplate,
        sourceReference: "local-qualitative-provider:route-setter-lens",
        sourceVersion: "x0",
        confidence: 0.51,
        decision: .pending
      ),
      occurredAt: learningInstant(4)
    ),
    to: &reopened
  )
  try learningExperienceExpect(
    secondSuggestionOutcome == .accepted,
    "expected a second pending suggestion"
  )
  let rejectionOutcome = try trySubmitLearning(
    .rejectSetterLensReading(
      actionID: ActionID("setter-lens-reject"),
      readingID: rejectedID,
      occurredAt: learningInstant(5)
    ),
    to: &reopened
  )
  try learningExperienceExpect(
    rejectionOutcome == .accepted,
    "expected an explicit rejection"
  )
  let final = try PersistentLineWiseExperienceCoordinator(store: store)
  try learningExperienceExpect(
    final.projection.learning.setterLensReadings.first(where: { $0.id == acceptedID })?.status
      == .userConfirmed
      && final.projection.learning.setterLensReadings.first(where: { $0.id == rejectedID })?.status
        == .rejected,
    "both explicit decisions should reopen durably"
  )
}

private func proofChecksRequireARealRouteMatchedAttemptAndPersistCompletion() throws {
  let store = MemoryExperienceArchiveStore()
  var experience = try PersistentLineWiseExperienceCoordinator(
    store: store,
    microDrillCatalog: .lineWiseEditorialV0
  )
  let routeID = RouteCardID("learning-route")
  let otherRouteID = RouteCardID("learning-other-route")
  let projectID = ProjectID("learning-project")
  let visitID = GymVisitID("learning-visit")
  let attemptID = AttemptID("learning-attempt")
  let otherAttemptID = AttemptID("learning-other-attempt")
  try applyLearningCapture(
    [
      .createRoute(
        actionID: ActionID("learning-create-route"),
        routeCardID: routeID,
        label: "Learning route",
        availability: .present,
        occurredAt: learningInstant(10),
        source: .iPhone
      ),
      .createRoute(
        actionID: ActionID("learning-create-other-route"),
        routeCardID: otherRouteID,
        label: "Other route",
        availability: .present,
        occurredAt: learningInstant(11),
        source: .iPhone
      ),
      .startProject(
        actionID: ActionID("learning-start-project"),
        projectID: projectID,
        routeCardID: routeID,
        occurredAt: learningInstant(12),
        source: .iPhone
      ),
      .startVisit(
        actionID: ActionID("learning-start-visit"),
        visitID: visitID,
        occurredAt: learningInstant(13),
        source: .iPhone
      ),
      .selectRoute(routeID),
      .recordAttempt(
        actionID: ActionID("learning-record-attempt"),
        attemptID: attemptID,
        occurredAt: learningInstant(14),
        source: .iPhone
      ),
      .confirmNotSent(
        actionID: ActionID("learning-not-sent"),
        attemptID: attemptID,
        occurredAt: learningInstant(15),
        source: .iPhone
      ),
      .selectRoute(otherRouteID),
      .recordAttempt(
        actionID: ActionID("learning-record-other-attempt"),
        attemptID: otherAttemptID,
        occurredAt: learningInstant(16),
        source: .iPhone
      ),
    ],
    to: &experience
  )

  let episodeID = FailureEpisodeID("learning-failure")
  let moveCueID = MoveCueID("learning-move-cue")
  let nextSessionCueID = NextSessionCueID("learning-next-cue")
  let review = try experience.completeFailureReview(
    FailureReviewRequest(
      failureActionID: ActionID("learning-failure-action"),
      moveCueActionID: ActionID("learning-move-action"),
      nextSessionCueActionID: ActionID("learning-next-action"),
      episodeID: episodeID,
      attemptID: attemptID,
      routeCardID: routeID,
      primaryBlocker: .footwork,
      locationNote: "before the hand move",
      moveCueID: moveCueID,
      moveCueText: "Name the foot before moving the hand",
      nextSessionCueID: nextSessionCueID,
      projectID: projectID,
      nextAction: "Try one controlled pause",
      occurredAt: learningInstant(17)
    )
  )
  try learningExperienceExpect(review == .accepted, "expected a confirmed recall chain")

  let pathID = TrainingPathID("learning-path")
  let drillID = try learningRequire(
    experience.projection.approvedMicroDrills.first?.id,
    "expected the injected approved drill"
  )
  let draftOutcome = try experience.submitLearning(
    .draftTrainingPath(
      actionID: ActionID("learning-draft-path"),
      pathID: pathID,
      failureEpisodeID: episodeID,
      moveCueID: moveCueID,
      microDrillID: drillID,
      nextSessionCueID: nextSessionCueID,
      proofQuestion: "Did the named foot land before the hand moved?",
      occurredAt: learningInstant(18)
    )
  )
  try learningExperienceExpect(
    draftOutcome == .accepted,
    "expected a draft from the confirmed recall chain"
  )
  let activationOutcome = try experience.submitLearning(
    .activateTrainingPath(
      actionID: ActionID("learning-activate-path"),
      pathID: pathID,
      occurredAt: learningInstant(19)
    )
  )
  try learningExperienceExpect(
    activationOutcome == .accepted,
    "expected the user to activate the draft"
  )

  let missingAttemptOutcome = try experience.submitLearning(
    .recordProofCheck(
      actionID: ActionID("learning-missing-proof"),
      proofCheckID: ProofCheckID("learning-missing-proof"),
      pathID: pathID,
      attemptID: AttemptID("does-not-exist"),
      outcome: .insufficientEvidence,
      decision: .revise,
      note: nil,
      occurredAt: learningInstant(20)
    )
  )
  try learningExperienceExpect(
    missingAttemptOutcome == .rejected(.proofCheckAttemptDoesNotExist),
    "a ProofCheck must not bind to a fabricated Attempt ID"
  )

  let wrongRouteOutcome = try experience.submitLearning(
    .recordProofCheck(
      actionID: ActionID("learning-wrong-route-proof"),
      proofCheckID: ProofCheckID("learning-wrong-route-proof"),
      pathID: pathID,
      attemptID: otherAttemptID,
      outcome: .triedNoObservableChange,
      decision: .revise,
      note: nil,
      occurredAt: learningInstant(21)
    )
  )
  try learningExperienceExpect(
    wrongRouteOutcome == .rejected(.proofCheckAttemptRouteMismatch),
    "a ProofCheck must use an Attempt from the TrainingPath RouteCard"
  )
  let oldAttemptOutcome = try experience.submitLearning(
    .recordProofCheck(
      actionID: ActionID("learning-old-attempt-proof"),
      proofCheckID: ProofCheckID("learning-old-attempt-proof"),
      pathID: pathID,
      attemptID: attemptID,
      outcome: .triedTargetBehaviorChanged,
      decision: .retain,
      note: nil,
      occurredAt: learningInstant(22)
    )
  )
  try learningExperienceExpect(
    oldAttemptOutcome == .rejected(.proofCheckAttemptIsNotLaterThanPath),
    "the failure-source Attempt must not double as a later TrainingPath ProofCheck"
  )
  try learningExperienceExpect(
    experience.projection.learning.proofChecks.isEmpty,
    "rejected ProofChecks must not mutate projected learning state"
  )

  let laterAttemptID = AttemptID("learning-later-attempt")
  try applyLearningCapture(
    [
      .selectRoute(routeID),
      .recordAttempt(
        actionID: ActionID("learning-record-later-attempt"),
        attemptID: laterAttemptID,
        occurredAt: learningInstant(23),
        source: .iPhone
      ),
    ],
    to: &experience
  )
  let validProofOutcome = try experience.submitLearning(
    .recordProofCheck(
      actionID: ActionID("learning-valid-proof"),
      proofCheckID: ProofCheckID("learning-valid-proof"),
      pathID: pathID,
      attemptID: laterAttemptID,
      outcome: .triedTargetBehaviorChanged,
      decision: .retain,
      note: "The foot landed first on the recorded Attempt.",
      occurredAt: learningInstant(24)
    )
  )
  try learningExperienceExpect(
    validProofOutcome == .accepted,
    "a real route-matched Attempt should support a retained ProofCheck"
  )
  let completionOutcome = try experience.submitLearning(
    .completeTrainingPath(
      actionID: ActionID("learning-complete-path"),
      pathID: pathID,
      occurredAt: learningInstant(25)
    )
  )
  try learningExperienceExpect(
    completionOutcome == .accepted,
    "a retained path should complete explicitly"
  )

  let reopened = try PersistentLineWiseExperienceCoordinator(store: store)
  try learningExperienceExpect(
    reopened.projection.learning.trainingPaths.first?.status == .completed
      && reopened.projection.learning.proofChecks.first?.attemptID == laterAttemptID,
    "the completed path and its later real Attempt proof should reopen durably"
  )
}

private func persistenceFailureDoesNotLeakSuggestedLearningState() throws {
  let store = FailingLearningExperienceStore()
  var experience = try PersistentLineWiseExperienceCoordinator(store: store)
  do {
    _ = try experience.submitLearning(
      .suggestSetterLensReading(
        actionID: ActionID("failed-learning-suggestion"),
        readingID: SetterLensReadingID("failed-learning-reading"),
        routeCardID: RouteCardID("failed-learning-route"),
        evidence: [
          SetterLensEvidence(
            id: "route_scene:failed-learning",
            kind: .routePhoto,
            version: "scene-v1",
            summary: "Pinned RouteScene."
          )
        ],
        interpretation: "Suggested balance sequence.",
        alternativeInterpretation: nil,
        provenance: SuggestionProvenance(
          suggestionID: "failed-learning-suggestion",
          source: .deterministicTemplate,
          sourceReference: "local-provider:failed-learning-route",
          sourceVersion: "x0",
          confidence: 0.5,
          decision: .pending
        ),
        occurredAt: learningInstant(30)
      )
    )
    throw LearningExperienceSpecFailure.expected("expected the scripted save to fail")
  } catch is ExperiencePersistenceError {
    // Expected: the proposed reducer state must not replace the projected state.
  }
  try learningExperienceExpect(
    experience.projection.learning.setterLensReadings.isEmpty,
    "a failed archive save must not leak a SetterLens suggestion into the UI projection"
  )
}

private func trySubmitLearning(
  _ command: LearningLoopCommand,
  to experience: inout PersistentLineWiseExperienceCoordinator
) throws -> LearningLoopOutcome {
  try experience.submitLearning(command)
}

private func applyLearningCapture(
  _ intents: [LineWiseAppIntent],
  to experience: inout PersistentLineWiseExperienceCoordinator
) throws {
  for intent in intents {
    let feedback = try experience.handle(intent)
    try learningExperienceExpect(
      feedback.isSuccess,
      "expected learning fixture capture to succeed: \(intent)"
    )
  }
}

private func learningRequire<Value>(_ value: Value?, _ message: String) throws -> Value {
  guard let value else { throw LearningExperienceSpecFailure.expected(message) }
  return value
}

private func learningExperienceExpect(_ condition: @autoclosure () -> Bool, _ message: String)
  throws
{
  guard condition() else { throw LearningExperienceSpecFailure.expected(message) }
}

private enum LearningExperienceSpecFailure: Error {
  case expected(String)
}

private final class FailingLearningExperienceStore: ExperienceArchiveStore {
  func load() throws -> LineWiseExperienceArchive? { nil }

  func save(_ archive: LineWiseExperienceArchive) throws {
    throw ExperiencePersistenceError.ioFailure(
      operation: "save",
      path: "/spec/failing-learning-experience",
      reason: "scripted failure"
    )
  }

  func exportData() throws -> Data? { nil }
  func delete() throws {}
}

private func learningInstant(_ seconds: Int64) -> Instant {
  Instant(millisecondsSince1970: seconds * 1_000)
}
