import Foundation
import LineWiseApplication
import LineWiseDomain

func experiencePersistenceSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "experience archive reopens recall learning physiology and rehearsal history",
      experienceArchiveReopensAllNonVisitState
    ),
    (
      "experience save failure leaves proposed memory unapplied",
      experienceSaveFailureLeavesMemoryUnapplied
    ),
    (
      "experience file store rejects corrupt and future archives",
      experienceFileStoreRejectsCorruptAndFutureArchives
    ),
    (
      "experience lifecycle exports and deletes all non visit data",
      experienceLifecycleExportsAndDeletesAllNonVisitData
    ),
  ]
}

private func experienceArchiveReopensAllNonVisitState() throws {
  let visitStore = MemoryVisitEventStore()
  let archiveStore = MemoryExperienceArchiveStore()
  let repository = try VisitRepository(
    store: visitStore,
    localDeviceID: DeviceID("experience-persistence-phone")
  )
  let drill = persistenceApprovedDrill()
  var experience = try PersistentLineWiseExperienceCoordinator(
    store: archiveStore,
    repository: repository,
    microDrillCatalog: ApprovedMicroDrillCatalog(drills: [drill]),
    provenance: ExperienceArchiveProvenance(
      writerIdentifier: "linewise-tests",
      writerVersion: "1.2.3"
    )
  )

  let routeID = RouteCardID("experience-persistence-route")
  let projectID = ProjectID("experience-persistence-project")
  let visitID = GymVisitID("experience-persistence-visit")
  let attemptID = AttemptID("experience-persistence-attempt")
  try prepareFailedAttempt(
    in: &experience,
    routeID: routeID,
    projectID: projectID,
    visitID: visitID,
    attemptID: attemptID
  )

  let episodeID = FailureEpisodeID("experience-persistence-episode")
  let moveCueID = MoveCueID("experience-persistence-move-cue")
  let nextCueID = NextSessionCueID("experience-persistence-next-cue")
  let review = FailureReviewRequest(
    failureActionID: ActionID("experience-persistence-failure-action"),
    moveCueActionID: ActionID("experience-persistence-move-action"),
    nextSessionCueActionID: ActionID("experience-persistence-next-action"),
    episodeID: episodeID,
    attemptID: attemptID,
    routeCardID: routeID,
    primaryBlocker: .bodyTension,
    locationNote: "At the compression move",
    moveCueID: moveCueID,
    moveCueText: "Keep the left toe loaded",
    nextSessionCueID: nextCueID,
    projectID: projectID,
    nextAction: "Retry the same sequence at lower intensity",
    occurredAt: persistenceInstant(10)
  )
  let reviewOutcome = try experience.completeFailureReview(review)
  try expect(reviewOutcome == .accepted, "expected review")

  let pathID = TrainingPathID("experience-persistence-path")
  let draft = LearningLoopCommand.draftTrainingPath(
    actionID: ActionID("experience-persistence-draft"),
    pathID: pathID,
    failureEpisodeID: episodeID,
    moveCueID: moveCueID,
    microDrillID: drill.id,
    nextSessionCueID: nextCueID,
    proofQuestion: "Did the left toe stay loaded?",
    occurredAt: persistenceInstant(11)
  )
  let draftOutcome = try experience.submitLearning(draft)
  try expect(draftOutcome == .accepted, "expected training path")
  let activationOutcome = try experience.submitLearning(
    .activateTrainingPath(
      actionID: ActionID("experience-persistence-activate"),
      pathID: pathID,
      occurredAt: persistenceInstant(12)
    )
  )
  try expect(activationOutcome == .accepted, "expected active training path")
  let laterAttemptID = AttemptID("experience-persistence-later-attempt")
  let laterAttemptFeedback = try experience.handle(
    .recordAttempt(
      actionID: ActionID("experience-persistence-later-attempt-action"),
      attemptID: laterAttemptID,
      occurredAt: persistenceInstant(13),
      source: .iPhone
    )
  )
  try expect(laterAttemptFeedback.isSuccess, "expected a later route-matched Attempt")
  let proof = LearningLoopCommand.recordProofCheck(
    actionID: ActionID("experience-persistence-proof"),
    proofCheckID: ProofCheckID("experience-persistence-proof-check"),
    pathID: pathID,
    attemptID: laterAttemptID,
    outcome: .triedTargetBehaviorChanged,
    decision: .retain,
    note: "The hip stayed closer to the wall",
    occurredAt: persistenceInstant(14)
  )
  let proofOutcome = try experience.submitLearning(proof)
  try expect(proofOutcome == .accepted, "expected proof check")

  let physiologyOutcome = try experience.recordPhysiology(
    contextID: PhysiologyContextID("experience-persistence-physiology"),
    visitID: visitID,
    subjective: SubjectivePhysiologyCheckIn(
      sessionEffort1To10: 8,
      wholeBodyFatigue0To10: 6,
      forearmPumpOverall: .strong
    ),
    healthKitSummary: HealthKitWorkoutSummary(
      durationSeconds: 2_700,
      averageHeartRateBPM: 136,
      maximumHeartRateBPM: 174,
      heartRateCoverage: 0.78,
      activeEnergyKilocalories: 310,
      workoutEffortScore: 8,
      workoutEffortSource: .perceived,
      sourceVersion: "healthkit-v2"
    ),
    recordedAt: persistenceInstant(14)
  )
  try expect(physiologyOutcome.isAccepted, "expected physiology context")

  let rehearsal = try persistenceRehearsalEngine()
  let rehearsalOutcome = try experience.attachRehearsal(
    rehearsal,
    routeCardID: routeID,
    plannedVisitID: visitID
  )
  try expect(rehearsalOutcome == .accepted, "expected rehearsal association")
  let restID = RestIntervalID("experience-persistence-rest")
  let startRest = LineWiseAppIntent.startRest(
    actionID: ActionID("experience-persistence-start-rest"),
    restID: restID,
    afterAttemptID: attemptID,
    occurredAt: persistenceInstant(15)
  )
  let startRestFeedback = try experience.handle(startRest)
  try expect(startRestFeedback.isSuccess, "expected active rest")
  let beforeReopen = experience.projection

  let reopenedRepository = try VisitRepository(
    store: visitStore,
    localDeviceID: DeviceID("experience-persistence-phone")
  )
  var reopened = try PersistentLineWiseExperienceCoordinator(
    store: archiveStore,
    repository: reopenedRepository
  )

  try expect(reopened.projection == beforeReopen, "expected lossless experience restoration")
  try expect(
    reopened.archive.provenance.writerVersion == "1.2.3",
    "expected archive provenance to survive"
  )
  try expect(
    reopened.projection.rehearsals.first?.rehearsal.plan.keyframes.first?.provenance
      == .manual,
    "expected rehearsal authorship provenance"
  )
  try expect(
    reopened.projection.capture.activeRest?.id == restID,
    "expected active rest to reopen"
  )
  let duplicateRecallOutcome = try reopened.submitRecall(
    .confirmFailureEpisode(
      actionID: review.failureActionID,
      episodeID: episodeID,
      attemptID: attemptID,
      routeCardID: routeID,
      primaryBlocker: .bodyTension,
      locationNote: "At the compression move",
      occurredAt: persistenceInstant(10)
    )
  )
  try expect(
    duplicateRecallOutcome == .duplicate,
    "expected restored recall command history to keep idempotency"
  )
  let duplicateProofOutcome = try reopened.submitLearning(proof)
  try expect(
    duplicateProofOutcome == .duplicate,
    "expected restored learning command history to keep idempotency"
  )

  let stopRest = LineWiseAppIntent.stopRest(
    actionID: ActionID("experience-persistence-stop-rest"),
    restID: restID,
    occurredAt: persistenceInstant(16)
  )
  let stopRestFeedback = try reopened.handle(stopRest)
  try expect(stopRestFeedback.isSuccess, "expected reopened rest to stop")
  let afterStopRepository = try VisitRepository(
    store: visitStore,
    localDeviceID: DeviceID("experience-persistence-phone")
  )
  var reopenedAfterStop = try PersistentLineWiseExperienceCoordinator(
    store: archiveStore,
    repository: afterStopRepository
  )
  try expect(
    reopenedAfterStop.projection.capture.activeRest == nil,
    "expected stopped rest to stay stopped after reopen"
  )
  let duplicateRestFeedback = try reopenedAfterStop.handle(stopRest)
  try expect(
    duplicateRestFeedback.outcome == .duplicate,
    "expected restored Rest command history to keep idempotency"
  )
}

private func experienceSaveFailureLeavesMemoryUnapplied() throws {
  let visitStore = MemoryVisitEventStore()
  let repository = try VisitRepository(
    store: visitStore,
    localDeviceID: DeviceID("experience-failure-phone")
  )
  let archiveStore = FailingExperienceArchiveStore()
  var experience = try PersistentLineWiseExperienceCoordinator(
    store: archiveStore,
    repository: repository
  )
  let routeID = RouteCardID("experience-failure-route")
  let projectID = ProjectID("experience-failure-project")
  let visitID = GymVisitID("experience-failure-visit")
  let attemptID = AttemptID("experience-failure-attempt")
  try prepareFailedAttempt(
    in: &experience,
    routeID: routeID,
    projectID: projectID,
    visitID: visitID,
    attemptID: attemptID
  )
  let before = experience.projection
  archiveStore.failNextSave = true

  do {
    _ = try experience.submitRecall(
      .confirmFailureEpisode(
        actionID: ActionID("experience-failure-recall"),
        episodeID: FailureEpisodeID("experience-failure-episode"),
        attemptID: attemptID,
        routeCardID: routeID,
        primaryBlocker: .footwork,
        locationNote: nil,
        occurredAt: persistenceInstant(20)
      )
    )
    throw ApplicationSpecFailure.expected("expected injected save failure")
  } catch FailingExperienceArchiveStore.Failure.save {
    // Expected: the proposed coordinator must not become visible.
  }

  try expect(experience.projection == before, "expected failed save to preserve in-memory state")
}

private func experienceFileStoreRejectsCorruptAndFutureArchives() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-experience-persistence-\(UUID().uuidString)",
    isDirectory: true
  )
  let fileURL = directory.appendingPathComponent("experience.json")
  defer { try? FileManager.default.removeItem(at: directory) }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

  let store = FoundationFileExperienceArchiveStore(fileURL: fileURL)
  try Data("not-json".utf8).write(to: fileURL)
  do {
    _ = try store.load()
    throw ApplicationSpecFailure.expected("expected corrupt archive failure")
  } catch ExperiencePersistenceError.corruptedStore {
    // Expected.
  }

  try Data("{\"schemaVersion\":999}".utf8).write(to: fileURL)
  do {
    _ = try store.load()
    throw ApplicationSpecFailure.expected("expected future schema failure")
  } catch ExperiencePersistenceError.unsupportedSchemaVersion(999) {
    // Expected.
  }
}

private func experienceLifecycleExportsAndDeletesAllNonVisitData() throws {
  let visitStore = MemoryVisitEventStore()
  let archiveStore = MemoryExperienceArchiveStore()
  let repository = try VisitRepository(
    store: visitStore,
    localDeviceID: DeviceID("experience-lifecycle-phone")
  )
  var experience = try PersistentLineWiseExperienceCoordinator(
    store: archiveStore,
    repository: repository
  )
  let visitID = GymVisitID("experience-lifecycle-visit")
  let visitFeedback = try experience.handle(
    .startVisit(
      actionID: ActionID("experience-lifecycle-start"),
      visitID: visitID,
      occurredAt: persistenceInstant(1),
      source: .iPhone
    )
  )
  try expect(visitFeedback.isSuccess, "expected visit")
  let contextOutcome = try experience.recordPhysiology(
    contextID: PhysiologyContextID("experience-lifecycle-context"),
    visitID: visitID,
    subjective: SubjectivePhysiologyCheckIn(
      sessionEffort1To10: 5,
      wholeBodyFatigue0To10: 3,
      forearmPumpOverall: .light
    ),
    healthKitSummary: nil,
    recordedAt: persistenceInstant(2)
  )
  try expect(contextOutcome.isAccepted, "expected persisted context")

  let data = try experience.exportData()
  let exported = try LineWiseExperienceArchiveCodec.decode(data)
  try expect(exported.physiologyContexts.count == 1, "expected full archive export")

  try experience.deleteAllExperienceData()
  try expect(experience.projection.physiologyContexts.isEmpty, "expected in-memory deletion")
  let deletedArchive = try archiveStore.load()
  try expect(deletedArchive == nil, "expected persistent deletion")
  try expect(
    experience.projection.capture.visits.map(\.id) == [visitID],
    "expected non-Visit deletion not to erase Visit history"
  )
}

private final class FailingExperienceArchiveStore: ExperienceArchiveStore {
  enum Failure: Error {
    case save
  }

  var failNextSave = false
  private var value: LineWiseExperienceArchive?

  func load() throws -> LineWiseExperienceArchive? { value }

  func save(_ archive: LineWiseExperienceArchive) throws {
    if failNextSave {
      failNextSave = false
      throw Failure.save
    }
    value = archive
  }

  func exportData() throws -> Data? {
    try value.map(LineWiseExperienceArchiveCodec.encode)
  }

  func delete() throws {
    value = nil
  }
}

private func prepareFailedAttempt(
  in experience: inout PersistentLineWiseExperienceCoordinator,
  routeID: RouteCardID,
  projectID: ProjectID,
  visitID: GymVisitID,
  attemptID: AttemptID
) throws {
  let intents: [LineWiseAppIntent] = [
    .createRoute(
      actionID: ActionID("\(routeID.rawValue)-create"),
      routeCardID: routeID,
      label: "Persistence route",
      availability: .present,
      occurredAt: persistenceInstant(1),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("\(projectID.rawValue)-start"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: persistenceInstant(2),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("\(visitID.rawValue)-start"),
      visitID: visitID,
      occurredAt: persistenceInstant(3),
      source: .iPhone
    ),
    .selectRoute(routeID),
    .recordAttempt(
      actionID: ActionID("\(attemptID.rawValue)-record"),
      attemptID: attemptID,
      occurredAt: persistenceInstant(4),
      source: .watch
    ),
    .confirmNotSent(
      actionID: ActionID("\(attemptID.rawValue)-not-sent"),
      attemptID: attemptID,
      occurredAt: persistenceInstant(5),
      source: .iPhone
    ),
  ]
  for intent in intents {
    let feedback = try experience.handle(intent)
    try expect(feedback.isSuccess, "expected setup intent: \(intent)")
  }
}

private func persistenceApprovedDrill() -> MicroDrill {
  MicroDrill(
    id: MicroDrillID("experience-persistence-drill"),
    title: "Quiet toe repeat",
    target: "Foot loading",
    routeContext: "Compression sequence",
    instructions: "Repeat the move with the left toe loaded",
    successCriterion: "Hip remains close through the hand move",
    source: .lineWiseEditorial,
    sourceReference: "linewise://drills/quiet-toe",
    version: "1",
    approvalState: .approved
  )
}

private func persistenceRehearsalEngine() throws -> RouteRehearsalEngine {
  let start = Hold(
    id: HoldID("experience-persistence-hold-start"),
    center: Point2D(x: 0.25, y: 0.2),
    radius: 0.05,
    routeRole: .start
  )
  let finish = Hold(
    id: HoldID("experience-persistence-hold-finish"),
    center: Point2D(x: 0.65, y: 0.75),
    radius: 0.05,
    routeRole: .top
  )
  let scene = RouteScene(
    id: RouteSceneID("experience-persistence-scene"),
    name: "Persistence wall",
    size: SceneSize(width: 1, height: 1),
    metersPerSceneUnit: 3,
    holds: [start, finish]
  )
  let frame = PoseKeyframe(
    id: PoseKeyframeID("experience-persistence-frame"),
    label: "Start",
    torsoPosition: Point2D(x: 0.4, y: 0.35),
    contacts: [
      LimbContact(limb: .leftHand, target: .hold(start.id), mode: .hand),
      LimbContact(limb: .rightHand, target: .hold(finish.id), mode: .hand),
      LimbContact(limb: .leftFoot, target: .ground(Point2D(x: 0.3, y: 0))),
      LimbContact(limb: .rightFoot, target: .ground(Point2D(x: 0.5, y: 0))),
    ],
    provenance: .manual
  )
  return try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("experience-persistence-rehearsal"),
    scene: scene,
    bodyProfile: .generic(id: BodyProfileID("experience-persistence-body")),
    planKeyframes: [frame]
  )
}

private func persistenceInstant(_ value: Int64) -> Instant {
  Instant(millisecondsSince1970: value * 1_000)
}
