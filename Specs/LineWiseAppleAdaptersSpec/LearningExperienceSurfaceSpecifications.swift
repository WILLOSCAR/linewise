import Foundation
import LineWiseAppleAdapters
import LineWiseApplication
import LineWiseDomain

@MainActor
func runLearningExperienceSurfaceSpecifications() async throws -> Int {
  try await qualitativeReadingAndTrainingPathCompleteThroughPublicSurface()
  try await persistenceFailureKeepsThePendingReadingVisible()
  return 2
}

@MainActor
private func qualitativeReadingAndTrainingPathCompleteThroughPublicSurface() async throws {
  let store = MemoryExperienceArchiveStore()
  let model = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(
      store: store,
      microDrillCatalog: .lineWiseEditorialV0
    )
  )
  let routeID = RouteCardID("learning-surface-route")
  let projectID = ProjectID("learning-surface-project")
  let visitID = GymVisitID("learning-surface-visit")
  let attemptID = AttemptID("learning-surface-attempt")
  try expect(
    model.createRoute(label: "Purple balance", routeCardID: routeID, at: learningSurfaceInstant(1)),
    "expected route creation"
  )
  try expect(
    model.startProject(routeCardID: routeID, projectID: projectID, at: learningSurfaceInstant(2)),
    "expected Project creation"
  )
  try expect(model.startVisit(visitID: visitID, at: learningSurfaceInstant(3)), "expected Visit")
  try expect(
    model.recordAttempt(attemptID: attemptID, at: learningSurfaceInstant(4)),
    "expected a real Attempt"
  )
  try expect(
    model.markAttemptNotSent(attemptID, at: learningSurfaceInstant(5)),
    "expected explicit Not Sent"
  )

  let failureID = FailureEpisodeID("learning-surface-failure")
  let moveCueID = MoveCueID("learning-surface-move-cue")
  let nextCueID = NextSessionCueID("learning-surface-next-cue")
  try expect(
    model.completeFailureReview(
      itemID: nil,
      attemptID: attemptID,
      routeCardID: routeID,
      projectID: projectID,
      blocker: .footwork,
      locationNote: "before the second hand move",
      moveCueText: "Name the right foot, then stand",
      nextAction: "Try one controlled pause",
      failureEpisodeID: failureID,
      moveCueID: moveCueID,
      nextSessionCueID: nextCueID,
      at: learningSurfaceInstant(6)
    ),
    "expected a user-confirmed failure chain"
  )

  let rehearsalID = RouteRehearsalID("learning-surface-rehearsal")
  try expect(
    model.createManualRehearsalStarter(
      routeCardID: routeID,
      plannedVisitID: visitID,
      rehearsalID: rehearsalID
    ),
    "expected manual rehearsal"
  )
  let editor = try requireLearningSurfaceValue(
    model.rehearsalEditorModel(for: rehearsalID),
    "expected a rehearsal editor"
  )
  await editor.runLocalQualitativeAnalysis()
  try expect(editor.qualitativeAnalysis != nil, "expected a local qualitative suggestion")

  let acceptedReadingID = SetterLensReadingID("learning-surface-reading")
  try expect(
    model.saveSetterLensSuggestion(
      from: rehearsalID,
      readingID: acceptedReadingID,
      at: learningSurfaceInstant(7)
    ),
    "expected the qualitative result to save through the SetterLens bridge"
  )
  try expect(
    model.projection.learning.setterLensReadings.first?.status == .suggested,
    "saving analysis must not silently confirm it"
  )
  try expect(
    model.acceptSetterLensReading(
      acceptedReadingID,
      interpretationOverride: "My reading: right foot first, then stand.",
      at: learningSurfaceInstant(8)
    ),
    "expected explicit edited acceptance"
  )
  try expect(
    model.projection.learning.setterLensReadings.first?.suggestionProvenance.decision == .edited,
    "the explicit edit should be visible in provenance"
  )

  let rejectedReadingID = SetterLensReadingID("learning-surface-rejected-reading")
  try expect(
    model.saveSetterLensSuggestion(
      from: rehearsalID,
      readingID: rejectedReadingID,
      at: learningSurfaceInstant(9)
    ),
    "expected a second independently reviewable suggestion"
  )
  try expect(
    model.rejectSetterLensReading(rejectedReadingID, at: learningSurfaceInstant(10)),
    "expected explicit rejection"
  )

  let drill = try requireLearningSurfaceValue(
    model.projection.approvedMicroDrills.first,
    "expected the approved LineWise editorial v0 drill"
  )
  try expect(
    drill.sourceReference
      == "LineWise editorial v0 · movement practice only · not medical or safety guidance",
    "the UI-facing drill must carry its claim boundary"
  )
  let pathID = TrainingPathID("learning-surface-path")
  try expect(
    model.draftTrainingPath(
      failureEpisodeID: failureID,
      moveCueID: moveCueID,
      microDrillID: drill.id,
      nextSessionCueID: nextCueID,
      proofQuestion: "Did the named foot land before the hand moved?",
      pathID: pathID,
      at: learningSurfaceInstant(11)
    ),
    "expected a draft from the confirmed chain and approved drill"
  )
  try expect(
    model.activateTrainingPath(pathID, at: learningSurfaceInstant(12)),
    "expected explicit activation"
  )
  let laterAttemptID = AttemptID("learning-surface-later-attempt")
  try expect(
    model.recordAttempt(attemptID: laterAttemptID, at: learningSurfaceInstant(13)),
    "expected a later real Attempt for ProofCheck"
  )
  try expect(
    model.recordProofCheck(
      pathID: pathID,
      attemptID: laterAttemptID,
      outcome: .triedTargetBehaviorChanged,
      decision: .retain,
      note: "Observed on the recorded Attempt.",
      proofCheckID: ProofCheckID("learning-surface-proof"),
      at: learningSurfaceInstant(14)
    ),
    "expected the active path to bind a real Attempt"
  )
  try expect(
    model.completeTrainingPath(pathID, at: learningSurfaceInstant(15)),
    "expected retained path completion"
  )

  let reopened = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(store: store)
  )
  try expect(
    reopened.projection.learning.trainingPaths.first?.status == .completed
      && reopened.projection.learning.proofChecks.first?.attemptID == laterAttemptID,
    "the public learning loop should reopen durably"
  )
}

@MainActor
private func persistenceFailureKeepsThePendingReadingVisible() async throws {
  let store = ToggleFailingLearningSurfaceStore()
  let model = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(
      store: store,
      microDrillCatalog: .lineWiseEditorialV0
    )
  )
  let routeID = RouteCardID("failure-learning-surface-route")
  let rehearsalID = RouteRehearsalID("failure-learning-surface-rehearsal")
  try expect(
    model.createRoute(label: "Failure route", routeCardID: routeID, at: learningSurfaceInstant(20)),
    "expected fixture route"
  )
  try expect(
    model.createManualRehearsalStarter(routeCardID: routeID, rehearsalID: rehearsalID),
    "expected fixture rehearsal"
  )
  let editor = try requireLearningSurfaceValue(
    model.rehearsalEditorModel(for: rehearsalID),
    "expected fixture editor"
  )
  await editor.runLocalQualitativeAnalysis()
  let readingID = SetterLensReadingID("failure-learning-surface-reading")
  try expect(
    model.saveSetterLensSuggestion(
      from: rehearsalID,
      readingID: readingID,
      at: learningSurfaceInstant(21)
    ),
    "expected pending fixture suggestion"
  )
  store.shouldFail = true
  let accepted = model.acceptSetterLensReading(readingID, at: learningSurfaceInstant(22))
  try expect(!accepted, "expected scripted persistence failure")
  try expect(
    model.projection.learning.setterLensReadings.first?.status == .suggested,
    "failed acceptance must not leak the proposed confirmed state"
  )
  if case .persistence = model.issue {
    // Expected public error boundary.
  } else {
    throw AppleAdapterSpecFailure.expected("expected an explicit persistence issue")
  }
}

private func learningSurfaceInstant(_ seconds: Int64) -> Instant {
  Instant(millisecondsSince1970: seconds * 1_000)
}

private func requireLearningSurfaceValue<Value>(_ value: Value?, _ message: String) throws -> Value
{
  guard let value else { throw AppleAdapterSpecFailure.expected(message) }
  return value
}

private final class ToggleFailingLearningSurfaceStore: ExperienceArchiveStore {
  var shouldFail = false
  private var archive: LineWiseExperienceArchive?

  func load() throws -> LineWiseExperienceArchive? { archive }

  func save(_ archive: LineWiseExperienceArchive) throws {
    if shouldFail {
      throw ExperiencePersistenceError.ioFailure(
        operation: "save",
        path: "/spec/toggle-learning-surface",
        reason: "scripted failure"
      )
    }
    self.archive = archive
  }

  func exportData() throws -> Data? {
    try archive.map(LineWiseExperienceArchiveCodec.encode)
  }

  func delete() throws { archive = nil }
}
