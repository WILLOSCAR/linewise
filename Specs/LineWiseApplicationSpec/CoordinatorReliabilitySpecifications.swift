import LineWiseApplication
import LineWiseDomain

func coordinatorReliabilitySpecifications() -> [(String, () throws -> Void)] {
  [
    ("Undo exposes only reversible capture actions", undoExposesOnlyReversibleCaptureActions),
    ("coordinator reconciles and acknowledges durable device events", coordinatorReconcilesEvents),
    (
      "coordinator exposes route correction lifecycle without rewriting history",
      coordinatorExposesRouteCorrectionLifecycle
    ),
    (
      "experience restore derives Undo target from durable Visit history",
      experienceRestoreDerivesUndoFromDurableVisitHistory
    ),
  ]
}

private func experienceRestoreDerivesUndoFromDurableVisitHistory() throws {
  let visitStore = MemoryVisitEventStore()
  let repository = try VisitRepository(
    store: visitStore,
    localDeviceID: DeviceID("iphone-durable-undo")
  )
  let visitID = GymVisitID("visit-durable-undo")
  let attemptID = AttemptID("attempt-durable-undo")
  _ = try repository.submit(
    .startVisit(
      actionID: ActionID("durable-undo-start"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ))
  _ = try repository.submit(
    .recordAttempt(
      actionID: ActionID("durable-undo-attempt"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ))

  let staleArchive = LineWiseExperienceArchive(
    reversibleActionIDs: [ActionID("stale-archive-target")]
  )
  let restored = try PersistentLineWiseExperienceCoordinator(
    store: MemoryExperienceArchiveStore(archive: staleArchive),
    repository: repository
  )
  try expect(
    restored.projection.capture.lastAcceptedActionID == ActionID("durable-undo-attempt"),
    "durable Visit history must override stale auxiliary Undo metadata"
  )
}

private func coordinatorExposesRouteCorrectionLifecycle() throws {
  let canonicalID = RouteCardID("route-canonical-app")
  let duplicateID = RouteCardID("route-duplicate-app")
  let projectID = ProjectID("project-canonical-app")
  let attemptID = AttemptID("attempt-duplicate-app")
  var app = LineWiseAppCoordinator()
  let setup: [LineWiseAppIntent] = [
    .createRoute(
      actionID: ActionID("route-correction-create-canonical"),
      routeCardID: canonicalID,
      label: "Canonical",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ),
    .createRoute(
      actionID: ActionID("route-correction-create-duplicate"),
      routeCardID: duplicateID,
      label: "Duplicate",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("route-correction-project"),
      projectID: projectID,
      routeCardID: canonicalID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .iPhone
    ),
    .startVisit(
      actionID: ActionID("route-correction-visit"),
      visitID: GymVisitID("visit-route-correction-app"),
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .iPhone
    ),
    .selectRoute(duplicateID),
    .recordAttempt(
      actionID: ActionID("route-correction-attempt"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .iPhone
    ),
  ]
  for intent in setup {
    try expect(app.handle(intent).isSuccess, "expected route lifecycle setup: \(intent)")
  }

  try expect(
    app.handle(
      .mergeRoute(
        actionID: ActionID("route-correction-merge"),
        duplicateRouteCardID: duplicateID,
        canonicalRouteCardID: canonicalID,
        occurredAt: Instant(millisecondsSince1970: 6_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected confirmed duplicate merge"
  )
  try expect(app.projection.currentRouteCard?.id == canonicalID, "expected canonical selection")
  try expect(
    app.projection.currentRouteAttempts.map(\.id) == [attemptID],
    "expected merged history to remain visible without rewriting Attempt route identity"
  )
  try expect(
    app.projection.attempts.first?.routeCardID == duplicateID,
    "expected historical Attempt identity to remain unchanged by merge"
  )

  try expect(
    app.handle(
      .correctAttemptRoute(
        actionID: ActionID("route-correction-unassign"),
        attemptID: attemptID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 7_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected explicit unassigned correction"
  )
  try expect(app.projection.attempts.first?.routeCardID == nil, "expected corrected binding")
  try expect(
    app.projection.attemptRouteCorrections.first?.previousRouteCardID == duplicateID,
    "expected before/after correction audit"
  )

  try expect(
    app.handle(
      .archiveRoute(
        actionID: ActionID("route-correction-archive"),
        routeCardID: canonicalID,
        occurredAt: Instant(millisecondsSince1970: 8_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected RouteCard archive"
  )
  try expect(
    !app.projection.selectableRouteCards.contains(where: { $0.id == canonicalID }),
    "expected archive to affect selection only"
  )
  try expect(
    app.handle(
      .restoreRoute(
        actionID: ActionID("route-correction-restore"),
        routeCardID: canonicalID,
        occurredAt: Instant(millisecondsSince1970: 9_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected RouteCard restore"
  )
  try expect(
    app.handle(
      .correctRouteAvailability(
        actionID: ActionID("route-correction-gone"),
        routeCardID: canonicalID,
        availability: .gone,
        occurredAt: Instant(millisecondsSince1970: 10_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected explicit gone correction"
  )
  try expect(
    app.projection.projects.first(where: { $0.id == projectID })?.state == .gone,
    "expected gone to close only the active Project"
  )
  try expect(
    app.handle(
      .correctRouteAvailability(
        actionID: ActionID("route-correction-present"),
        routeCardID: canonicalID,
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 11_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected availability correction"
  )
  try expect(
    app.projection.projects.first(where: { $0.id == projectID })?.state == .gone,
    "correcting availability must not resurrect a terminal Project"
  )
}

private func undoExposesOnlyReversibleCaptureActions() throws {
  let routeID = RouteCardID("route-undo-stack")
  let attemptID = AttemptID("attempt-undo-stack")
  var app = LineWiseAppCoordinator()

  _ = app.handle(
    .createRoute(
      actionID: ActionID("undo-create"),
      routeCardID: routeID,
      label: "Undo route",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ))
  _ = app.handle(
    .startVisit(
      actionID: ActionID("undo-start-visit"),
      visitID: GymVisitID("visit-undo-stack"),
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ))
  _ = app.handle(.selectRoute(routeID))
  try expect(!app.watchProjection.canUndo, "visit setup must not appear reversible")

  _ = app.handle(
    .recordAttempt(
      actionID: ActionID("undo-record"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 3_000),
      source: .watch
    ))
  _ = app.handle(
    .markSend(
      actionID: ActionID("undo-send"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 4_000),
      source: .watch
    ))
  try expect(
    app.projection.lastAcceptedActionID == ActionID("undo-send"),
    "expected the latest reversible result action"
  )

  let undoSend = app.handle(
    .undo(
      actionID: ActionID("undo-send-action"),
      targetActionID: app.projection.lastAcceptedActionID!,
      occurredAt: Instant(millisecondsSince1970: 5_000),
      source: .watch
    ))
  try expect(undoSend.isSuccess, "expected Send correction to be reversible")
  try expect(
    app.projection.attempts.first?.outcome == .unresolved,
    "expected undoing Send to restore unresolved"
  )
  try expect(
    app.projection.lastAcceptedActionID == ActionID("undo-record"),
    "Undo itself must not replace the next eligible target"
  )

  let undoAttempt = app.handle(
    .undo(
      actionID: ActionID("undo-record-action"),
      targetActionID: app.projection.lastAcceptedActionID!,
      occurredAt: Instant(millisecondsSince1970: 6_000),
      source: .watch
    ))
  try expect(undoAttempt.isSuccess, "expected Attempt to be reversible after its result")
  try expect(
    app.projection.attempts.first?.recordState == .retracted,
    "expected exact Attempt retraction"
  )
  try expect(!app.watchProjection.canUndo, "expected no reversible action to remain")
}

private func coordinatorReconcilesEvents() throws {
  let watchRepository = try VisitRepository(
    store: MemoryVisitEventStore(),
    localDeviceID: DeviceID("watch-reconcile")
  )
  let phoneRepository = try VisitRepository(
    store: MemoryVisitEventStore(),
    localDeviceID: DeviceID("phone-reconcile")
  )
  var watch = LineWiseAppCoordinator(repository: watchRepository)
  var phone = LineWiseAppCoordinator(repository: phoneRepository)
  let visitID = GymVisitID("visit-reconcile")

  _ = watch.handle(
    .startVisit(
      actionID: ActionID("reconcile-start"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    ))
  let pending = watch.pendingOutboundEvents
  try expect(pending.count == 1, "expected one durable Watch Outbox event")
  try expect(
    phone.receive(pending)
      == .received(
        insertedEventIDs: [ActionID("reconcile-start")],
        duplicateEventIDs: []
      ),
    "expected the phone to receive the durable envelope"
  )
  try expect(phone.projection.activeVisit?.id == visitID, "expected received visit projection")
  try expect(
    phone.receive(pending)
      == .received(
        insertedEventIDs: [],
        duplicateEventIDs: [ActionID("reconcile-start")]
      ),
    "expected duplicate delivery to stay explicit and idempotent"
  )
  try expect(
    watch.acknowledgeOutbound(ActionID("reconcile-start"))
      == .acknowledged(ActionID("reconcile-start")),
    "expected transport acknowledgement to clear the exact event"
  )
  try expect(watch.pendingOutboundEvents.isEmpty, "expected the acknowledged Outbox to be empty")
  try expect(
    watch.acknowledgeOutbound(ActionID("reconcile-start"))
      == .alreadyAcknowledged(ActionID("reconcile-start")),
    "expected acknowledgement retry to be idempotent"
  )
}
