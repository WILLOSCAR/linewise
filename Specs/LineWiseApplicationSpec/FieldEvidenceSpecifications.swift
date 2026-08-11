import Foundation
import LineWiseApplication
import LineWiseDomain

private final class ProbeFieldEvidenceStore: FieldEvidenceStore {
  var loadCount = 0
  var appendCount = 0
  var exportCount = 0
  var deleteCount = 0

  func load() throws -> FieldEvidenceArchive {
    loadCount += 1
    throw FieldEvidencePersistenceError.corruptedStore("probe must not be read")
  }

  func append(_ event: FieldEvidenceEvent) throws -> FieldEvidenceAppendOutcome {
    appendCount += 1
    throw FieldEvidencePersistenceError.ioFailure(
      operation: "append",
      path: "probe",
      reason: "probe must not be written"
    )
  }

  func exportData() throws -> Data {
    exportCount += 1
    throw FieldEvidencePersistenceError.corruptedStore("probe must not be exported")
  }

  func delete() throws {
    deleteCount += 1
    throw FieldEvidencePersistenceError.corruptedStore("probe must not be deleted")
  }
}

private final class FailingAppendFieldEvidenceStore: FieldEvidenceStore {
  func load() throws -> FieldEvidenceArchive {
    FieldEvidenceArchive(events: [])
  }

  func append(_ event: FieldEvidenceEvent) throws -> FieldEvidenceAppendOutcome {
    throw FieldEvidencePersistenceError.ioFailure(
      operation: "append",
      path: "test-boundary",
      reason: "injected failure"
    )
  }

  func exportData() throws -> Data {
    try FieldEvidenceArchiveCodec.encode(FieldEvidenceArchive(events: []))
  }

  func delete() throws {}
}

private func fieldEvidenceDefaultsOffWithoutTouchingItsStore() throws {
  let store = ProbeFieldEvidenceStore()
  var recorder = FieldEvidenceRecorder(store: store)

  let result = recorder.record(
    eventID: FieldEvidenceEventID("event-disabled"),
    marker: .attemptPrimaryActionTapped,
    occurredAt: Instant(millisecondsSince1970: 1_000)
  )

  try expect(result == .disabled, "expected field evidence to default off")
  try expect(recorder.currentSessionEvents.isEmpty, "expected no evidence in memory")
  try expect(store.loadCount == 0, "expected disabled mode not to read its store")
  try expect(store.appendCount == 0, "expected disabled mode not to write its store")
}

private func consentedFieldTestPersistsIdempotentlyAcrossRestart() throws {
  let store = MemoryFieldEvidenceStore()
  let consent = FieldEvidenceSessionConsent(
    sessionID: FieldEvidenceSessionID("field-session-restart"),
    consentedAt: Instant(millisecondsSince1970: 900)
  )
  var recorder = try FieldEvidenceRecorder(mode: .fieldTest(consent), store: store)

  let first = recorder.record(
    eventID: FieldEvidenceEventID("event-restart"),
    marker: .attemptPrimaryActionTapped,
    occurredAt: Instant(millisecondsSince1970: 1_000)
  )
  let retried = recorder.record(
    eventID: FieldEvidenceEventID("event-restart"),
    marker: .attemptPrimaryActionTapped,
    occurredAt: Instant(millisecondsSince1970: 1_000)
  )

  try expect(first == .inserted, "expected consented evidence to persist")
  try expect(retried == .duplicate, "expected retry to be idempotent")
  try expect(recorder.currentSessionEvents.count == 1, "expected one in-memory event")

  let reopened = try FieldEvidenceRecorder(mode: .fieldTest(consent), store: store)
  try expect(reopened.currentSessionEvents.count == 1, "expected event after restart")
  try expect(
    reopened.currentSessionEvents.first?.sessionID == consent.sessionID,
    "expected evidence to remain scoped to the consented session"
  )
}

private func routeDurationAndAttemptTapBurdenComeFromBoundedEvents() throws {
  let store = MemoryFieldEvidenceStore()
  let consent = FieldEvidenceSessionConsent(
    sessionID: FieldEvidenceSessionID("field-session-burden"),
    consentedAt: Instant(millisecondsSince1970: 500)
  )
  var recorder = try FieldEvidenceRecorder(mode: .fieldTest(consent), store: store)
  let taskID = FieldEvidenceTaskID("route-task-1")

  _ = recorder.record(
    eventID: FieldEvidenceEventID("event-route-start"),
    marker: .routeCardCreationStarted(taskID),
    occurredAt: Instant(millisecondsSince1970: 1_000)
  )
  _ = recorder.record(
    eventID: FieldEvidenceEventID("event-route-complete"),
    marker: .routeCardCreationCompleted(taskID),
    occurredAt: Instant(millisecondsSince1970: 3_500)
  )
  _ = recorder.record(
    eventID: FieldEvidenceEventID("event-attempt-tap"),
    marker: .attemptPrimaryActionTapped,
    occurredAt: Instant(millisecondsSince1970: 4_000)
  )

  let intent = LineWiseAppIntent.recordAttempt(
    actionID: ActionID("action-field-attempt"),
    attemptID: AttemptID("attempt-field"),
    occurredAt: Instant(millisecondsSince1970: 4_100),
    source: .watch
  )
  var app = LineWiseAppCoordinator()
  _ = app.handle(
    .startVisit(
      actionID: ActionID("action-field-visit"),
      visitID: GymVisitID("visit-field"),
      occurredAt: Instant(millisecondsSince1970: 3_900),
      source: .watch
    )
  )
  let feedback = app.handle(intent)
  _ = recorder.record(
    eventID: FieldEvidenceEventID("event-attempt-feedback"),
    intent: intent,
    feedback: feedback,
    occurredAt: Instant(millisecondsSince1970: 4_100)
  )

  let duration = recorder.report.metric(.routeCardCompletionDurationMilliseconds)
  try expect(duration?.numerator == 2_500, "expected measured RouteCard task duration")
  try expect(duration?.denominator == 1, "expected one completed RouteCard task")
  try expect(duration?.value == 2_500, "expected duration per completed RouteCard")

  let burden = recorder.report.metric(.attemptPrimaryActionTapBurden)
  try expect(burden?.numerator == 1, "expected one explicit primary-action tap")
  try expect(burden?.denominator == 1, "expected one Attempt interaction")
  try expect(burden?.value == 1, "expected one tap per Attempt")
}

private func manualLoopOutcomesProduceReliabilityRecallAndCorrectionMetrics() throws {
  let store = MemoryFieldEvidenceStore()
  let consent = FieldEvidenceSessionConsent(
    sessionID: FieldEvidenceSessionID("field-session-loop-metrics"),
    consentedAt: Instant(millisecondsSince1970: 100)
  )
  var recorder = try FieldEvidenceRecorder(mode: .fieldTest(consent), store: store)
  let projection = LineWiseAppCoordinator().projection

  let interactions: [(String, LineWiseAppIntent, LineWiseAppOutcome)] = [
    (
      "create-route",
      .createRoute(
        actionID: ActionID("action-metric-route"),
        routeCardID: RouteCardID("route-metric"),
        label: "must not be retained",
        availability: .present,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      ),
      .accepted
    ),
    (
      "attempt-save-failed",
      .recordAttempt(
        actionID: ActionID("action-metric-attempt"),
        attemptID: AttemptID("attempt-metric"),
        occurredAt: Instant(millisecondsSince1970: 2_000),
        source: .watch
      ),
      .persistenceFailed("must not be retained")
    ),
    (
      "review-began",
      .beginReview(
        actionID: ActionID("action-metric-review-began"),
        visitID: GymVisitID("visit-metric"),
        occurredAt: Instant(millisecondsSince1970: 3_000),
        source: .iPhone
      ),
      .accepted
    ),
    (
      "review-completed",
      .completeReview(
        actionID: ActionID("action-metric-review-completed"),
        visitID: GymVisitID("visit-metric"),
        occurredAt: Instant(millisecondsSince1970: 4_000),
        source: .iPhone
      ),
      .accepted
    ),
    (
      "route-corrected",
      .reviseRoute(
        actionID: ActionID("action-metric-route-corrected"),
        routeCardID: RouteCardID("route-metric"),
        revisedLabel: "also must not be retained",
        occurredAt: Instant(millisecondsSince1970: 5_000),
        source: .iPhone
      ),
      .accepted
    ),
    (
      "attempt-corrected",
      .correctAttemptRoute(
        actionID: ActionID("action-metric-attempt-corrected"),
        attemptID: AttemptID("attempt-metric"),
        routeCardID: RouteCardID("route-metric"),
        occurredAt: Instant(millisecondsSince1970: 6_000),
        source: .iPhone
      ),
      .accepted
    ),
  ]
  for (index, interaction) in interactions.enumerated() {
    _ = recorder.record(
      eventID: FieldEvidenceEventID("event-\(interaction.0)"),
      intent: interaction.1,
      feedback: LineWiseAppFeedback(outcome: interaction.2, projection: projection),
      occurredAt: Instant(millisecondsSince1970: Int64(index + 1) * 1_000)
    )
  }

  let cueID = FieldEvidenceCuePresentationID("cue-presentation-1")
  _ = recorder.record(
    eventID: FieldEvidenceEventID("event-cue-presented"),
    marker: .nextSessionCuePresented(cueID),
    occurredAt: Instant(millisecondsSince1970: 7_000)
  )
  _ = recorder.record(
    eventID: FieldEvidenceEventID("event-cue-actioned"),
    marker: .nextSessionCueActioned(cueID),
    occurredAt: Instant(millisecondsSince1970: 8_000)
  )

  let report = recorder.report
  try expect(
    report.metric(.saveAcceptedReliability)?.numerator == 5,
    "expected accepted saves in the reliability numerator"
  )
  try expect(
    report.metric(.saveAcceptedReliability)?.denominator == 6,
    "expected accepted and persistence-failed saves in the denominator"
  )
  try expect(
    report.metric(.savePersistenceFailureRate)?.numerator == 1,
    "expected one persistence failure"
  )
  try expect(
    report.metric(.reviewCompletion)?.value == 1,
    "expected completed Review per begun Review"
  )
  try expect(
    report.metric(.nextSessionCueActionRate)?.value == 1,
    "expected action on the presented NextSessionCue"
  )
  try expect(
    report.metric(.routeCorrectionCount)?.numerator == 1,
    "expected one accepted route correction"
  )
  try expect(
    report.metric(.attemptCorrectionCount)?.numerator == 1,
    "expected one accepted Attempt correction"
  )

  let exported = String(decoding: try store.exportData(), as: UTF8.self)
  try expect(!exported.contains("must not be retained"), "expected no labels or failure text")
  try expect(!exported.contains("action-metric-route"), "expected no product action ID")
  try expect(!exported.contains("route-metric"), "expected no RouteCard ID")
  try expect(!exported.contains("attempt-metric"), "expected no Attempt ID")
  try expect(!exported.contains("visit-metric"), "expected no GymVisit ID")
}

private func foundationStoreAtomicallyReopensExportsAndDeletesEvidence() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-field-evidence-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: directory) }
  let fileURL = directory.appendingPathComponent("field-evidence.json")
  let store = FoundationFileFieldEvidenceStore(fileURL: fileURL)
  let consent = FieldEvidenceSessionConsent(
    sessionID: FieldEvidenceSessionID("field-session-file"),
    consentedAt: Instant(millisecondsSince1970: 100)
  )
  var recorder = try FieldEvidenceRecorder(mode: .fieldTest(consent), store: store)
  try expect(
    recorder.record(
      eventID: FieldEvidenceEventID("event-file"),
      marker: .attemptPrimaryActionTapped,
      occurredAt: Instant(millisecondsSince1970: 1_000)
    ) == .inserted,
    "expected atomic file append"
  )

  let reopened = try FieldEvidenceRecorder(
    mode: .fieldTest(consent),
    store: FoundationFileFieldEvidenceStore(fileURL: fileURL)
  )
  try expect(reopened.currentSessionEvents.count == 1, "expected file-backed restart")
  let exported = try store.exportData()
  let exportedArchive = try FieldEvidenceArchiveCodec.decode(exported)
  try expect(
    exportedArchive.events.count == 1,
    "expected schema-valid local export"
  )

  try store.delete()
  let deletedArchive = try store.load()
  try expect(deletedArchive.events.isEmpty, "expected evidence deletion to be idempotent")
  try store.delete()
}

private func consentCannotBackfillEvidenceFromBeforeTheSession() throws {
  let store = MemoryFieldEvidenceStore()
  let consent = FieldEvidenceSessionConsent(
    sessionID: FieldEvidenceSessionID("field-session-consent-boundary"),
    consentedAt: Instant(millisecondsSince1970: 1_000)
  )
  var recorder = try FieldEvidenceRecorder(mode: .fieldTest(consent), store: store)

  let result = recorder.record(
    eventID: FieldEvidenceEventID("event-before-consent"),
    marker: .attemptPrimaryActionTapped,
    occurredAt: Instant(millisecondsSince1970: 999)
  )

  try expect(result == .beforeConsent, "expected evidence before consent to be refused")
  try expect(recorder.currentSessionEvents.isEmpty, "expected no pre-consent event in memory")
  let exported = try store.exportData()
  let emptyExport = try FieldEvidenceArchiveCodec.encode(FieldEvidenceArchive(events: []))
  try expect(exported == emptyExport, "expected no pre-consent event on disk")
}

private func corruptAndFutureFieldEvidenceArchivesAreRejected() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "linewise-field-evidence-schema-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: directory) }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let fileURL = directory.appendingPathComponent("field-evidence.json")
  let store = FoundationFileFieldEvidenceStore(fileURL: fileURL)

  try Data("not-json".utf8).write(to: fileURL, options: .atomic)
  do {
    _ = try store.load()
    throw ApplicationSpecFailure.expected("expected corrupted field evidence to fail")
  } catch FieldEvidencePersistenceError.corruptedStore {
    // Expected.
  }

  try Data(#"{"schemaVersion":99,"events":[]}"#.utf8).write(to: fileURL, options: .atomic)
  do {
    _ = try store.load()
    throw ApplicationSpecFailure.expected("expected future field evidence schema to fail")
  } catch FieldEvidencePersistenceError.unsupportedSchemaVersion(let version) {
    try expect(version == 99, "expected future schema version in the error")
  }
}

private func failedEvidenceWriteDoesNotAdvanceRecorderMemory() throws {
  let consent = FieldEvidenceSessionConsent(
    sessionID: FieldEvidenceSessionID("field-session-write-failure"),
    consentedAt: Instant(millisecondsSince1970: 100)
  )
  var recorder = try FieldEvidenceRecorder(
    mode: .fieldTest(consent),
    store: FailingAppendFieldEvidenceStore()
  )

  let result = recorder.record(
    eventID: FieldEvidenceEventID("event-write-failure"),
    marker: .attemptPrimaryActionTapped,
    occurredAt: Instant(millisecondsSince1970: 1_000)
  )

  guard case .failed = result else {
    throw ApplicationSpecFailure.expected("expected an observable evidence write failure")
  }
  try expect(recorder.currentSessionEvents.isEmpty, "expected failed write not to change memory")
  try expect(
    recorder.report.metric(.attemptPrimaryActionTapBurden)?.numerator == 0,
    "expected failed event not to affect a metric"
  )
}

private func everyMetricDeclaresMissingDataSourcesAndPrivacyScope() throws {
  let report = FieldEvidenceReport(events: [])
  try expect(
    report.metrics.count == FieldEvidenceMetricID.allCases.count,
    "expected one output for every field metric"
  )
  for metricID in FieldEvidenceMetricID.allCases {
    guard let metric = report.metric(metricID) else {
      throw ApplicationSpecFailure.expected("missing metric \(metricID.rawValue)")
    }
    try expect(metric.numerator == 0, "expected an explicit zero numerator")
    try expect(!metric.sourceEventKinds.isEmpty, "expected declared source event kinds")
    try expect(
      metric.privacyScope == .consentedFieldTestSessionOperationalMetadata,
      "expected session-scoped privacy"
    )
    switch metricID {
    case .routeCorrectionCount, .attemptCorrectionCount:
      try expect(metric.denominator == 1, "expected count denominator per consented session")
      try expect(metric.value == 0, "expected no correction to report zero")
      try expect(
        metric.missingDataBehavior == .zeroWhenNoMatchingEvent,
        "expected count missing data to be zero"
      )
    case .routeCardCompletionDurationMilliseconds, .attemptPrimaryActionTapBurden,
      .saveAcceptedReliability, .savePersistenceFailureRate, .reviewCompletion,
      .nextSessionCueActionRate:
      try expect(metric.denominator == 0, "expected absent opportunity denominator to be zero")
      try expect(metric.value == nil, "expected absent opportunity value to be unavailable")
    }
  }
}

func fieldEvidenceSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "field evidence defaults off without touching its store",
      fieldEvidenceDefaultsOffWithoutTouchingItsStore
    ),
    (
      "consented field test persists idempotently across restart",
      consentedFieldTestPersistsIdempotentlyAcrossRestart
    ),
    (
      "route duration and Attempt tap burden come from bounded events",
      routeDurationAndAttemptTapBurdenComeFromBoundedEvents
    ),
    (
      "manual loop outcomes produce reliability recall and correction metrics",
      manualLoopOutcomesProduceReliabilityRecallAndCorrectionMetrics
    ),
    (
      "Foundation store atomically reopens exports and deletes evidence",
      foundationStoreAtomicallyReopensExportsAndDeletesEvidence
    ),
    (
      "consent cannot backfill evidence from before the session",
      consentCannotBackfillEvidenceFromBeforeTheSession
    ),
    (
      "corrupt and future field evidence archives are rejected",
      corruptAndFutureFieldEvidenceArchivesAreRejected
    ),
    (
      "failed evidence write does not advance recorder memory",
      failedEvidenceWriteDoesNotAdvanceRecorderMemory
    ),
    (
      "every metric declares missing data sources and privacy scope",
      everyMetricDeclaresMissingDataSourcesAndPrivacyScope
    ),
  ]
}
