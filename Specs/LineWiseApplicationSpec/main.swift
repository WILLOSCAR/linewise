import LineWiseApplication
import LineWiseDomain

enum ApplicationSpecFailure: Error, CustomStringConvertible {
  case expected(String)

  var description: String {
    switch self {
    case .expected(let message): message
    }
  }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else {
    throw ApplicationSpecFailure.expected(message)
  }
}

func manualPhoneLoopWorksWithoutOptionalSystems() throws {
  let routeID = RouteCardID("route-phone-loop")
  let projectID = ProjectID("project-phone-loop")
  let visitID = GymVisitID("visit-phone-loop")
  let attemptID = AttemptID("attempt-phone-loop")
  var app = LineWiseAppCoordinator()

  let commands: [LineWiseAppIntent] = [
    .createRoute(
      actionID: ActionID("action-create-phone-loop"),
      routeCardID: routeID,
      label: "Yellow slab",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("action-project-phone-loop"),
      projectID: projectID,
      routeCardID: routeID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("action-start-phone-loop"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    .selectRoute(routeID),
    .recordAttempt(
      actionID: ActionID("action-attempt-phone-loop"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .iPhone
    ),
  ]

  for command in commands {
    let feedback = app.handle(command)
    try expect(feedback.isSuccess, "expected manual phone command to succeed: \(command)")
  }

  try expect(app.projection.activeVisit?.id == visitID, "expected one active visit")
  try expect(app.projection.currentRouteCard?.id == routeID, "expected selected RouteCard")
  try expect(app.projection.currentRouteAttemptCount == 1, "expected one Attempt")
  try expect(
    app.projection.currentRouteAttempts.first?.outcome == .unresolved,
    "expected honest unresolved outcome"
  )

  let sent = app.handle(
    .markSend(
      actionID: ActionID("action-send-phone-loop"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_100),
      source: .iPhone
    )
  )
  try expect(sent.isSuccess, "expected Mark Send to succeed")
  try expect(app.projection.currentRouteAttemptCount == 1, "expected Send not to add an Attempt")
  try expect(app.projection.currentRouteAttempts.first?.outcome == .sent, "expected sent outcome")

  _ = app.handle(
    .endVisit(
      actionID: ActionID("action-end-phone-loop"),
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    )
  )
  try expect(app.projection.activeVisit == nil, "expected visit capture to end")
  try expect(
    app.projection.visits.first?.reviewState == .pendingReview,
    "expected ended visit to enter review"
  )
}

func watchProjectionKeepsThePrimaryActionOneTap() throws {
  let routeID = RouteCardID("route-watch-projection")
  let visitID = GymVisitID("visit-watch-projection")
  var app = LineWiseAppCoordinator()

  _ = app.handle(
    .createRoute(
      actionID: ActionID("action-create-watch-projection"),
      routeCardID: routeID,
      label: "Blue roof",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    )
  )
  _ = app.handle(
    .startVisit(
      actionID: ActionID("action-start-watch-projection"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    )
  )
  _ = app.handle(.selectRoute(routeID))

  try expect(app.watchProjection.primaryAction == .recordAttempt, "expected one primary action")
  try expect(app.watchProjection.currentRouteLabel == "Blue roof", "expected route context")
  try expect(app.watchProjection.canMarkSend == false, "expected no Send target before capture")

  _ = app.handle(
    .recordAttempt(
      actionID: ActionID("action-attempt-watch-projection"),
      attemptID: AttemptID("attempt-watch-projection"),
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    )
  )
  try expect(app.watchProjection.attemptCount == 1, "expected immediate local count")
  try expect(app.watchProjection.canMarkSend, "expected optional Send after Attempt")

  let restID = RestIntervalID("rest-watch-projection")
  let startedRest = app.handle(
    .startRest(
      actionID: ActionID("action-start-rest-watch-projection"),
      restID: restID,
      afterAttemptID: AttemptID("attempt-watch-projection"),
      occurredAt: Instant(millisecondsSince1970: 3_100)
    )
  )
  try expect(startedRest.isSuccess, "expected rest timer to start")
  try expect(app.watchProjection.isResting, "expected Watch to expose active rest")

  let stoppedRest = app.handle(
    .stopRest(
      actionID: ActionID("action-stop-rest-watch-projection"),
      restID: restID,
      occurredAt: Instant(millisecondsSince1970: 4_100)
    )
  )
  try expect(stoppedRest.isSuccess, "expected rest timer to stop")
  try expect(!app.watchProjection.isResting, "expected stopped rest state")
}

func applicationCoordinatorReopensPersistedVisitState() throws {
  let store = MemoryVisitEventStore()
  let repository = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))
  let visitID = GymVisitID("visit-app-reopen")
  let attemptID = AttemptID("attempt-app-reopen")
  var app = LineWiseAppCoordinator(repository: repository)

  try expect(
    app.handle(
      .startVisit(
        actionID: ActionID("action-start-app-reopen"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected persisted Visit start"
  )
  try expect(
    app.handle(
      .recordAttempt(
        actionID: ActionID("action-attempt-app-reopen"),
        attemptID: attemptID,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected persisted Attempt"
  )

  let reopenedRepository = try VisitRepository(
    store: store,
    localDeviceID: DeviceID("iphone")
  )
  let reopened = LineWiseAppCoordinator(repository: reopenedRepository)
  try expect(reopened.projection.activeVisit?.id == visitID, "expected Visit after reopen")
  try expect(reopened.projection.attempts.map(\.id) == [attemptID], "expected Attempt after reopen")
}

var specifications: [(String, () throws -> Void)] = [
  ("manual phone loop works without optional systems", manualPhoneLoopWorksWithoutOptionalSystems),
  ("Watch projection keeps the primary action one tap", watchProjectionKeepsThePrimaryActionOneTap),
  (
    "application coordinator reopens persisted visit state",
    applicationCoordinatorReopensPersistedVisitState
  ),
]
specifications.append(contentsOf: experienceSpecifications())
specifications.append(contentsOf: coordinatorReliabilitySpecifications())
specifications.append(contentsOf: rehearsalCoordinatorSpecifications())
specifications.append(contentsOf: experiencePersistenceSpecifications())
specifications.append(contentsOf: fieldEvidenceSpecifications())
specifications.append(contentsOf: learningExperienceSpecifications())
specifications.append(contentsOf: reviewInboxReconciliationSpecifications())

var failures: [String] = []
for (name, specification) in specifications {
  do {
    try specification()
    print("PASS: \(name)")
  } catch {
    failures.append("FAIL: \(name) — \(error)")
  }
}

if failures.isEmpty {
  print("LineWiseApplicationSpec: \(specifications.count) passed")
} else {
  fatalError(failures.joined(separator: "\n"))
}
