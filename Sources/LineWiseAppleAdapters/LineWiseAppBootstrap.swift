import Foundation
import LineWiseApplication
import LineWiseDomain

public enum LineWiseAppBootstrapError: Error, Equatable, Sendable, CustomStringConvertible {
  case applicationSupportDirectoryUnavailable
  case storageDirectoryUnavailable(path: String, reason: String)
  case corruptedDeviceIdentity(path: String)

  public var description: String {
    switch self {
    case .applicationSupportDirectoryUnavailable:
      "LineWise could not locate the application support directory"
    case .storageDirectoryUnavailable(let path, let reason):
      "LineWise could not prepare durable storage at \(path): \(reason)"
    case .corruptedDeviceIdentity(let path):
      "LineWise found an invalid durable device identity at \(path)"
    }
  }
}

public enum LineWiseDeviceRole: String, Equatable, Codable, Sendable {
  case iPhone = "iphone"
  case watch
}

public struct LineWiseAppRuntime {
  public let deviceID: DeviceID
  public var coordinator: LineWiseAppCoordinator

  public init(deviceID: DeviceID, coordinator: LineWiseAppCoordinator) {
    self.deviceID = deviceID
    self.coordinator = coordinator
  }
}

public enum LineWiseAppBootstrap {
  public static func defaultStorageDirectoryURL(
    applicationIdentifier: String = "LineWise"
  ) throws -> URL {
    guard
      let root = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else {
      throw LineWiseAppBootstrapError.applicationSupportDirectoryUnavailable
    }
    return root.appendingPathComponent(applicationIdentifier, isDirectory: true)
  }

  public static func visitJournalURL(in storageDirectoryURL: URL) -> URL {
    storageDirectoryURL.appendingPathComponent("visit-events-v1.json", isDirectory: false)
  }

  public static func deviceIdentityURL(
    in storageDirectoryURL: URL,
    role: LineWiseDeviceRole
  ) -> URL {
    storageDirectoryURL.appendingPathComponent(
      "device-identity-\(role.rawValue).txt",
      isDirectory: false
    )
  }

  public static func experienceArchiveURL(
    in storageDirectoryURL: URL,
    role: LineWiseDeviceRole
  ) -> URL {
    storageDirectoryURL.appendingPathComponent(
      "experience-\(role.rawValue)-v1.json",
      isDirectory: false
    )
  }

  public static func makePersistentCoordinator(
    storageDirectoryURL: URL,
    deviceID: DeviceID
  ) throws -> LineWiseAppCoordinator {
    do {
      try FileManager.default.createDirectory(
        at: storageDirectoryURL,
        withIntermediateDirectories: true
      )
    } catch {
      throw LineWiseAppBootstrapError.storageDirectoryUnavailable(
        path: storageDirectoryURL.path,
        reason: error.localizedDescription
      )
    }

    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var mutableStorageURL = storageDirectoryURL
    try? mutableStorageURL.setResourceValues(resourceValues)

    let store = FoundationFileVisitEventStore(
      fileURL: visitJournalURL(in: storageDirectoryURL)
    )
    let repository = try VisitRepository(store: store, localDeviceID: deviceID)
    return LineWiseAppCoordinator(repository: repository)
  }

  public static func makePersistentRuntime(
    storageDirectoryURL: URL,
    role: LineWiseDeviceRole
  ) throws -> LineWiseAppRuntime {
    try prepareStorageDirectory(storageDirectoryURL)
    let deviceID = try loadOrCreateDeviceID(in: storageDirectoryURL, role: role)
    let journalURL = storageDirectoryURL.appendingPathComponent(
      "visit-events-\(role.rawValue)-v1.json",
      isDirectory: false
    )
    let repository = try VisitRepository(
      store: FoundationFileVisitEventStore(fileURL: journalURL),
      localDeviceID: deviceID
    )
    return LineWiseAppRuntime(
      deviceID: deviceID,
      coordinator: LineWiseAppCoordinator(repository: repository)
    )
  }

  public static func makePersistentRuntime(
    role: LineWiseDeviceRole,
    applicationIdentifier: String = "LineWise"
  ) throws -> LineWiseAppRuntime {
    try makePersistentRuntime(
      storageDirectoryURL: defaultStorageDirectoryURL(
        applicationIdentifier: applicationIdentifier
      ),
      role: role
    )
  }

  public static func makePersistentCoordinator(
    deviceID: DeviceID,
    applicationIdentifier: String = "LineWise"
  ) throws -> LineWiseAppCoordinator {
    try makePersistentCoordinator(
      storageDirectoryURL: defaultStorageDirectoryURL(
        applicationIdentifier: applicationIdentifier
      ),
      deviceID: deviceID
    )
  }

  private static func prepareStorageDirectory(_ storageDirectoryURL: URL) throws {
    do {
      try FileManager.default.createDirectory(
        at: storageDirectoryURL,
        withIntermediateDirectories: true
      )
    } catch {
      throw LineWiseAppBootstrapError.storageDirectoryUnavailable(
        path: storageDirectoryURL.path,
        reason: error.localizedDescription
      )
    }
  }

  private static func loadOrCreateDeviceID(
    in storageDirectoryURL: URL,
    role: LineWiseDeviceRole
  ) throws -> DeviceID {
    let url = deviceIdentityURL(in: storageDirectoryURL, role: role)
    if FileManager.default.fileExists(atPath: url.path) {
      let rawValue: String
      do {
        rawValue = try String(contentsOf: url, encoding: .utf8)
          .trimmingCharacters(in: .whitespacesAndNewlines)
      } catch {
        throw LineWiseAppBootstrapError.storageDirectoryUnavailable(
          path: url.path,
          reason: error.localizedDescription
        )
      }
      let expectedPrefix = "\(role.rawValue)-"
      guard rawValue.hasPrefix(expectedPrefix),
        UUID(uuidString: String(rawValue.dropFirst(expectedPrefix.count))) != nil
      else {
        throw LineWiseAppBootstrapError.corruptedDeviceIdentity(path: url.path)
      }
      return DeviceID(rawValue)
    }

    let deviceID = DeviceID("\(role.rawValue)-\(UUID().uuidString.lowercased())")
    do {
      try Data(deviceID.rawValue.utf8).write(to: url, options: .atomic)
    } catch {
      throw LineWiseAppBootstrapError.storageDirectoryUnavailable(
        path: url.path,
        reason: error.localizedDescription
      )
    }
    return deviceID
  }
}
