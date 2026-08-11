public enum RouteCardRecordVisibility: String, Codable, Sendable {
  case active
  case archived
  case merged
}

public enum RouteAvailability: String, Codable, Sendable {
  case unknown
  case present
  case gone
}

public struct RouteCardSnapshot: Equatable, Codable, Sendable {
  public let id: RouteCardID
  public let label: String
  public let recordVisibility: RouteCardRecordVisibility
  public let availability: RouteAvailability
  public let mergedIntoRouteCardID: RouteCardID?
  public let successorRouteCardID: RouteCardID?
  public let createdAt: Instant

  public init(
    id: RouteCardID,
    label: String,
    recordVisibility: RouteCardRecordVisibility,
    availability: RouteAvailability,
    mergedIntoRouteCardID: RouteCardID?,
    successorRouteCardID: RouteCardID?,
    createdAt: Instant
  ) {
    self.id = id
    self.label = label
    self.recordVisibility = recordVisibility
    self.availability = availability
    self.mergedIntoRouteCardID = mergedIntoRouteCardID
    self.successorRouteCardID = successorRouteCardID
    self.createdAt = createdAt
  }
}

extension RouteCardSnapshot {
  func revising(label: String) -> RouteCardSnapshot {
    RouteCardSnapshot(
      id: id,
      label: label,
      recordVisibility: recordVisibility,
      availability: availability,
      mergedIntoRouteCardID: mergedIntoRouteCardID,
      successorRouteCardID: successorRouteCardID,
      createdAt: createdAt
    )
  }

  func changingVisibility(
    to visibility: RouteCardRecordVisibility,
    mergedIntoRouteCardID: RouteCardID?
  ) -> RouteCardSnapshot {
    RouteCardSnapshot(
      id: id,
      label: label,
      recordVisibility: visibility,
      availability: availability,
      mergedIntoRouteCardID: mergedIntoRouteCardID,
      successorRouteCardID: successorRouteCardID,
      createdAt: createdAt
    )
  }

  func changingAvailability(to availability: RouteAvailability) -> RouteCardSnapshot {
    RouteCardSnapshot(
      id: id,
      label: label,
      recordVisibility: recordVisibility,
      availability: availability,
      mergedIntoRouteCardID: mergedIntoRouteCardID,
      successorRouteCardID: successorRouteCardID,
      createdAt: createdAt
    )
  }
}

public enum ProjectState: String, Codable, Sendable {
  case active
  case sent
  case archived
  case gone
}

public struct ProjectSnapshot: Equatable, Codable, Sendable {
  public let id: ProjectID
  public let routeCardID: RouteCardID
  public let state: ProjectState
  public let startedAt: Instant
  public let closedAt: Instant?
  public let supportingAttemptID: AttemptID?

  public init(
    id: ProjectID,
    routeCardID: RouteCardID,
    state: ProjectState,
    startedAt: Instant,
    closedAt: Instant?,
    supportingAttemptID: AttemptID?
  ) {
    self.id = id
    self.routeCardID = routeCardID
    self.state = state
    self.startedAt = startedAt
    self.closedAt = closedAt
    self.supportingAttemptID = supportingAttemptID
  }
}
