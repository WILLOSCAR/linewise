import Foundation
import LineWiseAppleAdapters
import LineWiseApplication
import LineWiseDomain

func durableDeviceTransportSpecifications() -> [(String, () async throws -> Void)] {
  [
    (
      "Outbox acknowledgement waits for the reliable completion callback",
      durableOutboxWaitsForCompletionCallbackAndRetriesTheSameAction
    ),
    (
      "inbound transport bytes wait for repository persistence",
      inboundTransportPayloadWaitsForRepositoryPersistence
    ),
  ]
}

@MainActor
private func durableOutboxWaitsForCompletionCallbackAndRetriesTheSameAction() async throws {
  let transport = DeferredRuntimeTransport()
  let fixture = try durableRuntimeFixture(transport: transport)
  defer { try? FileManager.default.removeItem(at: fixture.root) }
  _ = fixture.runtime.handle(
    .startVisit(
      actionID: ActionID("start-callback-durable"),
      visitID: GymVisitID("visit-callback-durable"),
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    )
  )

  let immediateFlush = Task { @MainActor [runtime = fixture.runtime] in
    await runtime.flushPendingEvents(mode: .immediateIfReachable)
  }
  let firstTransfers = try await waitForRuntimeTransfers(transport, count: 1)
  let firstTransfer = firstTransfers[0]
  try expect(
    fixture.runtime.pendingOutboundCount == 1,
    "the Outbox must remain durable while immediate fast+fallback awaits didFinish"
  )
  let reopenedWhileCallbackIsPending = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: fixture.root,
    role: .watch
  )
  try expect(
    reopenedWhileCallbackIsPending.coordinator.pendingOutboundEvents.map(\.eventID) == [
      ActionID("start-callback-durable")
    ],
    "a process restart before didFinish must reopen the same unacknowledged Outbox event"
  )
  await transport.complete(.failed("background callback failed"), transferID: firstTransfer.id)
  let failedBatch = await immediateFlush.value
  try expect(
    failedBatch.deliveries.map(\.outcome) == [.failed("background callback failed")],
    "a failed completion callback must remain an explicit delivery failure"
  )
  try expect(
    fixture.runtime.pendingOutboundCount == 1,
    "a callback failure must not acknowledge the durable Outbox"
  )

  let retryFlush = Task { @MainActor [runtime = fixture.runtime] in
    await runtime.flushPendingEvents(mode: .reliableBackground)
  }
  let transfers = try await waitForRuntimeTransfers(transport, count: 2)
  let retryTransfer = transfers[1]
  try expect(
    fixture.runtime.pendingOutboundCount == 1,
    "a restarted reliable transfer must also wait for didFinish"
  )
  await transport.complete(.succeeded, transferID: retryTransfer.id)
  _ = await retryFlush.value
  try expect(
    fixture.runtime.pendingOutboundCount == 0,
    "only a successful completion callback may acknowledge the Outbox"
  )

  let decoder = JSONDecoder()
  let retriedEnvelopes = try transfers.map {
    try decoder.decode(DeviceEventEnvelope.self, from: $0.payload)
  }
  try expect(
    retriedEnvelopes.map(\.eventID) == [
      ActionID("start-callback-durable"), ActionID("start-callback-durable"),
    ],
    "a retry must preserve the same ActionID so duplicate delivery stays safe"
  )
}

@MainActor
private func inboundTransportPayloadWaitsForRepositoryPersistence() async throws {
  let transport = InMemoryDevicePayloadTransport()
  let inboundEnvelope = DeviceEventEnvelope(
    originDeviceID: DeviceID("watch-inbound-persistence"),
    sequence: 1,
    command: .startVisit(
      actionID: ActionID("inbound-persistence-action"),
      visitID: GymVisitID("inbound-persistence-visit"),
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    )
  )
  _ = try await DeviceEnvelopeBridge(transport: transport).send(inboundEnvelope)

  let store = ToggleReceiveVisitEventStore()
  let deviceID = DeviceID("iphone-inbound-persistence")
  let repository = try VisitRepository(store: store, localDeviceID: deviceID)
  let runtime = LineWiseAppleRuntime(
    persistentRuntime: LineWiseAppRuntime(
      deviceID: deviceID,
      coordinator: LineWiseAppCoordinator(repository: repository)
    ),
    syncService: LineWiseDeviceSyncService(
      bridge: DeviceEnvelopeBridge(transport: transport)
    ),
    workoutRecorder: NoHealthKitWorkoutRecorder()
  )

  let failedPull = await runtime.pullReceivedEvents()
  try expect(
    failedPull.insertedCount == 0 && failedPull.error == "inbound repository save failed",
    "repository persistence failure must not be reported as a successful receive"
  )
  try expect(
    runtime.projection.visits.isEmpty,
    "failed repository persistence must not mutate the projected Visit"
  )
  let stillPending = try await transport.pendingReceivedPayloads()
  try expect(
    stillPending.count == 1,
    "a transport inbox payload must remain pending when repository persistence fails"
  )

  store.shouldFailSave = false
  let recoveredPull = await runtime.pullReceivedEvents()
  try expect(
    recoveredPull.insertedCount == 1 && recoveredPull.error == nil,
    "the retained inbound payload should succeed after repository recovery"
  )
  let consumed = try await transport.pendingReceivedPayloads()
  try expect(
    consumed.isEmpty,
    "repository success must be followed by durable transport-inbox acknowledgement"
  )
}

@MainActor
private func durableRuntimeFixture(
  transport: any DevicePayloadTransport
) throws -> (runtime: LineWiseAppleRuntime, root: URL) {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-durable-device-runtime-\(UUID().uuidString)",
    isDirectory: true
  )
  let persistent = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: root,
    role: .watch
  )
  return (
    LineWiseAppleRuntime(
      persistentRuntime: persistent,
      syncService: LineWiseDeviceSyncService(
        bridge: DeviceEnvelopeBridge(transport: transport)
      ),
      workoutRecorder: NoHealthKitWorkoutRecorder()
    ),
    root
  )
}

private struct RuntimeStartedTransfer: Sendable {
  let id: Int
  let payload: Data
}

private actor DeferredRuntimeTransport: DevicePayloadTransport {
  private let completions = DeviceTransferCompletionRegistry<Int>()
  private var nextTransferID = 0
  private var transfers: [RuntimeStartedTransfer] = []

  func activate() async {}

  func send(
    _ payload: Data,
    mode: DeviceTransferMode
  ) async throws -> DeviceTransferReceipt {
    nextTransferID += 1
    let transferID = nextTransferID
    await completions.prepare(transferID)
    transfers.append(RuntimeStartedTransfer(id: transferID, payload: payload))
    switch await completions.wait(for: transferID) {
    case .succeeded:
      return DeviceTransferReceipt(disposition: .durablyCompleted, mode: mode)
    case .failed(let reason):
      throw DeferredRuntimeTransportError.failed(reason)
    }
  }

  func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] { [] }

  func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {}

  var startedTransfers: [RuntimeStartedTransfer] { transfers }

  func complete(_ completion: DeviceTransferCompletion, transferID: Int) async {
    await completions.complete(completion, for: transferID)
  }
}

private enum DeferredRuntimeTransportError: Error, CustomStringConvertible {
  case failed(String)

  var description: String {
    switch self {
    case .failed(let reason): reason
    }
  }
}

private func waitForRuntimeTransfers(
  _ transport: DeferredRuntimeTransport,
  count: Int
) async throws -> [RuntimeStartedTransfer] {
  for _ in 0..<10_000 {
    let transfers = await transport.startedTransfers
    if transfers.count == count { return transfers }
    await Task.yield()
  }
  throw AppleAdapterSpecFailure.expected("timed out waiting for runtime transfer callback")
}

private final class ToggleReceiveVisitEventStore: VisitEventStore {
  enum Failure: Error, CustomStringConvertible {
    case save

    var description: String { "inbound repository save failed" }
  }

  var shouldFailSave = true
  private var journal = VisitEventJournal()

  func load() throws -> VisitEventJournal { journal }

  func save(_ journal: VisitEventJournal) throws {
    if shouldFailSave { throw Failure.save }
    self.journal = journal
  }

  func delete() throws {
    journal = VisitEventJournal()
  }
}
