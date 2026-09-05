import Foundation
import LineWiseApplication
import LineWiseDomain

func reviewInboxReconciliationSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "synced ended Visit restores an idempotent Review Inbox",
      syncedEndedVisitRestoresAnIdempotentReviewInbox
    ),
    (
      "Review Inbox reconciliation retries after an archive write failure",
      reviewInboxReconciliationRetriesAfterArchiveWriteFailure
    ),
    (
      "an undone result returns its Attempt to the review queue",
      anUndoneResultReturnsItsAttemptToTheReviewQueue
    ),
  ]
}

/// Resolving an inbox item records that the user answered the question once. It
/// does not mean the question can never be asked again: undoing the Send returns
/// the Attempt to `unresolved`, and the Visit correctly flips to `needsRecheck`.
/// Treating a resolved sourceKey as permanently satisfied leaves the Visit flagged
/// for recheck while the queue that tells the user WHAT to recheck is empty — an
/// Attempt with no confirmed result, invisible.
private func anUndoneResultReturnsItsAttemptToTheReviewQueue() throws {
  let fixture = try reviewSyncFixture()
  var phone = fixture.phone
  _ = phone.receive(fixture.envelopes)
  try phone.reconcileReviewInboxFromCapture()

  let attemptID = AttemptID("attempt-assigned-sync-review")
  let itemID = ReviewInboxItemID("unresolved/\(attemptID.rawValue)")
  let sendActionID = ActionID("send-assigned-sync-review")
  try expect(
    phone.projection.recall.reviewItems.contains { $0.id == itemID },
    "expected the unresolved Attempt to be queued before it is answered"
  )

  let markSend = try phone.handle(
    .markSend(
      actionID: sendActionID,
      attemptID: attemptID,
      occurredAt: reviewInstant(40),
      source: .iPhone
    )
  )
  try expect(markSend.isSuccess, "expected the user to be able to confirm a Send")
  let resolved = try phone.submitRecall(
    .resolveReviewItem(
      actionID: ActionID("resolve-assigned-sync-review"),
      itemID: itemID,
      occurredAt: reviewInstant(41)
    )
  )
  try expect(resolved == .accepted, "expected the answered item to be resolvable")

  // The user changes their mind: undo the Send. The Attempt is unresolved again.
  let undo = try phone.handle(
    .undo(
      actionID: ActionID("undo-assigned-sync-review"),
      targetActionID: sendActionID,
      occurredAt: reviewInstant(42),
      source: .iPhone
    )
  )
  try expect(undo.isSuccess, "expected the Send to be undoable")
  try expect(
    phone.projection.capture.attempts.first { $0.id == attemptID }?.outcome == .unresolved,
    "undoing the Send must return the Attempt to unresolved"
  )

  try phone.reconcileReviewInboxFromCapture()
  let openItems = phone.projection.recall.reviewItems.filter {
    $0.status == .pending || $0.status == .snoozed
  }
  try expect(
    openItems.contains { $0.sourceKey == "attempt/\(attemptID.rawValue)/unresolved" },
    """
    the Attempt is unresolved again but no open review item covers it \
    (open: \(openItems.map(\.id))). The Visit is flagged for recheck while the queue \
    that says what to recheck is empty, so an unresolved Attempt is silently invisible
    """
  )
}

private func syncedEndedVisitRestoresAnIdempotentReviewInbox() throws {
  let fixture = try reviewSyncFixture()
  var phone = fixture.phone

  let first = phone.receive(fixture.envelopes)
  guard case .received(let inserted, _) = first else {
    throw ApplicationSpecFailure.expected("expected Watch events to reach the Phone: \(first)")
  }
  try expect(!inserted.isEmpty, "expected newly inserted Watch events")
  try expect(
    phone.projection.capture.visits.first?.reviewState == .pendingReview,
    "the synced ended Visit must remain ready for explicit review"
  )

  let items = phone.projection.recall.reviewItems
  try expect(
    items.map(\.id)
      == [
        ReviewInboxItemID("unresolved/attempt-assigned-sync-review"),
        ReviewInboxItemID("unassigned/attempt-unassigned-sync-review"),
        ReviewInboxItemID("unresolved/attempt-unassigned-sync-review"),
      ],
    "expected one stable item for each unresolved or unassigned decision, got \(items.map(\.id))"
  )
  try expect(
    Set(items.map(\.sourceKey))
      == [
        "attempt/attempt-assigned-sync-review/unresolved",
        "attempt/attempt-unassigned-sync-review/unassigned",
        "attempt/attempt-unassigned-sync-review/unresolved",
      ],
    "each reconciled review decision needs a stable source key"
  )
  let archiveJSON = String(decoding: try phone.exportData(), as: UTF8.self)
    .replacingOccurrences(of: "\\/", with: "/")
  try expect(
    archiveJSON.contains(
      "experience.reconcile-review/attempt/attempt-assigned-sync-review/unresolved"
    ),
    "the reconciliation action ID must be deterministic across retry and restart"
  )

  let begin = try phone.handle(
    .beginReview(
      actionID: ActionID("begin-synced-review"),
      visitID: fixture.visitID,
      occurredAt: reviewInstant(8),
      source: .iPhone
    )
  )
  try expect(begin.isSuccess, "the Phone must be able to enter review for the synced Visit")

  let duplicate = phone.receive(fixture.envelopes)
  guard case .received(_, let duplicateIDs) = duplicate else {
    throw ApplicationSpecFailure.expected("expected duplicate delivery to remain valid")
  }
  try expect(!duplicateIDs.isEmpty, "expected the retry to be recognized as duplicate delivery")
  try expect(
    phone.projection.recall.reviewItems.count == 3,
    "duplicate delivery must not duplicate Review Inbox items"
  )

  var reopened = try PersistentLineWiseExperienceCoordinator(
    store: fixture.archiveStore,
    repository: fixture.phoneRepository
  )
  let reconciliation = try reopened.reconcileReviewInboxFromCapture()
  try expect(
    reconciliation.enqueuedItemIDs.isEmpty,
    "reopening and reconciling must preserve already tracked sources"
  )
  try expect(
    reopened.projection.recall.reviewItems.count == 3,
    "the reconciled Review Inbox must survive restart"
  )
}

private func reviewInboxReconciliationRetriesAfterArchiveWriteFailure() throws {
  let fixture = try reviewSyncFixture(
    archiveStore: ToggleFailingReviewArchiveStore(failSaves: true)
  )
  guard let archiveStore = fixture.archiveStore as? ToggleFailingReviewArchiveStore else {
    throw ApplicationSpecFailure.expected("expected the scripted archive store")
  }
  var phone = fixture.phone

  guard case .persistenceFailed(let reason) = phone.receive(fixture.envelopes) else {
    throw ApplicationSpecFailure.expected("expected the first Review Inbox save to fail visibly")
  }
  try expect(!reason.isEmpty, "the persistence failure must contain a readable reason")
  try expect(
    phone.projection.recall.reviewItems.isEmpty,
    "failed archive writes must not publish unpersisted Review Inbox items"
  )

  archiveStore.failSaves = false
  guard case .received(_, let duplicates) = phone.receive(fixture.envelopes) else {
    throw ApplicationSpecFailure.expected(
      "expected duplicate capture delivery to retry reconciliation"
    )
  }
  try expect(
    !duplicates.isEmpty,
    "the Visit events should already be durable after the first receive"
  )
  try expect(
    phone.projection.recall.reviewItems.count == 3,
    "a duplicate pull must repair the Review Inbox after its earlier write failed, got \(phone.projection.recall.reviewItems)"
  )
}

private struct ReviewSyncFixture {
  let visitID: GymVisitID
  let envelopes: [DeviceEventEnvelope]
  let phoneRepository: VisitRepository
  let archiveStore: any ExperienceArchiveStore
  let phone: PersistentLineWiseExperienceCoordinator
}

private func reviewSyncFixture(
  archiveStore: any ExperienceArchiveStore = MemoryExperienceArchiveStore()
) throws -> ReviewSyncFixture {
  let watchRepository = try VisitRepository(
    store: MemoryVisitEventStore(),
    localDeviceID: DeviceID("watch-sync-review")
  )
  var watch = LineWiseAppCoordinator(repository: watchRepository)
  let routeID = RouteCardID("route-sync-review")
  let visitID = GymVisitID("visit-sync-review")
  let setup: [LineWiseAppIntent] = [
    .createRoute(
      actionID: ActionID("create-route-sync-review"),
      routeCardID: routeID,
      label: "Blue sync route",
      availability: .present,
      occurredAt: reviewInstant(1),
      source: .watch
    ),
    .startVisit(
      actionID: ActionID("start-visit-sync-review"),
      visitID: visitID,
      occurredAt: reviewInstant(2),
      source: .watch
    ),
    .selectRoute(routeID),
    .recordAttempt(
      actionID: ActionID("record-assigned-sync-review"),
      attemptID: AttemptID("attempt-assigned-sync-review"),
      occurredAt: reviewInstant(3),
      source: .watch
    ),
    .selectRoute(nil),
    // Recording with "no route selected" now yields an unassigned Attempt
    // directly. This previously needed a follow-up correctAttemptRoute(nil) to
    // undo a route binding the selection fallback fabricated.
    .recordAttempt(
      actionID: ActionID("record-unassigned-sync-review"),
      attemptID: AttemptID("attempt-unassigned-sync-review"),
      occurredAt: reviewInstant(4),
      source: .watch
    ),
    .endVisit(
      actionID: ActionID("end-visit-sync-review"),
      occurredAt: reviewInstant(5),
      source: .watch
    ),
  ]
  for intent in setup {
    try expect(watch.handle(intent).isSuccess, "expected Watch setup action: \(intent)")
  }

  let phoneRepository = try VisitRepository(
    store: MemoryVisitEventStore(),
    localDeviceID: DeviceID("phone-sync-review")
  )
  return ReviewSyncFixture(
    visitID: visitID,
    envelopes: watch.pendingOutboundEvents,
    phoneRepository: phoneRepository,
    archiveStore: archiveStore,
    phone: try PersistentLineWiseExperienceCoordinator(
      store: archiveStore,
      repository: phoneRepository
    )
  )
}

private final class ToggleFailingReviewArchiveStore: ExperienceArchiveStore {
  enum Failure: Error {
    case save
  }

  var failSaves: Bool
  private var archive: LineWiseExperienceArchive?

  init(failSaves: Bool) {
    self.failSaves = failSaves
  }

  func load() throws -> LineWiseExperienceArchive? { archive }

  func save(_ archive: LineWiseExperienceArchive) throws {
    if failSaves { throw Failure.save }
    self.archive = archive
  }

  func exportData() throws -> Data? {
    try archive.map(LineWiseExperienceArchiveCodec.encode)
  }

  func delete() throws {
    archive = nil
  }
}

private func reviewInstant(_ value: Int64) -> Instant {
  Instant(millisecondsSince1970: value * 1_000)
}
