import Foundation
import LineWiseDomain

public struct RemoteQualitativeAnalysisProvenance: Equatable, Codable, Sendable {
  public let claimedAuthorship: String
  public let providerIdentifier: String
  public let version: String

  public init(
    claimedAuthorship: String,
    providerIdentifier: String,
    version: String
  ) {
    self.claimedAuthorship = claimedAuthorship
    self.providerIdentifier = providerIdentifier
    self.version = version
  }
}

public struct RemoteQualitativeRouteAnalysisResponse: Equatable, Codable, Sendable {
  public let observations: [QualitativeObservation]
  public let candidateMovementFamily: QualitativeMovementFamily
  public let candidateConstraint: QualitativeConstraint
  public let candidateCrux: QualitativeCruxCandidate?
  public let alternative: QualitativeAlternative
  public let uncertainties: [QualitativeUncertainty]
  public let evidenceReferences: [QualitativeEvidenceReference]
  public let confidence: Double
  public let provenance: RemoteQualitativeAnalysisProvenance

  public init(
    observations: [QualitativeObservation],
    candidateMovementFamily: QualitativeMovementFamily,
    candidateConstraint: QualitativeConstraint,
    candidateCrux: QualitativeCruxCandidate?,
    alternative: QualitativeAlternative,
    uncertainties: [QualitativeUncertainty],
    evidenceReferences: [QualitativeEvidenceReference],
    confidence: Double,
    provenance: RemoteQualitativeAnalysisProvenance
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

public struct HTTPQualitativeRouteAnalysisProvider: QualitativeRouteAnalysisProvider {
  public var identifier: String { configuration.providerIdentifier }

  private let configuration: RemoteModelEndpointConfiguration
  private let transport: any RemoteModelHTTPTransport

  public init(
    configuration: RemoteModelEndpointConfiguration,
    transport: any RemoteModelHTTPTransport = URLSessionRemoteModelHTTPTransport()
  ) {
    self.configuration = configuration
    self.transport = transport
  }

  public func analyze(
    _ request: QualitativeRouteAnalysisRequest
  ) async throws -> QualitativeRouteAnalysisResult {
    try Task.checkCancellation()
    try QualitativeRouteAnalysisContract.validate(request)
    let response: RemoteQualitativeRouteAnalysisResponse = try await RemoteModelHTTPClient(
      configuration: configuration,
      transport: transport
    ).post(request, responseType: RemoteQualitativeRouteAnalysisResponse.self)
    try Task.checkCancellation()

    let result = QualitativeRouteAnalysisResult(
      observations: response.observations,
      candidateMovementFamily: response.candidateMovementFamily,
      candidateConstraint: response.candidateConstraint,
      candidateCrux: response.candidateCrux,
      alternative: response.alternative,
      uncertainties: response.uncertainties,
      evidenceReferences: response.evidenceReferences,
      confidence: response.confidence,
      provenance: QualitativeAnalysisProvenance(
        authorship: .suggested,
        evidenceTreatment: .inferred,
        automation: .modelAdapter,
        providerIdentifier: configuration.providerIdentifier,
        version: configuration.providerVersion
      )
    )
    do {
      try QualitativeRouteAnalysisContract.validate(result, for: request)
    } catch let error as QualitativeRouteAnalysisContractError {
      throw RemoteModelAdapterError.responseContractViolation(
        reason: contractReason(error)
      )
    }
    return result
  }

  private func contractReason(_ error: QualitativeRouteAnalysisContractError) -> String {
    switch error {
    case .emptyEvidence:
      "request evidence is empty"
    case .emptyRouteSceneVersion:
      "route scene version is empty"
    case .emptyBodyProfileVersion:
      "body profile version is empty"
    case .pinnedSceneMismatch:
      "pinned scene does not match"
    case .pinnedBodyProfileMismatch:
      "pinned body profile does not match"
    case .pinnedRehearsalMismatch:
      "pinned rehearsal does not match"
    case .pinnedTimelineVersionMismatch:
      "pinned timeline version does not match"
    case .failureEpisodeRouteMismatch(let id):
      "FailureEpisode route does not match: \(id.rawValue)"
    case .failureEpisodeIsNotUserConfirmed(let id):
      "FailureEpisode is not user-confirmed: \(id.rawValue)"
    case .moveCueRouteMismatch(let id):
      "MoveCue route does not match: \(id.rawValue)"
    case .moveCueIsNotUserConfirmed(let id):
      "MoveCue is not user-confirmed: \(id.rawValue)"
    case .moveCueFailureEpisodeIsNotPinned(let id):
      "MoveCue FailureEpisode is not pinned: \(id.rawValue)"
    case .duplicateEvidenceID(let id):
      "evidence id is duplicated: \(id)"
    case .emptyObservations:
      "observations are empty"
    case .emptyEvidenceReferences:
      "evidence references are empty"
    case .evidenceReferenceIsNotPinned(let reference):
      "evidence reference is not pinned: \(reference.kind.rawValue):\(reference.id)"
    case .evidenceReferenceIsNotDeclared(let reference):
      "evidence reference is not declared: \(reference.kind.rawValue):\(reference.id)"
    case .evidenceReferenceIsNotUsed(let reference):
      "evidence reference is not used: \(reference.kind.rawValue):\(reference.id)"
    case .confidenceOutOfRange:
      "confidence is outside 0...1"
    case .emptyStatement:
      "a qualitative statement is empty"
    case .prohibitedClaim(let phrase):
      "a qualitative statement contains a prohibited claim: \(phrase)"
    case .invalidProvenance:
      "qualitative provenance is invalid"
    }
  }
}
