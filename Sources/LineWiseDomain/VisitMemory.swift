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

public struct AttemptRouteCorrectionSnapshot: Equatable, Codable, Sendable {
  public let actionID: ActionID
  public let attemptID: AttemptID
  public let previousRouteCardID: RouteCardID?
  public let correctedRouteCardID: RouteCardID?
  public let occurredAt: Instant
  public let source: CaptureSource

  public init(
    actionID: ActionID,
    attemptID: AttemptID,
    previousRouteCardID: RouteCardID?,
    correctedRouteCardID: RouteCardID?,
    occurredAt: Instant,
    source: CaptureSource
  ) {
    self.actionID = actionID
    self.attemptID = attemptID
    self.previousRouteCardID = previousRouteCardID
    self.correctedRouteCardID = correctedRouteCardID
    self.occurredAt = occurredAt
    self.source = source
  }
}

public struct VisitSnapshot: Equatable, Sendable {
  public let visits: [GymVisitSnapshot]
  public let attempts: [AttemptSnapshot]
  public let routeCards: [RouteCardSnapshot]
  public let projects: [ProjectSnapshot]
  public let pendingActionIDs: [ActionID]
  public let reconciliationIssues: [ReconciliationIssueSnapshot]
  public let attemptRouteCorrections: [AttemptRouteCorrectionSnapshot]

  public init(
    visits: [GymVisitSnapshot],
    attempts: [AttemptSnapshot],
    routeCards: [RouteCardSnapshot],
    projects: [ProjectSnapshot],
    pendingActionIDs: [ActionID],
    reconciliationIssues: [ReconciliationIssueSnapshot],
    attemptRouteCorrections: [AttemptRouteCorrectionSnapshot] = []
  ) {
    self.visits = visits
    self.attempts = attempts
    self.routeCards = routeCards
    self.projects = projects
    self.pendingActionIDs = pendingActionIDs
    self.reconciliationIssues = reconciliationIssues
    self.attemptRouteCorrections = attemptRouteCorrections
  }

  public var activeAttempts: [AttemptSnapshot] {
    attempts.filter { $0.recordState == .active }
  }

  public var selectableRouteCards: [RouteCardSnapshot] {
    routeCards.filter {
      $0.recordVisibility == .active && $0.availability != .gone
    }
  }

  public func canonicalRouteCardID(for routeCardID: RouteCardID) -> RouteCardID? {
    guard let routeCard = routeCards.first(where: { $0.id == routeCardID }) else {
      return nil
    }
    return routeCard.mergedIntoRouteCardID ?? routeCard.id
  }
}

public struct VisitState: Equatable, Sendable {
  var openVisitID: GymVisitID?
  var visitsByID: [GymVisitID: GymVisitSnapshot]
  var attemptsByID: [AttemptID: AttemptSnapshot]
  var attemptOutcomeRecordsByActionID: [ActionID: AttemptOutcomeRecord]
  var attemptRouteCorrectionsByActionID: [ActionID: AttemptRouteCorrectionSnapshot]
  var routeCardsByID: [RouteCardID: RouteCardSnapshot]
  var routeVisibilityBeforeMergeByRouteCardID: [RouteCardID: RouteCardRecordVisibility]
  var projectsByID: [ProjectID: ProjectSnapshot]
  var appliedCommands: [ActionID: VisitCommand]
  var appliedEffects: [ActionID: AppliedEffect]
  var retractedActionIDs: Set<ActionID>
  var pendingCommands: [ActionID: VisitCommand]
  var pendingReasons: [ActionID: VisitDeferredReason]
  var conflictingCommandsByActionID: [ActionID: VisitCommand]
  var reconciliationIssuesByActionID: [ActionID: ReconciliationIssueSnapshot]

  public init() {
    openVisitID = nil
    visitsByID = [:]
    attemptsByID = [:]
    attemptOutcomeRecordsByActionID = [:]
    attemptRouteCorrectionsByActionID = [:]
    routeCardsByID = [:]
    routeVisibilityBeforeMergeByRouteCardID = [:]
    projectsByID = [:]
    appliedCommands = [:]
    appliedEffects = [:]
    retractedActionIDs = []
    pendingCommands = [:]
    pendingReasons = [:]
    conflictingCommandsByActionID = [:]
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
      },
      attemptRouteCorrections: attemptRouteCorrectionsByActionID.values.sorted {
        if $0.occurredAt != $1.occurredAt {
          return $0.occurredAt < $1.occurredAt
        }
        return $0.actionID.rawValue < $1.actionID.rawValue
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
  case reviseRouteCard(
    actionID: ActionID,
    routeCardID: RouteCardID,
    revisedLabel: String,
    occurredAt: Instant,
    source: CaptureSource
  )
  case archiveRouteCard(
    actionID: ActionID,
    routeCardID: RouteCardID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case restoreRouteCard(
    actionID: ActionID,
    routeCardID: RouteCardID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case correctRouteAvailability(
    actionID: ActionID,
    routeCardID: RouteCardID,
    availability: RouteAvailability,
    occurredAt: Instant,
    source: CaptureSource
  )
  case confirmRouteCardMerge(
    actionID: ActionID,
    duplicateRouteCardID: RouteCardID,
    canonicalRouteCardID: RouteCardID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case unmergeRouteCard(
    actionID: ActionID,
    mergedRouteCardID: RouteCardID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case correctAttemptRoute(
    actionID: ActionID,
    attemptID: AttemptID,
    routeCardID: RouteCardID?,
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
  case archiveProject(
    actionID: ActionID,
    projectID: ProjectID,
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
  case visitAlreadyExists
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
  case routeCardVisibilityCannotChange
  case routeCardIsMerged
  case routeCardIsNotMerged
  case routeCardCannotMergeIntoSelf
  case routeCardMergeWouldCreateChain
  case routeAvailabilityUnchanged
  case attemptRouteUnchanged
  case projectAlreadyExists
  case activeProjectAlreadyExists
  case projectDoesNotExist
  case projectIsNotActive
  case supportingAttemptIsNotSent
  case supportingAttemptRouteMismatch
}

public enum VisitConflict: Equatable, Sendable {
  case actionIDReused
  case ambiguousAttemptOutcome(AttemptID)
  case projectCycleWouldOverlap(RouteCardID)
  case targetIsRetracted(AttemptID)
  case targetHasDependentActions
  case routeMergeHasActiveProjectConflict(
    duplicateRouteCardID: RouteCardID,
    canonicalRouteCardID: RouteCardID
  )
}

public enum VisitDeferredReason: Equatable, Sendable {
  case missingAttempt(AttemptID)
  case missingAction(ActionID)
  case missingRouteCard(RouteCardID)
  case missingProject(ProjectID)
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
    if let conflicting = state.conflictingCommandsByActionID[command.actionID] {
      guard conflicting == command else {
        return VisitTransition(state: state, outcome: .conflict(.actionIDReused))
      }
      guard
        let issue = state.reconciliationIssuesByActionID[command.actionID],
        case .conflict(let conflict) = issue.reason
      else {
        return VisitTransition(state: state, outcome: .conflict(.actionIDReused))
      }
      return VisitTransition(state: state, outcome: .conflict(conflict))
    }

    var next = state
    let effect: AppliedEffect

    switch command {
    case .startVisit(_, let visitID, let occurredAt, let source):
      guard next.openVisitID == nil else {
        return VisitTransition(state: state, outcome: .rejected(.anotherVisitIsOpen))
      }
      guard next.visitsByID[visitID] == nil else {
        return VisitTransition(state: state, outcome: .rejected(.visitAlreadyExists))
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
      markVisitNeedsRecheckIfReviewed(visitID, in: &next)
      effect = .attemptRecorded(attemptID)

    case .markSend(let actionID, let attemptID, let occurredAt, _):
      guard let attempt = next.attemptsByID[attemptID] else {
        return deferred(command, reason: .missingAttempt(attemptID), from: state)
      }
      guard attempt.recordState == .active else {
        return preservedConflict(
          command,
          reason: .targetIsRetracted(attemptID),
          visitID: attempt.visitID,
          from: state
        )
      }

      next.attemptOutcomeRecordsByActionID[actionID] = AttemptOutcomeRecord(
        actionID: actionID,
        attemptID: attemptID,
        outcome: .sent,
        occurredAt: occurredAt
      )
      reprojectAttemptOutcome(attemptID, in: &next)
      if let routeCardID = routeCardWithOverlappingActiveProjects(in: next) {
        return preservedConflict(
          command,
          reason: .projectCycleWouldOverlap(routeCardID),
          visitID: attempt.visitID,
          from: state
        )
      }
      markVisitNeedsRecheckIfReviewed(attempt.visitID, in: &next)
      effect = .outcomeRecorded(attemptID)

    case .confirmNotSent(let actionID, let attemptID, let occurredAt, _):
      guard let attempt = next.attemptsByID[attemptID] else {
        return deferred(command, reason: .missingAttempt(attemptID), from: state)
      }
      guard attempt.recordState == .active else {
        return preservedConflict(
          command,
          reason: .targetIsRetracted(attemptID),
          visitID: attempt.visitID,
          from: state
        )
      }

      next.attemptOutcomeRecordsByActionID[actionID] = AttemptOutcomeRecord(
        actionID: actionID,
        attemptID: attemptID,
        outcome: .notSent,
        occurredAt: occurredAt
      )
      reprojectAttemptOutcome(attemptID, in: &next)
      if let routeCardID = routeCardWithOverlappingActiveProjects(in: next) {
        return preservedConflict(
          command,
          reason: .projectCycleWouldOverlap(routeCardID),
          visitID: attempt.visitID,
          from: state
        )
      }
      markVisitNeedsRecheckIfReviewed(attempt.visitID, in: &next)
      effect = .outcomeRecorded(attemptID)

    case .undo(_, let targetActionID, _, _):
      guard !next.retractedActionIDs.contains(targetActionID) else {
        return VisitTransition(state: state, outcome: .rejected(.actionAlreadyRetracted))
      }
      guard let targetEffect = next.appliedEffects[targetActionID] else {
        return deferred(command, reason: .missingAction(targetActionID), from: state)
      }
      if hasDependentActions(
        on: targetEffect,
        targetActionID: targetActionID,
        in: next
      ) {
        if let visitID = affectedVisitID(for: targetEffect, in: next) {
          return preservedConflict(
            command,
            reason: .targetHasDependentActions,
            visitID: visitID,
            from: state
          )
        }
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
        reprojectProjects(in: &next)
        if let routeCardID = routeCardWithOverlappingActiveProjects(in: next) {
          return preservedConflict(
            command,
            reason: .projectCycleWouldOverlap(routeCardID),
            visitID: attempt.visitID,
            from: state
          )
        }
        markVisitNeedsRecheckIfReviewed(attempt.visitID, in: &next)

      case .outcomeRecorded(let attemptID):
        guard let attempt = next.attemptsByID[attemptID] else {
          return VisitTransition(state: state, outcome: .rejected(.attemptDoesNotExist))
        }
        next.retractedActionIDs.insert(targetActionID)
        reprojectAttemptOutcome(attemptID, in: &next)
        if let routeCardID = routeCardWithOverlappingActiveProjects(in: next) {
          return preservedConflict(
            command,
            reason: .projectCycleWouldOverlap(routeCardID),
            visitID: attempt.visitID,
            from: state
          )
        }
        markVisitNeedsRecheckIfReviewed(attempt.visitID, in: &next)

      case .visitStarted, .visitEnded, .reviewStateChanged, .routeCardCreated,
        .routeCardRevised, .routeCardVisibilityChanged, .routeCardAvailabilityChanged,
        .routeCardMerged, .routeCardUnmerged, .routeReplaced, .projectStarted, .projectClosed,
        .projectArchived, .attemptRouteCorrected, .undo:
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

    case .reviseRouteCard(_, let routeCardID, let revisedLabel, _, _):
      guard let routeCard = next.routeCardsByID[routeCardID] else {
        return deferred(command, reason: .missingRouteCard(routeCardID), from: state)
      }
      next.routeCardsByID[routeCardID] = routeCard.revising(label: revisedLabel)
      effect = .routeCardRevised(routeCardID)

    case .archiveRouteCard(_, let routeCardID, _, _):
      guard let routeCard = next.routeCardsByID[routeCardID] else {
        return deferred(command, reason: .missingRouteCard(routeCardID), from: state)
      }
      guard routeCard.recordVisibility == .active else {
        return VisitTransition(
          state: state, outcome: .rejected(.routeCardVisibilityCannotChange))
      }
      next.routeCardsByID[routeCardID] = routeCard.changingVisibility(
        to: .archived,
        mergedIntoRouteCardID: nil
      )
      effect = .routeCardVisibilityChanged(routeCardID)

    case .restoreRouteCard(_, let routeCardID, _, _):
      guard let routeCard = next.routeCardsByID[routeCardID] else {
        return deferred(command, reason: .missingRouteCard(routeCardID), from: state)
      }
      guard routeCard.recordVisibility == .archived else {
        return VisitTransition(
          state: state, outcome: .rejected(.routeCardVisibilityCannotChange))
      }
      next.routeCardsByID[routeCardID] = routeCard.changingVisibility(
        to: .active,
        mergedIntoRouteCardID: nil
      )
      effect = .routeCardVisibilityChanged(routeCardID)

    case .correctRouteAvailability(_, let routeCardID, let availability, let occurredAt, _):
      guard let routeCard = next.routeCardsByID[routeCardID] else {
        return deferred(command, reason: .missingRouteCard(routeCardID), from: state)
      }
      guard routeCard.recordVisibility != .merged else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardIsMerged))
      }
      guard routeCard.availability != availability else {
        return VisitTransition(state: state, outcome: .rejected(.routeAvailabilityUnchanged))
      }
      next.routeCardsByID[routeCardID] = routeCard.changingAvailability(to: availability)
      if availability == .gone {
        closeActiveProjects(
          canonicallyLinkedTo: routeCardID,
          as: .gone,
          at: occurredAt,
          in: &next
        )
      }
      effect = .routeCardAvailabilityChanged(routeCardID)

    case .confirmRouteCardMerge(
      _, let duplicateRouteCardID, let canonicalRouteCardID, _, _
    ):
      guard duplicateRouteCardID != canonicalRouteCardID else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardCannotMergeIntoSelf))
      }
      guard let duplicateRouteCard = next.routeCardsByID[duplicateRouteCardID] else {
        return deferred(
          command, reason: .missingRouteCard(duplicateRouteCardID), from: state)
      }
      guard let canonicalRouteCard = next.routeCardsByID[canonicalRouteCardID] else {
        return deferred(
          command, reason: .missingRouteCard(canonicalRouteCardID), from: state)
      }
      guard duplicateRouteCard.recordVisibility != .merged else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardIsMerged))
      }
      guard canonicalRouteCard.recordVisibility != .merged else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardIsMerged))
      }
      guard
        !next.routeCardsByID.values.contains(where: {
          $0.mergedIntoRouteCardID == duplicateRouteCardID
        })
      else {
        return VisitTransition(
          state: state, outcome: .rejected(.routeCardMergeWouldCreateChain))
      }

      let duplicateHasActiveProject = hasActiveProject(
        canonicallyLinkedTo: duplicateRouteCardID,
        in: next
      )
      let canonicalHasActiveProject = hasActiveProject(
        canonicallyLinkedTo: canonicalRouteCardID,
        in: next
      )
      guard !(duplicateHasActiveProject && canonicalHasActiveProject) else {
        return preservedConflict(
          command,
          reason: .routeMergeHasActiveProjectConflict(
            duplicateRouteCardID: duplicateRouteCardID,
            canonicalRouteCardID: canonicalRouteCardID
          ),
          from: state
        )
      }

      next.routeVisibilityBeforeMergeByRouteCardID[duplicateRouteCardID] =
        duplicateRouteCard.recordVisibility
      next.routeCardsByID[duplicateRouteCardID] = duplicateRouteCard.changingVisibility(
        to: .merged,
        mergedIntoRouteCardID: canonicalRouteCardID
      )
      effect = .routeCardMerged(
        duplicate: duplicateRouteCardID,
        canonical: canonicalRouteCardID
      )

    case .unmergeRouteCard(_, let mergedRouteCardID, _, _):
      guard let routeCard = next.routeCardsByID[mergedRouteCardID] else {
        return deferred(command, reason: .missingRouteCard(mergedRouteCardID), from: state)
      }
      guard routeCard.recordVisibility == .merged,
        let canonicalRouteCardID = routeCard.mergedIntoRouteCardID
      else {
        return VisitTransition(state: state, outcome: .rejected(.routeCardIsNotMerged))
      }
      let restoredVisibility =
        next.routeVisibilityBeforeMergeByRouteCardID[mergedRouteCardID] ?? .active
      next.routeCardsByID[mergedRouteCardID] = routeCard.changingVisibility(
        to: restoredVisibility,
        mergedIntoRouteCardID: nil
      )
      next.routeVisibilityBeforeMergeByRouteCardID[mergedRouteCardID] = nil
      reprojectProjects(in: &next)
      effect = .routeCardUnmerged(
        recovered: mergedRouteCardID,
        formerCanonical: canonicalRouteCardID
      )

    case .correctAttemptRoute(
      let actionID, let attemptID, let routeCardID, let occurredAt, let source
    ):
      guard let attempt = next.attemptsByID[attemptID] else {
        return deferred(command, reason: .missingAttempt(attemptID), from: state)
      }
      guard attempt.recordState == .active else {
        return VisitTransition(state: state, outcome: .rejected(.attemptIsRetracted))
      }
      if let routeCardID {
        guard let routeCard = next.routeCardsByID[routeCardID] else {
          return deferred(command, reason: .missingRouteCard(routeCardID), from: state)
        }
        guard routeCard.recordVisibility != .merged else {
          return VisitTransition(state: state, outcome: .rejected(.routeCardIsMerged))
        }
      }
      guard attempt.routeCardID != routeCardID else {
        return VisitTransition(state: state, outcome: .rejected(.attemptRouteUnchanged))
      }

      next.attemptsByID[attemptID] = AttemptSnapshot(
        id: attempt.id,
        visitID: attempt.visitID,
        routeCardID: routeCardID,
        occurredAt: attempt.occurredAt,
        recordedBy: attempt.recordedBy,
        recordState: attempt.recordState,
        outcome: attempt.outcome
      )
      next.attemptRouteCorrectionsByActionID[actionID] = AttemptRouteCorrectionSnapshot(
        actionID: actionID,
        attemptID: attemptID,
        previousRouteCardID: attempt.routeCardID,
        correctedRouteCardID: routeCardID,
        occurredAt: occurredAt,
        source: source
      )
      reprojectProjects(in: &next)
      if let overlappingRouteCardID = routeCardWithOverlappingActiveProjects(in: next) {
        return preservedConflict(
          command,
          reason: .projectCycleWouldOverlap(overlappingRouteCardID),
          visitID: attempt.visitID,
          from: state
        )
      }
      markVisitNeedsRecheckIfReviewed(attempt.visitID, in: &next)
      effect = .attemptRouteCorrected(attemptID)

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
          $0.state == .active
            && canonicalRouteCardID(for: $0.routeCardID, in: next) == routeCardID
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
      guard
        attempt.routeCardID.flatMap({ canonicalRouteCardID(for: $0, in: next) })
          == canonicalRouteCardID(for: project.routeCardID, in: next)
      else {
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

    case .archiveProject(_, let projectID, let occurredAt, _):
      guard let project = next.projectsByID[projectID] else {
        return deferred(command, reason: .missingProject(projectID), from: state)
      }
      guard project.state == .active else {
        return VisitTransition(state: state, outcome: .rejected(.projectIsNotActive))
      }
      next.projectsByID[projectID] = ProjectSnapshot(
        id: project.id,
        routeCardID: project.routeCardID,
        state: .archived,
        startedAt: project.startedAt,
        closedAt: occurredAt,
        supportingAttemptID: nil
      )
      effect = .projectArchived(projectID)

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

  private static func preservedConflict(
    _ command: VisitCommand,
    reason: VisitConflict,
    visitID: GymVisitID? = nil,
    from state: VisitState
  ) -> VisitTransition {
    var next = state
    next.conflictingCommandsByActionID[command.actionID] = command
    next.reconciliationIssuesByActionID[command.actionID] = ReconciliationIssueSnapshot(
      actionID: command.actionID,
      reason: .conflict(reason)
    )
    if let visitID {
      markVisitNeedsRecheckIfReviewed(visitID, in: &next)
    }
    return VisitTransition(state: next, outcome: .conflict(reason))
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

  private static func reprojectAttemptOutcome(
    _ attemptID: AttemptID,
    in state: inout VisitState
  ) {
    guard let attempt = state.attemptsByID[attemptID] else {
      return
    }

    let activeRecords =
      state.attemptOutcomeRecordsByActionID.values
      .filter {
        $0.attemptID == attemptID && !state.retractedActionIDs.contains($0.actionID)
      }

    let latestOccurredAt = activeRecords.map(\.occurredAt).max()
    let latestRecords = activeRecords.filter { $0.occurredAt == latestOccurredAt }
    let firstOutcome = latestRecords.first?.outcome
    let hasAmbiguousOutcome = latestRecords.contains { $0.outcome != firstOutcome }
    let currentOutcome = hasAmbiguousOutcome ? .unresolved : firstOutcome ?? .unresolved

    let previousAmbiguityIssueIDs = state.reconciliationIssuesByActionID.compactMap {
      actionID, issue -> ActionID? in
      guard
        case .conflict(.ambiguousAttemptOutcome(let issueAttemptID)) = issue.reason,
        issueAttemptID == attemptID
      else {
        return nil
      }
      return actionID
    }
    for actionID in previousAmbiguityIssueIDs {
      state.reconciliationIssuesByActionID[actionID] = nil
    }
    if hasAmbiguousOutcome,
      let issueActionID = latestRecords.map(\.actionID).max(by: {
        $0.rawValue < $1.rawValue
      })
    {
      state.reconciliationIssuesByActionID[issueActionID] = ReconciliationIssueSnapshot(
        actionID: issueActionID,
        reason: .conflict(.ambiguousAttemptOutcome(attemptID))
      )
    }

    state.attemptsByID[attemptID] = AttemptSnapshot(
      id: attempt.id,
      visitID: attempt.visitID,
      routeCardID: attempt.routeCardID,
      occurredAt: attempt.occurredAt,
      recordedBy: attempt.recordedBy,
      recordState: attempt.recordState,
      outcome: currentOutcome
    )

    reprojectProjects(in: &state)
  }

  private static func reprojectProjects(in state: inout VisitState) {
    let projects = Array(state.projectsByID.values)

    for project in projects where project.state != .archived && project.state != .gone {
      let closureCommands = state.appliedCommands.values.filter { command in
        guard
          case .closeProjectSent(let actionID, let projectID, _, _, _) = command,
          projectID == project.id,
          !state.retractedActionIDs.contains(actionID)
        else {
          return false
        }
        return true
      }
      let latestClosure = closureCommands.max(by: {
        if $0.occurredAt != $1.occurredAt {
          return $0.occurredAt < $1.occurredAt
        }
        return $0.actionID.rawValue < $1.actionID.rawValue
      })

      var supportingAttemptID: AttemptID?
      var sentAt: Instant?
      if let latestClosure,
        case .closeProjectSent(_, _, let attemptID, let closedAt, _) = latestClosure
      {
        supportingAttemptID = attemptID
        sentAt = closedAt
      }
      let supportingAttempt = supportingAttemptID.flatMap { state.attemptsByID[$0] }
      // Route identity is compared canonically so a merge does not invalidate a
      // send. It must also survive the merge being UNDONE: unmerge clears the
      // link before reprojecting, so a cycle closed while the identities were
      // one would find no match at all and silently flip back to active,
      // un-recording a send whose Attempt is untouched and still sent.
      //
      // A closure recorded while the routes were merged stays valid. The user
      // really sent the route; splitting the identity afterwards is a
      // bookkeeping correction, not evidence the send did not happen. Retract
      // the Undo or the Attempt to reopen the cycle — that is what those
      // commands are for.
      let closedWhileRoutesWereMerged: Bool = {
        guard let closure = latestClosure, let attemptRouteCardID = supportingAttempt?.routeCardID
        else { return false }
        return state.appliedCommands.values.contains { applied in
          guard
            case .confirmRouteCardMerge(
              let mergeActionID, let duplicateRouteCardID, let canonicalRouteCardID, let mergedAt, _
            ) = applied,
            !state.retractedActionIDs.contains(mergeActionID),
            mergedAt <= closure.occurredAt
          else { return false }
          let pair: Set<RouteCardID> = [duplicateRouteCardID, canonicalRouteCardID]
          return pair.contains(attemptRouteCardID) && pair.contains(project.routeCardID)
        }
      }()
      let supportRoutesMatch =
        supportingAttempt?.routeCardID.flatMap({
          canonicalRouteCardID(for: $0, in: state)
        }) == canonicalRouteCardID(for: project.routeCardID, in: state)
        || closedWhileRoutesWereMerged
      let hasValidSupport =
        supportingAttempt?.recordState == .active
        && supportingAttempt?.outcome == .sent
        && supportRoutesMatch

      let routeIsGone =
        canonicalRouteCardID(for: project.routeCardID, in: state)
        .flatMap { state.routeCardsByID[$0]?.availability } == .gone
      let resetAt = state.appliedCommands.values
        .filter { command in
          guard case .replaceRouteAfterReset(_, let oldRouteCardID, _, _, _, _) = command else {
            return false
          }
          return oldRouteCardID == project.routeCardID
        }
        .map(\.occurredAt)
        .max()

      let projectedState: ProjectState = hasValidSupport ? .sent : routeIsGone ? .gone : .active
      state.projectsByID[project.id] = ProjectSnapshot(
        id: project.id,
        routeCardID: project.routeCardID,
        state: projectedState,
        startedAt: project.startedAt,
        closedAt: hasValidSupport ? sentAt : routeIsGone ? resetAt : nil,
        supportingAttemptID: hasValidSupport ? supportingAttemptID : nil
      )
    }
  }

  private static func routeCardWithOverlappingActiveProjects(
    in state: VisitState
  ) -> RouteCardID? {
    var seenRouteCardIDs: Set<RouteCardID> = []
    for project in state.projectsByID.values where project.state == .active {
      let routeCardID =
        canonicalRouteCardID(for: project.routeCardID, in: state)
        ?? project.routeCardID
      guard seenRouteCardIDs.insert(routeCardID).inserted else {
        return routeCardID
      }
    }
    return nil
  }

  private static func canonicalRouteCardID(
    for routeCardID: RouteCardID,
    in state: VisitState
  ) -> RouteCardID? {
    guard let routeCard = state.routeCardsByID[routeCardID] else {
      return nil
    }
    return routeCard.mergedIntoRouteCardID ?? routeCard.id
  }

  private static func hasActiveProject(
    canonicallyLinkedTo routeCardID: RouteCardID,
    in state: VisitState
  ) -> Bool {
    state.projectsByID.values.contains {
      $0.state == .active
        && canonicalRouteCardID(for: $0.routeCardID, in: state) == routeCardID
    }
  }

  private static func closeActiveProjects(
    canonicallyLinkedTo routeCardID: RouteCardID,
    as projectState: ProjectState,
    at occurredAt: Instant,
    in state: inout VisitState
  ) {
    for project in state.projectsByID.values
    where
      project.state == .active
      && canonicalRouteCardID(for: project.routeCardID, in: state) == routeCardID
    {
      state.projectsByID[project.id] = ProjectSnapshot(
        id: project.id,
        routeCardID: project.routeCardID,
        state: projectState,
        startedAt: project.startedAt,
        closedAt: occurredAt,
        supportingAttemptID: nil
      )
    }
  }

  private static func markVisitNeedsRecheckIfReviewed(
    _ visitID: GymVisitID,
    in state: inout VisitState
  ) {
    guard let visit = state.visitsByID[visitID], visit.reviewState == .reviewed else {
      return
    }
    state.visitsByID[visitID] = GymVisitSnapshot(
      id: visit.id,
      startedAt: visit.startedAt,
      endedAt: visit.endedAt,
      startedBy: visit.startedBy,
      captureState: visit.captureState,
      reviewState: .needsRecheck
    )
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
    case .outcomeRecorded(let attemptID):
      targetAttemptID = attemptID
      onlyActionsAfterTarget = true
    default:
      return false
    }

    let targetTime = state.appliedCommands[targetActionID]?.occurredAt
    let hasAppliedResult = state.appliedEffects.contains { actionID, effect in
      guard actionID != targetActionID,
        !state.retractedActionIDs.contains(actionID),
        case .outcomeRecorded(let attemptID) = effect,
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

  private static func affectedVisitID(
    for effect: AppliedEffect,
    in state: VisitState
  ) -> GymVisitID? {
    let attemptID: AttemptID
    switch effect {
    case .attemptRecorded(let id), .outcomeRecorded(let id):
      attemptID = id
    default:
      return nil
    }
    return state.attemptsByID[attemptID]?.visitID
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
      .reviseRouteCard(let actionID, _, _, _, _),
      .archiveRouteCard(let actionID, _, _, _),
      .restoreRouteCard(let actionID, _, _, _),
      .correctRouteAvailability(let actionID, _, _, _, _),
      .confirmRouteCardMerge(let actionID, _, _, _, _),
      .unmergeRouteCard(let actionID, _, _, _),
      .correctAttemptRoute(let actionID, _, _, _, _),
      .startProject(let actionID, _, _, _, _),
      .closeProjectSent(let actionID, _, _, _, _),
      .archiveProject(let actionID, _, _, _),
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
      .reviseRouteCard(_, _, _, let occurredAt, _),
      .archiveRouteCard(_, _, let occurredAt, _),
      .restoreRouteCard(_, _, let occurredAt, _),
      .correctRouteAvailability(_, _, _, let occurredAt, _),
      .confirmRouteCardMerge(_, _, _, let occurredAt, _),
      .unmergeRouteCard(_, _, let occurredAt, _),
      .correctAttemptRoute(_, _, _, let occurredAt, _),
      .startProject(_, _, _, let occurredAt, _),
      .closeProjectSent(_, _, _, let occurredAt, _),
      .archiveProject(_, _, let occurredAt, _),
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
  case routeCardRevised(RouteCardID)
  case routeCardVisibilityChanged(RouteCardID)
  case routeCardAvailabilityChanged(RouteCardID)
  case routeCardMerged(duplicate: RouteCardID, canonical: RouteCardID)
  case routeCardUnmerged(recovered: RouteCardID, formerCanonical: RouteCardID)
  case routeReplaced(old: RouteCardID, successor: RouteCardID)
  case projectStarted(ProjectID)
  case projectClosed(ProjectID)
  case projectArchived(ProjectID)
  case attemptRecorded(AttemptID)
  case outcomeRecorded(AttemptID)
  case attemptRouteCorrected(AttemptID)
  case undo(ActionID)
}

struct AttemptOutcomeRecord: Equatable, Sendable {
  let actionID: ActionID
  let attemptID: AttemptID
  let outcome: AttemptOutcome
  let occurredAt: Instant
}
