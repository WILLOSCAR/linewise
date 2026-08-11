public struct RestIntervalID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum RestIntervalState: String, Codable, Sendable {
  case active
  case completed
}

public struct RestIntervalSnapshot: Equatable, Codable, Sendable {
  public let id: RestIntervalID
  public let visitID: GymVisitID
  public let afterAttemptID: AttemptID?
  public let startedAt: Instant
  public let endedAt: Instant?
  public let state: RestIntervalState

  public init(
    id: RestIntervalID,
    visitID: GymVisitID,
    afterAttemptID: AttemptID?,
    startedAt: Instant,
    endedAt: Instant?,
    state: RestIntervalState
  ) {
    self.id = id
    self.visitID = visitID
    self.afterAttemptID = afterAttemptID
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.state = state
  }

  public var durationMilliseconds: Int64? {
    endedAt.map { max(0, $0.rawValue - startedAt.rawValue) }
  }

  public func elapsedMilliseconds(at instant: Instant) -> Int64 {
    let upperBound = endedAt ?? instant
    return max(0, upperBound.rawValue - startedAt.rawValue)
  }
}

public struct RestSnapshot: Equatable, Codable, Sendable {
  public let intervals: [RestIntervalSnapshot]

  public init(intervals: [RestIntervalSnapshot]) {
    self.intervals = intervals
  }

  public var activeRest: RestIntervalSnapshot? {
    intervals.first { $0.state == .active }
  }
}

public struct RestState: Equatable, Codable, Sendable {
  var intervalsByID: [RestIntervalID: RestIntervalSnapshot]
  var appliedCommands: [ActionID: RestCommand]

  public init() {
    intervalsByID = [:]
    appliedCommands = [:]
  }

  public var snapshot: RestSnapshot {
    RestSnapshot(
      intervals: intervalsByID.values.sorted {
        if $0.startedAt != $1.startedAt {
          return $0.startedAt < $1.startedAt
        }
        return $0.id.rawValue < $1.id.rawValue
      }
    )
  }
}

public enum RestCommand: Equatable, Codable, Sendable {
  case start(
    actionID: ActionID,
    restID: RestIntervalID,
    visitID: GymVisitID,
    afterAttemptID: AttemptID?,
    occurredAt: Instant
  )
  case stop(actionID: ActionID, restID: RestIntervalID, occurredAt: Instant)
}

public enum RestRejection: Equatable, Sendable {
  case actionIDReused
  case restAlreadyExists
  case restAlreadyActive
  case restDoesNotExist
  case restIsNotActive
  case visitIsNotOpen
  case attemptDoesNotExist
  case attemptDoesNotBelongToVisit
  case attemptIsRetracted
  case stopPrecedesStart
}

public enum RestOutcome: Equatable, Sendable {
  case accepted
  case duplicate
  case rejected(RestRejection)
}

public struct RestTransition: Equatable, Sendable {
  public let state: RestState
  public let outcome: RestOutcome

  public init(state: RestState, outcome: RestOutcome) {
    self.state = state
    self.outcome = outcome
  }
}

public enum RestMemory {
  public static func apply(
    _ command: RestCommand,
    visitSnapshot: VisitSnapshot,
    to state: RestState
  ) -> RestTransition {
    if let applied = state.appliedCommands[command.actionID] {
      return RestTransition(
        state: state,
        outcome: applied == command ? .duplicate : .rejected(.actionIDReused)
      )
    }

    var next = state
    switch command {
    case .start(_, let restID, let visitID, let afterAttemptID, let occurredAt):
      guard next.intervalsByID[restID] == nil else {
        return RestTransition(state: state, outcome: .rejected(.restAlreadyExists))
      }
      guard !next.intervalsByID.values.contains(where: { $0.state == .active }) else {
        return RestTransition(state: state, outcome: .rejected(.restAlreadyActive))
      }
      guard
        visitSnapshot.visits.contains(where: {
          $0.id == visitID && $0.captureState == .open
        })
      else {
        return RestTransition(state: state, outcome: .rejected(.visitIsNotOpen))
      }
      if let afterAttemptID {
        guard let attempt = visitSnapshot.attempts.first(where: { $0.id == afterAttemptID }) else {
          return RestTransition(state: state, outcome: .rejected(.attemptDoesNotExist))
        }
        guard attempt.visitID == visitID else {
          return RestTransition(state: state, outcome: .rejected(.attemptDoesNotBelongToVisit))
        }
        guard attempt.recordState == .active else {
          return RestTransition(state: state, outcome: .rejected(.attemptIsRetracted))
        }
      }
      next.intervalsByID[restID] = RestIntervalSnapshot(
        id: restID,
        visitID: visitID,
        afterAttemptID: afterAttemptID,
        startedAt: occurredAt,
        endedAt: nil,
        state: .active
      )

    case .stop(_, let restID, let occurredAt):
      guard let rest = next.intervalsByID[restID] else {
        return RestTransition(state: state, outcome: .rejected(.restDoesNotExist))
      }
      guard rest.state == .active else {
        return RestTransition(state: state, outcome: .rejected(.restIsNotActive))
      }
      guard occurredAt >= rest.startedAt else {
        return RestTransition(state: state, outcome: .rejected(.stopPrecedesStart))
      }
      next.intervalsByID[restID] = RestIntervalSnapshot(
        id: rest.id,
        visitID: rest.visitID,
        afterAttemptID: rest.afterAttemptID,
        startedAt: rest.startedAt,
        endedAt: occurredAt,
        state: .completed
      )
    }

    next.appliedCommands[command.actionID] = command
    return RestTransition(state: next, outcome: .accepted)
  }
}

extension RestCommand {
  fileprivate var actionID: ActionID {
    switch self {
    case .start(let actionID, _, _, _, _), .stop(let actionID, _, _):
      actionID
    }
  }
}
