import Foundation
import LineWiseDomain

public enum ExperiencePersistenceError: Error, Equatable, Sendable, CustomStringConvertible {
  case corruptedStore(String)
  case unsupportedSchemaVersion(Int)
  case ioFailure(operation: String, path: String, reason: String)

  public var description: String {
    switch self {
    case .corruptedStore(let reason):
      "LineWise experience archive is corrupted: \(reason)"
    case .unsupportedSchemaVersion(let version):
      "LineWise experience archive schema \(version) is not supported"
    case .ioFailure(let operation, let path, let reason):
      "LineWise could not \(operation) \(path): \(reason)"
    }
  }
}

public struct ExperienceArchiveProvenance: Equatable, Codable, Sendable {
  public let writerIdentifier: String
  public let writerVersion: String

  public init(writerIdentifier: String, writerVersion: String) {
    self.writerIdentifier = writerIdentifier
    self.writerVersion = writerVersion
  }

  public static let local = ExperienceArchiveProvenance(
    writerIdentifier: "linewise.local",
    writerVersion: "1"
  )
}

public struct LineWiseExperienceArchive: Equatable, Codable, Sendable {
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let provenance: ExperienceArchiveProvenance
  public let recallTrainingState: RecallTrainingState
  public let learningLoopState: LearningLoopState
  public let microDrillCatalog: ApprovedMicroDrillCatalog
  public let restState: RestState
  public let selectedRouteCardID: RouteCardID?
  public let reversibleActionIDs: [ActionID]
  public let physiologyContexts: [PhysiologyContextSnapshot]
  public let rehearsalAssociations: [RouteRehearsalAssociationSnapshot]

  public init(
    provenance: ExperienceArchiveProvenance = .local,
    recallTrainingState: RecallTrainingState = RecallTrainingState(),
    learningLoopState: LearningLoopState = LearningLoopState(),
    microDrillCatalog: ApprovedMicroDrillCatalog = ApprovedMicroDrillCatalog(drills: []),
    restState: RestState = RestState(),
    selectedRouteCardID: RouteCardID? = nil,
    reversibleActionIDs: [ActionID] = [],
    physiologyContexts: [PhysiologyContextSnapshot] = [],
    rehearsalAssociations: [RouteRehearsalAssociationSnapshot] = []
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.provenance = provenance
    self.recallTrainingState = recallTrainingState
    self.learningLoopState = learningLoopState
    self.microDrillCatalog = microDrillCatalog
    self.restState = restState
    self.selectedRouteCardID = selectedRouteCardID
    self.reversibleActionIDs = reversibleActionIDs
    self.physiologyContexts = physiologyContexts
    self.rehearsalAssociations = rehearsalAssociations
  }
}

public enum LineWiseExperienceArchiveCodec {
  private struct SchemaHeader: Decodable {
    let schemaVersion: Int
  }

  public static func encode(_ archive: LineWiseExperienceArchive) throws -> Data {
    try validate(archive)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      return try encoder.encode(archive)
    } catch let error as ExperiencePersistenceError {
      throw error
    } catch {
      throw ExperiencePersistenceError.corruptedStore(
        "could not encode archive: \(error.localizedDescription)"
      )
    }
  }

  public static func decode(_ data: Data) throws -> LineWiseExperienceArchive {
    let decoder = JSONDecoder()
    let header: SchemaHeader
    do {
      header = try decoder.decode(SchemaHeader.self, from: data)
    } catch {
      throw ExperiencePersistenceError.corruptedStore(
        "could not decode schema header: \(error.localizedDescription)"
      )
    }
    guard header.schemaVersion == LineWiseExperienceArchive.currentSchemaVersion else {
      throw ExperiencePersistenceError.unsupportedSchemaVersion(header.schemaVersion)
    }

    let archive: LineWiseExperienceArchive
    do {
      archive = try decoder.decode(LineWiseExperienceArchive.self, from: data)
    } catch {
      throw ExperiencePersistenceError.corruptedStore(
        "could not decode schema \(header.schemaVersion): \(error.localizedDescription)"
      )
    }
    try validate(archive)
    return archive
  }

  static func validate(_ archive: LineWiseExperienceArchive) throws {
    guard archive.schemaVersion == LineWiseExperienceArchive.currentSchemaVersion else {
      throw ExperiencePersistenceError.unsupportedSchemaVersion(archive.schemaVersion)
    }
    guard !archive.provenance.writerIdentifier.isEmpty else {
      throw ExperiencePersistenceError.corruptedStore("empty writer identifier")
    }
    guard !archive.provenance.writerVersion.isEmpty else {
      throw ExperiencePersistenceError.corruptedStore("empty writer version")
    }
    try requireUnique(
      archive.physiologyContexts.map(\.id),
      label: "physiology context ID"
    )
    try requireUnique(
      archive.rehearsalAssociations.map { $0.rehearsal.id },
      label: "rehearsal ID"
    )
    for association in archive.rehearsalAssociations
    where
      !association.rehearsal.actual.keyframes.isEmpty && association.actualAttemptID == nil
    {
      throw ExperiencePersistenceError.corruptedStore(
        "rehearsal \(association.rehearsal.id.rawValue) has actual poses without an Attempt"
      )
    }
  }

  private static func requireUnique<ID: Hashable>(_ ids: [ID], label: String) throws {
    guard Set(ids).count == ids.count else {
      throw ExperiencePersistenceError.corruptedStore("duplicate \(label)")
    }
  }
}

public protocol ExperienceArchiveStore: AnyObject {
  func load() throws -> LineWiseExperienceArchive?
  func save(_ archive: LineWiseExperienceArchive) throws
  func exportData() throws -> Data?
  func delete() throws
}

public final class MemoryExperienceArchiveStore: ExperienceArchiveStore {
  private var archive: LineWiseExperienceArchive?

  public init(archive: LineWiseExperienceArchive? = nil) {
    self.archive = archive
  }

  public func load() throws -> LineWiseExperienceArchive? {
    if let archive {
      try LineWiseExperienceArchiveCodec.validate(archive)
    }
    return archive
  }

  public func save(_ archive: LineWiseExperienceArchive) throws {
    try LineWiseExperienceArchiveCodec.validate(archive)
    self.archive = archive
  }

  public func exportData() throws -> Data? {
    try archive.map(LineWiseExperienceArchiveCodec.encode)
  }

  public func delete() throws {
    archive = nil
  }
}

public final class FoundationFileExperienceArchiveStore: ExperienceArchiveStore {
  public let fileURL: URL
  private let fileManager: FileManager

  public init(fileURL: URL, fileManager: FileManager = .default) {
    self.fileURL = fileURL
    self.fileManager = fileManager
  }

  public func load() throws -> LineWiseExperienceArchive? {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      return nil
    }
    let data: Data
    do {
      data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
    } catch {
      throw ExperiencePersistenceError.ioFailure(
        operation: "read",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
    return try LineWiseExperienceArchiveCodec.decode(data)
  }

  public func save(_ archive: LineWiseExperienceArchive) throws {
    let data = try LineWiseExperienceArchiveCodec.encode(archive)
    do {
      try fileManager.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: fileURL, options: .atomic)
    } catch let error as ExperiencePersistenceError {
      throw error
    } catch {
      throw ExperiencePersistenceError.ioFailure(
        operation: "atomically write",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }

  public func exportData() throws -> Data? {
    try load().map(LineWiseExperienceArchiveCodec.encode)
  }

  public func delete() throws {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      return
    }
    do {
      try fileManager.removeItem(at: fileURL)
    } catch {
      throw ExperiencePersistenceError.ioFailure(
        operation: "delete",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }
}

public struct PersistentLineWiseExperienceCoordinator {
  private let store: any ExperienceArchiveStore
  private let provenance: ExperienceArchiveProvenance
  private let configuredMicroDrillCatalog: ApprovedMicroDrillCatalog
  private var coordinator: LineWiseExperienceCoordinator

  public init(
    store: any ExperienceArchiveStore,
    appCoordinator: LineWiseAppCoordinator = LineWiseAppCoordinator(),
    microDrillCatalog: ApprovedMicroDrillCatalog = ApprovedMicroDrillCatalog(drills: []),
    provenance: ExperienceArchiveProvenance = .local
  ) throws {
    self.store = store
    configuredMicroDrillCatalog = microDrillCatalog
    if let archive = try store.load() {
      try LineWiseExperienceArchiveCodec.validate(archive)
      self.provenance = archive.provenance
      do {
        coordinator = try LineWiseExperienceCoordinator(
          restoring: archive,
          appCoordinator: appCoordinator,
          configuredMicroDrillCatalog: microDrillCatalog
        )
      } catch {
        throw ExperiencePersistenceError.corruptedStore(
          "could not restore rehearsal engine: \(error)"
        )
      }
    } else {
      self.provenance = provenance
      coordinator = LineWiseExperienceCoordinator(
        appCoordinator: appCoordinator,
        microDrillCatalog: microDrillCatalog
      )
    }
  }

  public init(
    store: any ExperienceArchiveStore,
    repository: VisitRepository,
    microDrillCatalog: ApprovedMicroDrillCatalog = ApprovedMicroDrillCatalog(drills: []),
    provenance: ExperienceArchiveProvenance = .local
  ) throws {
    try self.init(
      store: store,
      appCoordinator: LineWiseAppCoordinator(repository: repository),
      microDrillCatalog: microDrillCatalog,
      provenance: provenance
    )
  }

  public var projection: LineWiseExperienceProjection {
    coordinator.projection
  }

  public var watchProjection: WatchCaptureProjection {
    coordinator.watchProjection
  }

  public var pendingOutboundEvents: [DeviceEventEnvelope] {
    coordinator.pendingOutboundEvents
  }

  public var archive: LineWiseExperienceArchive {
    coordinator.makeArchive(provenance: provenance)
  }

  @discardableResult
  public mutating func receive(
    _ envelopes: [DeviceEventEnvelope]
  ) -> LineWiseDeviceSyncOutcome {
    var proposed = coordinator
    let result = proposed.receive(envelopes)
    guard case .received(let insertedEventIDs, _) = result else {
      return result
    }
    do {
      let reconciliation = try proposed.reconcileReviewInboxFromCapture()
      guard !insertedEventIDs.isEmpty || !reconciliation.enqueuedItemIDs.isEmpty else {
        return result
      }
      try persist(proposed)
      coordinator = proposed
      return result
    } catch {
      return .persistenceFailed(String(describing: error))
    }
  }

  @discardableResult
  public mutating func acknowledgeOutbound(
    _ eventID: ActionID
  ) -> LineWiseDeviceSyncOutcome {
    coordinator.acknowledgeOutbound(eventID)
  }

  @discardableResult
  public mutating func reconcileReviewInboxFromCapture() throws
    -> ReviewInboxReconciliationSummary
  {
    var proposed = coordinator
    let result = try proposed.reconcileReviewInboxFromCapture()
    guard !result.enqueuedItemIDs.isEmpty else { return result }
    try persist(proposed)
    coordinator = proposed
    return result
  }

  @discardableResult
  public mutating func handle(_ intent: LineWiseAppIntent) throws -> LineWiseAppFeedback {
    try applying({ $0.handle(intent) }, commitsWhen: { $0.isSuccess })
  }

  @discardableResult
  public mutating func submitRecall(
    _ command: RecallTrainingCommand
  ) throws -> RecallTrainingOutcome {
    try applying({ $0.submitRecall(command) }, commitsWhen: { $0 == .accepted })
  }

  @discardableResult
  public mutating func completeFailureReview(
    _ request: FailureReviewRequest
  ) throws -> FailureReviewOutcome {
    try applying({ $0.completeFailureReview(request) }, commitsWhen: { $0 == .accepted })
  }

  @discardableResult
  public mutating func submitLearning(
    _ command: LearningLoopCommand
  ) throws -> LearningLoopOutcome {
    try applying({ $0.submitLearning(command) }, commitsWhen: { $0 == .accepted })
  }

  @discardableResult
  public mutating func recordPhysiology(
    contextID: PhysiologyContextID,
    visitID: GymVisitID,
    subjective: SubjectivePhysiologyCheckIn?,
    healthKitSummary: HealthKitWorkoutSummary?,
    recordedAt: Instant
  ) throws -> PhysiologyRecordingOutcome {
    try applying(
      {
        $0.recordPhysiology(
          contextID: contextID,
          visitID: visitID,
          subjective: subjective,
          healthKitSummary: healthKitSummary,
          recordedAt: recordedAt
        )
      },
      commitsWhen: { $0.isAccepted }
    )
  }

  @discardableResult
  public mutating func attachRehearsal(
    _ engine: RouteRehearsalEngine,
    routeCardID: RouteCardID,
    plannedVisitID: GymVisitID? = nil,
    actualAttemptID: AttemptID? = nil,
    routeReadProvenance: RehearsalProvenance = .manual
  ) throws -> RehearsalAssociationOutcome {
    try applying(
      {
        $0.attachRehearsal(
          engine,
          routeCardID: routeCardID,
          plannedVisitID: plannedVisitID,
          actualAttemptID: actualAttemptID,
          routeReadProvenance: routeReadProvenance
        )
      },
      commitsWhen: { $0 == .accepted }
    )
  }

  @discardableResult
  public mutating func attachRouteReadResult(
    _ result: RouteReadResult,
    routeCardID: RouteCardID,
    rehearsalID: RouteRehearsalID,
    bodyProfile: BodyProfile,
    confirmedStartHoldIDs: [HoldID] = [],
    plannedVisitID: GymVisitID? = nil
  ) throws -> RehearsalAssociationOutcome {
    try applying(
      {
        $0.attachRouteReadResult(
          result,
          routeCardID: routeCardID,
          rehearsalID: rehearsalID,
          bodyProfile: bodyProfile,
          confirmedStartHoldIDs: confirmedStartHoldIDs,
          plannedVisitID: plannedVisitID
        )
      },
      commitsWhen: { $0 == .accepted }
    )
  }

  @discardableResult
  public mutating func updateRehearsal(
    _ rehearsalID: RouteRehearsalID,
    edit: (inout RouteRehearsalEngine) throws -> Void
  ) throws -> RouteRehearsalAssociationSnapshot {
    var proposed = coordinator
    let result = try proposed.updateRehearsal(rehearsalID, edit: edit)
    try persist(proposed)
    coordinator = proposed
    return result
  }

  public func exportData() throws -> Data {
    try LineWiseExperienceArchiveCodec.encode(archive)
  }

  public func exportData(to fileURL: URL) throws {
    let data = try exportData()
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: fileURL, options: .atomic)
    } catch {
      throw ExperiencePersistenceError.ioFailure(
        operation: "atomically export",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }

  public mutating func deleteAllExperienceData() throws {
    try store.delete()
    coordinator.resetPersistedExperienceData()
  }

  public mutating func reload() throws {
    guard let loaded = try store.load() else {
      coordinator.resetPersistedExperienceData()
      return
    }
    try LineWiseExperienceArchiveCodec.validate(loaded)
    do {
      coordinator = try LineWiseExperienceCoordinator(
        restoring: loaded,
        appCoordinator: coordinator.captureCoordinatorForPersistence,
        configuredMicroDrillCatalog: configuredMicroDrillCatalog
      )
    } catch {
      throw ExperiencePersistenceError.corruptedStore(
        "could not restore rehearsal engine: \(error)"
      )
    }
  }

  private mutating func applying<Result>(
    _ operation: (inout LineWiseExperienceCoordinator) throws -> Result,
    commitsWhen shouldCommit: (Result) -> Bool
  ) throws -> Result {
    var proposed = coordinator
    let result = try operation(&proposed)
    guard shouldCommit(result) else {
      return result
    }
    try persist(proposed)
    coordinator = proposed
    return result
  }

  private func persist(_ proposed: LineWiseExperienceCoordinator) throws {
    try store.save(proposed.makeArchive(provenance: provenance))
  }
}
