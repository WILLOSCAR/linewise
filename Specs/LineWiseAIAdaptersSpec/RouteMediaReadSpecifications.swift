import Foundation
import LineWiseAIAdapters
import LineWiseDomain

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

private enum RouteMediaReadSpecFailure: Error {
  case expected(String)
}

private func mediaExpect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw RouteMediaReadSpecFailure.expected(message) }
}

private actor MediaRequestTransport: RemoteModelHTTPTransport {
  private let statusCode: Int
  private let responseBody: Data
  private var observedRequest: URLRequest?

  init(statusCode: Int = 200, responseBody: Data) {
    self.statusCode = statusCode
    self.responseBody = responseBody
  }

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
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
}

private struct DictionaryMediaLoader: RouteMediaDataLoader {
  let dataByFileIdentifier: [String: Data]

  func loadData(for reference: LocalMediaReference) async throws -> Data {
    guard let data = dataByFileIdentifier[reference.fileIdentifier] else {
      throw RouteMediaReadSpecFailure.expected("missing fixture media")
    }
    return data
  }
}

private actor CountingMediaLoader: RouteMediaDataLoader {
  private let data: Data
  private var count = 0

  init(data: Data) {
    self.data = data
  }

  func loadData(for reference: LocalMediaReference) async throws -> Data {
    count += 1
    return data
  }

  func loadCount() -> Int { count }
}

private struct SuspendingMediaLoader: RouteMediaDataLoader {
  func loadData(for reference: LocalMediaReference) async throws -> Data {
    try await Task.sleep(nanoseconds: 30_000_000_000)
    return Data()
  }
}

private struct TimedOutMediaTransport: RemoteModelHTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    throw URLError(.timedOut)
  }
}

private struct CapturedMediaReadPayload: Decodable {
  let routeRead: RouteReadRequest
  let media: [CapturedMediaPayload]
}

private struct CapturedMediaPayload: Decodable {
  let assetID: RouteMediaAssetID
  let routeCardID: RouteCardID
  let mimeType: String
  let byteCount: Int64
  let purpose: MediaPurpose
  let lineage: CapturedMediaLineage
  let contentBase64: String
}

private struct CapturedMediaLineage: Decodable {
  let origin: String
  let sourceAssetIDs: [RouteMediaAssetID]
  let transform: MediaDerivation?
}

private func mediaEndpointConfiguration() throws -> RemoteModelEndpointConfiguration {
  try RemoteModelEndpointConfiguration(
    endpoint: URL(string: "https://model.invalid/route-media-read")!,
    providerIdentifier: "media-model",
    providerVersion: "route-v3",
    requestTimeout: 0.25
  )
}

private func mediaRouteReadRequest() -> RouteReadRequest {
  RouteReadRequest(
    sceneID: RouteSceneID("scene-media"),
    name: "Media route",
    size: SceneSize(width: 9, height: 16),
    metersPerSceneUnit: nil,
    candidateHolds: []
  )
}

private func mediaScene() -> RouteScene {
  RouteScene(
    id: RouteSceneID("scene-media"),
    name: "Media route",
    size: SceneSize(width: 9, height: 16),
    metersPerSceneUnit: nil,
    holds: [Hold(id: HoldID("hold-media"), center: Point2D(x: 4, y: 7), radius: 0.4)]
  )
}

private func mediaAsset(
  id: String,
  fileIdentifier: String,
  byteCount: Int64,
  digest: String,
  consent: MediaConsent = MediaConsent(
    status: .granted,
    scope: .explicitModelProcessing,
    recordedAt: Instant(millisecondsSince1970: 1_800)
  ),
  purpose: MediaPurpose = .routeReference,
  mimeType: String = "image/png",
  origin: MediaAssetOrigin = .source
) -> RouteMediaAsset {
  RouteMediaAsset(
    id: RouteMediaAssetID(id),
    routeCardID: RouteCardID("route-media"),
    localReference: LocalMediaReference(
      fileIdentifier: fileIdentifier,
      sandboxRelativePath: "private/\(fileIdentifier)"
    ),
    kind: .routePhoto,
    mimeType: mimeType,
    byteCount: byteCount,
    dimensions: MediaDimensions(pixelWidth: 1200, pixelHeight: 1800),
    contentDigest: MediaContentDigest(algorithm: .sha256, hexValue: digest),
    purpose: purpose,
    consent: consent,
    captureProvenance: MediaCaptureProvenance(
      capturedAt: Instant(millisecondsSince1970: 1_700),
      deviceClass: .phone,
      method: .cameraCapture,
      importedByUser: true
    ),
    origin: origin,
    quality: .usable,
    retention: .keepUntilUserDeletes
  )
}

private func routeMediaSuccessCarriesVerifiedBytesAndLineage() async throws {
  let sourceBytes = Data("abc".utf8)
  let derivedBytes = Data("hello".utf8)
  let source = mediaAsset(
    id: "source-photo",
    fileIdentifier: "source-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  let derived = mediaAsset(
    id: "derived-crop",
    fileIdentifier: "derived-file",
    byteCount: 5,
    digest: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
    origin: .derived(
      sourceAssetIDs: [source.id],
      transform: MediaDerivation(
        kind: .crop,
        implementationIdentifier: "linewise.crop",
        version: "1"
      )
    )
  )
  let response = try JSONEncoder().encode(RemoteRouteReadResponse(scene: mediaScene()))
  let transport = MediaRequestTransport(responseBody: response)
  let provider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: DictionaryMediaLoader(
      dataByFileIdentifier: [
        "source-file": sourceBytes,
        "derived-file": derivedBytes,
      ]
    ),
    transport: transport,
    maximumTotalByteCount: 16
  )
  let routeRead = mediaRouteReadRequest()

  let result = try await provider.read(
    RouteMediaReadRequest(routeRead: routeRead, assets: [source, derived])
  )

  let observed = await transport.request()
  let body = try mediaExpectBody(observed)
  let payload = try JSONDecoder().decode(CapturedMediaReadPayload.self, from: body)
  try mediaExpect(payload.routeRead == routeRead, "route-read contract should be lossless")
  try mediaExpect(payload.media.count == 2, "both authorized assets should be sent")
  try mediaExpect(
    payload.media[0].contentBase64 == "YWJj"
      && payload.media[1].contentBase64 == "aGVsbG8=",
    "verified bytes should be encoded only in the request payload"
  )
  try mediaExpect(payload.media[0].lineage.origin == "source", "source lineage should survive")
  try mediaExpect(
    payload.media[1].lineage.origin == "derived"
      && payload.media[1].lineage.sourceAssetIDs == [source.id]
      && payload.media[1].lineage.transform?.kind == .crop,
    "derived lineage should survive"
  )
  try mediaExpect(
    !String(decoding: body, as: UTF8.self).contains("private/source-file"),
    "sandbox paths must not leave the adapter"
  )
  try mediaExpect(result.scene == mediaScene(), "remote scene should be returned")
  try mediaExpect(
    result.provenance.authorship == .suggested
      && result.provenance.automation == .modelAdapter
      && result.provenance.providerIdentifier == "media-model"
      && result.provenance.version == "route-v3",
    "media route read must remain a model suggestion"
  )
}

private func routeMediaRequiresCurrentExplicitModelConsent() async throws {
  let response = try JSONEncoder().encode(RemoteRouteReadResponse(scene: mediaScene()))
  let revokedLoader = CountingMediaLoader(data: Data("abc".utf8))
  let revoked = mediaAsset(
    id: "revoked-photo",
    fileIdentifier: "revoked-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    consent: MediaConsent(
      status: .revoked,
      scope: .explicitModelProcessing,
      recordedAt: Instant(millisecondsSince1970: 1_900)
    )
  )
  let revokedProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: revokedLoader,
    transport: MediaRequestTransport(responseBody: response)
  )

  do {
    _ = try await revokedProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [revoked])
    )
    throw RouteMediaReadSpecFailure.expected("revoked consent should block model processing")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(
      error == .consentNotGranted(assetID: revoked.id, status: .revoked),
      "revoked consent should be explicit"
    )
  }
  let revokedLoadCount = await revokedLoader.loadCount()
  try mediaExpect(revokedLoadCount == 0, "revoked bytes must never be loaded")

  let wrongScopeLoader = CountingMediaLoader(data: Data("abc".utf8))
  let wrongScope = mediaAsset(
    id: "storage-only-photo",
    fileIdentifier: "storage-only-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    consent: MediaConsent(
      status: .granted,
      scope: .storageOnly,
      recordedAt: Instant(millisecondsSince1970: 1_900)
    )
  )
  let wrongScopeProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: wrongScopeLoader,
    transport: MediaRequestTransport(responseBody: response)
  )
  do {
    _ = try await wrongScopeProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [wrongScope])
    )
    throw RouteMediaReadSpecFailure.expected(
      "storage consent should not authorize model processing")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(
      error == .consentScopeMismatch(assetID: wrongScope.id, actual: .storageOnly),
      "wrong processing scope should be explicit"
    )
  }
  let wrongScopeLoadCount = await wrongScopeLoader.loadCount()
  try mediaExpect(wrongScopeLoadCount == 0, "wrong-scope bytes must never be loaded")
}

private func routeMediaRequiresRouteReferenceImages() async throws {
  let response = try JSONEncoder().encode(RemoteRouteReadResponse(scene: mediaScene()))
  let wrongPurposeLoader = CountingMediaLoader(data: Data("abc".utf8))
  let wrongPurpose = mediaAsset(
    id: "review-photo",
    fileIdentifier: "review-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    purpose: .personalMovementReview
  )
  let wrongPurposeProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: wrongPurposeLoader,
    transport: MediaRequestTransport(responseBody: response)
  )
  do {
    _ = try await wrongPurposeProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [wrongPurpose])
    )
    throw RouteMediaReadSpecFailure.expected("movement-review media is not route-read input")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(
      error
        == .incompatiblePurpose(
          assetID: wrongPurpose.id,
          actual: .personalMovementReview
        ),
      "incompatible purpose should be explicit"
    )
  }
  let wrongPurposeLoadCount = await wrongPurposeLoader.loadCount()
  try mediaExpect(wrongPurposeLoadCount == 0, "wrong-purpose bytes must never be loaded")

  let wrongMIMELoader = CountingMediaLoader(data: Data("abc".utf8))
  let wrongMIME = mediaAsset(
    id: "video-route",
    fileIdentifier: "video-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    mimeType: "video/mp4"
  )
  let wrongMIMEProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: wrongMIMELoader,
    transport: MediaRequestTransport(responseBody: response)
  )
  do {
    _ = try await wrongMIMEProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [wrongMIME])
    )
    throw RouteMediaReadSpecFailure.expected("non-image media should not enter image route read")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(
      error == .unsupportedMIMEType(assetID: wrongMIME.id, mimeType: "video/mp4"),
      "non-image MIME should be explicit"
    )
  }
  let wrongMIMELoadCount = await wrongMIMELoader.loadCount()
  try mediaExpect(wrongMIMELoadCount == 0, "non-image bytes must never be loaded")
}

private func routeMediaRejectsSizeAndDigestMismatches() async throws {
  let response = try JSONEncoder().encode(RemoteRouteReadResponse(scene: mediaScene()))
  let sizeTransport = MediaRequestTransport(responseBody: response)
  let wrongSize = mediaAsset(
    id: "wrong-size",
    fileIdentifier: "wrong-size-file",
    byteCount: 4,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  let sizeProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: DictionaryMediaLoader(dataByFileIdentifier: ["wrong-size-file": Data("abc".utf8)]),
    transport: sizeTransport
  )
  do {
    _ = try await sizeProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [wrongSize])
    )
    throw RouteMediaReadSpecFailure.expected("byte-count mismatch should fail")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(
      error == .byteCountMismatch(assetID: wrongSize.id, declared: 4, actual: 3),
      "declared and loaded byte counts should be reported"
    )
  }
  let sizeRequest = await sizeTransport.request()
  try mediaExpect(sizeRequest == nil, "invalid-size media must not reach HTTP")

  let digestTransport = MediaRequestTransport(responseBody: response)
  let wrongDigest = mediaAsset(
    id: "wrong-digest",
    fileIdentifier: "wrong-digest-file",
    byteCount: 3,
    digest: String(repeating: "0", count: 64)
  )
  let digestProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: DictionaryMediaLoader(dataByFileIdentifier: ["wrong-digest-file": Data("abc".utf8)]
    ),
    transport: digestTransport
  )
  do {
    _ = try await digestProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [wrongDigest])
    )
    throw RouteMediaReadSpecFailure.expected("digest mismatch should fail")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(
      error
        == .contentDigestMismatch(
          assetID: wrongDigest.id,
          expected: String(repeating: "0", count: 64),
          actual: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        ),
      "expected and computed SHA-256 should be reported"
    )
  }
  let digestRequest = await digestTransport.request()
  try mediaExpect(digestRequest == nil, "invalid-digest media must not reach HTTP")
}

private func routeMediaEnforcesTotalByteLimitBeforeLoading() async throws {
  let response = try JSONEncoder().encode(RemoteRouteReadResponse(scene: mediaScene()))
  let loader = CountingMediaLoader(data: Data("abc".utf8))
  let first = mediaAsset(
    id: "limit-first",
    fileIdentifier: "limit-first-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  let second = mediaAsset(
    id: "limit-second",
    fileIdentifier: "limit-second-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  let transport = MediaRequestTransport(responseBody: response)
  let provider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: loader,
    transport: transport,
    maximumTotalByteCount: 5
  )

  do {
    _ = try await provider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [first, second])
    )
    throw RouteMediaReadSpecFailure.expected("oversized media request should fail")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(
      error == .totalByteLimitExceeded(limit: 5, observed: 6),
      "total size and configured limit should be reported"
    )
  }
  let loadCount = await loader.loadCount()
  let observedRequest = await transport.request()
  try mediaExpect(loadCount == 0, "oversized requests must fail before loading bytes")
  try mediaExpect(observedRequest == nil, "oversized requests must not reach HTTP")
}

private func routeMediaCancellationPropagatesWithoutTransport() async throws {
  let asset = mediaAsset(
    id: "cancel-photo",
    fileIdentifier: "cancel-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  let response = try JSONEncoder().encode(RemoteRouteReadResponse(scene: mediaScene()))
  let transport = MediaRequestTransport(responseBody: response)
  let provider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: SuspendingMediaLoader(),
    transport: transport
  )
  let task = Task {
    try await provider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [asset])
    )
  }
  await Task.yield()
  task.cancel()

  do {
    _ = try await task.value
    throw RouteMediaReadSpecFailure.expected("cancelled media load should not complete")
  } catch is CancellationError {
    // Public cancellation remains CancellationError, matching the existing HTTP adapter contract.
  }
  let observedRequest = await transport.request()
  try mediaExpect(observedRequest == nil, "cancelled media must not reach HTTP")
}

private func routeMediaRequestCannotSilentlyDropMedia() async throws {
  let response = try JSONEncoder().encode(RemoteRouteReadResponse(scene: mediaScene()))
  let transport = MediaRequestTransport(responseBody: response)
  let provider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: DictionaryMediaLoader(dataByFileIdentifier: [:]),
    transport: transport
  )
  do {
    _ = try await provider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [])
    )
    throw RouteMediaReadSpecFailure.expected("media route read should require media")
  } catch let error as RouteMediaReadContractError {
    try mediaExpect(error == .mediaRequired, "empty media should have an explicit contract error")
  }
  let observedRequest = await transport.request()
  try mediaExpect(observedRequest == nil, "empty media requests must not reach HTTP")
}

private func routeMediaReusesHTTPTimeoutAndStatusErrors() async throws {
  let bytes = Data("abc".utf8)
  let asset = mediaAsset(
    id: "http-photo",
    fileIdentifier: "http-file",
    byteCount: 3,
    digest: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  let loader = DictionaryMediaLoader(dataByFileIdentifier: ["http-file": bytes])
  let timeoutProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: loader,
    transport: TimedOutMediaTransport()
  )
  do {
    _ = try await timeoutProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [asset])
    )
    throw RouteMediaReadSpecFailure.expected("media HTTP timeout should fail")
  } catch let error as RemoteModelAdapterError {
    try mediaExpect(error == .timedOut, "media route read should reuse timedOut")
  }

  let statusProvider = try HTTPRouteMediaReadProvider(
    configuration: mediaEndpointConfiguration(),
    dataLoader: loader,
    transport: MediaRequestTransport(statusCode: 422, responseBody: Data())
  )
  do {
    _ = try await statusProvider.read(
      RouteMediaReadRequest(routeRead: mediaRouteReadRequest(), assets: [asset])
    )
    throw RouteMediaReadSpecFailure.expected("media HTTP status should fail")
  } catch let error as RemoteModelAdapterError {
    try mediaExpect(error == .httpStatus(code: 422), "media route read should reuse httpStatus")
  }
}

private func mediaExpectBody(_ request: URLRequest?) throws -> Data {
  try mediaExpect(request?.httpMethod == "POST", "expected POST")
  try mediaExpect(
    request?.value(forHTTPHeaderField: "Content-Type") == "application/json", "expected JSON")
  guard let body = request?.httpBody else {
    throw RouteMediaReadSpecFailure.expected("missing request body")
  }
  return body
}

func runRouteMediaReadSpecifications() async throws -> Int {
  try await routeMediaSuccessCarriesVerifiedBytesAndLineage()
  print("PASS: route media read carries verified bytes and source/derived lineage")
  try await routeMediaRequiresCurrentExplicitModelConsent()
  print("PASS: route media read requires current explicit model consent")
  try await routeMediaRequiresRouteReferenceImages()
  print("PASS: route media read accepts only route-reference images")
  try await routeMediaRejectsSizeAndDigestMismatches()
  print("PASS: route media read verifies byte count and SHA-256")
  try await routeMediaEnforcesTotalByteLimitBeforeLoading()
  print("PASS: route media read enforces total byte limit before loading")
  try await routeMediaCancellationPropagatesWithoutTransport()
  print("PASS: route media read cancellation propagates before transport")
  try await routeMediaRequestCannotSilentlyDropMedia()
  print("PASS: route media read requires at least one media asset")
  try await routeMediaReusesHTTPTimeoutAndStatusErrors()
  print("PASS: route media read reuses timeout and HTTP status errors")
  return 8
}
