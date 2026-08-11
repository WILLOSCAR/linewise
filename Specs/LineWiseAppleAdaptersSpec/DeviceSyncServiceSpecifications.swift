import Foundation
import LineWiseAppleAdapters
import LineWiseDomain

func runDeviceSyncServiceSpecifications() async throws -> Int {
  try await acceptedTransfersBecomeAcknowledgementCandidates()
  try await rejectedAndFailedTransfersRemainPending()
  return 2
}

private func acceptedTransfersBecomeAcknowledgementCandidates() async throws {
  let transport = InMemoryDevicePayloadTransport()
  let service = LineWiseDeviceSyncService(
    bridge: DeviceEnvelopeBridge(transport: transport)
  )
  let envelopes = [
    envelope(action: "sync-accepted-1", sequence: 1),
    envelope(action: "sync-accepted-2", sequence: 2),
  ]

  let batch = await service.flush(envelopes)
  try expect(
    batch.acknowledgementCandidates == envelopes.map(\.eventID),
    "only locally accepted transfers should become acknowledgement candidates"
  )
  try expect(batch.deliveries.allSatisfy(\.wasAcceptedLocally), "expected accepted delivery")
  let received = try await service.pull()
  try expect(
    received == envelopes,
    "expected lossless pull after accepted delivery"
  )
}

private func rejectedAndFailedTransfersRemainPending() async throws {
  let service = LineWiseDeviceSyncService(
    bridge: DeviceEnvelopeBridge(transport: ScriptedTransport())
  )
  let envelopes = [
    envelope(action: "sync-rejected", sequence: 1),
    envelope(action: "sync-failed", sequence: 2),
    envelope(action: "sync-recovered", sequence: 3),
  ]

  let batch = await service.flush(envelopes)
  try expect(
    batch.acknowledgementCandidates == [envelopes[2].eventID],
    "rejected and failed events must remain pending while later events continue"
  )
  try expect(
    batch.deliveries.map(\.outcome) == [
      .notAcceptedLocally,
      .failed("scripted transport failure"),
      .acceptedForDelivery(.reliableBackground),
    ],
    "expected an explicit result for every envelope"
  )
}

private actor ScriptedTransport: DevicePayloadTransport {
  private var sendCount = 0

  func activate() async {}

  func send(
    _ payload: Data,
    mode: DeviceTransferMode
  ) async throws -> DeviceTransferReceipt {
    sendCount += 1
    switch sendCount {
    case 1:
      return DeviceTransferReceipt(acceptedLocally: false, mode: mode)
    case 2:
      throw ScriptedTransportError.failure
    default:
      return DeviceTransferReceipt(acceptedLocally: true, mode: mode)
    }
  }

  func receivedPayloads() async -> [Data] { [] }
}

private enum ScriptedTransportError: Error, CustomStringConvertible {
  case failure

  var description: String { "scripted transport failure" }
}

private func envelope(action: String, sequence: UInt64) -> DeviceEventEnvelope {
  DeviceEventEnvelope(
    originDeviceID: DeviceID("watch-sync-spec"),
    sequence: sequence,
    command: .startVisit(
      actionID: ActionID(action),
      visitID: GymVisitID("visit-\(action)"),
      occurredAt: Instant(millisecondsSince1970: Int64(sequence) * 1_000),
      source: .watch
    )
  )
}
