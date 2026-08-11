import Foundation
import LineWiseDomain

public struct RemoteRehearsalSuggestionResponse: Equatable, Codable, Sendable {
  public let rehearsalID: RouteRehearsalID
  public let keyframes: [PoseKeyframe]

  public init(rehearsalID: RouteRehearsalID, keyframes: [PoseKeyframe]) {
    self.rehearsalID = rehearsalID
    self.keyframes = keyframes
  }
}

public struct HTTPRehearsalSuggestionProvider: RehearsalSuggestionProvider {
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

  public func suggest(
    _ request: RehearsalSuggestionRequest
  ) async throws -> RehearsalSuggestion {
    let response: RemoteRehearsalSuggestionResponse = try await RemoteModelHTTPClient(
      configuration: configuration,
      transport: transport
    ).post(request, responseType: RemoteRehearsalSuggestionResponse.self)

    guard response.rehearsalID == request.rehearsalID else {
      throw RemoteModelAdapterError.responseContractViolation(
        reason: "rehearsal id does not match the request"
      )
    }
    guard response.keyframes.count <= request.maximumKeyframeCount else {
      throw RemoteModelAdapterError.responseContractViolation(
        reason: "keyframe count exceeds the requested maximum"
      )
    }

    let provenance = modelProvenance
    return RehearsalSuggestion(
      rehearsalID: response.rehearsalID,
      keyframes: response.keyframes.map { frame in
        PoseKeyframe(
          id: frame.id,
          label: frame.label,
          torsoPosition: frame.torsoPosition,
          contacts: frame.contacts,
          avatar: frame.avatar,
          confidence: frame.confidence,
          findings: frame.findings,
          validity: frame.validity,
          provenance: provenance
        )
      },
      provenance: provenance
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
