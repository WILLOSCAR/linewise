import LineWiseApplication
import LineWiseDomain

func experienceSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "failure review becomes a cue in the next visit",
      failureReviewBecomesACueInTheNextVisit
    ),
    (
      "failure review is atomic across the recall chain",
      failureReviewIsAtomicAcrossTheRecallChain
    ),
    (
      "subjective physiology stays primary without requiring HealthKit",
      subjectivePhysiologyStaysPrimaryWithoutRequiringHealthKit
    ),
    (
      "route rehearsal links plan and actual without blocking capture",
      routeRehearsalLinksPlanAndActualWithoutBlockingCapture
    ),
  ]
}

private func failureReviewBecomesACueInTheNextVisit() throws {
  let routeID = RouteCardID("route-experience-loop")
  let projectID = ProjectID("project-experience-loop")
  let firstVisitID = GymVisitID("visit-experience-loop-1")
  let secondVisitID = GymVisitID("visit-experience-loop-2")
  let attemptID = AttemptID("attempt-experience-loop")
  let episodeID = FailureEpisodeID("failure-experience-loop")
  let moveCueID = MoveCueID("move-cue-experience-loop")
  let nextCueID = NextSessionCueID("next-cue-experience-loop")
  let drill = approvedDrill()
  let repository = try VisitRepository(
    store: MemoryVisitEventStore(),
    localDeviceID: DeviceID("iphone-experience-loop")
  )
  var experience = LineWiseExperienceCoordinator(
    repository: repository,
    microDrillCatalog: ApprovedMicroDrillCatalog(drills: [drill])
  )

  let captureCommands: [LineWiseAppIntent] = [
    .createRoute(
      actionID: ActionID("experience-create-route"),
      routeCardID: routeID,
      label: "Purple compression",
      availability: .present,
      occurredAt: instant(1),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("experience-start-project"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: instant(2),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("experience-start-visit-1"),
      visitID: firstVisitID,
      occurredAt: instant(3),
      source: .iPhone
    ),
    .selectRoute(routeID),
    .recordAttempt(
      actionID: ActionID("experience-record-attempt"),
      attemptID: attemptID,
      occurredAt: instant(4),
      source: .watch
    ),
    .confirmNotSent(
      actionID: ActionID("experience-confirm-not-sent"),
      attemptID: attemptID,
      occurredAt: instant(5),
      source: .iPhone
    ),
    .endVisit(
      actionID: ActionID("experience-end-visit-1"),
      occurredAt: instant(6),
      source: .iPhone
    ),
    .beginReview(
      actionID: ActionID("experience-begin-review"),
      visitID: firstVisitID,
      occurredAt: instant(7),
      source: .iPhone
    ),
  ]
  for command in captureCommands {
    try expect(experience.handle(command).isSuccess, "expected capture command: \(command)")
  }

  let review = experience.completeFailureReview(
    FailureReviewRequest(
      failureActionID: ActionID("experience-confirm-failure"),
      moveCueActionID: ActionID("experience-create-move-cue"),
      nextSessionCueActionID: ActionID("experience-create-next-cue"),
      episodeID: episodeID,
      attemptID: attemptID,
      routeCardID: routeID,
      primaryBlocker: .bodyPosition,
      locationNote: "After the third hand move",
      moveCueID: moveCueID,
      moveCueText: "Keep the left hip close before moving the right hand",
      nextSessionCueID: nextCueID,
      projectID: projectID,
      nextAction: "Try the hip-first sequence before adding power",
      occurredAt: instant(8)
    )
  )
  try expect(review == .accepted, "expected an accepted manual review chain")
  try expect(experience.projection.recall.failureEpisodes.count == 1, "expected failure")
  try expect(experience.projection.recall.moveCues.count == 1, "expected move cue")
  try expect(experience.projection.recall.nextSessionCues.count == 1, "expected next cue")

  try expect(
    experience.submitLearning(
      .draftTrainingPath(
        actionID: ActionID("experience-draft-path"),
        pathID: TrainingPathID("path-experience-loop"),
        failureEpisodeID: episodeID,
        moveCueID: moveCueID,
        microDrillID: drill.id,
        nextSessionCueID: nextCueID,
        proofQuestion: "Did the right hand move happen without the hips peeling?",
        occurredAt: instant(9)
      )
    ) == .accepted,
    "expected recall chain to feed the training path"
  )

  try expect(
    experience.handle(
      .completeReview(
        actionID: ActionID("experience-complete-review"),
        visitID: firstVisitID,
        occurredAt: instant(10),
        source: .iPhone
      )
    ).isSuccess,
    "expected visit review completion"
  )
  try expect(
    experience.handle(
      .startVisit(
        actionID: ActionID("experience-start-visit-2"),
        visitID: secondVisitID,
        occurredAt: instant(11),
        source: .watch
      )
    ).isSuccess,
    "expected the next visit to stay a normal P0 capture"
  )

  let reopened = experience.projection.reopenedNextSessionCues
  try expect(reopened.map(\.id) == [nextCueID], "expected cue to reappear in next visit")
  try expect(
    reopened.first?.reopenedInVisitID == secondVisitID,
    "expected cue to retain its reopening visit"
  )
  try expect(experience.projection.warnings.isEmpty, "expected no hidden automation failures")
  try expect(
    repository.snapshot.visits.contains(where: { $0.id == secondVisitID }),
    "expected the new visit to remain persisted through VisitRepository"
  )
}

private func failureReviewIsAtomicAcrossTheRecallChain() throws {
  let routeID = RouteCardID("route-atomic-review")
  let visitID = GymVisitID("visit-atomic-review")
  let attemptID = AttemptID("attempt-atomic-review")
  var experience = LineWiseExperienceCoordinator()

  for command in basicFailedAttemptCommands(
    routeID: routeID,
    visitID: visitID,
    attemptID: attemptID
  ) {
    try expect(experience.handle(command).isSuccess, "expected failed-attempt setup")
  }

  let result = experience.completeFailureReview(
    FailureReviewRequest(
      failureActionID: ActionID("atomic-failure"),
      moveCueActionID: ActionID("atomic-move-cue"),
      nextSessionCueActionID: ActionID("atomic-next-cue"),
      episodeID: FailureEpisodeID("atomic-episode"),
      attemptID: attemptID,
      routeCardID: routeID,
      primaryBlocker: .footwork,
      locationNote: nil,
      moveCueID: MoveCueID("atomic-cue"),
      moveCueText: "Step through quietly",
      nextSessionCueID: NextSessionCueID("atomic-next"),
      projectID: ProjectID("missing-project"),
      nextAction: "Retry",
      occurredAt: instant(20)
    )
  )

  try expect(
    result == .rejected(stage: .nextSessionCue, reason: .projectDoesNotExist),
    "expected the failing stage and domain reason"
  )
  try expect(
    experience.projection.recall.failureEpisodes.isEmpty
      && experience.projection.recall.moveCues.isEmpty
      && experience.projection.recall.nextSessionCues.isEmpty,
    "expected no partial recall chain"
  )
}

private func subjectivePhysiologyStaysPrimaryWithoutRequiringHealthKit() throws {
  let visitID = GymVisitID("visit-physiology-experience")
  var experience = LineWiseExperienceCoordinator()
  try expect(
    experience.handle(
      .startVisit(
        actionID: ActionID("physiology-start-visit"),
        visitID: visitID,
        occurredAt: instant(1),
        source: .watch
      )
    ).isSuccess,
    "expected visit setup"
  )

  let subjective = SubjectivePhysiologyCheckIn(
    sessionEffort1To10: 7,
    wholeBodyFatigue0To10: 5,
    forearmPumpOverall: .strong
  )
  let withoutHealthKit = experience.recordPhysiology(
    contextID: PhysiologyContextID("physiology-subjective-only"),
    visitID: visitID,
    subjective: subjective,
    healthKitSummary: nil,
    recordedAt: instant(2)
  )
  try expect(withoutHealthKit.isAccepted, "expected subjective-only check-in")
  let first = experience.projection.physiologyContexts.first
  try expect(first?.primarySource == .subjectiveReport, "expected subjective primary source")
  try expect(first?.healthKitRole == .absent, "expected HealthKit to be optional")
  try expect(
    first?.claimBoundary == .contextOnlyNonDiagnostic,
    "expected a non-diagnostic claim boundary"
  )

  let withHealthKit = experience.recordPhysiology(
    contextID: PhysiologyContextID("physiology-with-health-kit"),
    visitID: visitID,
    subjective: subjective,
    healthKitSummary: HealthKitWorkoutSummary(
      durationSeconds: 3_600,
      averageHeartRateBPM: 132,
      maximumHeartRateBPM: 171,
      heartRateCoverage: 0.82,
      activeEnergyKilocalories: 420,
      workoutEffortScore: 7,
      workoutEffortSource: .perceived,
      sourceVersion: "healthkit-test-v1"
    ),
    recordedAt: instant(3)
  )
  try expect(withHealthKit.isAccepted, "expected valid optional HealthKit context")
  let second = experience.projection.physiologyContexts.last
  try expect(second?.primarySource == .subjectiveReport, "expected subjective to remain primary")
  try expect(
    second?.healthKitRole == .optionalSupportingContext,
    "expected HealthKit to remain supporting context"
  )
}

private func routeRehearsalLinksPlanAndActualWithoutBlockingCapture() throws {
  let routeID = RouteCardID("route-rehearsal-experience")
  let visitID = GymVisitID("visit-rehearsal-experience")
  let attemptID = AttemptID("attempt-rehearsal-experience")
  var experience = LineWiseExperienceCoordinator()

  for command in basicAttemptCommands(routeID: routeID, visitID: visitID, attemptID: attemptID) {
    try expect(experience.handle(command).isSuccess, "expected P0 capture without rehearsal")
  }
  try expect(
    experience.projection.capture.attempts.map(\.id) == [attemptID],
    "expected the manual Attempt before rehearsal exists"
  )

  let engine = try makeRehearsalEngine()
  let associated = experience.attachRehearsal(
    engine,
    routeCardID: routeID,
    plannedVisitID: visitID,
    actualAttemptID: attemptID
  )
  try expect(associated == .accepted, "expected valid plan/actual association")
  let link = experience.projection.rehearsals.first
  try expect(link?.routeCardID == routeID, "expected route association")
  try expect(link?.plannedVisitID == visitID, "expected plan visit association")
  try expect(link?.actualAttemptID == attemptID, "expected actual attempt association")
  try expect(link?.rehearsal.plan.keyframes.count == 2, "expected plan timeline")
  try expect(link?.rehearsal.actual.keyframes.count == 2, "expected actual timeline")

  let invalid = experience.attachRehearsal(
    try makeRehearsalEngine(id: RouteRehearsalID("rehearsal-missing-attempt")),
    routeCardID: routeID,
    plannedVisitID: visitID,
    actualAttemptID: AttemptID("attempt-that-does-not-exist")
  )
  try expect(
    invalid == .rejected(.attemptDoesNotExist),
    "expected an explicit optional-association rejection"
  )
  try expect(
    experience.projection.capture.attempts.map(\.id) == [attemptID],
    "expected rehearsal failure not to roll back or block P0 capture"
  )
}

private func basicAttemptCommands(
  routeID: RouteCardID,
  visitID: GymVisitID,
  attemptID: AttemptID
) -> [LineWiseAppIntent] {
  [
    .createRoute(
      actionID: ActionID("basic-create-\(routeID.rawValue)"),
      routeCardID: routeID,
      label: "Test route",
      availability: .present,
      occurredAt: instant(1),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("basic-start-\(visitID.rawValue)"),
      visitID: visitID,
      occurredAt: instant(2),
      source: .watch
    ),
    .selectRoute(routeID),
    .recordAttempt(
      actionID: ActionID("basic-attempt-\(attemptID.rawValue)"),
      attemptID: attemptID,
      occurredAt: instant(3),
      source: .watch
    ),
  ]
}

private func basicFailedAttemptCommands(
  routeID: RouteCardID,
  visitID: GymVisitID,
  attemptID: AttemptID
) -> [LineWiseAppIntent] {
  basicAttemptCommands(routeID: routeID, visitID: visitID, attemptID: attemptID)
    + [
      .confirmNotSent(
        actionID: ActionID("basic-not-sent-\(attemptID.rawValue)"),
        attemptID: attemptID,
        occurredAt: instant(4),
        source: .iPhone
      )
    ]
}

private func approvedDrill() -> MicroDrill {
  MicroDrill(
    id: MicroDrillID("drill-hip-position"),
    title: "Hip position rehearsal",
    target: "body position",
    routeContext: "vertical or slight overhang",
    instructions: "Pause with the hip close before the hand move.",
    successCriterion: "Complete three controlled repetitions.",
    source: .lineWiseEditorial,
    sourceReference: "linewise-core-drills",
    version: "1",
    approvalState: .approved
  )
}

private func makeRehearsalEngine(
  id: RouteRehearsalID = RouteRehearsalID("rehearsal-experience")
) throws -> RouteRehearsalEngine {
  let start = HoldID("hold-start")
  let finish = HoldID("hold-finish")
  let scene = RouteScene(
    id: RouteSceneID("scene-experience"),
    name: "Purple compression",
    size: SceneSize(width: 1, height: 1),
    metersPerSceneUnit: 2.5,
    holds: [
      Hold(id: start, center: Point2D(x: 0.35, y: 0.2), radius: 0.05, routeRole: .start),
      Hold(id: finish, center: Point2D(x: 0.6, y: 0.75), radius: 0.05, routeRole: .top),
    ]
  )
  let unknown = Limb.allCases.map { LimbContact.unknown($0) }
  let plan = [
    PoseKeyframe(
      id: PoseKeyframeID("plan-start-\(id.rawValue)"),
      label: "Plan start",
      torsoPosition: Point2D(x: 0.45, y: 0.3),
      contacts: unknown,
      provenance: .manual
    ),
    PoseKeyframe(
      id: PoseKeyframeID("plan-finish-\(id.rawValue)"),
      label: "Plan finish",
      torsoPosition: Point2D(x: 0.52, y: 0.6),
      contacts: unknown,
      provenance: .manual
    ),
  ]
  let actual = [
    PoseKeyframe(
      id: PoseKeyframeID("actual-start-\(id.rawValue)"),
      label: "Actual start",
      torsoPosition: Point2D(x: 0.44, y: 0.3),
      contacts: unknown,
      provenance: RehearsalProvenance(
        authorship: .observed,
        automation: .manual,
        providerIdentifier: "user-observation",
        version: "1"
      )
    ),
    PoseKeyframe(
      id: PoseKeyframeID("actual-finish-\(id.rawValue)"),
      label: "Actual finish",
      torsoPosition: Point2D(x: 0.56, y: 0.58),
      contacts: unknown,
      provenance: RehearsalProvenance(
        authorship: .observed,
        automation: .manual,
        providerIdentifier: "user-observation",
        version: "1"
      )
    ),
  ]
  return try RouteRehearsalEngine(
    rehearsalID: id,
    scene: scene,
    bodyProfile: .generic(id: BodyProfileID("body-experience")),
    planKeyframes: plan,
    actualKeyframes: actual
  )
}

private func instant(_ value: Int64) -> Instant {
  Instant(millisecondsSince1970: value * 1_000)
}
