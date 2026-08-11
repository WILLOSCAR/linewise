import Foundation

public struct RedactedDebugBundle: Equatable, Codable, Sendable {
  public let schemaVersion: Int
  public let eventCount: Int
  public let eventCountsByKind: [String: Int]
  public let originDeviceCount: Int
  public let pendingOutboundEventCount: Int
  public let visitCount: Int
  public let attemptCount: Int
  public let unresolvedAttemptCount: Int
  public let routeCardCount: Int
  public let projectCount: Int
  public let pendingDomainActionCount: Int
  public let reconciliationIssueCount: Int

  public init(
    schemaVersion: Int,
    eventCount: Int,
    eventCountsByKind: [String: Int],
    originDeviceCount: Int,
    pendingOutboundEventCount: Int,
    visitCount: Int,
    attemptCount: Int,
    unresolvedAttemptCount: Int,
    routeCardCount: Int,
    projectCount: Int,
    pendingDomainActionCount: Int,
    reconciliationIssueCount: Int
  ) {
    self.schemaVersion = schemaVersion
    self.eventCount = eventCount
    self.eventCountsByKind = eventCountsByKind
    self.originDeviceCount = originDeviceCount
    self.pendingOutboundEventCount = pendingOutboundEventCount
    self.visitCount = visitCount
    self.attemptCount = attemptCount
    self.unresolvedAttemptCount = unresolvedAttemptCount
    self.routeCardCount = routeCardCount
    self.projectCount = projectCount
    self.pendingDomainActionCount = pendingDomainActionCount
    self.reconciliationIssueCount = reconciliationIssueCount
  }
}

public final class LineWiseDataLifecycle {
  private let repository: VisitRepository

  public init(repository: VisitRepository) {
    self.repository = repository
  }

  public func exportData() throws -> Data {
    try VisitJournalCodec.encode(repository.exportJournal())
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
      throw VisitPersistenceError.ioFailure(
        operation: "atomically export",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }

  public func redactedDebugSummary() -> RedactedDebugBundle {
    let journal = repository.exportJournal()
    let snapshot = repository.snapshot
    let countsByKind = Dictionary(grouping: journal.events, by: { $0.command.kind })
      .mapValues(\.count)
      .reduce(into: [String: Int]()) { result, element in
        result[element.key.rawValue] = element.value
      }

    return RedactedDebugBundle(
      schemaVersion: journal.schemaVersion,
      eventCount: journal.events.count,
      eventCountsByKind: countsByKind,
      originDeviceCount: Set(journal.events.map(\.originDeviceID)).count,
      pendingOutboundEventCount: repository.pendingOutboundEvents.count,
      visitCount: snapshot.visits.count,
      attemptCount: snapshot.attempts.count,
      unresolvedAttemptCount: snapshot.attempts.filter { $0.outcome == .unresolved }.count,
      routeCardCount: snapshot.routeCards.count,
      projectCount: snapshot.projects.count,
      pendingDomainActionCount: snapshot.pendingActionIDs.count,
      reconciliationIssueCount: snapshot.reconciliationIssues.count
    )
  }

  public func redactedDebugBundle() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(redactedDebugSummary())
  }

  public func deleteAllData() throws {
    try repository.deleteAllData()
  }
}
