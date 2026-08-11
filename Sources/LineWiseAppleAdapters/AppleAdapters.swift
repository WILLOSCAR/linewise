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

public struct DeviceTransferReceipt: Equatable, Sendable {
  public let acceptedLocally: Bool
  public let mode: DeviceTransferMode

  public init(acceptedLocally: Bool, mode: DeviceTransferMode) {
    self.acceptedLocally = acceptedLocally
    self.mode = mode
  }
}

public protocol DevicePayloadTransport: Sendable {
  func activate() async
  func send(_ payload: Data, mode: DeviceTransferMode) async throws -> DeviceTransferReceipt
  func receivedPayloads() async -> [Data]
}

public actor InMemoryDevicePayloadTransport: DevicePayloadTransport {
  private var payloads: [Data] = []

  public init() {}

  public func activate() async {}

  public func send(_ payload: Data, mode: DeviceTransferMode) async throws -> DeviceTransferReceipt
  {
    payloads.append(payload)
    return DeviceTransferReceipt(acceptedLocally: true, mode: mode)
  }

  public func receivedPayloads() async -> [Data] {
    payloads
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

  public func receivedEnvelopes() async throws -> [DeviceEventEnvelope] {
    let decoder = JSONDecoder()
    return try await transport.receivedPayloads().map {
      try decoder.decode(DeviceEventEnvelope.self, from: $0)
    }
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

  public final class WatchConnectivityPayloadTransport: NSObject, DevicePayloadTransport,
    @unchecked Sendable
  {
    private let session: WCSession
    private let lock = NSLock()
    private var inbox: [Data] = []

    public init(session: WCSession = .default) {
      self.session = session
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
        return DeviceTransferReceipt(acceptedLocally: false, mode: mode)
      }
      let value: [String: Any] = ["linewiseEnvelope": payload]
      switch mode {
      case .reliableBackground:
        session.transferUserInfo(value)
      case .latestContext:
        try session.updateApplicationContext(value)
      case .immediateIfReachable:
        if session.isReachable {
          session.sendMessage(value, replyHandler: nil, errorHandler: nil)
        }
        // Keep a reliable local queue even when the best-effort fast path is
        // reachable. Duplicate reception is safe because DeviceEventEnvelope
        // replay is idempotent.
        session.transferUserInfo(value)
      }
      return DeviceTransferReceipt(acceptedLocally: true, mode: mode)
    }

    public func receivedPayloads() async -> [Data] {
      lock.withLock { inbox }
    }

    private func receive(_ userInfo: [String: Any]) {
      guard let data = userInfo["linewiseEnvelope"] as? Data else { return }
      lock.withLock { inbox.append(data) }
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
