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

  /// The rest the user is currently in.
  ///
  /// A visit can end without its rest being stopped, so more than one interval may
  /// remain `.active` — an abandoned one from a finished session plus the live one.
  /// The newest start is the live one. Picking the first match would also be
  /// non-deterministic, since these come from an unordered dictionary.
  public var activeRest: RestIntervalSnapshot? {
    intervals
      .filter { $0.state == .active }
      .max {
        if $0.startedAt != $1.startedAt {
          return $0.startedAt < $1.startedAt
        }
        return $0.id.rawValue < $1.id.rawValue
      }
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
      // Only a rest belonging to a still-open visit blocks a new one. Ending a
      // visit does not stop its rest — nothing reconciles the two — so a session
      // finished without tapping stop leaves an interval active forever. Treating
      // that as "a rest is already running" would refuse the rest timer in every
      // later visit and keep accruing a cross-session duration the Watch renders
      // as live. A rest whose visit has ended is abandoned, not current.
      let blockingRest = next.intervalsByID.values.first { interval in
        guard interval.state == .active else { return false }
        return visitSnapshot.visits.contains {
          $0.id == interval.visitID && $0.captureState == .open
        }
      }
      guard blockingRest == nil else {
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
