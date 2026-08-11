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

  public func pendingReceivedEnvelopes() async throws -> [ReceivedDeviceEnvelope] {
    let decoder = JSONDecoder()
    return try await transport.pendingReceivedPayloads().map { received in
      ReceivedDeviceEnvelope(
        payloadID: received.id,
        envelope: try decoder.decode(DeviceEventEnvelope.self, from: received.payload)
      )
    }
  }

  public func receivedEnvelopes() async throws -> [DeviceEventEnvelope] {
    try await pendingReceivedEnvelopes().map(\.envelope)
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
    private var workoutStartedAt: Date?
    private let summaryLock = NSLock()
    private var storedLatestSummary: HealthKitWorkoutSummary?

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
      workoutStartedAt = date
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
      let duration = max(0, date.timeIntervalSince(workoutStartedAt ?? date))
      let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
      let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
      let heartRateStatistics = heartRateType.flatMap { builder.statistics(for: $0) }
      let activeEnergyStatistics = activeEnergyType.flatMap { builder.statistics(for: $0) }
      let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
      let summary = HealthKitWorkoutSummary(
        durationSeconds: duration,
        averageHeartRateBPM: heartRateStatistics?.averageQuantity()?.doubleValue(
          for: heartRateUnit),
        maximumHeartRateBPM: heartRateStatistics?.maximumQuantity()?.doubleValue(
          for: heartRateUnit),
        heartRateCoverage: nil,
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
      workoutStartedAt = nil
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

    public func workoutBuilder(
      _ workoutBuilder: HKLiveWorkoutBuilder,
      didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {}
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

    private let session: WCSession
    private let inbox: DurableDevicePayloadInbox
    private let completions = DeviceTransferCompletionRegistry<UUID>()
    private let delegateErrorLock = NSLock()
    private var delegatePersistenceError: DevicePayloadInboxError?

    public init(session: WCSession = .default) {
      self.session = session
      inbox = DurableDevicePayloadInbox()
      super.init()
      session.delegate = self
    }

    public init(
      session: WCSession = .default,
      inboxStore: any DevicePayloadInboxStore
    ) throws {
      self.session = session
      inbox = try DurableDevicePayloadInbox(store: inboxStore)
      super.init()
      session.delegate = self
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

      let completion = await completions.wait(for: transferID)
      try Task.checkCancellation()
      switch completion {
      case .succeeded:
        return DeviceTransferReceipt(disposition: .durablyCompleted, mode: mode)
      case .failed(let reason):
        throw WatchConnectivityPayloadTransportError.backgroundTransferFailed(reason)
      }
    }

    public func pendingReceivedPayloads() async throws -> [ReceivedDevicePayload] {
      if let error = delegateErrorLock.withLock({ delegatePersistenceError }) {
        throw error
      }
      return inbox.pendingPayloads
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
        delegateErrorLock.withLock { delegatePersistenceError = nil }
      } catch let error as DevicePayloadInboxError {
        delegateErrorLock.withLock { delegatePersistenceError = error }
      } catch {
        delegateErrorLock.withLock {
          delegatePersistenceError = .delegatePersistenceFailed(String(describing: error))
        }
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
