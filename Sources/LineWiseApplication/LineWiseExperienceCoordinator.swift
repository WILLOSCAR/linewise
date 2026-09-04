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
  case routeReadMustBeSuggested
  case confirmedStartHoldDoesNotExist(HoldID)
  case invalidRouteReadResult(RouteRehearsalError)
}

public enum RehearsalAssociationOutcome: Equatable, Sendable {
  case accepted
  case rejected(RehearsalAssociationRejection)
}

public struct RouteRehearsalAssociationSnapshot: Equatable, Codable, Sendable {
  public let routeCardID: RouteCardID
  public let plannedVisitID: GymVisitID?
  public let actualAttemptID: AttemptID?
  public let routeReadProvenance: RehearsalProvenance
  public let rehearsal: RouteRehearsal

  public init(
    routeCardID: RouteCardID,
    plannedVisitID: GymVisitID?,
    actualAttemptID: AttemptID?,
    routeReadProvenance: RehearsalProvenance = .manual,
    rehearsal: RouteRehearsal
  ) {
    self.routeCardID = routeCardID
    self.plannedVisitID = plannedVisitID
    self.actualAttemptID = actualAttemptID
    self.routeReadProvenance = routeReadProvenance
    self.rehearsal = rehearsal
  }

  private enum CodingKeys: String, CodingKey {
    case routeCardID
    case plannedVisitID
    case actualAttemptID
    case routeReadProvenance
    case rehearsal
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    routeCardID = try container.decode(RouteCardID.self, forKey: .routeCardID)
    plannedVisitID = try container.decodeIfPresent(GymVisitID.self, forKey: .plannedVisitID)
    actualAttemptID = try container.decodeIfPresent(AttemptID.self, forKey: .actualAttemptID)
    routeReadProvenance =
      try container.decodeIfPresent(RehearsalProvenance.self, forKey: .routeReadProvenance)
      ?? .manual
    rehearsal = try container.decode(RouteRehearsal.self, forKey: .rehearsal)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(routeCardID, forKey: .routeCardID)
    try container.encodeIfPresent(plannedVisitID, forKey: .plannedVisitID)
    try container.encodeIfPresent(actualAttemptID, forKey: .actualAttemptID)
    try container.encode(routeReadProvenance, forKey: .routeReadProvenance)
    try container.encode(rehearsal, forKey: .rehearsal)
  }
}

public enum LineWiseExperienceWarning: Equatable, Sendable {
  case nextSessionCueReopenRejected(
    cueID: NextSessionCueID,
    reason: RecallTrainingRejection
  )
}

public struct ReviewInboxReconciliationSummary: Equatable, Sendable {
  public let enqueuedItemIDs: [ReviewInboxItemID]

  public init(enqueuedItemIDs: [ReviewInboxItemID]) {
    self.enqueuedItemIDs = enqueuedItemIDs
  }
}

public enum ReviewInboxReconciliationError: Error, Equatable, Sendable,
  CustomStringConvertible
{
  case enqueueRejected(sourceKey: String, reason: RecallTrainingRejection)

  public var description: String {
    switch self {
    case .enqueueRejected(let sourceKey, let reason):
      "Could not reconcile Review Inbox source \(sourceKey): \(reason)"
    }
  }
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
    let routeReadProvenance: RehearsalProvenance
    var engine: RouteRehearsalEngine

    var snapshot: RouteRehearsalAssociationSnapshot {
      RouteRehearsalAssociationSnapshot(
        routeCardID: routeCardID,
        plannedVisitID: plannedVisitID,
        actualAttemptID: actualAttemptID,
        routeReadProvenance: routeReadProvenance,
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
        routeReadProvenance: association.routeReadProvenance,
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

  /// Whether capture commands reach a durable `VisitRepository` rather than
  /// living only in this value's in-memory state. The persistence wrapper needs
  /// this to know whether a failed archive save can safely roll a capture back.
  var hasPersistentVisitRepository: Bool {
    appCoordinator.hasPersistentVisitRepository
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
    let outcome = appCoordinator.receive(envelopes)
    guard case .received = outcome else {
      return outcome
    }
    // The Watch owns starting a Visit, so that start usually arrives here rather
    // than through `handle`. Cue reopening must follow the Visit itself, not the
    // code path that delivered it, or the recall loop skips exactly the sessions
    // the product is designed for. Reopening is idempotent per visit, so a
    // redelivered envelope does not resurface an already-reopened cue.
    for envelope in envelopes {
      if case .startVisit(_, let visitID, let occurredAt, _) = envelope.command {
        reopenEligibleCues(in: visitID, at: occurredAt)
      }
    }
    return outcome
  }

  /// Rebuilds the user-decision queue from durable capture state without
  /// reopening sources the user already resolved or dismissed.
  @discardableResult
  public mutating func reconcileReviewInboxFromCapture() throws
    -> ReviewInboxReconciliationSummary
  {
    let capture = appCoordinator.projection
    let reviewableVisitIDs = Set(
      capture.visits.compactMap { visit -> GymVisitID? in
        guard visit.captureState == .ended else { return nil }
        switch visit.reviewState {
        case .pendingReview, .reviewing, .needsRecheck:
          return visit.id
        case .notReady, .reviewed:
          return nil
        }
      }
    )
    let trackedSourceKeys = Set(recallTrainingState.snapshot.reviewItems.map(\.sourceKey))
    var proposedRecallState = recallTrainingState
    var newlyTrackedSourceKeys: Set<String> = []
    var enqueuedItemIDs: [ReviewInboxItemID] = []

    for attempt in capture.attempts
    where attempt.recordState == .active && reviewableVisitIDs.contains(attempt.visitID) {
      var candidates: [(suffix: String, kind: ReviewInboxItemKind)] = []
      if attempt.routeCardID == nil {
        candidates.append(("unassigned", .unassignedAttempt(attempt.id)))
      }
      if attempt.outcome == .unresolved {
        candidates.append(("unresolved", .unresolvedAttempt(attempt.id)))
      }

      for candidate in candidates {
        let sourceKey = "attempt/\(attempt.id.rawValue)/\(candidate.suffix)"
        guard
          !trackedSourceKeys.contains(sourceKey),
          !newlyTrackedSourceKeys.contains(sourceKey)
        else { continue }
        let itemID = ReviewInboxItemID("\(candidate.suffix)/\(attempt.id.rawValue)")
        let transition = RecallTraining.apply(
          .enqueueReviewItem(
            actionID: ActionID("experience.reconcile-review/\(sourceKey)"),
            itemID: itemID,
            sourceKey: sourceKey,
            visitID: attempt.visitID,
            kind: candidate.kind,
            occurredAt: attempt.occurredAt
          ),
          visitSnapshot: visitSnapshotForRecall,
          to: proposedRecallState
        )
        switch transition.outcome {
        case .accepted:
          proposedRecallState = transition.state
          newlyTrackedSourceKeys.insert(sourceKey)
          enqueuedItemIDs.append(itemID)
        case .duplicate:
          proposedRecallState = transition.state
          newlyTrackedSourceKeys.insert(sourceKey)
        case .rejected(let reason):
          throw ReviewInboxReconciliationError.enqueueRejected(
            sourceKey: sourceKey,
            reason: reason
          )
        }
      }
    }

    recallTrainingState = proposedRecallState
    return ReviewInboxReconciliationSummary(enqueuedItemIDs: enqueuedItemIDs)
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
    let transition = LearningLoop.apply(
      command,
      visitSnapshot: visitSnapshotForRecall,
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
    actualAttemptID: AttemptID? = nil,
    routeReadProvenance: RehearsalProvenance = .manual
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
      routeReadProvenance: routeReadProvenance,
      engine: engine
    )
    return .accepted
  }

  /// Creates an editable suggested rehearsal from a media route read without inventing observed
  /// movement. Suggested start holds become contacts only when their IDs were separately confirmed.
  @discardableResult
  public mutating func attachRouteReadResult(
    _ result: RouteReadResult,
    routeCardID: RouteCardID,
    rehearsalID: RouteRehearsalID,
    bodyProfile: BodyProfile,
    confirmedStartHoldIDs: [HoldID] = [],
    plannedVisitID: GymVisitID? = nil
  ) -> RehearsalAssociationOutcome {
    guard result.provenance.authorship == .suggested else {
      return .rejected(.routeReadMustBeSuggested)
    }
    let uniqueConfirmedStarts = confirmedStartHoldIDs.reduce(into: [HoldID]()) {
      if !$0.contains($1) { $0.append($1) }
    }
    for holdID in uniqueConfirmedStarts where result.scene.hold(id: holdID) == nil {
      return .rejected(.confirmedStartHoldDoesNotExist(holdID))
    }

    let contacts = Self.suggestedStarterContacts(confirmedStartHoldIDs: uniqueConfirmedStarts)
    let confirmedHolds = uniqueConfirmedStarts.compactMap(result.scene.hold)
    let torsoPosition: Point2D
    if confirmedHolds.isEmpty {
      torsoPosition = Point2D(
        x: result.scene.size.width / 2,
        y: result.scene.size.height / 2
      )
    } else {
      torsoPosition = Point2D(
        x: confirmedHolds.map(\.center.x).reduce(0, +) / Double(confirmedHolds.count),
        y: confirmedHolds.map(\.center.y).reduce(0, +) / Double(confirmedHolds.count)
      )
    }
    let starter = PoseKeyframe(
      id: PoseKeyframeID("\(rehearsalID.rawValue)/suggested-start"),
      label: "Suggested start draft",
      torsoPosition: torsoPosition,
      contacts: contacts,
      provenance: result.provenance
    )
    do {
      let engine = try RouteRehearsalEngine(
        rehearsalID: rehearsalID,
        scene: result.scene,
        bodyProfile: bodyProfile,
        planKeyframes: [starter]
      )
      return attachRehearsal(
        engine,
        routeCardID: routeCardID,
        plannedVisitID: plannedVisitID,
        routeReadProvenance: result.provenance
      )
    } catch let error as RouteRehearsalError {
      return .rejected(.invalidRouteReadResult(error))
    } catch {
      return .rejected(.invalidRouteReadResult(.emptyPlan))
    }
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
        // An open-ended deferral means "not this visit", so it becomes due at the next
        // one. Treating a missing deadline as never-due would strand the cue forever.
        return cue.deferredUntil.map { $0 <= occurredAt } ?? true
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

  private static func suggestedStarterContacts(
    confirmedStartHoldIDs: [HoldID]
  ) -> [LimbContact] {
    var contacts = Limb.allCases.map(LimbContact.unknown)
    guard let first = confirmedStartHoldIDs.first else { return contacts }
    contacts[0] = LimbContact(
      limb: .leftHand,
      target: .hold(first),
      mode: confirmedStartHoldIDs.count == 1 ? .match : .hand
    )
    contacts[1] = LimbContact(
      limb: .rightHand,
      target: .hold(confirmedStartHoldIDs.dropFirst().first ?? first),
      mode: confirmedStartHoldIDs.count == 1 ? .match : .hand
    )
    return contacts
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
