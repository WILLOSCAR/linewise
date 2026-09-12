import CryptoKit
import Foundation
import ImageIO
import LineWiseDomain

public struct RouteMediaImportRequest: Sendable {
  public let assetID: RouteMediaAssetID
  public let routeCardID: RouteCardID
  public let data: Data
  public let kind: RouteMediaKind
  public let mimeType: String
  public let purpose: MediaPurpose
  public let consent: MediaConsent
  public let capturedAt: Instant
  public let captureDeviceClass: MediaCaptureDeviceClass
  public let captureMethod: MediaCaptureMethod
  public let retention: MediaRetentionPolicy

  public init(
    assetID: RouteMediaAssetID,
    routeCardID: RouteCardID,
    data: Data,
    kind: RouteMediaKind,
    mimeType: String,
    purpose: MediaPurpose,
    consent: MediaConsent,
    capturedAt: Instant,
    captureDeviceClass: MediaCaptureDeviceClass,
    captureMethod: MediaCaptureMethod,
    retention: MediaRetentionPolicy
  ) {
    self.assetID = assetID
    self.routeCardID = routeCardID
    self.data = data
    self.kind = kind
    self.mimeType = mimeType
    self.purpose = purpose
    self.consent = consent
    self.capturedAt = capturedAt
    self.captureDeviceClass = captureDeviceClass
    self.captureMethod = captureMethod
    self.retention = retention
  }
}

public enum RouteMediaLibraryError: Error, Equatable, Sendable {
  case invalidRootDirectory
  case emptyMedia
  case invalidMIMEType(String)
  case storageConsentRequired
  case modelProcessingConsentRequiresSeparateAction
  case assetNotFound(RouteMediaAssetID)
  case unregisteredReference
  case unsafeLocalReference
  case mediaBytesMissing(RouteMediaAssetID)
  case mediaIntegrityMismatch(RouteMediaAssetID)
  case corruptManifest(String)
  case unsupportedSchemaVersion(Int)
  case ioFailure(operation: String, reason: String)
}

extension RouteMediaLibraryError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidRootDirectory:
      "The route-media library requires a local app directory."
    case .emptyMedia:
      "Empty media cannot be imported."
    case .invalidMIMEType(let value):
      "The route-media MIME type is invalid: \(value)."
    case .storageConsentRequired:
      "Explicit local-storage consent is required before import."
    case .modelProcessingConsentRequiresSeparateAction:
      "Model-processing consent must be granted after local import as a separate action."
    case .assetNotFound(let assetID):
      "Route media \(assetID.rawValue) is not registered."
    case .unregisteredReference:
      "The local media reference is not registered in this library."
    case .unsafeLocalReference:
      "The local media reference escapes the app-controlled library."
    case .mediaBytesMissing(let assetID):
      "The bytes for route media \(assetID.rawValue) are missing."
    case .mediaIntegrityMismatch(let assetID):
      "The bytes for route media \(assetID.rawValue) no longer match the manifest."
    case .corruptManifest(let reason):
      "The route-media manifest is corrupt: \(reason)."
    case .unsupportedSchemaVersion(let version):
      "Route-media manifest schema \(version) is not supported."
    case .ioFailure(let operation, let reason):
      "Could not \(operation): \(reason)."
    }
  }
}

private struct StoredRouteMediaManifest: Codable {
  static let currentSchemaVersion = 1

  let schemaVersion: Int
  let personalDataset: PersonalDataset
  let modelProcessingConsentRecordedAt: [String: Instant]

  init(
    personalDataset: PersonalDataset,
    modelProcessingConsentRecordedAt: [String: Instant]
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.personalDataset = personalDataset
    self.modelProcessingConsentRecordedAt = modelProcessingConsentRecordedAt
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case personalDataset
    case modelProcessingConsentRecordedAt
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    personalDataset = try container.decode(PersonalDataset.self, forKey: .personalDataset)
    modelProcessingConsentRecordedAt =
      try container.decodeIfPresent(
        [String: Instant].self,
        forKey: .modelProcessingConsentRecordedAt
      ) ?? [:]
  }
}

private struct StoredRouteMediaManifestHeader: Decodable {
  let schemaVersion: Int
}

public actor FoundationRouteMediaLibrary: RouteMediaDataLoader {
  public static let manifestFileName = "PersonalDataset.json"

  private let rootDirectory: URL
  private let mediaDirectory: URL
  private let sourceDirectory: URL
  private let derivedDirectory: URL
  private let stagingDirectory: URL
  private let manifestURL: URL
  private var dataset: PersonalDataset
  private var modelProcessingConsentRecordedAt: [String: Instant]

  public init(rootDirectory: URL) throws {
    guard rootDirectory.isFileURL else {
      throw RouteMediaLibraryError.invalidRootDirectory
    }

    let canonicalRoot = rootDirectory.standardizedFileURL
    self.rootDirectory = canonicalRoot
    mediaDirectory = canonicalRoot.appendingPathComponent("media", isDirectory: true)
    sourceDirectory = mediaDirectory.appendingPathComponent("source", isDirectory: true)
    derivedDirectory = mediaDirectory.appendingPathComponent("derived", isDirectory: true)
    stagingDirectory = canonicalRoot.appendingPathComponent("staging", isDirectory: true)
    manifestURL = canonicalRoot.appendingPathComponent(Self.manifestFileName, isDirectory: false)

    do {
      try FileManager.default.createDirectory(
        at: sourceDirectory,
        withIntermediateDirectories: true
      )
      try FileManager.default.createDirectory(
        at: derivedDirectory,
        withIntermediateDirectories: true
      )
      try FileManager.default.createDirectory(
        at: stagingDirectory,
        withIntermediateDirectories: true
      )
      Self.applyPlatformProtection(to: canonicalRoot)
    } catch {
      throw RouteMediaLibraryError.ioFailure(
        operation: "prepare the app-controlled media directory",
        reason: error.localizedDescription
      )
    }

    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
      dataset = PersonalDataset()
      modelProcessingConsentRecordedAt = [:]
      Self.reclaimStagedMediaBytes(in: stagingDirectory)
      return
    }

    do {
      let data = try Data(contentsOf: manifestURL)
      let decoder = JSONDecoder()
      let header = try decoder.decode(StoredRouteMediaManifestHeader.self, from: data)
      guard header.schemaVersion == StoredRouteMediaManifest.currentSchemaVersion else {
        throw RouteMediaLibraryError.unsupportedSchemaVersion(header.schemaVersion)
      }
      let stored = try decoder.decode(StoredRouteMediaManifest.self, from: data)
      dataset = stored.personalDataset
      modelProcessingConsentRecordedAt = stored.modelProcessingConsentRecordedAt
    } catch let error as RouteMediaLibraryError {
      throw error
    } catch {
      throw RouteMediaLibraryError.corruptManifest(error.localizedDescription)
    }
    Self.reclaimStagedMediaBytes(in: stagingDirectory)
  }

  public func assets() -> [RouteMediaAsset] {
    dataset.activeAssets.map(effectiveAsset)
  }

  public func asset(id: RouteMediaAssetID) -> RouteMediaAsset? {
    dataset.asset(id: id).map(effectiveAsset)
  }

  public func importSource(_ request: RouteMediaImportRequest) throws -> RouteMediaAsset {
    try importMedia(request, origin: .source, directory: sourceDirectory)
  }

  public func importDerived(
    _ request: RouteMediaImportRequest,
    sourceAssetIDs: [RouteMediaAssetID],
    transform: MediaDerivation
  ) throws -> RouteMediaAsset {
    try importMedia(
      request,
      origin: .derived(sourceAssetIDs: sourceAssetIDs, transform: transform),
      directory: derivedDirectory
    )
  }

  public func grantModelProcessingConsent(
    for assetID: RouteMediaAssetID,
    at recordedAt: Instant
  ) throws -> RouteMediaAsset {
    guard let storedAsset = dataset.asset(id: assetID) else {
      throw RouteMediaLibraryError.assetNotFound(assetID)
    }
    var candidateConsent = modelProcessingConsentRecordedAt
    candidateConsent[assetID.rawValue] = recordedAt
    try persist(dataset, modelProcessingConsent: candidateConsent)
    modelProcessingConsentRecordedAt = candidateConsent
    return Self.replacingConsent(
      of: storedAsset,
      with: MediaConsent(
        status: .granted,
        scope: .explicitModelProcessing,
        recordedAt: recordedAt
      )
    )
  }

  @discardableResult
  public func revokeConsentAndDelete(
    for assetID: RouteMediaAssetID,
    at deletedAt: Instant
  ) throws -> MediaDeletionTombstone {
    try deleteAsset(assetID, at: deletedAt, reason: .consentRevoked)
  }

  @discardableResult
  public func enforceRetention(at now: Instant) throws -> [MediaDeletionTombstone] {
    let activeAssets = dataset.activeAssets
    let sourceIDsStillUsedByDerivedAssets = Set(activeAssets.flatMap(\.sourceAssetIDs))
    // "Derived assets removed" must mean derived assets once existed and are
    // now gone. A source whose derivation step has not run yet has no derived
    // assets either, and deleting it would destroy the user's only copy.
    let sourceIDsOfRemovedDerivedAssets = Set(
      dataset.deletionTombstones.flatMap(\.sourceAssetIDs)
    )
    let assetIDsToDelete = activeAssets.compactMap { asset -> RouteMediaAssetID? in
      switch asset.retention {
      case .keepUntilUserDeletes:
        nil
      case .expiresAt(let expiration):
        expiration <= now ? asset.id : nil
      case .deleteAfterDerivedAssetsRemoved:
        asset.isSource
          && sourceIDsOfRemovedDerivedAssets.contains(asset.id)
          && !sourceIDsStillUsedByDerivedAssets.contains(asset.id) ? asset.id : nil
      }
    }

    // One unusable entry must not shield every other expired asset from its
    // retention deadline, so the sweep completes before reporting the failure.
    var tombstones: [MediaDeletionTombstone] = []
    var firstFailure: (any Error)?
    for assetID in assetIDsToDelete {
      do {
        tombstones.append(try deleteAsset(assetID, at: now, reason: .retentionExpired))
      } catch {
        firstFailure = firstFailure ?? error
      }
    }
    if let firstFailure { throw firstFailure }
    return tombstones
  }

  @discardableResult
  public func deleteAsset(
    _ assetID: RouteMediaAssetID,
    at deletedAt: Instant,
    reason: MediaDeletionReason
  ) throws -> MediaDeletionTombstone {
    guard let registeredAsset = dataset.asset(id: assetID) else {
      throw RouteMediaLibraryError.assetNotFound(assetID)
    }
    let fileURL = try resolvedURL(for: registeredAsset.localReference)

    var candidate = dataset
    let tombstone = try candidate.deleteAsset(assetID, at: deletedAt, reason: reason)
    var candidateConsent = modelProcessingConsentRecordedAt
    candidateConsent.removeValue(forKey: assetID.rawValue)

    // Bytes that are already absent are the desired end state, not a reason to
    // abort. Refusing here would leave the asset registered with its model
    // processing consent intact, so a revocation the user asked for would
    // silently never take effect.
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      try persist(candidate, modelProcessingConsent: candidateConsent)
      dataset = candidate
      modelProcessingConsentRecordedAt = candidateConsent
      return tombstone
    }

    let stagedDeletionURL = stagingDirectory.appendingPathComponent(
      "delete-\(UUID().uuidString).stage",
      isDirectory: false
    )
    do {
      try FileManager.default.moveItem(at: fileURL, to: stagedDeletionURL)
      try persist(candidate, modelProcessingConsent: candidateConsent)
      do {
        try FileManager.default.removeItem(at: stagedDeletionURL)
      } catch {
        try? persist(dataset, modelProcessingConsent: modelProcessingConsentRecordedAt)
        try? FileManager.default.moveItem(at: stagedDeletionURL, to: fileURL)
        throw error
      }
      dataset = candidate
      modelProcessingConsentRecordedAt = candidateConsent
      return tombstone
    } catch {
      if FileManager.default.fileExists(atPath: stagedDeletionURL.path),
        !FileManager.default.fileExists(atPath: fileURL.path)
      {
        try? FileManager.default.moveItem(at: stagedDeletionURL, to: fileURL)
      }
      if let libraryError = error as? RouteMediaLibraryError { throw libraryError }
      throw RouteMediaLibraryError.ioFailure(
        operation: "atomically delete route media",
        reason: error.localizedDescription
      )
    }
  }

  public func exportManifest(createdAt: Instant) -> DatasetExportManifest {
    let stored = dataset.exportManifest(createdAt: createdAt)
    return DatasetExportManifest(
      schemaVersion: stored.schemaVersion,
      createdAt: stored.createdAt,
      activeAssets: stored.activeAssets.map(effectiveAsset),
      annotationHistory: stored.annotationHistory,
      correctionHistory: stored.correctionHistory,
      deletionTombstones: stored.deletionTombstones
    )
  }

  public func exportManifestData(createdAt: Instant) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(exportManifest(createdAt: createdAt))
  }

  public func loadData(for reference: LocalMediaReference) async throws -> Data {
    guard
      let registeredAsset = dataset.activeAssets.first(where: {
        $0.localReference == reference
      })
    else {
      throw RouteMediaLibraryError.unregisteredReference
    }
    let fileURL = try resolvedURL(for: reference)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw RouteMediaLibraryError.mediaBytesMissing(registeredAsset.id)
    }
    let data: Data
    do {
      data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
    } catch {
      throw RouteMediaLibraryError.ioFailure(
        operation: "read registered route media",
        reason: error.localizedDescription
      )
    }
    guard Int64(data.count) == registeredAsset.byteCount,
      Self.sha256Hex(data) == registeredAsset.contentDigest.hexValue.lowercased()
    else {
      throw RouteMediaLibraryError.mediaIntegrityMismatch(registeredAsset.id)
    }
    return data
  }

  private func importMedia(
    _ request: RouteMediaImportRequest,
    origin: MediaAssetOrigin,
    directory: URL
  ) throws -> RouteMediaAsset {
    guard !request.data.isEmpty else { throw RouteMediaLibraryError.emptyMedia }
    let normalizedMIMEType = request.mimeType
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    guard normalizedMIMEType.contains("/"), !normalizedMIMEType.hasPrefix("/") else {
      throw RouteMediaLibraryError.invalidMIMEType(request.mimeType)
    }
    guard request.consent.status == .granted else {
      throw RouteMediaLibraryError.storageConsentRequired
    }
    guard request.consent.scope != .explicitModelProcessing else {
      throw RouteMediaLibraryError.modelProcessingConsentRequiresSeparateAction
    }

    let fileIdentifier = UUID().uuidString.lowercased()
    let fileName = "\(fileIdentifier).\(Self.fileExtension(for: normalizedMIMEType))"
    let destinationURL = directory.appendingPathComponent(fileName, isDirectory: false)
    let relativePath = destinationURL.path.replacingOccurrences(
      of: rootDirectory.path + "/",
      with: ""
    )
    let asset = RouteMediaAsset(
      id: request.assetID,
      routeCardID: request.routeCardID,
      localReference: LocalMediaReference(
        fileIdentifier: fileIdentifier,
        sandboxRelativePath: relativePath
      ),
      kind: request.kind,
      mimeType: normalizedMIMEType,
      byteCount: Int64(request.data.count),
      dimensions: Self.inspectDimensions(of: request.data),
      contentDigest: MediaContentDigest(
        algorithm: .sha256,
        hexValue: Self.sha256Hex(request.data)
      ),
      purpose: request.purpose,
      consent: request.consent,
      captureProvenance: MediaCaptureProvenance(
        capturedAt: request.capturedAt,
        deviceClass: request.captureDeviceClass,
        method: request.captureMethod,
        importedByUser: request.captureMethod != .derivedLocally
      ),
      origin: origin,
      quality: .unreviewed,
      retention: request.retention
    )

    var candidate = dataset
    try candidate.add(asset)

    let stagingURL =
      stagingDirectory
      .appendingPathComponent("\(UUID().uuidString).stage", isDirectory: false)
    do {
      try request.data.write(to: stagingURL, options: [.atomic])
      try FileManager.default.moveItem(at: stagingURL, to: destinationURL)
      Self.applyPlatformProtection(to: destinationURL)
      try persist(candidate, modelProcessingConsent: modelProcessingConsentRecordedAt)
      dataset = candidate
      return asset
    } catch {
      try? FileManager.default.removeItem(at: stagingURL)
      try? FileManager.default.removeItem(at: destinationURL)
      if let libraryError = error as? RouteMediaLibraryError { throw libraryError }
      if let domainError = error as? PersonalDatasetError { throw domainError }
      throw RouteMediaLibraryError.ioFailure(
        operation: "atomically import route media",
        reason: error.localizedDescription
      )
    }
  }

  private func persist(
    _ candidate: PersonalDataset,
    modelProcessingConsent: [String: Instant]
  ) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      let data = try encoder.encode(
        StoredRouteMediaManifest(
          personalDataset: candidate,
          modelProcessingConsentRecordedAt: modelProcessingConsent
        )
      )
      try data.write(to: manifestURL, options: [.atomic])
      Self.applyPlatformProtection(to: manifestURL)
    } catch {
      throw RouteMediaLibraryError.ioFailure(
        operation: "atomically persist the PersonalDataset manifest",
        reason: error.localizedDescription
      )
    }
  }

  private func resolvedURL(for reference: LocalMediaReference) throws -> URL {
    let path = reference.sandboxRelativePath
    guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
      throw RouteMediaLibraryError.unsafeLocalReference
    }
    let candidate = rootDirectory.appendingPathComponent(path, isDirectory: false)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let canonicalRoot = rootDirectory.resolvingSymlinksInPath().path
    guard candidate.path.hasPrefix(canonicalRoot + "/") else {
      throw RouteMediaLibraryError.unsafeLocalReference
    }
    guard candidate.deletingPathExtension().lastPathComponent == reference.fileIdentifier else {
      throw RouteMediaLibraryError.unsafeLocalReference
    }
    return candidate
  }

  private func effectiveAsset(_ storedAsset: RouteMediaAsset) -> RouteMediaAsset {
    guard let recordedAt = modelProcessingConsentRecordedAt[storedAsset.id.rawValue] else {
      return storedAsset
    }
    return Self.replacingConsent(
      of: storedAsset,
      with: MediaConsent(
        status: .granted,
        scope: .explicitModelProcessing,
        recordedAt: recordedAt
      )
    )
  }

  private static func replacingConsent(
    of asset: RouteMediaAsset,
    with consent: MediaConsent
  ) -> RouteMediaAsset {
    RouteMediaAsset(
      id: asset.id,
      routeCardID: asset.routeCardID,
      localReference: asset.localReference,
      kind: asset.kind,
      mimeType: asset.mimeType,
      byteCount: asset.byteCount,
      dimensions: asset.dimensions,
      contentDigest: asset.contentDigest,
      purpose: asset.purpose,
      consent: consent,
      captureProvenance: asset.captureProvenance,
      origin: asset.origin,
      quality: asset.quality,
      retention: asset.retention
    )
  }

  private static func inspectDimensions(of data: Data) -> MediaDimensions {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
      let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
    else {
      return MediaDimensions(pixelWidth: 0, pixelHeight: 0)
    }
    return MediaDimensions(pixelWidth: width.intValue, pixelHeight: height.intValue)
  }

  private static func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func fileExtension(for mimeType: String) -> String {
    switch mimeType {
    case "image/jpeg": "jpg"
    case "image/png": "png"
    case "image/heic", "image/heif": "heic"
    case "video/quicktime": "mov"
    case "video/mp4": "mp4"
    default: "bin"
    }
  }

  /// Reclaims media bytes left in the staging directory by an import or delete
  /// that was interrupted between staging the bytes and committing the
  /// manifest. Staging is only ever a transient step of a commit protocol, so
  /// anything found there at open time belongs to no registered asset and is
  /// unreachable by `assets()`, retention, deletion and export. Without this
  /// sweep a full-resolution photo could stay on disk after the user was told
  /// it was deleted, with no API able to remove it.
  private static func reclaimStagedMediaBytes(in stagingDirectory: URL) {
    guard
      let staged = try? FileManager.default.contentsOfDirectory(
        at: stagingDirectory,
        includingPropertiesForKeys: nil
      )
    else { return }
    for orphan in staged where orphan.pathExtension == "stage" {
      try? FileManager.default.removeItem(at: orphan)
    }
  }

  private static func applyPlatformProtection(to url: URL) {
    #if os(iOS) || os(watchOS)
      try? FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: url.path
      )
    #endif
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableURL = url
    try? mutableURL.setResourceValues(values)
  }
}
