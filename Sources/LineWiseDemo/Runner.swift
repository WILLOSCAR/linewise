import Foundation
import LineWiseApplication
import LineWiseDomain

private struct DemoSummary: Codable {
  let routeCards: Int
  let visits: Int
  let attempts: Int
  let failureEpisodes: Int
  let moveCues: Int
  let nextSessionCues: Int
  let reopenedCues: Int
  let physiologyContexts: Int
  let rehearsals: Int
  let planFrames: Int
  let actualFrames: Int
  let alignedPlanActualSteps: Int
  let stickFigureCueSteps: Int
  let learningArtifactIsSuggested: Bool
  let qualitativeAnalysisIsSuggested: Bool
  let setterLensIsUserConfirmed: Bool
  let trainingPathIsCompleted: Bool
  let proofCheckUsesLaterAttempt: Bool
  let comparisonMakesSafetyClaim: Bool
  let synchronizedEvents: Int
  let duplicateEventsSuppressed: Int
}

private enum DemoFailure: Error, CustomStringConvertible {
  case rejected(String)

  var description: String {
    switch self {
    case .rejected(let message): message
    }
  }
}

@main
struct LineWiseDemo {
  static func main() throws {
    let watchStore = MemoryVisitEventStore()
    let watchRepository = try VisitRepository(
      store: watchStore,
      localDeviceID: DeviceID("watch-demo")
    )
    var experience = try PersistentLineWiseExperienceCoordinator(
      store: MemoryExperienceArchiveStore(),
      repository: watchRepository,
      microDrillCatalog: .lineWiseEditorialV0
    )

    let routeID = RouteCardID("route-demo-purple")
    let projectID = ProjectID("project-demo-purple")
    let firstVisitID = GymVisitID("visit-demo-1")
    let secondVisitID = GymVisitID("visit-demo-2")
    let attemptID = AttemptID("attempt-demo-1")

    try accept(
      &experience,
      .createRoute(
        actionID: ActionID("demo-create-route"),
        routeCardID: routeID,
        label: "Purple compression",
        availability: .present,
        occurredAt: instant(1),
        source: .iPhone
      ))
    try accept(
      &experience,
      .startProject(
        actionID: ActionID("demo-start-project"),
        projectID: projectID,
        routeCardID: routeID,
        occurredAt: instant(2),
        source: .iPhone
      ))
    try accept(
      &experience,
      .startVisit(
        actionID: ActionID("demo-start-visit-1"),
        visitID: firstVisitID,
        occurredAt: instant(3),
        source: .watch
      ))
    try accept(&experience, .selectRoute(routeID))
    try accept(
      &experience,
      .recordAttempt(
        actionID: ActionID("demo-attempt"),
        attemptID: attemptID,
        occurredAt: instant(4),
        source: .watch
      ))
    try accept(
      &experience,
      .confirmNotSent(
        actionID: ActionID("demo-not-sent"),
        attemptID: attemptID,
        occurredAt: instant(5),
        source: .iPhone
      ))
    try accept(
      &experience,
      .startRest(
        actionID: ActionID("demo-rest-start"),
        restID: RestIntervalID("rest-demo"),
        afterAttemptID: attemptID,
        occurredAt: instant(6)
      ))
    try accept(
      &experience,
      .stopRest(
        actionID: ActionID("demo-rest-stop"),
        restID: RestIntervalID("rest-demo"),
        occurredAt: instant(7)
      ))
    try accept(
      &experience,
      .endVisit(
        actionID: ActionID("demo-end-visit-1"),
        occurredAt: instant(8),
        source: .watch
      ))
    try accept(
      &experience,
      .beginReview(
        actionID: ActionID("demo-begin-review"),
        visitID: firstVisitID,
        occurredAt: instant(9),
        source: .iPhone
      ))

    let review = try experience.completeFailureReview(
      FailureReviewRequest(
        failureActionID: ActionID("demo-failure"),
        moveCueActionID: ActionID("demo-move-cue"),
        nextSessionCueActionID: ActionID("demo-next-cue"),
        episodeID: FailureEpisodeID("failure-demo"),
        attemptID: attemptID,
        routeCardID: routeID,
        primaryBlocker: .bodyPosition,
        locationNote: "Third hand move",
        moveCueID: MoveCueID("move-cue-demo"),
        moveCueText: "Bring the left hip in before moving the right hand",
        nextSessionCueID: NextSessionCueID("next-cue-demo"),
        projectID: projectID,
        nextAction: "Try the hip-first sequence once before adding power",
        occurredAt: instant(10)
      ))
    guard review == .accepted else {
      throw DemoFailure.rejected("failure review rejected: \(review)")
    }

    let physiology = try experience.recordPhysiology(
      contextID: PhysiologyContextID("physiology-demo"),
      visitID: firstVisitID,
      subjective: SubjectivePhysiologyCheckIn(
        sessionEffort1To10: 7,
        wholeBodyFatigue0To10: 5,
        forearmPumpOverall: .strong
      ),
      healthKitSummary: nil,
      recordedAt: instant(11)
    )
    guard physiology.isAccepted else {
      throw DemoFailure.rejected("physiology rejected: \(physiology)")
    }

    let rehearsal = try demoRehearsal()
    let attached = try experience.attachRehearsal(
      rehearsal,
      routeCardID: routeID,
      plannedVisitID: firstVisitID,
      actualAttemptID: attemptID
    )
    guard attached == .accepted else {
      throw DemoFailure.rejected("rehearsal association rejected: \(attached)")
    }

    try accept(
      &experience,
      .completeReview(
        actionID: ActionID("demo-complete-review"),
        visitID: firstVisitID,
        occurredAt: instant(12),
        source: .iPhone
      ))
    try accept(
      &experience,
      .startVisit(
        actionID: ActionID("demo-start-visit-2"),
        visitID: secondVisitID,
        occurredAt: instant(13),
        source: .watch
      ))

    let rehearsalProjection = try require(
      experience.projection.rehearsals.first?.rehearsal,
      "expected attached rehearsal"
    )
    let comparison = RehearsalCompare.align(
      rehearsal: rehearsalProjection,
      planTimelineVersion: "demo-plan-v1",
      actualTimelineVersion: "demo-actual-v1"
    )
    let stickFigureCue: StickFigureCue?
    if !comparison.alignedSteps.isEmpty {
      stickFigureCue = try RehearsalCompare.makeStickFigureCue(
        id: StickFigureCueID("stick-cue-demo"),
        comparison: comparison,
        alignedStepRange: 0...0,
        preferredTrack: .plan,
        pin: StickFigureCuePin(
          scene: comparison.sceneSnapshot,
          bodyProfile: comparison.bodyProfileSnapshot,
          timelineVersion: comparison.planTimelineVersion
        )
      )
    } else {
      stickFigureCue = nil
    }
    let suggestedArtifacts = stickFigureCue.map {
      RehearsalCompare.suggestLearningArtifacts(from: $0, routeCardID: routeID)
    }
    let qualitativeRequest = QualitativeRouteAnalysisRequest(
      routeCardID: routeID,
      routeScene: rehearsalProjection.scene,
      routeSceneVersion: "demo-scene-v1",
      bodyProfile: rehearsalProjection.bodyProfile,
      bodyProfileVersion: "demo-body-v1",
      rehearsalComparison: comparison,
      stickFigureCue: stickFigureCue,
      confirmedFailureEpisodes: experience.projection.recall.failureEpisodes,
      confirmedMoveCues: experience.projection.recall.moveCues
    )
    let qualitativeResult = try DeterministicLocalQualitativeRouteAnalysisProvider(
      algorithmVersion: "demo-x0"
    ).analyzeLocally(qualitativeRequest)
    let setterLensReadingID = SetterLensReadingID("setter-lens-demo")
    try acceptLearning(
      &experience,
      try QualitativeSetterLensBridge.suggestSetterLensReading(
        from: qualitativeResult,
        request: qualitativeRequest,
        actionID: ActionID("demo-suggest-setter-lens"),
        readingID: setterLensReadingID,
        occurredAt: instant(14)
      )
    )
    try acceptLearning(
      &experience,
      .acceptSetterLensReading(
        actionID: ActionID("demo-accept-setter-lens"),
        readingID: setterLensReadingID,
        interpretationOverride: nil,
        occurredAt: instant(15)
      )
    )

    let drillID = try require(
      experience.projection.approvedMicroDrills.first?.id,
      "expected approved editorial MicroDrill"
    )
    let trainingPathID = TrainingPathID("training-path-demo")
    try acceptLearning(
      &experience,
      .draftTrainingPath(
        actionID: ActionID("demo-draft-training-path"),
        pathID: trainingPathID,
        failureEpisodeID: FailureEpisodeID("failure-demo"),
        moveCueID: MoveCueID("move-cue-demo"),
        microDrillID: drillID,
        nextSessionCueID: NextSessionCueID("next-cue-demo"),
        proofQuestion: "Did the hip move before the right hand?",
        occurredAt: instant(16)
      )
    )
    try acceptLearning(
      &experience,
      .activateTrainingPath(
        actionID: ActionID("demo-activate-training-path"),
        pathID: trainingPathID,
        occurredAt: instant(17)
      )
    )
    let proofAttemptID = AttemptID("attempt-demo-proof")
    try accept(
      &experience,
      .recordAttempt(
        actionID: ActionID("demo-proof-attempt"),
        attemptID: proofAttemptID,
        occurredAt: instant(18),
        source: .watch
      )
    )
    try acceptLearning(
      &experience,
      .recordProofCheck(
        actionID: ActionID("demo-proof-check"),
        proofCheckID: ProofCheckID("proof-check-demo"),
        pathID: trainingPathID,
        attemptID: proofAttemptID,
        outcome: .triedTargetBehaviorChanged,
        decision: .retain,
        note: "The hip moved first on the later recorded Attempt.",
        occurredAt: instant(19)
      )
    )
    try acceptLearning(
      &experience,
      .completeTrainingPath(
        actionID: ActionID("demo-complete-training-path"),
        pathID: trainingPathID,
        occurredAt: instant(20)
      )
    )

    let phoneRepository = try VisitRepository(
      store: MemoryVisitEventStore(),
      localDeviceID: DeviceID("iphone-demo")
    )
    let outbound = watchRepository.pendingOutboundEvents
    let firstReceipt = try phoneRepository.receive(Array(outbound.reversed()))
    let duplicateReceipt = try phoneRepository.receive(outbound)

    let projection = experience.projection
    let summary = DemoSummary(
      routeCards: projection.capture.routeCards.count,
      visits: projection.capture.visits.count,
      attempts: projection.capture.attempts.count,
      failureEpisodes: projection.recall.failureEpisodes.count,
      moveCues: projection.recall.moveCues.count,
      nextSessionCues: projection.recall.nextSessionCues.count,
      reopenedCues: projection.reopenedNextSessionCues.count,
      physiologyContexts: projection.physiologyContexts.count,
      rehearsals: projection.rehearsals.count,
      planFrames: rehearsalProjection.plan.keyframes.count,
      actualFrames: rehearsalProjection.actual.keyframes.count,
      alignedPlanActualSteps: comparison.alignedSteps.count,
      stickFigureCueSteps: stickFigureCue?.steps.count ?? 0,
      learningArtifactIsSuggested: suggestedArtifacts?.moveCue.status == .suggested,
      qualitativeAnalysisIsSuggested: qualitativeResult.provenance.authorship == .suggested,
      setterLensIsUserConfirmed: projection.learning.setterLensReadings.first?.status
        == .userConfirmed,
      trainingPathIsCompleted: projection.learning.trainingPaths.first?.status == .completed,
      proofCheckUsesLaterAttempt: projection.learning.proofChecks.first?.attemptID
        == proofAttemptID,
      comparisonMakesSafetyClaim: stickFigureCue?.isSafetyJudgment ?? false,
      synchronizedEvents: firstReceipt.insertedEventIDs.count,
      duplicateEventsSuppressed: duplicateReceipt.duplicateEventIDs.count
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(summary))
    FileHandle.standardOutput.write(Data("\n".utf8))
  }

  private static func accept(
    _ experience: inout PersistentLineWiseExperienceCoordinator,
    _ intent: LineWiseAppIntent
  ) throws {
    let feedback = try experience.handle(intent)
    guard feedback.isSuccess else {
      throw DemoFailure.rejected("intent rejected: \(intent) -> \(feedback.outcome)")
    }
  }

  private static func acceptLearning(
    _ experience: inout PersistentLineWiseExperienceCoordinator,
    _ command: LearningLoopCommand
  ) throws {
    let outcome = try experience.submitLearning(command)
    guard outcome == .accepted || outcome == .duplicate else {
      throw DemoFailure.rejected("learning command rejected: \(command) -> \(outcome)")
    }
  }

  private static func require<Value>(_ value: Value?, _ message: String) throws -> Value {
    guard let value else { throw DemoFailure.rejected(message) }
    return value
  }

  private static func demoRehearsal() throws -> RouteRehearsalEngine {
    let lowerLeft = HoldID("demo-lower-left")
    let lowerRight = HoldID("demo-lower-right")
    let upperLeft = HoldID("demo-upper-left")
    let top = HoldID("demo-top")
    let scene = RouteScene(
      id: RouteSceneID("scene-demo"),
      name: "Purple compression",
      size: SceneSize(width: 100, height: 180),
      metersPerSceneUnit: 0.025,
      holds: [
        Hold(id: lowerLeft, center: Point2D(x: 28, y: 22), radius: 5, routeRole: .start),
        Hold(id: lowerRight, center: Point2D(x: 62, y: 25), radius: 5, routeRole: .start),
        Hold(id: upperLeft, center: Point2D(x: 32, y: 92), radius: 5),
        Hold(id: top, center: Point2D(x: 58, y: 155), radius: 6, routeRole: .top),
      ]
    )
    let planStart = PoseKeyframe(
      id: PoseKeyframeID("demo-plan-start"),
      label: "Start",
      torsoPosition: Point2D(x: 45, y: 48),
      contacts: [
        LimbContact(limb: .leftFoot, target: .hold(lowerLeft), mode: .foot),
        LimbContact(limb: .rightFoot, target: .hold(lowerRight), mode: .foot),
        LimbContact(limb: .leftHand, target: .hold(upperLeft), mode: .hand),
        LimbContact(limb: .rightHand, target: .hold(lowerRight), mode: .hand),
      ],
      provenance: .manual
    )
    let planFinish = PoseKeyframe(
      id: PoseKeyframeID("demo-plan-finish"),
      label: "Reach top",
      torsoPosition: Point2D(x: 49, y: 112),
      contacts: [
        LimbContact(limb: .leftFoot, target: .hold(lowerLeft), mode: .foot),
        LimbContact(limb: .rightFoot, target: .hold(lowerRight), mode: .foot),
        LimbContact(limb: .leftHand, target: .hold(upperLeft), mode: .hand),
        LimbContact(limb: .rightHand, target: .hold(top), mode: .hand),
      ],
      provenance: .manual
    )
    let observed = RehearsalProvenance(
      authorship: .observed,
      automation: .manual,
      providerIdentifier: "user-observation",
      version: "1"
    )
    let actualStart = PoseKeyframe(
      id: PoseKeyframeID("demo-actual-start"),
      label: "Observed start",
      torsoPosition: Point2D(x: 45, y: 48),
      contacts: planStart.contacts,
      provenance: observed
    )
    let actualCrux = PoseKeyframe(
      id: PoseKeyframeID("demo-actual-crux"),
      label: "Observed crux",
      torsoPosition: Point2D(x: 54, y: 96),
      contacts: planFinish.contacts,
      provenance: observed
    )
    return try RouteRehearsalEngine(
      rehearsalID: RouteRehearsalID("rehearsal-demo"),
      scene: scene,
      bodyProfile: .generic(id: BodyProfileID("body-demo")),
      planKeyframes: [planStart, planFinish],
      actualKeyframes: [actualStart, actualCrux]
    )
  }

  private static func instant(_ seconds: Int64) -> Instant {
    Instant(millisecondsSince1970: seconds * 1_000)
  }
}
