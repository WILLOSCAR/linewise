import Foundation

public enum QualitativeMovementFamily: String, CaseIterable, Hashable, Codable, Sendable {
  case balanceAndWeightShift = "balance_and_weight_shift"
  case preciseFootwork = "precise_footwork"
  case bodyTension = "body_tension"
  case compressionAndOpposition = "compression_and_opposition"
  case rotationFlagOrDropKnee = "rotation_flag_or_drop_knee"
  case hookEngagement = "hook_engagement"
  case lockOffOrReachManagement = "lock_off_or_reach_management"
  case coordinationOrDynamicTiming = "coordination_or_dynamic_timing"
  case mantleOrFinishControl = "mantle_or_finish_control"
  case sequenceAndRouteReading = "sequence_and_route_reading"
  case pacingOrEndurance = "pacing_or_endurance"
  case commitmentOrConfidence = "commitment_or_confidence"
  case unknownOrMixed = "unknown_or_mixed"
}

public enum QualitativeConstraint: String, CaseIterable, Hashable, Codable, Sendable {
  case limitedUsableFootholds = "limited_usable_footholds"
  case directionallyPoorHandholds = "directionally_poor_handholds"
  case distanceBetweenUsefulContacts = "distance_between_useful_contacts"
  case requiredCenterOfMassShift = "required_center_of_mass_shift"
  case swingOrCutLooseControl = "swing_or_cut_loose_control"
  case simultaneousContactChange = "simultaneous_contact_change"
  case lowFrictionOrUncertainContact = "low_friction_or_uncertain_contact"
  case narrowTimingWindow = "narrow_timing_window"
  case deceptiveSequence = "deceptive_sequence"
  case bodySizeSensitiveOption = "body_size_sensitive_option"
  case accumulatedFatigueOrPacingContext = "accumulated_fatigue_or_pacing_context"
  case unresolved
}

public enum QualitativeEvidenceKind: String, CaseIterable, Hashable, Codable, Sendable {
  case routeScene = "route_scene"
  case rehearsalComparison = "rehearsal_comparison"
  case stickFigureCue = "stick_figure_cue"
  case failureEpisode = "failure_episode"
  case moveCue = "move_cue"
  case constraintFinding = "constraint_finding"
}

public struct QualitativeEvidenceReference: Hashable, Codable, Sendable {
  public let id: String
  public let kind: QualitativeEvidenceKind
  public let version: String

  public init(id: String, kind: QualitativeEvidenceKind, version: String) {
    self.id = id
    self.kind = kind
    self.version = version
  }
}

public struct QualitativeObservation: Equatable, Codable, Sendable {
  public let text: String
  public let evidenceReferences: [QualitativeEvidenceReference]

  public init(text: String, evidenceReferences: [QualitativeEvidenceReference]) {
    self.text = text
    self.evidenceReferences = evidenceReferences
  }
}

public struct QualitativeCruxCandidate: Equatable, Codable, Sendable {
  public let location: String
  public let explanation: String
  public let evidenceReferences: [QualitativeEvidenceReference]

  public init(
    location: String,
    explanation: String,
    evidenceReferences: [QualitativeEvidenceReference]
  ) {
    self.location = location
    self.explanation = explanation
    self.evidenceReferences = evidenceReferences
  }
}

public struct QualitativeAlternative: Equatable, Codable, Sendable {
  public let movementFamily: QualitativeMovementFamily
  public let constraint: QualitativeConstraint
  public let explanation: String
  public let evidenceReferences: [QualitativeEvidenceReference]

  public init(
    movementFamily: QualitativeMovementFamily,
    constraint: QualitativeConstraint,
    explanation: String,
    evidenceReferences: [QualitativeEvidenceReference]
  ) {
    self.movementFamily = movementFamily
    self.constraint = constraint
    self.explanation = explanation
    self.evidenceReferences = evidenceReferences
  }
}

public struct QualitativeUncertainty: Equatable, Codable, Sendable {
  public let text: String
  public let evidenceReferences: [QualitativeEvidenceReference]

  public init(text: String, evidenceReferences: [QualitativeEvidenceReference]) {
    self.text = text
    self.evidenceReferences = evidenceReferences
  }
}

public enum QualitativeAnalysisAuthorship: String, Equatable, Codable, Sendable {
  case suggested
}

public enum QualitativeEvidenceTreatment: String, Equatable, Codable, Sendable {
  case inferred
}

public enum QualitativeAnalysisAutomation: String, Equatable, Codable, Sendable {
  case deterministicLocal = "deterministic_local"
  case modelAdapter = "model_adapter"
}

public struct QualitativeAnalysisProvenance: Equatable, Codable, Sendable {
  public let authorship: QualitativeAnalysisAuthorship
  public let evidenceTreatment: QualitativeEvidenceTreatment
  public let automation: QualitativeAnalysisAutomation
  public let providerIdentifier: String
  public let version: String

  public init(
    authorship: QualitativeAnalysisAuthorship,
    evidenceTreatment: QualitativeEvidenceTreatment,
    automation: QualitativeAnalysisAutomation,
    providerIdentifier: String,
    version: String
  ) {
    self.authorship = authorship
    self.evidenceTreatment = evidenceTreatment
    self.automation = automation
    self.providerIdentifier = providerIdentifier
    self.version = version
  }
}

public struct QualitativeRouteAnalysisResult: Equatable, Codable, Sendable {
  public let observations: [QualitativeObservation]
  public let candidateMovementFamily: QualitativeMovementFamily
  public let candidateConstraint: QualitativeConstraint
  public let candidateCrux: QualitativeCruxCandidate?
  public let alternative: QualitativeAlternative
  public let uncertainties: [QualitativeUncertainty]
  public let evidenceReferences: [QualitativeEvidenceReference]
  public let confidence: Double
  public let provenance: QualitativeAnalysisProvenance

  public init(
    observations: [QualitativeObservation],
    candidateMovementFamily: QualitativeMovementFamily,
    candidateConstraint: QualitativeConstraint,
    candidateCrux: QualitativeCruxCandidate?,
    alternative: QualitativeAlternative,
    uncertainties: [QualitativeUncertainty],
    evidenceReferences: [QualitativeEvidenceReference],
    confidence: Double,
    provenance: QualitativeAnalysisProvenance
  ) {
    self.observations = observations
    self.candidateMovementFamily = candidateMovementFamily
    self.candidateConstraint = candidateConstraint
    self.candidateCrux = candidateCrux
    self.alternative = alternative
    self.uncertainties = uncertainties
    self.evidenceReferences = evidenceReferences
    self.confidence = confidence
    self.provenance = provenance
  }
}

public struct QualitativeRouteAnalysisRequest: Equatable, Codable, Sendable {
  public let routeCardID: RouteCardID
  public let routeScene: RouteScene
  public let routeSceneVersion: String
  public let bodyProfile: BodyProfile
  public let bodyProfileVersion: String
  public let rehearsalComparison: RehearsalComparison?
  public let stickFigureCue: StickFigureCue?
  public let confirmedFailureEpisodes: [FailureEpisodeSnapshot]
  public let confirmedMoveCues: [MoveCueSnapshot]

  public init(
    routeCardID: RouteCardID,
    routeScene: RouteScene,
    routeSceneVersion: String,
    bodyProfile: BodyProfile,
    bodyProfileVersion: String,
    rehearsalComparison: RehearsalComparison?,
    stickFigureCue: StickFigureCue?,
    confirmedFailureEpisodes: [FailureEpisodeSnapshot],
    confirmedMoveCues: [MoveCueSnapshot]
  ) {
    self.routeCardID = routeCardID
    self.routeScene = routeScene
    self.routeSceneVersion = routeSceneVersion
    self.bodyProfile = bodyProfile
    self.bodyProfileVersion = bodyProfileVersion
    self.rehearsalComparison = rehearsalComparison
    self.stickFigureCue = stickFigureCue
    self.confirmedFailureEpisodes = confirmedFailureEpisodes
    self.confirmedMoveCues = confirmedMoveCues
  }
}

public enum QualitativeRouteAnalysisContractError: Error, Equatable, Sendable {
  case emptyEvidence
  case emptyRouteSceneVersion
  case emptyBodyProfileVersion
  case pinnedSceneMismatch
  case pinnedBodyProfileMismatch
  case pinnedRehearsalMismatch
  case pinnedTimelineVersionMismatch
  case failureEpisodeRouteMismatch(FailureEpisodeID)
  case failureEpisodeIsNotUserConfirmed(FailureEpisodeID)
  case moveCueRouteMismatch(MoveCueID)
  case moveCueIsNotUserConfirmed(MoveCueID)
  case moveCueFailureEpisodeIsNotPinned(MoveCueID)
  case duplicateEvidenceID(String)
  case emptyObservations
  case emptyEvidenceReferences
  case evidenceReferenceIsNotPinned(QualitativeEvidenceReference)
  case evidenceReferenceIsNotDeclared(QualitativeEvidenceReference)
  case evidenceReferenceIsNotUsed(QualitativeEvidenceReference)
  case confidenceOutOfRange
  case emptyStatement
  case prohibitedClaim(String)
  case invalidProvenance
}

public enum QualitativeRouteAnalysisContract {
  public static func validate(_ request: QualitativeRouteAnalysisRequest) throws {
    guard !request.routeSceneVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw QualitativeRouteAnalysisContractError.emptyRouteSceneVersion
    }
    guard !request.bodyProfileVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw QualitativeRouteAnalysisContractError.emptyBodyProfileVersion
    }

    if let comparison = request.rehearsalComparison {
      guard comparison.sceneSnapshot == request.routeScene else {
        throw QualitativeRouteAnalysisContractError.pinnedSceneMismatch
      }
      guard comparison.bodyProfileSnapshot == request.bodyProfile else {
        throw QualitativeRouteAnalysisContractError.pinnedBodyProfileMismatch
      }
      guard
        !comparison.planTimelineVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !comparison.actualTimelineVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw QualitativeRouteAnalysisContractError.pinnedTimelineVersionMismatch
      }
    }

    if let cue = request.stickFigureCue {
      guard cue.sceneSnapshot == request.routeScene else {
        throw QualitativeRouteAnalysisContractError.pinnedSceneMismatch
      }
      guard cue.bodyProfileSnapshot == request.bodyProfile else {
        throw QualitativeRouteAnalysisContractError.pinnedBodyProfileMismatch
      }
      guard !cue.timelineVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw QualitativeRouteAnalysisContractError.pinnedTimelineVersionMismatch
      }
      if let comparison = request.rehearsalComparison {
        guard cue.rehearsalID == comparison.rehearsalID else {
          throw QualitativeRouteAnalysisContractError.pinnedRehearsalMismatch
        }
        let expectedVersion =
          cue.track == .plan
          ? comparison.planTimelineVersion : comparison.actualTimelineVersion
        guard cue.timelineVersion == expectedVersion else {
          throw QualitativeRouteAnalysisContractError.pinnedTimelineVersionMismatch
        }
      }
    }

    try requireUnique(
      request.confirmedFailureEpisodes.map { "failure_episode:\($0.id.rawValue)" }
        + request.confirmedMoveCues.map { "move_cue:\($0.id.rawValue)" }
    )

    let pinnedFailureIDs = Set(request.confirmedFailureEpisodes.map(\.id))
    for failure in request.confirmedFailureEpisodes {
      guard failure.routeCardID == request.routeCardID else {
        throw QualitativeRouteAnalysisContractError.failureEpisodeRouteMismatch(failure.id)
      }
      guard failure.status == .userConfirmed else {
        throw QualitativeRouteAnalysisContractError.failureEpisodeIsNotUserConfirmed(failure.id)
      }
    }
    for moveCue in request.confirmedMoveCues {
      guard moveCue.routeCardID == request.routeCardID else {
        throw QualitativeRouteAnalysisContractError.moveCueRouteMismatch(moveCue.id)
      }
      guard moveCue.status == .userAuthored || moveCue.status == .userConfirmed else {
        throw QualitativeRouteAnalysisContractError.moveCueIsNotUserConfirmed(moveCue.id)
      }
      guard pinnedFailureIDs.contains(moveCue.failureEpisodeID) else {
        throw QualitativeRouteAnalysisContractError.moveCueFailureEpisodeIsNotPinned(moveCue.id)
      }
    }

    let hasSceneEvidence = !request.routeScene.holds.isEmpty
    let hasComparisonEvidence =
      request.rehearsalComparison.map {
        !$0.alignedSteps.isEmpty
          || !$0.planSnapshot.keyframes.isEmpty
          || !$0.actualSnapshot.keyframes.isEmpty
      } ?? false
    let hasStickFigureEvidence =
      request.stickFigureCue.map {
        !$0.keyframes.isEmpty || !$0.steps.isEmpty
      } ?? false
    guard
      hasSceneEvidence || hasComparisonEvidence || hasStickFigureEvidence
        || !request.confirmedFailureEpisodes.isEmpty || !request.confirmedMoveCues.isEmpty
    else {
      throw QualitativeRouteAnalysisContractError.emptyEvidence
    }
  }

  public static func validate(
    _ result: QualitativeRouteAnalysisResult,
    for request: QualitativeRouteAnalysisRequest
  ) throws {
    try validate(request)
    guard !result.observations.isEmpty else {
      throw QualitativeRouteAnalysisContractError.emptyObservations
    }
    guard !result.evidenceReferences.isEmpty else {
      throw QualitativeRouteAnalysisContractError.emptyEvidenceReferences
    }
    guard result.confidence.isFinite, (0...1).contains(result.confidence) else {
      throw QualitativeRouteAnalysisContractError.confidenceOutOfRange
    }
    guard
      !result.provenance.providerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty,
      !result.provenance.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw QualitativeRouteAnalysisContractError.invalidProvenance
    }

    try requireUnique(result.evidenceReferences.map(evidenceKey))
    let available = availableEvidenceReferences(for: request)
    for reference in result.evidenceReferences where !available.contains(reference) {
      throw QualitativeRouteAnalysisContractError.evidenceReferenceIsNotPinned(reference)
    }

    var used = Set<QualitativeEvidenceReference>()
    for observation in result.observations {
      try validateStatement(observation.text)
      try validateReferences(observation.evidenceReferences, available: available, used: &used)
    }
    if let crux = result.candidateCrux {
      try validateStatement(crux.location)
      try validateStatement(crux.explanation)
      try validateReferences(crux.evidenceReferences, available: available, used: &used)
    }
    try validateStatement(result.alternative.explanation)
    try validateReferences(result.alternative.evidenceReferences, available: available, used: &used)
    for uncertainty in result.uncertainties {
      try validateStatement(uncertainty.text)
      try validateReferences(uncertainty.evidenceReferences, available: available, used: &used)
    }

    let declared = Set(result.evidenceReferences)
    for reference in used.sorted(by: { evidenceKey($0) < evidenceKey($1) })
    where !declared.contains(reference) {
      throw QualitativeRouteAnalysisContractError.evidenceReferenceIsNotDeclared(reference)
    }
    for reference in result.evidenceReferences where !used.contains(reference) {
      throw QualitativeRouteAnalysisContractError.evidenceReferenceIsNotUsed(reference)
    }
  }

  public static func availableEvidenceReferences(
    for request: QualitativeRouteAnalysisRequest
  ) -> Set<QualitativeEvidenceReference> {
    var references = Set<QualitativeEvidenceReference>()
    if !request.routeScene.holds.isEmpty {
      references.insert(
        QualitativeEvidenceReference(
          id: request.routeScene.id.rawValue,
          kind: .routeScene,
          version: request.routeSceneVersion
        ))
    }
    if let comparison = request.rehearsalComparison {
      references.insert(
        QualitativeEvidenceReference(
          id: comparison.rehearsalID.rawValue,
          kind: .rehearsalComparison,
          version: "\(comparison.planTimelineVersion)|\(comparison.actualTimelineVersion)"
        ))
      addConstraintFindingReferences(
        from: comparison.planSnapshot.keyframes,
        sourcePrefix: "comparison-plan",
        version: comparison.planTimelineVersion,
        to: &references
      )
      addConstraintFindingReferences(
        from: comparison.actualSnapshot.keyframes,
        sourcePrefix: "comparison-actual",
        version: comparison.actualTimelineVersion,
        to: &references
      )
    }
    if let cue = request.stickFigureCue {
      references.insert(
        QualitativeEvidenceReference(
          id: cue.id.rawValue,
          kind: .stickFigureCue,
          version: cue.timelineVersion
        ))
      addConstraintFindingReferences(
        from: cue.keyframes,
        sourcePrefix: "stick-figure-cue:\(cue.id.rawValue)",
        version: cue.timelineVersion,
        to: &references
      )
    }
    for failure in request.confirmedFailureEpisodes {
      references.insert(
        QualitativeEvidenceReference(
          id: failure.id.rawValue,
          kind: .failureEpisode,
          version: String(failure.updatedAt.rawValue)
        ))
    }
    for moveCue in request.confirmedMoveCues {
      references.insert(
        QualitativeEvidenceReference(
          id: moveCue.id.rawValue,
          kind: .moveCue,
          version: String(moveCue.updatedAt.rawValue)
        ))
    }
    return references
  }

  private static func requireUnique(_ identifiers: [String]) throws {
    var seen = Set<String>()
    for identifier in identifiers where !seen.insert(identifier).inserted {
      throw QualitativeRouteAnalysisContractError.duplicateEvidenceID(identifier)
    }
  }

  private static func evidenceKey(_ reference: QualitativeEvidenceReference) -> String {
    "\(reference.kind.rawValue):\(reference.id):\(reference.version)"
  }

  private static func addConstraintFindingReferences(
    from keyframes: [PoseKeyframe],
    sourcePrefix: String,
    version: String,
    to references: inout Set<QualitativeEvidenceReference>
  ) {
    for frame in keyframes {
      for index in frame.findings.indices {
        references.insert(
          QualitativeEvidenceReference(
            id: "\(sourcePrefix):\(frame.id.rawValue):\(index)",
            kind: .constraintFinding,
            version: version
          ))
      }
    }
  }

  private static func validateReferences(
    _ references: [QualitativeEvidenceReference],
    available: Set<QualitativeEvidenceReference>,
    used: inout Set<QualitativeEvidenceReference>
  ) throws {
    guard !references.isEmpty else {
      throw QualitativeRouteAnalysisContractError.emptyEvidenceReferences
    }
    try requireUnique(references.map(evidenceKey))
    for reference in references {
      guard available.contains(reference) else {
        throw QualitativeRouteAnalysisContractError.evidenceReferenceIsNotPinned(reference)
      }
      used.insert(reference)
    }
  }

  private static func validateStatement(_ value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw QualitativeRouteAnalysisContractError.emptyStatement
    }
    let normalized = trimmed.lowercased()
    let prohibited = [
      "official setter intent",
      "official intent",
      "setter intended",
      "setter's intent",
      "routesetter intended",
      "physically feasible",
      "physically impossible",
      "guaranteed reachable",
      "guaranteed reach",
      "definitely reach",
      "safety",
      "safe",
      "injury",
      "diagnosis",
      "diagnose",
      "medical",
      "官方定线意图",
      "定线员意图",
      "身体上可行",
      "身体上不可行",
      "一定够得到",
      "安全",
      "受伤",
      "伤病",
      "诊断",
      "医疗",
    ]
    if let phrase = prohibited.first(where: normalized.contains) {
      throw QualitativeRouteAnalysisContractError.prohibitedClaim(phrase)
    }
  }
}

public enum QualitativeSetterLensBridge {
  public static func suggestSetterLensReading(
    from result: QualitativeRouteAnalysisResult,
    request: QualitativeRouteAnalysisRequest,
    actionID: ActionID,
    readingID: SetterLensReadingID,
    occurredAt: Instant
  ) throws -> LearningLoopCommand {
    try QualitativeRouteAnalysisContract.validate(result, for: request)
    let evidence = result.evidenceReferences.map { reference in
      SetterLensEvidence(
        id: "\(reference.kind.rawValue):\(reference.id)",
        kind: setterLensKind(for: reference, request: request),
        version: reference.version,
        summary: evidenceSummary(for: reference)
      )
    }
    let cruxSuffix = result.candidateCrux.map { " \($0.explanation)" } ?? ""
    let interpretation =
      "Candidate \(result.candidateMovementFamily.rawValue) under "
      + "\(result.candidateConstraint.rawValue).\(cruxSuffix)"
    let alternative =
      "Alternative \(result.alternative.movementFamily.rawValue) under "
      + "\(result.alternative.constraint.rawValue). \(result.alternative.explanation)"
    let source: SuggestionSource =
      result.provenance.automation == .modelAdapter ? .model : .deterministicTemplate

    return .suggestSetterLensReading(
      actionID: actionID,
      readingID: readingID,
      routeCardID: request.routeCardID,
      evidence: evidence,
      interpretation: interpretation,
      alternativeInterpretation: alternative,
      provenance: SuggestionProvenance(
        suggestionID: "qualitative-route-analysis:\(readingID.rawValue)",
        source: source,
        sourceReference:
          "\(result.provenance.providerIdentifier):\(request.routeCardID.rawValue)",
        sourceVersion: result.provenance.version,
        confidence: result.confidence,
        decision: .pending
      ),
      occurredAt: occurredAt
    )
  }

  private static func setterLensKind(
    for reference: QualitativeEvidenceReference,
    request: QualitativeRouteAnalysisRequest
  ) -> SetterLensEvidenceKind {
    switch reference.kind {
    case .routeScene:
      .routePhoto
    case .failureEpisode, .moveCue:
      .userReport
    case .rehearsalComparison:
      .observedMovement
    case .stickFigureCue:
      request.stickFigureCue?.track == .actual ? .observedMovement : .plannedMovement
    case .constraintFinding:
      reference.id.hasPrefix("comparison-actual")
        || (reference.id.hasPrefix("stick-figure-cue")
          && request.stickFigureCue?.track == .actual)
        ? .observedMovement : .plannedMovement
    }
  }

  private static func evidenceSummary(
    for reference: QualitativeEvidenceReference
  ) -> String {
    switch reference.kind {
    case .routeScene:
      "Pinned RouteScene evidence."
    case .rehearsalComparison:
      "Pinned Plan/Actual comparison evidence."
    case .stickFigureCue:
      "Pinned StickFigureCue evidence."
    case .failureEpisode:
      "User-confirmed FailureEpisode evidence."
    case .moveCue:
      "User-confirmed MoveCue evidence."
    case .constraintFinding:
      "Pinned qualitative ConstraintFinding evidence."
    }
  }
}

public protocol QualitativeRouteAnalysisProvider: Sendable {
  var identifier: String { get }
  func analyze(
    _ request: QualitativeRouteAnalysisRequest
  ) async throws -> QualitativeRouteAnalysisResult
}

public struct DeterministicLocalQualitativeRouteAnalysisProvider:
  QualitativeRouteAnalysisProvider
{
  public let identifier = "deterministic-local-qualitative-route-analysis"
  public let algorithmVersion: String

  public init(algorithmVersion: String = "x0") {
    self.algorithmVersion = algorithmVersion
  }

  public func analyze(
    _ request: QualitativeRouteAnalysisRequest
  ) async throws -> QualitativeRouteAnalysisResult {
    try analyzeLocally(request)
  }

  public func analyzeLocally(
    _ request: QualitativeRouteAnalysisRequest
  ) throws -> QualitativeRouteAnalysisResult {
    try QualitativeRouteAnalysisContract.validate(request)
    let evidenceReferences = QualitativeRouteAnalysisContract.availableEvidenceReferences(
      for: request
    ).sorted(by: evidenceOrder)
    let sceneReference = evidenceReferences.first { $0.kind == .routeScene }
    let primaryFailure = request.confirmedFailureEpisodes.sorted {
      if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
      return $0.id.rawValue < $1.id.rawValue
    }.first
    let pinnedFindings = pinnedConstraintFindings(for: request)
    let classification = classification(
      request: request,
      primaryFailure: primaryFailure,
      pinnedFindings: pinnedFindings,
      fallbackReference: evidenceReferences[0]
    )
    let observations = observations(
      for: request,
      pinnedFindings: pinnedFindings,
      sceneReference: sceneReference
    )
    let crux = QualitativeCruxCandidate(
      location: classification.location,
      explanation:
        "This area may emphasize \(classification.family.rawValue) under \(classification.constraint.rawValue).",
      evidenceReferences: [classification.reference]
    )
    let alternativeClassification:
      (
        family: QualitativeMovementFamily, constraint: QualitativeConstraint
      ) =
        classification.family == .sequenceAndRouteReading
        ? (.balanceAndWeightShift, .requiredCenterOfMassShift)
        : (.sequenceAndRouteReading, .deceptiveSequence)
    var uncertainties: [QualitativeUncertainty] = []
    if request.routeScene.metersPerSceneUnit == nil, let sceneReference {
      uncertainties.append(
        QualitativeUncertainty(
          text: "Scene scale is not pinned, so distance remains qualitative.",
          evidenceReferences: [sceneReference]
        ))
    }
    if request.rehearsalComparison == nil, request.stickFigureCue == nil {
      uncertainties.append(
        QualitativeUncertainty(
          text: "No Plan/Actual movement comparison is pinned for this reading.",
          evidenceReferences: [classification.reference]
        ))
    }
    var confidence = 0.35
    if primaryFailure != nil { confidence += 0.2 }
    if request.rehearsalComparison != nil { confidence += 0.15 }
    if request.stickFigureCue != nil { confidence += 0.1 }
    if !pinnedFindings.isEmpty { confidence += 0.1 }

    let result = QualitativeRouteAnalysisResult(
      observations: observations,
      candidateMovementFamily: classification.family,
      candidateConstraint: classification.constraint,
      candidateCrux: crux,
      alternative: QualitativeAlternative(
        movementFamily: alternativeClassification.family,
        constraint: alternativeClassification.constraint,
        explanation: "A different contact sequence may also explain the same evidence.",
        evidenceReferences: evidenceReferences
      ),
      uncertainties: uncertainties,
      evidenceReferences: evidenceReferences,
      confidence: min(confidence, 0.85),
      provenance: QualitativeAnalysisProvenance(
        authorship: .suggested,
        evidenceTreatment: .inferred,
        automation: .deterministicLocal,
        providerIdentifier: identifier,
        version: algorithmVersion
      )
    )
    try QualitativeRouteAnalysisContract.validate(result, for: request)
    return result
  }

  private struct Classification {
    let family: QualitativeMovementFamily
    let constraint: QualitativeConstraint
    let location: String
    let reference: QualitativeEvidenceReference
  }

  private struct PinnedConstraintFinding {
    let finding: ConstraintFinding
    let reference: QualitativeEvidenceReference
    let location: String
  }

  private func classification(
    request: QualitativeRouteAnalysisRequest,
    primaryFailure: FailureEpisodeSnapshot?,
    pinnedFindings: [PinnedConstraintFinding],
    fallbackReference: QualitativeEvidenceReference
  ) -> Classification {
    if let primaryFailure {
      let mapped = classification(for: primaryFailure.primaryBlocker)
      return Classification(
        family: mapped.family,
        constraint: mapped.constraint,
        location: "user-confirmed failure point",
        reference: QualitativeEvidenceReference(
          id: primaryFailure.id.rawValue,
          kind: .failureEpisode,
          version: String(primaryFailure.updatedAt.rawValue)
        )
      )
    }
    if let pinnedFinding = pinnedFindings.first {
      let mapped = classification(for: pinnedFinding.finding.kind)
      return Classification(
        family: mapped.family,
        constraint: mapped.constraint,
        location: pinnedFinding.location,
        reference: pinnedFinding.reference
      )
    }
    if let comparison = request.rehearsalComparison {
      let comparisonReference = QualitativeEvidenceReference(
        id: comparison.rehearsalID.rawValue,
        kind: .rehearsalComparison,
        version: "\(comparison.planTimelineVersion)|\(comparison.actualTimelineVersion)"
      )
      for aligned in comparison.alignedSteps.sorted(by: {
        $0.alignmentIndex < $1.alignmentIndex
      }) {
        if let divergence = aligned.limbDivergences.first(where: { $0.state == .different }) {
          return Classification(
            family: divergence.limb.isHand ? .sequenceAndRouteReading : .preciseFootwork,
            constraint: divergence.limb.isHand
              ? .directionallyPoorHandholds : .limitedUsableFootholds,
            location: "aligned movement step \(aligned.alignmentIndex + 1)",
            reference: comparisonReference
          )
        }
        if aligned.torsoDivergence.state == .different {
          return Classification(
            family: .balanceAndWeightShift,
            constraint: .requiredCenterOfMassShift,
            location: "aligned movement step \(aligned.alignmentIndex + 1)",
            reference: comparisonReference
          )
        }
        if aligned.timingDivergence.state == .different {
          return Classification(
            family: .coordinationOrDynamicTiming,
            constraint: .narrowTimingWindow,
            location: "aligned movement step \(aligned.alignmentIndex + 1)",
            reference: comparisonReference
          )
        }
      }
    }
    if let cue = request.stickFigureCue {
      let reference = QualitativeEvidenceReference(
        id: cue.id.rawValue,
        kind: .stickFigureCue,
        version: cue.timelineVersion
      )
      if cue.steps.contains(where: { $0.changes.count > 1 }) {
        return Classification(
          family: .coordinationOrDynamicTiming,
          constraint: .simultaneousContactChange,
          location: "pinned StickFigureCue",
          reference: reference
        )
      }
      if cue.steps.flatMap(\.changes).contains(where: { !$0.limb.isHand }) {
        return Classification(
          family: .preciseFootwork,
          constraint: .limitedUsableFootholds,
          location: "pinned StickFigureCue",
          reference: reference
        )
      }
    }
    return Classification(
      family: request.routeScene.holds.count <= 3 ? .preciseFootwork : .sequenceAndRouteReading,
      constraint: request.routeScene.holds.count <= 3
        ? .limitedUsableFootholds : .deceptiveSequence,
      location: "route-wide evidence",
      reference: fallbackReference
    )
  }

  private func classification(
    for blocker: FailureBlocker
  ) -> (family: QualitativeMovementFamily, constraint: QualitativeConstraint) {
    switch blocker {
    case .sequence:
      (.sequenceAndRouteReading, .deceptiveSequence)
    case .footwork:
      (.preciseFootwork, .limitedUsableFootholds)
    case .bodyPosition:
      (.balanceAndWeightShift, .requiredCenterOfMassShift)
    case .bodyTension:
      (.bodyTension, .swingOrCutLooseControl)
    case .dynamicTiming:
      (.coordinationOrDynamicTiming, .narrowTimingWindow)
    case .reachOrLockoff:
      (.lockOffOrReachManagement, .distanceBetweenUsefulContacts)
    case .hookOrCompression:
      (.hookEngagement, .lowFrictionOrUncertainContact)
    case .topoutOrFinish:
      (.mantleOrFinishControl, .simultaneousContactChange)
    case .fearOrCommitment:
      (.commitmentOrConfidence, .unresolved)
    case .enduranceOrPacing:
      (.pacingOrEndurance, .accumulatedFatigueOrPacingContext)
    case .unknown:
      (.unknownOrMixed, .unresolved)
    }
  }

  private func classification(
    for finding: ConstraintFindingKind
  ) -> (family: QualitativeMovementFamily, constraint: QualitativeConstraint) {
    switch finding {
    case .reachLimit:
      (.lockOffOrReachManagement, .distanceBetweenUsefulContacts)
    case .jointRangeTension:
      (.rotationFlagOrDropKnee, .bodySizeSensitiveOption)
    case .contactConflict:
      (.sequenceAndRouteReading, .directionallyPoorHandholds)
    case .wallOrBodyCollision:
      (.rotationFlagOrDropKnee, .requiredCenterOfMassShift)
    case .scaleUncertainty:
      (.unknownOrMixed, .unresolved)
    case .wallAngleUncertainty:
      (.bodyTension, .unresolved)
    case .balanceOrSupportConcern:
      (.balanceAndWeightShift, .requiredCenterOfMassShift)
    case .occludedHold:
      (.sequenceAndRouteReading, .deceptiveSequence)
    case .downstreamInvalidated:
      (.sequenceAndRouteReading, .unresolved)
    case .dynamicMoveRequiresDifferentModel:
      (.coordinationOrDynamicTiming, .narrowTimingWindow)
    }
  }

  private func observations(
    for request: QualitativeRouteAnalysisRequest,
    pinnedFindings: [PinnedConstraintFinding],
    sceneReference: QualitativeEvidenceReference?
  ) -> [QualitativeObservation] {
    var observations: [QualitativeObservation] = []
    if let sceneReference {
      observations.append(
        QualitativeObservation(
          text: "The pinned RouteScene contains \(request.routeScene.holds.count) route contacts.",
          evidenceReferences: [sceneReference]
        ))
    }
    if let comparison = request.rehearsalComparison {
      let reference = QualitativeEvidenceReference(
        id: comparison.rehearsalID.rawValue,
        kind: .rehearsalComparison,
        version: "\(comparison.planTimelineVersion)|\(comparison.actualTimelineVersion)"
      )
      let differentLimb = comparison.alignedSteps.sorted(by: {
        $0.alignmentIndex < $1.alignmentIndex
      }).lazy.compactMap { aligned in
        aligned.limbDivergences.first(where: { $0.state == .different }).map {
          (aligned.alignmentIndex, $0.limb)
        }
      }.first
      let text =
        differentLimb.map {
          "Plan/Actual differ at aligned step \($0.0 + 1) for the \(limbName($0.1)) contact."
        }
        ?? "The pinned Plan/Actual comparison contains \(comparison.alignedSteps.count) aligned steps."
      observations.append(QualitativeObservation(text: text, evidenceReferences: [reference]))
    }
    if let cue = request.stickFigureCue {
      observations.append(
        QualitativeObservation(
          text: "The pinned StickFigureCue contains \(cue.steps.count) movement steps.",
          evidenceReferences: [
            QualitativeEvidenceReference(
              id: cue.id.rawValue,
              kind: .stickFigureCue,
              version: cue.timelineVersion
            )
          ]
        ))
    }
    observations += pinnedFindings.map {
      QualitativeObservation(
        text: "A pinned solver frame contains a \($0.finding.kind.rawValue) qualitative finding.",
        evidenceReferences: [$0.reference]
      )
    }
    observations += request.confirmedFailureEpisodes.sorted { $0.id.rawValue < $1.id.rawValue }.map
    {
      QualitativeObservation(
        text: "The user-confirmed blocker is \($0.primaryBlocker.rawValue).",
        evidenceReferences: [
          QualitativeEvidenceReference(
            id: $0.id.rawValue,
            kind: .failureEpisode,
            version: String($0.updatedAt.rawValue)
          )
        ]
      )
    }
    observations += request.confirmedMoveCues.sorted { $0.id.rawValue < $1.id.rawValue }.map {
      QualitativeObservation(
        text: "A user-confirmed MoveCue is pinned to this failure chain.",
        evidenceReferences: [
          QualitativeEvidenceReference(
            id: $0.id.rawValue,
            kind: .moveCue,
            version: String($0.updatedAt.rawValue)
          )
        ]
      )
    }
    return observations
  }

  private func pinnedConstraintFindings(
    for request: QualitativeRouteAnalysisRequest
  ) -> [PinnedConstraintFinding] {
    var findings: [PinnedConstraintFinding] = []
    if let comparison = request.rehearsalComparison {
      findings += pinnedFindings(
        frames: comparison.planSnapshot.keyframes,
        sourcePrefix: "comparison-plan",
        version: comparison.planTimelineVersion,
        locationPrefix: "planned frame"
      )
      findings += pinnedFindings(
        frames: comparison.actualSnapshot.keyframes,
        sourcePrefix: "comparison-actual",
        version: comparison.actualTimelineVersion,
        locationPrefix: "actual frame"
      )
    }
    if let cue = request.stickFigureCue {
      findings += pinnedFindings(
        frames: cue.keyframes,
        sourcePrefix: "stick-figure-cue:\(cue.id.rawValue)",
        version: cue.timelineVersion,
        locationPrefix: "StickFigureCue frame"
      )
    }
    return findings
  }

  private func pinnedFindings(
    frames: [PoseKeyframe],
    sourcePrefix: String,
    version: String,
    locationPrefix: String
  ) -> [PinnedConstraintFinding] {
    frames.flatMap { frame in
      frame.findings.enumerated().map { index, finding in
        PinnedConstraintFinding(
          finding: finding,
          reference: QualitativeEvidenceReference(
            id: "\(sourcePrefix):\(frame.id.rawValue):\(index)",
            kind: .constraintFinding,
            version: version
          ),
          location: "\(locationPrefix) \(frame.id.rawValue)"
        )
      }
    }
  }

  private func limbName(_ limb: Limb) -> String {
    switch limb {
    case .leftHand: "left hand"
    case .rightHand: "right hand"
    case .leftFoot: "left foot"
    case .rightFoot: "right foot"
    }
  }

  private func evidenceOrder(
    _ lhs: QualitativeEvidenceReference,
    _ rhs: QualitativeEvidenceReference
  ) -> Bool {
    if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
    if lhs.id != rhs.id { return lhs.id < rhs.id }
    return lhs.version < rhs.version
  }
}
