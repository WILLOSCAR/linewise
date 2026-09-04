import Foundation
import LineWiseAppleAdapters
import LineWiseApplication
import LineWiseDomain

@MainActor
func experienceSurfaceSpecifications() -> [(String, () async throws -> Void)] {
  [
    (
      "iPhone review remains explicit and reopens the next-session cue",
      { try manualReviewRemainsExplicitAndReopensTheNextSessionCue() }
    ),
    (
      "physiology and manual rehearsal remain available without AI",
      lifecyclePhysiologyAndManualRehearsalRemainAvailableWithoutAI
    ),
    (
      "review branches and persistence failures remain visible",
      { try reviewBranchesAndPersistenceFailuresStayHonest() }
    ),
    (
      "synced ended Visit restores the Review Inbox and can begin review",
      { try syncedEndedVisitRestoresReviewInboxAndCanBeginReview() }
    ),
  ]
}

@MainActor
private func syncedEndedVisitRestoresReviewInboxAndCanBeginReview() throws {
  let repository = try VisitRepository(
    store: MemoryVisitEventStore(),
    localDeviceID: DeviceID("iphone-synced-review-surface")
  )
  let archiveStore = MemoryExperienceArchiveStore()
  let model = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(
      store: archiveStore,
      repository: repository
    )
  )
  var syncSide = LineWiseAppCoordinator(repository: repository)
  let routeID = RouteCardID("route-synced-review-surface")
  let visitID = GymVisitID("visit-synced-review-surface")
  let attemptID = AttemptID("attempt-synced-review-surface")
  let intents: [LineWiseAppIntent] = [
    .createRoute(
      actionID: ActionID("create-synced-review-surface"),
      routeCardID: routeID,
      label: "Synced orange route",
      availability: .present,
      occurredAt: surfaceInstant(70),
      source: .watch
    ),
    .startVisit(
      actionID: ActionID("start-synced-review-surface"),
      visitID: visitID,
      occurredAt: surfaceInstant(71),
      source: .watch
    ),
    .selectRoute(routeID),
    .recordAttempt(
      actionID: ActionID("attempt-synced-review-surface"),
      attemptID: attemptID,
      occurredAt: surfaceInstant(72),
      source: .watch
    ),
    .endVisit(
      actionID: ActionID("end-synced-review-surface"),
      occurredAt: surfaceInstant(73),
      source: .watch
    ),
  ]
  for intent in intents {
    try expect(syncSide.handle(intent).isSuccess, "expected synced surface setup: \(intent)")
  }

  try expect(model.pendingReviewItems.isEmpty, "expected the experience surface to start stale")
  model.refreshFromPersistence()
  try expect(
    model.pendingReviewItems.map(\.id)
      == [ReviewInboxItemID("unresolved/attempt-synced-review-surface")],
    "refresh must reconcile the ended Watch Visit into the iPhone Review Inbox"
  )

  let failingModel = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(
      store: AlwaysFailingExperienceStore(),
      repository: repository
    )
  )
  failingModel.refreshFromPersistence()
  if case .persistence(let message) = failingModel.issue {
    try expect(
      message.localizedCaseInsensitiveContains("review inbox"),
      "the failed reconciliation should identify the unsaved Review Inbox"
    )
  } else {
    throw AppleAdapterSpecFailure.expected(
      "a failed Review Inbox write must remain visible on the iPhone surface"
    )
  }
  try expect(
    failingModel.pendingReviewItems.isEmpty,
    "an unsaved reconciled item must not leak into the published projection"
  )

  try expect(
    model.beginVisitReview(visitID, at: surfaceInstant(74)),
    "the synced Visit must expose an explicit enter-review action"
  )
  try expect(
    model.projection.capture.visits.first?.reviewState == .reviewing,
    "entering review must durably advance the synced Visit"
  )
}

@MainActor
private func manualReviewRemainsExplicitAndReopensTheNextSessionCue() throws {
  let store = MemoryExperienceArchiveStore()
  let coordinator = try PersistentLineWiseExperienceCoordinator(store: store)
  let model = LineWiseExperienceViewModel(coordinator: coordinator)

  try expect(model.projection.capture.routeCards.isEmpty, "expected an honest first-run state")

  let routeID = RouteCardID("route-surface")
  let projectID = ProjectID("project-surface")
  let visitID = GymVisitID("visit-surface")
  let attemptID = AttemptID("attempt-surface")
  model.createRoute(
    label: "Blue slab",
    routeCardID: routeID,
    at: surfaceInstant(1)
  )
  model.startProject(routeCardID: routeID, projectID: projectID, at: surfaceInstant(2))
  model.startVisit(visitID: visitID, at: surfaceInstant(3))
  model.recordAttempt(attemptID: attemptID, at: surfaceInstant(4))
  model.endVisitAndPrepareReview(at: surfaceInstant(5))

  let item = try requireSurfaceValue(
    model.pendingReviewItems.first,
    "expected the unresolved Attempt in Review Inbox"
  )
  try expect(
    model.projection.capture.attempts.first?.outcome == .unresolved,
    "Review Inbox must not infer a failure from an unresolved Attempt"
  )
  try expect(
    model.projection.recall.failureEpisodes.isEmpty,
    "ending a Visit must not create FailureEpisode automatically"
  )

  model.resolveAttemptAsNotSent(itemID: item.id, attemptID: attemptID, at: surfaceInstant(6))
  try expect(
    model.projection.capture.attempts.first?.outcome == .notSent,
    "Not Sent must be an explicit user classification"
  )
  try expect(
    model.projection.recall.failureEpisodes.isEmpty,
    "Not Sent classification alone must not fabricate a blocker"
  )

  let cueID = NextSessionCueID("cue-surface")
  model.completeFailureReview(
    itemID: item.id,
    attemptID: attemptID,
    routeCardID: routeID,
    projectID: projectID,
    blocker: .footwork,
    locationNote: "At the volume",
    moveCueText: "Place the right toe before standing up",
    nextAction: "Try the toe placement before pulling",
    failureEpisodeID: FailureEpisodeID("failure-surface"),
    moveCueID: MoveCueID("move-cue-surface"),
    nextSessionCueID: cueID,
    at: surfaceInstant(7)
  )

  try expect(model.projection.recall.failureEpisodes.count == 1, "expected one blocker")
  try expect(model.projection.recall.moveCues.count == 1, "expected one MoveCue")
  try expect(model.projection.recall.nextSessionCues.count == 1, "expected one cue")
  try expect(model.pendingReviewItems.isEmpty, "expected the reviewed item to close")

  let nextVisitID = GymVisitID("visit-next-surface")
  model.startVisit(visitID: nextVisitID, at: surfaceInstant(8))
  try expect(
    model.reopenedNextSessionCues.map(\.id) == [cueID],
    "the next Visit should reopen the committed cue"
  )
  model.completeNextSessionCue(cueID, at: surfaceInstant(9))
  try expect(
    model.projection.recall.nextSessionCues.first?.status == .completed,
    "the user must be able to complete a reopened cue"
  )
}

@MainActor
private func lifecyclePhysiologyAndManualRehearsalRemainAvailableWithoutAI() async throws {
  let coordinator = try PersistentLineWiseExperienceCoordinator(
    store: MemoryExperienceArchiveStore()
  )
  let model = LineWiseExperienceViewModel(coordinator: coordinator)
  let routeID = RouteCardID("route-lifecycle")
  let projectID = ProjectID("project-lifecycle")
  let visitID = GymVisitID("visit-lifecycle")
  let attemptID = AttemptID("attempt-lifecycle")

  model.createRoute(label: "Orange corner", routeCardID: routeID, at: surfaceInstant(20))
  model.renameRoute(routeID, label: "Orange compression", at: surfaceInstant(21))
  try expect(
    model.projection.capture.routeCards.first?.label == "Orange compression",
    "expected RouteCard rename"
  )
  model.archiveRoute(routeID, at: surfaceInstant(22))
  try expect(
    model.projection.capture.routeCards.first?.recordVisibility == .archived,
    "expected RouteCard archive"
  )
  model.restoreRoute(routeID, at: surfaceInstant(23))
  model.selectRoute(routeID)
  model.startProject(routeCardID: routeID, projectID: projectID, at: surfaceInstant(24))
  model.archiveProject(projectID, at: surfaceInstant(25))
  try expect(
    model.projection.capture.projects.first?.state == .archived,
    "expected an explicit Project archive"
  )

  model.startVisit(visitID: visitID, at: surfaceInstant(26))
  model.recordAttempt(attemptID: attemptID, at: surfaceInstant(27))
  model.startRest(restID: RestIntervalID("rest-lifecycle"), at: surfaceInstant(28))
  try expect(model.projection.capture.activeRest != nil, "expected a visible active rest")
  model.stopRest(at: surfaceInstant(29))
  model.markAttemptSend(attemptID, at: surfaceInstant(30))
  model.undoLatest(at: surfaceInstant(31))
  try expect(
    model.projection.capture.attempts.first?.outcome == .unresolved,
    "Undo should target the exact latest Send classification"
  )

  let rehearsalID = RouteRehearsalID("rehearsal-lifecycle")
  model.createManualRehearsalStarter(
    routeCardID: routeID,
    plannedVisitID: visitID,
    rehearsalID: rehearsalID
  )
  let association = try requireSurfaceValue(
    model.projection.rehearsals.first,
    "expected a rehearsal association"
  )
  try expect(
    association.rehearsal.scene.holds.count >= 4,
    "manual starter should contain editable holds without an AI result"
  )
  let editor = try requireSurfaceValue(
    model.rehearsalEditorModel(for: rehearsalID),
    "expected an entry into LineWiseRehearsalEditorView"
  )
  try expect(
    editor.projection.routeReadProvenance.automation == .manual,
    "manual starter must be labeled as user-authored, not AI-generated"
  )
  let edit = editor.handle(
    .addKeyframe(
      id: PoseKeyframeID("rehearsal-lifecycle-second-pose"),
      label: "Move 2",
      after: editor.projection.selectedKeyframeID
    )
  )
  try expect(edit.isSuccess, "expected the manual timeline to remain editable")
  try expect(model.saveRehearsalEdits(rehearsalID), "expected explicit rehearsal save")
  try expect(
    model.projection.rehearsals.first?.rehearsal.plan.keyframes.count == 2,
    "saved editor changes should return to persistent experience state"
  )
  await editor.runLocalQualitativeAnalysis()
  try expect(
    editor.qualitativeAnalysis?.provenance.authorship == .suggested
      && editor.qualitativeAnalysis?.provenance.evidenceTreatment == .inferred,
    "local qualitative analysis must stay a suggested inference"
  )
  try expect(
    editor.qualitativeAnalysis?.observations.isEmpty == false,
    "the visible qualitative reading should retain pinned observations"
  )

  model.endVisitAndPrepareReview(at: surfaceInstant(32))
  model.recordPhysiology(
    visitID: visitID,
    sessionEffort1To10: 8,
    wholeBodyFatigue0To10: 6,
    forearmPumpOverall: .strong,
    healthKitSummary: HealthKitWorkoutSummary(
      durationSeconds: 1_800,
      averageHeartRateBPM: 132,
      maximumHeartRateBPM: 168,
      heartRateCoverage: 0.8,
      activeEnergyKilocalories: 210,
      workoutEffortScore: nil,
      workoutEffortSource: nil,
      sourceVersion: "surface-spec"
    ),
    contextID: PhysiologyContextID("physiology-lifecycle"),
    at: surfaceInstant(33)
  )
  let physiology = try requireSurfaceValue(
    model.projection.physiologyContexts.first,
    "expected subjective physiology memory"
  )
  try expect(physiology.primarySource == .subjectiveReport, "subjective report stays primary")
  try expect(
    physiology.healthKitRole == .optionalSupportingContext
      && physiology.claimBoundary == .contextOnlyNonDiagnostic,
    "HealthKit must remain optional supporting and non-diagnostic context"
  )
  try expect(
    model.physiologyBoundaryMessage.localizedCaseInsensitiveContains("not a diagnosis"),
    "the claim boundary must be visible in the UI"
  )

  model.setRouteAvailability(routeID, availability: .gone, at: surfaceInstant(34))
  try expect(
    model.projection.capture.routeCards.first?.availability == .gone
      && model.projection.capture.currentRouteCard == nil,
    "a gone route remains in history but is no longer selectable"
  )
}

@MainActor
private func reviewBranchesAndPersistenceFailuresStayHonest() throws {
  let failingModel = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(store: AlwaysFailingExperienceStore())
  )
  let failed = failingModel.createRoute(
    label: "Must not appear",
    routeCardID: RouteCardID("route-failed-save"),
    at: surfaceInstant(40)
  )
  try expect(!failed, "expected the surfaced operation to fail")
  try expect(
    failingModel.projection.capture.routeCards.isEmpty,
    "a persistence failure must not leak proposed state into the UI"
  )
  if case .persistence(let message) = failingModel.issue {
    try expect(!message.isEmpty, "expected a readable persistence error")
  } else {
    throw AppleAdapterSpecFailure.expected("expected an explicit persistence issue")
  }

  let sharedRepository = try VisitRepository(
    store: MemoryVisitEventStore(),
    localDeviceID: DeviceID("iphone-shared-surface")
  )
  let sharedModel = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(
      store: MemoryExperienceArchiveStore(),
      repository: sharedRepository
    )
  )
  var syncSide = LineWiseAppCoordinator(repository: sharedRepository)
  _ = syncSide.handle(
    .createRoute(
      actionID: ActionID("sync-side-route-action"),
      routeCardID: RouteCardID("sync-side-route"),
      label: "Route from Watch sync",
      availability: .present,
      occurredAt: surfaceInstant(40),
      source: .watch
    )
  )
  try expect(sharedModel.projection.capture.routeCards.isEmpty, "expected a stale UI projection")
  sharedModel.refreshFromPersistence()
  try expect(
    sharedModel.projection.capture.routeCards.map(\.id) == [RouteCardID("sync-side-route")],
    "refresh should project the shared repository after device sync"
  )

  let model = LineWiseExperienceViewModel(
    coordinator: try PersistentLineWiseExperienceCoordinator(
      store: MemoryExperienceArchiveStore()
    )
  )
  let routeID = RouteCardID("route-review-branches")
  let projectID = ProjectID("project-review-branches")
  let visitID = GymVisitID("visit-review-branches")
  let sendID = AttemptID("attempt-review-send")
  let skipID = AttemptID("attempt-review-skip")
  let failureID = AttemptID("attempt-review-failure")
  model.createRoute(label: "Green roof", routeCardID: routeID, at: surfaceInstant(41))
  model.startProject(routeCardID: routeID, projectID: projectID, at: surfaceInstant(42))
  model.startVisit(visitID: visitID, at: surfaceInstant(43))
  model.recordAttempt(attemptID: sendID, at: surfaceInstant(44))
  model.recordAttempt(attemptID: skipID, at: surfaceInstant(45))
  model.recordAttempt(attemptID: failureID, at: surfaceInstant(46))
  model.endVisitAndPrepareReview(at: surfaceInstant(47))

  let sendItem = try requireSurfaceValue(
    model.reviewItem(for: sendID),
    "expected Send review item"
  )
  let skipItem = try requireSurfaceValue(
    model.reviewItem(for: skipID),
    "expected Skip review item"
  )
  let failureItem = try requireSurfaceValue(
    model.reviewItem(for: failureID),
    "expected Not Sent review item"
  )
  model.resolveAttemptAsSent(itemID: sendItem.id, attemptID: sendID, at: surfaceInstant(48))
  model.skipReviewItem(skipItem.id, at: surfaceInstant(49))
  try expect(
    model.projection.capture.attempts.first(where: { $0.id == sendID })?.outcome == .sent,
    "Send must be stored only after its explicit review action"
  )
  try expect(
    model.projection.capture.attempts.first(where: { $0.id == skipID })?.outcome == .unresolved,
    "Skip must preserve an honest unknown outcome"
  )

  model.resolveAttemptAsNotSent(
    itemID: failureItem.id,
    attemptID: failureID,
    at: surfaceInstant(50)
  )
  let cueID = NextSessionCueID("cue-review-branches")
  model.completeFailureReview(
    itemID: failureItem.id,
    attemptID: failureID,
    routeCardID: routeID,
    projectID: projectID,
    blocker: .bodyPosition,
    locationNote: nil,
    moveCueText: "Turn the hip before moving the hand",
    nextAction: "Rehearse the hip turn once",
    failureEpisodeID: FailureEpisodeID("failure-review-branches"),
    moveCueID: MoveCueID("move-review-branches"),
    nextSessionCueID: cueID,
    at: surfaceInstant(51)
  )
  model.completeVisitReview(visitID, at: surfaceInstant(52))

  let cueVisit = GymVisitID("visit-review-cue")
  model.startVisit(visitID: cueVisit, at: surfaceInstant(53))
  model.deferNextSessionCue(cueID, until: surfaceInstant(60), at: surfaceInstant(54))
  try expect(
    model.projection.recall.nextSessionCues.first?.status == .deferred,
    "a cue can be deliberately deferred"
  )
  model.endVisitAndPrepareReview(at: surfaceInstant(55))
  model.completeVisitReview(cueVisit, at: surfaceInstant(56))
  model.startVisit(visitID: GymVisitID("visit-review-cue-later"), at: surfaceInstant(61))
  try expect(
    model.reopenedNextSessionCues.map(\.id) == [cueID],
    "a deferred cue should reopen after its deadline"
  )
  model.dismissNextSessionCue(cueID, at: surfaceInstant(62))
  try expect(
    model.projection.recall.nextSessionCues.first?.status == .dismissed,
    "Ignore must be an explicit durable cue state"
  )
}

private func surfaceInstant(_ seconds: Int64) -> Instant {
  Instant(millisecondsSince1970: seconds * 1_000)
}

private func requireSurfaceValue<Value>(_ value: Value?, _ message: String) throws -> Value {
  guard let value else { throw AppleAdapterSpecFailure.expected(message) }
  return value
}

private final class AlwaysFailingExperienceStore: ExperienceArchiveStore {
  func load() throws -> LineWiseExperienceArchive? { nil }

  func save(_ archive: LineWiseExperienceArchive) throws {
    throw ExperiencePersistenceError.ioFailure(
      operation: "save",
      path: "/spec/failing-store",
      reason: "scripted failure"
    )
  }

  func exportData() throws -> Data? { nil }
  func delete() throws {}
}
