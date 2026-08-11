import CryptoKit
import Foundation
import LineWiseDomain

/// Loads one app-controlled media reference into memory. Storage ownership and file-system access
/// stay with the caller; this adapter never persists the returned bytes.
public protocol RouteMediaDataLoader: Sendable {
  func loadData(for reference: LocalMediaReference) async throws -> Data
}

/// A route-read request whose media remains represented by local dataset metadata until `read`.
public struct RouteMediaReadRequest: Equatable, Sendable {
  public let routeRead: RouteReadRequest
  public let assets: [RouteMediaAsset]

  public init(routeRead: RouteReadRequest, assets: [RouteMediaAsset]) {
    self.routeRead = routeRead
    self.assets = assets
  }
}

public enum RouteMediaReadContractError: Error, Equatable, Sendable {
  case invalidTotalByteLimit
  case mediaRequired
  case consentNotGranted(assetID: RouteMediaAssetID, status: MediaConsentStatus)
  case consentScopeMismatch(assetID: RouteMediaAssetID, actual: MediaConsentScope)
  case incompatiblePurpose(assetID: RouteMediaAssetID, actual: MediaPurpose)
  case unsupportedMIMEType(assetID: RouteMediaAssetID, mimeType: String)
  case byteCountMismatch(assetID: RouteMediaAssetID, declared: Int64, actual: Int64)
  case contentDigestMismatch(assetID: RouteMediaAssetID, expected: String, actual: String)
  case totalByteLimitExceeded(limit: Int64, observed: Int64)
}

extension RouteMediaReadContractError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidTotalByteLimit:
      "The route-media byte limit must be greater than zero."
    case .mediaRequired:
      "A route-media read requires at least one image."
    case .consentNotGranted(let assetID, let status):
      "Media \(assetID.rawValue) is not authorized for model processing (\(status.rawValue))."
    case .consentScopeMismatch(let assetID, let actual):
      "Media \(assetID.rawValue) has consent scope \(actual.rawValue), not explicit model processing."
    case .incompatiblePurpose(let assetID, let actual):
      "Media \(assetID.rawValue) has purpose \(actual.rawValue), not route reference."
    case .unsupportedMIMEType(let assetID, let mimeType):
      "Media \(assetID.rawValue) has unsupported MIME type \(mimeType)."
    case .byteCountMismatch(let assetID, let declared, let actual):
      "Media \(assetID.rawValue) declares \(declared) bytes but loaded \(actual)."
    case .contentDigestMismatch(let assetID, _, _):
      "Media \(assetID.rawValue) does not match its declared SHA-256 digest."
    case .totalByteLimitExceeded(let limit, let observed):
      "Route media totals \(observed) bytes, exceeding the \(limit)-byte limit."
    }
  }
}

/// Sends explicitly authorized route imagery to a replaceable remote model endpoint.
public struct HTTPRouteMediaReadProvider: Sendable {
  public var identifier: String { configuration.providerIdentifier }

  private let configuration: RemoteModelEndpointConfiguration
  private let dataLoader: any RouteMediaDataLoader
  private let transport: any RemoteModelHTTPTransport
  private let maximumTotalByteCount: Int64

  public init(
    configuration: RemoteModelEndpointConfiguration,
    dataLoader: any RouteMediaDataLoader,
    transport: any RemoteModelHTTPTransport = URLSessionRemoteModelHTTPTransport(),
    maximumTotalByteCount: Int64 = 20 * 1_024 * 1_024
  ) throws {
    guard maximumTotalByteCount > 0 else {
      throw RouteMediaReadContractError.invalidTotalByteLimit
    }
    self.configuration = configuration
    self.dataLoader = dataLoader
    self.transport = transport
    self.maximumTotalByteCount = maximumTotalByteCount
  }

  public func read(_ request: RouteMediaReadRequest) async throws -> RouteReadResult {
    try Task.checkCancellation()
    guard !request.assets.isEmpty else {
      throw RouteMediaReadContractError.mediaRequired
    }
    for asset in request.assets {
      guard asset.consent.status == .granted else {
        throw RouteMediaReadContractError.consentNotGranted(
          assetID: asset.id,
          status: asset.consent.status
        )
      }
      guard asset.consent.scope == .explicitModelProcessing else {
        throw RouteMediaReadContractError.consentScopeMismatch(
          assetID: asset.id,
          actual: asset.consent.scope
        )
      }
      guard asset.purpose == .routeReference else {
        throw RouteMediaReadContractError.incompatiblePurpose(
          assetID: asset.id,
          actual: asset.purpose
        )
      }
      let mimeType = asset.mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard mimeType.hasPrefix("image/"), mimeType.count > "image/".count else {
        throw RouteMediaReadContractError.unsupportedMIMEType(
          assetID: asset.id,
          mimeType: asset.mimeType
        )
      }
    }

    var declaredTotal: Int64 = 0
    for asset in request.assets {
      let (nextTotal, overflowed) = declaredTotal.addingReportingOverflow(asset.byteCount)
      guard !overflowed, nextTotal <= maximumTotalByteCount else {
        throw RouteMediaReadContractError.totalByteLimitExceeded(
          limit: maximumTotalByteCount,
          observed: overflowed ? Int64.max : nextTotal
        )
      }
      declaredTotal = nextTotal
    }

    var media: [RemoteRouteMediaPayload] = []
    media.reserveCapacity(request.assets.count)

    for asset in request.assets {
      let bytes: Data
      do {
        bytes = try await dataLoader.loadData(for: asset.localReference)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        if Task.isCancelled { throw CancellationError() }
        throw error
      }
      try Task.checkCancellation()
      let actualByteCount = Int64(bytes.count)
      guard asset.byteCount == actualByteCount else {
        throw RouteMediaReadContractError.byteCountMismatch(
          assetID: asset.id,
          declared: asset.byteCount,
          actual: actualByteCount
        )
      }
      let expectedDigest = asset.contentDigest.hexValue
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      let actualDigest = SHA256.hash(data: bytes)
        .map { String(format: "%02x", $0) }
        .joined()
      guard expectedDigest == actualDigest else {
        throw RouteMediaReadContractError.contentDigestMismatch(
          assetID: asset.id,
          expected: expectedDigest,
          actual: actualDigest
        )
      }
      media.append(RemoteRouteMediaPayload(asset: asset, bytes: bytes))
    }

    let response: RemoteRouteReadResponse = try await RemoteModelHTTPClient(
      configuration: configuration,
      transport: transport
    ).post(
      RemoteRouteMediaReadPayload(routeRead: request.routeRead, media: media),
      responseType: RemoteRouteReadResponse.self
    )

    guard response.scene.id == request.routeRead.sceneID else {
      throw RemoteModelAdapterError.responseContractViolation(
        reason: "scene id does not match the request"
      )
    }
    return RouteReadResult(
      scene: response.scene,
      provenance: RehearsalProvenance(
        authorship: .suggested,
        automation: .modelAdapter,
        providerIdentifier: configuration.providerIdentifier,
        version: configuration.providerVersion
      )
    )
  }
}

private struct RemoteRouteMediaReadPayload: Encodable {
  let routeRead: RouteReadRequest
  let media: [RemoteRouteMediaPayload]
}

private struct RemoteRouteMediaPayload: Encodable {
  let assetID: RouteMediaAssetID
  let routeCardID: RouteCardID
  let kind: RouteMediaKind
  let mimeType: String
  let byteCount: Int64
  let dimensions: MediaDimensions
  let contentDigest: MediaContentDigest
  let purpose: MediaPurpose
  let consent: MediaConsent
  let captureProvenance: MediaCaptureProvenance
  let lineage: RemoteRouteMediaLineage
  let contentBase64: String

  init(asset: RouteMediaAsset, bytes: Data) {
    assetID = asset.id
    routeCardID = asset.routeCardID
    kind = asset.kind
    mimeType = asset.mimeType
    byteCount = asset.byteCount
    dimensions = asset.dimensions
    contentDigest = asset.contentDigest
    purpose = asset.purpose
    consent = asset.consent
    captureProvenance = asset.captureProvenance
    lineage = RemoteRouteMediaLineage(origin: asset.origin)
    contentBase64 = bytes.base64EncodedString()
  }
}

private struct RemoteRouteMediaLineage: Encodable {
  let origin: String
  let sourceAssetIDs: [RouteMediaAssetID]
  let transform: MediaDerivation?

  init(origin: MediaAssetOrigin) {
    switch origin {
    case .source:
      self.origin = "source"
      sourceAssetIDs = []
      transform = nil
    case .derived(let sourceAssetIDs, let transform):
      self.origin = "derived"
      self.sourceAssetIDs = sourceAssetIDs
      self.transform = transform
    }
  }
}
