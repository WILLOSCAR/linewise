import Foundation

public enum DeviceTransferCompletion: Equatable, Sendable {
  case succeeded
  case failed(String)
}

/// Correlates an asynchronous transport callback with the task that initiated
/// the transfer. Callers prepare a unique ID before invoking the platform API.
/// This makes callback-before-wait safe, ignores duplicate callbacks, and keeps
/// independent transfers isolated under Swift concurrency.
public actor DeviceTransferCompletionRegistry<TransferID: Hashable & Sendable> {
  private enum State {
    case pending
    case completed(DeviceTransferCompletion)
    case waiting([CheckedContinuation<DeviceTransferCompletion, Never>])
  }

  private var states: [TransferID: State] = [:]

  public init() {}

  public func prepare(_ transferID: TransferID) {
    guard states[transferID] == nil else { return }
    states[transferID] = .pending
  }

  public func wait(for transferID: TransferID) async -> DeviceTransferCompletion {
    await withCheckedContinuation { continuation in
      switch states[transferID] {
      case .pending:
        states[transferID] = .waiting([continuation])
      case .completed(let completion):
        states.removeValue(forKey: transferID)
        continuation.resume(returning: completion)
      case .waiting(var continuations):
        continuations.append(continuation)
        states[transferID] = .waiting(continuations)
      case nil:
        continuation.resume(
          returning: .failed("Transfer completion was not prepared")
        )
      }
    }
  }

  /// Waits for a transport callback that a platform may never deliver.
  ///
  /// WatchConnectivity does not guarantee `didFinish` — the counterpart app may
  /// not be installed, the pairing can break mid-flight, the session can
  /// deactivate, or the process can be relaunched with the in-memory registry
  /// gone. An unbounded wait therefore freezes the whole outbox flush and the
  /// sync poll loop behind one transfer. Timing out reports an explicit failure
  /// instead: the durable event stays unacknowledged and the next flush retries
  /// it under the same stable ActionID, so a late real callback is harmless.
  public func wait(
    for transferID: TransferID,
    timeoutNanoseconds: UInt64
  ) async -> DeviceTransferCompletion {
    let deadline = Task { [weak self] in
      try? await Task.sleep(nanoseconds: timeoutNanoseconds)
      guard !Task.isCancelled else { return }
      await self?.timeOut(transferID, afterNanoseconds: timeoutNanoseconds)
    }
    let completion = await wait(for: transferID)
    deadline.cancel()
    return completion
  }

  private func timeOut(_ transferID: TransferID, afterNanoseconds nanoseconds: UInt64) {
    let seconds = Double(nanoseconds) / 1_000_000_000
    complete(
      .failed("the device transport did not confirm within \(seconds) seconds"),
      for: transferID
    )
  }

  public func complete(
    _ completion: DeviceTransferCompletion,
    for transferID: TransferID
  ) {
    switch states[transferID] {
    case .pending:
      states[transferID] = .completed(completion)
    case .waiting(let continuations):
      states.removeValue(forKey: transferID)
      for continuation in continuations {
        continuation.resume(returning: completion)
      }
    case .completed, nil:
      // The first callback is authoritative. A duplicate callback, including
      // one racing after a waiter consumed the result, must never resume twice.
      return
    }
  }
}

public struct DevicePayloadID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct ReceivedDevicePayload: Equatable, Codable, Sendable {
  public let id: DevicePayloadID
  public let payload: Data

  public init(id: DevicePayloadID, payload: Data) {
    self.id = id
    self.payload = payload
  }
}

public enum DevicePayloadInboxError: Error, Equatable, Sendable, CustomStringConvertible {
  case emptyPayloadID
  case payloadIDCollision(DevicePayloadID)
  case corruptedStore(String)
  case unsupportedSchemaVersion(Int)
  case ioFailure(operation: String, path: String, reason: String)
  case delegatePersistenceFailed(String)

  public var description: String {
    switch self {
    case .emptyPayloadID:
      "Device payload ID cannot be empty"
    case .payloadIDCollision(let id):
      "Device payload ID \(id.rawValue) was reused for different bytes"
    case .corruptedStore(let reason):
      "Device payload inbox is corrupted: \(reason)"
    case .unsupportedSchemaVersion(let version):
      "Device payload inbox schema \(version) is not supported"
    case .ioFailure(let operation, let path, let reason):
      "Device payload inbox could not \(operation) \(path): \(reason)"
    case .delegatePersistenceFailed(let reason):
      "Device payload delegate could not persist inbound bytes: \(reason)"
    }
  }
}

public protocol DevicePayloadInboxStore: AnyObject {
  func load() throws -> [ReceivedDevicePayload]
  func save(_ payloads: [ReceivedDevicePayload]) throws
}

public final class MemoryDevicePayloadInboxStore: DevicePayloadInboxStore {
  private var payloads: [ReceivedDevicePayload]

  public init(payloads: [ReceivedDevicePayload] = []) {
    self.payloads = payloads
  }

  public func load() throws -> [ReceivedDevicePayload] {
    payloads
  }

  public func save(_ payloads: [ReceivedDevicePayload]) throws {
    self.payloads = payloads
  }
}

public final class FoundationFileDevicePayloadInboxStore: DevicePayloadInboxStore {
  private struct Journal: Codable {
    let schemaVersion: Int
    let payloads: [ReceivedDevicePayload]
  }

  public static let currentSchemaVersion = 1

  public let fileURL: URL
  private let fileManager: FileManager

  public init(fileURL: URL, fileManager: FileManager = .default) {
    self.fileURL = fileURL
    self.fileManager = fileManager
  }

  public func load() throws -> [ReceivedDevicePayload] {
    guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
    let data: Data
    do {
      data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
    } catch {
      throw DevicePayloadInboxError.ioFailure(
        operation: "read",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }

    let journal: Journal
    do {
      journal = try JSONDecoder().decode(Journal.self, from: data)
    } catch {
      throw DevicePayloadInboxError.corruptedStore(String(describing: error))
    }
    guard journal.schemaVersion == Self.currentSchemaVersion else {
      throw DevicePayloadInboxError.unsupportedSchemaVersion(journal.schemaVersion)
    }
    return journal.payloads
  }

  public func save(_ payloads: [ReceivedDevicePayload]) throws {
    let journal = Journal(
      schemaVersion: Self.currentSchemaVersion,
      payloads: payloads
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data: Data
    do {
      data = try encoder.encode(journal)
    } catch {
      throw DevicePayloadInboxError.corruptedStore(String(describing: error))
    }

    do {
      try fileManager.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: fileURL, options: .atomic)
    } catch {
      throw DevicePayloadInboxError.ioFailure(
        operation: "atomically write",
        path: fileURL.path,
        reason: error.localizedDescription
      )
    }
  }
}

/// A process-safe boundary for payloads delivered by platform callbacks.
/// State mutates only after the backing store has atomically accepted the
/// proposed journal, so a failed write leaves the last durable state intact.
public final class DurableDevicePayloadInbox: @unchecked Sendable {
  private let store: any DevicePayloadInboxStore
  private let lock = NSLock()
  private var payloads: [ReceivedDevicePayload]
  private var unreportedDeliveryFault: DevicePayloadInboxError?

  public init() {
    store = MemoryDevicePayloadInboxStore()
    payloads = []
  }

  public init(store: any DevicePayloadInboxStore) throws {
    self.store = store
    let payloads = try store.load()
    try Self.validate(payloads)
    self.payloads = payloads
  }

  public var pendingPayloads: [ReceivedDevicePayload] {
    lock.withLock { payloads }
  }

  /// Records that a platform delegate callback could not persist inbound bytes.
  ///
  /// The bytes are lost, but the peer has not acknowledged them either, so the
  /// event is still recoverable by redelivery. The fault exists only to stay
  /// visible; it must never become a reason to withhold data.
  public func recordDeliveryFault(_ error: DevicePayloadInboxError) {
    lock.withLock { unreportedDeliveryFault = error }
  }

  /// Reads the durable inbox, reporting at most one delivery fault.
  ///
  /// A fault is reported only when there is nothing durable to hand over.
  /// Payloads that were already committed are confirmed peer events, and a
  /// later unrelated write failure must not hide them — doing so leaves
  /// late or conflicting events that should reopen review sitting unprocessed
  /// indefinitely, even after the fault has cleared. Each fault is reported
  /// once so an idle inbox does not throw forever.
  public func readPendingPayloadsReportingFault() throws -> [ReceivedDevicePayload] {
    try lock.withLock {
      let fault = unreportedDeliveryFault
      unreportedDeliveryFault = nil
      if payloads.isEmpty, let fault {
        throw fault
      }
      return payloads
    }
  }

  @discardableResult
  public func receive(_ payload: ReceivedDevicePayload) throws -> Bool {
    try lock.withLock {
      guard !payload.id.rawValue.isEmpty else {
        throw DevicePayloadInboxError.emptyPayloadID
      }
      if let existing = payloads.first(where: { $0.id == payload.id }) {
        guard existing.payload == payload.payload else {
          throw DevicePayloadInboxError.payloadIDCollision(payload.id)
        }
        return false
      }
      let proposed = payloads + [payload]
      try store.save(proposed)
      payloads = proposed
      return true
    }
  }

  public func acknowledge(_ payloadIDs: [DevicePayloadID]) throws {
    try lock.withLock {
      let acknowledged = Set(payloadIDs)
      guard !acknowledged.isEmpty else { return }
      let proposed = payloads.filter { !acknowledged.contains($0.id) }
      guard proposed.count != payloads.count else { return }
      try store.save(proposed)
      payloads = proposed
    }
  }

  private static func validate(_ payloads: [ReceivedDevicePayload]) throws {
    var seen: [DevicePayloadID: Data] = [:]
    for payload in payloads {
      guard !payload.id.rawValue.isEmpty else {
        throw DevicePayloadInboxError.emptyPayloadID
      }
      if let existing = seen[payload.id], existing != payload.payload {
        throw DevicePayloadInboxError.payloadIDCollision(payload.id)
      }
      guard seen[payload.id] == nil else {
        throw DevicePayloadInboxError.corruptedStore(
          "duplicate payload ID \(payload.id.rawValue)"
        )
      }
      seen[payload.id] = payload.payload
    }
  }
}
