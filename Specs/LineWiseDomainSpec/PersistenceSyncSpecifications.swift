import Foundation
import LineWiseDomain

private final class RejectingSaveEventStore: VisitEventStore {
  func load() throws -> VisitEventJournal {
    VisitEventJournal()
  }

  func save(_ journal: VisitEventJournal) throws {
    throw VisitPersistenceError.ioFailure(
      operation: "write",
      path: "/unavailable/events.json",
      reason: "injected boundary failure"
    )
  }

  func delete() throws {}
}

private func repositoryReplaysTheSameSnapshotAfterReopen() throws {
  let store = MemoryVisitEventStore()
  let visitID = GymVisitID("visit-persisted")
  let attemptID = AttemptID("attempt-persisted")
  let first = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))

  let startOutcome = try first.submit(
    .startVisit(
      actionID: ActionID("start-persisted"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .iPhone
    ))
  try expect(
    startOutcome == .accepted,
    "expected persisted visit start to be accepted"
  )
  let recordOutcome = try first.submit(
    .recordAttempt(
      actionID: ActionID("record-persisted"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    ))
  try expect(
    recordOutcome == .accepted,
    "expected persisted Attempt to be accepted"
  )
  let sendOutcome = try first.submit(
    .markSend(
      actionID: ActionID("send-persisted"),
      attemptID: attemptID,
      occurredAt: Instant(millisecondsSince1970: 2_100),
      source: .watch
    ))
  try expect(
    sendOutcome == .accepted,
    "expected persisted Send to be accepted"
  )

  let reopened = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))
  try expect(
    reopened.snapshot == first.snapshot,
    "expected reopening the same event store to replay the same VisitSnapshot"
  )
  try expect(
    reopened.snapshot.attempts.first?.outcome == .sent,
    "expected replay to preserve the Attempt result"
  )
  try expect(first.pendingOutboundEvents.count == 3, "expected local events to enter the outbox")
  let didAcknowledge = try first.acknowledgeOutbound(ActionID("start-persisted"))
  try expect(didAcknowledge, "expected a persisted local event to acknowledge")
  let reopenedAfterAcknowledgement = try VisitRepository(
    store: store,
    localDeviceID: DeviceID("iphone")
  )
  try expect(
    reopenedAfterAcknowledgement.pendingOutboundEvents.map(\.eventID) == [
      ActionID("record-persisted"), ActionID("send-persisted"),
    ],
    "expected acknowledgment to survive repository reopen"
  )
}

private func inboxAndOutboxKeepStableIDsAcrossRetryAndDisorder() throws {
  let deviceID = DeviceID("watch")
  let start = VisitCommand.startVisit(
    actionID: ActionID("sync-start"),
    visitID: GymVisitID("sync-visit"),
    occurredAt: Instant(millisecondsSince1970: 1_000),
    source: .watch
  )
  let attempt = VisitCommand.recordAttempt(
    actionID: ActionID("sync-attempt"),
    attemptID: AttemptID("sync-attempt"),
    visitID: GymVisitID("sync-visit"),
    routeCardID: nil,
    occurredAt: Instant(millisecondsSince1970: 2_000),
    source: .watch
  )

  var outbox = DeviceEventOutbox(originDeviceID: deviceID)
  let first = try outbox.enqueue(start)
  let retry = try outbox.enqueue(start)
  let second = try outbox.enqueue(attempt)

  try expect(first == retry, "expected retry to reuse the exact same event envelope")
  try expect(first.eventID == start.stableActionID, "expected action ID to be the stable event ID")
  try expect(second.sequence == 2, "expected monotonically increasing origin sequence")
  try expect(outbox.pendingEvents.count == 2, "expected two unacknowledged outbound events")

  var inbox = DeviceEventInbox()
  let received = try inbox.receive([second, first, second])
  try expect(received.insertedEventIDs.count == 2, "expected duplicate delivery to insert once")
  try expect(received.duplicateEventIDs == [second.eventID], "expected duplicate to be reported")
  try expect(
    inbox.events.map(\.eventID) == [first.eventID, second.eventID],
    "expected inbox events to expose deterministic business-time order"
  )

  try expect(outbox.acknowledge(first.eventID), "expected existing outbound event to acknowledge")
  try expect(
    outbox.pendingEvents.map(\.eventID) == [second.eventID],
    "expected acknowledged event to leave the pending outbox"
  )
}

private func repositoryReconcilesRemoteEventsThatArriveOutOfOrder() throws {
  let store = MemoryVisitEventStore()
  let repository = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))
  let visitID = GymVisitID("remote-visit")
  let attemptID = AttemptID("remote-attempt")
  let remote = DeviceID("watch")

  let attempt = DeviceEventEnvelope(
    originDeviceID: remote,
    sequence: 2,
    command: .recordAttempt(
      actionID: ActionID("remote-attempt-action"),
      attemptID: attemptID,
      visitID: visitID,
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 2_000),
      source: .watch
    )
  )
  let start = DeviceEventEnvelope(
    originDeviceID: remote,
    sequence: 1,
    command: .startVisit(
      actionID: ActionID("remote-start-action"),
      visitID: visitID,
      occurredAt: Instant(millisecondsSince1970: 1_000),
      source: .watch
    )
  )

  _ = try repository.receive(attempt)
  try expect(repository.snapshot.attempts.isEmpty, "expected missing visit to remain unapplied")
  _ = try repository.receive(start)

  try expect(
    repository.snapshot.attempts.map(\.id) == [attemptID],
    "expected deterministic replay to apply the delayed visit before its Attempt"
  )
  let retry = try repository.receive(attempt)
  try expect(
    retry == .duplicate,
    "expected transport retry to be idempotent"
  )
}

private func repositoryReplaysOutOfOrderRouteCorrectionWithoutRetargeting() throws {
  let store = MemoryVisitEventStore()
  let repository = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))
  let remote = DeviceID("watch")
  let visitID = GymVisitID("remote-correction-visit")
  let attemptID = AttemptID("remote-correction-attempt")
  let routeID = RouteCardID("remote-correction-route")
  let events = [
    DeviceEventEnvelope(
      originDeviceID: remote,
      sequence: 4,
      command: .correctAttemptRoute(
        actionID: ActionID("remote-correction"),
        attemptID: attemptID,
        routeCardID: routeID,
        occurredAt: Instant(millisecondsSince1970: 4_000),
        source: .iPhone
      )
    ),
    DeviceEventEnvelope(
      originDeviceID: remote,
      sequence: 3,
      command: .recordAttempt(
        actionID: ActionID("remote-correction-attempt-action"),
        attemptID: attemptID,
        visitID: visitID,
        routeCardID: nil,
        occurredAt: Instant(millisecondsSince1970: 3_000),
        source: .watch
      )
    ),
    DeviceEventEnvelope(
      originDeviceID: remote,
      sequence: 1,
      command: .createRouteCard(
        actionID: ActionID("remote-correction-route-action"),
        routeCardID: routeID,
        label: "Remote corrected route",
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      )
    ),
    DeviceEventEnvelope(
      originDeviceID: remote,
      sequence: 2,
      command: .startVisit(
        actionID: ActionID("remote-correction-visit-action"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      )
    ),
  ]

  for event in events {
    _ = try repository.receive(event)
  }

  try expect(
    repository.snapshot.attempts.first?.id == attemptID
      && repository.snapshot.attempts.first?.routeCardID == routeID,
    "expected replay to bind the named Attempt only after both exact subjects exist"
  )
  try expect(
    repository.snapshot.attemptRouteCorrections.map(\.actionID) == [ActionID("remote-correction")],
    "expected replay to retain one correction audit"
  )
  let retry = try repository.receive(events[0])
  try expect(retry == .duplicate, "expected redelivery not to append another correction")
}

private func everyVisitCommandRoundTripsWithoutLosingCausalTargets() throws {
  let commands: [VisitCommand] = [
    .startVisit(
      actionID: ActionID("round-start"),
      visitID: GymVisitID("round-visit"),
      occurredAt: Instant(millisecondsSince1970: 1),
      source: .watch
    ),
    .recordAttempt(
      actionID: ActionID("round-record"),
      attemptID: AttemptID("round-attempt"),
      visitID: GymVisitID("round-visit"),
      routeCardID: RouteCardID("round-route"),
      occurredAt: Instant(millisecondsSince1970: 2),
      source: .watch
    ),
    .markSend(
      actionID: ActionID("round-send"),
      attemptID: AttemptID("round-attempt"),
      occurredAt: Instant(millisecondsSince1970: 3),
      source: .watch
    ),
    .confirmNotSent(
      actionID: ActionID("round-not-sent"),
      attemptID: AttemptID("round-attempt"),
      occurredAt: Instant(millisecondsSince1970: 4),
      source: .iPhone
    ),
    .undo(
      actionID: ActionID("round-undo"),
      targetActionID: ActionID("round-send"),
      occurredAt: Instant(millisecondsSince1970: 5),
      source: .watch
    ),
    .endVisit(
      actionID: ActionID("round-end"),
      visitID: GymVisitID("round-visit"),
      occurredAt: Instant(millisecondsSince1970: 6),
      source: .iPhone
    ),
    .beginReview(
      actionID: ActionID("round-begin-review"),
      visitID: GymVisitID("round-visit"),
      occurredAt: Instant(millisecondsSince1970: 7),
      source: .iPhone
    ),
    .completeReview(
      actionID: ActionID("round-complete-review"),
      visitID: GymVisitID("round-visit"),
      occurredAt: Instant(millisecondsSince1970: 8),
      source: .iPhone
    ),
    .createRouteCard(
      actionID: ActionID("round-create-route"),
      routeCardID: RouteCardID("round-route"),
      label: "Blue slab",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 9),
      source: .iPhone
    ),
    .reviseRouteCard(
      actionID: ActionID("round-revise-route"),
      routeCardID: RouteCardID("round-route"),
      revisedLabel: "Blue slab revised",
      occurredAt: Instant(millisecondsSince1970: 9_100),
      source: .iPhone
    ),
    .archiveRouteCard(
      actionID: ActionID("round-archive-route"),
      routeCardID: RouteCardID("round-route"),
      occurredAt: Instant(millisecondsSince1970: 9_200),
      source: .iPhone
    ),
    .restoreRouteCard(
      actionID: ActionID("round-restore-route"),
      routeCardID: RouteCardID("round-route"),
      occurredAt: Instant(millisecondsSince1970: 9_300),
      source: .iPhone
    ),
    .correctRouteAvailability(
      actionID: ActionID("round-route-availability"),
      routeCardID: RouteCardID("round-route"),
      availability: .gone,
      occurredAt: Instant(millisecondsSince1970: 9_400),
      source: .iPhone
    ),
    .confirmRouteCardMerge(
      actionID: ActionID("round-merge-route"),
      duplicateRouteCardID: RouteCardID("round-route"),
      canonicalRouteCardID: RouteCardID("round-canonical"),
      occurredAt: Instant(millisecondsSince1970: 9_500),
      source: .iPhone
    ),
    .unmergeRouteCard(
      actionID: ActionID("round-unmerge-route"),
      mergedRouteCardID: RouteCardID("round-route"),
      occurredAt: Instant(millisecondsSince1970: 9_600),
      source: .iPhone
    ),
    .correctAttemptRoute(
      actionID: ActionID("round-correct-attempt-route"),
      attemptID: AttemptID("round-attempt"),
      routeCardID: RouteCardID("round-canonical"),
      occurredAt: Instant(millisecondsSince1970: 9_700),
      source: .iPhone
    ),
    .correctAttemptRoute(
      actionID: ActionID("round-unassign-attempt-route"),
      attemptID: AttemptID("round-attempt"),
      routeCardID: nil,
      occurredAt: Instant(millisecondsSince1970: 9_800),
      source: .iPhone
    ),
    .startProject(
      actionID: ActionID("round-start-project"),
      projectID: ProjectID("round-project"),
      routeCardID: RouteCardID("round-route"),
      occurredAt: Instant(millisecondsSince1970: 10),
      source: .iPhone
    ),
    .closeProjectSent(
      actionID: ActionID("round-close-project"),
      projectID: ProjectID("round-project"),
      supportingAttemptID: AttemptID("round-attempt"),
      occurredAt: Instant(millisecondsSince1970: 11),
      source: .iPhone
    ),
    .archiveProject(
      actionID: ActionID("round-archive-project"),
      projectID: ProjectID("round-project"),
      occurredAt: Instant(millisecondsSince1970: 11_100),
      source: .iPhone
    ),
    .replaceRouteAfterReset(
      actionID: ActionID("round-reset-route"),
      oldRouteCardID: RouteCardID("round-route"),
      successorRouteCardID: RouteCardID("round-successor"),
      successorLabel: "New blue slab",
      occurredAt: Instant(millisecondsSince1970: 12),
      source: .iPhone
    ),
  ]
  let envelopes = commands.enumerated().map { index, command in
    DeviceEventEnvelope(
      originDeviceID: DeviceID("round-device"),
      sequence: UInt64(index + 1),
      command: command
    )
  }

  let encoded = try JSONEncoder().encode(envelopes)
  let decoded = try JSONDecoder().decode([DeviceEventEnvelope].self, from: encoded)

  try expect(decoded == envelopes, "expected all VisitCommand payloads to round trip exactly")
}

private func foundationStoreRoundTripsAndMigratesLegacySchema() throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("linewise-persistence-spec-\(UUID().uuidString)", isDirectory: true)
  let fileURL = directory.appendingPathComponent("events.json")
  defer { try? FileManager.default.removeItem(at: directory) }

  let store = FoundationFileVisitEventStore(fileURL: fileURL)
  let first = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))
  _ = try first.submit(
    .startVisit(
      actionID: ActionID("file-start"),
      visitID: GymVisitID("file-visit"),
      occurredAt: Instant(millisecondsSince1970: 10),
      source: .iPhone
    ))

  let reopened = try VisitRepository(
    store: FoundationFileVisitEventStore(fileURL: fileURL),
    localDeviceID: DeviceID("iphone")
  )
  try expect(reopened.snapshot == first.snapshot, "expected atomic file store round trip")

  let legacyURL = directory.appendingPathComponent("legacy.json")
  let legacy =
    #"{"schemaVersion":0,"commands":[{"kind":"start_visit","actionID":"legacy-start","visitID":"legacy-visit","occurredAt":20,"source":"watch"}]}"#
  try Data(legacy.utf8).write(to: legacyURL, options: .atomic)

  let migrated = try VisitRepository(
    store: FoundationFileVisitEventStore(fileURL: legacyURL),
    localDeviceID: DeviceID("iphone")
  )
  try expect(
    migrated.snapshot.visits.map(\.id) == [GymVisitID("legacy-visit")],
    "expected schema zero command log to migrate and replay"
  )
  let migratedJSON = try String(contentsOf: legacyURL, encoding: .utf8)
  try expect(
    migratedJSON.contains("\"schemaVersion\" : 1"),
    "expected successful migration to rewrite the current schema atomically"
  )
}

private func corruptedAndFutureStoresFailExplicitly() throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("linewise-corrupt-spec-\(UUID().uuidString)", isDirectory: true)
  let fileURL = directory.appendingPathComponent("events.json")
  defer { try? FileManager.default.removeItem(at: directory) }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

  try Data("not-json".utf8).write(to: fileURL, options: .atomic)
  do {
    _ = try VisitRepository(
      store: FoundationFileVisitEventStore(fileURL: fileURL),
      localDeviceID: DeviceID("iphone")
    )
    throw SpecFailure.expected("expected corrupted store to fail")
  } catch let error as VisitPersistenceError {
    guard case .corruptedStore = error else {
      throw SpecFailure.expected("expected explicit corruptedStore error, got \(error)")
    }
  }

  try Data(#"{"schemaVersion":99,"events":[]}"#.utf8)
    .write(to: fileURL, options: .atomic)
  do {
    _ = try VisitRepository(
      store: FoundationFileVisitEventStore(fileURL: fileURL),
      localDeviceID: DeviceID("iphone")
    )
    throw SpecFailure.expected("expected future schema to fail")
  } catch let error as VisitPersistenceError {
    try expect(
      error == .unsupportedSchemaVersion(99),
      "expected unsupported schema version to remain explicit"
    )
  }
}

private func failedPersistenceDoesNotMutateRepositoryState() throws {
  let repository = try VisitRepository(
    store: RejectingSaveEventStore(),
    localDeviceID: DeviceID("iphone")
  )
  do {
    _ = try repository.submit(
      .startVisit(
        actionID: ActionID("must-not-appear"),
        visitID: GymVisitID("must-not-appear"),
        occurredAt: Instant(millisecondsSince1970: 1),
        source: .iPhone
      ))
    throw SpecFailure.expected("expected injected persistence failure")
  } catch let error as VisitPersistenceError {
    guard case .ioFailure = error else {
      throw SpecFailure.expected("expected explicit IO failure, got \(error)")
    }
  }

  try expect(
    repository.snapshot == VisitState().snapshot,
    "expected failed save not to change the domain projection"
  )
  try expect(
    repository.persistedEvents.isEmpty && repository.pendingOutboundEvents.isEmpty,
    "expected failed save not to change Inbox or Outbox"
  )
}

private func exportDeleteAndDebugBundleHaveHonestBoundaries() throws {
  let store = MemoryVisitEventStore()
  let repository = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))
  _ = try repository.submit(
    .createRouteCard(
      actionID: ActionID("private-action-id"),
      routeCardID: RouteCardID("private-route-id"),
      label: "Secret gym route label",
      availability: .present,
      occurredAt: Instant(millisecondsSince1970: 100),
      source: .iPhone
    ))
  let lifecycle = LineWiseDataLifecycle(repository: repository)

  let export = try lifecycle.exportData()
  let exportedJSON = String(decoding: export, as: UTF8.self)
  try expect(exportedJSON.contains("Secret gym route label"), "expected user export to be complete")

  let debug = try lifecycle.redactedDebugBundle()
  let debugJSON = String(decoding: debug, as: UTF8.self)
  try expect(!debugJSON.contains("Secret gym route label"), "expected debug bundle to omit labels")
  try expect(!debugJSON.contains("private-action-id"), "expected debug bundle to omit stable IDs")
  try expect(debugJSON.contains("create_route_card"), "expected debug bundle to retain event kinds")

  try lifecycle.deleteAllData()
  try expect(repository.snapshot == VisitState().snapshot, "expected live repository to clear")
  let reopened = try VisitRepository(store: store, localDeviceID: DeviceID("iphone"))
  try expect(reopened.snapshot == VisitState().snapshot, "expected deleted store to stay empty")
}

func persistenceSyncSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "repository replays the same snapshot after reopen",
      repositoryReplaysTheSameSnapshotAfterReopen
    ),
    (
      "Inbox and Outbox preserve stable IDs across retry and disorder",
      inboxAndOutboxKeepStableIDsAcrossRetryAndDisorder
    ),
    (
      "repository reconciles remote events that arrive out of order",
      repositoryReconcilesRemoteEventsThatArriveOutOfOrder
    ),
    (
      "repository replays out-of-order route correction without retargeting",
      repositoryReplaysOutOfOrderRouteCorrectionWithoutRetargeting
    ),
    (
      "every VisitCommand round trips without losing causal targets",
      everyVisitCommandRoundTripsWithoutLosingCausalTargets
    ),
    (
      "Foundation store round trips and migrates legacy schema",
      foundationStoreRoundTripsAndMigratesLegacySchema
    ),
    ("corrupted and future stores fail explicitly", corruptedAndFutureStoresFailExplicitly),
    (
      "failed persistence does not mutate repository state",
      failedPersistenceDoesNotMutateRepositoryState
    ),
    (
      "export delete and debug bundle have honest boundaries",
      exportDeleteAndDebugBundleHaveHonestBoundaries
    ),
  ]
}
