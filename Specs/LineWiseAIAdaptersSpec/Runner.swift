import Foundation
import LineWiseAIAdapters
import LineWiseDomain

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

enum AIAdapterSpecFailure: Error, CustomStringConvertible {
  case expected(String)

  var description: String {
    switch self {
    case .expected(let message): message
    }
  }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw AIAdapterSpecFailure.expected(message) }
}

private struct StubResponse: Sendable {
  let statusCode: Int
  let body: Data
}

private struct RequestCapture: Sendable {
  let method: String?
  let authorization: String?
  let contentType: String?
  let body: Data?
}

private final class LockedCapture: @unchecked Sendable {
  private let lock = NSLock()
  private var value: RequestCapture?

  func set(_ value: RequestCapture) {
    lock.lock()
    defer { lock.unlock() }
    self.value = value
  }

  func get() -> RequestCapture? {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> StubResponse)?
  nonisolated(unsafe) static var capture: LockedCapture?

  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.capture?.set(
      RequestCapture(
        method: request.httpMethod,
        authorization: request.value(forHTTPHeaderField: "Authorization"),
        contentType: request.value(forHTTPHeaderField: "Content-Type"),
        body: requestBody()
      ))
    do {
      guard let handler = Self.handler else {
        throw URLError(.unsupportedURL)
      }
      let response = try handler(request)
      guard
        let url = request.url,
        let httpResponse = HTTPURLResponse(
          url: url,
          statusCode: response.statusCode,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "application/json"]
        )
      else {
        throw URLError(.badServerResponse)
      }
      client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: response.body)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}

  private func requestBody() -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
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
}

private struct TimeoutTransport: RemoteModelHTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    throw URLError(.timedOut)
  }
}

private struct SleepingTransport: RemoteModelHTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await Task.sleep(nanoseconds: 30_000_000_000)
    throw URLError(.unknown)
  }
}

private func sessionTransport() -> URLSessionRemoteModelHTTPTransport {
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [StubURLProtocol.self]
  return URLSessionRemoteModelHTTPTransport(session: URLSession(configuration: configuration))
}

private func endpointConfiguration(
  path: String,
  token: BearerTokenSource = .none
) throws -> RemoteModelEndpointConfiguration {
  try RemoteModelEndpointConfiguration(
    endpoint: URL(string: "https://model.invalid/\(path)")!,
    providerIdentifier: "replaceable-model",
    providerVersion: "2026-08",
    requestTimeout: 0.25,
    bearerToken: token
  )
}

private func scene() -> RouteScene {
  RouteScene(
    id: RouteSceneID("scene-ai"),
    name: "AI route",
    size: SceneSize(width: 10, height: 20),
    metersPerSceneUnit: 0.1,
    holds: [
      Hold(id: HoldID("hold-1"), center: Point2D(x: 2, y: 4), radius: 0.3),
      Hold(id: HoldID("hold-2"), center: Point2D(x: 4, y: 8), radius: 0.3),
    ]
  )
}

private func keyframe(provenance: RehearsalProvenance = .manual) -> PoseKeyframe {
  PoseKeyframe(
    id: PoseKeyframeID("frame-ai"),
    label: "Generated frame",
    torsoPosition: Point2D(x: 3, y: 6),
    contacts: Limb.allCases.map(LimbContact.unknown),
    provenance: provenance
  )
}

private func routeReadSuccessUsesJSONAndForcesModelProvenance() async throws {
  let capture = LockedCapture()
  StubURLProtocol.capture = capture
  StubURLProtocol.handler = { _ in
    StubResponse(
      statusCode: 200,
      body: try JSONEncoder().encode(RemoteRouteReadResponse(scene: scene()))
    )
  }
  let configuration = try endpointConfiguration(
    path: "route-read",
    token: BearerTokenSource(value: "runtime-secret")
  )
  let provider = HTTPRouteReadProvider(
    configuration: configuration,
    transport: sessionTransport()
  )
  let request = RouteReadRequest(
    sceneID: RouteSceneID("scene-ai"),
    name: "AI route",
    size: SceneSize(width: 10, height: 20),
    metersPerSceneUnit: 0.1,
    candidateHolds: []
  )

  let result = try await provider.read(request)
  let observed = capture.get()
  try expect(observed?.method == "POST", "expected POST")
  try expect(observed?.authorization == "Bearer runtime-secret", "expected runtime bearer")
  try expect(observed?.contentType == "application/json", "expected JSON request")
  let decodedRequest = try JSONDecoder().decode(RouteReadRequest.self, from: observed!.body!)
  try expect(decodedRequest == request, "expected lossless Codable request")
  try expect(result.scene == scene(), "expected decoded scene")
  try expect(result.provenance.authorship == .suggested, "expected suggested authorship")
  try expect(result.provenance.automation == .modelAdapter, "expected model adapter provenance")
  try expect(
    result.provenance.providerIdentifier == "replaceable-model"
      && result.provenance.version == "2026-08",
    "expected configured provider/version"
  )
}

private func suggestionForcesEveryFrameAndTopLevelProvenance() async throws {
  StubURLProtocol.capture = nil
  StubURLProtocol.handler = { _ in
    StubResponse(
      statusCode: 200,
      body: try JSONEncoder().encode(
        RemoteRehearsalSuggestionResponse(
          rehearsalID: RouteRehearsalID("rehearsal-ai"),
          keyframes: [keyframe(provenance: .manual)]
        ))
    )
  }
  let provider = HTTPRehearsalSuggestionProvider(
    configuration: try endpointConfiguration(path: "rehearsal"),
    transport: sessionTransport()
  )
  let request = RehearsalSuggestionRequest(
    rehearsalID: RouteRehearsalID("rehearsal-ai"),
    scene: scene(),
    bodyProfile: .generic(id: BodyProfileID("body-ai")),
    seedKeyframes: [],
    maximumKeyframeCount: 3
  )

  let result = try await provider.suggest(request)
  try expect(result.provenance.authorship == .suggested, "expected suggested result")
  try expect(result.provenance.automation == .modelAdapter, "expected model result")
  try expect(
    result.keyframes.allSatisfy {
      $0.provenance.authorship == .suggested
        && $0.provenance.automation == .modelAdapter
        && $0.provenance.providerIdentifier == "replaceable-model"
        && $0.provenance.version == "2026-08"
    },
    "expected every remote keyframe to be relabeled at the adapter boundary"
  )
}

private func statusAndMalformedResponsesAreExplicit() async throws {
  for statusCode in [401, 503] {
    StubURLProtocol.handler = { _ in StubResponse(statusCode: statusCode, body: Data()) }
    let provider = HTTPRouteReadProvider(
      configuration: try endpointConfiguration(path: "status-\(statusCode)"),
      transport: sessionTransport()
    )
    do {
      _ = try await provider.read(
        RouteReadRequest(
          sceneID: RouteSceneID("scene-ai"),
          name: "AI route",
          size: SceneSize(width: 10, height: 20),
          metersPerSceneUnit: nil,
          candidateHolds: []
        ))
      throw AIAdapterSpecFailure.expected("expected HTTP \(statusCode) failure")
    } catch let error as RemoteModelAdapterError {
      try expect(error == .httpStatus(code: statusCode), "expected explicit status error")
    }
  }

  StubURLProtocol.handler = { _ in StubResponse(statusCode: 200, body: Data("not-json".utf8)) }
  let provider = HTTPRouteReadProvider(
    configuration: try endpointConfiguration(path: "malformed"),
    transport: sessionTransport()
  )
  do {
    _ = try await provider.read(
      RouteReadRequest(
        sceneID: RouteSceneID("scene-ai"),
        name: "AI route",
        size: SceneSize(width: 10, height: 20),
        metersPerSceneUnit: nil,
        candidateHolds: []
      ))
    throw AIAdapterSpecFailure.expected("expected decoding failure")
  } catch let error as RemoteModelAdapterError {
    try expect(error == .responseDecodingFailed, "expected explicit decoding error")
  }
}

private func timeoutAndCancellationRemainDistinguishable() async throws {
  let timeoutProvider = HTTPRouteReadProvider(
    configuration: try endpointConfiguration(path: "timeout"),
    transport: TimeoutTransport()
  )
  let request = RouteReadRequest(
    sceneID: RouteSceneID("scene-ai"),
    name: "AI route",
    size: SceneSize(width: 10, height: 20),
    metersPerSceneUnit: nil,
    candidateHolds: []
  )
  do {
    _ = try await timeoutProvider.read(request)
    throw AIAdapterSpecFailure.expected("expected timeout")
  } catch let error as RemoteModelAdapterError {
    try expect(error == .timedOut, "expected explicit timeout error")
  }

  let cancellationProvider = HTTPRouteReadProvider(
    configuration: try endpointConfiguration(path: "cancel"),
    transport: SleepingTransport()
  )
  let task = Task { try await cancellationProvider.read(request) }
  await Task.yield()
  task.cancel()
  do {
    _ = try await task.value
    throw AIAdapterSpecFailure.expected("expected cancellation")
  } catch is CancellationError {
    // Expected: cancellation is not hidden inside an adapter error.
  }
}

@main
struct LineWiseAIAdaptersSpecRunner {
  static func main() async throws {
    var specifications: [(String, () async throws -> Void)] = [
      (
        "route read uses JSON and forces honest model provenance",
        routeReadSuccessUsesJSONAndForcesModelProvenance
      ),
      (
        "rehearsal suggestion cannot claim user authorship",
        suggestionForcesEveryFrameAndTopLevelProvenance
      ),
      (
        "HTTP status and malformed JSON failures are explicit",
        statusAndMalformedResponsesAreExplicit
      ),
      (
        "timeout is explicit and cancellation propagates",
        timeoutAndCancellationRemainDistinguishable
      ),
    ]
    specifications += routeMediaReadSpecifications()
    specifications += qualitativeRouteAnalysisAdapterSpecifications()
    specifications += routeSceneContractSpecifications()

    let passed = try await runSpecifications(specifications)
    print("LineWiseAIAdaptersSpec: \(passed) passed")
  }
}
