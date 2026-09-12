import Foundation
import LineWiseApplication
import LineWiseDomain

public enum OptionalCapabilityState: Equatable, Sendable {
  case unavailable
  case authorizationRequired
  case denied
  case ready
  case failed(String)
}

public protocol WorkoutRecording: Sendable {
  func capabilityState() async -> OptionalCapabilityState
  func requestAuthorization() async -> OptionalCapabilityState
  func start(at date: Date) async throws
  func stop(at date: Date) async throws
  func latestSummary() async -> HealthKitWorkoutSummary?
}

public struct NoHealthKitWorkoutRecorder: WorkoutRecording {
  public init() {}

  public func capabilityState() async -> OptionalCapabilityState {
    .unavailable
  }

  public func requestAuthorization() async -> OptionalCapabilityState {
    .unavailable
  }

  public func start(at date: Date) async throws {}

  public func stop(at date: Date) async throws {}

  public func latestSummary() async -> HealthKitWorkoutSummary? {
    nil
  }
}

public enum DeviceTransferMode: Equatable, Sendable {
  case reliableBackground
  case latestContext
  case immediateIfReachable
}

public enum DeviceTransferNonAcknowledgementReason: Equatable, Sendable,
  CustomStringConvertible
{
  case latestContextIsReplaceable
  case sessionNotActivated
  case transportDidNotConfirm

  public var description: String {
    switch self {
    case .latestContextIsReplaceable:
      "latestContext is replaceable and cannot acknowledge a durable event"
    case .sessionNotActivated:
      "the device transport session is not activated"
    case .transportDidNotConfirm:
      "the device transport did not confirm durable completion"
    }
  }
}

public enum DeviceTransferReceiptDisposition: Equatable, Sendable {
  case durablyCompleted
  case notEligibleForDurableAcknowledgement(DeviceTransferNonAcknowledgementReason)
}

public struct DeviceTransferReceipt: Equatable, Sendable {
  public let disposition: DeviceTransferReceiptDisposition
  public let mode: DeviceTransferMode

  public init(
    disposition: DeviceTransferReceiptDisposition,
    mode: DeviceTransferMode
  ) {
    self.disposition = disposition
    self.mode = mode
  }

  /// Compatibility initializer for simple fakes. A `true` value means the
  /// transport has durably completed delivery, not merely queued work in RAM.
  public init(acceptedLocally: Bool, mode: DeviceTransferMode) {
    disposition =
      acceptedLocally
      ? .durablyCompleted
      : .notEligibleForDurableAcknowledgement(.transportDidNotConfirm)
    self.mode = mode
  }

  public var acceptedLocally: Bool {
    disposition == .durablyCompleted
  }
}

public protocol DevicePayloadTransport: Sendable {
  func activate() async
  func send(_ payload: Data, mode: DeviceTransferMode) async throws -> DeviceTransferReceipt
  func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload]
  func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws
}

extension DevicePayloadTransport {
  public func receivedPayloads() async -> [Data] {
    (try? await pendingReceivedPayloads().map(\.payload)) ?? []
  }
}

public actor InMemoryDevicePayloadTransport: DevicePayloadTransport {
  private var payloads: [ReceivedDevicePayload] = []

  public init() {}

  public func activate() async {}

  public func send(_ payload: Data, mode: DeviceTransferMode) async throws -> DeviceTransferReceipt
  {
    guard mode != .latestContext else {
      return DeviceTransferReceipt(
        disposition: .notEligibleForDurableAcknowledgement(.latestContextIsReplaceable),
        mode: mode
      )
    }
    payloads.append(
      ReceivedDevicePayload(
        id: DevicePayloadID(UUID().uuidString.lowercased()),
        payload: payload
      )
    )
    return DeviceTransferReceipt(disposition: .durablyCompleted, mode: mode)
  }

  public func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] {
    payloads
  }

  public func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {
    let acknowledged = Set(payloadIDs)
    payloads.removeAll { acknowledged.contains($0.id) }
  }
}

public struct ReceivedDeviceEnvelope: Equatable, Sendable {
  public let payloadID: DevicePayloadID
  public let envelope: DeviceEventEnvelope

  public init(payloadID: DevicePayloadID, envelope: DeviceEventEnvelope) {
    self.payloadID = payloadID
    self.envelope = envelope
  }
}

/// An inbound payload this build cannot interpret as a `DeviceEventEnvelope`.
///
/// A counterpart that updates first can send a command kind an older build does
/// not know. Such a payload is retained rather than discarded — silently
/// dropping a peer's durable event would lose confirmed history — but it must
/// never withhold the payloads that did decode.
public struct UndecodableDevicePayload: Equatable, Sendable {
  public let payloadID: DevicePayloadID
  public let reason: String

  public init(payloadID: DevicePayloadID, reason: String) {
    self.payloadID = payloadID
    self.reason = reason
  }
}

/// The decodable and undecodable halves of one durable inbox read, kept apart so
/// a single bad payload cannot stall every later inbound event behind it.
public struct DeviceInboundBatch: Equatable, Sendable {
  public let envelopes: [ReceivedDeviceEnvelope]
  public let undecodablePayloads: [UndecodableDevicePayload]

  public init(
    envelopes: [ReceivedDeviceEnvelope],
    undecodablePayloads: [UndecodableDevicePayload] = []
  ) {
    self.envelopes = envelopes
    self.undecodablePayloads = undecodablePayloads
  }

  public var isEmpty: Bool {
    envelopes.isEmpty && undecodablePayloads.isEmpty
  }
}

public actor DeviceEnvelopeBridge {
  private let transport: any DevicePayloadTransport

  public init(transport: any DevicePayloadTransport) {
    self.transport = transport
  }

  public func activate() async {
    await transport.activate()
  }

  public func send(
    _ envelope: DeviceEventEnvelope,
    mode: DeviceTransferMode = .reliableBackground
  ) async throws -> DeviceTransferReceipt {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try await transport.send(encoder.encode(envelope), mode: mode)
  }

  /// Decodes each durable inbox payload independently. A payload that cannot be
  /// decoded is reported alongside the ones that could, never in place of them.
  public func pendingReceivedEnvelopes() async throws -> DeviceInboundBatch {
    let decoder = JSONDecoder()
    var envelopes: [ReceivedDeviceEnvelope] = []
    var undecodable: [UndecodableDevicePayload] = []
    for received in try await transport.pendingReceivedPayloads() {
      do {
        envelopes.append(
          ReceivedDeviceEnvelope(
            payloadID: received.id,
            envelope: try decoder.decode(DeviceEventEnvelope.self, from: received.payload)
          )
        )
      } catch {
        undecodable.append(
          UndecodableDevicePayload(
            payloadID: received.id,
            reason: String(describing: error)
          )
        )
      }
    }
    return DeviceInboundBatch(envelopes: envelopes, undecodablePayloads: undecodable)
  }

  public func receivedEnvelopes() async throws -> [DeviceEventEnvelope] {
    try await pendingReceivedEnvelopes().envelopes.map(\.envelope)
  }

  public func acknowledgeReceivedPayloads(_ payloadIDs: [DevicePayloadID]) async throws {
    try await transport.acknowledgeReceivedPayloads(payloadIDs)
  }
}

#if canImport(HealthKit) && os(watchOS)
  import HealthKit

  public final class HealthKitWorkoutRecorder: NSObject, WorkoutRecording, @unchecked Sendable {
    private let healthStore: HKHealthStore
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private let summaryLock = NSLock()
    private var storedLatestSummary: HealthKitWorkoutSummary?
    // The whole live-collection window is guarded by summaryLock, because
    // HealthKit invokes didCollectDataOf on an arbitrary background queue while
    // start()/stop() run from the MainActor-driven runtime. This class is
    // @unchecked Sendable, so the lock is the only thing standing between an
    // in-flight sample and a torn read of the workout start — which would either
    // drop the sample and under-report coverage, or crash.
    private var workoutStartedAt: Date?
    private var coverageAccumulator = HeartRateCoverageAccumulator()

    public init(healthStore: HKHealthStore = HKHealthStore()) {
      self.healthStore = healthStore
      super.init()
    }

    public func capabilityState() async -> OptionalCapabilityState {
      guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
      switch healthStore.authorizationStatus(for: HKObjectType.workoutType()) {
      case .notDetermined:
        return .authorizationRequired
      case .sharingDenied:
        return .denied
      case .sharingAuthorized:
        return .ready
      @unknown default:
        return .failed("Unknown HealthKit workout authorization state")
      }
    }

    public func requestAuthorization() async -> OptionalCapabilityState {
      guard HKHealthStore.isHealthDataAvailable() else {
        return .unavailable
      }
      let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
      var readTypes: Set<HKObjectType> = []
      if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
        readTypes.insert(heartRate)
      }
      if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
        readTypes.insert(activeEnergy)
      }
      do {
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        return await capabilityState()
      } catch {
        return .failed(String(describing: error))
      }
    }

    public func start(at date: Date) async throws {
      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .climbing
      configuration.locationType = .indoor
      let session = try HKWorkoutSession(
        healthStore: healthStore,
        configuration: configuration
      )
      let builder = session.associatedWorkoutBuilder()
      builder.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore,
        workoutConfiguration: configuration
      )
      session.delegate = self
      builder.delegate = self
      workoutSession = session
      workoutBuilder = builder
      summaryLock.withLock {
        workoutStartedAt = date
        coverageAccumulator = HeartRateCoverageAccumulator()
      }
      session.startActivity(with: date)
      try await builder.beginCollection(at: date)
    }

    public func stop(at date: Date) async throws {
      guard let session = workoutSession, let builder = workoutBuilder else {
        return
      }
      session.end()
      try await builder.endCollection(at: date)
      _ = try await builder.finishWorkout()
      let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
      let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
      let heartRateStatistics = heartRateType.flatMap { builder.statistics(for: $0) }
      let activeEnergyStatistics = activeEnergyType.flatMap { builder.statistics(for: $0) }
      let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
      // One critical section closes the live window, reads the start instant and
      // folds the accumulator, so a final delegate callback either lands fully
      // inside this workout's coverage or is cleanly excluded from it.
      let (duration, coverage) = summaryLock.withLock {
        () -> (TimeInterval, Double?) in
        let elapsed = max(0, date.timeIntervalSince(workoutStartedAt ?? date))
        let coverage =
          elapsed > 0 ? coverageAccumulator.coverage(overWorkoutDurationSeconds: elapsed) : nil
        workoutStartedAt = nil
        return (elapsed, coverage)
      }
      let summary = HealthKitWorkoutSummary(
        durationSeconds: duration,
        averageHeartRateBPM: heartRateStatistics?.averageQuantity()?.doubleValue(
          for: heartRateUnit),
        maximumHeartRateBPM: heartRateStatistics?.maximumQuantity()?.doubleValue(
          for: heartRateUnit),
        heartRateCoverage: coverage,
        activeEnergyKilocalories: activeEnergyStatistics?.sumQuantity()?.doubleValue(
          for: .kilocalorie()
        ),
        workoutEffortScore: nil,
        workoutEffortSource: nil,
        sourceVersion: "healthkit-live-workout-v1"
      )
      summaryLock.withLock { storedLatestSummary = summary }
      workoutSession = nil
      workoutBuilder = nil
    }

    public func latestSummary() async -> HealthKitWorkoutSummary? {
      summaryLock.withLock { storedLatestSummary }
    }
  }

  extension HealthKitWorkoutRecorder: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    public func workoutSession(
      _ workoutSession: HKWorkoutSession,
      didChangeTo toState: HKWorkoutSessionState,
      from fromState: HKWorkoutSessionState,
      date: Date
    ) {}

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    // Live data collection. Real-device gate: this path only runs against a
    // real HKLiveWorkoutBuilder on a signed Apple Watch, so its coverage
    // contribution cannot be exercised by the Swift-package specs. The pure
    // accumulation logic it delegates to (HeartRateCoverageAccumulator) is
    // covered by physiologyCoverageSpecifications.
    //
    // HealthKit calls this on an arbitrary background queue, so the workout
    // start instant and the accumulator are read and updated inside one
    // summaryLock critical section. A sample arriving after stop() closed the
    // window finds no start and is excluded, rather than racing a torn read.
    public func workoutBuilder(
      _ workoutBuilder: HKLiveWorkoutBuilder,
      didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
      guard
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
        collectedTypes.contains(heartRateType),
        let statistics = workoutBuilder.statistics(for: heartRateType)
      else { return }

      let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
      guard let averageBPM = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) else {
        return
      }
      summaryLock.withLock {
        guard let start = workoutStartedAt else { return }
        coverageAccumulator.observeWindow(
          startSeconds: max(0, statistics.startDate.timeIntervalSince(start)),
          endSeconds: max(0, statistics.endDate.timeIntervalSince(start)),
          bpm: averageBPM
        )
      }
    }
  }
#endif

#if canImport(WatchConnectivity) && (os(iOS) || os(watchOS))
  import WatchConnectivity

  public enum WatchConnectivityPayloadTransportError: Error, Equatable, Sendable,
    CustomStringConvertible
  {
    case backgroundTransferFailed(String)

    public var description: String {
      switch self {
      case .backgroundTransferFailed(let reason):
        "WatchConnectivity background transfer failed: \(reason)"
      }
    }
  }

  public final class WatchConnectivityPayloadTransport: NSObject, DevicePayloadTransport,
    @unchecked Sendable
  {
    private static let envelopeKey = "linewiseEnvelope"
    private static let payloadIDKey = "linewisePayloadID"

    /// WatchConnectivity may never deliver `didFinish` for a queued transfer, so
    /// every durable send is bounded. The event stays unacknowledged and the next
    /// flush retries it under the same stable ActionID, which is strictly better
    /// than freezing the outbox and the sync poll loop behind one transfer.
    public static let defaultTransferConfirmationTimeoutSeconds: Double = 120

    private let session: WCSession
    private let inbox: DurableDevicePayloadInbox
    private let completions = DeviceTransferCompletionRegistry<UUID>()
    private let transferConfirmationTimeoutNanoseconds: UInt64

    public init(
      session: WCSession = .default,
      transferConfirmationTimeoutSeconds: Double =
        WatchConnectivityPayloadTransport.defaultTransferConfirmationTimeoutSeconds
    ) {
      self.session = session
      inbox = DurableDevicePayloadInbox()
      transferConfirmationTimeoutNanoseconds = Self.nanoseconds(
        from: transferConfirmationTimeoutSeconds
      )
      super.init()
      session.delegate = self
    }

    public init(
      session: WCSession = .default,
      inboxStore: any DevicePayloadInboxStore,
      transferConfirmationTimeoutSeconds: Double =
        WatchConnectivityPayloadTransport.defaultTransferConfirmationTimeoutSeconds
    ) throws {
      self.session = session
      inbox = try DurableDevicePayloadInbox(store: inboxStore)
      transferConfirmationTimeoutNanoseconds = Self.nanoseconds(
        from: transferConfirmationTimeoutSeconds
      )
      super.init()
      session.delegate = self
    }

    private static func nanoseconds(from seconds: Double) -> UInt64 {
      UInt64(max(1, seconds) * 1_000_000_000)
    }

    public func activate() async {
      guard WCSession.isSupported() else { return }
      session.activate()
    }

    public func send(
      _ payload: Data,
      mode: DeviceTransferMode
    ) async throws -> DeviceTransferReceipt {
      guard session.activationState == .activated else {
        session.activate()
        return DeviceTransferReceipt(
          disposition: .notEligibleForDurableAcknowledgement(.sessionNotActivated),
          mode: mode
        )
      }
      let transferID = UUID()
      let value: [String: Any] = [
        Self.envelopeKey: payload,
        Self.payloadIDKey: transferID.uuidString.lowercased(),
      ]
      switch mode {
      case .reliableBackground:
        await completions.prepare(transferID)
        session.transferUserInfo(value)
      case .latestContext:
        try session.updateApplicationContext(value)
        return DeviceTransferReceipt(
          disposition: .notEligibleForDurableAcknowledgement(.latestContextIsReplaceable),
          mode: mode
        )
      case .immediateIfReachable:
        if session.isReachable {
          session.sendMessage(value, replyHandler: nil, errorHandler: nil)
        }
        // The fast path improves latency but never acknowledges durable work.
        // Its reliable fallback owns the completion callback and uses the same
        // payload ID so the receiver's durable inbox can deduplicate both.
        await completions.prepare(transferID)
        session.transferUserInfo(value)
      }

      try Task.checkCancellation()
      let completion = await completions.wait(
        for: transferID,
        timeoutNanoseconds: transferConfirmationTimeoutNanoseconds
      )
      try Task.checkCancellation()
      switch completion {
      case .succeeded:
        return DeviceTransferReceipt(disposition: .durablyCompleted, mode: mode)
      case .failed(let reason):
        throw WatchConnectivityPayloadTransportError.backgroundTransferFailed(reason)
      }
    }

    public func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] {
      // A lost inbound delivery must stay visible, but it must never withhold
      // payloads that were already committed — those are confirmed peer events
      // and holding them back stalls late or conflicting events that should
      // reopen review.
      try inbox.readPendingPayloadsReportingFault()
    }

    public func acknowledgeReceivedPayloads(
      _ payloadIDs: [DevicePayloadID]
    ) async throws {
      try inbox.acknowledge(payloadIDs)
    }

    private func receive(_ userInfo: [String: Any]) {
      guard let data = userInfo[Self.envelopeKey] as? Data else { return }
      let payloadID = DevicePayloadID(
        (userInfo[Self.payloadIDKey] as? String) ?? UUID().uuidString.lowercased()
      )
      do {
        _ = try inbox.receive(ReceivedDevicePayload(id: payloadID, payload: data))
      } catch let error as DevicePayloadInboxError {
        inbox.recordDeliveryFault(error)
      } catch {
        inbox.recordDeliveryFault(.delegatePersistenceFailed(String(describing: error)))
      }
    }
  }

  extension WatchConnectivityPayloadTransport: WCSessionDelegate {
    public func session(
      _ session: WCSession,
      activationDidCompleteWith activationState: WCSessionActivationState,
      error: Error?
    ) {}

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
      receive(userInfo)
    }

    public func session(
      _ session: WCSession,
      didFinish userInfoTransfer: WCSessionUserInfoTransfer,
      error: Error?
    ) {
      guard
        let rawTransferID = userInfoTransfer.userInfo[Self.payloadIDKey] as? String,
        let transferID = UUID(uuidString: rawTransferID)
      else { return }
      let completion: DeviceTransferCompletion =
        error.map {
          .failed(String(describing: $0))
        } ?? .succeeded
      Task { [completions] in
        await completions.complete(completion, for: transferID)
      }
    }

    public func session(
      _ session: WCSession,
      didReceiveApplicationContext applicationContext: [String: Any]
    ) {
      receive(applicationContext)
    }

    public func session(
      _ session: WCSession,
      didReceiveMessage message: [String: Any]
    ) {
      receive(message)
    }

    #if os(iOS)
      public func sessionDidBecomeInactive(_ session: WCSession) {}

      public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
      }
    #endif
  }
#endif
