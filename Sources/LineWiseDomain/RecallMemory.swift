public struct ReviewInboxItemID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct FailureEpisodeID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct MoveCueID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct NextSessionCueID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum FailureBlocker: String, Equatable, Codable, Sendable {
  case sequence
  case footwork
  case bodyPosition = "body_position"
  case bodyTension = "body_tension"
  case dynamicTiming = "dynamic_timing"
  case reachOrLockoff = "reach_or_lockoff"
  case hookOrCompression = "hook_or_compression"
  case topoutOrFinish = "topout_or_finish"
  case fearOrCommitment = "fear_or_commitment"
  case enduranceOrPacing = "endurance_or_pacing"
  case unknown
}

public enum SuggestionSource: String, Equatable, Codable, Sendable {
  case model
  case deterministicTemplate = "deterministic_template"
  case coach
  case friend
  case setter
}

public enum SuggestionDecision: String, Equatable, Codable, Sendable {
  case pending
  case accepted
  case edited
  case rejected
}

public struct SuggestionProvenance: Equatable, Codable, Sendable {
  public let suggestionID: String
  public let source: SuggestionSource
  public let sourceReference: String
  public let sourceVersion: String
  public let confidence: Double?
  public let decision: SuggestionDecision

  public init(
    suggestionID: String,
    source: SuggestionSource,
    sourceReference: String,
    sourceVersion: String,
    confidence: Double?,
    decision: SuggestionDecision
  ) {
    self.suggestionID = suggestionID
    self.source = source
    self.sourceReference = sourceReference
    self.sourceVersion = sourceVersion
    self.confidence = confidence
    self.decision = decision
  }

  func recording(_ decision: SuggestionDecision) -> SuggestionProvenance {
    SuggestionProvenance(
      suggestionID: suggestionID,
      source: source,
      sourceReference: sourceReference,
      sourceVersion: sourceVersion,
      confidence: confidence,
      decision: decision
    )
  }
}

public enum FailureEpisodeStatus: String, Equatable, Codable, Sendable {
  case suggested
  case userConfirmed = "user_confirmed"
  case rejected
}

public struct FailureEpisodeSnapshot: Equatable, Codable, Sendable {
  public let id: FailureEpisodeID
  public let attemptID: AttemptID
  public let routeCardID: RouteCardID
  public let primaryBlocker: FailureBlocker
  public let suggestedPrimaryBlocker: FailureBlocker?
  public let locationNote: String?
  public let status: FailureEpisodeStatus
  public let suggestionProvenance: SuggestionProvenance?
  public let createdAt: Instant
  public let updatedAt: Instant

  public init(
    id: FailureEpisodeID,
    attemptID: AttemptID,
    routeCardID: RouteCardID,
    primaryBlocker: FailureBlocker,
    suggestedPrimaryBlocker: FailureBlocker? = nil,
    locationNote: String?,
    status: FailureEpisodeStatus,
    suggestionProvenance: SuggestionProvenance?,
    createdAt: Instant,
    updatedAt: Instant
  ) {
    self.id = id
    self.attemptID = attemptID
    self.routeCardID = routeCardID
    self.primaryBlocker = primaryBlocker
    self.suggestedPrimaryBlocker = suggestedPrimaryBlocker
    self.locationNote = locationNote
    self.status = status
    self.suggestionProvenance = suggestionProvenance
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public enum MoveCueStatus: String, Equatable, Codable, Sendable {
  case userAuthored = "user_authored"
  case suggested
  case userConfirmed = "user_confirmed"
  case rejected
}

public struct MoveCueSnapshot: Equatable, Codable, Sendable {
  public let id: MoveCueID
  public let failureEpisodeID: FailureEpisodeID
  public let routeCardID: RouteCardID
  public let text: String
  public let originallySuggestedText: String?
  public let status: MoveCueStatus
  public let suggestionProvenance: SuggestionProvenance?
  public let createdAt: Instant
  public let updatedAt: Instant

  public init(
    id: MoveCueID,
    failureEpisodeID: FailureEpisodeID,
    routeCardID: RouteCardID,
    text: String,
    originallySuggestedText: String? = nil,
    status: MoveCueStatus,
    suggestionProvenance: SuggestionProvenance?,
    createdAt: Instant,
    updatedAt: Instant
  ) {
    self.id = id
    self.failureEpisodeID = failureEpisodeID
    self.routeCardID = routeCardID
    self.text = text
    self.originallySuggestedText = originallySuggestedText
    self.status = status
    self.suggestionProvenance = suggestionProvenance
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public enum NextSessionCueStatus: String, Equatable, Codable, Sendable {
  case ready
  case deferred
  case completed
  case dismissed
}

public struct NextSessionCueSnapshot: Equatable, Codable, Sendable {
  public let id: NextSessionCueID
  public let projectID: ProjectID
  public let routeCardID: RouteCardID
  public let failureEpisodeID: FailureEpisodeID
  public let moveCueID: MoveCueID
  public let nextAction: String
  public let status: NextSessionCueStatus
  public let deferredUntil: Instant?
  public let reopenedInVisitID: GymVisitID?
  public let createdAt: Instant
  public let updatedAt: Instant

  public init(
    id: NextSessionCueID,
    projectID: ProjectID,
    routeCardID: RouteCardID,
    failureEpisodeID: FailureEpisodeID,
    moveCueID: MoveCueID,
    nextAction: String,
    status: NextSessionCueStatus,
    deferredUntil: Instant?,
    reopenedInVisitID: GymVisitID?,
    createdAt: Instant,
    updatedAt: Instant
  ) {
    self.id = id
    self.projectID = projectID
    self.routeCardID = routeCardID
    self.failureEpisodeID = failureEpisodeID
    self.moveCueID = moveCueID
    self.nextAction = nextAction
    self.status = status
    self.deferredUntil = deferredUntil
    self.reopenedInVisitID = reopenedInVisitID
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public enum ReviewInboxItemKind: Equatable, Codable, Sendable {
  case unresolvedAttempt(AttemptID)
  case unassignedAttempt(AttemptID)
  case lateRecord(ActionID)
  case conflictingRecord(ActionID)
  case missingNextSessionCue(ProjectID)
}

public enum ReviewInboxItemStatus: String, Equatable, Codable, Sendable {
  case pending
  case snoozed
  case resolved
  case dismissed
}

public struct ReviewInboxItemSnapshot: Equatable, Codable, Sendable {
  public let id: ReviewInboxItemID
  public let sourceKey: String
  public let visitID: GymVisitID
  public let kind: ReviewInboxItemKind
  public let status: ReviewInboxItemStatus
  public let snoozedUntil: Instant?
  public let createdAt: Instant
  public let updatedAt: Instant

  public init(
    id: ReviewInboxItemID,
    sourceKey: String,
    visitID: GymVisitID,
    kind: ReviewInboxItemKind,
    status: ReviewInboxItemStatus,
    snoozedUntil: Instant?,
    createdAt: Instant,
    updatedAt: Instant
  ) {
    self.id = id
    self.sourceKey = sourceKey
    self.visitID = visitID
    self.kind = kind
    self.status = status
    self.snoozedUntil = snoozedUntil
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct RecallTrainingSnapshot: Equatable, Codable, Sendable {
  public let reviewItems: [ReviewInboxItemSnapshot]
  public let failureEpisodes: [FailureEpisodeSnapshot]
  public let moveCues: [MoveCueSnapshot]
  public let nextSessionCues: [NextSessionCueSnapshot]

  public init(
    reviewItems: [ReviewInboxItemSnapshot],
    failureEpisodes: [FailureEpisodeSnapshot] = [],
    moveCues: [MoveCueSnapshot] = [],
    nextSessionCues: [NextSessionCueSnapshot] = []
  ) {
    self.reviewItems = reviewItems
    self.failureEpisodes = failureEpisodes
    self.moveCues = moveCues
    self.nextSessionCues = nextSessionCues
  }
}

public struct RecallTrainingState: Equatable, Codable, Sendable {
  var reviewItemsByID: [ReviewInboxItemID: ReviewInboxItemSnapshot]
  var failureEpisodesByID: [FailureEpisodeID: FailureEpisodeSnapshot]
  var moveCuesByID: [MoveCueID: MoveCueSnapshot]
  var nextSessionCuesByID: [NextSessionCueID: NextSessionCueSnapshot]
  var appliedCommands: [ActionID: RecallTrainingCommand]

  public init() {
    reviewItemsByID = [:]
    failureEpisodesByID = [:]
    moveCuesByID = [:]
    nextSessionCuesByID = [:]
    appliedCommands = [:]
  }

  public var snapshot: RecallTrainingSnapshot {
    RecallTrainingSnapshot(
      reviewItems: reviewItemsByID.values.sorted {
        if $0.createdAt != $1.createdAt {
          return $0.createdAt < $1.createdAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      failureEpisodes: failureEpisodesByID.values.sorted {
        if $0.createdAt != $1.createdAt {
          return $0.createdAt < $1.createdAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      moveCues: moveCuesByID.values.sorted {
        if $0.createdAt != $1.createdAt {
          return $0.createdAt < $1.createdAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      nextSessionCues: nextSessionCuesByID.values.sorted {
        if $0.createdAt != $1.createdAt {
          return $0.createdAt < $1.createdAt
        }
        return $0.id.rawValue < $1.id.rawValue
      }
    )
  }
}

public enum RecallTrainingCommand: Equatable, Codable, Sendable {
  case enqueueReviewItem(
    actionID: ActionID,
    itemID: ReviewInboxItemID,
    sourceKey: String,
    visitID: GymVisitID,
    kind: ReviewInboxItemKind,
    occurredAt: Instant
  )
  case snoozeReviewItem(
    actionID: ActionID,
    itemID: ReviewInboxItemID,
    until: Instant,
    occurredAt: Instant
  )
  case resolveReviewItem(
    actionID: ActionID,
    itemID: ReviewInboxItemID,
    occurredAt: Instant
  )
  case dismissReviewItem(
    actionID: ActionID,
    itemID: ReviewInboxItemID,
    occurredAt: Instant
  )
  case confirmFailureEpisode(
    actionID: ActionID,
    episodeID: FailureEpisodeID,
    attemptID: AttemptID,
    routeCardID: RouteCardID,
    primaryBlocker: FailureBlocker,
    locationNote: String?,
    occurredAt: Instant
  )
  case suggestFailureEpisode(
    actionID: ActionID,
    episodeID: FailureEpisodeID,
    attemptID: AttemptID,
    routeCardID: RouteCardID,
    primaryBlocker: FailureBlocker,
    locationNote: String?,
    provenance: SuggestionProvenance,
    occurredAt: Instant
  )
  case acceptFailureSuggestion(
    actionID: ActionID,
    episodeID: FailureEpisodeID,
    blockerOverride: FailureBlocker?,
    occurredAt: Instant
  )
  case createMoveCue(
    actionID: ActionID,
    moveCueID: MoveCueID,
    failureEpisodeID: FailureEpisodeID,
    text: String,
    occurredAt: Instant
  )
  case suggestMoveCue(
    actionID: ActionID,
    moveCueID: MoveCueID,
    failureEpisodeID: FailureEpisodeID,
    text: String,
    provenance: SuggestionProvenance,
    occurredAt: Instant
  )
  case acceptMoveCueSuggestion(
    actionID: ActionID,
    moveCueID: MoveCueID,
    textOverride: String?,
    occurredAt: Instant
  )
  case rejectMoveCueSuggestion(
    actionID: ActionID,
    moveCueID: MoveCueID,
    occurredAt: Instant
  )
  case createNextSessionCue(
    actionID: ActionID,
    cueID: NextSessionCueID,
    projectID: ProjectID,
    failureEpisodeID: FailureEpisodeID,
    moveCueID: MoveCueID,
    nextAction: String,
    occurredAt: Instant
  )
  case deferNextSessionCue(
    actionID: ActionID,
    cueID: NextSessionCueID,
    until: Instant?,
    occurredAt: Instant
  )
  case completeNextSessionCue(
    actionID: ActionID,
    cueID: NextSessionCueID,
    occurredAt: Instant
  )
  case dismissNextSessionCue(
    actionID: ActionID,
    cueID: NextSessionCueID,
    occurredAt: Instant
  )
  case reopenNextSessionCue(
    actionID: ActionID,
    cueID: NextSessionCueID,
    visitID: GymVisitID,
    occurredAt: Instant
  )
}

public enum RecallTrainingRejection: Equatable, Sendable {
  case actionIDReused
  case reviewItemAlreadyExists
  case reviewItemDoesNotExist
  case reviewSourceAlreadyTracked
  case dismissedReviewSource
  case reviewItemIsClosed
  case invalidSnoozeDeadline
  case failureEpisodeAlreadyExists
  case failureEpisodeDoesNotExist
  case attemptDoesNotExist
  case attemptRouteDoesNotMatch
  case confirmedFailureRequiresActiveNotSentAttempt
  case suggestedFailureRequiresActiveUnsentAttempt
  case failureSuggestionIsNotPending
  case invalidSuggestionProvenance
  case moveCueAlreadyExists
  case moveCueDoesNotExist
  case moveCueRequiresConfirmedFailure
  case moveCueSuggestionIsNotPending
  case emptyMoveCue
  case nextSessionCueAlreadyExists
  case nextSessionCueDoesNotExist
  case nextSessionCueIsClosed
  case activeNextSessionCueAlreadyExists
  case projectDoesNotExist
  case projectIsNotActive
  case recallChainRouteMismatch
  case nextVisitIsNotOpen
  case invalidNextAction
  case invalidCueDeferral
}

public enum RecallTrainingOutcome: Equatable, Sendable {
  case accepted
  case duplicate
  case rejected(RecallTrainingRejection)
}

public struct RecallTrainingTransition: Equatable, Sendable {
  public let state: RecallTrainingState
  public let outcome: RecallTrainingOutcome

  public init(state: RecallTrainingState, outcome: RecallTrainingOutcome) {
    self.state = state
    self.outcome = outcome
  }
}

public enum RecallTraining {
  public static func apply(
    _ command: RecallTrainingCommand,
    visitSnapshot: VisitSnapshot,
    to state: RecallTrainingState
  ) -> RecallTrainingTransition {
    if let applied = state.appliedCommands[command.actionID] {
      return RecallTrainingTransition(
        state: state,
        outcome: applied == command ? .duplicate : .rejected(.actionIDReused)
      )
    }

    var next = state

    switch command {
    case .enqueueReviewItem(
      _, let itemID, let sourceKey, let visitID, let kind, let occurredAt
    ):
      guard next.reviewItemsByID[itemID] == nil else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.reviewItemAlreadyExists))
      }
      if let existing = next.reviewItemsByID.values.first(where: {
        $0.sourceKey == sourceKey
      }) {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(
            existing.status == .dismissed
              ? .dismissedReviewSource : .reviewSourceAlreadyTracked
          )
        )
      }
      next.reviewItemsByID[itemID] = ReviewInboxItemSnapshot(
        id: itemID,
        sourceKey: sourceKey,
        visitID: visitID,
        kind: kind,
        status: .pending,
        snoozedUntil: nil,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .snoozeReviewItem(_, let itemID, let until, let occurredAt):
      guard let item = next.reviewItemsByID[itemID] else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.reviewItemDoesNotExist))
      }
      guard item.status == .pending || item.status == .snoozed else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.reviewItemIsClosed))
      }
      guard until > occurredAt else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.invalidSnoozeDeadline))
      }
      next.reviewItemsByID[itemID] = item.replacing(
        status: .snoozed,
        snoozedUntil: until,
        updatedAt: occurredAt
      )

    case .resolveReviewItem(_, let itemID, let occurredAt):
      guard let item = next.reviewItemsByID[itemID] else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.reviewItemDoesNotExist))
      }
      guard item.status == .pending || item.status == .snoozed else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.reviewItemIsClosed))
      }
      next.reviewItemsByID[itemID] = item.replacing(
        status: .resolved,
        snoozedUntil: nil,
        updatedAt: occurredAt
      )

    case .dismissReviewItem(_, let itemID, let occurredAt):
      guard let item = next.reviewItemsByID[itemID] else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.reviewItemDoesNotExist))
      }
      guard item.status == .pending || item.status == .snoozed else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.reviewItemIsClosed))
      }
      next.reviewItemsByID[itemID] = item.replacing(
        status: .dismissed,
        snoozedUntil: nil,
        updatedAt: occurredAt
      )

    case .confirmFailureEpisode(
      _, let episodeID, let attemptID, let routeCardID, let primaryBlocker,
      let locationNote, let occurredAt
    ):
      guard next.failureEpisodesByID[episodeID] == nil else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.failureEpisodeAlreadyExists)
        )
      }
      guard let attempt = visitSnapshot.attempts.first(where: { $0.id == attemptID }) else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.attemptDoesNotExist))
      }
      guard attempt.routeCardID == routeCardID else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.attemptRouteDoesNotMatch))
      }
      guard attempt.recordState == .active && attempt.outcome == .notSent else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.confirmedFailureRequiresActiveNotSentAttempt)
        )
      }
      next.failureEpisodesByID[episodeID] = FailureEpisodeSnapshot(
        id: episodeID,
        attemptID: attemptID,
        routeCardID: routeCardID,
        primaryBlocker: primaryBlocker,
        locationNote: locationNote,
        status: .userConfirmed,
        suggestionProvenance: nil,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .suggestFailureEpisode(
      _, let episodeID, let attemptID, let routeCardID, let primaryBlocker,
      let locationNote, let provenance, let occurredAt
    ):
      guard next.failureEpisodesByID[episodeID] == nil else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.failureEpisodeAlreadyExists)
        )
      }
      guard let attempt = visitSnapshot.attempts.first(where: { $0.id == attemptID }) else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.attemptDoesNotExist))
      }
      guard attempt.routeCardID == routeCardID else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.attemptRouteDoesNotMatch))
      }
      guard attempt.recordState == .active && attempt.outcome != .sent else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.suggestedFailureRequiresActiveUnsentAttempt)
        )
      }
      guard
        provenance.decision == .pending,
        provenance.confidence.map({ (0...1).contains($0) }) ?? true
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.invalidSuggestionProvenance)
        )
      }
      next.failureEpisodesByID[episodeID] = FailureEpisodeSnapshot(
        id: episodeID,
        attemptID: attemptID,
        routeCardID: routeCardID,
        primaryBlocker: primaryBlocker,
        suggestedPrimaryBlocker: primaryBlocker,
        locationNote: locationNote,
        status: .suggested,
        suggestionProvenance: provenance,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .acceptFailureSuggestion(_, let episodeID, let blockerOverride, let occurredAt):
      guard let episode = next.failureEpisodesByID[episodeID] else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.failureEpisodeDoesNotExist)
        )
      }
      guard episode.status == .suggested,
        let provenance = episode.suggestionProvenance,
        provenance.decision == .pending
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.failureSuggestionIsNotPending)
        )
      }
      guard
        let attempt = visitSnapshot.attempts.first(where: { $0.id == episode.attemptID })
      else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.attemptDoesNotExist))
      }
      guard
        canonicalRouteCardID(attempt.routeCardID, in: visitSnapshot)
          == canonicalRouteCardID(episode.routeCardID, in: visitSnapshot)
      else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.attemptRouteDoesNotMatch))
      }
      guard attempt.recordState == .active, attempt.outcome == .notSent else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.confirmedFailureRequiresActiveNotSentAttempt)
        )
      }
      let confirmedBlocker = blockerOverride ?? episode.primaryBlocker
      let decision: SuggestionDecision =
        confirmedBlocker == episode.primaryBlocker ? .accepted : .edited
      next.failureEpisodesByID[episodeID] = FailureEpisodeSnapshot(
        id: episode.id,
        attemptID: episode.attemptID,
        routeCardID: episode.routeCardID,
        primaryBlocker: confirmedBlocker,
        suggestedPrimaryBlocker: episode.suggestedPrimaryBlocker,
        locationNote: episode.locationNote,
        status: .userConfirmed,
        suggestionProvenance: provenance.recording(decision),
        createdAt: episode.createdAt,
        updatedAt: occurredAt
      )

    case .createMoveCue(_, let moveCueID, let failureEpisodeID, let text, let occurredAt):
      guard next.moveCuesByID[moveCueID] == nil else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.moveCueAlreadyExists))
      }
      guard !text.isEmpty else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.emptyMoveCue))
      }
      guard let failure = next.failureEpisodesByID[failureEpisodeID],
        failure.status == .userConfirmed
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.moveCueRequiresConfirmedFailure)
        )
      }
      next.moveCuesByID[moveCueID] = MoveCueSnapshot(
        id: moveCueID,
        failureEpisodeID: failureEpisodeID,
        routeCardID: failure.routeCardID,
        text: text,
        status: .userAuthored,
        suggestionProvenance: nil,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .suggestMoveCue(
      _, let moveCueID, let failureEpisodeID, let text, let provenance, let occurredAt
    ):
      guard next.moveCuesByID[moveCueID] == nil else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.moveCueAlreadyExists))
      }
      guard !text.isEmpty else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.emptyMoveCue))
      }
      guard let failure = next.failureEpisodesByID[failureEpisodeID],
        failure.status != .rejected
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.failureEpisodeDoesNotExist)
        )
      }
      guard
        provenance.decision == .pending,
        provenance.confidence.map({ (0...1).contains($0) }) ?? true
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.invalidSuggestionProvenance)
        )
      }
      next.moveCuesByID[moveCueID] = MoveCueSnapshot(
        id: moveCueID,
        failureEpisodeID: failureEpisodeID,
        routeCardID: failure.routeCardID,
        text: text,
        originallySuggestedText: text,
        status: .suggested,
        suggestionProvenance: provenance,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .acceptMoveCueSuggestion(_, let moveCueID, let textOverride, let occurredAt):
      guard let moveCue = next.moveCuesByID[moveCueID] else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.moveCueDoesNotExist))
      }
      guard moveCue.status == .suggested,
        let provenance = moveCue.suggestionProvenance,
        provenance.decision == .pending
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.moveCueSuggestionIsNotPending)
        )
      }
      guard next.failureEpisodesByID[moveCue.failureEpisodeID]?.status == .userConfirmed else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.moveCueRequiresConfirmedFailure)
        )
      }
      let confirmedText = textOverride ?? moveCue.text
      guard !confirmedText.isEmpty else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.emptyMoveCue))
      }
      let decision: SuggestionDecision = confirmedText == moveCue.text ? .accepted : .edited
      next.moveCuesByID[moveCueID] = MoveCueSnapshot(
        id: moveCue.id,
        failureEpisodeID: moveCue.failureEpisodeID,
        routeCardID: moveCue.routeCardID,
        text: confirmedText,
        originallySuggestedText: moveCue.originallySuggestedText,
        status: .userConfirmed,
        suggestionProvenance: provenance.recording(decision),
        createdAt: moveCue.createdAt,
        updatedAt: occurredAt
      )

    case .rejectMoveCueSuggestion(_, let moveCueID, let occurredAt):
      guard let moveCue = next.moveCuesByID[moveCueID] else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.moveCueDoesNotExist))
      }
      guard moveCue.status == .suggested,
        let provenance = moveCue.suggestionProvenance,
        provenance.decision == .pending
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.moveCueSuggestionIsNotPending)
        )
      }
      next.moveCuesByID[moveCueID] = MoveCueSnapshot(
        id: moveCue.id,
        failureEpisodeID: moveCue.failureEpisodeID,
        routeCardID: moveCue.routeCardID,
        text: moveCue.text,
        originallySuggestedText: moveCue.originallySuggestedText,
        status: .rejected,
        suggestionProvenance: provenance.recording(.rejected),
        createdAt: moveCue.createdAt,
        updatedAt: occurredAt
      )

    case .createNextSessionCue(
      _, let cueID, let projectID, let failureEpisodeID, let moveCueID,
      let nextAction, let occurredAt
    ):
      guard next.nextSessionCuesByID[cueID] == nil else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.nextSessionCueAlreadyExists)
        )
      }
      guard !nextAction.isEmpty else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.invalidNextAction))
      }
      guard let project = visitSnapshot.projects.first(where: { $0.id == projectID }) else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.projectDoesNotExist))
      }
      guard project.state == .active else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.projectIsNotActive))
      }
      guard let failure = next.failureEpisodesByID[failureEpisodeID],
        failure.status == .userConfirmed
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.moveCueRequiresConfirmedFailure)
        )
      }
      guard let moveCue = next.moveCuesByID[moveCueID],
        moveCue.failureEpisodeID == failureEpisodeID,
        moveCue.status == .userAuthored || moveCue.status == .userConfirmed,
        project.routeCardID == failure.routeCardID,
        moveCue.routeCardID == failure.routeCardID
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.recallChainRouteMismatch)
        )
      }
      guard
        !next.nextSessionCuesByID.values.contains(where: {
          $0.projectID == projectID && ($0.status == .ready || $0.status == .deferred)
        })
      else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.activeNextSessionCueAlreadyExists)
        )
      }
      next.nextSessionCuesByID[cueID] = NextSessionCueSnapshot(
        id: cueID,
        projectID: projectID,
        routeCardID: project.routeCardID,
        failureEpisodeID: failureEpisodeID,
        moveCueID: moveCueID,
        nextAction: nextAction,
        status: .ready,
        deferredUntil: nil,
        reopenedInVisitID: nil,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .deferNextSessionCue(_, let cueID, let until, let occurredAt):
      guard let cue = next.nextSessionCuesByID[cueID] else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.nextSessionCueDoesNotExist)
        )
      }
      guard cue.isOpenForDecision else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.nextSessionCueIsClosed))
      }
      guard until.map({ $0 > occurredAt }) ?? true else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.invalidCueDeferral))
      }
      next.nextSessionCuesByID[cueID] = cue.replacing(
        status: .deferred,
        deferredUntil: until,
        reopenedInVisitID: cue.reopenedInVisitID,
        updatedAt: occurredAt
      )

    case .completeNextSessionCue(_, let cueID, let occurredAt):
      guard let cue = next.nextSessionCuesByID[cueID] else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.nextSessionCueDoesNotExist)
        )
      }
      guard cue.isOpenForDecision else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.nextSessionCueIsClosed))
      }
      next.nextSessionCuesByID[cueID] = cue.replacing(
        status: .completed,
        deferredUntil: nil,
        reopenedInVisitID: cue.reopenedInVisitID,
        updatedAt: occurredAt
      )

    case .dismissNextSessionCue(_, let cueID, let occurredAt):
      guard let cue = next.nextSessionCuesByID[cueID] else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.nextSessionCueDoesNotExist)
        )
      }
      guard cue.isOpenForDecision else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.nextSessionCueIsClosed))
      }
      next.nextSessionCuesByID[cueID] = cue.replacing(
        status: .dismissed,
        deferredUntil: nil,
        reopenedInVisitID: cue.reopenedInVisitID,
        updatedAt: occurredAt
      )

    case .reopenNextSessionCue(_, let cueID, let visitID, let occurredAt):
      guard let cue = next.nextSessionCuesByID[cueID] else {
        return RecallTrainingTransition(
          state: state,
          outcome: .rejected(.nextSessionCueDoesNotExist)
        )
      }
      guard
        visitSnapshot.visits.contains(where: {
          $0.id == visitID && $0.captureState == .open
        })
      else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.nextVisitIsNotOpen))
      }
      guard
        visitSnapshot.projects.contains(where: {
          $0.id == cue.projectID && $0.state == .active
        })
      else {
        return RecallTrainingTransition(state: state, outcome: .rejected(.projectIsNotActive))
      }
      next.nextSessionCuesByID[cueID] = cue.replacing(
        status: .ready,
        deferredUntil: nil,
        reopenedInVisitID: visitID,
        updatedAt: occurredAt
      )
    }

    next.appliedCommands[command.actionID] = command
    return RecallTrainingTransition(state: next, outcome: .accepted)
  }

  /// Resolves a RouteCard to the identity a later merge folded it into, so recall evidence
  /// stays anchored across a RouteCard merge. An unknown RouteCard stays its own anchor,
  /// and an Attempt with no RouteCard yet never matches a route-anchored record.
  private static func canonicalRouteCardID(
    _ routeCardID: RouteCardID?,
    in visitSnapshot: VisitSnapshot
  ) -> RouteCardID? {
    guard let routeCardID else { return nil }
    return visitSnapshot.canonicalRouteCardID(for: routeCardID) ?? routeCardID
  }
}

extension RecallTrainingCommand {
  fileprivate var actionID: ActionID {
    switch self {
    case .enqueueReviewItem(let actionID, _, _, _, _, _),
      .snoozeReviewItem(let actionID, _, _, _),
      .resolveReviewItem(let actionID, _, _),
      .dismissReviewItem(let actionID, _, _),
      .confirmFailureEpisode(let actionID, _, _, _, _, _, _),
      .suggestFailureEpisode(let actionID, _, _, _, _, _, _, _),
      .acceptFailureSuggestion(let actionID, _, _, _),
      .createMoveCue(let actionID, _, _, _, _),
      .suggestMoveCue(let actionID, _, _, _, _, _),
      .acceptMoveCueSuggestion(let actionID, _, _, _),
      .rejectMoveCueSuggestion(let actionID, _, _),
      .createNextSessionCue(let actionID, _, _, _, _, _, _),
      .deferNextSessionCue(let actionID, _, _, _),
      .completeNextSessionCue(let actionID, _, _),
      .dismissNextSessionCue(let actionID, _, _),
      .reopenNextSessionCue(let actionID, _, _, _):
      actionID
    }
  }
}

extension ReviewInboxItemSnapshot {
  fileprivate func replacing(
    status: ReviewInboxItemStatus,
    snoozedUntil: Instant?,
    updatedAt: Instant
  ) -> ReviewInboxItemSnapshot {
    ReviewInboxItemSnapshot(
      id: id,
      sourceKey: sourceKey,
      visitID: visitID,
      kind: kind,
      status: status,
      snoozedUntil: snoozedUntil,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension NextSessionCueSnapshot {
  /// A cue accepts a new complete/defer/dismiss decision only while it is still open.
  /// A snapshot keeps just its current status, so overwriting a terminal decision would
  /// erase what the user chose; a closed cue returns only through an explicit reopen.
  fileprivate var isOpenForDecision: Bool {
    switch status {
    case .ready, .deferred:
      true
    case .completed, .dismissed:
      false
    }
  }

  fileprivate func replacing(
    status: NextSessionCueStatus,
    deferredUntil: Instant?,
    reopenedInVisitID: GymVisitID?,
    updatedAt: Instant
  ) -> NextSessionCueSnapshot {
    NextSessionCueSnapshot(
      id: id,
      projectID: projectID,
      routeCardID: routeCardID,
      failureEpisodeID: failureEpisodeID,
      moveCueID: moveCueID,
      nextAction: nextAction,
      status: status,
      deferredUntil: deferredUntil,
      reopenedInVisitID: reopenedInVisitID,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
