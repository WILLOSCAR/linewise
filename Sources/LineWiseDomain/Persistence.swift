import Foundation

public enum VisitPersistenceError: Error, Equatable, Sendable, CustomStringConvertible {
  case corruptedStore(String)
  case unsupportedSchemaVersion(Int)
  case ioFailure(operation: String, path: String, reason: String)

  public var description: String {
    switch self {
    case .corruptedStore(let reason):
      "LineWise event store is corrupted: \(reason)"
    case .unsupportedSchemaVersion(let version):
      "LineWise event store schema \(version) is not supported"
    case .ioFailure(let operation, let path, let reason):
      "LineWise could not \(operation) \(path): \(reason)"
    }
  }
}

public struct VisitEventJournal: Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public let schemaVersion: Int
  public let events: [DeviceEventEnvelope]
  public let acknowledgedOutboundEventIDs: Set<ActionID>

  public init(
    events: [DeviceEventEnvelope] = [],
    acknowledgedOutboundEventIDs: Set<ActionID> = []
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.events = events
    self.acknowledgedOutboundEventIDs = acknowledgedOutboundEventIDs
  }
}

public protocol VisitEventStore: AnyObject {
  func load() throws -> VisitEventJournal
  func save(_ journal: VisitEventJournal) throws
  func delete() throws
}

public final class MemoryVisitEventStore: VisitEventStore {
  private var journal: VisitEventJournal

  public init(journal: VisitEventJournal = VisitEventJournal()) {
    self.journal = journal
  }

  public func load() throws -> VisitEventJournal {
    journal
  }

  public func save(_ journal: VisitEventJournal) throws {
    try validate(journal)
    self.journal = journal
  }

  public func delete() throws {
    journal = VisitEventJournal()
  }
}

public final class FoundationFileVisitEventStore: VisitEventStore {
  public let fileURL: URL
  private let fileManager: FileManager

  public init(fileURL: URL, fileManager: FileManager = .default) {
    self.fileURL = fileURL
    self.fileManager = fileManager
  }

  public func load() throws -> VisitEventJournal {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      return VisitEventJournal()
    }

    let data: Data
    do {
      data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
    } catch {
      throw VisitPersistenceError.ioFailure(
        operation: "read",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }

    let decoded = try VisitJournalCodec.decode(data)
    if decoded.wasMigrated {
      try save(decoded.journal)
    }
    return decoded.journal
  }

  public func save(_ journal: VisitEventJournal) throws {
    try validate(journal)
    let data = try VisitJournalCodec.encode(journal)
    let directoryURL = fileURL.deletingLastPathComponent()

    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )
      try data.write(to: fileURL, options: .atomic)
    } catch {
      throw VisitPersistenceError.ioFailure(
        operation: "atomically write",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }

  public func delete() throws {
    guard fileManager.fileExists(atPath: fileURL.path) else {
      return
    }
    do {
      try fileManager.removeItem(at: fileURL)
    } catch {
      throw VisitPersistenceError.ioFailure(
        operation: "delete",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }
}

public enum DeviceReceiveResult: Equatable, Sendable {
  case inserted(CommandOutcome)
  case duplicate
}

public final class VisitRepository {
  private let store: any VisitEventStore
  private let localDeviceID: DeviceID
  private var journal: VisitEventJournal
  private var inbox: DeviceEventInbox
  private var outbox: DeviceEventOutbox
  private var replayEngine: IncrementalVisitReplay

  public init(store: any VisitEventStore, localDeviceID: DeviceID) throws {
    guard !localDeviceID.rawValue.isEmpty else {
      throw DeviceSyncError.emptyDeviceID
    }

    let journal = try store.load()
    try validate(journal)
    let inbox = try DeviceEventInbox(events: journal.events)
    let outbox = try DeviceEventOutbox(
      originDeviceID: localDeviceID,
      events: journal.events,
      acknowledgedEventIDs: journal.acknowledgedOutboundEventIDs
    )

    self.store = store
    self.localDeviceID = localDeviceID
    self.journal = journal
    self.inbox = inbox
    self.outbox = outbox
    replayEngine = IncrementalVisitReplay(events: inbox.events)
  }

  public var snapshot: VisitSnapshot {
    replayEngine.state.snapshot
  }

  public var deviceID: DeviceID {
    localDeviceID
  }

  public var pendingOutboundEvents: [DeviceEventEnvelope] {
    outbox.pendingEvents
  }

  public var persistedEvents: [DeviceEventEnvelope] {
    inbox.events
  }

  @discardableResult
  public func submit(_ command: VisitCommand) throws -> CommandOutcome {
    var proposedOutbox = outbox
    let envelope = try proposedOutbox.enqueue(command)

    if inbox.events.contains(where: { $0.eventID == envelope.eventID }) {
      return .duplicate
    }

    var proposedInbox = inbox
    _ = try proposedInbox.receive(envelope)
    var proposedEngine = replayEngine
    let outcome = proposedEngine.insert(envelope)
    let proposedJournal = VisitEventJournal(
      events: proposedInbox.events,
      acknowledgedOutboundEventIDs: journal.acknowledgedOutboundEventIDs
    )
    try store.save(proposedJournal)

    inbox = proposedInbox
    outbox = proposedOutbox
    journal = proposedJournal
    replayEngine = proposedEngine
    return outcome
  }

  @discardableResult
  public func receive(_ envelope: DeviceEventEnvelope) throws -> DeviceReceiveResult {
    var proposedInbox = inbox
    let receipt = try proposedInbox.receive(envelope)
    guard !receipt.insertedEventIDs.isEmpty else {
      return .duplicate
    }

    var proposedEngine = replayEngine
    let outcome = proposedEngine.insert(envelope)
    let proposedJournal = VisitEventJournal(
      events: proposedInbox.events,
      acknowledgedOutboundEventIDs: journal.acknowledgedOutboundEventIDs
    )
    try store.save(proposedJournal)

    inbox = proposedInbox
    journal = proposedJournal
    replayEngine = proposedEngine
    return .inserted(outcome)
  }

  @discardableResult
  public func receive(_ envelopes: [DeviceEventEnvelope]) throws -> DeviceInboxReceipt {
    var proposedInbox = inbox
    let receipt = try proposedInbox.receive(envelopes)
    guard !receipt.insertedEventIDs.isEmpty else {
      return receipt
    }

    var proposedEngine = replayEngine
    let insertedIDs = Set(receipt.insertedEventIDs)
    for envelope in proposedInbox.events where insertedIDs.contains(envelope.eventID) {
      proposedEngine.insert(envelope)
    }
    let proposedJournal = VisitEventJournal(
      events: proposedInbox.events,
      acknowledgedOutboundEventIDs: journal.acknowledgedOutboundEventIDs
    )
    try store.save(proposedJournal)

    inbox = proposedInbox
    journal = proposedJournal
    replayEngine = proposedEngine
    return receipt
  }

  @discardableResult
  public func acknowledgeOutbound(_ eventID: ActionID) throws -> Bool {
    var proposedOutbox = outbox
    guard proposedOutbox.acknowledge(eventID) else {
      return false
    }
    var acknowledgements = journal.acknowledgedOutboundEventIDs
    acknowledgements.insert(eventID)
    let proposedJournal = VisitEventJournal(
      events: journal.events,
      acknowledgedOutboundEventIDs: acknowledgements
    )
    try store.save(proposedJournal)

    outbox = proposedOutbox
    journal = proposedJournal
    return true
  }

  public func reload() throws {
    let loaded = try store.load()
    try validate(loaded)
    let proposedInbox = try DeviceEventInbox(events: loaded.events)
    let proposedOutbox = try DeviceEventOutbox(
      originDeviceID: localDeviceID,
      events: loaded.events,
      acknowledgedEventIDs: loaded.acknowledgedOutboundEventIDs
    )

    journal = loaded
    inbox = proposedInbox
    outbox = proposedOutbox
    replayEngine = IncrementalVisitReplay(events: proposedInbox.events)
  }

  func exportJournal() -> VisitEventJournal {
    journal
  }

  func deleteAllData() throws {
    try store.delete()
    journal = VisitEventJournal()
    inbox = DeviceEventInbox()
    outbox = DeviceEventOutbox(originDeviceID: localDeviceID)
    replayEngine = IncrementalVisitReplay()
  }
}

private func validate(_ journal: VisitEventJournal) throws {
  guard journal.schemaVersion == VisitEventJournal.currentSchemaVersion else {
    throw VisitPersistenceError.unsupportedSchemaVersion(journal.schemaVersion)
  }
  do {
    _ = try DeviceEventInbox(events: journal.events)
  } catch {
    throw VisitPersistenceError.corruptedStore(String(describing: error))
  }
  let eventIDs = Set(journal.events.map(\.eventID))
  let danglingAcknowledgements = journal.acknowledgedOutboundEventIDs.subtracting(eventIDs)
  guard danglingAcknowledgements.isEmpty else {
    throw VisitPersistenceError.corruptedStore(
      "outbox acknowledgments reference events that do not exist"
    )
  }
}

enum VisitJournalCodec {
  struct DecodeResult {
    let journal: VisitEventJournal
    let wasMigrated: Bool
  }

  private struct SchemaHeader: Decodable {
    let schemaVersion: Int
  }

  private struct DiskJournalV1: Codable {
    let schemaVersion: Int
    let events: [DeviceEventEnvelope]
    let acknowledgedOutboundEventIDs: [String]
  }

  private struct DiskJournalV0: Decodable {
    let schemaVersion: Int
    let commands: [VisitCommandWire]
  }

  static func encode(_ journal: VisitEventJournal) throws -> Data {
    try validate(journal)
    let disk = DiskJournalV1(
      schemaVersion: VisitEventJournal.currentSchemaVersion,
      events: journal.events.sorted(by: DeviceEventEnvelope.replayOrder),
      acknowledgedOutboundEventIDs: journal.acknowledgedOutboundEventIDs
        .map(\.rawValue)
        .sorted()
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      return try encoder.encode(disk)
    } catch {
      throw VisitPersistenceError.corruptedStore(
        "could not encode current journal: \(error.localizedDescription)"
      )
    }
  }

  static func decode(_ data: Data) throws -> DecodeResult {
    guard !data.isEmpty else {
      throw VisitPersistenceError.corruptedStore("file is empty")
    }

    let decoder = JSONDecoder()
    let schemaVersion: Int
    do {
      schemaVersion = try decoder.decode(SchemaHeader.self, from: data).schemaVersion
    } catch {
      throw VisitPersistenceError.corruptedStore(
        "missing or invalid schemaVersion: \(error.localizedDescription)"
      )
    }

    do {
      switch schemaVersion {
      case 0:
        let legacy = try decoder.decode(DiskJournalV0.self, from: data)
        let events = try legacy.commands.enumerated().map { offset, wire in
          let command = try wire.command
          return DeviceEventEnvelope(
            originDeviceID: DeviceID("legacy-\(wire.source.rawValue)"),
            sequence: UInt64(offset + 1),
            command: command
          )
        }
        let journal = VisitEventJournal(events: events)
        try validate(journal)
        return DecodeResult(journal: journal, wasMigrated: true)

      case VisitEventJournal.currentSchemaVersion:
        let disk = try decoder.decode(DiskJournalV1.self, from: data)
        let journal = VisitEventJournal(
          events: disk.events,
          acknowledgedOutboundEventIDs: Set(
            disk.acknowledgedOutboundEventIDs.map { ActionID($0) })
        )
        try validate(journal)
        return DecodeResult(journal: journal, wasMigrated: false)

      default:
        throw VisitPersistenceError.unsupportedSchemaVersion(schemaVersion)
      }
    } catch let error as VisitPersistenceError {
      throw error
    } catch {
      throw VisitPersistenceError.corruptedStore(error.localizedDescription)
    }
  }
}
