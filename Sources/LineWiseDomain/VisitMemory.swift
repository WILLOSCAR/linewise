public enum CaptureSource: String, Codable, Sendable {
  case watch
  case iPhone
}

public enum AttemptRecordState: String, Codable, Sendable {
  case active
  case retracted
}

public enum AttemptOutcome: String, Codable, Sendable {
  case unresolved
  case sent
  case notSent = "not_sent"
}

public enum GymVisitCaptureState: String, Codable, Sendable {
  case open
  case ended
  case voided
}

public enum GymVisitReviewState: String, Codable, Sendable {
  case notReady = "not_ready"
  case pendingReview = "pending_review"
  case reviewing
  case reviewed
  case needsRecheck = "needs_recheck"
}

public struct GymVisitSnapshot: Equatable, Codable, Sendable {
  public let id: GymVisitID
  public let startedAt: Instant
  public let endedAt: Instant?
  public let startedBy: CaptureSource
  public let captureState: GymVisitCaptureState
  public let reviewState: GymVisitReviewState

  public init(
    id: GymVisitID,
    startedAt: Instant,
    endedAt: Instant?,
    startedBy: CaptureSource,
    captureState: GymVisitCaptureState,
    reviewState: GymVisitReviewState
  ) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.startedBy = startedBy
    self.captureState = captureState
    self.reviewState = reviewState
  }
}

public struct AttemptSnapshot: Equatable, Codable, Sendable {
  public let id: AttemptID
  public let visitID: GymVisitID
  public let routeCardID: RouteCardID?
  public let occurredAt: Instant
  public let recordedBy: CaptureSource
  public let recordState: AttemptRecordState
  public let outcome: AttemptOutcome

  public init(
    id: AttemptID,
    visitID: GymVisitID,
    routeCardID: RouteCardID?,
    occurredAt: Instant,
    recordedBy: CaptureSource,
    recordState: AttemptRecordState,
    outcome: AttemptOutcome
  ) {
    self.id = id
    self.visitID = visitID
    self.routeCardID = routeCardID
    self.occurredAt = occurredAt
    self.recordedBy = recordedBy
    self.recordState = recordState
    self.outcome = outcome
  }
}

public struct VisitSnapshot: Equatable, Sendable {
  public let visits: [GymVisitSnapshot]
  public let attempts: [AttemptSnapshot]
  public let routeCards: [RouteCardSnapshot]
  public let projects: [ProjectSnapshot]
  public let pendingActionIDs: [ActionID]
  public let reconciliationIssues: [ReconciliationIssueSnapshot]

  public init(
    visits: [GymVisitSnapshot],
    attempts: [AttemptSnapshot],
    routeCards: [RouteCardSnapshot],
    projects: [ProjectSnapshot],
    pendingActionIDs: [ActionID],
    reconciliationIssues: [ReconciliationIssueSnapshot]
  ) {
    self.visits = visits
    self.attempts = attempts
    self.routeCards = routeCards
    self.projects = projects
    self.pendingActionIDs = pendingActionIDs
    self.reconciliationIssues = reconciliationIssues
  }

  public var activeAttempts: [AttemptSnapshot] {
    attempts.filter { $0.recordState == .active }
  }
}

public struct VisitState: Equatable, Sendable {
  var openVisitID: GymVisitID?
  var visitsByID: [GymVisitID: GymVisitSnapshot]
  var attemptsByID: [AttemptID: AttemptSnapshot]
  var routeCardsByID: [RouteCardID: RouteCardSnapshot]
  var projectsByID: [ProjectID: ProjectSnapshot]
  var appliedCommands: [ActionID: VisitCommand]
  var appliedEffects: [ActionID: AppliedEffect]
  var retractedActionIDs: Set<ActionID>
  var pendingCommands: [ActionID: VisitCommand]
  var pendingReasons: [ActionID: VisitDeferredReason]
  var reconciliationIssuesByActionID: [ActionID: ReconciliationIssueSnapshot]

  public init() {
    openVisitID = nil
    visitsByID = [:]
    attemptsByID = [:]
    routeCardsByID = [:]
    projectsByID = [:]
    appliedCommands = [:]
    appliedEffects = [:]
    retractedActionIDs = []
    pendingCommands = [:]
    pendingReasons = [:]
    reconciliationIssuesByActionID = [:]
  }

  public var snapshot: VisitSnapshot {
    VisitSnapshot(
      visits: visitsByID.values.sorted {
        if $0.startedAt != $1.startedAt {
          return $0.startedAt < $1.startedAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      attempts: attemptsByID.values.sorted {
        if $0.occurredAt != $1.occurredAt {
          return $0.occurredAt < $1.occurredAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      routeCards: routeCardsByID.values.sorted { $0.id.rawValue < $1.id.rawValue },
      projects: projectsByID.values.sorted {
        if $0.startedAt != $1.startedAt {
          return $0.startedAt < $1.startedAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      pendingActionIDs: pendingCommands.keys.sorted { $0.rawValue < $1.rawValue },
      reconciliationIssues: reconciliationIssuesByActionID.values.sorted {
        $0.actionID.rawValue < $1.actionID.rawValue
      }
    )
  }
}

public enum VisitCommand: Equatable, Sendable {
  case startVisit(
    actionID: ActionID,
    visitID: GymVisitID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case recordAttempt(
    actionID: ActionID,
    attemptID: AttemptID,
    visitID: GymVisitID,
    routeCardID: RouteCardID?,
    occurredAt: Instant,
    source: CaptureSource
  )
  case markSend(
    actionID: ActionID,
    attemptID: AttemptID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case confirmNotSent(
    actionID: ActionID,
    attemptID: AttemptID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case undo(
    actionID: ActionID,
    targetActionID: ActionID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case endVisit(
    actionID: ActionID,
    visitID: GymVisitID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case beginReview(
    actionID: ActionID,
    visitID: GymVisitID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case completeReview(
    actionID: ActionID,
    visitID: GymVisitID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case createRouteCard(
    actionID: ActionID,
    routeCardID: RouteCardID,
    label: String,
    availability: RouteAvailability,
    occurredAt: Instant,
    source: CaptureSource
  )
  case startProject(
    actionID: ActionID,
    projectID: ProjectID,
    routeCardID: RouteCardID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case closeProjectSent(
    actionID: ActionID,
    projectID: ProjectID,
    supportingAttemptID: AttemptID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case replaceRouteAfterReset(
    actionID: ActionID,
    oldRouteCardID: RouteCardID,
    successorRouteCardID: RouteCardID,
    successorLabel: String,
    occurredAt: Instant,
    source: CaptureSource
  )
}

public enum VisitRejection: Equatable, Sendable {
  case anotherVisitIsOpen
  case visitDoesNotExist
  case visitIsNotOpen
  case attemptAlreadyExists
  case attemptDoesNotExist
  case attemptIsRetracted
  case actionIsNotReversible
  case actionAlreadyRetracted
  case reviewRequiresEndedVisit
  case reviewIsNotInProgress
  case routeCardAlreadyExists
  case routeCardDoesNotExist
  case routeCardIsNotAvailable
  case projectAlreadyExists
  case activeProjectAlreadyExists
  case projectDoesNotExist
  case projectIsNotActive
  case supportingAttemptIsNotSent
  case supportingAttemptRouteMismatch
}

public enum VisitConflict: Equatable, Sendable {
  case actionIDReused
  case targetHasDependentActions
}

public enum VisitDeferredReason: Equatable, Sendable {
  case missingAttempt(AttemptID)
  case missingAction(ActionID)
}

public enum CommandOutcome: Equatable, Sendable {
  case accepted
  case duplicate
  case conflict(VisitConflict)
  case deferred(VisitDeferredReason)
  case rejected(VisitRejection)
}

public enum ReconciliationIssueReason: Equatable, Sendable {
  case conflict(VisitConflict)
  case rejected(VisitRejection)
}

public struct ReconciliationIssueSnapshot: Equatable, Sendable {
  public let actionID: ActionID
  public let reason: ReconciliationIssueReason

  public init(actionID: ActionID, reason: ReconciliationIssueReason) {
    self.actionID = actionID
    self.reason = reason
  }
}

public struct VisitTransition: Equatable, Sendable {
  public let state: VisitState
  public let outcome: CommandOutcome

  public init(state: VisitState, outcome: CommandOutcome) {
    self.state = state
    self.outcome = outcome
  }
}

public enum VisitMemory {
  public static func apply(_ command: VisitCommand, to state: VisitState) -> VisitTransition {
    if let applied = state.appliedCommands[command.actionID] {
      return VisitTransition(
        state: state,
        outcome: applied == command ? .duplicate : .conflict(.actionIDReused)
      )
    }
    if let pending = state.pendingCommands[command.actionID] {
      guard pending == command else {
        return VisitTransition(state: state, outcome: .conflict(.actionIDReused))
      }
      return VisitTransition(
        state: state,
        outcome: .deferred(
          state.pendingReasons[command.actionID] ?? .missingAction(command.actionID))
      )
    }

    var next = state
    let effect: AppliedEffect

    switch command {
    case .startVisit(_, let visitID, let occurredAt, let source):
      guard next.openVisitID == nil else {
        return VisitTransition(state: state, outcome: .rejected(.anotherVisitIsOpen))
      }
      next.openVisitID = visitID
      next.visitsByID[visitID] = GymVisitSnapshot(
        id: visitID,
        startedAt: occurredAt,
        endedAt: nil,
        startedBy: source,
        captureState: .open,
        reviewState: .notReady
      )
      effect = .visitStarted(visitID)

    case .recordAttempt(_, let attemptID, let visitID, let routeCardID, let occurredAt, let source):
      guard let visit = next.visitsByID[visitID] else {
        return VisitTransition(state: state, outcome: .rejected(.visitDoesNotExist))
      }
      let isOpenCapture = visit.captureState == .open && next.openVisitID == visitID
      let isLateCapture =
        visit.captureState == .ended && occurredAt <= (visit.endedAt ?? occurredAt)
      guard isOpenCapture || isLateCapture else {
        return VisitTransition(state: state, outcome: .rejected(.visitIsNotOpen))
      }
      guard next.attemptsByID[attemptID] == nil else {
        return VisitTransition(state: state, outcome: .rejected(.attemptAlreadyExists))
      }

      next.attemptsByID[attemptID] = AttemptSnapshot(
        id: attemptID,
        visitID: visitID,
        routeCardID: routeCardID,
        occurredAt: occurredAt,
        recordedBy: source,
        recordState: .active,
        outcome: .unresolved
      )
      if visit.reviewState == .reviewed {
        next.visitsByID[visitID] = GymVisitSnapshot(
          id: visit.id,
          startedAt: visit.startedAt,
          endedAt: visit.endedAt,
          startedBy: visit.startedBy,
          captureState: visit.captureState,
          reviewState: .needsRecheck
        )
      }
      effect = .attemptRecorded(attemptID)

    case .markSend(_, let attemptID, _, _):
      guard let attempt = next.attemptsByID[attemptID] else {
        return deferred(command, reason: .missingAttempt(attemptID), from: state)
      }
      guard attempt.recordState == .active else {
        return VisitTransition(state: state, outcome: .rejected(.attemptIsRetracted))
      }

      let previousOutcome = attempt.outcome
      next.attemptsByID[attemptID] = AttemptSnapshot(
        id: attempt.id,
        visitID: attempt.visitID,
        routeCardID: attempt.routeCardID,
        occurredAt: attempt.occurredAt,
        recordedBy: attempt.recordedBy,
        recordState: attempt.recordState,
        outcome: .sent
      )
      effect = .outcomeChanged(attemptID: attemptID, previous: previousOutcome)

    case .confirmNotSent(_, let attemptID, _, _):
      guard let attempt = next.attemptsByID[attemptID] else {
        return deferred(command, reason: .missingAttempt(attemptID), from: state)
      }
      guard attempt.recordState == .active else {
        return VisitTransition(state: state, outcome: .rejected(.attemptIsRetracted))
      }

      let previousOutcome = attempt.outcome
      next.attemptsByID[attemptID] = AttemptSnapshot(
        id: attempt.id,
        visitID: attempt.visitID,
        routeCardID: attempt.routeCardID,
        occurredAt: attempt.occurredAt,
        recordedBy: attempt.recordedBy,
        recordState: attempt.recordState,
        outcome: .notSent
      )
      effect = .outcomeChanged(attemptID: attemptID, previous: previousOutcome)

    case .undo(_, let targetActionID, _, _):
      guard !next.retractedActionIDs.contains(targetActionID) else {
        return VisitTransition(state: state, outcome: .rejected(.actionAlreadyRetracted))
      }
      guard let targetEffect = next.appliedEffects[targetActionID] else {
        return deferred(command, reason: .missingAction(targetActionID), from: state)
      }
      guard
        !hasDependentActions(
          on: targetEffect,
          targetActionID: targetActionID,
          in: next
        )
      else {
        return VisitTransition(state: state, outcome: .conflict(.targetHasDependentActions))
      }

      switch targetEffect {
      case .attemptRecorded(let attemptID):
        guard let attempt = next.attemptsByID[attemptID] else {
          return VisitTransition(state: state, outcome: .rejected(.attemptDoesNotExist))
        }
        next.attemptsByID[attemptID] = AttemptSnapshot(
          id: attempt.id,
          visitID: attempt.visitID,
          routeCardID: attempt.routeCardID,
          occurredAt: attempt.occurredAt,
          recordedBy: attempt.recordedBy,
          recordState: .retracted,
          outcome: attempt.outcome
        )
        reopenProjectsSupportedBy(attemptID, in: &next)

      case .outcomeChanged(let attemptID, let previousOutcome):
        guard let attempt = next.attemptsByID[attemptID] else {
          return VisitTransition(state: state, outcome: .rejected(.attemptDoesNotExist))
        }
        next.attemptsByID[attemptID] = AttemptSnapshot(
          id: attempt.id,
          visitID: attempt.visitID,
          routeCardID: attempt.routeCardID,
          occurredAt: attempt.occurredAt,
          recordedBy: attempt.recordedBy,
          recordState: attempt.recordState,
          outcome: previousOutcome
        )
        if previousOutcome != .sent {
          reopenProjectsSupportedBy(attemptID, in: &next)
        }

      case .visitStarted, .visitEnded, .reviewStateChanged, .routeCardCreated, .routeReplaced,
        .projectStarted, .projectClosed, .undo:
        return VisitTransition(state: state, outcome: .rejected(.actionIsNotReversible))
      }

      next.retractedActionIDs.insert(targetActionID)
      effect = .undo(targetActionID)

    case .endVisit(_, let visitID, let occurredAt, _):
      guard next.openVisitID == visitID else {
        return VisitTransition(state: state, outcome: .rejected(.visitIsNotOpen))
      }
      guard let visit = next.visitsByID[visitID] else {
        return VisitTransition(state: state, outcome: .rejected(.visitDoesNotExist))
      }

      next.openVisitID = nil
      next.visitsByID[visitID] = GymVisitSnapshot(
        id: visit.id,
        startedAt: visit.startedAt,
        endedAt: occurredAt,
        startedBy: visit.startedBy,
        captureState: .ended,
        reviewState: .pendingReview
      )
      effect = .visitEnded(visitID)

    case .beginReview(_, let visitID, _, _):
      guard let visit = next.visitsByID[visitID] else {
        return VisitTransition(state: state, outcome: .rejected(.visitDoesNotExist))
      }
      guard visit.captureState == .ended else {
        return VisitTransition(state: state, outcome: .rejected(.reviewRequiresEndedVisit))
      }
      guard
        visit.reviewState == .pendingReview || visit.reviewState == .needsRecheck
          || visit.reviewState == .reviewed
      else {
        return VisitTransition(state: state, outcome: .rejected(.reviewIsNotInProgress))
      }
      next.visitsByID[visitID] = GymVisitSnapshot(
        id: visit.id,
        startedAt: visit.startedAt,
        endedAt: visit.endedAt,
        startedBy: visit.startedBy,
        captureState: visit.captureState,
        reviewState: .reviewing
      )
      effect = .reviewStateChanged(visitID: visitID, previous: visit.reviewState)

    case .completeReview(_, let visitID, _, _):
      guard let visit = next.visitsByID[visitID] else {
        return VisitTransition(state: state, outcome: .rejected(.visitDoesNotExist))
      }
      guard visit.captureState == .ended else {
        return VisitTransition(state: state, outcome: .rejected(.reviewRequiresEndedVisit))
      }
      guard visit.reviewState == .reviewing else {
        return VisitTransition(state: state, outcome: .rejected(.reviewIsNotInProgress))
      }
      next.visitsByID[visitID] = GymVisitSnapshot(
        id: visit.id,
        startedAt: visit.startedAt,
        endedAt: visit.endedAt,
        startedBy: visit.startedBy,
        captureState: visit.captureState,
        reviewState: .reviewed
      )
      effect = .reviewStateChanged(visitID: visitID, previous: visit.reviewState)

    case .createRouteCard(_, let routeCardID, let label, let availability, let occurredAt, _):
      guard next.routeCardsByID[routeCardID] == nil else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardAlreadyExists))
      }
      next.routeCardsByID[routeCardID] = RouteCardSnapshot(
        id: routeCardID,
        label: label,
        recordVisibility: .active,
        availability: availability,
        mergedIntoRouteCardID: nil,
        successorRouteCardID: nil,
        createdAt: occurredAt
      )
      effect = .routeCardCreated(routeCardID)

    case .startProject(_, let projectID, let routeCardID, let occurredAt, _):
      guard next.projectsByID[projectID] == nil else {
        return VisitTransition(state: state, outcome: .rejected(.projectAlreadyExists))
      }
      guard let routeCard = next.routeCardsByID[routeCardID] else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardDoesNotExist))
      }
      guard routeCard.recordVisibility == .active && routeCard.availability != .gone else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardIsNotAvailable))
      }
      guard
        !next.projectsByID.values.contains(where: {
          $0.routeCardID == routeCardID && $0.state == .active
        })
      else {
        return VisitTransition(state: state, outcome: .rejected(.activeProjectAlreadyExists))
      }
      next.projectsByID[projectID] = ProjectSnapshot(
        id: projectID,
        routeCardID: routeCardID,
        state: .active,
        startedAt: occurredAt,
        closedAt: nil,
        supportingAttemptID: nil
      )
      effect = .projectStarted(projectID)

    case .closeProjectSent(_, let projectID, let supportingAttemptID, let occurredAt, _):
      guard let project = next.projectsByID[projectID] else {
        return VisitTransition(state: state, outcome: .rejected(.projectDoesNotExist))
      }
      guard project.state == .active else {
        return VisitTransition(state: state, outcome: .rejected(.projectIsNotActive))
      }
      guard let attempt = next.attemptsByID[supportingAttemptID],
        attempt.recordState == .active,
        attempt.outcome == .sent
      else {
        return VisitTransition(state: state, outcome: .rejected(.supportingAttemptIsNotSent))
      }
      guard attempt.routeCardID == project.routeCardID else {
        return VisitTransition(state: state, outcome: .rejected(.supportingAttemptRouteMismatch))
      }
      next.projectsByID[projectID] = ProjectSnapshot(
        id: project.id,
        routeCardID: project.routeCardID,
        state: .sent,
        startedAt: project.startedAt,
        closedAt: occurredAt,
        supportingAttemptID: supportingAttemptID
      )
      effect = .projectClosed(projectID)

    case .replaceRouteAfterReset(
      _,
      let oldRouteCardID,
      let successorRouteCardID,
      let successorLabel,
      let occurredAt,
      _
    ):
      guard let oldRoute = next.routeCardsByID[oldRouteCardID] else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardDoesNotExist))
      }
      guard next.routeCardsByID[successorRouteCardID] == nil else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardAlreadyExists))
      }
      next.routeCardsByID[oldRouteCardID] = RouteCardSnapshot(
        id: oldRoute.id,
        label: oldRoute.label,
        recordVisibility: oldRoute.recordVisibility,
        availability: .gone,
        mergedIntoRouteCardID: oldRoute.mergedIntoRouteCardID,
        successorRouteCardID: successorRouteCardID,
        createdAt: oldRoute.createdAt
      )
      next.routeCardsByID[successorRouteCardID] = RouteCardSnapshot(
        id: successorRouteCardID,
        label: successorLabel,
        recordVisibility: .active,
        availability: .present,
        mergedIntoRouteCardID: nil,
        successorRouteCardID: nil,
        createdAt: occurredAt
      )

      for project in next.projectsByID.values
      where
        project.routeCardID == oldRouteCardID && project.state == .active
      {
        next.projectsByID[project.id] = ProjectSnapshot(
          id: project.id,
          routeCardID: project.routeCardID,
          state: .gone,
          startedAt: project.startedAt,
          closedAt: occurredAt,
          supportingAttemptID: nil
        )
      }
      effect = .routeReplaced(old: oldRouteCardID, successor: successorRouteCardID)
    }

    next.appliedCommands[command.actionID] = command
    next.appliedEffects[command.actionID] = effect
    return VisitTransition(state: drainingPending(from: next), outcome: .accepted)
  }

  private static func deferred(
    _ command: VisitCommand,
    reason: VisitDeferredReason,
    from state: VisitState
  ) -> VisitTransition {
    var next = state
    next.pendingCommands[command.actionID] = command
    next.pendingReasons[command.actionID] = reason
    return VisitTransition(state: next, outcome: .deferred(reason))
  }

  private static func drainingPending(from state: VisitState) -> VisitState {
    var next = state
    let candidates = next.pendingCommands.values.sorted {
      if $0.occurredAt != $1.occurredAt {
        return $0.occurredAt < $1.occurredAt
      }
      return $0.actionID.rawValue < $1.actionID.rawValue
    }

    for command in candidates {
      next.pendingCommands[command.actionID] = nil
      next.pendingReasons[command.actionID] = nil
      let transition = apply(command, to: next)
      next = transition.state
      switch transition.outcome {
      case .conflict(let conflict):
        next.reconciliationIssuesByActionID[command.actionID] = ReconciliationIssueSnapshot(
          actionID: command.actionID,
          reason: .conflict(conflict)
        )
      case .rejected(let rejection):
        next.reconciliationIssuesByActionID[command.actionID] = ReconciliationIssueSnapshot(
          actionID: command.actionID,
          reason: .rejected(rejection)
        )
      case .accepted, .duplicate, .deferred:
        break
      }
    }

    return next
  }

  private static func reopenProjectsSupportedBy(
    _ attemptID: AttemptID,
    in state: inout VisitState
  ) {
    for project in state.projectsByID.values
    where
      project.state == .sent && project.supportingAttemptID == attemptID
    {
      state.projectsByID[project.id] = ProjectSnapshot(
        id: project.id,
        routeCardID: project.routeCardID,
        state: .active,
        startedAt: project.startedAt,
        closedAt: nil,
        supportingAttemptID: nil
      )
    }
  }

  private static func hasDependentActions(
    on targetEffect: AppliedEffect,
    targetActionID: ActionID,
    in state: VisitState
  ) -> Bool {
    let targetAttemptID: AttemptID
    let onlyActionsAfterTarget: Bool

    switch targetEffect {
    case .attemptRecorded(let attemptID):
      targetAttemptID = attemptID
      onlyActionsAfterTarget = false
    case .outcomeChanged(let attemptID, _):
      targetAttemptID = attemptID
      onlyActionsAfterTarget = true
    default:
      return false
    }

    let targetTime = state.appliedCommands[targetActionID]?.occurredAt
    let hasAppliedResult = state.appliedEffects.contains { actionID, effect in
      guard actionID != targetActionID,
        !state.retractedActionIDs.contains(actionID),
        case .outcomeChanged(let attemptID, _) = effect,
        attemptID == targetAttemptID
      else {
        return false
      }
      guard onlyActionsAfterTarget, let targetTime else {
        return true
      }
      return (state.appliedCommands[actionID]?.occurredAt ?? targetTime) > targetTime
    }
    if hasAppliedResult {
      return true
    }

    return state.pendingCommands.values.contains { command in
      switch command {
      case .markSend(_, let attemptID, _, _),
        .confirmNotSent(_, let attemptID, _, _):
        attemptID == targetAttemptID
      default:
        false
      }
    }
  }
}

extension VisitCommand {
  fileprivate var actionID: ActionID {
    switch self {
    case .startVisit(let actionID, _, _, _),
      .recordAttempt(let actionID, _, _, _, _, _),
      .markSend(let actionID, _, _, _),
      .confirmNotSent(let actionID, _, _, _),
      .undo(let actionID, _, _, _),
      .endVisit(let actionID, _, _, _),
      .beginReview(let actionID, _, _, _),
      .completeReview(let actionID, _, _, _),
      .createRouteCard(let actionID, _, _, _, _, _),
      .startProject(let actionID, _, _, _, _),
      .closeProjectSent(let actionID, _, _, _, _),
      .replaceRouteAfterReset(let actionID, _, _, _, _, _):
      actionID
    }
  }

  fileprivate var occurredAt: Instant {
    switch self {
    case .startVisit(_, _, let occurredAt, _),
      .recordAttempt(_, _, _, _, let occurredAt, _),
      .markSend(_, _, let occurredAt, _),
      .confirmNotSent(_, _, let occurredAt, _),
      .undo(_, _, let occurredAt, _),
      .endVisit(_, _, let occurredAt, _),
      .beginReview(_, _, let occurredAt, _),
      .completeReview(_, _, let occurredAt, _),
      .createRouteCard(_, _, _, _, let occurredAt, _),
      .startProject(_, _, _, let occurredAt, _),
      .closeProjectSent(_, _, _, let occurredAt, _),
      .replaceRouteAfterReset(_, _, _, _, let occurredAt, _):
      occurredAt
    }
  }
}

enum AppliedEffect: Equatable, Sendable {
  case visitStarted(GymVisitID)
  case visitEnded(GymVisitID)
  case reviewStateChanged(visitID: GymVisitID, previous: GymVisitReviewState)
  case routeCardCreated(RouteCardID)
  case routeReplaced(old: RouteCardID, successor: RouteCardID)
  case projectStarted(ProjectID)
  case projectClosed(ProjectID)
  case attemptRecorded(AttemptID)
  case outcomeChanged(attemptID: AttemptID, previous: AttemptOutcome)
  case undo(ActionID)
}
