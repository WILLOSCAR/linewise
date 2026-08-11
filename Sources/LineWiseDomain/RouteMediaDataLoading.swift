import Foundation

/// Resolves an app-controlled media reference without exposing storage paths to a model adapter.
///
/// Storage implementations own authorization, path containment, integrity, and lifecycle. Consumers
/// receive only the requested in-memory bytes.
public protocol RouteMediaDataLoader: Sendable {
  func loadData(for reference: LocalMediaReference) async throws -> Data
}

/// Joins one provider-neutral route-read draft with the authorized local assets used as evidence.
/// The request contains references and metadata only; a provider decides when to ask its injected
/// `RouteMediaDataLoader` for in-memory bytes.
public struct RouteMediaReadRequest: Equatable, Sendable {
  public let routeRead: RouteReadRequest
  public let assets: [RouteMediaAsset]

  public init(routeRead: RouteReadRequest, assets: [RouteMediaAsset]) {
    self.routeRead = routeRead
    self.assets = assets
  }
}

/// Provider-neutral media route reading seam. Apple UI can depend on this protocol without
/// depending on a concrete HTTP/model adapter.
public protocol RouteMediaReadProviding: Sendable {
  var identifier: String { get }
  func read(_ request: RouteMediaReadRequest) async throws -> RouteReadResult
}
