import Foundation
import LineWiseAppleAdapters
import LineWiseApplication
import LineWiseDomain

func runAppleRuntimeSpecifications() async throws -> Int {
  try await manualVisitStartDoesNotRequestHealthAuthorization()
  try await explicitHealthOptInRequestsAuthorizationAndStartsFutureVisit()
  try await workoutDenialDoesNotRollbackTheLocalVisit()
  try await workoutFailureDoesNotRollbackTheLocalVisit()
  try await acceptedTransfersAreAcknowledgedButRejectedTransfersRemainPending()
  try await pullingTheSamePayloadIsIdempotent()
  try await completedWorkoutExposesAnOptionalSummary()
  try await experienceBackedRuntimeReopensActiveRest()
  return 8
}

@MainActor
private func manualVisitStartDoesNotRequestHealthAuthorization() async throws {
  let recorder = ScriptedWorkoutRecorder(
    capability: .authorizationRequired,
    authorization: .ready
  )
  let fixture = try runtimeFixture(recorder: recorder)
  defer { try? FileManager.default.removeItem(at: fixture.root) }

  let feedback = fixture.runtime.handle(startVisitIntent("manual-only"))
  try expect(feedback.isSuccess, "manual Visit capture should still begin")
  await fixture.runtime.waitForOptionalCapabilityWork()
  let counts = await recorder.invocationCounts()
  try expect(
    counts.authorizationRequests == 0 && counts.starts == 0,
    "default Visit start must not request Health authorization or start a workout"
  )
  try expect(
    fixture.runtime.healthRecordingPreference == .manualOnly,
    "Health recording must be visibly off until the user opts in"
  )
  try expect(
    fixture.runtime.workoutStatus == .idle,
    "manual-only capture must keep the optional workout idle"
  )
}

@MainActor
private func explicitHealthOptInRequestsAuthorizationAndStartsFutureVisit() async throws {
  let recorder = ScriptedWorkoutRecorder(
    capability: .authorizationRequired,
    authorization: .ready
  )
  let fixture = try runtimeFixture(recorder: recorder)
  defer { try? FileManager.default.removeItem(at: fixture.root) }

  fixture.runtime.enableHealthRecording()
  await fixture.runtime.waitForOptionalCapabilityWork()
  var counts = await recorder.invocationCounts()
  try expect(
    counts.authorizationRequests == 1 && counts.starts == 0,
    "explicit Enable Health Recording must request access without inventing a Visit"
  )
  try expect(
    fixture.runtime.healthRecordingPreference == .enabled,
    "the runtime must retain the user's current-run opt-in"
  )

  let feedback = fixture.runtime.handle(startVisitIntent("health-enabled"))
  try expect(feedback.isSuccess, "optional Health recording must not replace manual capture")
  await fixture.runtime.waitForOptionalCapabilityWork()
  counts = await recorder.invocationCounts()
  try expect(
    counts.authorizationRequests == 1 && counts.starts == 1,
    "an authorized opt-in should best-effort start the later Visit workout"
  )
  try expect(fixture.runtime.workoutStatus == .recording, "expected optional workout recording")
}

@MainActor
private func experienceBackedRuntimeReopensActiveRest() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-watch-rest-runtime-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: root) }
  let experienceStore = MemoryExperienceArchiveStore()
  let firstPersistent = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: root,
    role: .watch
  )
  let firstExperience = try PersistentLineWiseExperienceCoordinator(
    store: experienceStore,
    appCoordinator: firstPersistent.coordinator
  )
  let first = LineWiseAppleRuntime(
    deviceID: firstPersistent.deviceID,
    experienceCoordinator: firstExperience,
    syncService: LineWiseDeviceSyncService(
      bridge: DeviceEnvelopeBridge(transport: InMemoryDevicePayloadTransport())
    ),
    workoutRecorder: NoHealthKitWorkoutRecorder()
  )
  _ = first.handle(startVisitIntent("rest-reopen"))
  let restID = RestIntervalID("rest-runtime-reopen")
  let started = first.handle(
    .startRest(
      actionID: ActionID("rest-runtime-start"),
      restID: restID,
      afterAttemptID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000)
    ))
  try expect(started.isSuccess, "expected Watch rest to persist through experience backend")

  let reopenedPersistent = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: root,
    role: .watch
  )
  let reopenedExperience = try PersistentLineWiseExperienceCoordinator(
    store: experienceStore,
    appCoordinator: reopenedPersistent.coordinator
  )
  let reopened = LineWiseAppleRuntime(
    deviceID: reopenedPersistent.deviceID,
    experienceCoordinator: reopenedExperience,
    syncService: LineWiseDeviceSyncService(
      bridge: DeviceEnvelopeBridge(transport: InMemoryDevicePayloadTransport())
    ),
    workoutRecorder: NoHealthKitWorkoutRecorder()
  )
  try expect(
    reopened.projection.activeRest?.id == restID,
    "expected active Rest to survive Watch process death"
  )
  let stopped = reopened.handle(
    .stopRest(
      actionID: ActionID("rest-runtime-stop"),
      restID: restID,
      occurredAt: Instant(millisecondsSince1970: 3_000)
    ))
  try expect(stopped.isSuccess, "expected reopened Rest to stop normally")
}

@MainActor
private func workoutDenialDoesNotRollbackTheLocalVisit() async throws {
  let recorder = ScriptedWorkoutRecorder(
    capability: .authorizationRequired,
    authorization: .denied
  )
  let fixture = try runtimeFixture(recorder: recorder)
  defer { try? FileManager.default.removeItem(at: fixture.root) }

  fixture.runtime.enableHealthRecording()
  await fixture.runtime.waitForOptionalCapabilityWork()
  let feedback = fixture.runtime.handle(startVisitIntent("denied"))
  try expect(feedback.isSuccess, "HealthKit authorization must not gate the local visit")
  try expect(
    fixture.runtime.projection.activeVisit?.id == GymVisitID("visit-denied"),
    "the local visit must exist before optional authorization completes"
  )

  await fixture.runtime.waitForOptionalCapabilityWork()
  let deniedCounts = await recorder.invocationCounts()
  try expect(
    fixture.runtime.workoutStatus == .degraded(.denied),
    "denied HealthKit must be visible as an optional degraded state"
  )
  try expect(
    deniedCounts.authorizationRequests == 1 && deniedCounts.starts == 0,
    "denial must not trigger a workout or a repeated authorization prompt"
  )
}

@MainActor
private func workoutFailureDoesNotRollbackTheLocalVisit() async throws {
  let fixture = try runtimeFixture(
    recorder: ScriptedWorkoutRecorder(
      capability: .ready,
      startError: ScriptedRuntimeError.workoutFailed
    )
  )
  defer { try? FileManager.default.removeItem(at: fixture.root) }

  fixture.runtime.enableHealthRecording()
  await fixture.runtime.waitForOptionalCapabilityWork()
  let feedback = fixture.runtime.handle(startVisitIntent("failed"))
  try expect(feedback.isSuccess, "a recorder failure must not reject a durable local visit")
  await fixture.runtime.waitForOptionalCapabilityWork()
  try expect(
    fixture.runtime.workoutStatus == .failed("workout failed"),
    "the recorder failure must remain inspectable"
  )
  try expect(
    fixture.runtime.projection.activeVisit?.id == GymVisitID("visit-failed"),
    "a recorder failure must not roll back the visit"
  )
}

@MainActor
private func acceptedTransfersAreAcknowledgedButRejectedTransfersRemainPending() async throws {
  let accepted = try runtimeFixture(
    recorder: NoHealthKitWorkoutRecorder(),
    transport: ScriptedRuntimeTransport(results: [.accepted])
  )
  defer { try? FileManager.default.removeItem(at: accepted.root) }
  _ = accepted.runtime.handle(startVisitIntent("accepted"))
  try expect(accepted.runtime.pendingOutboundCount == 1, "expected a durable pending event")
  await accepted.runtime.flushPendingEvents()
  try expect(
    accepted.runtime.pendingOutboundCount == 0,
    "transport-local acceptance should acknowledge the matching Outbox event"
  )

  let rejected = try runtimeFixture(
    recorder: NoHealthKitWorkoutRecorder(),
    transport: ScriptedRuntimeTransport(results: [.rejected])
  )
  defer { try? FileManager.default.removeItem(at: rejected.root) }
  _ = rejected.runtime.handle(startVisitIntent("rejected"))
  await rejected.runtime.flushPendingEvents()
  try expect(
    rejected.runtime.pendingOutboundCount == 1,
    "a transport rejection must leave the durable event pending"
  )
  try expect(
    rejected.runtime.syncStatus.phase == .pending,
    "the UI projection must expose pending sync work"
  )
}

@MainActor
private func pullingTheSamePayloadIsIdempotent() async throws {
  let transport = InMemoryDevicePayloadTransport()
  let source = try runtimeFixture(
    recorder: NoHealthKitWorkoutRecorder(),
    transport: transport,
    role: .watch
  )
  let destination = try runtimeFixture(
    recorder: NoHealthKitWorkoutRecorder(),
    transport: transport,
    role: .iPhone
  )
  defer {
    try? FileManager.default.removeItem(at: source.root)
    try? FileManager.default.removeItem(at: destination.root)
  }

  _ = source.runtime.handle(startVisitIntent("pull"))
  await source.runtime.flushPendingEvents()
  let first = await destination.runtime.pullReceivedEvents()
  let second = await destination.runtime.pullReceivedEvents()

  try expect(first.insertedCount == 1 && first.duplicateCount == 0, "first pull should insert")
  try expect(
    second.insertedCount == 0 && second.duplicateCount == 0,
    "a repository-persisted payload should be consumed from the transport inbox"
  )
  try expect(
    destination.runtime.projection.visits.count == 1,
    "repeated pulls must not duplicate domain state"
  )
}

@MainActor
private func completedWorkoutExposesAnOptionalSummary() async throws {
  let summary = HealthKitWorkoutSummary(
    durationSeconds: 900,
    averageHeartRateBPM: 132,
    maximumHeartRateBPM: 171,
    heartRateCoverage: nil,
    activeEnergyKilocalories: 126,
    workoutEffortScore: nil,
    workoutEffortSource: nil,
    sourceVersion: "spec-v1"
  )
  let fixture = try runtimeFixture(
    recorder: ScriptedWorkoutRecorder(
      capability: .ready,
      summary: summary
    )
  )
  defer { try? FileManager.default.removeItem(at: fixture.root) }

  fixture.runtime.enableHealthRecording()
  await fixture.runtime.waitForOptionalCapabilityWork()
  _ = fixture.runtime.handle(startVisitIntent("summary"))
  await fixture.runtime.waitForOptionalCapabilityWork()
  _ = fixture.runtime.handle(
    .endVisit(
      actionID: ActionID("end-summary"),
      occurredAt: Instant(millisecondsSince1970: 901_000),
      source: .watch
    )
  )
  await fixture.runtime.waitForOptionalCapabilityWork()

  try expect(
    fixture.runtime.latestHealthKitWorkoutSummary == summary,
    "a completed recorder may expose non-diagnostic optional context"
  )
  let unavailable = NoHealthKitWorkoutRecorder()
  let unavailableSummary = await unavailable.latestSummary()
  try expect(
    unavailableSummary == nil,
    "the explicit no-HealthKit path must never fabricate a summary"
  )
}

@MainActor
private func runtimeFixture(
  recorder: any WorkoutRecording,
  transport: any DevicePayloadTransport = InMemoryDevicePayloadTransport(),
  role: LineWiseDeviceRole = .watch
) throws -> (runtime: LineWiseAppleRuntime, root: URL) {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-apple-runtime-\(UUID().uuidString)",
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
      workoutRecorder: recorder
    ),
    root
  )
}

private func startVisitIntent(_ suffix: String) -> LineWiseAppIntent {
  .startVisit(
    actionID: ActionID("start-\(suffix)"),
    visitID: GymVisitID("visit-\(suffix)"),
    occurredAt: Instant(millisecondsSince1970: 1_000),
    source: .watch
  )
}

private enum ScriptedRuntimeTransportResult: Sendable {
  case accepted
  case rejected
  case failed
}

private actor ScriptedRuntimeTransport: DevicePayloadTransport {
  private var results: [ScriptedRuntimeTransportResult]
  private var payloads: [Data] = []

  init(results: [ScriptedRuntimeTransportResult]) {
    self.results = results
  }

  func activate() async {}

  func send(_ payload: Data, mode: DeviceTransferMode) async throws -> DeviceTransferReceipt {
    let result = results.isEmpty ? .accepted : results.removeFirst()
    switch result {
    case .accepted:
      payloads.append(payload)
      return DeviceTransferReceipt(acceptedLocally: true, mode: mode)
    case .rejected:
      return DeviceTransferReceipt(acceptedLocally: false, mode: mode)
    case .failed:
      throw ScriptedRuntimeError.transportFailed
    }
  }

  func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] {
    payloads.enumerated().map { offset, payload in
      ReceivedDevicePayload(id: DevicePayloadID("scripted-\(offset)"), payload: payload)
    }
  }

  func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {}
}

private actor ScriptedWorkoutRecorder: WorkoutRecording {
  private let capability: OptionalCapabilityState
  private let authorization: OptionalCapabilityState
  private let startError: Error?
  private let stopError: Error?
  private let summary: HealthKitWorkoutSummary?
  private var authorizationRequestCount = 0
  private var startCount = 0
  private var stopCount = 0

  init(
    capability: OptionalCapabilityState,
    authorization: OptionalCapabilityState = .ready,
    startError: Error? = nil,
    stopError: Error? = nil,
    summary: HealthKitWorkoutSummary? = nil
  ) {
    self.capability = capability
    self.authorization = authorization
    self.startError = startError
    self.stopError = stopError
    self.summary = summary
  }

  func capabilityState() async -> OptionalCapabilityState { capability }
  func requestAuthorization() async -> OptionalCapabilityState {
    authorizationRequestCount += 1
    return authorization
  }
  func start(at date: Date) async throws {
    startCount += 1
    if let startError { throw startError }
  }
  func stop(at date: Date) async throws {
    stopCount += 1
    if let stopError { throw stopError }
  }
  func latestSummary() async -> HealthKitWorkoutSummary? { summary }

  func invocationCounts() -> (authorizationRequests: Int, starts: Int, stops: Int) {
    (authorizationRequestCount, startCount, stopCount)
  }
}

private enum ScriptedRuntimeError: Error, CustomStringConvertible {
  case workoutFailed
  case transportFailed

  var description: String {
    switch self {
    case .workoutFailed: "workout failed"
    case .transportFailed: "transport failed"
    }
  }
}
