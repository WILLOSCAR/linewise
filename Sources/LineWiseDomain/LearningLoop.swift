public struct SetterLensReadingID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct TrainingPathID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct MicroDrillID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct ProofCheckID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum SetterLensEvidenceKind: String, Equatable, Codable, Sendable {
  case routePhoto = "route_photo"
  case userReport = "user_report"
  case plannedMovement = "planned_movement"
  case observedMovement = "observed_movement"
}

public struct SetterLensEvidence: Equatable, Codable, Sendable {
  public let id: String
  public let kind: SetterLensEvidenceKind
  public let version: String
  public let summary: String

  public init(id: String, kind: SetterLensEvidenceKind, version: String, summary: String) {
    self.id = id
    self.kind = kind
    self.version = version
    self.summary = summary
  }
}

public enum SetterLensReadingStatus: String, Equatable, Codable, Sendable {
  case suggested
  case userConfirmed = "user_confirmed"
  case rejected
}

public struct SetterLensReadingSnapshot: Equatable, Codable, Sendable {
  public let id: SetterLensReadingID
  public let routeCardID: RouteCardID
  public let evidence: [SetterLensEvidence]
  public let interpretation: String
  public let originallySuggestedInterpretation: String
  public let alternativeInterpretation: String?
  public let status: SetterLensReadingStatus
  public let suggestionProvenance: SuggestionProvenance
  public let createdAt: Instant
  public let updatedAt: Instant

  public init(
    id: SetterLensReadingID,
    routeCardID: RouteCardID,
    evidence: [SetterLensEvidence],
    interpretation: String,
    originallySuggestedInterpretation: String,
    alternativeInterpretation: String?,
    status: SetterLensReadingStatus,
    suggestionProvenance: SuggestionProvenance,
    createdAt: Instant,
    updatedAt: Instant
  ) {
    self.id = id
    self.routeCardID = routeCardID
    self.evidence = evidence
    self.interpretation = interpretation
    self.originallySuggestedInterpretation = originallySuggestedInterpretation
    self.alternativeInterpretation = alternativeInterpretation
    self.status = status
    self.suggestionProvenance = suggestionProvenance
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public enum MicroDrillContentSource: String, Equatable, Codable, Sendable {
  case userAuthored = "user_authored"
  case verifiedCoach = "verified_coach"
  case licensedThirdParty = "licensed_third_party"
  case lineWiseEditorial = "linewise_editorial"
  case modelGenerated = "model_generated"
}

public enum MicroDrillApprovalState: String, Equatable, Codable, Sendable {
  case unreviewed
  case approved
  case retired
}

public struct MicroDrill: Equatable, Codable, Sendable {
  public let id: MicroDrillID
  public let title: String
  public let target: String
  public let routeContext: String
  public let instructions: String
  public let successCriterion: String
  public let source: MicroDrillContentSource
  public let sourceReference: String
  public let version: String
  public let approvalState: MicroDrillApprovalState

  public init(
    id: MicroDrillID,
    title: String,
    target: String,
    routeContext: String,
    instructions: String,
    successCriterion: String,
    source: MicroDrillContentSource,
    sourceReference: String,
    version: String,
    approvalState: MicroDrillApprovalState
  ) {
    self.id = id
    self.title = title
    self.target = target
    self.routeContext = routeContext
    self.instructions = instructions
    self.successCriterion = successCriterion
    self.source = source
    self.sourceReference = sourceReference
    self.version = version
    self.approvalState = approvalState
  }
}

public struct ApprovedMicroDrillCatalog: Equatable, Codable, Sendable {
  public let drills: [MicroDrill]

  public init(drills: [MicroDrill]) {
    self.drills = drills
  }

  fileprivate func approvedDrill(id: MicroDrillID) -> MicroDrill? {
    drills.first {
      $0.id == id && $0.approvalState == .approved && $0.source != .modelGenerated
    }
  }

  public var approvedDrills: [MicroDrill] {
    drills.filter {
      $0.approvalState == .approved && $0.source != .modelGenerated
    }.sorted { $0.id.rawValue < $1.id.rawValue }
  }

  public static let lineWiseEditorialV0 = ApprovedMicroDrillCatalog(
    drills: [
      MicroDrill(
        id: MicroDrillID("linewise-editorial-v0-controlled-pause"),
        title: "Controlled pause rehearsal",
        target: "movement sequencing and body position",
        routeContext: "an easy familiar indoor boulder with comfortable holds",
        instructions:
          "On an easier route, pause in a stable position before the next hand move, name the next foot placement, then continue with normal control. Stop whenever the practice no longer feels appropriate.",
        successCriterion:
          "Complete one deliberate repetition and note whether the intended foot placement happened before the hand move.",
        source: .lineWiseEditorial,
        sourceReference:
          "LineWise editorial v0 · movement practice only · not medical or safety guidance",
        version: "editorial-v0",
        approvalState: .approved
      )
    ]
  )
}

public enum TrainingPathStatus: String, Equatable, Codable, Sendable {
  case draft
  case active
  case retained
  case revisionRequested = "revision_requested"
  case rejected
  case completed
}

public struct TrainingPathSnapshot: Equatable, Codable, Sendable {
  public let id: TrainingPathID
  public let routeCardID: RouteCardID
  public let failureEpisodeID: FailureEpisodeID
  public let moveCueID: MoveCueID
  public let microDrill: MicroDrill
  public let nextSessionCueID: NextSessionCueID
  public let proofQuestion: String
  public let status: TrainingPathStatus
  public let createdAt: Instant
  public let updatedAt: Instant

  public init(
    id: TrainingPathID,
    routeCardID: RouteCardID,
    failureEpisodeID: FailureEpisodeID,
    moveCueID: MoveCueID,
    microDrill: MicroDrill,
    nextSessionCueID: NextSessionCueID,
    proofQuestion: String,
    status: TrainingPathStatus,
    createdAt: Instant,
    updatedAt: Instant
  ) {
    self.id = id
    self.routeCardID = routeCardID
    self.failureEpisodeID = failureEpisodeID
    self.moveCueID = moveCueID
    self.microDrill = microDrill
    self.nextSessionCueID = nextSessionCueID
    self.proofQuestion = proofQuestion
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public enum ProofCheckOutcome: String, Equatable, Codable, Sendable {
  case notTried = "not_tried"
  case triedNoObservableChange = "tried_no_observable_change"
  case triedTargetBehaviorChanged = "tried_target_behavior_changed"
  case triedFeltEasierBehaviorUnclear = "tried_felt_easier_behavior_unclear"
  case attemptImprovedWithOtherChanges = "attempt_improved_with_other_changes"
  case interpretationAppearsWrong = "interpretation_appears_wrong"
  case insufficientEvidence = "insufficient_evidence"
}

public enum ProofDecision: String, Equatable, Codable, Sendable {
  case retain
  case revise
  case reject
}

public struct ProofCheckSnapshot: Equatable, Codable, Sendable {
  public let id: ProofCheckID
  public let pathID: TrainingPathID
  public let attemptID: AttemptID
  public let question: String
  public let outcome: ProofCheckOutcome
  public let decision: ProofDecision
  public let note: String?
  public let occurredAt: Instant

  public init(
    id: ProofCheckID,
    pathID: TrainingPathID,
    attemptID: AttemptID,
    question: String,
    outcome: ProofCheckOutcome,
    decision: ProofDecision,
    note: String?,
    occurredAt: Instant
  ) {
    self.id = id
    self.pathID = pathID
    self.attemptID = attemptID
    self.question = question
    self.outcome = outcome
    self.decision = decision
    self.note = note
    self.occurredAt = occurredAt
  }
}

public struct LearningLoopSnapshot: Equatable, Codable, Sendable {
  public let setterLensReadings: [SetterLensReadingSnapshot]
  public let trainingPaths: [TrainingPathSnapshot]
  public let proofChecks: [ProofCheckSnapshot]

  public init(
    setterLensReadings: [SetterLensReadingSnapshot],
    trainingPaths: [TrainingPathSnapshot],
    proofChecks: [ProofCheckSnapshot]
  ) {
    self.setterLensReadings = setterLensReadings
    self.trainingPaths = trainingPaths
    self.proofChecks = proofChecks
  }
}

public struct LearningLoopState: Equatable, Codable, Sendable {
  var setterLensReadingsByID: [SetterLensReadingID: SetterLensReadingSnapshot]
  var trainingPathsByID: [TrainingPathID: TrainingPathSnapshot]
  var proofChecksByID: [ProofCheckID: ProofCheckSnapshot]
  var appliedCommands: [ActionID: LearningLoopCommand]

  public init() {
    setterLensReadingsByID = [:]
    trainingPathsByID = [:]
    proofChecksByID = [:]
    appliedCommands = [:]
  }

  public var snapshot: LearningLoopSnapshot {
    LearningLoopSnapshot(
      setterLensReadings: setterLensReadingsByID.values.sorted {
        if $0.createdAt != $1.createdAt {
          return $0.createdAt < $1.createdAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      trainingPaths: trainingPathsByID.values.sorted {
        if $0.createdAt != $1.createdAt {
          return $0.createdAt < $1.createdAt
        }
        return $0.id.rawValue < $1.id.rawValue
      },
      proofChecks: proofChecksByID.values.sorted {
        if $0.occurredAt != $1.occurredAt {
          return $0.occurredAt < $1.occurredAt
        }
        return $0.id.rawValue < $1.id.rawValue
      }
    )
  }
}

public enum LearningLoopCommand: Equatable, Codable, Sendable {
  case suggestSetterLensReading(
    actionID: ActionID,
    readingID: SetterLensReadingID,
    routeCardID: RouteCardID,
    evidence: [SetterLensEvidence],
    interpretation: String,
    alternativeInterpretation: String?,
    provenance: SuggestionProvenance,
    occurredAt: Instant
  )
  case acceptSetterLensReading(
    actionID: ActionID,
    readingID: SetterLensReadingID,
    interpretationOverride: String?,
    occurredAt: Instant
  )
  case rejectSetterLensReading(
    actionID: ActionID,
    readingID: SetterLensReadingID,
    occurredAt: Instant
  )
  case draftTrainingPath(
    actionID: ActionID,
    pathID: TrainingPathID,
    failureEpisodeID: FailureEpisodeID,
    moveCueID: MoveCueID,
    microDrillID: MicroDrillID,
    nextSessionCueID: NextSessionCueID,
    proofQuestion: String,
    occurredAt: Instant
  )
  case activateTrainingPath(
    actionID: ActionID,
    pathID: TrainingPathID,
    occurredAt: Instant
  )
  case recordProofCheck(
    actionID: ActionID,
    proofCheckID: ProofCheckID,
    pathID: TrainingPathID,
    attemptID: AttemptID,
    outcome: ProofCheckOutcome,
    decision: ProofDecision,
    note: String?,
    occurredAt: Instant
  )
  case completeTrainingPath(
    actionID: ActionID,
    pathID: TrainingPathID,
    occurredAt: Instant
  )
}

public enum LearningLoopRejection: Equatable, Sendable {
  case actionIDReused
  case setterLensReadingAlreadyExists
  case setterLensReadingDoesNotExist
  case setterLensSuggestionIsNotPending
  case insufficientSetterLensEvidence
  case invalidSuggestionProvenance
  case emptyInterpretation
  case trainingPathAlreadyExists
  case trainingPathDoesNotExist
  case trainingPathRequiresConfirmedFailure
  case trainingPathRecallChainMismatch
  case microDrillIsNotApproved
  case emptyProofQuestion
  case trainingPathIsNotDraft
  case trainingPathIsNotActive
  case proofCheckAlreadyExists
  case proofCheckAttemptDoesNotExist
  case proofCheckAttemptRouteMismatch
  case proofCheckAttemptIsNotLaterThanPath
  case trainingPathCannotComplete
}

public enum LearningLoopOutcome: Equatable, Sendable {
  case accepted
  case duplicate
  case rejected(LearningLoopRejection)
}

public struct LearningLoopTransition: Equatable, Sendable {
  public let state: LearningLoopState
  public let outcome: LearningLoopOutcome

  public init(state: LearningLoopState, outcome: LearningLoopOutcome) {
    self.state = state
    self.outcome = outcome
  }
}

public enum LearningLoop {
  public static func apply(
    _ command: LearningLoopCommand,
    recallSnapshot: RecallTrainingSnapshot,
    catalog: ApprovedMicroDrillCatalog,
    to state: LearningLoopState
  ) -> LearningLoopTransition {
    if let applied = state.appliedCommands[command.actionID] {
      return LearningLoopTransition(
        state: state,
        outcome: applied == command ? .duplicate : .rejected(.actionIDReused)
      )
    }

    var next = state

    switch command {
    case .suggestSetterLensReading(
      _, let readingID, let routeCardID, let evidence, let interpretation,
      let alternativeInterpretation, let provenance, let occurredAt
    ):
      guard next.setterLensReadingsByID[readingID] == nil else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.setterLensReadingAlreadyExists)
        )
      }
      guard !evidence.isEmpty else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.insufficientSetterLensEvidence)
        )
      }
      guard !interpretation.isEmpty else {
        return LearningLoopTransition(state: state, outcome: .rejected(.emptyInterpretation))
      }
      guard
        provenance.decision == .pending,
        provenance.confidence.map({ (0...1).contains($0) }) ?? true
      else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.invalidSuggestionProvenance)
        )
      }
      next.setterLensReadingsByID[readingID] = SetterLensReadingSnapshot(
        id: readingID,
        routeCardID: routeCardID,
        evidence: evidence,
        interpretation: interpretation,
        originallySuggestedInterpretation: interpretation,
        alternativeInterpretation: alternativeInterpretation,
        status: .suggested,
        suggestionProvenance: provenance,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .acceptSetterLensReading(
      _, let readingID, let interpretationOverride, let occurredAt
    ):
      guard let reading = next.setterLensReadingsByID[readingID] else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.setterLensReadingDoesNotExist)
        )
      }
      guard reading.status == .suggested,
        reading.suggestionProvenance.decision == .pending
      else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.setterLensSuggestionIsNotPending)
        )
      }
      let confirmedInterpretation = interpretationOverride ?? reading.interpretation
      guard !confirmedInterpretation.isEmpty else {
        return LearningLoopTransition(state: state, outcome: .rejected(.emptyInterpretation))
      }
      let decision: SuggestionDecision =
        confirmedInterpretation == reading.interpretation ? .accepted : .edited
      next.setterLensReadingsByID[readingID] = SetterLensReadingSnapshot(
        id: reading.id,
        routeCardID: reading.routeCardID,
        evidence: reading.evidence,
        interpretation: confirmedInterpretation,
        originallySuggestedInterpretation: reading.originallySuggestedInterpretation,
        alternativeInterpretation: reading.alternativeInterpretation,
        status: .userConfirmed,
        suggestionProvenance: reading.suggestionProvenance.recording(decision),
        createdAt: reading.createdAt,
        updatedAt: occurredAt
      )

    case .rejectSetterLensReading(_, let readingID, let occurredAt):
      guard let reading = next.setterLensReadingsByID[readingID] else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.setterLensReadingDoesNotExist)
        )
      }
      guard reading.status == .suggested,
        reading.suggestionProvenance.decision == .pending
      else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.setterLensSuggestionIsNotPending)
        )
      }
      next.setterLensReadingsByID[readingID] = SetterLensReadingSnapshot(
        id: reading.id,
        routeCardID: reading.routeCardID,
        evidence: reading.evidence,
        interpretation: reading.interpretation,
        originallySuggestedInterpretation: reading.originallySuggestedInterpretation,
        alternativeInterpretation: reading.alternativeInterpretation,
        status: .rejected,
        suggestionProvenance: reading.suggestionProvenance.recording(.rejected),
        createdAt: reading.createdAt,
        updatedAt: occurredAt
      )

    case .draftTrainingPath(
      _, let pathID, let failureEpisodeID, let moveCueID, let microDrillID,
      let nextSessionCueID, let proofQuestion, let occurredAt
    ):
      guard next.trainingPathsByID[pathID] == nil else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.trainingPathAlreadyExists)
        )
      }
      guard
        let failure = recallSnapshot.failureEpisodes.first(where: {
          $0.id == failureEpisodeID && $0.status == .userConfirmed
        })
      else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.trainingPathRequiresConfirmedFailure)
        )
      }
      guard
        let moveCue = recallSnapshot.moveCues.first(where: {
          $0.id == moveCueID
            && $0.failureEpisodeID == failureEpisodeID
            && ($0.status == .userAuthored || $0.status == .userConfirmed)
        }),
        let nextSessionCue = recallSnapshot.nextSessionCues.first(where: {
          $0.id == nextSessionCueID
            && $0.failureEpisodeID == failureEpisodeID
            && $0.moveCueID == moveCueID
        }),
        moveCue.routeCardID == failure.routeCardID,
        nextSessionCue.routeCardID == failure.routeCardID
      else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.trainingPathRecallChainMismatch)
        )
      }
      guard let drill = catalog.approvedDrill(id: microDrillID) else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.microDrillIsNotApproved)
        )
      }
      guard !proofQuestion.isEmpty else {
        return LearningLoopTransition(state: state, outcome: .rejected(.emptyProofQuestion))
      }
      next.trainingPathsByID[pathID] = TrainingPathSnapshot(
        id: pathID,
        routeCardID: failure.routeCardID,
        failureEpisodeID: failureEpisodeID,
        moveCueID: moveCueID,
        microDrill: drill,
        nextSessionCueID: nextSessionCueID,
        proofQuestion: proofQuestion,
        status: .draft,
        createdAt: occurredAt,
        updatedAt: occurredAt
      )

    case .activateTrainingPath(_, let pathID, let occurredAt):
      guard let path = next.trainingPathsByID[pathID] else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.trainingPathDoesNotExist)
        )
      }
      guard path.status == .draft else {
        return LearningLoopTransition(state: state, outcome: .rejected(.trainingPathIsNotDraft))
      }
      next.trainingPathsByID[pathID] = path.replacing(status: .active, updatedAt: occurredAt)

    case .recordProofCheck(
      _, let proofCheckID, let pathID, let attemptID, let outcome, let decision,
      let note, let occurredAt
    ):
      guard next.proofChecksByID[proofCheckID] == nil else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.proofCheckAlreadyExists)
        )
      }
      guard let path = next.trainingPathsByID[pathID] else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.trainingPathDoesNotExist)
        )
      }
      guard path.status == .active else {
        return LearningLoopTransition(state: state, outcome: .rejected(.trainingPathIsNotActive))
      }
      next.proofChecksByID[proofCheckID] = ProofCheckSnapshot(
        id: proofCheckID,
        pathID: pathID,
        attemptID: attemptID,
        question: path.proofQuestion,
        outcome: outcome,
        decision: decision,
        note: note,
        occurredAt: occurredAt
      )
      let status: TrainingPathStatus
      switch decision {
      case .retain: status = .retained
      case .revise: status = .revisionRequested
      case .reject: status = .rejected
      }
      next.trainingPathsByID[pathID] = path.replacing(status: status, updatedAt: occurredAt)

    case .completeTrainingPath(_, let pathID, let occurredAt):
      guard let path = next.trainingPathsByID[pathID] else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.trainingPathDoesNotExist)
        )
      }
      guard path.status == .retained else {
        return LearningLoopTransition(
          state: state,
          outcome: .rejected(.trainingPathCannotComplete)
        )
      }
      next.trainingPathsByID[pathID] = path.replacing(status: .completed, updatedAt: occurredAt)
    }

    next.appliedCommands[command.actionID] = command
    return LearningLoopTransition(state: next, outcome: .accepted)
  }
}

extension LearningLoopCommand {
  fileprivate var actionID: ActionID {
    switch self {
    case .suggestSetterLensReading(let actionID, _, _, _, _, _, _, _),
      .acceptSetterLensReading(let actionID, _, _, _),
      .rejectSetterLensReading(let actionID, _, _),
      .draftTrainingPath(let actionID, _, _, _, _, _, _, _),
      .activateTrainingPath(let actionID, _, _),
      .recordProofCheck(let actionID, _, _, _, _, _, _, _),
      .completeTrainingPath(let actionID, _, _):
      actionID
    }
  }
}

extension TrainingPathSnapshot {
  fileprivate func replacing(
    status: TrainingPathStatus,
    updatedAt: Instant
  ) -> TrainingPathSnapshot {
    TrainingPathSnapshot(
      id: id,
      routeCardID: routeCardID,
      failureEpisodeID: failureEpisodeID,
      moveCueID: moveCueID,
      microDrill: microDrill,
      nextSessionCueID: nextSessionCueID,
      proofQuestion: proofQuestion,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
