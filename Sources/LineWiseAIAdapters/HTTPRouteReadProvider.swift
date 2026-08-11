import Foundation
import LineWiseDomain

public struct RemoteRouteReadResponse: Equatable, Codable, Sendable {
  public let scene: RouteScene

  public init(scene: RouteScene) {
    self.scene = scene
  }
}

public struct HTTPRouteReadProvider: RouteReadProvider {
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

  public func read(_ request: RouteReadRequest) async throws -> RouteReadResult {
    let response: RemoteRouteReadResponse = try await RemoteModelHTTPClient(
      configuration: configuration,
      transport: transport
    ).post(request, responseType: RemoteRouteReadResponse.self)

    guard response.scene.id == request.sceneID else {
      throw RemoteModelAdapterError.responseContractViolation(
        reason: "scene id does not match the request"
      )
    }
    return RouteReadResult(
      scene: response.scene,
      provenance: modelProvenance
    )
  }

  private var modelProvenance: RehearsalProvenance {
    RehearsalProvenance(
      authorship: .suggested,
      automation: .modelAdapter,
      providerIdentifier: configuration.providerIdentifier,
      version: configuration.providerVersion
    )
  }
}
