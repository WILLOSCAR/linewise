import Foundation
import LineWiseDomain

public struct FieldEvidenceEventID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct FieldEvidenceSessionID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct FieldEvidenceSessionConsent: Equatable, Codable, Sendable {
  public let sessionID: FieldEvidenceSessionID
  public let consentedAt: Instant

  public init(sessionID: FieldEvidenceSessionID, consentedAt: Instant) {
    self.sessionID = sessionID
    self.consentedAt = consentedAt
  }
}

public enum FieldEvidenceMode: Equatable, Codable, Sendable {
  case disabled
  case fieldTest(FieldEvidenceSessionConsent)
}

public struct FieldEvidenceTaskID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct FieldEvidenceCuePresentationID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum FieldEvidenceUIMarker: Equatable, Codable, Sendable {
  case routeCardCreationStarted(FieldEvidenceTaskID)
  case routeCardCreationCompleted(FieldEvidenceTaskID)
  case attemptPrimaryActionTapped
  case nextSessionCuePresented(FieldEvidenceCuePresentationID)
  case nextSessionCueActioned(FieldEvidenceCuePresentationID)
}

public enum FieldEvidenceIntentKind: String, Equatable, Codable, Sendable {
  case createRoute
  case reviseRoute
  case archiveRoute
  case restoreRoute
  case correctRouteAvailability
  case mergeRoute
  case unmergeRoute
  case correctAttemptRoute
  case startProject
  case archiveProject
  case startVisit
  case selectRoute
  case recordAttempt
  case markSend
  case confirmNotSent
  case undo
  case endVisit
  case beginReview
  case completeReview
  case closeProjectSent
  case startRest
  case stopRest
}

public enum FieldEvidenceFeedbackKind: String, Equatable, Codable, Sendable {
  case accepted
  case duplicate
  case selectionChanged
  case conflict
  case deferred
  case rejected
  case restRejected
  case persistenceFailed
  case locallyRejected
}

public enum FieldEvidenceEventKind: Equatable, Codable, Sendable {
  case uiMarker(FieldEvidenceUIMarker)
  case intentFeedback(intent: FieldEvidenceIntentKind, feedback: FieldEvidenceFeedbackKind)
}

public struct FieldEvidenceEvent: Equatable, Codable, Sendable {
  public let id: FieldEvidenceEventID
  public let sessionID: FieldEvidenceSessionID
  public let occurredAt: Instant
  public let kind: FieldEvidenceEventKind

  public init(
    id: FieldEvidenceEventID,
    sessionID: FieldEvidenceSessionID,
    occurredAt: Instant,
    kind: FieldEvidenceEventKind
  ) {
    self.id = id
    self.sessionID = sessionID
    self.occurredAt = occurredAt
    self.kind = kind
  }
}

public struct FieldEvidenceArchive: Equatable, Codable, Sendable {
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let events: [FieldEvidenceEvent]

  public init(events: [FieldEvidenceEvent]) {
    schemaVersion = Self.currentSchemaVersion
    self.events = events
  }
}

public enum FieldEvidencePersistenceError: Error, Equatable, Sendable, CustomStringConvertible {
  case corruptedStore(String)
  case unsupportedSchemaVersion(Int)
  case ioFailure(operation: String, path: String, reason: String)
  case eventIDConflict(FieldEvidenceEventID)

  public var description: String {
    switch self {
    case .corruptedStore(let reason):
      "Field evidence store is corrupted: \(reason)"
    case .unsupportedSchemaVersion(let version):
      "Field evidence schema \(version) is not supported"
    case .ioFailure(let operation, let path, let reason):
      "Field evidence could not \(operation) \(path): \(reason)"
    case .eventIDConflict(let eventID):
      "Field evidence event ID conflict: \(eventID.rawValue)"
    }
  }
}

public enum FieldEvidenceAppendOutcome: Equatable, Sendable {
  case inserted
  case duplicate
}

public protocol FieldEvidenceStore: AnyObject {
  func load() throws -> FieldEvidenceArchive
  func append(_ event: FieldEvidenceEvent) throws -> FieldEvidenceAppendOutcome
  func exportData() throws -> Data
  func delete() throws
}

public enum FieldEvidenceArchiveCodec {
  private struct SchemaHeader: Decodable {
    let schemaVersion: Int
  }

  public static func encode(_ archive: FieldEvidenceArchive) throws -> Data {
    try validate(archive)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      return try encoder.encode(archive)
    } catch {
      throw FieldEvidencePersistenceError.corruptedStore(
        "could not encode archive: \(error.localizedDescription)"
      )
    }
  }

  public static func decode(_ data: Data) throws -> FieldEvidenceArchive {
    let decoder = JSONDecoder()
    let header: SchemaHeader
    do {
      header = try decoder.decode(SchemaHeader.self, from: data)
    } catch {
      throw FieldEvidencePersistenceError.corruptedStore(
        "could not decode schema header: \(error.localizedDescription)"
      )
    }
    guard header.schemaVersion == FieldEvidenceArchive.currentSchemaVersion else {
      throw FieldEvidencePersistenceError.unsupportedSchemaVersion(header.schemaVersion)
    }
    let archive: FieldEvidenceArchive
    do {
      archive = try decoder.decode(FieldEvidenceArchive.self, from: data)
    } catch {
      throw FieldEvidencePersistenceError.corruptedStore(
        "could not decode archive: \(error.localizedDescription)"
      )
    }
    try validate(archive)
    return archive
  }

  static func validate(_ archive: FieldEvidenceArchive) throws {
    guard archive.schemaVersion == FieldEvidenceArchive.currentSchemaVersion else {
      throw FieldEvidencePersistenceError.unsupportedSchemaVersion(archive.schemaVersion)
    }
    var byID: [FieldEvidenceEventID: FieldEvidenceEvent] = [:]
    for event in archive.events {
      if let existing = byID[event.id], existing != event {
        throw FieldEvidencePersistenceError.eventIDConflict(event.id)
      }
      if byID[event.id] != nil {
        throw FieldEvidencePersistenceError.corruptedStore(
          "duplicate event ID \(event.id.rawValue)"
        )
      }
      byID[event.id] = event
    }
  }
}

public final class MemoryFieldEvidenceStore: FieldEvidenceStore {
  private var archive: FieldEvidenceArchive

  public init(archive: FieldEvidenceArchive = FieldEvidenceArchive(events: [])) {
    self.archive = archive
  }

  public func load() throws -> FieldEvidenceArchive {
    try FieldEvidenceArchiveCodec.validate(archive)
    return archive
  }

  public func append(_ event: FieldEvidenceEvent) throws -> FieldEvidenceAppendOutcome {
    if let existing = archive.events.first(where: { $0.id == event.id }) {
      guard existing == event else {
        throw FieldEvidencePersistenceError.eventIDConflict(event.id)
      }
      return .duplicate
    }
    archive = FieldEvidenceArchive(events: archive.events + [event])
    return .inserted
  }

  public func exportData() throws -> Data {
    try FieldEvidenceArchiveCodec.encode(archive)
  }

  public func delete() throws {
    archive = FieldEvidenceArchive(events: [])
  }
}

public final class FoundationFileFieldEvidenceStore: FieldEvidenceStore {
  public let fileURL: URL
  private let fileManager: FileManager

  public init(fileURL: URL, fileManager: FileManager = .default) {
    self.fileURL = fileURL
    self.fileManager = fileManager
  }

  public func load() throws -> FieldEvidenceArchive {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      return FieldEvidenceArchive(events: [])
    }
    let data: Data
    do {
      data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
    } catch {
      throw FieldEvidencePersistenceError.ioFailure(
        operation: "read",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
    return try FieldEvidenceArchiveCodec.decode(data)
  }

  public func append(_ event: FieldEvidenceEvent) throws -> FieldEvidenceAppendOutcome {
    let archive = try load()
    if let existing = archive.events.first(where: { $0.id == event.id }) {
      guard existing == event else {
        throw FieldEvidencePersistenceError.eventIDConflict(event.id)
      }
      return .duplicate
    }
    let data = try FieldEvidenceArchiveCodec.encode(
      FieldEvidenceArchive(events: archive.events + [event])
    )
    do {
      try fileManager.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: fileURL, options: .atomic)
    } catch {
      throw FieldEvidencePersistenceError.ioFailure(
        operation: "atomically write",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
    return .inserted
  }

  public func exportData() throws -> Data {
    try FieldEvidenceArchiveCodec.encode(load())
  }

  public func delete() throws {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      return
    }
    do {
      try fileManager.removeItem(at: fileURL)
    } catch {
      throw FieldEvidencePersistenceError.ioFailure(
        operation: "delete",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }
}

public enum FieldEvidenceRecordResult: Equatable, Sendable {
  case disabled
  case beforeConsent
  case inserted
  case duplicate
  case failed(String)
}

public enum FieldEvidenceMetricID: String, CaseIterable, Equatable, Codable, Sendable {
  case routeCardCompletionDurationMilliseconds
  case attemptPrimaryActionTapBurden
  case saveAcceptedReliability
  case savePersistenceFailureRate
  case reviewCompletion
  case nextSessionCueActionRate
  case routeCorrectionCount
  case attemptCorrectionCount
}

public enum FieldEvidenceMetricUnit: String, Equatable, Codable, Sendable {
  case millisecondsPerCompletion
  case tapsPerInteraction
  case ratio
  case countPerSession
}

public enum FieldEvidenceMissingDataBehavior: String, Equatable, Codable, Sendable {
  case unavailableWhenNoCompletedTaskPair
  case unavailableWhenNoEligibleInteraction
  case unavailableWhenNoSaveOutcome
  case unavailableWhenNoReviewStarted
  case unavailableWhenNoCuePresented
  case zeroWhenNoMatchingEvent
}

public enum FieldEvidenceSourceEventKind: String, Equatable, Codable, Sendable {
  case uiTaskMarker
  case intentFeedback
}

public enum FieldEvidencePrivacyScope: String, Equatable, Codable, Sendable {
  case consentedFieldTestSessionOperationalMetadata
}

public struct FieldEvidenceMetric: Equatable, Codable, Sendable {
  public let id: FieldEvidenceMetricID
  public let numerator: Int64
  public let denominator: Int64
  public let unit: FieldEvidenceMetricUnit
  public let missingDataBehavior: FieldEvidenceMissingDataBehavior
  public let sourceEventKinds: [FieldEvidenceSourceEventKind]
  public let privacyScope: FieldEvidencePrivacyScope

  public init(
    id: FieldEvidenceMetricID,
    numerator: Int64,
    denominator: Int64,
    unit: FieldEvidenceMetricUnit,
    missingDataBehavior: FieldEvidenceMissingDataBehavior,
    sourceEventKinds: [FieldEvidenceSourceEventKind],
    privacyScope: FieldEvidencePrivacyScope =
      .consentedFieldTestSessionOperationalMetadata
  ) {
    self.id = id
    self.numerator = numerator
    self.denominator = denominator
    self.unit = unit
    self.missingDataBehavior = missingDataBehavior
    self.sourceEventKinds = sourceEventKinds
    self.privacyScope = privacyScope
  }

  public var value: Double? {
    guard denominator > 0 else {
      return nil
    }
    return Double(numerator) / Double(denominator)
  }
}

public struct FieldEvidenceReport: Equatable, Codable, Sendable {
  public let metrics: [FieldEvidenceMetric]

  public init(events: [FieldEvidenceEvent]) {
    let routeStarts = events.reduce(into: [FieldEvidenceTaskID: Instant]()) { result, event in
      guard case .uiMarker(.routeCardCreationStarted(let taskID)) = event.kind else {
        return
      }
      if let current = result[taskID], current <= event.occurredAt {
        return
      }
      result[taskID] = event.occurredAt
    }
    var completedTaskIDs: Set<FieldEvidenceTaskID> = []
    var totalDuration: Int64 = 0
    for event in events {
      guard case .uiMarker(.routeCardCreationCompleted(let taskID)) = event.kind,
        !completedTaskIDs.contains(taskID),
        let startedAt = routeStarts[taskID],
        event.occurredAt >= startedAt
      else {
        continue
      }
      totalDuration += event.occurredAt.rawValue - startedAt.rawValue
      completedTaskIDs.insert(taskID)
    }

    let attemptTapCount = events.reduce(into: Int64(0)) { result, event in
      if case .uiMarker(.attemptPrimaryActionTapped) = event.kind {
        result += 1
      }
    }
    let attemptInteractionCount = events.reduce(into: Int64(0)) { result, event in
      if case .intentFeedback(.recordAttempt, _) = event.kind {
        result += 1
      }
    }

    var acceptedSaveCount: Int64 = 0
    var persistenceFailureCount: Int64 = 0
    var reviewStartedCount: Int64 = 0
    var reviewCompletedCount: Int64 = 0
    var routeCorrectionCount: Int64 = 0
    var attemptCorrectionCount: Int64 = 0
    var presentedCueIDs: Set<FieldEvidenceCuePresentationID> = []
    var actionedCueIDs: Set<FieldEvidenceCuePresentationID> = []
    for event in events {
      switch event.kind {
      case .uiMarker(.nextSessionCuePresented(let presentationID)):
        presentedCueIDs.insert(presentationID)
      case .uiMarker(.nextSessionCueActioned(let presentationID)):
        actionedCueIDs.insert(presentationID)
      case .uiMarker:
        break
      case .intentFeedback(let intent, let feedback):
        switch feedback {
        case .accepted:
          acceptedSaveCount += 1
        case .persistenceFailed:
          persistenceFailureCount += 1
        case .duplicate, .selectionChanged, .conflict, .deferred, .rejected, .restRejected,
          .locallyRejected:
          break
        }
        if intent == .beginReview, feedback == .accepted {
          reviewStartedCount += 1
        }
        if intent == .completeReview, feedback == .accepted {
          reviewCompletedCount += 1
        }
        if Self.isRouteCorrection(intent), feedback == .accepted {
          routeCorrectionCount += 1
        }
        if intent == .correctAttemptRoute, feedback == .accepted {
          attemptCorrectionCount += 1
        }
      }
    }
    let saveOutcomeCount = acceptedSaveCount + persistenceFailureCount
    let actionedPresentedCueCount = presentedCueIDs.intersection(actionedCueIDs).count

    metrics = [
      FieldEvidenceMetric(
        id: .routeCardCompletionDurationMilliseconds,
        numerator: totalDuration,
        denominator: Int64(completedTaskIDs.count),
        unit: .millisecondsPerCompletion,
        missingDataBehavior: .unavailableWhenNoCompletedTaskPair,
        sourceEventKinds: [.uiTaskMarker]
      ),
      FieldEvidenceMetric(
        id: .attemptPrimaryActionTapBurden,
        numerator: attemptTapCount,
        denominator: attemptInteractionCount,
        unit: .tapsPerInteraction,
        missingDataBehavior: .unavailableWhenNoEligibleInteraction,
        sourceEventKinds: [.uiTaskMarker, .intentFeedback]
      ),
      FieldEvidenceMetric(
        id: .saveAcceptedReliability,
        numerator: acceptedSaveCount,
        denominator: saveOutcomeCount,
        unit: .ratio,
        missingDataBehavior: .unavailableWhenNoSaveOutcome,
        sourceEventKinds: [.intentFeedback]
      ),
      FieldEvidenceMetric(
        id: .savePersistenceFailureRate,
        numerator: persistenceFailureCount,
        denominator: saveOutcomeCount,
        unit: .ratio,
        missingDataBehavior: .unavailableWhenNoSaveOutcome,
        sourceEventKinds: [.intentFeedback]
      ),
      FieldEvidenceMetric(
        id: .reviewCompletion,
        numerator: reviewCompletedCount,
        denominator: reviewStartedCount,
        unit: .ratio,
        missingDataBehavior: .unavailableWhenNoReviewStarted,
        sourceEventKinds: [.intentFeedback]
      ),
      FieldEvidenceMetric(
        id: .nextSessionCueActionRate,
        numerator: Int64(actionedPresentedCueCount),
        denominator: Int64(presentedCueIDs.count),
        unit: .ratio,
        missingDataBehavior: .unavailableWhenNoCuePresented,
        sourceEventKinds: [.uiTaskMarker]
      ),
      FieldEvidenceMetric(
        id: .routeCorrectionCount,
        numerator: routeCorrectionCount,
        denominator: 1,
        unit: .countPerSession,
        missingDataBehavior: .zeroWhenNoMatchingEvent,
        sourceEventKinds: [.intentFeedback]
      ),
      FieldEvidenceMetric(
        id: .attemptCorrectionCount,
        numerator: attemptCorrectionCount,
        denominator: 1,
        unit: .countPerSession,
        missingDataBehavior: .zeroWhenNoMatchingEvent,
        sourceEventKinds: [.intentFeedback]
      ),
    ]
  }

  public func metric(_ id: FieldEvidenceMetricID) -> FieldEvidenceMetric? {
    metrics.first { $0.id == id }
  }

  private static func isRouteCorrection(_ intent: FieldEvidenceIntentKind) -> Bool {
    switch intent {
    case .reviseRoute, .correctRouteAvailability, .mergeRoute, .unmergeRoute:
      true
    case .createRoute, .archiveRoute, .restoreRoute, .correctAttemptRoute, .startProject,
      .archiveProject, .startVisit, .selectRoute, .recordAttempt, .markSend, .confirmNotSent,
      .undo, .endVisit, .beginReview, .completeReview, .closeProjectSent, .startRest, .stopRest:
      false
    }
  }
}

public struct FieldEvidenceRecorder {
  private let mode: FieldEvidenceMode
  private let store: any FieldEvidenceStore
  private var events: [FieldEvidenceEvent]

  public init(store: any FieldEvidenceStore) {
    mode = .disabled
    self.store = store
    events = []
  }

  public init(mode: FieldEvidenceMode, store: any FieldEvidenceStore) throws {
    self.mode = mode
    self.store = store
    switch mode {
    case .disabled:
      events = []
    case .fieldTest:
      events = try store.load().events
    }
  }

  public var currentSessionEvents: [FieldEvidenceEvent] {
    guard case .fieldTest(let consent) = mode else {
      return []
    }
    return events.filter {
      $0.sessionID == consent.sessionID && $0.occurredAt >= consent.consentedAt
    }
  }

  public var report: FieldEvidenceReport {
    FieldEvidenceReport(events: currentSessionEvents)
  }

  @discardableResult
  public mutating func record(
    eventID: FieldEvidenceEventID,
    marker: FieldEvidenceUIMarker,
    occurredAt: Instant
  ) -> FieldEvidenceRecordResult {
    record(eventID: eventID, kind: .uiMarker(marker), occurredAt: occurredAt)
  }

  @discardableResult
  public mutating func record(
    eventID: FieldEvidenceEventID,
    intent: LineWiseAppIntent,
    feedback: LineWiseAppFeedback,
    occurredAt: Instant
  ) -> FieldEvidenceRecordResult {
    record(
      eventID: eventID,
      kind: .intentFeedback(
        intent: Self.evidenceKind(for: intent),
        feedback: Self.evidenceKind(for: feedback.outcome)
      ),
      occurredAt: occurredAt
    )
  }

  private mutating func record(
    eventID: FieldEvidenceEventID,
    kind: FieldEvidenceEventKind,
    occurredAt: Instant
  ) -> FieldEvidenceRecordResult {
    guard case .fieldTest(let consent) = mode else {
      return .disabled
    }
    guard occurredAt >= consent.consentedAt else {
      return .beforeConsent
    }
    let event = FieldEvidenceEvent(
      id: eventID,
      sessionID: consent.sessionID,
      occurredAt: occurredAt,
      kind: kind
    )
    do {
      switch try store.append(event) {
      case .inserted:
        events.append(event)
        return .inserted
      case .duplicate:
        if !events.contains(where: { $0.id == event.id }) {
          events.append(event)
        }
        return .duplicate
      }
    } catch {
      return .failed(String(describing: error))
    }
  }

  private static func evidenceKind(for intent: LineWiseAppIntent) -> FieldEvidenceIntentKind {
    switch intent {
    case .createRoute: .createRoute
    case .reviseRoute: .reviseRoute
    case .archiveRoute: .archiveRoute
    case .restoreRoute: .restoreRoute
    case .correctRouteAvailability: .correctRouteAvailability
    case .mergeRoute: .mergeRoute
    case .unmergeRoute: .unmergeRoute
    case .correctAttemptRoute: .correctAttemptRoute
    case .startProject: .startProject
    case .archiveProject: .archiveProject
    case .startVisit: .startVisit
    case .selectRoute: .selectRoute
    case .recordAttempt: .recordAttempt
    case .markSend: .markSend
    case .confirmNotSent: .confirmNotSent
    case .undo: .undo
    case .endVisit: .endVisit
    case .beginReview: .beginReview
    case .completeReview: .completeReview
    case .closeProjectSent: .closeProjectSent
    case .startRest: .startRest
    case .stopRest: .stopRest
    }
  }

  private static func evidenceKind(for outcome: LineWiseAppOutcome) -> FieldEvidenceFeedbackKind {
    switch outcome {
    case .accepted: .accepted
    case .duplicate: .duplicate
    case .selectionChanged: .selectionChanged
    case .conflict: .conflict
    case .deferred: .deferred
    case .rejected: .rejected
    case .restRejected: .restRejected
    case .persistenceFailed: .persistenceFailed
    case .locallyRejected: .locallyRejected
    }
  }
}
