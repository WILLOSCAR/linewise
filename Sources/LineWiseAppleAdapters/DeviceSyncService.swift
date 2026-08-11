import LineWiseDomain

public enum DeviceSyncDeliveryOutcome: Equatable, Sendable {
  case acceptedForDelivery(DeviceTransferMode)
  case notAcceptedLocally
  case failed(String)
}

public struct DeviceSyncDelivery: Equatable, Sendable {
  public let eventID: ActionID
  public let outcome: DeviceSyncDeliveryOutcome

  public init(eventID: ActionID, outcome: DeviceSyncDeliveryOutcome) {
    self.eventID = eventID
    self.outcome = outcome
  }

  public var wasAcceptedLocally: Bool {
    if case .acceptedForDelivery = outcome { return true }
    return false
  }
}

public struct DeviceSyncBatchResult: Equatable, Sendable {
  public let deliveries: [DeviceSyncDelivery]

  public init(deliveries: [DeviceSyncDelivery]) {
    self.deliveries = deliveries
  }

  public var acknowledgementCandidates: [ActionID] {
    deliveries.compactMap { delivery in
      delivery.wasAcceptedLocally ? delivery.eventID : nil
    }
  }
}

/// Moves already-durable domain envelopes across an optional device transport.
///
/// This service never owns the Outbox. Its acknowledgement candidates are only
/// a signal that the transport accepted a payload locally; the caller remains
/// responsible for atomically acknowledging the matching durable event.
public struct LineWiseDeviceSyncService: Sendable {
  private let bridge: DeviceEnvelopeBridge

  public init(bridge: DeviceEnvelopeBridge) {
    self.bridge = bridge
  }

  public func activate() async {
    await bridge.activate()
  }

  public func flush(
    _ envelopes: [DeviceEventEnvelope],
    mode: DeviceTransferMode = .reliableBackground
  ) async -> DeviceSyncBatchResult {
    var deliveries: [DeviceSyncDelivery] = []
    deliveries.reserveCapacity(envelopes.count)

    for envelope in envelopes {
      do {
        let receipt = try await bridge.send(envelope, mode: mode)
        deliveries.append(
          DeviceSyncDelivery(
            eventID: envelope.eventID,
            outcome: receipt.acceptedLocally
              ? .acceptedForDelivery(receipt.mode)
              : .notAcceptedLocally
          ))
      } catch {
        deliveries.append(
          DeviceSyncDelivery(
            eventID: envelope.eventID,
            outcome: .failed(String(describing: error))
          ))
      }
    }

    return DeviceSyncBatchResult(deliveries: deliveries)
  }

  public func pull() async throws -> [DeviceEventEnvelope] {
    try await bridge.receivedEnvelopes()
  }
}
