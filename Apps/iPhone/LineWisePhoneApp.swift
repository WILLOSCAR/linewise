#if os(iOS)
  import Foundation
  import LineWiseAIAdapters
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
        mediaLibrary: FoundationRouteMediaLibrary,
        routeReadProvider: HTTPRouteMediaReadProvider?
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
        let transport = try WatchConnectivityPayloadTransport(
          inboxStore: FoundationFileDevicePayloadInboxStore(
            fileURL: LineWiseAppBootstrap.devicePayloadInboxURL(
              in: storageDirectory,
              role: .iPhone
            )
          )
        )
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
        let routeReadProvider = Self.configuredRouteMediaReadProvider(
          dataLoader: mediaLibrary
        )
        startup = .ready(
          experience: LineWiseExperienceViewModel(coordinator: experienceCoordinator),
          sync: LineWiseAppViewModel(runtime: runtime),
          mediaLibrary: mediaLibrary,
          routeReadProvider: routeReadProvider
        )
      } catch {
        startup = .degraded(String(describing: error))
      }
    }

    var body: some Scene {
      WindowGroup {
        switch startup {
        case .ready(let experience, let sync, let mediaLibrary, let routeReadProvider):
          LineWisePhoneExperienceHostView(
            experienceModel: experience,
            syncModel: sync,
            routeMediaLibrary: mediaLibrary,
            routeMediaReadProvider: routeReadProvider
          )
        case .degraded(let reason):
          LineWiseStartupFailureView(reason: reason)
        }
      }
    }

    private static func configuredRouteMediaReadProvider(
      dataLoader: FoundationRouteMediaLibrary
    ) -> HTTPRouteMediaReadProvider? {
      guard
        let endpointValue = Bundle.main.object(
          forInfoDictionaryKey: "LineWiseRouteReadEndpoint"
        ) as? String,
        !endpointValue.isEmpty,
        !endpointValue.hasPrefix("$("),
        let endpoint = URL(string: endpointValue)
      else { return nil }

      let providerIdentifier = configuredValue(
        forInfoDictionaryKey: "LineWiseRouteReadProvider",
        fallback: "configured-route-read"
      )
      let providerVersion = configuredValue(
        forInfoDictionaryKey: "LineWiseRouteReadProviderVersion",
        fallback: "1"
      )
      let bearerToken = BearerTokenSource {
        ProcessInfo.processInfo.environment["LINEWISE_ROUTE_READ_BEARER_TOKEN"]
      }
      guard
        let configuration = try? RemoteModelEndpointConfiguration(
          endpoint: endpoint,
          providerIdentifier: providerIdentifier,
          providerVersion: providerVersion,
          bearerToken: bearerToken
        )
      else { return nil }
      return try? HTTPRouteMediaReadProvider(
        configuration: configuration,
        dataLoader: dataLoader
      )
    }

    private static func configuredValue(
      forInfoDictionaryKey key: String,
      fallback: String
    ) -> String {
      guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
        !value.isEmpty,
        !value.hasPrefix("$(")
      else { return fallback }
      return value
    }
  }
#endif
