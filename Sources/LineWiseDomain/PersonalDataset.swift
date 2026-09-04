public struct DatasetScopedID<Scope>: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum RouteMediaAssetIDScope: Sendable {}
public enum MediaAnnotationIDScope: Sendable {}
public enum MediaAnnotationRevisionIDScope: Sendable {}
public enum MediaCorrectionRevisionIDScope: Sendable {}

public typealias RouteMediaAssetID = DatasetScopedID<RouteMediaAssetIDScope>
public typealias MediaAnnotationID = DatasetScopedID<MediaAnnotationIDScope>
public typealias MediaAnnotationRevisionID = DatasetScopedID<MediaAnnotationRevisionIDScope>
public typealias MediaCorrectionRevisionID = DatasetScopedID<MediaCorrectionRevisionIDScope>

/// An app-controlled reference to a local file. It deliberately has no URL, header, or credential
/// fields, so authentication material cannot become part of the personal dataset manifest.
public struct LocalMediaReference: Hashable, Codable, Sendable {
  public let fileIdentifier: String
  public let sandboxRelativePath: String

  public init(fileIdentifier: String, sandboxRelativePath: String) {
    self.fileIdentifier = fileIdentifier
    self.sandboxRelativePath = sandboxRelativePath
  }
}

public enum RouteMediaKind: String, Hashable, Codable, Sendable {
  case routePhoto = "route_photo"
  case plannedVideo = "planned_video"
  case actualVideo = "actual_video"
  case extractedFrame = "extracted_frame"
  case poseOverlay = "pose_overlay"
  case depthMap = "depth_map"
}

public struct MediaDimensions: Hashable, Codable, Sendable {
  public let pixelWidth: Int
  public let pixelHeight: Int

  public init(pixelWidth: Int, pixelHeight: Int) {
    self.pixelWidth = max(pixelWidth, 0)
    self.pixelHeight = max(pixelHeight, 0)
  }
}

public enum MediaDigestAlgorithm: String, Hashable, Codable, Sendable {
  case sha256
}

public struct MediaContentDigest: Hashable, Codable, Sendable {
  public let algorithm: MediaDigestAlgorithm
  public let hexValue: String

  public init(algorithm: MediaDigestAlgorithm, hexValue: String) {
    self.algorithm = algorithm
    self.hexValue = hexValue
  }
}

public enum MediaPurpose: String, Hashable, Codable, Sendable {
  case routeReference = "route_reference"
  case personalMovementReview = "personal_movement_review"
  case planActualComparison = "plan_actual_comparison"
  case stickFigureCue = "stick_figure_cue"
}

public enum MediaConsentStatus: String, Hashable, Codable, Sendable {
  case granted
  case revoked
}

public enum MediaConsentScope: String, Hashable, Codable, Sendable {
  case storageOnly = "storage_only"
  case onDevicePersonalAnalysis = "on_device_personal_analysis"
  case explicitModelProcessing = "explicit_model_processing"
}

public struct MediaConsent: Hashable, Codable, Sendable {
  public let status: MediaConsentStatus
  public let scope: MediaConsentScope
  public let recordedAt: Instant

  public init(status: MediaConsentStatus, scope: MediaConsentScope, recordedAt: Instant) {
    self.status = status
    self.scope = scope
    self.recordedAt = recordedAt
  }
}

public enum MediaCaptureDeviceClass: String, Hashable, Codable, Sendable {
  case phone
  case watch
  case camera
  case unknown
}

public enum MediaCaptureMethod: String, Hashable, Codable, Sendable {
  case cameraCapture = "camera_capture"
  case photoLibraryImport = "photo_library_import"
  case fileImport = "file_import"
  case derivedLocally = "derived_locally"
}

public struct MediaCaptureProvenance: Hashable, Codable, Sendable {
  public let capturedAt: Instant
  public let deviceClass: MediaCaptureDeviceClass
  public let method: MediaCaptureMethod
  public let importedByUser: Bool

  public init(
    capturedAt: Instant,
    deviceClass: MediaCaptureDeviceClass,
    method: MediaCaptureMethod,
    importedByUser: Bool
  ) {
    self.capturedAt = capturedAt
    self.deviceClass = deviceClass
    self.method = method
    self.importedByUser = importedByUser
  }
}

public enum MediaDerivationKind: String, Hashable, Codable, Sendable {
  case frameExtraction = "frame_extraction"
  case crop
  case transcode
  case poseOverlay = "pose_overlay"
  case annotationRasterization = "annotation_rasterization"
}

public struct MediaDerivation: Hashable, Codable, Sendable {
  public let kind: MediaDerivationKind
  public let implementationIdentifier: String
  public let version: String

  public init(kind: MediaDerivationKind, implementationIdentifier: String, version: String) {
    self.kind = kind
    self.implementationIdentifier = implementationIdentifier
    self.version = version
  }
}

public enum MediaAssetOrigin: Hashable, Codable, Sendable {
  case source
  case derived(sourceAssetIDs: [RouteMediaAssetID], transform: MediaDerivation)
}

public enum MediaQualityIssue: String, Hashable, Codable, Sendable {
  case motionBlur = "motion_blur"
  case occlusion
  case lowLight = "low_light"
  case incompleteRoute = "incomplete_route"
  case scaleUnknown = "scale_unknown"
  case timingUnreliable = "timing_unreliable"
}

public enum MediaQualityState: Hashable, Codable, Sendable {
  case unreviewed
  case usable
  case limited([MediaQualityIssue])
  case unusable([MediaQualityIssue])
}

public enum MediaRetentionPolicy: Hashable, Codable, Sendable {
  case keepUntilUserDeletes
  case expiresAt(Instant)
  case deleteAfterDerivedAssetsRemoved
}

public struct RouteMediaAsset: Hashable, Codable, Sendable {
  public let id: RouteMediaAssetID
  public let routeCardID: RouteCardID
  public let localReference: LocalMediaReference
  public let kind: RouteMediaKind
  public let mimeType: String
  public let byteCount: Int64
  public let dimensions: MediaDimensions
  public let contentDigest: MediaContentDigest
  public let purpose: MediaPurpose
  public let consent: MediaConsent
  public let captureProvenance: MediaCaptureProvenance
  public let origin: MediaAssetOrigin
  public let quality: MediaQualityState
  public let retention: MediaRetentionPolicy

  public init(
    id: RouteMediaAssetID,
    routeCardID: RouteCardID,
    localReference: LocalMediaReference,
    kind: RouteMediaKind,
    mimeType: String,
    byteCount: Int64,
    dimensions: MediaDimensions,
    contentDigest: MediaContentDigest,
    purpose: MediaPurpose,
    consent: MediaConsent,
    captureProvenance: MediaCaptureProvenance,
    origin: MediaAssetOrigin,
    quality: MediaQualityState,
    retention: MediaRetentionPolicy
  ) {
    self.id = id
    self.routeCardID = routeCardID
    self.localReference = localReference
    self.kind = kind
    self.mimeType = mimeType
    self.byteCount = max(byteCount, 0)
    self.dimensions = dimensions
    self.contentDigest = contentDigest
    self.purpose = purpose
    self.consent = consent
    self.captureProvenance = captureProvenance
    self.origin = origin
    self.quality = quality
    self.retention = retention
  }

  public var isSource: Bool {
    if case .source = origin { return true }
    return false
  }

  public var sourceAssetIDs: [RouteMediaAssetID] {
    guard case .derived(let ids, _) = origin else { return [] }
    return ids
  }

  fileprivate func replacing(quality: MediaQualityState) -> RouteMediaAsset {
    RouteMediaAsset(
      id: id,
      routeCardID: routeCardID,
      localReference: localReference,
      kind: kind,
      mimeType: mimeType,
      byteCount: byteCount,
      dimensions: dimensions,
      contentDigest: contentDigest,
      purpose: purpose,
      consent: consent,
      captureProvenance: captureProvenance,
      origin: origin,
      quality: quality,
      retention: retention
    )
  }
}

public enum MediaAssertionState: String, Hashable, Codable, Sendable {
  case suggested
  case confirmed
  case rejected
}

public enum MediaEvidenceProvenance: Hashable, Codable, Sendable {
  case manualUser
  case directObservation(sourceAssetID: RouteMediaAssetID)
  case deterministicInference(implementationIdentifier: String, version: String)
  case modelSuggestion(providerIdentifier: String, version: String)

  public var isSuggestion: Bool {
    switch self {
    case .deterministicInference, .modelSuggestion: true
    case .manualUser, .directObservation: false
    }
  }
}

public struct HoldAnnotation: Hashable, Codable, Sendable {
  public let holdID: HoldID
  public let center: Point2D
  public let radius: Double

  public init(holdID: HoldID, center: Point2D, radius: Double) {
    self.holdID = holdID
    self.center = center
    self.radius = max(radius, 0)
  }
}

public struct PoseAnnotation: Equatable, Codable, Sendable {
  public let keyframe: PoseKeyframe

  public init(keyframe: PoseKeyframe) {
    self.keyframe = keyframe
  }
}

public struct TimingAnnotation: Hashable, Codable, Sendable {
  public let startMilliseconds: Int64
  public let endMilliseconds: Int64
  public let certainty: MediaAnnotationCertainty

  public init(
    startMilliseconds: Int64,
    endMilliseconds: Int64,
    certainty: MediaAnnotationCertainty
  ) {
    self.startMilliseconds = max(startMilliseconds, 0)
    self.endMilliseconds = max(endMilliseconds, self.startMilliseconds)
    self.certainty = certainty
  }
}

public enum MediaAnnotationCertainty: String, Hashable, Codable, Sendable {
  case certain
  case uncertain
}

public enum MediaAnnotationPayload: Equatable, Codable, Sendable {
  case hold(HoldAnnotation)
  case pose(PoseAnnotation)
  case timing(TimingAnnotation)
  case note(String)
}

public struct MediaAnnotationRevision: Equatable, Codable, Sendable {
  public let id: MediaAnnotationRevisionID
  public let annotationID: MediaAnnotationID
  public let assetID: RouteMediaAssetID
  public let revision: Int
  public let payload: MediaAnnotationPayload
  public let assertionState: MediaAssertionState
  public let evidence: MediaEvidenceProvenance
  public let createdAt: Instant

  public init(
    id: MediaAnnotationRevisionID,
    annotationID: MediaAnnotationID,
    assetID: RouteMediaAssetID,
    revision: Int,
    payload: MediaAnnotationPayload,
    assertionState: MediaAssertionState,
    evidence: MediaEvidenceProvenance,
    createdAt: Instant
  ) {
    self.id = id
    self.annotationID = annotationID
    self.assetID = assetID
    self.revision = revision
    self.payload = payload
    self.assertionState = assertionState
    self.evidence = evidence
    self.createdAt = createdAt
  }
}

public struct MediaCorrectionRevision: Equatable, Codable, Sendable {
  public let id: MediaCorrectionRevisionID
  public let annotationID: MediaAnnotationID
  public let assetID: RouteMediaAssetID
  public let revision: Int
  public let replacesAnnotationRevisionID: MediaAnnotationRevisionID
  public let replacement: MediaAnnotationPayload
  public let reason: String
  public let assertionState: MediaAssertionState
  public let evidence: MediaEvidenceProvenance
  public let createdAt: Instant

  public init(
    id: MediaCorrectionRevisionID,
    annotationID: MediaAnnotationID,
    assetID: RouteMediaAssetID,
    revision: Int,
    replacesAnnotationRevisionID: MediaAnnotationRevisionID,
    replacement: MediaAnnotationPayload,
    reason: String,
    assertionState: MediaAssertionState,
    evidence: MediaEvidenceProvenance,
    createdAt: Instant
  ) {
    self.id = id
    self.annotationID = annotationID
    self.assetID = assetID
    self.revision = revision
    self.replacesAnnotationRevisionID = replacesAnnotationRevisionID
    self.replacement = replacement
    self.reason = reason
    self.assertionState = assertionState
    self.evidence = evidence
    self.createdAt = createdAt
  }
}

public enum MediaDeletionReason: String, Hashable, Codable, Sendable {
  case userRequested = "user_requested"
  case retentionExpired = "retention_expired"
  case consentRevoked = "consent_revoked"
  case sourceRemoved = "source_removed"
}

public struct MediaDeletionTombstone: Hashable, Codable, Sendable {
  public let assetID: RouteMediaAssetID
  public let routeCardID: RouteCardID
  public let contentDigest: MediaContentDigest
  public let sourceAssetIDs: [RouteMediaAssetID]
  public let deletedAt: Instant
  public let reason: MediaDeletionReason

  public init(
    assetID: RouteMediaAssetID,
    routeCardID: RouteCardID,
    contentDigest: MediaContentDigest,
    sourceAssetIDs: [RouteMediaAssetID],
    deletedAt: Instant,
    reason: MediaDeletionReason
  ) {
    self.assetID = assetID
    self.routeCardID = routeCardID
    self.contentDigest = contentDigest
    self.sourceAssetIDs = sourceAssetIDs
    self.deletedAt = deletedAt
    self.reason = reason
  }
}

public struct DatasetExportManifest: Equatable, Codable, Sendable {
  public let schemaVersion: Int
  public let createdAt: Instant
  public let activeAssets: [RouteMediaAsset]
  public let annotationHistory: [MediaAnnotationRevision]
  public let correctionHistory: [MediaCorrectionRevision]
  public let deletionTombstones: [MediaDeletionTombstone]

  public init(
    schemaVersion: Int = 1,
    createdAt: Instant,
    activeAssets: [RouteMediaAsset],
    annotationHistory: [MediaAnnotationRevision],
    correctionHistory: [MediaCorrectionRevision],
    deletionTombstones: [MediaDeletionTombstone]
  ) {
    self.schemaVersion = schemaVersion
    self.createdAt = createdAt
    self.activeAssets = activeAssets
    self.annotationHistory = annotationHistory
    self.correctionHistory = correctionHistory
    self.deletionTombstones = deletionTombstones
  }
}

public enum PersonalDatasetError: Error, Equatable, Sendable {
  case duplicateAssetID(RouteMediaAssetID)
  case assetIDTombstoned(RouteMediaAssetID)
  case assetNotFound(RouteMediaAssetID)
  case derivedAssetRequiresSource
  case sourceAssetNotFound(RouteMediaAssetID)
  case sourceAssetRouteCardMismatch(
    sourceAssetID: RouteMediaAssetID,
    expected: RouteCardID,
    actual: RouteCardID
  )
  case duplicateAnnotationRevisionID(MediaAnnotationRevisionID)
  case duplicateCorrectionRevisionID(MediaCorrectionRevisionID)
  case invalidAnnotationRevision(expected: Int, actual: Int)
  case invalidCorrectionRevision(expected: Int, actual: Int)
  case annotationNotFound(MediaAnnotationID)
  case annotationAssetMismatch
  case replacedAnnotationRevisionNotFound(MediaAnnotationRevisionID)
  case suggestionCannotBeConfirmed
}

public struct PersonalDataset: Equatable, Codable, Sendable {
  private var assetsByID: [RouteMediaAssetID: RouteMediaAsset]
  private var annotationRevisions: [MediaAnnotationRevision]
  private var correctionRevisions: [MediaCorrectionRevision]
  private var tombstonesByAssetID: [RouteMediaAssetID: MediaDeletionTombstone]

  public init() {
    assetsByID = [:]
    annotationRevisions = []
    correctionRevisions = []
    tombstonesByAssetID = [:]
  }

  public var activeAssets: [RouteMediaAsset] {
    assetsByID.values.sorted { $0.id.rawValue < $1.id.rawValue }
  }

  public var deletionTombstones: [MediaDeletionTombstone] {
    tombstonesByAssetID.values.sorted { $0.assetID.rawValue < $1.assetID.rawValue }
  }

  public func asset(id: RouteMediaAssetID) -> RouteMediaAsset? {
    assetsByID[id]
  }

  public mutating func add(_ asset: RouteMediaAsset) throws {
    guard assetsByID[asset.id] == nil else {
      throw PersonalDatasetError.duplicateAssetID(asset.id)
    }
    guard tombstonesByAssetID[asset.id] == nil else {
      throw PersonalDatasetError.assetIDTombstoned(asset.id)
    }
    if case .derived(let sourceAssetIDs, _) = asset.origin {
      guard !sourceAssetIDs.isEmpty else {
        throw PersonalDatasetError.derivedAssetRequiresSource
      }
      for sourceAssetID in sourceAssetIDs {
        guard let source = assetsByID[sourceAssetID] else {
          throw PersonalDatasetError.sourceAssetNotFound(sourceAssetID)
        }
        // Evidence must never cross a RouteCard boundary: a frame extracted from
        // one route's video cannot be filed as another route's evidence, because
        // the lineage outlives the bytes in the export manifest and in the
        // deletion tombstone.
        guard source.routeCardID == asset.routeCardID else {
          throw PersonalDatasetError.sourceAssetRouteCardMismatch(
            sourceAssetID: sourceAssetID,
            expected: asset.routeCardID,
            actual: source.routeCardID
          )
        }
      }
    }
    assetsByID[asset.id] = asset
  }

  public mutating func updateQuality(
    of assetID: RouteMediaAssetID,
    to quality: MediaQualityState
  ) throws {
    guard let asset = assetsByID[assetID] else {
      throw PersonalDatasetError.assetNotFound(assetID)
    }
    assetsByID[assetID] = asset.replacing(quality: quality)
  }

  public mutating func recordAnnotation(_ revision: MediaAnnotationRevision) throws {
    guard assetsByID[revision.assetID] != nil else {
      throw PersonalDatasetError.assetNotFound(revision.assetID)
    }
    guard !annotationRevisions.contains(where: { $0.id == revision.id }) else {
      throw PersonalDatasetError.duplicateAnnotationRevisionID(revision.id)
    }
    try Self.validateAssertion(revision.assertionState, evidence: revision.evidence)
    let history = annotationHistory(for: revision.annotationID)
    if let first = history.first, first.assetID != revision.assetID {
      throw PersonalDatasetError.annotationAssetMismatch
    }
    let expected = (history.last?.revision ?? 0) + 1
    guard revision.revision == expected else {
      throw PersonalDatasetError.invalidAnnotationRevision(
        expected: expected,
        actual: revision.revision
      )
    }
    annotationRevisions.append(revision)
  }

  public mutating func recordCorrection(_ revision: MediaCorrectionRevision) throws {
    guard assetsByID[revision.assetID] != nil else {
      throw PersonalDatasetError.assetNotFound(revision.assetID)
    }
    guard !correctionRevisions.contains(where: { $0.id == revision.id }) else {
      throw PersonalDatasetError.duplicateCorrectionRevisionID(revision.id)
    }
    try Self.validateAssertion(revision.assertionState, evidence: revision.evidence)
    let annotations = annotationHistory(for: revision.annotationID)
    guard !annotations.isEmpty else {
      throw PersonalDatasetError.annotationNotFound(revision.annotationID)
    }
    guard annotations.allSatisfy({ $0.assetID == revision.assetID }) else {
      throw PersonalDatasetError.annotationAssetMismatch
    }
    guard annotations.contains(where: { $0.id == revision.replacesAnnotationRevisionID }) else {
      throw PersonalDatasetError.replacedAnnotationRevisionNotFound(
        revision.replacesAnnotationRevisionID
      )
    }
    let history = correctionHistory(for: revision.annotationID)
    let expected = (history.last?.revision ?? 0) + 1
    guard revision.revision == expected else {
      throw PersonalDatasetError.invalidCorrectionRevision(
        expected: expected,
        actual: revision.revision
      )
    }
    correctionRevisions.append(revision)
  }

  public func annotationHistory(for annotationID: MediaAnnotationID) -> [MediaAnnotationRevision] {
    annotationRevisions
      .filter { $0.annotationID == annotationID }
      .sorted { lhs, rhs in
        lhs.revision == rhs.revision
          ? lhs.id.rawValue < rhs.id.rawValue : lhs.revision < rhs.revision
      }
  }

  public func correctionHistory(for annotationID: MediaAnnotationID) -> [MediaCorrectionRevision] {
    correctionRevisions
      .filter { $0.annotationID == annotationID }
      .sorted { lhs, rhs in
        lhs.revision == rhs.revision
          ? lhs.id.rawValue < rhs.id.rawValue : lhs.revision < rhs.revision
      }
  }

  @discardableResult
  public mutating func deleteAsset(
    _ assetID: RouteMediaAssetID,
    at deletedAt: Instant,
    reason: MediaDeletionReason
  ) throws -> MediaDeletionTombstone {
    guard let asset = assetsByID.removeValue(forKey: assetID) else {
      throw PersonalDatasetError.assetNotFound(assetID)
    }
    let tombstone = MediaDeletionTombstone(
      assetID: asset.id,
      routeCardID: asset.routeCardID,
      contentDigest: asset.contentDigest,
      sourceAssetIDs: asset.sourceAssetIDs,
      deletedAt: deletedAt,
      reason: reason
    )
    tombstonesByAssetID[assetID] = tombstone
    return tombstone
  }

  public func exportManifest(createdAt: Instant) -> DatasetExportManifest {
    DatasetExportManifest(
      createdAt: createdAt,
      activeAssets: activeAssets,
      annotationHistory: annotationRevisions.sorted(by: Self.annotationSort),
      correctionHistory: correctionRevisions.sorted(by: Self.correctionSort),
      deletionTombstones: deletionTombstones
    )
  }

  private static func validateAssertion(
    _ state: MediaAssertionState,
    evidence: MediaEvidenceProvenance
  ) throws {
    if evidence.isSuggestion && state == .confirmed {
      throw PersonalDatasetError.suggestionCannotBeConfirmed
    }
  }

  private static func annotationSort(
    _ lhs: MediaAnnotationRevision,
    _ rhs: MediaAnnotationRevision
  ) -> Bool {
    if lhs.assetID != rhs.assetID { return lhs.assetID.rawValue < rhs.assetID.rawValue }
    if lhs.annotationID != rhs.annotationID {
      return lhs.annotationID.rawValue < rhs.annotationID.rawValue
    }
    if lhs.revision != rhs.revision { return lhs.revision < rhs.revision }
    return lhs.id.rawValue < rhs.id.rawValue
  }

  private static func correctionSort(
    _ lhs: MediaCorrectionRevision,
    _ rhs: MediaCorrectionRevision
  ) -> Bool {
    if lhs.assetID != rhs.assetID { return lhs.assetID.rawValue < rhs.assetID.rawValue }
    if lhs.annotationID != rhs.annotationID {
      return lhs.annotationID.rawValue < rhs.annotationID.rawValue
    }
    if lhs.revision != rhs.revision { return lhs.revision < rhs.revision }
    return lhs.id.rawValue < rhs.id.rawValue
  }
}
