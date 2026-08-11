import LineWiseDomain

public enum FailureReviewStage: Equatable, Sendable {
  case failureEpisode
  case moveCue
  case nextSessionCue
}

public enum FailureReviewOutcome: Equatable, Sendable {
  case accepted
  case duplicate
  case rejected(stage: FailureReviewStage, reason: RecallTrainingRejection)
}

public struct FailureReviewRequest: Equatable, Sendable {
  public let failureActionID: ActionID
  public let moveCueActionID: ActionID
  public let nextSessionCueActionID: ActionID
  public let episodeID: FailureEpisodeID
  public let attemptID: AttemptID
  public let routeCardID: RouteCardID
  public let primaryBlocker: FailureBlocker
  public let locationNote: String?
  public let moveCueID: MoveCueID
  public let moveCueText: String
  public let nextSessionCueID: NextSessionCueID
  public let projectID: ProjectID
  public let nextAction: String
  public let occurredAt: Instant

  public init(
    failureActionID: ActionID,
    moveCueActionID: ActionID,
    nextSessionCueActionID: ActionID,
    episodeID: FailureEpisodeID,
    attemptID: AttemptID,
    routeCardID: RouteCardID,
    primaryBlocker: FailureBlocker,
    locationNote: String?,
    moveCueID: MoveCueID,
    moveCueText: String,
    nextSessionCueID: NextSessionCueID,
    projectID: ProjectID,
    nextAction: String,
    occurredAt: Instant
  ) {
    self.failureActionID = failureActionID
    self.moveCueActionID = moveCueActionID
    self.nextSessionCueActionID = nextSessionCueActionID
    self.episodeID = episodeID
    self.attemptID = attemptID
    self.routeCardID = routeCardID
    self.primaryBlocker = primaryBlocker
    self.locationNote = locationNote
    self.moveCueID = moveCueID
    self.moveCueText = moveCueText
    self.nextSessionCueID = nextSessionCueID
    self.projectID = projectID
    self.nextAction = nextAction
    self.occurredAt = occurredAt
  }
}

public enum PhysiologyRecordingRejection: Equatable, Sendable {
  case visitDoesNotExist
  case contextAlreadyExists
  case invalidContext(PhysiologyContextRejection)
}

public enum PhysiologyRecordingOutcome: Equatable, Sendable {
  case accepted(PhysiologyContextSnapshot)
  case rejected(PhysiologyRecordingRejection)

  public var isAccepted: Bool {
    if case .accepted = self {
      return true
    }
    return false
  }
}

public enum RehearsalAssociationRejection: Error, Equatable, Sendable {
  case rehearsalAlreadyExists
  case rehearsalDoesNotExist
  case routeDoesNotExist
  case visitDoesNotExist
  case attemptDoesNotExist
  case attemptRouteMismatch
  case attemptVisitMismatch
  case actualTrackRequiresAttempt
}

public enum RehearsalAssociationOutcome: Equatable, Sendable {
  case accepted
  case rejected(RehearsalAssociationRejection)
}

public struct RouteRehearsalAssociationSnapshot: Equatable, Codable, Sendable {
  public let routeCardID: RouteCardID
  public let plannedVisitID: GymVisitID?
  public let actualAttemptID: AttemptID?
  public let rehearsal: RouteRehearsal

  public init(
    routeCardID: RouteCardID,
    plannedVisitID: GymVisitID?,
    actualAttemptID: AttemptID?,
    rehearsal: RouteRehearsal
  ) {
    self.routeCardID = routeCardID
    self.plannedVisitID = plannedVisitID
    self.actualAttemptID = actualAttemptID
    self.rehearsal = rehearsal
  }
}

public enum LineWiseExperienceWarning: Equatable, Sendable {
  case nextSessionCueReopenRejected(
    cueID: NextSessionCueID,
    reason: RecallTrainingRejection
  )
}

public struct LineWiseExperienceProjection: Equatable, Sendable {
  public let capture: LineWiseAppProjection
  public let recall: RecallTrainingSnapshot
  public let learning: LearningLoopSnapshot
  public let approvedMicroDrills: [MicroDrill]
  public let physiologyContexts: [PhysiologyContextSnapshot]
  public let rehearsals: [RouteRehearsalAssociationSnapshot]
  public let reopenedNextSessionCues: [NextSessionCueSnapshot]
  public let warnings: [LineWiseExperienceWarning]

  public init(
    capture: LineWiseAppProjection,
    recall: RecallTrainingSnapshot,
    learning: LearningLoopSnapshot,
    approvedMicroDrills: [MicroDrill],
    physiologyContexts: [PhysiologyContextSnapshot],
    rehearsals: [RouteRehearsalAssociationSnapshot],
    reopenedNextSessionCues: [NextSessionCueSnapshot],
    warnings: [LineWiseExperienceWarning]
  ) {
    self.capture = capture
    self.recall = recall
    self.learning = learning
    self.approvedMicroDrills = approvedMicroDrills
    self.physiologyContexts = physiologyContexts
    self.rehearsals = rehearsals
    self.reopenedNextSessionCues = reopenedNextSessionCues
    self.warnings = warnings
  }
}

public struct LineWiseExperienceCoordinator {
  private struct RehearsalRecord: Sendable {
    let routeCardID: RouteCardID
    let plannedVisitID: GymVisitID?
    let actualAttemptID: AttemptID?
    var engine: RouteRehearsalEngine

    var snapshot: RouteRehearsalAssociationSnapshot {
      RouteRehearsalAssociationSnapshot(
        routeCardID: routeCardID,
        plannedVisitID: plannedVisitID,
        actualAttemptID: actualAttemptID,
        rehearsal: engine.rehearsal
      )
    }
  }

  private var appCoordinator: LineWiseAppCoordinator
  private var recallTrainingState: RecallTrainingState
  private var learningLoopState: LearningLoopState
  private let microDrillCatalog: ApprovedMicroDrillCatalog
  private var physiologyByID: [PhysiologyContextID: PhysiologyContextSnapshot]
  private var rehearsalsByID: [RouteRehearsalID: RehearsalRecord]
  private var warnings: [LineWiseExperienceWarning]

  public init(
    appCoordinator: LineWiseAppCoordinator = LineWiseAppCoordinator(),
    recallTrainingState: RecallTrainingState = RecallTrainingState(),
    learningLoopState: LearningLoopState = LearningLoopState(),
    microDrillCatalog: ApprovedMicroDrillCatalog = ApprovedMicroDrillCatalog(drills: []),
    physiologyContexts: [PhysiologyContextSnapshot] = []
  ) {
    self.appCoordinator = appCoordinator
    self.recallTrainingState = recallTrainingState
    self.learningLoopState = learningLoopState
    self.microDrillCatalog = microDrillCatalog
    physiologyByID = physiologyContexts.reduce(into: [:]) { result, context in
      result[context.id] = context
    }
    rehearsalsByID = [:]
    warnings = []
  }

  public init(
    repository: VisitRepository,
    recallTrainingState: RecallTrainingState = RecallTrainingState(),
    learningLoopState: LearningLoopState = LearningLoopState(),
    microDrillCatalog: ApprovedMicroDrillCatalog = ApprovedMicroDrillCatalog(drills: []),
    physiologyContexts: [PhysiologyContextSnapshot] = []
  ) {
    self.init(
      appCoordinator: LineWiseAppCoordinator(repository: repository),
      recallTrainingState: recallTrainingState,
      learningLoopState: learningLoopState,
      microDrillCatalog: microDrillCatalog,
      physiologyContexts: physiologyContexts
    )
  }

  init(
    restoring archive: LineWiseExperienceArchive,
    appCoordinator: LineWiseAppCoordinator,
    configuredMicroDrillCatalog: ApprovedMicroDrillCatalog
  ) throws {
    var restoredAppCoordinator = appCoordinator
    let restoredReversibleActionIDs =
      appCoordinator.hasPersistentVisitRepository
      ? appCoordinator.persistedReversibleActionIDs
      : archive.reversibleActionIDs
    restoredAppCoordinator.restorePersistedAppState(
      restState: archive.restState,
      selectedRouteCardID: archive.selectedRouteCardID,
      reversibleActionIDs: restoredReversibleActionIDs
    )
    self.appCoordinator = restoredAppCoordinator
    recallTrainingState = archive.recallTrainingState
    learningLoopState = archive.learningLoopState
    microDrillCatalog =
      configuredMicroDrillCatalog.approvedDrills.isEmpty
      ? archive.microDrillCatalog : configuredMicroDrillCatalog
    physiologyByID = Dictionary(
      uniqueKeysWithValues: archive.physiologyContexts.map { ($0.id, $0) }
    )
    rehearsalsByID = [:]
    for association in archive.rehearsalAssociations {
      let engine = try RouteRehearsalEngine(reopening: association.rehearsal)
      rehearsalsByID[association.rehearsal.id] = RehearsalRecord(
        routeCardID: association.routeCardID,
        plannedVisitID: association.plannedVisitID,
        actualAttemptID: association.actualAttemptID,
        engine: engine
      )
    }
    warnings = []
  }

  func makeArchive(
    provenance: ExperienceArchiveProvenance
  ) -> LineWiseExperienceArchive {
    LineWiseExperienceArchive(
      provenance: provenance,
      recallTrainingState: recallTrainingState,
      learningLoopState: learningLoopState,
      microDrillCatalog: microDrillCatalog,
      restState: appCoordinator.persistedRestState,
      selectedRouteCardID: appCoordinator.persistedSelectedRouteCardID,
      reversibleActionIDs: appCoordinator.persistedReversibleActionIDs,
      physiologyContexts: physiologyByID.values.sorted(by: physiologySortOrder),
      rehearsalAssociations: rehearsalsByID.values.map(\.snapshot).sorted {
        $0.rehearsal.id.rawValue < $1.rehearsal.id.rawValue
      }
    )
  }

  var captureCoordinatorForPersistence: LineWiseAppCoordinator {
    appCoordinator
  }

  mutating func resetPersistedExperienceData() {
    recallTrainingState = RecallTrainingState()
    learningLoopState = LearningLoopState()
    appCoordinator.restorePersistedAppState(
      restState: RestState(),
      selectedRouteCardID: appCoordinator.persistedSelectedRouteCardID,
      reversibleActionIDs: appCoordinator.persistedReversibleActionIDs
    )
    physiologyByID = [:]
    rehearsalsByID = [:]
    warnings = []
  }

  public var projection: LineWiseExperienceProjection {
    let capture = appCoordinator.projection
    let recall = recallTrainingState.snapshot
    let activeVisitID = capture.activeVisit?.id
    let reopened = recall.nextSessionCues.filter { cue in
      activeVisitID != nil && cue.reopenedInVisitID == activeVisitID
    }
    return LineWiseExperienceProjection(
      capture: capture,
      recall: recall,
      learning: learningLoopState.snapshot,
      approvedMicroDrills: microDrillCatalog.approvedDrills,
      physiologyContexts: physiologyByID.values.sorted(by: physiologySortOrder),
      rehearsals: rehearsalsByID.values.map(\.snapshot).sorted {
        $0.rehearsal.id.rawValue < $1.rehearsal.id.rawValue
      },
      reopenedNextSessionCues: reopened,
      warnings: warnings
    )
  }

  public var watchProjection: WatchCaptureProjection {
    appCoordinator.watchProjection
  }

  public var pendingOutboundEvents: [DeviceEventEnvelope] {
    appCoordinator.pendingOutboundEvents
  }

  @discardableResult
  public mutating func receive(
    _ envelopes: [DeviceEventEnvelope]
  ) -> LineWiseDeviceSyncOutcome {
    appCoordinator.receive(envelopes)
  }

  @discardableResult
  public mutating func acknowledgeOutbound(
    _ eventID: ActionID
  ) -> LineWiseDeviceSyncOutcome {
    appCoordinator.acknowledgeOutbound(eventID)
  }

  @discardableResult
  public mutating func handle(_ intent: LineWiseAppIntent) -> LineWiseAppFeedback {
    let feedback = appCoordinator.handle(intent)
    guard feedback.isSuccess else {
      return feedback
    }
    if case .startVisit(_, let visitID, let occurredAt, _) = intent {
      reopenEligibleCues(in: visitID, at: occurredAt)
    }
    return feedback
  }

  @discardableResult
  public mutating func submitRecall(_ command: RecallTrainingCommand) -> RecallTrainingOutcome {
    let transition = RecallTraining.apply(
      command,
      visitSnapshot: visitSnapshotForRecall,
      to: recallTrainingState
    )
    recallTrainingState = transition.state
    return transition.outcome
  }

  @discardableResult
  public mutating func completeFailureReview(
    _ request: FailureReviewRequest
  ) -> FailureReviewOutcome {
    let commands: [(FailureReviewStage, RecallTrainingCommand)] = [
      (
        .failureEpisode,
        .confirmFailureEpisode(
          actionID: request.failureActionID,
          episodeID: request.episodeID,
          attemptID: request.attemptID,
          routeCardID: request.routeCardID,
          primaryBlocker: request.primaryBlocker,
          locationNote: request.locationNote,
          occurredAt: request.occurredAt
        )
      ),
      (
        .moveCue,
        .createMoveCue(
          actionID: request.moveCueActionID,
          moveCueID: request.moveCueID,
          failureEpisodeID: request.episodeID,
          text: request.moveCueText,
          occurredAt: request.occurredAt
        )
      ),
      (
        .nextSessionCue,
        .createNextSessionCue(
          actionID: request.nextSessionCueActionID,
          cueID: request.nextSessionCueID,
          projectID: request.projectID,
          failureEpisodeID: request.episodeID,
          moveCueID: request.moveCueID,
          nextAction: request.nextAction,
          occurredAt: request.occurredAt
        )
      ),
    ]

    var proposed = recallTrainingState
    var duplicateCount = 0
    for (stage, command) in commands {
      let transition = RecallTraining.apply(
        command,
        visitSnapshot: visitSnapshotForRecall,
        to: proposed
      )
      switch transition.outcome {
      case .accepted:
        proposed = transition.state
      case .duplicate:
        duplicateCount += 1
        proposed = transition.state
      case .rejected(let reason):
        return .rejected(stage: stage, reason: reason)
      }
    }
    recallTrainingState = proposed
    return duplicateCount == commands.count ? .duplicate : .accepted
  }

  @discardableResult
  public mutating func submitLearning(_ command: LearningLoopCommand) -> LearningLoopOutcome {
    if case .recordProofCheck(_, _, let pathID, let attemptID, _, _, _, _) = command,
      let path = learningLoopState.snapshot.trainingPaths.first(where: { $0.id == pathID }),
      path.status == .active
    {
      guard
        let attempt = appCoordinator.projection.attempts.first(where: {
          $0.id == attemptID && $0.recordState == .active
        })
      else {
        return .rejected(.proofCheckAttemptDoesNotExist)
      }
      guard attempt.routeCardID == path.routeCardID else {
        return .rejected(.proofCheckAttemptRouteMismatch)
      }
      guard attempt.occurredAt > path.createdAt else {
        return .rejected(.proofCheckAttemptIsNotLaterThanPath)
      }
    }
    let transition = LearningLoop.apply(
      command,
      recallSnapshot: recallTrainingState.snapshot,
      catalog: microDrillCatalog,
      to: learningLoopState
    )
    learningLoopState = transition.state
    return transition.outcome
  }

  @discardableResult
  public mutating func recordPhysiology(
    contextID: PhysiologyContextID,
    visitID: GymVisitID,
    subjective: SubjectivePhysiologyCheckIn?,
    healthKitSummary: HealthKitWorkoutSummary?,
    recordedAt: Instant
  ) -> PhysiologyRecordingOutcome {
    guard appCoordinator.projection.visits.contains(where: { $0.id == visitID }) else {
      return .rejected(.visitDoesNotExist)
    }
    guard physiologyByID[contextID] == nil else {
      return .rejected(.contextAlreadyExists)
    }
    switch PhysiologyContextService.build(
      contextID: contextID,
      visitID: visitID,
      subjective: subjective,
      healthKitSummary: healthKitSummary,
      recordedAt: recordedAt
    ) {
    case .built(let context):
      physiologyByID[contextID] = context
      return .accepted(context)
    case .rejected(let reason):
      return .rejected(.invalidContext(reason))
    }
  }

  @discardableResult
  public mutating func attachRehearsal(
    _ engine: RouteRehearsalEngine,
    routeCardID: RouteCardID,
    plannedVisitID: GymVisitID? = nil,
    actualAttemptID: AttemptID? = nil
  ) -> RehearsalAssociationOutcome {
    let rehearsalID = engine.rehearsal.id
    guard rehearsalsByID[rehearsalID] == nil else {
      return .rejected(.rehearsalAlreadyExists)
    }
    if let rejection = validateRehearsalAssociation(
      engine,
      routeCardID: routeCardID,
      plannedVisitID: plannedVisitID,
      actualAttemptID: actualAttemptID
    ) {
      return .rejected(rejection)
    }
    rehearsalsByID[rehearsalID] = RehearsalRecord(
      routeCardID: routeCardID,
      plannedVisitID: plannedVisitID,
      actualAttemptID: actualAttemptID,
      engine: engine
    )
    return .accepted
  }

  @discardableResult
  public mutating func updateRehearsal(
    _ rehearsalID: RouteRehearsalID,
    edit: (inout RouteRehearsalEngine) throws -> Void
  ) throws -> RouteRehearsalAssociationSnapshot {
    guard var record = rehearsalsByID[rehearsalID] else {
      throw RehearsalAssociationRejection.rehearsalDoesNotExist
    }
    try edit(&record.engine)
    if !record.engine.rehearsal.actual.keyframes.isEmpty && record.actualAttemptID == nil {
      throw RehearsalAssociationRejection.actualTrackRequiresAttempt
    }
    rehearsalsByID[rehearsalID] = record
    return record.snapshot
  }

  private var visitSnapshotForRecall: VisitSnapshot {
    let capture = appCoordinator.projection
    return VisitSnapshot(
      visits: capture.visits,
      attempts: capture.attempts,
      routeCards: capture.routeCards,
      projects: capture.projects,
      pendingActionIDs: [],
      reconciliationIssues: []
    )
  }

  private mutating func reopenEligibleCues(in visitID: GymVisitID, at occurredAt: Instant) {
    let eligible = recallTrainingState.snapshot.nextSessionCues.filter { cue in
      guard cue.reopenedInVisitID != visitID else {
        return false
      }
      switch cue.status {
      case .ready:
        return true
      case .deferred:
        return cue.deferredUntil.map { $0 <= occurredAt } ?? false
      case .completed, .dismissed:
        return false
      }
    }

    for cue in eligible {
      let transition = RecallTraining.apply(
        .reopenNextSessionCue(
          actionID: ActionID("experience.auto-reopen/\(cue.id.rawValue)/\(visitID.rawValue)"),
          cueID: cue.id,
          visitID: visitID,
          occurredAt: occurredAt
        ),
        visitSnapshot: visitSnapshotForRecall,
        to: recallTrainingState
      )
      recallTrainingState = transition.state
      if case .rejected(let reason) = transition.outcome {
        let warning = LineWiseExperienceWarning.nextSessionCueReopenRejected(
          cueID: cue.id,
          reason: reason
        )
        if !warnings.contains(warning) {
          warnings.append(warning)
        }
      }
    }
  }

  private func validateRehearsalAssociation(
    _ engine: RouteRehearsalEngine,
    routeCardID: RouteCardID,
    plannedVisitID: GymVisitID?,
    actualAttemptID: AttemptID?
  ) -> RehearsalAssociationRejection? {
    let capture = appCoordinator.projection
    guard capture.routeCards.contains(where: { $0.id == routeCardID }) else {
      return .routeDoesNotExist
    }
    if let plannedVisitID,
      !capture.visits.contains(where: { $0.id == plannedVisitID })
    {
      return .visitDoesNotExist
    }
    if !engine.rehearsal.actual.keyframes.isEmpty && actualAttemptID == nil {
      return .actualTrackRequiresAttempt
    }
    if let actualAttemptID {
      guard let attempt = capture.attempts.first(where: { $0.id == actualAttemptID }) else {
        return .attemptDoesNotExist
      }
      guard attempt.routeCardID == routeCardID else {
        return .attemptRouteMismatch
      }
      if let plannedVisitID, attempt.visitID != plannedVisitID {
        return .attemptVisitMismatch
      }
    }
    return nil
  }
}

private func physiologySortOrder(
  _ lhs: PhysiologyContextSnapshot,
  _ rhs: PhysiologyContextSnapshot
) -> Bool {
  if lhs.recordedAt != rhs.recordedAt {
    return lhs.recordedAt < rhs.recordedAt
  }
  return lhs.id.rawValue < rhs.id.rawValue
}
