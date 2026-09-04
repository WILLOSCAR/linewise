import Foundation
import LineWiseAppleAdapters
import LineWiseDomain

func deviceSyncServiceSpecifications() -> [(String, () async throws -> Void)] {
  [
    (
      "completion registry settles callbacks in order and concurrently",
      completionRegistryHandlesCallbackOrderingAndConcurrency
    ),
    (
      "callback-confirmed transfers complete independently",
      callbackConfirmedTransfersCompleteIndependently
    ),
    (
      "callback-confirmed transfers become acknowledgement candidates",
      acceptedTransfersBecomeAcknowledgementCandidates
    ),
    (
      "latest context cannot acknowledge durable events",
      latestContextCannotAcknowledgeDurableEvents
    ),
    (
      "rejected and failed transfers remain pending",
      rejectedAndFailedTransfersRemainPending
    ),
    (
      "durable inbox survives reopen until explicit acknowledgement",
      { try durableInboxSurvivesReopenUntilExplicitAcknowledgement() }
    ),
  ]
}

private func completionRegistryHandlesCallbackOrderingAndConcurrency() async throws {
  let registry = DeviceTransferCompletionRegistry<String>()

  await registry.prepare("callback-first")
  await registry.complete(.succeeded, for: "callback-first")
  await registry.complete(.failed("duplicate callback must be ignored"), for: "callback-first")
  let callbackFirst = await registry.wait(for: "callback-first")
  try expect(
    callbackFirst == .succeeded,
    "the first callback must win even when it arrives before wait"
  )

  await registry.prepare("first")
  await registry.prepare("second")
  async let first = registry.wait(for: "first")
  async let second = registry.wait(for: "second")
  await registry.complete(.failed("second failed"), for: "second")
  await registry.complete(.succeeded, for: "first")
  let concurrentResults = await (first, second)
  try expect(
    concurrentResults.0 == .succeeded && concurrentResults.1 == .failed("second failed"),
    "concurrent transfer IDs must settle independently"
  )
}

private func callbackConfirmedTransfersCompleteIndependently() async throws {
  let transport = CallbackConfirmedTransport()
  let reliablePayload = Data("reliable".utf8)
  let immediatePayload = Data("immediate".utf8)

  let reliableTask = Task {
    try await transport.send(reliablePayload, mode: .reliableBackground)
  }
  let immediateTask = Task {
    try await transport.send(immediatePayload, mode: .immediateIfReachable)
  }
  try await waitForStartedTransfers(transport, count: 2)

  let reliableID = try await transport.transferID(for: reliablePayload)
  let immediateID = try await transport.transferID(for: immediatePayload)
  await transport.complete(.succeeded, transferID: immediateID)
  await transport.complete(.succeeded, transferID: reliableID)

  let reliableReceipt = try await reliableTask.value
  let immediateReceipt = try await immediateTask.value
  try expect(
    reliableReceipt.disposition == .durablyCompleted
      && immediateReceipt.disposition == .durablyCompleted,
    "both durable modes must wait for their own completion callback"
  )
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
    "only callback-confirmed transfers should become acknowledgement candidates"
  )
  try expect(batch.deliveries.allSatisfy(\.wasDurablyConfirmed), "expected confirmed delivery")
  let received = try await service.pull()
  try expect(
    received.map(\.envelope) == envelopes,
    "expected lossless pull after accepted delivery"
  )
  try await service.acknowledgeReceived(received.map(\.payloadID))
  let afterAcknowledgement = try await service.pull()
  try expect(
    afterAcknowledgement.isEmpty,
    "transport inbox entries should remain pending until and only until explicit acknowledgement"
  )
}

private func durableInboxSurvivesReopenUntilExplicitAcknowledgement() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-device-inbox-spec-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: root) }
  let fileURL = root.appendingPathComponent("inbox.json", isDirectory: false)
  let entry = ReceivedDevicePayload(
    id: DevicePayloadID("payload-that-must-survive-restart"),
    payload: Data("durable inbound bytes".utf8)
  )

  let first = try DurableDevicePayloadInbox(
    store: FoundationFileDevicePayloadInboxStore(fileURL: fileURL)
  )
  let inserted = try first.receive(entry)
  try expect(inserted, "the first delegate delivery should enter the durable inbox")

  let reopened = try DurableDevicePayloadInbox(
    store: FoundationFileDevicePayloadInboxStore(fileURL: fileURL)
  )
  try expect(
    reopened.pendingPayloads == [entry],
    "an inbound payload must survive process restart before repository consumption"
  )
  try reopened.acknowledge([entry.id])

  let afterAcknowledgement = try DurableDevicePayloadInbox(
    store: FoundationFileDevicePayloadInboxStore(fileURL: fileURL)
  )
  try expect(
    afterAcknowledgement.pendingPayloads.isEmpty,
    "only an explicit post-persistence acknowledgement may consume the durable inbox entry"
  )
}

private func latestContextCannotAcknowledgeDurableEvents() async throws {
  let transport = CountingAcceptedTransport()
  let service = LineWiseDeviceSyncService(
    bridge: DeviceEnvelopeBridge(transport: transport)
  )
  let durableEnvelope = envelope(action: "sync-latest-context", sequence: 1)

  let batch = await service.flush([durableEnvelope], mode: .latestContext)

  try expect(
    batch.acknowledgementCandidates.isEmpty,
    "replaceable application context must never acknowledge a durable event"
  )
  try expect(
    batch.deliveries.map(\.outcome) == [
      .notEligibleForDurableAcknowledgement(.latestContextIsReplaceable)
    ],
    "latestContext must produce an explicit non-acknowledgement outcome"
  )
  let sendCount = await transport.sendCount
  try expect(
    sendCount == 0,
    "the durable sync service must not hand an Outbox event to latestContext"
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
      .notEligibleForDurableAcknowledgement(.transportDidNotConfirm),
      .failed("scripted transport failure"),
      .confirmedDurableDelivery(.reliableBackground),
    ],
    "expected an explicit result for every envelope"
  )
}

private actor CallbackConfirmedTransport: DevicePayloadTransport {
  private let completions = DeviceTransferCompletionRegistry<Int>()
  private var nextTransferID = 0
  private var transferIDsByPayload: [Data: Int] = [:]

  func activate() async {}

  func send(
    _ payload: Data,
    mode: DeviceTransferMode
  ) async throws -> DeviceTransferReceipt {
    nextTransferID += 1
    let transferID = nextTransferID
    await completions.prepare(transferID)
    transferIDsByPayload[payload] = transferID
    let completion = await completions.wait(for: transferID)
    switch completion {
    case .succeeded:
      return DeviceTransferReceipt(disposition: .durablyCompleted, mode: mode)
    case .failed(let reason):
      throw CallbackTransportError.failed(reason)
    }
  }

  func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] { [] }

  func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {}

  var startedTransferCount: Int {
    transferIDsByPayload.count
  }

  func transferID(for payload: Data) throws -> Int {
    guard let transferID = transferIDsByPayload[payload] else {
      throw AppleAdapterSpecFailure.expected("missing started transfer")
    }
    return transferID
  }

  func complete(_ completion: DeviceTransferCompletion, transferID: Int) async {
    await completions.complete(completion, for: transferID)
  }
}

private actor CountingAcceptedTransport: DevicePayloadTransport {
  private(set) var sendCount = 0

  func activate() async {}

  func send(
    _ payload: Data,
    mode: DeviceTransferMode
  ) async throws -> DeviceTransferReceipt {
    sendCount += 1
    return DeviceTransferReceipt(disposition: .durablyCompleted, mode: mode)
  }

  func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] { [] }

  func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {}
}

private enum CallbackTransportError: Error, CustomStringConvertible {
  case failed(String)

  var description: String {
    switch self {
    case .failed(let reason): reason
    }
  }
}

private func waitForStartedTransfers(
  _ transport: CallbackConfirmedTransport,
  count: Int
) async throws {
  for _ in 0..<10_000 {
    if await transport.startedTransferCount == count { return }
    await Task.yield()
  }
  throw AppleAdapterSpecFailure.expected("timed out waiting for callback-driven transfers")
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

  func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] { [] }

  func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {}
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
