import Foundation
import LineWiseApplication
import LineWiseDomain

public enum LineWiseWorkoutStatus: Equatable, Sendable {
  case idle
  case preparing
  case recording
  case completing
  case completed
  case degraded(OptionalCapabilityState)
  case failed(String)
}

public enum LineWiseHealthRecordingPreference: Equatable, Sendable {
  case manualOnly
  case enabled
}

public enum LineWiseSyncPhase: Equatable, Sendable {
  case inactive
  case activating
  case ready
  case syncing
  case synchronized
  case pending
  case degraded
}

public struct LineWiseSyncStatus: Equatable, Sendable {
  public let phase: LineWiseSyncPhase
  public let pendingCount: Int
  public let lastError: String?

  public init(phase: LineWiseSyncPhase, pendingCount: Int, lastError: String? = nil) {
    self.phase = phase
    self.pendingCount = pendingCount
    self.lastError = lastError
  }
}

public struct DeviceSyncPullResult: Equatable, Sendable {
  public let insertedCount: Int
  public let duplicateCount: Int
  public let error: String?

  public init(insertedCount: Int, duplicateCount: Int, error: String? = nil) {
    self.insertedCount = insertedCount
    self.duplicateCount = duplicateCount
    self.error = error
  }
}

@MainActor
private enum LineWiseAppleCaptureBackend {
  case app(LineWiseAppCoordinator)
  case experience(PersistentLineWiseExperienceCoordinator)

  var projection: LineWiseAppProjection {
    switch self {
    case .app(let coordinator): coordinator.projection
    case .experience(let coordinator): coordinator.projection.capture
    }
  }

  var watchProjection: WatchCaptureProjection {
    switch self {
    case .app(let coordinator): coordinator.watchProjection
    case .experience(let coordinator): coordinator.watchProjection
    }
  }

  var pendingOutboundEvents: [DeviceEventEnvelope] {
    switch self {
    case .app(let coordinator): coordinator.pendingOutboundEvents
    case .experience(let coordinator): coordinator.pendingOutboundEvents
    }
  }

  mutating func handle(_ intent: LineWiseAppIntent) -> LineWiseAppFeedback {
    switch self {
    case .app(var coordinator):
      let feedback = coordinator.handle(intent)
      self = .app(coordinator)
      return feedback
    case .experience(var coordinator):
      do {
        let feedback = try coordinator.handle(intent)
        self = .experience(coordinator)
        return feedback
      } catch {
        let projection = coordinator.projection.capture
        self = .experience(coordinator)
        return LineWiseAppFeedback(
          outcome: .persistenceFailed(String(describing: error)),
          projection: projection
        )
      }
    }
  }

  mutating func receive(_ envelopes: [DeviceEventEnvelope]) -> LineWiseDeviceSyncOutcome {
    switch self {
    case .app(var coordinator):
      let result = coordinator.receive(envelopes)
      self = .app(coordinator)
      return result
    case .experience(var coordinator):
      let result = coordinator.receive(envelopes)
      self = .experience(coordinator)
      return result
    }
  }

  mutating func acknowledgeOutbound(_ eventID: ActionID) -> LineWiseDeviceSyncOutcome {
    switch self {
    case .app(var coordinator):
      let result = coordinator.acknowledgeOutbound(eventID)
      self = .app(coordinator)
      return result
    case .experience(var coordinator):
      let result = coordinator.acknowledgeOutbound(eventID)
      self = .experience(coordinator)
      return result
    }
  }
}

/// Owns the production Apple runtime boundary while leaving the domain capture
/// loop authoritative. HealthKit recording requires a separate explicit user
/// opt-in, while cross-device delivery follows durable capture mutations.
@MainActor
public final class LineWiseAppleRuntime {
  public let deviceID: DeviceID

  private var captureBackend: LineWiseAppleCaptureBackend
  private let syncService: LineWiseDeviceSyncService
  private let workoutRecorder: any WorkoutRecording
  private var optionalCapabilityTask: Task<Void, Never>?
  private var inFlightFlush: Task<DeviceSyncBatchResult, Never>?
  private var authorizedCapabilityAfterOptIn: OptionalCapabilityState?
  private var syncWasActivated = false

  public private(set) var healthRecordingPreference: LineWiseHealthRecordingPreference = .manualOnly
  public private(set) var workoutStatus: LineWiseWorkoutStatus = .idle
  public private(set) var syncStatus: LineWiseSyncStatus
  public private(set) var latestHealthKitWorkoutSummary: HealthKitWorkoutSummary?

  public init(
    persistentRuntime: LineWiseAppRuntime,
    syncService: LineWiseDeviceSyncService,
    workoutRecorder: any WorkoutRecording
  ) {
    deviceID = persistentRuntime.deviceID
    captureBackend = .app(persistentRuntime.coordinator)
    self.syncService = syncService
    self.workoutRecorder = workoutRecorder
    syncStatus = LineWiseSyncStatus(
      phase: .inactive,
      pendingCount: persistentRuntime.coordinator.pendingOutboundEvents.count
    )
  }

  public init(
    deviceID: DeviceID,
    experienceCoordinator: PersistentLineWiseExperienceCoordinator,
    syncService: LineWiseDeviceSyncService,
    workoutRecorder: any WorkoutRecording
  ) {
    self.deviceID = deviceID
    captureBackend = .experience(experienceCoordinator)
    self.syncService = syncService
    self.workoutRecorder = workoutRecorder
    syncStatus = LineWiseSyncStatus(
      phase: .inactive,
      pendingCount: experienceCoordinator.pendingOutboundEvents.count
    )
  }

  public var projection: LineWiseAppProjection {
    captureBackend.projection
  }

  public var watchProjection: WatchCaptureProjection {
    captureBackend.watchProjection
  }

  public var pendingOutboundCount: Int {
    captureBackend.pendingOutboundEvents.count
  }

  @discardableResult
  public func handle(_ intent: LineWiseAppIntent) -> LineWiseAppFeedback {
    let feedback = captureBackend.handle(intent)
    refreshPendingStatusAfterLocalMutation()

    guard feedback.outcome == .accepted else { return feedback }
    switch intent {
    case .startVisit(_, _, let occurredAt, _):
      if healthRecordingPreference == .enabled {
        scheduleWorkoutStart(at: Self.date(from: occurredAt))
      }
    case .endVisit(_, let occurredAt, _):
      scheduleWorkoutStop(at: Self.date(from: occurredAt))
    default:
      break
    }
    return feedback
  }

  /// Records an explicit, runtime-scoped user choice before HealthKit access
  /// is requested. Manual Visit capture remains available for every outcome.
  public func enableHealthRecording() {
    guard healthRecordingPreference == .manualOnly else { return }
    healthRecordingPreference = .enabled
    scheduleHealthAuthorization()
  }

  public func waitForOptionalCapabilityWork() async {
    let task = optionalCapabilityTask
    await task?.value
  }

  public func activateSync() async {
    guard !syncWasActivated else { return }
    syncStatus = LineWiseSyncStatus(
      phase: .activating,
      pendingCount: pendingOutboundCount
    )
    await syncService.activate()
    syncWasActivated = true
    syncStatus = LineWiseSyncStatus(
      phase: pendingOutboundCount == 0 ? .ready : .pending,
      pendingCount: pendingOutboundCount
    )
  }

  /// Flushes the durable Outbox once. `pending` and "no other flush owns these
  /// envelopes" must both still hold after `await syncService.flush`, so an
  /// overlapping call joins the running flush instead of starting a second one.
  /// Without this, every tap during one slow transfer re-sent the same
  /// unacknowledged envelopes, and a late-finishing flush could overwrite a
  /// drained Outbox with a `.degraded` status carrying its own stale failure.
  @discardableResult
  public func flushPendingEvents(
    mode: DeviceTransferMode = .reliableBackground
  ) async -> DeviceSyncBatchResult {
    if let inFlightFlush {
      return await inFlightFlush.value
    }
    let flush = Task { @MainActor [weak self] in
      guard let self else { return DeviceSyncBatchResult(deliveries: []) }
      return await self.performFlush(mode: mode)
    }
    inFlightFlush = flush
    let batch = await flush.value
    inFlightFlush = nil
    return batch
  }

  private func performFlush(mode: DeviceTransferMode) async -> DeviceSyncBatchResult {
    await activateSync()
    let pending = captureBackend.pendingOutboundEvents
    syncStatus = LineWiseSyncStatus(phase: .syncing, pendingCount: pending.count)
    let batch = await syncService.flush(pending, mode: mode)
    var failures: [String] = []

    for delivery in batch.deliveries {
      switch delivery.outcome {
      case .confirmedDurableDelivery:
        let acknowledgement = captureBackend.acknowledgeOutbound(delivery.eventID)
        if case .persistenceFailed(let reason) = acknowledgement {
          failures.append(reason)
        }
      case .notEligibleForDurableAcknowledgement(let reason):
        failures.append("\(delivery.eventID.rawValue): \(reason.description)")
      case .failed(let reason):
        failures.append(reason)
      }
    }

    let remaining = pendingOutboundCount
    if remaining > 0 {
      syncStatus = LineWiseSyncStatus(
        phase: .pending,
        pendingCount: remaining,
        lastError: failures.first
      )
    } else if let failure = failures.first {
      syncStatus = LineWiseSyncStatus(phase: .degraded, pendingCount: 0, lastError: failure)
    } else {
      syncStatus = LineWiseSyncStatus(phase: .synchronized, pendingCount: 0)
    }
    return batch
  }

  /// Drains the durable transport inbox into the capture backend.
  ///
  /// Every inbound payload is isolated: one payload this build cannot decode, or
  /// one envelope that conflicts with already-accepted history, must never
  /// withhold the events that arrived with it or the events that arrive later.
  /// An unresolved payload stays durable and visible rather than being silently
  /// discarded or auto-resolved, and only payloads whose events actually
  /// persisted are acknowledged.
  @discardableResult
  public func pullReceivedEvents() async -> DeviceSyncPullResult {
    await activateSync()
    let batch: DeviceInboundBatch
    do {
      batch = try await syncService.pull()
    } catch {
      let reason = String(describing: error)
      syncStatus = LineWiseSyncStatus(
        phase: pendingOutboundCount > 0 ? .pending : .degraded,
        pendingCount: pendingOutboundCount,
        lastError: reason
      )
      return DeviceSyncPullResult(insertedCount: 0, duplicateCount: 0, error: reason)
    }

    var undeliverableReasons: [String] = batch.undecodablePayloads.map {
      "\($0.payloadID.rawValue): \($0.reason)"
    }
    let delivery = deliver(batch.envelopes)
    undeliverableReasons += delivery.failures

    if !delivery.acknowledgeablePayloadIDs.isEmpty {
      do {
        try await syncService.acknowledgeReceived(delivery.acknowledgeablePayloadIDs)
      } catch {
        let reason = String(describing: error)
        syncStatus = LineWiseSyncStatus(
          phase: .degraded,
          pendingCount: pendingOutboundCount,
          lastError: reason
        )
        return DeviceSyncPullResult(
          insertedCount: delivery.insertedCount,
          duplicateCount: delivery.duplicateCount,
          error: reason
        )
      }
    }

    guard let failure = undeliverableReasons.first else {
      refreshSyncStatusAfterPull()
      return DeviceSyncPullResult(
        insertedCount: delivery.insertedCount,
        duplicateCount: delivery.duplicateCount
      )
    }
    syncStatus = LineWiseSyncStatus(
      phase: .degraded,
      pendingCount: pendingOutboundCount,
      lastError: failure
    )
    return DeviceSyncPullResult(
      insertedCount: delivery.insertedCount,
      duplicateCount: delivery.duplicateCount,
      error: failure
    )
  }

  private struct InboundDelivery {
    var insertedCount = 0
    var duplicateCount = 0
    var acknowledgeablePayloadIDs: [DevicePayloadID] = []
    var failures: [String] = []
  }

  private func deliver(_ received: [ReceivedDeviceEnvelope]) -> InboundDelivery {
    var delivery = InboundDelivery()
    guard !received.isEmpty else { return delivery }

    // The batch path is the common case and keeps replay ordering work to one
    // fold. A rejection is not attributable to a single envelope, so fall back
    // to delivering each one on its own to find who is actually undeliverable.
    switch captureBackend.receive(received.map(\.envelope)) {
    case .received(let insertedEventIDs, let duplicateEventIDs):
      delivery.insertedCount = insertedEventIDs.count
      delivery.duplicateCount = duplicateEventIDs.count
      delivery.acknowledgeablePayloadIDs = received.map(\.payloadID)
      return delivery
    case .persistenceFailed, .unavailable, .acknowledged, .alreadyAcknowledged:
      break
    }

    for entry in received {
      switch captureBackend.receive([entry.envelope]) {
      case .received(let insertedEventIDs, let duplicateEventIDs):
        delivery.insertedCount += insertedEventIDs.count
        delivery.duplicateCount += duplicateEventIDs.count
        delivery.acknowledgeablePayloadIDs.append(entry.payloadID)
      case .persistenceFailed(let reason):
        delivery.failures.append("\(entry.payloadID.rawValue): \(reason)")
      case .unavailable:
        delivery.failures.append(
          "\(entry.payloadID.rawValue): Persistent device inbox is unavailable"
        )
      case .acknowledged, .alreadyAcknowledged:
        delivery.failures.append("\(entry.payloadID.rawValue): Unexpected device receive result")
      }
    }
    return delivery
  }

  private func scheduleWorkoutStart(at date: Date) {
    let preceding = optionalCapabilityTask
    workoutStatus = .preparing
    optionalCapabilityTask = Task { [weak self] in
      await preceding?.value
      guard let self else { return }
      await self.startOptionalWorkout(at: date)
    }
  }

  private func scheduleHealthAuthorization() {
    let preceding = optionalCapabilityTask
    workoutStatus = .preparing
    optionalCapabilityTask = Task { [weak self] in
      await preceding?.value
      guard let self else { return }
      var capability = await self.workoutRecorder.capabilityState()
      if capability == .authorizationRequired {
        capability = await self.workoutRecorder.requestAuthorization()
      }
      self.authorizedCapabilityAfterOptIn = capability
      self.workoutStatus = capability == .ready ? .idle : .degraded(capability)
    }
  }

  private func scheduleWorkoutStop(at date: Date) {
    let preceding = optionalCapabilityTask
    optionalCapabilityTask = Task { [weak self] in
      await preceding?.value
      guard let self else { return }
      guard self.workoutStatus == .recording else { return }
      self.workoutStatus = .completing
      await self.stopOptionalWorkout(at: date)
    }
  }

  private func startOptionalWorkout(at date: Date) async {
    var capability: OptionalCapabilityState
    if let authorizedCapabilityAfterOptIn {
      capability = authorizedCapabilityAfterOptIn
    } else {
      capability = await workoutRecorder.capabilityState()
    }
    if capability == .authorizationRequired {
      capability = await workoutRecorder.requestAuthorization()
    }
    authorizedCapabilityAfterOptIn = capability
    guard capability == .ready else {
      workoutStatus = .degraded(capability)
      return
    }
    do {
      try await workoutRecorder.start(at: date)
      workoutStatus = .recording
    } catch {
      workoutStatus = .failed(String(describing: error))
    }
  }

  private func stopOptionalWorkout(at date: Date) async {
    guard workoutStatus == .completing else { return }
    do {
      try await workoutRecorder.stop(at: date)
      latestHealthKitWorkoutSummary = await workoutRecorder.latestSummary()
      workoutStatus = .completed
    } catch {
      workoutStatus = .failed(String(describing: error))
    }
  }

  private func refreshPendingStatusAfterLocalMutation() {
    let pending = pendingOutboundCount
    guard pending > 0 else { return }
    syncStatus = LineWiseSyncStatus(
      phase: syncWasActivated ? .pending : .inactive,
      pendingCount: pending,
      lastError: syncStatus.lastError
    )
  }

  private func refreshSyncStatusAfterPull() {
    let pending = pendingOutboundCount
    syncStatus = LineWiseSyncStatus(
      phase: pending == 0 ? .synchronized : .pending,
      pendingCount: pending,
      lastError: pending == 0 ? nil : syncStatus.lastError
    )
  }

  private static func date(from instant: Instant) -> Date {
    Date(timeIntervalSince1970: Double(instant.rawValue) / 1_000)
  }
}
