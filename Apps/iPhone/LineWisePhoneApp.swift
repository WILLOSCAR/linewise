#if os(iOS)
  import LineWiseAppleAdapters
  import LineWiseApplication
  import SwiftUI

  @MainActor
  @main
  struct LineWisePhoneApp: App {
    private enum Startup {
      case ready(
        experience: LineWiseExperienceViewModel,
        sync: LineWiseAppViewModel,
        mediaLibrary: FoundationRouteMediaLibrary
      )
      case degraded(String)
    }

    private let startup: Startup

    init() {
      do {
        let storageDirectory = try LineWiseAppBootstrap.defaultStorageDirectoryURL()
        let persistent = try LineWiseAppBootstrap.makePersistentRuntime(
          storageDirectoryURL: storageDirectory,
          role: .iPhone
        )
        let experienceCoordinator = try PersistentLineWiseExperienceCoordinator(
          store: FoundationFileExperienceArchiveStore(
            fileURL: LineWiseAppBootstrap.experienceArchiveURL(
              in: storageDirectory,
              role: .iPhone
            )
          ),
          appCoordinator: persistent.coordinator,
          microDrillCatalog: .lineWiseEditorialV0
        )
        let transport = WatchConnectivityPayloadTransport()
        let runtime = LineWiseAppleRuntime(
          persistentRuntime: persistent,
          syncService: LineWiseDeviceSyncService(
            bridge: DeviceEnvelopeBridge(transport: transport)
          ),
          workoutRecorder: NoHealthKitWorkoutRecorder()
        )
        let mediaLibrary = try FoundationRouteMediaLibrary(
          rootDirectory: storageDirectory.appendingPathComponent(
            "route-media",
            isDirectory: true
          )
        )
        startup = .ready(
          experience: LineWiseExperienceViewModel(coordinator: experienceCoordinator),
          sync: LineWiseAppViewModel(runtime: runtime),
          mediaLibrary: mediaLibrary
        )
      } catch {
        startup = .degraded(String(describing: error))
      }
    }

    var body: some Scene {
      WindowGroup {
        switch startup {
        case .ready(let experience, let sync, let mediaLibrary):
          LineWisePhoneExperienceHostView(
            experienceModel: experience,
            syncModel: sync,
            routeMediaLibrary: mediaLibrary
          )
        case .degraded(let reason):
          LineWiseStartupFailureView(reason: reason)
        }
      }
    }
  }
#endif
