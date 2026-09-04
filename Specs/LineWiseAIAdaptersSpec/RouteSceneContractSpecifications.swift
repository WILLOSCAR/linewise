import Foundation
import LineWiseAIAdapters
import LineWiseDomain

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// A remote model is untrusted input. Whatever numbers it returns, the RouteScene
// the adapter hands to the rest of the app must satisfy the same invariants a
// locally constructed scene does: a scene scale is either a positive number of
// metres per scene unit or genuinely unknown, and a hold radius is never
// negative. An unknown scale is what makes the qualitative solver report
// `scaleUncertainty` and phrase reach as an estimate, so a scene that claims a
// nonsense scale would silently upgrade an honest "scale unknown, reach
// unresolved" read into a confident, finding-free one.

private enum RouteSceneContractSpecFailure: Error, CustomStringConvertible {
  case expected(String)

  var description: String {
    switch self {
    case .expected(let message): message
    }
  }
}

private func sceneExpect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw RouteSceneContractSpecFailure.expected(message) }
}

private struct FixedBodyRouteSceneTransport: RemoteModelHTTPTransport {
  let responseBody: Data

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )!
    return (responseBody, response)
  }
}

private struct FixedBytesMediaLoader: RouteMediaDataLoader {
  let bytes: Data

  func loadData(for reference: LocalMediaReference) async throws -> Data {
    bytes
  }
}

private let sceneContractSceneID = RouteSceneID("scene-contract")

private func sceneContractEndpoint() throws -> RemoteModelEndpointConfiguration {
  try RemoteModelEndpointConfiguration(
    endpoint: URL(string: "https://model.invalid/route-scene-contract")!,
    providerIdentifier: "scene-contract-model",
    providerVersion: "contract-1",
    requestTimeout: 0.25
  )
}

private func sceneContractRouteReadRequest() -> RouteReadRequest {
  RouteReadRequest(
    sceneID: sceneContractSceneID,
    name: "Contract route",
    size: SceneSize(width: 10, height: 20),
    metersPerSceneUnit: nil,
    candidateHolds: []
  )
}

/// A response body a remote model can legally emit but a local `RouteScene`
/// could never hold: a non-positive scale and a negative hold radius.
private func sceneContractResponseBody(metersPerSceneUnit: String) -> Data {
  Data(
    """
    {
      "scene": {
        "id": "\(sceneContractSceneID.rawValue)",
        "name": "Contract route",
        "size": { "width": 10, "height": 20 },
        "metersPerSceneUnit": \(metersPerSceneUnit),
        "holds": [
          {
            "id": "hold-contract",
            "center": { "x": 9, "y": 19 },
            "radius": -3,
            "kind": "hold",
            "routeRole": "route"
          }
        ]
      }
    }
    """.utf8
  )
}

private func sceneContractMediaAsset() -> RouteMediaAsset {
  RouteMediaAsset(
    id: RouteMediaAssetID("scene-contract-photo"),
    routeCardID: RouteCardID("scene-contract-route"),
    localReference: LocalMediaReference(
      fileIdentifier: "scene-contract-file",
      sandboxRelativePath: "private/scene-contract-file"
    ),
    kind: .routePhoto,
    mimeType: "image/png",
    byteCount: 3,
    dimensions: MediaDimensions(pixelWidth: 1_200, pixelHeight: 1_800),
    contentDigest: MediaContentDigest(
      algorithm: .sha256,
      hexValue: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    ),
    purpose: .routeReference,
    consent: MediaConsent(
      status: .granted,
      scope: .explicitModelProcessing,
      recordedAt: Instant(millisecondsSince1970: 1_800)
    ),
    captureProvenance: MediaCaptureProvenance(
      capturedAt: Instant(millisecondsSince1970: 1_700),
      deviceClass: .phone,
      method: .cameraCapture,
      importedByUser: true
    ),
    origin: .source,
    quality: .usable,
    retention: .keepUntilUserDeletes
  )
}

private func expectHonestScene(_ scene: RouteScene, _ label: String) throws {
  try sceneExpect(
    scene.metersPerSceneUnit == nil,
    "\(label) must report a non-positive scale as unknown, not store it"
  )
  try sceneExpect(
    scene.holds.allSatisfy { $0.radius >= 0 },
    "\(label) must not carry a negative hold radius"
  )

  // The doctrine consequence: an unknown scale keeps the solver honest.
  let solution = Qualitative2DSolver().solve(
    scene: scene,
    bodyProfile: .generic(id: BodyProfileID("scene-contract-body")),
    torsoPosition: Point2D(x: 5, y: 10),
    contacts: scene.holds.map { LimbContact(limb: .leftHand, target: .hold($0.id), mode: .hand) }
  )
  try sceneExpect(
    solution.findings.contains { $0.kind == .scaleUncertainty },
    "\(label) with an unknown scale must still report scale uncertainty"
  )
  try sceneExpect(
    solution.confidence != .high,
    "\(label) with an unknown scale must not be reported as high confidence"
  )
}

private func routeReadSanitizesModelSuppliedSceneNumbers() async throws {
  for scale in ["-4", "0", "1e-300"] {
    let provider = HTTPRouteReadProvider(
      configuration: try sceneContractEndpoint(),
      transport: FixedBodyRouteSceneTransport(
        responseBody: sceneContractResponseBody(metersPerSceneUnit: scale)
      )
    )

    let result = try await provider.read(sceneContractRouteReadRequest())

    try expectHonestScene(result.scene, "a route read claiming scale \(scale)")
  }
}

private func routeMediaReadSanitizesModelSuppliedSceneNumbers() async throws {
  let provider = try HTTPRouteMediaReadProvider(
    configuration: try sceneContractEndpoint(),
    dataLoader: FixedBytesMediaLoader(bytes: Data("abc".utf8)),
    transport: FixedBodyRouteSceneTransport(
      responseBody: sceneContractResponseBody(metersPerSceneUnit: "-4")
    )
  )

  let result = try await provider.read(
    RouteMediaReadRequest(
      routeRead: sceneContractRouteReadRequest(),
      assets: [sceneContractMediaAsset()]
    )
  )

  try expectHonestScene(result.scene, "a media route read claiming a negative scale")
}

func routeSceneContractSpecifications() -> [(String, () async throws -> Void)] {
  [
    (
      "route read cannot import a non-positive scale or negative hold radius",
      routeReadSanitizesModelSuppliedSceneNumbers
    ),
    (
      "media route read cannot import a non-positive scale or negative hold radius",
      routeMediaReadSanitizesModelSuppliedSceneNumbers
    ),
  ]
}
