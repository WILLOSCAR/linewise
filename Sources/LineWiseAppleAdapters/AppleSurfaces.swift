#if canImport(SwiftUI) && (os(iOS) || os(watchOS))
  import Foundation
  import LineWiseApplication
  import LineWiseDomain
  import SwiftUI

  @MainActor
  public final class LineWiseAppViewModel: ObservableObject {
    @Published public private(set) var projection: LineWiseAppProjection
    @Published public private(set) var feedback: LineWiseAppOutcome?
    @Published public private(set) var syncStatus: LineWiseSyncStatus
    @Published public private(set) var workoutStatus: LineWiseWorkoutStatus
    @Published public private(set) var healthRecordingPreference: LineWiseHealthRecordingPreference
    @Published public private(set) var latestHealthKitWorkoutSummary: HealthKitWorkoutSummary?
    @Published public private(set) var currentInstant: Instant
    @Published public private(set) var isLowPowerMode = false

    private let runtime: LineWiseAppleRuntime
    private var clockTask: Task<Void, Never>?
    private var syncPollingTask: Task<Void, Never>?

    public init(runtime: LineWiseAppleRuntime) {
      self.runtime = runtime
      projection = runtime.projection
      syncStatus = runtime.syncStatus
      workoutStatus = runtime.workoutStatus
      healthRecordingPreference = runtime.healthRecordingPreference
      latestHealthKitWorkoutSummary = runtime.latestHealthKitWorkoutSummary
      currentInstant = Self.now
    }

    public var watchProjection: WatchCaptureProjection {
      runtime.watchProjection
    }

    public func handle(_ intent: LineWiseAppIntent) {
      let result = runtime.handle(intent)
      feedback = result.outcome
      refreshProjection()
      Task { [weak self] in
        guard let self else { return }
        await self.runtime.waitForOptionalCapabilityWork()
        _ = await self.runtime.flushPendingEvents()
        self.refreshProjection()
      }
    }

    public func activate() {
      guard clockTask == nil else { return }
      clockTask = Task { [weak self] in
        while !Task.isCancelled {
          guard let self else { return }
          self.updateClockAndPowerState()
          let seconds: UInt64 = self.isLowPowerMode ? 5 : 1
          try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
        }
      }
      syncPollingTask = Task { [weak self] in
        guard let self else { return }
        await self.runtime.activateSync()
        while !Task.isCancelled {
          _ = await self.runtime.pullReceivedEvents()
          _ = await self.runtime.flushPendingEvents()
          self.refreshProjection()
          let seconds: UInt64 = self.isLowPowerMode ? 30 : 5
          try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
        }
      }
    }

    public func createRoute(label: String) {
      let routeID = RouteCardID(UUID().uuidString)
      handle(
        .createRoute(
          actionID: ActionID(UUID().uuidString),
          routeCardID: routeID,
          label: label,
          availability: .present,
          occurredAt: now,
          source: .iPhone
        )
      )
      handle(.selectRoute(routeID))
    }

    public func startVisit(source: CaptureSource) {
      handle(
        .startVisit(
          actionID: ActionID(UUID().uuidString),
          visitID: GymVisitID(UUID().uuidString),
          occurredAt: now,
          source: source
        )
      )
    }

    public let healthRecordingPurposeMessage =
      "Optionally save this visit as a Health workout for heart-rate and workout-summary context. LineWise does not use it to diagnose fatigue, safety, or injury."

    public var healthRecordingStatusText: String {
      switch workoutStatus {
      case .idle:
        "Ready for the next Visit"
      case .preparing:
        "Checking Health access"
      case .recording:
        "Recording an optional Health workout"
      case .completing:
        "Saving the optional Health workout"
      case .completed:
        "Health workout saved"
      case .degraded(.denied):
        "Health access was denied; manual capture remains available"
      case .degraded(.unavailable):
        "Health recording is unavailable; manual capture remains available"
      case .degraded(.authorizationRequired):
        "Health access still requires authorization"
      case .degraded(.ready):
        "Health recording is ready"
      case .degraded(.failed(let reason)), .failed(let reason):
        "Health recording did not start: \(reason)"
      }
    }

    public func enableHealthRecording() {
      runtime.enableHealthRecording()
      refreshProjection()
      Task { [weak self] in
        guard let self else { return }
        await self.runtime.waitForOptionalCapabilityWork()
        self.refreshProjection()
      }
    }

    public func recordAttempt(source: CaptureSource) {
      handle(
        .recordAttempt(
          actionID: ActionID(UUID().uuidString),
          attemptID: AttemptID(UUID().uuidString),
          occurredAt: now,
          source: source
        )
      )
    }

    public func markLatestSend(source: CaptureSource) {
      guard let attempt = projection.currentRouteAttempts.last else { return }
      handle(
        .markSend(
          actionID: ActionID(UUID().uuidString),
          attemptID: attempt.id,
          occurredAt: now,
          source: source
        )
      )
    }

    public func toggleRest() {
      if let activeRest = projection.activeRest {
        handle(
          .stopRest(
            actionID: ActionID(UUID().uuidString),
            restID: activeRest.id,
            occurredAt: now
          )
        )
      } else {
        handle(
          .startRest(
            actionID: ActionID(UUID().uuidString),
            restID: RestIntervalID(UUID().uuidString),
            afterAttemptID: projection.currentRouteAttempts.last?.id,
            occurredAt: now
          )
        )
      }
    }

    public func undoLatest(source: CaptureSource) {
      guard let targetActionID = projection.lastAcceptedActionID else { return }
      handle(
        .undo(
          actionID: ActionID(UUID().uuidString),
          targetActionID: targetActionID,
          occurredAt: now,
          source: source
        )
      )
    }

    public func endVisit(source: CaptureSource) {
      handle(
        .endVisit(
          actionID: ActionID(UUID().uuidString),
          occurredAt: now,
          source: source
        )
      )
    }

    public var visitElapsedText: String? {
      projection.activeVisit.map { visit in
        Self.durationText(milliseconds: max(0, currentInstant.rawValue - visit.startedAt.rawValue))
      }
    }

    public var restElapsedText: String? {
      projection.activeRest.map { rest in
        Self.durationText(milliseconds: rest.elapsedMilliseconds(at: currentInstant))
      }
    }

    public var syncStatusText: String {
      switch syncStatus.phase {
      case .inactive:
        syncStatus.pendingCount == 0 ? "Sync inactive" : "\(syncStatus.pendingCount) pending"
      case .activating:
        "Activating sync"
      case .ready:
        "Sync ready"
      case .syncing:
        "Syncing \(syncStatus.pendingCount)"
      case .synchronized:
        "Synced"
      case .pending:
        "\(syncStatus.pendingCount) pending"
      case .degraded:
        "Sync unavailable"
      }
    }

    private func refreshProjection() {
      projection = runtime.projection
      syncStatus = runtime.syncStatus
      workoutStatus = runtime.workoutStatus
      healthRecordingPreference = runtime.healthRecordingPreference
      latestHealthKitWorkoutSummary = runtime.latestHealthKitWorkoutSummary
    }

    private func updateClockAndPowerState() {
      currentInstant = Self.now
      #if os(watchOS)
        if #available(watchOS 9.0, *) {
          isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
          isLowPowerMode = false
        }
      #else
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
      #endif
    }

    private static var now: Instant {
      Instant(millisecondsSince1970: Int64(Date().timeIntervalSince1970 * 1_000))
    }

    private static func durationText(milliseconds: Int64) -> String {
      let totalSeconds = max(0, milliseconds / 1_000)
      let hours = totalSeconds / 3_600
      let minutes = (totalSeconds % 3_600) / 60
      let seconds = totalSeconds % 60
      if hours > 0 {
        return String(format: "%lld:%02lld:%02lld", hours, minutes, seconds)
      }
      return String(format: "%02lld:%02lld", minutes, seconds)
    }
  }

  #if os(iOS)
    public struct LineWisePhoneRootView: View {
      @StateObject private var model: LineWiseAppViewModel
      @State private var routeLabel = ""

      public init(model: @autoclosure @escaping () -> LineWiseAppViewModel) {
        _model = StateObject(wrappedValue: model())
      }

      public var body: some View {
        NavigationView {
          List {
            Section("Current visit") {
              if model.projection.activeVisit == nil {
                Button("Start gym visit") { model.startVisit(source: .iPhone) }
              } else {
                Text(model.projection.currentRouteCard?.label ?? "No route selected")
                if let elapsed = model.visitElapsedText {
                  HStack {
                    Text("Elapsed")
                    Spacer()
                    Text(elapsed).monospacedDigit()
                  }
                }
                Button("Record Attempt") { model.recordAttempt(source: .iPhone) }
                  .buttonStyle(.borderedProminent)
                Button("Mark latest Send") { model.markLatestSend(source: .iPhone) }
                  .disabled(model.projection.currentRouteAttempts.isEmpty)
                Button(model.projection.activeRest == nil ? "Start rest" : "Stop rest") {
                  model.toggleRest()
                }
                if let restElapsed = model.restElapsedText {
                  HStack {
                    Text("Rest")
                    Spacer()
                    Text(restElapsed).monospacedDigit()
                  }
                }
                Button("Undo") { model.undoLatest(source: .iPhone) }
                Button("End visit", role: .destructive) { model.endVisit(source: .iPhone) }
              }
            }
            Section("Route memory") {
              TextField("Route label", text: $routeLabel)
              Button("Create and select route") {
                let trimmed = routeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                model.createRoute(label: trimmed)
                routeLabel = ""
              }
              ForEach(model.projection.routeCards, id: \.id.rawValue) { route in
                Button(route.label) { model.handle(.selectRoute(route.id)) }
              }
            }
            Section("Review Inbox") {
              HStack {
                Text("Needs attention")
                Spacer()
                Text("\(model.projection.pendingReviewCount)")
              }
              HStack {
                Text("Conflicts")
                Spacer()
                Text("\(model.projection.reconciliationCount)")
              }
            }
            Section("Device") {
              HStack {
                Text("Sync")
                Spacer()
                Text(model.syncStatusText)
              }
              if let error = model.syncStatus.lastError {
                Text(error).font(.caption).foregroundColor(.orange)
              }
            }
          }
          .navigationTitle("LineWise")
        }
        .onAppear { model.activate() }
      }
    }
  #endif

  #if os(watchOS)
    public struct LineWiseWatchCaptureView: View {
      @StateObject private var model: LineWiseAppViewModel

      public init(model: @autoclosure @escaping () -> LineWiseAppViewModel) {
        _model = StateObject(wrappedValue: model())
      }

      public var body: some View {
        ScrollView {
          VStack(spacing: 8) {
            Text(model.watchProjection.currentRouteLabel ?? "Choose route")
              .font(.headline)
              .multilineTextAlignment(.center)
              .accessibilityLabel("Current route")
              .accessibilityValue(model.watchProjection.currentRouteLabel ?? "None selected")

            if !model.projection.selectableRouteCards.isEmpty {
              Picker(
                "Route",
                selection: Binding(
                  get: { model.projection.currentRouteCard?.id.rawValue ?? "" },
                  set: { rawValue in
                    guard !rawValue.isEmpty else { return }
                    model.handle(.selectRoute(RouteCardID(rawValue)))
                  }
                )
              ) {
                Text("Choose").tag("")
                ForEach(model.projection.selectableRouteCards, id: \.id.rawValue) { route in
                  Text(route.label).tag(route.id.rawValue)
                }
              }
            }

            Text("\(model.watchProjection.attemptCount) attempts")
              .foregroundStyle(.secondary)
              .accessibilityLabel("Attempt count")
              .accessibilityValue("\(model.watchProjection.attemptCount)")

            if let elapsed = model.visitElapsedText {
              Text(elapsed)
                .font(.title3.monospacedDigit())
                .accessibilityLabel("Visit elapsed time")
                .accessibilityValue(elapsed)
            }

            if model.watchProjection.visitIsOpen {
              Button("Attempt") { model.recordAttempt(source: .watch) }
                .buttonStyle(.borderedProminent)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .accessibilityLabel("Record attempt")
                .accessibilityHint("Saves an attempt immediately on this Watch")

              if model.watchProjection.canMarkSend {
                Button("Send") { model.markLatestSend(source: .watch) }
                  .frame(maxWidth: .infinity, minHeight: 44)
                  .accessibilityLabel("Mark latest attempt sent")
              }

              Button(model.watchProjection.isResting ? "Stop Rest" : "Start Rest") {
                model.toggleRest()
              }
              .frame(maxWidth: .infinity, minHeight: 44)
              .accessibilityHint("Rest timing is saved locally")

              if let restElapsed = model.restElapsedText {
                Text("Rest \(restElapsed)")
                  .monospacedDigit()
                  .accessibilityLabel("Rest elapsed time")
                  .accessibilityValue(restElapsed)
              }

              if model.watchProjection.canUndo {
                Button("Undo") { model.undoLatest(source: .watch) }
                  .frame(maxWidth: .infinity, minHeight: 44)
                  .accessibilityLabel("Undo latest action")
              }

              Button("End Visit", role: .destructive) { model.endVisit(source: .watch) }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityLabel("End visit")
            } else {
              if model.healthRecordingPreference == .manualOnly {
                Text(model.healthRecordingPurposeMessage)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                Button("Enable Health Recording") { model.enableHealthRecording() }
                  .frame(maxWidth: .infinity, minHeight: 44)
                  .accessibilityHint("Requests Health access only after this explicit choice")
              } else {
                Label("Health Recording selected", systemImage: "heart.circle")
                  .font(.caption2)
                  .accessibilityLabel("Health Recording selected for future Visits")
                Text(model.healthRecordingStatusText)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              Button("Start Visit") { model.startVisit(source: .watch) }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 50)
                .accessibilityHint("Starts the local visit before optional workout recording")
            }

            Text(model.syncStatusText)
              .font(.caption2)
              .foregroundStyle(model.syncStatus.pendingCount == 0 ? .secondary : .orange)
              .accessibilityLabel("Device sync status")
              .accessibilityValue(model.syncStatusText)

            if model.isLowPowerMode {
              Text("Low power: refresh reduced")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Low power mode. Recording remains available.")
            }
          }
          .padding(.horizontal, 4)
        }
        .onAppear { model.activate() }
      }
    }
  #endif

  public struct LineWiseStartupFailureView: View {
    private let reason: String

    public init(reason: String) {
      self.reason = reason
    }

    public var body: some View {
      VStack(spacing: 12) {
        Image(systemName: "externaldrive.badge.exclamationmark")
          .font(.largeTitle)
        Text("Durable storage unavailable")
          .font(.headline)
          .multilineTextAlignment(.center)
        Text(
          "LineWise did not start an in-memory replacement, so no climbing record can be lost silently."
        )
        .font(.caption)
        .multilineTextAlignment(.center)
        Text(reason)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding()
      .accessibilityElement(children: .combine)
    }
  }
#endif
