import LineWiseDomain

public enum LineWiseAppIntent: Equatable, Sendable {
  case createRoute(
    actionID: ActionID,
    routeCardID: RouteCardID,
    label: String,
    availability: RouteAvailability,
    occurredAt: Instant,
    source: CaptureSource
  )
  case reviseRoute(
    actionID: ActionID,
    routeCardID: RouteCardID,
    revisedLabel: String,
    occurredAt: Instant,
    source: CaptureSource
  )
  case archiveRoute(
    actionID: ActionID,
    routeCardID: RouteCardID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case restoreRoute(
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
  case mergeRoute(
    actionID: ActionID,
    duplicateRouteCardID: RouteCardID,
    canonicalRouteCardID: RouteCardID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case unmergeRoute(
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
  case archiveProject(
    actionID: ActionID,
    projectID: ProjectID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case startVisit(
    actionID: ActionID,
    visitID: GymVisitID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case selectRoute(RouteCardID?)
  case recordAttempt(
    actionID: ActionID,
    attemptID: AttemptID,
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
  case endVisit(actionID: ActionID, occurredAt: Instant, source: CaptureSource)
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
  case closeProjectSent(
    actionID: ActionID,
    projectID: ProjectID,
    supportingAttemptID: AttemptID,
    occurredAt: Instant,
    source: CaptureSource
  )
  case startRest(
    actionID: ActionID,
    restID: RestIntervalID,
    afterAttemptID: AttemptID?,
    occurredAt: Instant
  )
  case stopRest(actionID: ActionID, restID: RestIntervalID, occurredAt: Instant)
}

public enum LineWiseAppLocalRejection: Equatable, Sendable {
  case noOpenVisit
  case routeDoesNotExist
  case routeIsNotSelectable
}

public enum LineWiseAppOutcome: Equatable, Sendable {
  case accepted
  case duplicate
  case selectionChanged
  case conflict(VisitConflict)
  case deferred(VisitDeferredReason)
  case rejected(VisitRejection)
  case restRejected(RestRejection)
  case persistenceFailed(String)
  case locallyRejected(LineWiseAppLocalRejection)
}

public enum LineWiseDeviceSyncOutcome: Equatable, Sendable {
  case unavailable
  case received(insertedEventIDs: [ActionID], duplicateEventIDs: [ActionID])
  case acknowledged(ActionID)
  case alreadyAcknowledged(ActionID)
  case persistenceFailed(String)
}

public struct LineWiseAppFeedback: Equatable, Sendable {
  public let outcome: LineWiseAppOutcome
  public let projection: LineWiseAppProjection

  public init(outcome: LineWiseAppOutcome, projection: LineWiseAppProjection) {
    self.outcome = outcome
    self.projection = projection
  }

  public var isSuccess: Bool {
    switch outcome {
    case .accepted, .duplicate, .selectionChanged:
      true
    case .conflict, .deferred, .rejected, .restRejected, .persistenceFailed, .locallyRejected:
      false
    }
  }
}

public struct LineWiseAppProjection: Equatable, Sendable {
  public let visits: [GymVisitSnapshot]
  public let routeCards: [RouteCardSnapshot]
  public let projects: [ProjectSnapshot]
  public let attempts: [AttemptSnapshot]
  public let attemptRouteCorrections: [AttemptRouteCorrectionSnapshot]
  public let restIntervals: [RestIntervalSnapshot]
  public let activeRest: RestIntervalSnapshot?
  public let activeVisit: GymVisitSnapshot?
  public let currentRouteCard: RouteCardSnapshot?
  public let currentRouteAttempts: [AttemptSnapshot]
  public let pendingReviewCount: Int
  public let reconciliationCount: Int
  public let lastAcceptedActionID: ActionID?

  public init(
    visits: [GymVisitSnapshot],
    routeCards: [RouteCardSnapshot],
    projects: [ProjectSnapshot],
    attempts: [AttemptSnapshot],
    attemptRouteCorrections: [AttemptRouteCorrectionSnapshot] = [],
    restIntervals: [RestIntervalSnapshot],
    activeRest: RestIntervalSnapshot?,
    activeVisit: GymVisitSnapshot?,
    currentRouteCard: RouteCardSnapshot?,
    currentRouteAttempts: [AttemptSnapshot],
    pendingReviewCount: Int,
    reconciliationCount: Int,
    lastAcceptedActionID: ActionID?
  ) {
    self.visits = visits
    self.routeCards = routeCards
    self.projects = projects
    self.attempts = attempts
    self.attemptRouteCorrections = attemptRouteCorrections
    self.restIntervals = restIntervals
    self.activeRest = activeRest
    self.activeVisit = activeVisit
    self.currentRouteCard = currentRouteCard
    self.currentRouteAttempts = currentRouteAttempts
    self.pendingReviewCount = pendingReviewCount
    self.reconciliationCount = reconciliationCount
    self.lastAcceptedActionID = lastAcceptedActionID
  }

  public var currentRouteAttemptCount: Int {
    currentRouteAttempts.count
  }

  public var selectableRouteCards: [RouteCardSnapshot] {
    routeCards.filter {
      $0.recordVisibility == .active && $0.availability != .gone
    }
  }
}

public enum WatchPrimaryAction: Equatable, Sendable {
  case recordAttempt
}

public struct WatchCaptureProjection: Equatable, Sendable {
  public let visitIsOpen: Bool
  public let currentRouteLabel: String?
  public let attemptCount: Int
  public let primaryAction: WatchPrimaryAction
  public let canMarkSend: Bool
  public let canUndo: Bool
  public let isResting: Bool

  public init(
    visitIsOpen: Bool,
    currentRouteLabel: String?,
    attemptCount: Int,
    primaryAction: WatchPrimaryAction,
    canMarkSend: Bool,
    canUndo: Bool,
    isResting: Bool
  ) {
    self.visitIsOpen = visitIsOpen
    self.currentRouteLabel = currentRouteLabel
    self.attemptCount = attemptCount
    self.primaryAction = primaryAction
    self.canMarkSend = canMarkSend
    self.canUndo = canUndo
    self.isResting = isResting
  }
}

public struct LineWiseAppCoordinator {
  private var visitState: VisitState
  private var repository: VisitRepository?
  private var restState: RestState
  private var selectedRouteCardID: RouteCardID?
  private var reversibleActionIDs: [ActionID]

  public init(
    visitState: VisitState = VisitState(),
    restState: RestState = RestState(),
    selectedRouteCardID: RouteCardID? = nil,
    lastAcceptedActionID: ActionID? = nil
  ) {
    self.visitState = visitState
    repository = nil
    self.restState = restState
    self.selectedRouteCardID = selectedRouteCardID
    reversibleActionIDs = lastAcceptedActionID.map { [$0] } ?? []
  }

  public init(
    repository: VisitRepository,
    restState: RestState = RestState(),
    selectedRouteCardID: RouteCardID? = nil,
    lastAcceptedActionID: ActionID? = nil
  ) {
    visitState = VisitState()
    self.repository = repository
    self.restState = restState
    self.selectedRouteCardID = selectedRouteCardID
    reversibleActionIDs = Self.reversibleActionIDs(
      from: repository.persistedEvents,
      localDeviceID: repository.deviceID
    )
    if reversibleActionIDs.isEmpty, let lastAcceptedActionID {
      reversibleActionIDs = [lastAcceptedActionID]
    }
  }

  public var projection: LineWiseAppProjection {
    let snapshot = visitSnapshot
    let activeVisit = snapshot.visits.first { $0.captureState == .open }
    let effectiveRouteCardID = effectiveSelectedRouteCardID(in: snapshot)
    let currentRouteCard = effectiveRouteCardID.flatMap { routeID in
      snapshot.routeCards.first { $0.id == routeID }
    }
    let attempts = snapshot.attempts.filter { attempt in
      attempt.recordState == .active
        && attempt.routeCardID.flatMap { snapshot.canonicalRouteCardID(for: $0) }
          == effectiveRouteCardID
        && (activeVisit == nil || attempt.visitID == activeVisit?.id)
    }
    return LineWiseAppProjection(
      visits: snapshot.visits,
      routeCards: snapshot.routeCards,
      projects: snapshot.projects,
      attempts: snapshot.attempts,
      attemptRouteCorrections: snapshot.attemptRouteCorrections,
      restIntervals: restState.snapshot.intervals,
      activeRest: restState.snapshot.activeRest,
      activeVisit: activeVisit,
      currentRouteCard: currentRouteCard,
      currentRouteAttempts: attempts,
      pendingReviewCount: snapshot.visits.filter {
        $0.reviewState == .pendingReview || $0.reviewState == .needsRecheck
      }.count,
      reconciliationCount: snapshot.reconciliationIssues.count,
      lastAcceptedActionID: reversibleActionIDs.last
    )
  }

  public var watchProjection: WatchCaptureProjection {
    let app = projection
    let latestAttempt = app.currentRouteAttempts.max {
      if $0.occurredAt != $1.occurredAt {
        return $0.occurredAt < $1.occurredAt
      }
      return $0.id.rawValue < $1.id.rawValue
    }
    return WatchCaptureProjection(
      visitIsOpen: app.activeVisit != nil,
      currentRouteLabel: app.currentRouteCard?.label,
      attemptCount: app.currentRouteAttemptCount,
      primaryAction: .recordAttempt,
      canMarkSend: latestAttempt?.outcome != .sent && latestAttempt != nil,
      canUndo: !reversibleActionIDs.isEmpty,
      isResting: app.activeRest != nil
    )
  }

  var persistedRestState: RestState {
    restState
  }

  var persistedSelectedRouteCardID: RouteCardID? {
    selectedRouteCardID
  }

  var persistedReversibleActionIDs: [ActionID] {
    reversibleActionIDs
  }

  var hasPersistentVisitRepository: Bool {
    repository != nil
  }

  mutating func restorePersistedAppState(
    restState: RestState,
    selectedRouteCardID: RouteCardID?,
    reversibleActionIDs: [ActionID]
  ) {
    self.restState = restState
    self.selectedRouteCardID = selectedRouteCardID
    self.reversibleActionIDs = reversibleActionIDs
  }

  @discardableResult
  public mutating func handle(_ intent: LineWiseAppIntent) -> LineWiseAppFeedback {
    if case .selectRoute(let routeCardID) = intent {
      if let routeCardID {
        guard visitSnapshot.routeCards.contains(where: { $0.id == routeCardID }) else {
          return feedback(.locallyRejected(.routeDoesNotExist))
        }
        guard
          let canonicalID = visitSnapshot.canonicalRouteCardID(for: routeCardID),
          visitSnapshot.selectableRouteCards.contains(where: { $0.id == canonicalID })
        else {
          return feedback(.locallyRejected(.routeIsNotSelectable))
        }
        selectedRouteCardID = canonicalID
      } else {
        selectedRouteCardID = nil
      }
      return feedback(.selectionChanged)
    }

    switch intent {
    case .startRest(let actionID, let restID, let afterAttemptID, let occurredAt):
      guard let visitID = projection.activeVisit?.id else {
        return feedback(.locallyRejected(.noOpenVisit))
      }
      let transition = RestMemory.apply(
        .start(
          actionID: actionID,
          restID: restID,
          visitID: visitID,
          afterAttemptID: afterAttemptID,
          occurredAt: occurredAt
        ),
        visitSnapshot: visitSnapshot,
        to: restState
      )
      restState = transition.state
      return feedback(LineWiseAppOutcome(transition.outcome))
    case .stopRest(let actionID, let restID, let occurredAt):
      let transition = RestMemory.apply(
        .stop(actionID: actionID, restID: restID, occurredAt: occurredAt),
        visitSnapshot: visitSnapshot,
        to: restState
      )
      restState = transition.state
      return feedback(LineWiseAppOutcome(transition.outcome))
    default:
      break
    }

    guard let command = domainCommand(for: intent) else {
      return feedback(.locallyRejected(.noOpenVisit))
    }
    let outcome: LineWiseAppOutcome
    if let repository {
      do {
        outcome = LineWiseAppOutcome(try repository.submit(command))
      } catch {
        return feedback(.persistenceFailed(String(describing: error)))
      }
    } else {
      let transition = VisitMemory.apply(command, to: visitState)
      visitState = transition.state
      outcome = LineWiseAppOutcome(transition.outcome)
    }
    if outcome == .accepted {
      updateReversibleActions(after: command)
    }
    return feedback(outcome)
  }

  public var pendingOutboundEvents: [DeviceEventEnvelope] {
    repository?.pendingOutboundEvents ?? []
  }

  @discardableResult
  public mutating func receive(
    _ envelopes: [DeviceEventEnvelope]
  ) -> LineWiseDeviceSyncOutcome {
    guard let repository else { return .unavailable }
    do {
      let receipt = try repository.receive(envelopes)
      reversibleActionIDs = Self.reversibleActionIDs(
        from: repository.persistedEvents,
        localDeviceID: repository.deviceID
      )
      return .received(
        insertedEventIDs: receipt.insertedEventIDs,
        duplicateEventIDs: receipt.duplicateEventIDs
      )
    } catch {
      return .persistenceFailed(String(describing: error))
    }
  }

  @discardableResult
  public mutating func acknowledgeOutbound(
    _ eventID: ActionID
  ) -> LineWiseDeviceSyncOutcome {
    guard let repository else { return .unavailable }
    do {
      return try repository.acknowledgeOutbound(eventID)
        ? .acknowledged(eventID)
        : .alreadyAcknowledged(eventID)
    } catch {
      return .persistenceFailed(String(describing: error))
    }
  }

  private func feedback(_ outcome: LineWiseAppOutcome) -> LineWiseAppFeedback {
    LineWiseAppFeedback(outcome: outcome, projection: projection)
  }

  private var visitSnapshot: VisitSnapshot {
    repository?.snapshot ?? visitState.snapshot
  }

  private func effectiveSelectedRouteCardID(in snapshot: VisitSnapshot) -> RouteCardID? {
    func selectableCanonical(_ routeCardID: RouteCardID?) -> RouteCardID? {
      guard let routeCardID,
        let canonicalID = snapshot.canonicalRouteCardID(for: routeCardID),
        snapshot.selectableRouteCards.contains(where: { $0.id == canonicalID })
      else { return nil }
      return canonicalID
    }

    if let selected = selectableCanonical(selectedRouteCardID) {
      return selected
    }
    if let activeVisitID = snapshot.visits.first(where: { $0.captureState == .open })?.id,
      let recentAttempt = snapshot.attempts.last(where: {
        $0.visitID == activeVisitID && $0.recordState == .active && $0.routeCardID != nil
      }),
      let recent = selectableCanonical(recentAttempt.routeCardID)
    {
      return recent
    }
    if let activeProject = snapshot.projects
      .filter({ $0.state == .active })
      .sorted(by: { $0.startedAt < $1.startedAt })
      .last,
      let projectRoute = selectableCanonical(activeProject.routeCardID)
    {
      return projectRoute
    }
    if snapshot.selectableRouteCards.count == 1 {
      return snapshot.selectableRouteCards[0].id
    }
    return nil
  }

  private mutating func updateReversibleActions(after command: VisitCommand) {
    switch command {
    case .recordAttempt, .markSend, .confirmNotSent:
      reversibleActionIDs.removeAll { $0 == command.actionID }
      reversibleActionIDs.append(command.actionID)
    case .undo(_, let targetActionID, _, _):
      reversibleActionIDs.removeAll { $0 == targetActionID }
    default:
      break
    }
  }

  private static func reversibleActionIDs(
    from events: [DeviceEventEnvelope],
    localDeviceID: DeviceID
  ) -> [ActionID] {
    var state = VisitState()
    var result: [ActionID] = []
    for event in events {
      let transition = VisitMemory.apply(event.command, to: state)
      state = transition.state
      guard transition.outcome == .accepted else { continue }
      switch event.command {
      case .recordAttempt, .markSend, .confirmNotSent:
        guard event.originDeviceID == localDeviceID else { continue }
        result.removeAll { $0 == event.command.actionID }
        result.append(event.command.actionID)
      case .undo(_, let targetActionID, _, _):
        result.removeAll { $0 == targetActionID }
      default:
        break
      }
    }
    return result
  }

  private func domainCommand(for intent: LineWiseAppIntent) -> VisitCommand? {
    switch intent {
    case .createRoute(
      let actionID,
      let routeCardID,
      let label,
      let availability,
      let occurredAt,
      let source
    ):
      .createRouteCard(
        actionID: actionID,
        routeCardID: routeCardID,
        label: label,
        availability: availability,
        occurredAt: occurredAt,
        source: source
      )
    case .reviseRoute(
      let actionID,
      let routeCardID,
      let revisedLabel,
      let occurredAt,
      let source
    ):
      .reviseRouteCard(
        actionID: actionID,
        routeCardID: routeCardID,
        revisedLabel: revisedLabel,
        occurredAt: occurredAt,
        source: source
      )
    case .archiveRoute(let actionID, let routeCardID, let occurredAt, let source):
      .archiveRouteCard(
        actionID: actionID,
        routeCardID: routeCardID,
        occurredAt: occurredAt,
        source: source
      )
    case .restoreRoute(let actionID, let routeCardID, let occurredAt, let source):
      .restoreRouteCard(
        actionID: actionID,
        routeCardID: routeCardID,
        occurredAt: occurredAt,
        source: source
      )
    case .correctRouteAvailability(
      let actionID,
      let routeCardID,
      let availability,
      let occurredAt,
      let source
    ):
      .correctRouteAvailability(
        actionID: actionID,
        routeCardID: routeCardID,
        availability: availability,
        occurredAt: occurredAt,
        source: source
      )
    case .mergeRoute(
      let actionID,
      let duplicateRouteCardID,
      let canonicalRouteCardID,
      let occurredAt,
      let source
    ):
      .confirmRouteCardMerge(
        actionID: actionID,
        duplicateRouteCardID: duplicateRouteCardID,
        canonicalRouteCardID: canonicalRouteCardID,
        occurredAt: occurredAt,
        source: source
      )
    case .unmergeRoute(let actionID, let mergedRouteCardID, let occurredAt, let source):
      .unmergeRouteCard(
        actionID: actionID,
        mergedRouteCardID: mergedRouteCardID,
        occurredAt: occurredAt,
        source: source
      )
    case .correctAttemptRoute(
      let actionID,
      let attemptID,
      let routeCardID,
      let occurredAt,
      let source
    ):
      .correctAttemptRoute(
        actionID: actionID,
        attemptID: attemptID,
        routeCardID: routeCardID,
        occurredAt: occurredAt,
        source: source
      )
    case .startProject(
      let actionID,
      let projectID,
      let routeCardID,
      let occurredAt,
      let source
    ):
      .startProject(
        actionID: actionID,
        projectID: projectID,
        routeCardID: routeCardID,
        occurredAt: occurredAt,
        source: source
      )
    case .archiveProject(let actionID, let projectID, let occurredAt, let source):
      .archiveProject(
        actionID: actionID,
        projectID: projectID,
        occurredAt: occurredAt,
        source: source
      )
    case .startVisit(let actionID, let visitID, let occurredAt, let source):
      .startVisit(
        actionID: actionID,
        visitID: visitID,
        occurredAt: occurredAt,
        source: source
      )
    case .selectRoute:
      nil
    case .recordAttempt(let actionID, let attemptID, let occurredAt, let source):
      projection.activeVisit.map { visit in
        .recordAttempt(
          actionID: actionID,
          attemptID: attemptID,
          visitID: visit.id,
          routeCardID: effectiveSelectedRouteCardID(in: visitSnapshot),
          occurredAt: occurredAt,
          source: source
        )
      }
    case .markSend(let actionID, let attemptID, let occurredAt, let source):
      .markSend(
        actionID: actionID,
        attemptID: attemptID,
        occurredAt: occurredAt,
        source: source
      )
    case .confirmNotSent(let actionID, let attemptID, let occurredAt, let source):
      .confirmNotSent(
        actionID: actionID,
        attemptID: attemptID,
        occurredAt: occurredAt,
        source: source
      )
    case .undo(let actionID, let targetActionID, let occurredAt, let source):
      .undo(
        actionID: actionID,
        targetActionID: targetActionID,
        occurredAt: occurredAt,
        source: source
      )
    case .endVisit(let actionID, let occurredAt, let source):
      projection.activeVisit.map { visit in
        .endVisit(
          actionID: actionID,
          visitID: visit.id,
          occurredAt: occurredAt,
          source: source
        )
      }
    case .beginReview(let actionID, let visitID, let occurredAt, let source):
      .beginReview(
        actionID: actionID,
        visitID: visitID,
        occurredAt: occurredAt,
        source: source
      )
    case .completeReview(let actionID, let visitID, let occurredAt, let source):
      .completeReview(
        actionID: actionID,
        visitID: visitID,
        occurredAt: occurredAt,
        source: source
      )
    case .closeProjectSent(
      let actionID,
      let projectID,
      let supportingAttemptID,
      let occurredAt,
      let source
    ):
      .closeProjectSent(
        actionID: actionID,
        projectID: projectID,
        supportingAttemptID: supportingAttemptID,
        occurredAt: occurredAt,
        source: source
      )
    case .startRest, .stopRest:
      nil
    }
  }
}

extension LineWiseAppOutcome {
  fileprivate init(_ outcome: CommandOutcome) {
    switch outcome {
    case .accepted:
      self = .accepted
    case .duplicate:
      self = .duplicate
    case .conflict(let conflict):
      self = .conflict(conflict)
    case .deferred(let reason):
      self = .deferred(reason)
    case .rejected(let rejection):
      self = .rejected(rejection)
    }
  }

  fileprivate init(_ outcome: RestOutcome) {
    switch outcome {
    case .accepted:
      self = .accepted
    case .duplicate:
      self = .duplicate
    case .rejected(let rejection):
      self = .restRejected(rejection)
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
}
