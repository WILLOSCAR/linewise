import LineWiseDomain

public enum DeviceSyncDeliveryOutcome: Equatable, Sendable {
  case confirmedDurableDelivery(DeviceTransferMode)
  case notEligibleForDurableAcknowledgement(DeviceTransferNonAcknowledgementReason)
  case failed(String)
}

public struct DeviceSyncDelivery: Equatable, Sendable {
  public let eventID: ActionID
  public let outcome: DeviceSyncDeliveryOutcome

  public init(eventID: ActionID, outcome: DeviceSyncDeliveryOutcome) {
    self.eventID = eventID
    self.outcome = outcome
  }

  public var wasDurablyConfirmed: Bool {
    if case .confirmedDurableDelivery = outcome { return true }
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
      delivery.wasDurablyConfirmed ? delivery.eventID : nil
    }
  }
}

/// Moves already-durable domain envelopes across an optional device transport.
///
/// This service never owns the Outbox. An acknowledgement candidate means the
/// reliable transport produced its completion callback successfully; merely
/// entering a platform queue or updating replaceable context is insufficient.
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
    if mode == .latestContext {
      return DeviceSyncBatchResult(
        deliveries: envelopes.map {
          DeviceSyncDelivery(
            eventID: $0.eventID,
            outcome: .notEligibleForDurableAcknowledgement(.latestContextIsReplaceable)
          )
        }
      )
    }

    var deliveries: [DeviceSyncDelivery] = []
    deliveries.reserveCapacity(envelopes.count)

    for envelope in envelopes {
      do {
        let receipt = try await bridge.send(envelope, mode: mode)
        let outcome: DeviceSyncDeliveryOutcome =
          switch receipt.disposition {
          case .durablyCompleted:
            .confirmedDurableDelivery(receipt.mode)
          case .notEligibleForDurableAcknowledgement(let reason):
            .notEligibleForDurableAcknowledgement(reason)
          }
        deliveries.append(
          DeviceSyncDelivery(
            eventID: envelope.eventID,
            outcome: outcome
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

  public func pull() async throws -> DeviceInboundBatch {
    try await bridge.pendingReceivedEnvelopes()
  }

  public func acknowledgeReceived(_ payloadIDs: [DevicePayloadID]) async throws {
    try await bridge.acknowledgeReceivedPayloads(payloadIDs)
  }
}
