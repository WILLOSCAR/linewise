#if os(watchOS)
  import LineWiseAppleAdapters
  import LineWiseApplication
  import SwiftUI

  @MainActor
  @main
  struct LineWiseWatchApp: App {
    private enum Startup {
      case ready(LineWiseAppViewModel)
      case degraded(String)
    }

    private let startup: Startup

    init() {
      do {
        let storageDirectory = try LineWiseAppBootstrap.defaultStorageDirectoryURL()
        let persistent = try LineWiseAppBootstrap.makePersistentRuntime(
          storageDirectoryURL: storageDirectory,
          role: .watch
        )
        let experience = try PersistentLineWiseExperienceCoordinator(
          store: FoundationFileExperienceArchiveStore(
            fileURL: LineWiseAppBootstrap.experienceArchiveURL(
              in: storageDirectory,
              role: .watch
            )
          ),
          appCoordinator: persistent.coordinator
        )
        let transport = WatchConnectivityPayloadTransport()
        let runtime = LineWiseAppleRuntime(
          deviceID: persistent.deviceID,
          experienceCoordinator: experience,
          syncService: LineWiseDeviceSyncService(
            bridge: DeviceEnvelopeBridge(transport: transport)
          ),
          workoutRecorder: HealthKitWorkoutRecorder()
        )
        startup = .ready(LineWiseAppViewModel(runtime: runtime))
      } catch {
        startup = .degraded(String(describing: error))
      }
    }

    var body: some Scene {
      WindowGroup {
        switch startup {
        case .ready(let model):
          LineWiseWatchCaptureView(model: model)
        case .degraded(let reason):
          LineWiseStartupFailureView(reason: reason)
        }
      }
    }
  }
#endif
