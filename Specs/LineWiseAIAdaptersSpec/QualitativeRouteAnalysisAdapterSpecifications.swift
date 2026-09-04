import Foundation
import LineWiseAIAdapters
import LineWiseDomain

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private enum QualitativeAdapterSpecFailure: Error {
  case expected(String)
}

private func qualitativeAdapterExpect(
  _ condition: @autoclosure () -> Bool,
  _ message: String
) throws {
  guard condition() else {
    throw QualitativeAdapterSpecFailure.expected(message)
  }
}

private actor QualitativeAdapterTransport: RemoteModelHTTPTransport {
  let statusCode: Int
  let responseBody: Data
  private var observedRequest: URLRequest?
  private var calls = 0

  init(statusCode: Int = 200, responseBody: Data) {
    self.statusCode = statusCode
    self.responseBody = responseBody
  }

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    calls += 1
    observedRequest = request
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )!
    return (responseBody, response)
  }

  func request() -> URLRequest? { observedRequest }
  func callCount() -> Int { calls }
}

private struct SuspendingQualitativeTransport: RemoteModelHTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await Task.sleep(nanoseconds: 30_000_000_000)
    throw URLError(.unknown)
  }
}

private func qualitativeEndpoint() throws -> RemoteModelEndpointConfiguration {
  try RemoteModelEndpointConfiguration(
    endpoint: URL(string: "https://model.invalid/qualitative-route-analysis")!,
    providerIdentifier: "remote-qualitative-model",
    providerVersion: "lens-2026-08",
    requestTimeout: 0.25
  )
}

private func qualitativeAdapterRequest(
  includeEvidence: Bool = true
) -> QualitativeRouteAnalysisRequest {
  let routeID = RouteCardID("route-http-lens")
  let failure = FailureEpisodeSnapshot(
    id: FailureEpisodeID("failure-http-lens"),
    attemptID: AttemptID("attempt-http-lens"),
    routeCardID: routeID,
    primaryBlocker: .footwork,
    locationNote: "second move",
    status: .userConfirmed,
    suggestionProvenance: nil,
    createdAt: Instant(millisecondsSince1970: 10),
    updatedAt: Instant(millisecondsSince1970: 20)
  )
  return QualitativeRouteAnalysisRequest(
    routeCardID: routeID,
    routeScene: RouteScene(
      id: RouteSceneID("scene-http-lens"),
      name: "HTTP lens route",
      size: SceneSize(width: 10, height: 18),
      metersPerSceneUnit: 0.1,
      holds: includeEvidence
        ? [Hold(id: HoldID("hold-http-lens"), center: Point2D(x: 3, y: 4), radius: 0.2)]
        : []
    ),
    routeSceneVersion: "scene-http-v7",
    bodyProfile: .generic(id: BodyProfileID("body-http-lens")),
    bodyProfileVersion: "body-http-v3",
    rehearsalComparison: nil,
    stickFigureCue: nil,
    confirmedFailureEpisodes: includeEvidence ? [failure] : [],
    confirmedMoveCues: []
  )
}

private func qualitativeRemoteResponse(
  for request: QualitativeRouteAnalysisRequest,
  confidence: Double = 0.61,
  observations: [QualitativeObservation]? = nil,
  evidenceReferences: [QualitativeEvidenceReference]? = nil,
  claimedAuthorship: String = "official_setter"
) throws -> RemoteQualitativeRouteAnalysisResponse {
  let local = try DeterministicLocalQualitativeRouteAnalysisProvider().analyzeLocally(request)
  return RemoteQualitativeRouteAnalysisResponse(
    observations: observations ?? local.observations,
    candidateMovementFamily: local.candidateMovementFamily,
    candidateConstraint: local.candidateConstraint,
    candidateCrux: local.candidateCrux,
    alternative: local.alternative,
    uncertainties: local.uncertainties,
    evidenceReferences: evidenceReferences ?? local.evidenceReferences,
    confidence: confidence,
    provenance: RemoteQualitativeAnalysisProvenance(
      claimedAuthorship: claimedAuthorship,
      providerIdentifier: "forged-provider",
      version: "forged-version"
    )
  )
}

private func responseCannotForgeAuthorshipAndRequestKeepsPins() async throws {
  let request = qualitativeAdapterRequest()
  let response = try qualitativeRemoteResponse(for: request)
  let transport = QualitativeAdapterTransport(
    responseBody: try JSONEncoder().encode(response)
  )
  let provider = HTTPQualitativeRouteAnalysisProvider(
    configuration: try qualitativeEndpoint(),
    transport: transport
  )

  let result = try await provider.analyze(request)

  let observed = await transport.request()
  let requestBody = try qualitativeAdapterExpectBody(observed)
  let roundTripped = try JSONDecoder().decode(
    QualitativeRouteAnalysisRequest.self,
    from: requestBody
  )
  try qualitativeAdapterExpect(roundTripped == request, "the full evidence pin must be encoded")
  try qualitativeAdapterExpect(
    roundTripped.routeSceneVersion == "scene-http-v7"
      && roundTripped.bodyProfileVersion == "body-http-v3",
    "scene and body versions must survive the boundary"
  )
  try qualitativeAdapterExpect(
    result.provenance.authorship == .suggested
      && result.provenance.evidenceTreatment == .inferred
      && result.provenance.automation == .modelAdapter,
    "a model response can only become an inferred suggestion"
  )
  try qualitativeAdapterExpect(
    result.provenance.providerIdentifier == "remote-qualitative-model"
      && result.provenance.version == "lens-2026-08",
    "configured provenance must replace model-authored provenance"
  )
}

private func outputContractRejectsConfidenceAndEvidenceForgery() async throws {
  let request = qualitativeAdapterRequest()
  let invalidConfidence = try qualitativeRemoteResponse(for: request, confidence: 1.2)
  let confidenceProvider = HTTPQualitativeRouteAnalysisProvider(
    configuration: try qualitativeEndpoint(),
    transport: QualitativeAdapterTransport(
      responseBody: try JSONEncoder().encode(invalidConfidence)
    )
  )
  do {
    _ = try await confidenceProvider.analyze(request)
    throw QualitativeAdapterSpecFailure.expected("invalid confidence should fail")
  } catch let error as RemoteModelAdapterError {
    guard case .responseContractViolation(let reason) = error else {
      throw QualitativeAdapterSpecFailure.expected("expected a response contract failure")
    }
    try qualitativeAdapterExpect(
      reason.contains("confidence"),
      "the confidence violation should remain diagnosable"
    )
  }

  let forgedReference = QualitativeEvidenceReference(
    id: "forged-evidence",
    kind: .stickFigureCue,
    version: "forged-v1"
  )
  let forgedEvidence = try qualitativeRemoteResponse(
    for: request,
    observations: [
      QualitativeObservation(text: "A movement differs.", evidenceReferences: [forgedReference])
    ],
    evidenceReferences: [forgedReference]
  )
  let evidenceProvider = HTTPQualitativeRouteAnalysisProvider(
    configuration: try qualitativeEndpoint(),
    transport: QualitativeAdapterTransport(
      responseBody: try JSONEncoder().encode(forgedEvidence)
    )
  )
  do {
    _ = try await evidenceProvider.analyze(request)
    throw QualitativeAdapterSpecFailure.expected("forged evidence should fail")
  } catch let error as RemoteModelAdapterError {
    guard case .responseContractViolation(let reason) = error else {
      throw QualitativeAdapterSpecFailure.expected("expected a response contract failure")
    }
    try qualitativeAdapterExpect(
      reason.contains("not pinned"),
      "the forged evidence violation should remain diagnosable"
    )
  }
}

private func inputContractRunsBeforeTransportAndCancellationPropagates() async throws {
  let emptyRequest = qualitativeAdapterRequest(includeEvidence: false)
  let unusedTransport = QualitativeAdapterTransport(responseBody: Data())
  let provider = HTTPQualitativeRouteAnalysisProvider(
    configuration: try qualitativeEndpoint(),
    transport: unusedTransport
  )
  do {
    _ = try await provider.analyze(emptyRequest)
    throw QualitativeAdapterSpecFailure.expected("empty evidence should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    try qualitativeAdapterExpect(error == .emptyEvidence, "input failure should stay typed")
  }
  let callCount = await unusedTransport.callCount()
  try qualitativeAdapterExpect(callCount == 0, "invalid input must not reach the model")

  let cancellationProvider = HTTPQualitativeRouteAnalysisProvider(
    configuration: try qualitativeEndpoint(),
    transport: SuspendingQualitativeTransport()
  )
  let task = Task { try await cancellationProvider.analyze(qualitativeAdapterRequest()) }
  await Task.yield()
  task.cancel()
  do {
    _ = try await task.value
    throw QualitativeAdapterSpecFailure.expected("cancellation should propagate")
  } catch is CancellationError {
    // Cancellation must not be hidden inside a model adapter error.
  }

  let statusProvider = HTTPQualitativeRouteAnalysisProvider(
    configuration: try qualitativeEndpoint(),
    transport: QualitativeAdapterTransport(statusCode: 503, responseBody: Data())
  )
  do {
    _ = try await statusProvider.analyze(qualitativeAdapterRequest())
    throw QualitativeAdapterSpecFailure.expected("HTTP status should fail")
  } catch let error as RemoteModelAdapterError {
    try qualitativeAdapterExpect(
      error == .httpStatus(code: 503),
      "HTTP status should preserve the shared adapter error"
    )
  }
}

private func qualitativeAdapterExpectBody(_ request: URLRequest?) throws -> Data {
  guard let request else {
    throw QualitativeAdapterSpecFailure.expected("expected a captured request")
  }
  if let body = request.httpBody { return body }
  guard let stream = request.httpBodyStream else {
    throw QualitativeAdapterSpecFailure.expected("expected a request body")
  }
  stream.open()
  defer { stream.close() }
  var body = Data()
  var buffer = [UInt8](repeating: 0, count: 1_024)
  while stream.hasBytesAvailable {
    let count = stream.read(&buffer, maxLength: buffer.count)
    guard count > 0 else { break }
    body.append(buffer, count: count)
  }
  return body
}

public func qualitativeRouteAnalysisAdapterSpecifications()
  -> [(String, () async throws -> Void)]
{
  [
    (
      "qualitative response cannot forge authorship and the request keeps its pins",
      responseCannotForgeAuthorshipAndRequestKeepsPins
    ),
    (
      "output contract rejects confidence and evidence forgery",
      outputContractRejectsConfidenceAndEvidenceForgery
    ),
    (
      "input contract runs before transport and cancellation propagates",
      inputContractRunsBeforeTransportAndCancellationPropagates
    ),
  ]
}
