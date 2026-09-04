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
    (
      "a flush already in flight is not duplicated by later taps",
      overlappingFlushesDoNotResendTheSameEnvelopeOrReportFalseDegradation
    ),
    (
      "one undeliverable inbound payload does not block later events",
      oneUndeliverableInboundPayloadDoesNotBlockLaterEvents
    ),
  ]
}

@MainActor
private func oneUndeliverableInboundPayloadDoesNotBlockLaterEvents() async throws {
  let transport = SeedableRuntimeInboxTransport()
  let fixture = try durableRuntimeFixture(transport: transport, role: .iPhone)
  defer { try? FileManager.default.removeItem(at: fixture.root) }

  // A newer counterpart sends a command kind this build cannot decode. It
  // arrives ahead of a perfectly valid event.
  await transport.seed(
    DevicePayloadID("payload-undecodable"),
    payload: Data("{\"kind\":\"from-a-newer-build\"}".utf8)
  )
  let firstValid = inboundRouteEnvelope(action: "inbound-after-poison-1", sequence: 1)
  await transport.seed(DevicePayloadID("payload-valid-1"), envelope: firstValid)

  let firstPull = await fixture.runtime.pullReceivedEvents()
  try expect(
    firstPull.insertedCount == 1,
    "a valid inbound event must be delivered even when it queues behind an undecodable payload"
  )
  try expect(
    fixture.runtime.projection.routeCards.map(\.id) == [
      RouteCardID("route-inbound-after-poison-1")
    ],
    "the valid event must reach domain state, not sit behind the undecodable payload"
  )
  try expect(
    firstPull.error != nil,
    "an inbound payload this build cannot interpret must stay visible, never silent"
  )

  let remaining = try await transport.pendingReceivedPayloads()
  try expect(
    remaining.map(\.id) == [DevicePayloadID("payload-undecodable")],
    "only the delivered payload may be acknowledged; the rest must stay durable"
  )

  // A later, perfectly valid event must not queue behind the retained payload.
  let secondValid = inboundRouteEnvelope(action: "inbound-after-poison-2", sequence: 2)
  await transport.seed(DevicePayloadID("payload-valid-2"), envelope: secondValid)
  let secondPull = await fixture.runtime.pullReceivedEvents()
  try expect(
    secondPull.insertedCount == 1,
    "every later inbound event must keep flowing past a retained undecodable payload"
  )
  try expect(
    fixture.runtime.projection.routeCards.count == 2,
    "both synced RouteCards must be present after the second pull"
  )

  // The same isolation must hold when the bytes decode but the envelope
  // conflicts with one already accepted under the same ActionID.
  let forged = DeviceEventEnvelope(
    originDeviceID: DeviceID("watch-inbound-conflict"),
    sequence: 3,
    command: .createRouteCard(
      actionID: ActionID("inbound-after-poison-2"),
      routeCardID: RouteCardID("route-forged-conflict"),
      label: "Forged route",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 9_000),
      source: .watch
    )
  )
  await transport.seed(DevicePayloadID("payload-conflicting"), envelope: forged)
  let thirdValid = inboundRouteEnvelope(action: "inbound-after-poison-3", sequence: 4)
  await transport.seed(DevicePayloadID("payload-valid-3"), envelope: thirdValid)

  let thirdPull = await fixture.runtime.pullReceivedEvents()
  try expect(
    thirdPull.insertedCount == 1 && thirdPull.error != nil,
    "a conflicting envelope must be reported without discarding the valid batch members"
  )
  try expect(
    fixture.runtime.projection.routeCards.count == 3,
    "a conflicting envelope must not withhold the valid events that arrived with it"
  )
  try expect(
    !fixture.runtime.projection.routeCards.contains {
      $0.id == RouteCardID("route-forged-conflict")
    },
    "a conflicting envelope must never overwrite already-accepted history"
  )
  let stillPending = try await transport.pendingReceivedPayloads()
  try expect(
    Set(stillPending.map(\.id)) == [
      DevicePayloadID("payload-undecodable"), DevicePayloadID("payload-conflicting"),
    ],
    "an unresolved inbound payload must remain durable for review, not be silently dropped"
  )
}

private func requireSinglePendingPayloadID(
  _ transport: any DevicePayloadTransport
) async throws -> DevicePayloadID {
  let pending = try await transport.pendingReceivedPayloads()
  guard pending.count == 1, let only = pending.first else {
    throw AppleAdapterSpecFailure.expected("expected exactly one pending inbound payload")
  }
  return only.id
}

private func inboundRouteEnvelope(action: String, sequence: UInt64) -> DeviceEventEnvelope {
  DeviceEventEnvelope(
    originDeviceID: DeviceID("watch-inbound-isolation"),
    sequence: sequence,
    command: .createRouteCard(
      actionID: ActionID(action),
      routeCardID: RouteCardID("route-\(action)"),
      label: "Route \(sequence)",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: Int64(sequence) * 1_000),
      source: .watch
    )
  )
}

private actor SeedableRuntimeInboxTransport: DevicePayloadTransport {
  private var payloads: [ReceivedDevicePayload] = []

  func activate() async {}

  func send(_ payload: Data, mode: DeviceTransferMode) async throws -> DeviceTransferReceipt {
    DeviceTransferReceipt(disposition: .durablyCompleted, mode: mode)
  }

  func seed(_ id: DevicePayloadID, payload: Data) {
    payloads.append(ReceivedDevicePayload(id: id, payload: payload))
  }

  func seed(_ id: DevicePayloadID, envelope: DeviceEventEnvelope) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(envelope) else { return }
    payloads.append(ReceivedDevicePayload(id: id, payload: data))
  }

  func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] { payloads }

  func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {
    let acknowledged = Set(payloadIDs)
    payloads.removeAll { acknowledged.contains($0.id) }
  }
}

@MainActor
private func overlappingFlushesDoNotResendTheSameEnvelopeOrReportFalseDegradation() async throws {
  let transport = DeferredRuntimeTransport()
  let fixture = try durableRuntimeFixture(transport: transport)
  defer { try? FileManager.default.removeItem(at: fixture.root) }
  _ = fixture.runtime.handle(
    .startVisit(
      actionID: ActionID("start-overlapping-flush"),
      visitID: GymVisitID("visit-overlapping-flush"),
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    )
  )
  try expect(fixture.runtime.pendingOutboundCount == 1, "expected one durable pending event")

  // The first flush parks waiting for the transport completion callback, which
  // is exactly what an unreachable peer does for minutes.
  let firstFlush = Task { @MainActor [runtime = fixture.runtime] in
    await runtime.flushPendingEvents()
  }
  let started = try await waitForRuntimeTransfers(transport, count: 1)

  // Every user intent and every poll tick starts another flush while that one
  // is still suspended.
  var laterFlushes: [Task<DeviceSyncBatchResult, Never>] = []
  for _ in 0..<4 {
    laterFlushes.append(
      Task { @MainActor [runtime = fixture.runtime] in
        await runtime.flushPendingEvents()
      }
    )
  }
  for _ in 0..<2_000 {
    if await transport.startedTransfers.count > 1 { break }
    await Task.yield()
  }
  let transfersWhileStuck = await transport.startedTransfers
  try expect(
    transfersWhileStuck.count == 1,
    "a flush already in flight must not re-send the same unacknowledged envelope"
  )

  await transport.complete(.succeeded, transferID: started[0].id)
  let firstBatch = await firstFlush.value
  var laterBatches: [DeviceSyncBatchResult] = []
  for flush in laterFlushes {
    laterBatches.append(await flush.value)
  }
  try expect(
    laterBatches.allSatisfy { $0 == firstBatch },
    "an overlapping flush must report the in-flight delivery, never a separate attempt"
  )
  try expect(
    fixture.runtime.pendingOutboundCount == 0,
    "the confirmed transfer must acknowledge the Outbox exactly once"
  )
  try expect(
    fixture.runtime.syncStatus.phase == .synchronized
      && fixture.runtime.syncStatus.lastError == nil,
    "a fully drained Outbox must report synchronized, never a stale failure"
  )
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
  let seededPayloadID = try await requireSinglePendingPayloadID(transport)
  try expect(
    failedPull.insertedCount == 0
      && failedPull.error?.contains("inbound repository save failed") == true,
    "repository persistence failure must not be reported as a successful receive"
  )
  try expect(
    failedPull.error?.contains(seededPayloadID.rawValue) == true,
    "an undeliverable inbound payload must be identified so it can be reviewed"
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
  transport: any DevicePayloadTransport,
  role: LineWiseDeviceRole = .watch
) throws -> (runtime: LineWiseAppleRuntime, root: URL) {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-durable-device-runtime-\(UUID().uuidString)",
    isDirectory: true
  )
  let persistent = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: root,
    role: role
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
