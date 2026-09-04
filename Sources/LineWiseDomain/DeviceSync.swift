import Foundation

public struct DeviceID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum VisitCommandKind: String, CaseIterable, Codable, Sendable {
  case startVisit = "start_visit"
  case recordAttempt = "record_attempt"
  case markSend = "mark_send"
  case confirmNotSent = "confirm_not_sent"
  case undo
  case endVisit = "end_visit"
  case beginReview = "begin_review"
  case completeReview = "complete_review"
  case createRouteCard = "create_route_card"
  case reviseRouteCard = "revise_route_card"
  case archiveRouteCard = "archive_route_card"
  case restoreRouteCard = "restore_route_card"
  case correctRouteAvailability = "correct_route_availability"
  case confirmRouteCardMerge = "confirm_route_card_merge"
  case unmergeRouteCard = "unmerge_route_card"
  case correctAttemptRoute = "correct_attempt_route"
  case startProject = "start_project"
  case closeProjectSent = "close_project_sent"
  case archiveProject = "archive_project"
  case replaceRouteAfterReset = "replace_route_after_reset"
}

extension VisitCommand {
  public var stableActionID: ActionID {
    switch self {
    case .startVisit(let actionID, _, _, _),
      .recordAttempt(let actionID, _, _, _, _, _),
      .markSend(let actionID, _, _, _),
      .confirmNotSent(let actionID, _, _, _),
      .undo(let actionID, _, _, _),
      .endVisit(let actionID, _, _, _),
      .beginReview(let actionID, _, _, _),
      .completeReview(let actionID, _, _, _),
      .createRouteCard(let actionID, _, _, _, _, _),
      .reviseRouteCard(let actionID, _, _, _, _),
      .archiveRouteCard(let actionID, _, _, _),
      .restoreRouteCard(let actionID, _, _, _),
      .correctRouteAvailability(let actionID, _, _, _, _),
      .confirmRouteCardMerge(let actionID, _, _, _, _),
      .unmergeRouteCard(let actionID, _, _, _),
      .correctAttemptRoute(let actionID, _, _, _, _),
      .startProject(let actionID, _, _, _, _),
      .closeProjectSent(let actionID, _, _, _, _),
      .archiveProject(let actionID, _, _, _),
      .replaceRouteAfterReset(let actionID, _, _, _, _, _):
      actionID
    }
  }

  public var businessTime: Instant {
    switch self {
    case .startVisit(_, _, let occurredAt, _),
      .recordAttempt(_, _, _, _, let occurredAt, _),
      .markSend(_, _, let occurredAt, _),
      .confirmNotSent(_, _, let occurredAt, _),
      .undo(_, _, let occurredAt, _),
      .endVisit(_, _, let occurredAt, _),
      .beginReview(_, _, let occurredAt, _),
      .completeReview(_, _, let occurredAt, _),
      .createRouteCard(_, _, _, _, let occurredAt, _),
      .reviseRouteCard(_, _, _, let occurredAt, _),
      .archiveRouteCard(_, _, let occurredAt, _),
      .restoreRouteCard(_, _, let occurredAt, _),
      .correctRouteAvailability(_, _, _, let occurredAt, _),
      .confirmRouteCardMerge(_, _, _, let occurredAt, _),
      .unmergeRouteCard(_, _, let occurredAt, _),
      .correctAttemptRoute(_, _, _, let occurredAt, _),
      .startProject(_, _, _, let occurredAt, _),
      .closeProjectSent(_, _, _, let occurredAt, _),
      .archiveProject(_, _, let occurredAt, _),
      .replaceRouteAfterReset(_, _, _, _, let occurredAt, _):
      occurredAt
    }
  }

  public var kind: VisitCommandKind {
    switch self {
    case .startVisit: .startVisit
    case .recordAttempt: .recordAttempt
    case .markSend: .markSend
    case .confirmNotSent: .confirmNotSent
    case .undo: .undo
    case .endVisit: .endVisit
    case .beginReview: .beginReview
    case .completeReview: .completeReview
    case .createRouteCard: .createRouteCard
    case .reviseRouteCard: .reviseRouteCard
    case .archiveRouteCard: .archiveRouteCard
    case .restoreRouteCard: .restoreRouteCard
    case .correctRouteAvailability: .correctRouteAvailability
    case .confirmRouteCardMerge: .confirmRouteCardMerge
    case .unmergeRouteCard: .unmergeRouteCard
    case .correctAttemptRoute: .correctAttemptRoute
    case .startProject: .startProject
    case .closeProjectSent: .closeProjectSent
    case .archiveProject: .archiveProject
    case .replaceRouteAfterReset: .replaceRouteAfterReset
    }
  }

  fileprivate var replayPriority: Int {
    switch self {
    case .startVisit: 0
    case .createRouteCard: 1
    case .reviseRouteCard, .archiveRouteCard, .restoreRouteCard, .correctRouteAvailability: 2
    case .recordAttempt, .startProject: 3
    case .markSend, .confirmNotSent, .correctAttemptRoute: 4
    case .closeProjectSent, .archiveProject, .confirmRouteCardMerge, .unmergeRouteCard: 5
    case .endVisit, .replaceRouteAfterReset: 6
    case .beginReview: 7
    case .completeReview: 8
    case .undo: 9
    }
  }
}

public enum DeviceSyncError: Error, Equatable, Sendable, CustomStringConvertible {
  case emptyDeviceID
  case emptyActionID
  case invalidSequence(deviceID: DeviceID, sequence: UInt64)
  case conflictingEventID(ActionID)
  case conflictingSequence(deviceID: DeviceID, sequence: UInt64)
  case eventIDDoesNotMatchCommand(eventID: ActionID, commandActionID: ActionID)

  public var description: String {
    switch self {
    case .emptyDeviceID:
      "device ID must not be empty"
    case .emptyActionID:
      "action ID must not be empty"
    case .invalidSequence(let deviceID, let sequence):
      "device \(deviceID.rawValue) used invalid sequence \(sequence)"
    case .conflictingEventID(let actionID):
      "event ID \(actionID.rawValue) was reused for different content"
    case .conflictingSequence(let deviceID, let sequence):
      "device \(deviceID.rawValue) reused sequence \(sequence) for another event"
    case .eventIDDoesNotMatchCommand(let eventID, let commandActionID):
      "event ID \(eventID.rawValue) does not match command action ID \(commandActionID.rawValue)"
    }
  }
}

public struct DeviceEventEnvelope: Equatable, Codable, Sendable {
  public let eventID: ActionID
  public let originDeviceID: DeviceID
  public let sequence: UInt64
  public let recordedAt: Instant
  public let command: VisitCommand

  public init(
    originDeviceID: DeviceID,
    sequence: UInt64,
    recordedAt: Instant? = nil,
    command: VisitCommand
  ) {
    eventID = command.stableActionID
    self.originDeviceID = originDeviceID
    self.sequence = sequence
    self.recordedAt = recordedAt ?? command.businessTime
    self.command = command
  }

  private enum CodingKeys: String, CodingKey {
    case eventID
    case originDeviceID
    case sequence
    case recordedAt
    case command
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let eventID = ActionID(try container.decode(String.self, forKey: .eventID))
    let originDeviceID = DeviceID(
      try container.decode(String.self, forKey: .originDeviceID))
    let sequence = try container.decode(UInt64.self, forKey: .sequence)
    let recordedAt = Instant(
      millisecondsSince1970: try container.decode(Int64.self, forKey: .recordedAt))
    let command = try container.decode(VisitCommandWire.self, forKey: .command).command

    guard eventID == command.stableActionID else {
      throw DeviceSyncError.eventIDDoesNotMatchCommand(
        eventID: eventID,
        commandActionID: command.stableActionID
      )
    }

    self.eventID = eventID
    self.originDeviceID = originDeviceID
    self.sequence = sequence
    self.recordedAt = recordedAt
    self.command = command
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(eventID.rawValue, forKey: .eventID)
    try container.encode(originDeviceID.rawValue, forKey: .originDeviceID)
    try container.encode(sequence, forKey: .sequence)
    try container.encode(recordedAt.rawValue, forKey: .recordedAt)
    try container.encode(VisitCommandWire(command), forKey: .command)
  }
}

public struct DeviceInboxReceipt: Equatable, Sendable {
  public let insertedEventIDs: [ActionID]
  public let duplicateEventIDs: [ActionID]

  public init(insertedEventIDs: [ActionID], duplicateEventIDs: [ActionID]) {
    self.insertedEventIDs = insertedEventIDs
    self.duplicateEventIDs = duplicateEventIDs
  }
}

public struct DeviceEventInbox: Sendable {
  private struct OriginSequence: Hashable, Sendable {
    let originDeviceID: DeviceID
    let sequence: UInt64
  }

  private var eventsByID: [ActionID: DeviceEventEnvelope]
  private var eventIDByOriginSequence: [OriginSequence: ActionID]

  public init() {
    eventsByID = [:]
    eventIDByOriginSequence = [:]
  }

  public init(events: [DeviceEventEnvelope]) throws {
    self.init()
    _ = try receive(events)
  }

  public var events: [DeviceEventEnvelope] {
    eventsByID.values.sorted(by: DeviceEventEnvelope.replayOrder)
  }

  @discardableResult
  public mutating func receive(_ envelope: DeviceEventEnvelope) throws -> DeviceInboxReceipt {
    try receive([envelope])
  }

  @discardableResult
  public mutating func receive(_ envelopes: [DeviceEventEnvelope]) throws -> DeviceInboxReceipt {
    var candidate = self
    var insertedEventIDs: [ActionID] = []
    var duplicateEventIDs: [ActionID] = []

    for envelope in envelopes {
      try envelope.validateForTransport()

      if let existing = candidate.eventsByID[envelope.eventID] {
        guard existing == envelope else {
          throw DeviceSyncError.conflictingEventID(envelope.eventID)
        }
        duplicateEventIDs.append(envelope.eventID)
        continue
      }

      let originSequence = OriginSequence(
        originDeviceID: envelope.originDeviceID,
        sequence: envelope.sequence
      )
      if let existingEventID = candidate.eventIDByOriginSequence[originSequence] {
        guard existingEventID == envelope.eventID else {
          throw DeviceSyncError.conflictingSequence(
            deviceID: envelope.originDeviceID,
            sequence: envelope.sequence
          )
        }
      }

      candidate.eventsByID[envelope.eventID] = envelope
      candidate.eventIDByOriginSequence[originSequence] = envelope.eventID
      insertedEventIDs.append(envelope.eventID)
    }

    self = candidate
    return DeviceInboxReceipt(
      insertedEventIDs: insertedEventIDs,
      duplicateEventIDs: duplicateEventIDs
    )
  }
}

public struct DeviceEventOutbox: Sendable {
  public let originDeviceID: DeviceID
  private var eventsByID: [ActionID: DeviceEventEnvelope]
  private var acknowledgedEventIDs: Set<ActionID>
  private var nextSequence: UInt64

  public init(originDeviceID: DeviceID) {
    self.originDeviceID = originDeviceID
    eventsByID = [:]
    acknowledgedEventIDs = []
    nextSequence = 1
  }

  init(
    originDeviceID: DeviceID,
    events: [DeviceEventEnvelope],
    acknowledgedEventIDs: Set<ActionID>
  ) throws {
    self.init(originDeviceID: originDeviceID)
    let localEvents = events.filter { $0.originDeviceID == originDeviceID }
    var inbox = DeviceEventInbox()
    _ = try inbox.receive(localEvents)
    // `inbox.receive` tolerates an exact duplicate as idempotent redelivery, so
    // reaching here does not imply the list is unique. Building the index with
    // `uniqueKeysWithValues` would trap on a journal that recorded the same
    // locally-originated envelope twice — a crash on every launch, with no
    // recoverable error and no way for the user to reach their history. Keep the
    // first occurrence and report a genuine conflict instead.
    var index: [ActionID: DeviceEventEnvelope] = [:]
    for event in localEvents {
      if let existing = index[event.eventID] {
        guard existing == event else {
          throw DeviceSyncError.conflictingEventID(event.eventID)
        }
        continue
      }
      index[event.eventID] = event
    }
    eventsByID = index
    self.acknowledgedEventIDs = acknowledgedEventIDs.intersection(eventsByID.keys)
    nextSequence = (localEvents.map(\.sequence).max() ?? 0) + 1
  }

  public var pendingEvents: [DeviceEventEnvelope] {
    eventsByID.values
      .filter { !acknowledgedEventIDs.contains($0.eventID) }
      .sorted {
        if $0.sequence != $1.sequence {
          return $0.sequence < $1.sequence
        }
        return $0.eventID.rawValue < $1.eventID.rawValue
      }
  }

  @discardableResult
  public mutating func enqueue(
    _ command: VisitCommand,
    recordedAt: Instant? = nil
  ) throws -> DeviceEventEnvelope {
    guard !originDeviceID.rawValue.isEmpty else {
      throw DeviceSyncError.emptyDeviceID
    }
    guard !command.stableActionID.rawValue.isEmpty else {
      throw DeviceSyncError.emptyActionID
    }

    if let existing = eventsByID[command.stableActionID] {
      guard existing.command == command else {
        throw DeviceSyncError.conflictingEventID(command.stableActionID)
      }
      return existing
    }

    let envelope = DeviceEventEnvelope(
      originDeviceID: originDeviceID,
      sequence: nextSequence,
      recordedAt: recordedAt,
      command: command
    )
    eventsByID[envelope.eventID] = envelope
    nextSequence += 1
    return envelope
  }

  @discardableResult
  public mutating func acknowledge(_ eventID: ActionID) -> Bool {
    guard eventsByID[eventID] != nil else {
      return false
    }
    return acknowledgedEventIDs.insert(eventID).inserted
  }

  var allEvents: [DeviceEventEnvelope] {
    eventsByID.values.sorted { $0.sequence < $1.sequence }
  }

  var acknowledgements: Set<ActionID> {
    acknowledgedEventIDs
  }
}

extension DeviceEventEnvelope {
  fileprivate func validateForTransport() throws {
    guard !originDeviceID.rawValue.isEmpty else {
      throw DeviceSyncError.emptyDeviceID
    }
    guard !eventID.rawValue.isEmpty else {
      throw DeviceSyncError.emptyActionID
    }
    guard sequence > 0 else {
      throw DeviceSyncError.invalidSequence(
        deviceID: originDeviceID,
        sequence: sequence
      )
    }
    guard eventID == command.stableActionID else {
      throw DeviceSyncError.eventIDDoesNotMatchCommand(
        eventID: eventID,
        commandActionID: command.stableActionID
      )
    }
  }

  public static func replayOrder(
    _ lhs: DeviceEventEnvelope,
    _ rhs: DeviceEventEnvelope
  ) -> Bool {
    if lhs.command.businessTime != rhs.command.businessTime {
      return lhs.command.businessTime < rhs.command.businessTime
    }
    if lhs.command.replayPriority != rhs.command.replayPriority {
      return lhs.command.replayPriority < rhs.command.replayPriority
    }
    return lhs.eventID.rawValue < rhs.eventID.rawValue
  }
}

struct VisitCommandWire: Codable {
  let kind: VisitCommandKind
  let actionID: String
  let visitID: String?
  let attemptID: String?
  let routeCardID: String?
  let targetActionID: String?
  let projectID: String?
  let supportingAttemptID: String?
  let oldRouteCardID: String?
  let successorRouteCardID: String?
  let label: String?
  let successorLabel: String?
  let availability: RouteAvailability?
  let occurredAt: Int64
  let source: CaptureSource

  init(_ command: VisitCommand) {
    kind = command.kind
    actionID = command.stableActionID.rawValue
    occurredAt = command.businessTime.rawValue

    switch command {
    case .startVisit(_, let visitID, _, let source):
      self.visitID = visitID.rawValue
      attemptID = nil
      routeCardID = nil
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .recordAttempt(_, let attemptID, let visitID, let routeCardID, _, let source):
      self.visitID = visitID.rawValue
      self.attemptID = attemptID.rawValue
      self.routeCardID = routeCardID?.rawValue
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .markSend(_, let attemptID, _, let source),
      .confirmNotSent(_, let attemptID, _, let source):
      visitID = nil
      self.attemptID = attemptID.rawValue
      routeCardID = nil
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .undo(_, let targetActionID, _, let source):
      visitID = nil
      attemptID = nil
      routeCardID = nil
      self.targetActionID = targetActionID.rawValue
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .endVisit(_, let visitID, _, let source),
      .beginReview(_, let visitID, _, let source),
      .completeReview(_, let visitID, _, let source):
      self.visitID = visitID.rawValue
      attemptID = nil
      routeCardID = nil
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .createRouteCard(_, let routeCardID, let label, let availability, _, let source):
      visitID = nil
      attemptID = nil
      self.routeCardID = routeCardID.rawValue
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      self.label = label
      successorLabel = nil
      self.availability = availability
      self.source = source
    case .reviseRouteCard(_, let routeCardID, let revisedLabel, _, let source):
      visitID = nil
      attemptID = nil
      self.routeCardID = routeCardID.rawValue
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = revisedLabel
      successorLabel = nil
      availability = nil
      self.source = source
    case .archiveRouteCard(_, let routeCardID, _, let source),
      .restoreRouteCard(_, let routeCardID, _, let source):
      visitID = nil
      attemptID = nil
      self.routeCardID = routeCardID.rawValue
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .correctRouteAvailability(
      _, let routeCardID, let availability, _, let source
    ):
      visitID = nil
      attemptID = nil
      self.routeCardID = routeCardID.rawValue
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      self.availability = availability
      self.source = source
    case .confirmRouteCardMerge(
      _, let duplicateRouteCardID, let canonicalRouteCardID, _, let source
    ):
      visitID = nil
      attemptID = nil
      routeCardID = nil
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = duplicateRouteCardID.rawValue
      successorRouteCardID = canonicalRouteCardID.rawValue
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .unmergeRouteCard(_, let mergedRouteCardID, _, let source):
      visitID = nil
      attemptID = nil
      routeCardID = nil
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = mergedRouteCardID.rawValue
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .correctAttemptRoute(_, let attemptID, let routeCardID, _, let source):
      visitID = nil
      self.attemptID = attemptID.rawValue
      self.routeCardID = routeCardID?.rawValue
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .startProject(_, let projectID, let routeCardID, _, let source):
      visitID = nil
      attemptID = nil
      self.routeCardID = routeCardID.rawValue
      targetActionID = nil
      self.projectID = projectID.rawValue
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .closeProjectSent(
      _, let projectID, let supportingAttemptID, _, let source
    ):
      visitID = nil
      attemptID = nil
      routeCardID = nil
      targetActionID = nil
      self.projectID = projectID.rawValue
      self.supportingAttemptID = supportingAttemptID.rawValue
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .archiveProject(_, let projectID, _, let source):
      visitID = nil
      attemptID = nil
      routeCardID = nil
      targetActionID = nil
      self.projectID = projectID.rawValue
      supportingAttemptID = nil
      oldRouteCardID = nil
      successorRouteCardID = nil
      label = nil
      successorLabel = nil
      availability = nil
      self.source = source
    case .replaceRouteAfterReset(
      _, let oldRouteCardID, let successorRouteCardID, let successorLabel, _, let source
    ):
      visitID = nil
      attemptID = nil
      routeCardID = nil
      targetActionID = nil
      projectID = nil
      supportingAttemptID = nil
      self.oldRouteCardID = oldRouteCardID.rawValue
      self.successorRouteCardID = successorRouteCardID.rawValue
      label = nil
      self.successorLabel = successorLabel
      availability = nil
      self.source = source
    }
  }

  var command: VisitCommand {
    get throws {
      let actionID = ActionID(actionID)
      let occurredAt = Instant(millisecondsSince1970: occurredAt)

      switch kind {
      case .startVisit:
        return .startVisit(
          actionID: actionID,
          visitID: GymVisitID(try require(visitID, "visitID")),
          occurredAt: occurredAt,
          source: source
        )
      case .recordAttempt:
        return .recordAttempt(
          actionID: actionID,
          attemptID: AttemptID(try require(attemptID, "attemptID")),
          visitID: GymVisitID(try require(visitID, "visitID")),
          routeCardID: routeCardID.map { RouteCardID($0) },
          occurredAt: occurredAt,
          source: source
        )
      case .markSend:
        return .markSend(
          actionID: actionID,
          attemptID: AttemptID(try require(attemptID, "attemptID")),
          occurredAt: occurredAt,
          source: source
        )
      case .confirmNotSent:
        return .confirmNotSent(
          actionID: actionID,
          attemptID: AttemptID(try require(attemptID, "attemptID")),
          occurredAt: occurredAt,
          source: source
        )
      case .undo:
        return .undo(
          actionID: actionID,
          targetActionID: ActionID(try require(targetActionID, "targetActionID")),
          occurredAt: occurredAt,
          source: source
        )
      case .endVisit:
        return .endVisit(
          actionID: actionID,
          visitID: GymVisitID(try require(visitID, "visitID")),
          occurredAt: occurredAt,
          source: source
        )
      case .beginReview:
        return .beginReview(
          actionID: actionID,
          visitID: GymVisitID(try require(visitID, "visitID")),
          occurredAt: occurredAt,
          source: source
        )
      case .completeReview:
        return .completeReview(
          actionID: actionID,
          visitID: GymVisitID(try require(visitID, "visitID")),
          occurredAt: occurredAt,
          source: source
        )
      case .createRouteCard:
        return .createRouteCard(
          actionID: actionID,
          routeCardID: RouteCardID(try require(routeCardID, "routeCardID")),
          label: try require(label, "label"),
          availability: try require(availability, "availability"),
          occurredAt: occurredAt,
          source: source
        )
      case .reviseRouteCard:
        return .reviseRouteCard(
          actionID: actionID,
          routeCardID: RouteCardID(try require(routeCardID, "routeCardID")),
          revisedLabel: try require(label, "label"),
          occurredAt: occurredAt,
          source: source
        )
      case .archiveRouteCard:
        return .archiveRouteCard(
          actionID: actionID,
          routeCardID: RouteCardID(try require(routeCardID, "routeCardID")),
          occurredAt: occurredAt,
          source: source
        )
      case .restoreRouteCard:
        return .restoreRouteCard(
          actionID: actionID,
          routeCardID: RouteCardID(try require(routeCardID, "routeCardID")),
          occurredAt: occurredAt,
          source: source
        )
      case .correctRouteAvailability:
        return .correctRouteAvailability(
          actionID: actionID,
          routeCardID: RouteCardID(try require(routeCardID, "routeCardID")),
          availability: try require(availability, "availability"),
          occurredAt: occurredAt,
          source: source
        )
      case .confirmRouteCardMerge:
        return .confirmRouteCardMerge(
          actionID: actionID,
          duplicateRouteCardID: RouteCardID(
            try require(oldRouteCardID, "duplicateRouteCardID")),
          canonicalRouteCardID: RouteCardID(
            try require(successorRouteCardID, "canonicalRouteCardID")),
          occurredAt: occurredAt,
          source: source
        )
      case .unmergeRouteCard:
        return .unmergeRouteCard(
          actionID: actionID,
          mergedRouteCardID: RouteCardID(
            try require(oldRouteCardID, "mergedRouteCardID")),
          occurredAt: occurredAt,
          source: source
        )
      case .correctAttemptRoute:
        return .correctAttemptRoute(
          actionID: actionID,
          attemptID: AttemptID(try require(attemptID, "attemptID")),
          routeCardID: routeCardID.map { RouteCardID($0) },
          occurredAt: occurredAt,
          source: source
        )
      case .startProject:
        return .startProject(
          actionID: actionID,
          projectID: ProjectID(try require(projectID, "projectID")),
          routeCardID: RouteCardID(try require(routeCardID, "routeCardID")),
          occurredAt: occurredAt,
          source: source
        )
      case .closeProjectSent:
        return .closeProjectSent(
          actionID: actionID,
          projectID: ProjectID(try require(projectID, "projectID")),
          supportingAttemptID: AttemptID(
            try require(supportingAttemptID, "supportingAttemptID")),
          occurredAt: occurredAt,
          source: source
        )
      case .archiveProject:
        return .archiveProject(
          actionID: actionID,
          projectID: ProjectID(try require(projectID, "projectID")),
          occurredAt: occurredAt,
          source: source
        )
      case .replaceRouteAfterReset:
        return .replaceRouteAfterReset(
          actionID: actionID,
          oldRouteCardID: RouteCardID(try require(oldRouteCardID, "oldRouteCardID")),
          successorRouteCardID: RouteCardID(
            try require(successorRouteCardID, "successorRouteCardID")),
          successorLabel: try require(successorLabel, "successorLabel"),
          occurredAt: occurredAt,
          source: source
        )
      }
    }
  }
}

private func require<Value>(_ value: Value?, _ field: String) throws -> Value {
  guard let value else {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: [],
        debugDescription: "missing \(field) for persisted VisitCommand"
      ))
  }
  return value
}
