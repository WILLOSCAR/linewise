#if canImport(SwiftUI)
  import Combine
  import Foundation
  import LineWiseApplication
  import LineWiseDomain
  import SwiftUI

  public enum LineWiseExperienceSurfaceIssue: Equatable, Sendable {
    case validation(String)
    case operation(String)
    case persistence(String)

    public var message: String {
      switch self {
      case .validation(let message), .operation(let message), .persistence(let message):
        message
      }
    }
  }

  @MainActor
  public final class LineWiseExperienceViewModel: ObservableObject {
    @Published public private(set) var projection: LineWiseExperienceProjection
    @Published public private(set) var issue: LineWiseExperienceSurfaceIssue?

    private var coordinator: PersistentLineWiseExperienceCoordinator
    private var rehearsalEditorModels: [RouteRehearsalID: LineWiseRehearsalViewModel] = [:]

    public init(coordinator: PersistentLineWiseExperienceCoordinator) {
      self.coordinator = coordinator
      projection = coordinator.projection
    }

    public var pendingReviewItems: [ReviewInboxItemSnapshot] {
      projection.recall.reviewItems.filter { $0.status == .pending || $0.status == .snoozed }
    }

    public var reopenedNextSessionCues: [NextSessionCueSnapshot] {
      projection.reopenedNextSessionCues
    }

    public var notSentAttemptsAwaitingFailureReview: [AttemptSnapshot] {
      let reviewedAttemptIDs = Set(projection.recall.failureEpisodes.map(\.attemptID))
      return projection.capture.attempts.filter {
        $0.recordState == .active && $0.outcome == .notSent
          && !reviewedAttemptIDs.contains($0.id)
      }
    }

    public func reviewItem(for attemptID: AttemptID) -> ReviewInboxItemSnapshot? {
      projection.recall.reviewItems.first { item in
        switch item.kind {
        case .unresolvedAttempt(let id), .unassignedAttempt(let id):
          id == attemptID
        case .lateRecord, .conflictingRecord, .missingNextSessionCue:
          false
        }
      }
    }

    public let physiologyBoundaryMessage =
      "Subjective effort, fatigue, pump, and optional HealthKit summaries are training context only. They are not a diagnosis, safety assessment, or precise fatigue measurement."

    public func clearIssue() {
      issue = nil
    }

    public func refreshFromPersistence() {
      do {
        try coordinator.reload()
        _ = try coordinator.reconcileReviewInboxFromCapture()
        issue = nil
      } catch {
        issue = .persistence("Could not refresh the Review Inbox: \(error)")
      }
      syncProjection()
    }

    @discardableResult
    public func createRoute(
      label: String,
      routeCardID: RouteCardID = RouteCardID(UUID().uuidString),
      availability: RouteAvailability = .present,
      at occurredAt: Instant? = nil
    ) -> Bool {
      let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !label.isEmpty else {
        return rejectValidation("Route name cannot be empty.")
      }
      guard
        performCapture(
          .createRoute(
            actionID: makeActionID("create-route"),
            routeCardID: routeCardID,
            label: label,
            availability: availability,
            occurredAt: occurredAt ?? now,
            source: .iPhone
          )
        )
      else { return false }
      return performCapture(.selectRoute(routeCardID))
    }

    @discardableResult
    public func selectRoute(_ routeCardID: RouteCardID?) -> Bool {
      performCapture(.selectRoute(routeCardID))
    }

    @discardableResult
    public func renameRoute(
      _ routeCardID: RouteCardID,
      label: String,
      at occurredAt: Instant? = nil
    ) -> Bool {
      let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !label.isEmpty else {
        return rejectValidation("Route name cannot be empty.")
      }
      return performCapture(
        .reviseRoute(
          actionID: makeActionID("rename-route"),
          routeCardID: routeCardID,
          revisedLabel: label,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func archiveRoute(
      _ routeCardID: RouteCardID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .archiveRoute(
          actionID: makeActionID("archive-route"),
          routeCardID: routeCardID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func restoreRoute(
      _ routeCardID: RouteCardID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .restoreRoute(
          actionID: makeActionID("restore-route"),
          routeCardID: routeCardID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func setRouteAvailability(
      _ routeCardID: RouteCardID,
      availability: RouteAvailability,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .correctRouteAvailability(
          actionID: makeActionID("route-availability"),
          routeCardID: routeCardID,
          availability: availability,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func startProject(
      routeCardID: RouteCardID,
      projectID: ProjectID = ProjectID(UUID().uuidString),
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .startProject(
          actionID: makeActionID("start-project"),
          projectID: projectID,
          routeCardID: routeCardID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func archiveProject(
      _ projectID: ProjectID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .archiveProject(
          actionID: makeActionID("archive-project"),
          projectID: projectID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func startVisit(
      visitID: GymVisitID = GymVisitID(UUID().uuidString),
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .startVisit(
          actionID: makeActionID("start-visit"),
          visitID: visitID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func recordAttempt(
      attemptID: AttemptID = AttemptID(UUID().uuidString),
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .recordAttempt(
          actionID: makeActionID("record-attempt"),
          attemptID: attemptID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func markAttemptSend(
      _ attemptID: AttemptID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .markSend(
          actionID: makeActionID("mark-send"),
          attemptID: attemptID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func markAttemptNotSent(
      _ attemptID: AttemptID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .confirmNotSent(
          actionID: makeActionID("mark-not-sent"),
          attemptID: attemptID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func undoLatest(at occurredAt: Instant? = nil) -> Bool {
      guard let targetActionID = projection.capture.lastAcceptedActionID else {
        return rejectValidation("There is no reversible Attempt action.")
      }
      return performCapture(
        .undo(
          actionID: makeActionID("undo"),
          targetActionID: targetActionID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func startRest(
      restID: RestIntervalID = RestIntervalID(UUID().uuidString),
      afterAttemptID: AttemptID? = nil,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .startRest(
          actionID: makeActionID("start-rest"),
          restID: restID,
          afterAttemptID: afterAttemptID ?? projection.capture.currentRouteAttempts.last?.id,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func stopRest(at occurredAt: Instant? = nil) -> Bool {
      guard let rest = projection.capture.activeRest else {
        return rejectValidation("There is no active rest interval.")
      }
      return performCapture(
        .stopRest(
          actionID: makeActionID("stop-rest"),
          restID: rest.id,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func endVisitAndPrepareReview(at occurredAt: Instant? = nil) -> Bool {
      guard let visit = projection.capture.activeVisit else {
        return rejectValidation("There is no open gym visit to end.")
      }
      let time = occurredAt ?? now
      guard
        performCapture(
          .endVisit(
            actionID: makeActionID("end-visit"),
            occurredAt: time,
            source: .iPhone
          )
        )
      else { return false }
      guard
        performCapture(
          .beginReview(
            actionID: makeActionID("begin-review"),
            visitID: visit.id,
            occurredAt: time,
            source: .iPhone
          )
        )
      else { return false }
      return reconcileReviewInbox()
    }

    @discardableResult
    public func beginVisitReview(
      _ visitID: GymVisitID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performCapture(
        .beginReview(
          actionID: makeActionID("begin-review"),
          visitID: visitID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func completeVisitReview(
      _ visitID: GymVisitID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      let remaining = pendingReviewItems.filter { $0.visitID == visitID }
      guard remaining.isEmpty else {
        return rejectValidation("Resolve or skip every Review Inbox item before completing review.")
      }
      return performCapture(
        .completeReview(
          actionID: makeActionID("complete-review"),
          visitID: visitID,
          occurredAt: occurredAt ?? now,
          source: .iPhone
        )
      )
    }

    @discardableResult
    public func resolveAttemptAsSent(
      itemID: ReviewInboxItemID,
      attemptID: AttemptID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      let time = occurredAt ?? now
      guard markAttemptSend(attemptID, at: time) else { return false }
      return resolveReviewItemIfOpen(itemID, at: time)
    }

    @discardableResult
    public func resolveAttemptAsNotSent(
      itemID: ReviewInboxItemID,
      attemptID: AttemptID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      let time = occurredAt ?? now
      guard
        performCapture(
          .confirmNotSent(
            actionID: makeActionID("review-not-sent"),
            attemptID: attemptID,
            occurredAt: time,
            source: .iPhone
          )
        )
      else { return false }
      return resolveReviewItemIfOpen(itemID, at: time)
    }

    @discardableResult
    public func skipReviewItem(
      _ itemID: ReviewInboxItemID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performRecall(
        .dismissReviewItem(
          actionID: makeActionID("skip-review"),
          itemID: itemID,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func completeFailureReview(
      itemID: ReviewInboxItemID?,
      attemptID: AttemptID,
      routeCardID: RouteCardID,
      projectID: ProjectID,
      blocker: FailureBlocker,
      locationNote: String?,
      moveCueText: String,
      nextAction: String,
      failureEpisodeID: FailureEpisodeID = FailureEpisodeID(UUID().uuidString),
      moveCueID: MoveCueID = MoveCueID(UUID().uuidString),
      nextSessionCueID: NextSessionCueID = NextSessionCueID(UUID().uuidString),
      at occurredAt: Instant? = nil
    ) -> Bool {
      let cueText = moveCueText.trimmingCharacters(in: .whitespacesAndNewlines)
      let actionText = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cueText.isEmpty, !actionText.isEmpty else {
        return rejectValidation("Move cue and next-session action are both required.")
      }
      let time = occurredAt ?? now
      do {
        let outcome = try coordinator.completeFailureReview(
          FailureReviewRequest(
            failureActionID: makeActionID("failure-episode"),
            moveCueActionID: makeActionID("move-cue"),
            nextSessionCueActionID: makeActionID("next-session-cue"),
            episodeID: failureEpisodeID,
            attemptID: attemptID,
            routeCardID: routeCardID,
            primaryBlocker: blocker,
            locationNote: normalizedOptional(locationNote),
            moveCueID: moveCueID,
            moveCueText: cueText,
            nextSessionCueID: nextSessionCueID,
            projectID: projectID,
            nextAction: actionText,
            occurredAt: time
          )
        )
        syncProjection()
        switch outcome {
        case .accepted, .duplicate:
          if let itemID {
            return resolveReviewItemIfOpen(itemID, at: time)
          }
          issue = nil
          return true
        case .rejected(let stage, let reason):
          issue = .operation(
            "Could not save \(stage): \(reason). Nothing in the learning chain was added.")
          return false
        }
      } catch {
        issue = .persistence("Could not save the failure review: \(error)")
        syncProjection()
        return false
      }
    }

    @discardableResult
    public func completeNextSessionCue(
      _ cueID: NextSessionCueID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performRecall(
        .completeNextSessionCue(
          actionID: makeActionID("complete-next-session-cue"),
          cueID: cueID,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func deferNextSessionCue(
      _ cueID: NextSessionCueID,
      until: Instant? = nil,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performRecall(
        .deferNextSessionCue(
          actionID: makeActionID("defer-next-session-cue"),
          cueID: cueID,
          until: until,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func dismissNextSessionCue(
      _ cueID: NextSessionCueID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performRecall(
        .dismissNextSessionCue(
          actionID: makeActionID("dismiss-next-session-cue"),
          cueID: cueID,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func recordPhysiology(
      visitID: GymVisitID,
      sessionEffort1To10: Int?,
      wholeBodyFatigue0To10: Int?,
      forearmPumpOverall: ForearmPumpLevel?,
      healthKitSummary: HealthKitWorkoutSummary? = nil,
      contextID: PhysiologyContextID = PhysiologyContextID(UUID().uuidString),
      at recordedAt: Instant? = nil
    ) -> Bool {
      let subjective: SubjectivePhysiologyCheckIn? =
        sessionEffort1To10 == nil && wholeBodyFatigue0To10 == nil
          && forearmPumpOverall == nil
        ? nil
        : SubjectivePhysiologyCheckIn(
          sessionEffort1To10: sessionEffort1To10,
          wholeBodyFatigue0To10: wholeBodyFatigue0To10,
          forearmPumpOverall: forearmPumpOverall
        )
      do {
        let outcome = try coordinator.recordPhysiology(
          contextID: contextID,
          visitID: visitID,
          subjective: subjective,
          healthKitSummary: healthKitSummary,
          recordedAt: recordedAt ?? now
        )
        syncProjection()
        switch outcome {
        case .accepted:
          issue = nil
          return true
        case .rejected(let reason):
          issue = .operation("Could not save physiology context: \(reason).")
          return false
        }
      } catch {
        issue = .persistence("Could not save physiology context: \(error)")
        syncProjection()
        return false
      }
    }

    @discardableResult
    public func createManualRehearsalStarter(
      routeCardID: RouteCardID,
      plannedVisitID: GymVisitID? = nil,
      actualAttemptID: AttemptID? = nil,
      rehearsalID: RouteRehearsalID = RouteRehearsalID(UUID().uuidString)
    ) -> Bool {
      guard !projection.rehearsals.contains(where: { $0.rehearsal.id == rehearsalID }) else {
        return rejectValidation("This route rehearsal already exists.")
      }
      do {
        let engine = try manualStarterEngine(
          rehearsalID: rehearsalID,
          routeLabel: projection.capture.routeCards.first(where: { $0.id == routeCardID })?.label
            ?? "Manual route"
        )
        let outcome = try coordinator.attachRehearsal(
          engine,
          routeCardID: routeCardID,
          plannedVisitID: plannedVisitID,
          actualAttemptID: actualAttemptID
        )
        syncProjection()
        switch outcome {
        case .accepted:
          issue = nil
          return true
        case .rejected(let reason):
          issue = .operation("Could not create the route rehearsal: \(reason).")
          return false
        }
      } catch let error as ExperiencePersistenceError {
        issue = .persistence("Could not save the route rehearsal: \(error)")
        syncProjection()
        return false
      } catch {
        issue = .operation("Could not create the manual route rehearsal: \(error)")
        syncProjection()
        return false
      }
    }

    @discardableResult
    public func attachSuggestedRouteRead(
      _ result: RouteReadResult,
      routeCardID: RouteCardID,
      plannedVisitID: GymVisitID? = nil,
      confirmedStartHoldIDs: [HoldID] = [],
      rehearsalID: RouteRehearsalID = RouteRehearsalID(UUID().uuidString)
    ) -> Bool {
      guard projection.capture.routeCards.contains(where: { $0.id == routeCardID }) else {
        return rejectValidation("The RouteCard for this suggested read no longer exists.")
      }
      do {
        let outcome = try coordinator.attachRouteReadResult(
          result,
          routeCardID: routeCardID,
          rehearsalID: rehearsalID,
          bodyProfile: .generic(
            id: BodyProfileID("\(rehearsalID.rawValue)/generic-body")
          ),
          confirmedStartHoldIDs: confirmedStartHoldIDs,
          plannedVisitID: plannedVisitID
        )
        syncProjection()
        switch outcome {
        case .accepted:
          issue = nil
          return true
        case .rejected(let reason):
          issue = .operation("Could not save the suggested route read: \(reason).")
          return false
        }
      } catch {
        issue = .persistence("Could not persist the suggested route read: \(error)")
        syncProjection()
        return false
      }
    }

    public func rehearsalEditorModel(
      for rehearsalID: RouteRehearsalID
    ) -> LineWiseRehearsalViewModel? {
      if let cached = rehearsalEditorModels[rehearsalID] {
        return cached
      }
      guard
        let association = projection.rehearsals.first(where: {
          $0.rehearsal.id == rehearsalID
        })
      else {
        issue = .validation("The selected route rehearsal no longer exists.")
        return nil
      }
      do {
        let engine = try RouteRehearsalEngine(reopening: association.rehearsal)
        issue = nil
        let model = LineWiseRehearsalViewModel(
          coordinator: LineWiseRehearsalCoordinator(
            routeCardID: association.routeCardID,
            engine: engine,
            routeReadProvenance: association.routeReadProvenance,
            actualAttemptID: association.actualAttemptID
          )
        )
        model.updateConfirmedHistory(
          failureEpisodes: projection.recall.failureEpisodes.filter {
            $0.status == .userConfirmed
          },
          moveCues: projection.recall.moveCues.filter {
            $0.status == .userConfirmed
          }
        )
        rehearsalEditorModels[rehearsalID] = model
        return model
      } catch {
        issue = .operation("Could not open the route rehearsal: \(error)")
        return nil
      }
    }

    @discardableResult
    public func saveRehearsalEdits(_ rehearsalID: RouteRehearsalID) -> Bool {
      guard
        let editor = rehearsalEditorModels[rehearsalID],
        projection.rehearsals.contains(where: { $0.rehearsal.id == rehearsalID })
      else {
        return rejectValidation("Open the route rehearsal before saving edits.")
      }
      do {
        let replacement = try RouteRehearsalEngine(reopening: editor.rehearsalSnapshot)
        _ = try coordinator.updateRehearsal(rehearsalID) { engine in
          engine = replacement
        }
        syncProjection()
        issue = nil
        return true
      } catch let error as ExperiencePersistenceError {
        issue = .persistence("Could not save route rehearsal edits: \(error)")
        syncProjection()
        return false
      } catch {
        issue = .operation("Could not save route rehearsal edits: \(error)")
        syncProjection()
        return false
      }
    }

    @discardableResult
    public func saveSetterLensSuggestion(
      from rehearsalID: RouteRehearsalID,
      readingID: SetterLensReadingID = SetterLensReadingID(UUID().uuidString),
      at occurredAt: Instant? = nil
    ) -> Bool {
      guard let editor = rehearsalEditorModels[rehearsalID] else {
        return rejectValidation("Open the route rehearsal before saving its suggested reading.")
      }
      guard let result = editor.qualitativeAnalysis else {
        return rejectValidation("Run qualitative analysis before saving a SetterLens suggestion.")
      }
      do {
        let command = try QualitativeSetterLensBridge.suggestSetterLensReading(
          from: result,
          request: editor.qualitativeAnalysisRequest(),
          actionID: makeActionID("suggest-setter-lens"),
          readingID: readingID,
          occurredAt: occurredAt ?? now
        )
        return performLearning(command)
      } catch {
        issue = .operation("Could not prepare the suggested SetterLens reading: \(error)")
        return false
      }
    }

    @discardableResult
    public func acceptSetterLensReading(
      _ readingID: SetterLensReadingID,
      interpretationOverride: String? = nil,
      at occurredAt: Instant? = nil
    ) -> Bool {
      let override = interpretationOverride.map {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      if interpretationOverride != nil, override?.isEmpty != false {
        return rejectValidation("An edited SetterLens interpretation cannot be empty.")
      }
      return performLearning(
        .acceptSetterLensReading(
          actionID: makeActionID("accept-setter-lens"),
          readingID: readingID,
          interpretationOverride: override,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func rejectSetterLensReading(
      _ readingID: SetterLensReadingID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performLearning(
        .rejectSetterLensReading(
          actionID: makeActionID("reject-setter-lens"),
          readingID: readingID,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func draftTrainingPath(
      failureEpisodeID: FailureEpisodeID,
      moveCueID: MoveCueID,
      microDrillID: MicroDrillID,
      nextSessionCueID: NextSessionCueID,
      proofQuestion: String,
      pathID: TrainingPathID = TrainingPathID(UUID().uuidString),
      at occurredAt: Instant? = nil
    ) -> Bool {
      let question = proofQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !question.isEmpty else {
        return rejectValidation("A TrainingPath needs a next-session ProofCheck question.")
      }
      return performLearning(
        .draftTrainingPath(
          actionID: makeActionID("draft-training-path"),
          pathID: pathID,
          failureEpisodeID: failureEpisodeID,
          moveCueID: moveCueID,
          microDrillID: microDrillID,
          nextSessionCueID: nextSessionCueID,
          proofQuestion: question,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func activateTrainingPath(
      _ pathID: TrainingPathID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performLearning(
        .activateTrainingPath(
          actionID: makeActionID("activate-training-path"),
          pathID: pathID,
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func recordProofCheck(
      pathID: TrainingPathID,
      attemptID: AttemptID,
      outcome: ProofCheckOutcome,
      decision: ProofDecision,
      note: String? = nil,
      proofCheckID: ProofCheckID = ProofCheckID(UUID().uuidString),
      at occurredAt: Instant? = nil
    ) -> Bool {
      performLearning(
        .recordProofCheck(
          actionID: makeActionID("record-proof-check"),
          proofCheckID: proofCheckID,
          pathID: pathID,
          attemptID: attemptID,
          outcome: outcome,
          decision: decision,
          note: normalizedOptional(note),
          occurredAt: occurredAt ?? now
        )
      )
    }

    @discardableResult
    public func completeTrainingPath(
      _ pathID: TrainingPathID,
      at occurredAt: Instant? = nil
    ) -> Bool {
      performLearning(
        .completeTrainingPath(
          actionID: makeActionID("complete-training-path"),
          pathID: pathID,
          occurredAt: occurredAt ?? now
        )
      )
    }

    private func reconcileReviewInbox() -> Bool {
      do {
        _ = try coordinator.reconcileReviewInboxFromCapture()
        issue = nil
        syncProjection()
        return true
      } catch {
        issue = .persistence("Could not save the Review Inbox: \(error)")
        syncProjection()
        return false
      }
    }

    private func resolveReviewItemIfOpen(
      _ itemID: ReviewInboxItemID,
      at occurredAt: Instant
    ) -> Bool {
      guard let item = projection.recall.reviewItems.first(where: { $0.id == itemID }) else {
        return rejectValidation("The Review Inbox item no longer exists.")
      }
      guard item.status == .pending || item.status == .snoozed else {
        issue = nil
        return true
      }
      return performRecall(
        .resolveReviewItem(
          actionID: makeActionID("resolve-review"),
          itemID: itemID,
          occurredAt: occurredAt
        )
      )
    }

    private func performCapture(_ intent: LineWiseAppIntent) -> Bool {
      do {
        let feedback = try coordinator.handle(intent)
        syncProjection()
        guard feedback.isSuccess else {
          issue = .operation(captureFailureMessage(feedback.outcome))
          return false
        }
        issue = nil
        return true
      } catch {
        issue = .persistence("Could not save this change: \(error)")
        syncProjection()
        return false
      }
    }

    private func performRecall(_ command: RecallTrainingCommand) -> Bool {
      do {
        let outcome = try coordinator.submitRecall(command)
        syncProjection()
        switch outcome {
        case .accepted, .duplicate:
          issue = nil
          return true
        case .rejected(let reason):
          issue = .operation("Could not update review memory: \(reason).")
          return false
        }
      } catch {
        issue = .persistence("Could not save review memory: \(error)")
        syncProjection()
        return false
      }
    }

    private func performLearning(_ command: LearningLoopCommand) -> Bool {
      do {
        let outcome = try coordinator.submitLearning(command)
        syncProjection()
        switch outcome {
        case .accepted, .duplicate:
          issue = nil
          return true
        case .rejected(let reason):
          issue = .operation("Could not update the learning loop: \(reason).")
          return false
        }
      } catch {
        issue = .persistence("Could not save the learning loop: \(error)")
        syncProjection()
        return false
      }
    }

    private func rejectValidation(_ message: String) -> Bool {
      issue = .validation(message)
      return false
    }

    private func syncProjection() {
      projection = coordinator.projection
    }

    private func makeActionID(_ operation: String) -> ActionID {
      ActionID("experience-surface/\(operation)/\(UUID().uuidString)")
    }

    private var now: Instant {
      Instant(millisecondsSince1970: Int64(Date().timeIntervalSince1970 * 1_000))
    }

    private func manualStarterEngine(
      rehearsalID: RouteRehearsalID,
      routeLabel: String
    ) throws -> RouteRehearsalEngine {
      let leftStart = HoldID("\(rehearsalID.rawValue)/start-left")
      let rightStart = HoldID("\(rehearsalID.rawValue)/start-right")
      let scene = RouteScene(
        id: RouteSceneID("\(rehearsalID.rawValue)/scene"),
        name: "\(routeLabel) · manual rehearsal",
        size: SceneSize(width: 1_000, height: 1_600),
        metersPerSceneUnit: 0.0025,
        holds: [
          Hold(id: leftStart, center: Point2D(x: 390, y: 1_280), radius: 54, routeRole: .start),
          Hold(id: rightStart, center: Point2D(x: 610, y: 1_280), radius: 54, routeRole: .start),
          Hold(
            id: HoldID("\(rehearsalID.rawValue)/middle-left"),
            center: Point2D(x: 320, y: 930),
            radius: 48
          ),
          Hold(
            id: HoldID("\(rehearsalID.rawValue)/middle-right"),
            center: Point2D(x: 680, y: 830),
            radius: 48,
            routeRole: .zone
          ),
          Hold(
            id: HoldID("\(rehearsalID.rawValue)/upper"),
            center: Point2D(x: 470, y: 510),
            radius: 45
          ),
          Hold(
            id: HoldID("\(rehearsalID.rawValue)/top"),
            center: Point2D(x: 570, y: 210),
            radius: 58,
            routeRole: .top
          ),
        ]
      )
      let bodyProfile = BodyProfile.generic(
        id: BodyProfileID("\(rehearsalID.rawValue)/generic-body")
      )
      let starter = PoseKeyframe(
        id: PoseKeyframeID("\(rehearsalID.rawValue)/start-pose"),
        label: "Start",
        torsoPosition: Point2D(x: 500, y: 1_150),
        contacts: [
          LimbContact(limb: .leftHand, target: .hold(leftStart), mode: .hand),
          LimbContact(limb: .rightHand, target: .hold(rightStart), mode: .hand),
          LimbContact(limb: .leftFoot, target: .ground(Point2D(x: 430, y: 1_500)), mode: .foot),
          LimbContact(limb: .rightFoot, target: .ground(Point2D(x: 570, y: 1_500)), mode: .foot),
        ],
        provenance: .manual
      )
      return try RouteRehearsalEngine(
        rehearsalID: rehearsalID,
        scene: scene,
        bodyProfile: bodyProfile,
        planKeyframes: [starter]
      )
    }
  }

  @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
  @MainActor
  public struct LineWiseExperienceRootView: View {
    @StateObject private var model: LineWiseExperienceViewModel
    private let supportingHealthKitSummary: HealthKitWorkoutSummary?
    private let routeMediaLibrary: FoundationRouteMediaLibrary?
    private let routeMediaReadProvider: (any RouteMediaReadProviding)?

    @State private var newRouteLabel = ""
    @State private var editingRouteID: RouteCardID?
    @State private var routeRenameDraft = ""
    @State private var failureAttemptID: AttemptID?
    @State private var blockerRawValue = FailureBlocker.unknown.rawValue
    @State private var failureLocation = ""
    @State private var moveCueDraft = ""
    @State private var nextActionDraft = ""
    @State private var physiologyVisitRawValue = ""
    @State private var effort = 5
    @State private var fatigue = 5
    @State private var pumpRawValue = ForearmPumpLevel.moderate.rawValue
    @State private var setterLensEditDrafts: [String: String] = [:]
    @State private var showsRouteIntelligence = false

    public init(
      model: @autoclosure @escaping () -> LineWiseExperienceViewModel,
      supportingHealthKitSummary: HealthKitWorkoutSummary? = nil,
      routeMediaLibrary: FoundationRouteMediaLibrary? = nil,
      routeMediaReadProvider: (any RouteMediaReadProviding)? = nil
    ) {
      _model = StateObject(wrappedValue: model())
      self.supportingHealthKitSummary = supportingHealthKitSummary
      self.routeMediaLibrary = routeMediaLibrary
      self.routeMediaReadProvider = routeMediaReadProvider
    }

    public var body: some View {
      NavigationView {
        List {
          if let issue = model.issue {
            issueSection(issue)
          }
          if model.projection.capture.routeCards.isEmpty {
            firstRunSection
          }
          nextSessionCueSection
          currentVisitSection
          routeMemorySection
          projectSection
          reviewInboxSection
          failureReviewSection
          physiologySection
          routeIntelligenceAccessSection
          if showsRouteIntelligence {
            routeMediaSection
            rehearsalSection
            learningLoopSection
          }
        }
        .navigationTitle("LineWise")
      }
    }

    @ViewBuilder
    private var routeMediaSection: some View {
      #if os(iOS)
        if let routeMediaLibrary,
          let route = model.projection.capture.currentRouteCard
            ?? model.projection.capture.selectableRouteCards.first
        {
          Section("Private route media") {
            NavigationLink {
              RouteMediaImportSurface(
                library: routeMediaLibrary,
                routeCardID: route.id,
                routeReadProvider: routeMediaReadProvider,
                onRouteRead: { result in
                  model.attachSuggestedRouteRead(
                    result,
                    routeCardID: route.id,
                    plannedVisitID: model.projection.capture.activeVisit?.id
                  )
                }
              )
            } label: {
              Label("Add media for \(route.label)", systemImage: "photo.on.rectangle.angled")
            }
            Text("Local storage and optional AI processing require separate consent actions.")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      #endif
    }

    private var routeIntelligenceAccessSection: some View {
      Section("Optional route intelligence") {
        Toggle("Show RouteRehearsal, SetterLens, and training tools", isOn: $showsRouteIntelligence)
        Text(
          "The manual visit, review, and next-session memory loop works without these tools. Any automatic route read remains a suggestion that you can edit or reject."
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }

    private func issueSection(_ issue: LineWiseExperienceSurfaceIssue) -> some View {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Label(issueTitle(issue), systemImage: "exclamationmark.triangle.fill")
            .font(.headline)
            .foregroundColor(.red)
          Text(issue.message)
            .fixedSize(horizontal: false, vertical: true)
          Button("Dismiss message") { model.clearIssue() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error. \(issue.message)")
      }
    }

    private var firstRunSection: some View {
      Section("Start your route memory") {
        Label("No RouteCards yet", systemImage: "square.stack.3d.up.slash")
          .font(.headline)
        Text(
          "Name one gym route in your own words. LineWise does not need an official gym database or AI to begin."
        )
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }

    @ViewBuilder
    private var nextSessionCueSection: some View {
      if !model.reopenedNextSessionCues.isEmpty {
        Section("Before the next try") {
          ForEach(model.reopenedNextSessionCues, id: \.id.rawValue) { cue in
            VStack(alignment: .leading, spacing: 10) {
              Label("Next-session cue", systemImage: "lightbulb.fill")
                .font(.headline)
              Text(cue.nextAction)
                .fixedSize(horizontal: false, vertical: true)
              HStack {
                Button("Completed") { model.completeNextSessionCue(cue.id) }
                Button("Later") { model.deferNextSessionCue(cue.id) }
                Button("Ignore") { model.dismissNextSessionCue(cue.id) }
              }
              .buttonStyle(.bordered)
            }
            .accessibilityElement(children: .contain)
          }
        }
      }
    }

    private var currentVisitSection: some View {
      Section("Gym Visit") {
        if let visit = model.projection.capture.activeVisit {
          Label("Visit in progress", systemImage: "figure.climbing")
            .font(.headline)
          Text("Visit \(shortIdentifier(visit.id.rawValue))")
            .font(.caption)
            .foregroundColor(.secondary)

          if !model.projection.capture.selectableRouteCards.isEmpty {
            Picker(
              "Current route",
              selection: Binding(
                get: { model.projection.capture.currentRouteCard?.id.rawValue ?? "" },
                set: { rawValue in
                  model.selectRoute(
                    rawValue.isEmpty ? nil : RouteCardID(rawValue)
                  )
                }
              )
            ) {
              Text("No route selected").tag("")
              ForEach(model.projection.capture.selectableRouteCards, id: \.id.rawValue) { route in
                Text(route.label).tag(route.id.rawValue)
              }
            }
          }

          Button {
            model.recordAttempt()
          } label: {
            Label("Record Attempt", systemImage: "plus.circle.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(model.projection.capture.currentRouteCard == nil)
          .accessibilityHint("Adds one unresolved try to the selected RouteCard")

          if let attempt = latestCurrentAttempt {
            HStack {
              Label(
                attemptOutcomeText(attempt.outcome),
                systemImage: attemptOutcomeSymbol(attempt.outcome))
              Spacer()
              Text("\(model.projection.capture.currentRouteAttemptCount) tries")
                .foregroundColor(.secondary)
            }
            if attempt.outcome != .sent {
              Button("Mark latest Send") { model.markAttemptSend(attempt.id) }
            }
            if attempt.outcome != .notSent {
              Button("Mark latest Not Sent") { model.markAttemptNotSent(attempt.id) }
            }
          }

          Button(model.projection.capture.activeRest == nil ? "Start rest" : "Stop rest") {
            if model.projection.capture.activeRest == nil {
              model.startRest()
            } else {
              model.stopRest()
            }
          }
          .accessibilityHint("Rest is a pacing note, not a medical prescription")

          Button("Undo latest Attempt action") { model.undoLatest() }
            .disabled(model.projection.capture.lastAcceptedActionID == nil)

          Button("End Visit and review", role: .destructive) {
            model.endVisitAndPrepareReview()
          }
        } else {
          Label("No Visit in progress", systemImage: "pause.circle")
          ForEach(
            model.projection.capture.visits.filter {
              $0.captureState == .ended
                && ($0.reviewState == .pendingReview || $0.reviewState == .needsRecheck)
            },
            id: \.id.rawValue
          ) { visit in
            Button {
              model.beginVisitReview(visit.id)
            } label: {
              Label("Review ended Visit", systemImage: "checklist")
            }
          }
          Button {
            model.startVisit()
          } label: {
            Label("Start Gym Visit", systemImage: "play.circle.fill")
          }
          .buttonStyle(.borderedProminent)
        }
      }
    }

    private var routeMemorySection: some View {
      Section("RouteCards") {
        TextField("Route name, color, or wall location", text: $newRouteLabel)
          .accessibilityLabel("New RouteCard name")
        Button("Create and select RouteCard") {
          if model.createRoute(label: newRouteLabel) {
            newRouteLabel = ""
          }
        }

        ForEach(model.projection.capture.routeCards, id: \.id.rawValue) { route in
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
              Button {
                model.selectRoute(route.id)
              } label: {
                Label(
                  route.label,
                  systemImage: model.projection.capture.currentRouteCard?.id == route.id
                    ? "checkmark.circle.fill" : "circle"
                )
              }
              .disabled(route.recordVisibility != .active || route.availability == .gone)
              Spacer()
              routeStateLabel(route)
            }

            if editingRouteID == route.id {
              TextField("Updated route name", text: $routeRenameDraft)
              HStack {
                Button("Save name") {
                  if model.renameRoute(route.id, label: routeRenameDraft) {
                    editingRouteID = nil
                  }
                }
                Button("Cancel") { editingRouteID = nil }
              }
            } else {
              HStack {
                Button("Rename") {
                  routeRenameDraft = route.label
                  editingRouteID = route.id
                }
                if route.recordVisibility == .archived {
                  Button("Restore") { model.restoreRoute(route.id) }
                } else if route.recordVisibility == .active {
                  Button("Archive") { model.archiveRoute(route.id) }
                }
                Button(route.availability == .gone ? "Mark present" : "Mark gone") {
                  model.setRouteAvailability(
                    route.id,
                    availability: route.availability == .gone ? .present : .gone
                  )
                }
              }
              .buttonStyle(.bordered)

              if route.recordVisibility == .active && route.availability != .gone
                && activeProject(for: route.id) == nil
              {
                Button("Start Project") { model.startProject(routeCardID: route.id) }
              }
            }
          }
          .accessibilityElement(children: .contain)
        }
      }
    }

    @ViewBuilder
    private var projectSection: some View {
      if !model.projection.capture.projects.isEmpty {
        Section("Projects") {
          ForEach(model.projection.capture.projects, id: \.id.rawValue) { project in
            HStack {
              Label(
                routeLabel(project.routeCardID),
                systemImage: project.state == .active ? "bookmark.fill" : "archivebox"
              )
              Spacer()
              Text(projectStateText(project.state))
                .foregroundColor(.secondary)
              if project.state == .active {
                Button("Archive") { model.archiveProject(project.id) }
              }
            }
          }
        }
      }
    }

    @ViewBuilder
    private var reviewInboxSection: some View {
      if !model.pendingReviewItems.isEmpty
        || model.projection.capture.visits.contains(where: { $0.reviewState == .reviewing })
      {
        Section("Review Inbox") {
          Text(
            "Unresolved means unknown. Choose Send, Not Sent, or Skip; LineWise never turns it into a failure automatically."
          )
          .font(.callout)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)

          ForEach(model.pendingReviewItems, id: \.id.rawValue) { item in
            VStack(alignment: .leading, spacing: 8) {
              Label(reviewItemTitle(item), systemImage: "questionmark.circle")
                .font(.headline)
              if let attemptID = reviewAttemptID(item) {
                HStack {
                  Button("Send") {
                    model.resolveAttemptAsSent(itemID: item.id, attemptID: attemptID)
                  }
                  Button("Not Sent") {
                    if model.resolveAttemptAsNotSent(itemID: item.id, attemptID: attemptID) {
                      beginFailureForm(for: attemptID)
                    }
                  }
                  Button("Skip") { model.skipReviewItem(item.id) }
                }
                .buttonStyle(.bordered)
              } else {
                Button("Skip this item") { model.skipReviewItem(item.id) }
              }
            }
          }

          ForEach(
            model.projection.capture.visits.filter { $0.reviewState == .reviewing },
            id: \.id.rawValue
          ) { visit in
            Button("Complete Visit review") { model.completeVisitReview(visit.id) }
              .disabled(model.pendingReviewItems.contains(where: { $0.visitID == visit.id }))
          }
        }
      }
    }

    @ViewBuilder
    private var failureReviewSection: some View {
      if !model.notSentAttemptsAwaitingFailureReview.isEmpty {
        Section("Not Sent · learning memory") {
          Text(
            "Adding a blocker is optional. If you add one, LineWise saves the blocker, MoveCue, and NextSessionCue together."
          )
          .font(.callout)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)

          ForEach(model.notSentAttemptsAwaitingFailureReview, id: \.id.rawValue) { attempt in
            VStack(alignment: .leading, spacing: 8) {
              Label(routeLabel(attempt.routeCardID), systemImage: "xmark.circle")
              if failureAttemptID != attempt.id {
                Button("Add blocker and cue") { beginFailureForm(for: attempt.id) }
              } else {
                failureComposer(for: attempt)
              }
            }
          }
        }
      }
    }

    @ViewBuilder
    private func failureComposer(for attempt: AttemptSnapshot) -> some View {
      if let routeID = attempt.routeCardID, let project = activeProject(for: routeID) {
        Picker("Primary blocker", selection: $blockerRawValue) {
          ForEach(Self.blockerOptions, id: \.rawValue) { blocker in
            Text(blockerText(blocker)).tag(blocker.rawValue)
          }
        }
        TextField("Where did it break down? (optional)", text: $failureLocation)
        TextField("MoveCue: what will you remember?", text: $moveCueDraft)
        TextField("Next Visit: what will you try?", text: $nextActionDraft)
        Button("Save blocker, MoveCue, and NextSessionCue") {
          let blocker = Self.blockerOptions.first { $0.rawValue == blockerRawValue } ?? .unknown
          if model.completeFailureReview(
            itemID: model.reviewItem(for: attempt.id)?.id,
            attemptID: attempt.id,
            routeCardID: routeID,
            projectID: project.id,
            blocker: blocker,
            locationNote: failureLocation,
            moveCueText: moveCueDraft,
            nextAction: nextActionDraft
          ) {
            clearFailureForm()
          }
        }
        .buttonStyle(.borderedProminent)
        Button("Cancel") { clearFailureForm() }
      } else {
        Label(
          "Start an active Project for this RouteCard before creating a NextSessionCue.",
          systemImage: "exclamationmark.circle"
        )
        .foregroundColor(.secondary)
        Button("Cancel") { clearFailureForm() }
      }
    }

    private var learningLoopSection: some View {
      Section("SetterLens & TrainingPath") {
        Text(
          "All route readings are suggestions until you accept, edit, or reject them. LineWise editorial v0 drills are optional movement-practice prompts, not medical advice or safety judgments."
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        if model.projection.approvedMicroDrills.isEmpty {
          Label("No approved MicroDrills are installed", systemImage: "books.vertical")
            .foregroundColor(.secondary)
        } else {
          ForEach(model.projection.approvedMicroDrills, id: \.id.rawValue) { drill in
            VStack(alignment: .leading, spacing: 4) {
              Label(drill.title, systemImage: "figure.climbing")
                .font(.headline)
              Text(drill.instructions)
                .font(.callout)
              Text("Proof: \(drill.successCriterion)")
                .font(.caption)
                .foregroundColor(.secondary)
              Text(drill.sourceReference)
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
            }
          }
        }

        if model.projection.learning.setterLensReadings.isEmpty {
          Text(
            "Run qualitative analysis in a Route rehearsal, then explicitly save it as a suggested SetterLens reading."
          )
          .font(.callout)
          .foregroundColor(.secondary)
        } else {
          ForEach(model.projection.learning.setterLensReadings, id: \.id.rawValue) { reading in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Label("SetterLens", systemImage: "eye")
                  .font(.headline)
                Spacer()
                Text(setterLensStatusText(reading.status))
                  .font(.caption.bold())
                  .foregroundColor(reading.status == .suggested ? .orange : .secondary)
              }
              Text(reading.interpretation)
                .fixedSize(horizontal: false, vertical: true)
              if let alternative = reading.alternativeInterpretation {
                Text(alternative)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Text(
                "Suggested · \(reading.suggestionProvenance.sourceReference) · \(reading.suggestionProvenance.sourceVersion)"
              )
              .font(.caption2.monospaced())
              .foregroundColor(.secondary)

              if reading.status == .suggested {
                TextField(
                  "Edit before accepting",
                  text: Binding(
                    get: {
                      setterLensEditDrafts[reading.id.rawValue] ?? reading.interpretation
                    },
                    set: { setterLensEditDrafts[reading.id.rawValue] = $0 }
                  )
                )
                HStack {
                  Button("Accept") {
                    if model.acceptSetterLensReading(reading.id) {
                      setterLensEditDrafts.removeValue(forKey: reading.id.rawValue)
                    }
                  }
                  Button("Accept edit") {
                    let draft =
                      setterLensEditDrafts[reading.id.rawValue] ?? reading.interpretation
                    if model.acceptSetterLensReading(
                      reading.id,
                      interpretationOverride: draft
                    ) {
                      setterLensEditDrafts.removeValue(forKey: reading.id.rawValue)
                    }
                  }
                  Button("Reject", role: .destructive) {
                    if model.rejectSetterLensReading(reading.id) {
                      setterLensEditDrafts.removeValue(forKey: reading.id.rawValue)
                    }
                  }
                }
                .buttonStyle(.bordered)
              }
            }
          }
        }

        ForEach(
          model.projection.recall.failureEpisodes.filter { $0.status == .userConfirmed },
          id: \.id.rawValue
        ) { failure in
          if let moveCue = model.projection.recall.moveCues.first(where: {
            $0.failureEpisodeID == failure.id
              && ($0.status == .userAuthored || $0.status == .userConfirmed)
          }),
            let nextCue = model.projection.recall.nextSessionCues.first(where: {
              $0.failureEpisodeID == failure.id && $0.moveCueID == moveCue.id
            }),
            !model.projection.learning.trainingPaths.contains(where: {
              $0.failureEpisodeID == failure.id
            })
          {
            VStack(alignment: .leading, spacing: 6) {
              Text("Practice candidate")
                .font(.headline)
              Text(moveCue.text)
              Text("Next session: \(nextCue.nextAction)")
                .font(.caption)
                .foregroundColor(.secondary)
              ForEach(model.projection.approvedMicroDrills, id: \.id.rawValue) { drill in
                Button("Draft path with \(drill.title)") {
                  model.draftTrainingPath(
                    failureEpisodeID: failure.id,
                    moveCueID: moveCue.id,
                    microDrillID: drill.id,
                    nextSessionCueID: nextCue.id,
                    proofQuestion: proofQuestion(for: moveCue)
                  )
                }
                .buttonStyle(.bordered)
              }
            }
          }
        }

        ForEach(model.projection.learning.trainingPaths, id: \.id.rawValue) { path in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Label(
                path.microDrill.title,
                systemImage: "point.topleft.down.curvedto.point.bottomright.up"
              )
              .font(.headline)
              Spacer()
              Text(trainingPathStatusText(path.status))
                .font(.caption.bold())
            }
            Text(path.proofQuestion)
              .font(.callout)

            switch path.status {
            case .draft:
              Button("Activate TrainingPath") { model.activateTrainingPath(path.id) }
                .buttonStyle(.borderedProminent)
            case .active:
              let attempts = activeAttempts(for: path)
              if attempts.isEmpty {
                Label(
                  "Record a real Attempt on this RouteCard before ProofCheck",
                  systemImage: "record.circle"
                )
                .font(.caption)
                .foregroundColor(.secondary)
              } else {
                ForEach(attempts, id: \.id.rawValue) { attempt in
                  VStack(alignment: .leading, spacing: 6) {
                    Text("Attempt \(shortIdentifier(attempt.id.rawValue))")
                      .font(.caption.monospaced())
                    HStack {
                      Button("Retain") {
                        model.recordProofCheck(
                          pathID: path.id,
                          attemptID: attempt.id,
                          outcome: .triedTargetBehaviorChanged,
                          decision: .retain
                        )
                      }
                      Button("Revise") {
                        model.recordProofCheck(
                          pathID: path.id,
                          attemptID: attempt.id,
                          outcome: .triedNoObservableChange,
                          decision: .revise
                        )
                      }
                      Button("Reject", role: .destructive) {
                        model.recordProofCheck(
                          pathID: path.id,
                          attemptID: attempt.id,
                          outcome: .interpretationAppearsWrong,
                          decision: .reject
                        )
                      }
                    }
                    .buttonStyle(.bordered)
                  }
                }
              }
            case .retained:
              Button("Complete retained path") { model.completeTrainingPath(path.id) }
                .buttonStyle(.borderedProminent)
            case .revisionRequested, .rejected, .completed:
              EmptyView()
            }

            ForEach(
              model.projection.learning.proofChecks.filter { $0.pathID == path.id },
              id: \.id.rawValue
            ) { proof in
              Text(
                "ProofCheck · Attempt \(shortIdentifier(proof.attemptID.rawValue)) · \(proofDecisionText(proof.decision))"
              )
              .font(.caption.monospaced())
              .foregroundColor(.secondary)
            }
          }
        }
      }
    }

    @ViewBuilder
    private var physiologySection: some View {
      let visits = endedVisits
      if !visits.isEmpty {
        Section("How did this Visit feel?") {
          Picker("Gym Visit", selection: $physiologyVisitRawValue) {
            ForEach(visits, id: \.id.rawValue) { visit in
              Text("Visit \(shortIdentifier(visit.id.rawValue))").tag(visit.id.rawValue)
            }
          }
          Stepper("Session effort: \(effort) / 10", value: $effort, in: 1...10)
          Stepper("Whole-body fatigue: \(fatigue) / 10", value: $fatigue, in: 0...10)
          Picker("Forearm pump", selection: $pumpRawValue) {
            Text("None").tag(ForearmPumpLevel.none.rawValue)
            Text("Light").tag(ForearmPumpLevel.light.rawValue)
            Text("Moderate").tag(ForearmPumpLevel.moderate.rawValue)
            Text("Strong").tag(ForearmPumpLevel.strong.rawValue)
            Text("Maximal").tag(ForearmPumpLevel.maximal.rawValue)
          }

          if let summary = supportingHealthKitSummary {
            Label(
              "Optional HealthKit context available · \(Int(summary.durationSeconds / 60)) min",
              systemImage: "heart.text.square"
            )
          } else {
            Label("No HealthKit summary attached", systemImage: "heart.slash")
              .foregroundColor(.secondary)
          }
          Text(model.physiologyBoundaryMessage)
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

          Button("Save subjective check-in") {
            guard let visitID = selectedPhysiologyVisitID else { return }
            model.recordPhysiology(
              visitID: visitID,
              sessionEffort1To10: effort,
              wholeBodyFatigue0To10: fatigue,
              forearmPumpOverall: ForearmPumpLevel(rawValue: pumpRawValue),
              healthKitSummary: supportingHealthKitSummary
            )
          }
          .buttonStyle(.borderedProminent)

          ForEach(model.projection.physiologyContexts, id: \.id.rawValue) { context in
            Label(
              physiologySummary(context),
              systemImage: "checkmark.seal"
            )
            .font(.caption)
          }
        }
      }
    }

    private var rehearsalSection: some View {
      Section("Route rehearsal") {
        Text(
          "Start manually with editable holds and a four-limb pose. AI route reading is optional and is not required for this workflow."
        )
        .font(.callout)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        if let route = model.projection.capture.currentRouteCard
          ?? model.projection.capture.selectableRouteCards.first
        {
          Button("Create manual starter for \(route.label)") {
            model.createManualRehearsalStarter(
              routeCardID: route.id,
              plannedVisitID: model.projection.capture.activeVisit?.id,
              actualAttemptID: model.projection.capture.currentRouteAttempts.last?.id
            )
          }
        } else {
          Label("Create or restore a selectable RouteCard first", systemImage: "info.circle")
        }

        ForEach(model.projection.rehearsals, id: \.rehearsal.id.rawValue) { association in
          if let editor = model.rehearsalEditorModel(for: association.rehearsal.id) {
            NavigationLink {
              LineWiseExperienceRehearsalDestination(
                experienceModel: model,
                editorModel: editor,
                rehearsalID: association.rehearsal.id
              )
            } label: {
              Label(association.rehearsal.scene.name, systemImage: "figure.climbing")
            }
            .accessibilityHint(
              "Opens four-limb pose editing, timeline playback, and single-step controls")
          }
        }
      }
    }

    private var latestCurrentAttempt: AttemptSnapshot? {
      model.projection.capture.currentRouteAttempts.last
    }

    private var endedVisits: [GymVisitSnapshot] {
      model.projection.capture.visits.filter { $0.captureState == .ended }
    }

    private var selectedPhysiologyVisitID: GymVisitID? {
      if !physiologyVisitRawValue.isEmpty {
        return GymVisitID(physiologyVisitRawValue)
      }
      return endedVisits.last?.id
    }

    private func activeProject(for routeID: RouteCardID) -> ProjectSnapshot? {
      model.projection.capture.projects.last {
        $0.routeCardID == routeID && $0.state == .active
      }
    }

    private func routeLabel(_ routeID: RouteCardID?) -> String {
      guard let routeID else { return "Unassigned route" }
      return model.projection.capture.routeCards.first { $0.id == routeID }?.label
        ?? "Unknown RouteCard"
    }

    private func reviewAttemptID(_ item: ReviewInboxItemSnapshot) -> AttemptID? {
      switch item.kind {
      case .unresolvedAttempt(let id), .unassignedAttempt(let id): id
      case .lateRecord, .conflictingRecord, .missingNextSessionCue: nil
      }
    }

    private func reviewItemTitle(_ item: ReviewInboxItemSnapshot) -> String {
      guard let attemptID = reviewAttemptID(item) else { return "Review captured record" }
      let attempt = model.projection.capture.attempts.first { $0.id == attemptID }
      return "Unresolved Attempt · \(routeLabel(attempt?.routeCardID))"
    }

    private func beginFailureForm(for attemptID: AttemptID) {
      failureAttemptID = attemptID
      blockerRawValue = FailureBlocker.unknown.rawValue
      failureLocation = ""
      moveCueDraft = ""
      nextActionDraft = ""
    }

    private func clearFailureForm() {
      failureAttemptID = nil
      failureLocation = ""
      moveCueDraft = ""
      nextActionDraft = ""
    }

    private func routeStateLabel(_ route: RouteCardSnapshot) -> some View {
      let status: String
      let symbol: String
      if route.recordVisibility == .archived {
        status = "Archived"
        symbol = "archivebox"
      } else if route.availability == .gone {
        status = "Gone · history kept"
        symbol = "clock.arrow.circlepath"
      } else {
        status = "Available"
        symbol = "checkmark.circle"
      }
      return Label(status, systemImage: symbol)
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func physiologySummary(_ context: PhysiologyContextSnapshot) -> String {
      let effortText = context.reportedSessionEffort1To10.map { "effort \($0)/10" } ?? "no effort"
      let fatigueText =
        context.reportedWholeBodyFatigue0To10.map { "fatigue \($0)/10" }
        ?? "no fatigue"
      return "Saved \(effortText), \(fatigueText) · context only"
    }

    private func issueTitle(_ issue: LineWiseExperienceSurfaceIssue) -> String {
      switch issue {
      case .validation: "Check this entry"
      case .operation: "Could not apply the change"
      case .persistence: "Could not save"
      }
    }

    private func projectStateText(_ state: ProjectState) -> String {
      switch state {
      case .active: "Active"
      case .sent: "Sent"
      case .archived: "Archived"
      case .gone: "Route gone"
      }
    }

    private func attemptOutcomeText(_ outcome: AttemptOutcome) -> String {
      switch outcome {
      case .unresolved: "Unresolved"
      case .sent: "Send"
      case .notSent: "Not Sent"
      }
    }

    private func attemptOutcomeSymbol(_ outcome: AttemptOutcome) -> String {
      switch outcome {
      case .unresolved: "questionmark.circle"
      case .sent: "checkmark.circle.fill"
      case .notSent: "xmark.circle"
      }
    }

    private func blockerText(_ blocker: FailureBlocker) -> String {
      switch blocker {
      case .sequence: "Sequence"
      case .footwork: "Footwork"
      case .bodyPosition: "Body position"
      case .bodyTension: "Body tension"
      case .dynamicTiming: "Dynamic timing"
      case .reachOrLockoff: "Reach or lock-off"
      case .hookOrCompression: "Hook or compression"
      case .topoutOrFinish: "Top-out or finish"
      case .fearOrCommitment: "Fear or commitment"
      case .enduranceOrPacing: "Endurance or pacing"
      case .unknown: "Not sure yet"
      }
    }

    private func activeAttempts(for path: TrainingPathSnapshot) -> [AttemptSnapshot] {
      model.projection.capture.attempts.filter {
        $0.routeCardID == path.routeCardID && $0.recordState == .active
          && $0.occurredAt > path.createdAt
      }
    }

    private func proofQuestion(for moveCue: MoveCueSnapshot) -> String {
      "On a real Attempt, did this happen before the crux: \(moveCue.text)?"
    }

    private func setterLensStatusText(_ status: SetterLensReadingStatus) -> String {
      switch status {
      case .suggested: "Suggested · needs your decision"
      case .userConfirmed: "User confirmed"
      case .rejected: "Rejected"
      }
    }

    private func trainingPathStatusText(_ status: TrainingPathStatus) -> String {
      switch status {
      case .draft: "Draft"
      case .active: "Active"
      case .retained: "Retained"
      case .revisionRequested: "Revise"
      case .rejected: "Rejected"
      case .completed: "Completed"
      }
    }

    private func proofDecisionText(_ decision: ProofDecision) -> String {
      switch decision {
      case .retain: "Retain"
      case .revise: "Revise"
      case .reject: "Reject"
      }
    }

    private func shortIdentifier(_ value: String) -> String {
      value.count <= 12 ? value : String(value.prefix(12))
    }

    private static let blockerOptions: [FailureBlocker] = [
      .unknown,
      .sequence,
      .footwork,
      .bodyPosition,
      .bodyTension,
      .dynamicTiming,
      .reachOrLockoff,
      .hookOrCompression,
      .topoutOrFinish,
      .fearOrCommitment,
      .enduranceOrPacing,
    ]
  }

  @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
  @MainActor
  private struct LineWiseExperienceRehearsalDestination: View {
    @ObservedObject var experienceModel: LineWiseExperienceViewModel
    @ObservedObject var editorModel: LineWiseRehearsalViewModel
    let rehearsalID: RouteRehearsalID

    var body: some View {
      VStack(spacing: 0) {
        LineWiseRehearsalEditorView(model: editorModel)
        Divider()
        HStack {
          Label("Edits stay local until saved", systemImage: "externaldrive")
            .font(.caption)
            .foregroundColor(.secondary)
          Spacer()
          if editorModel.qualitativeAnalysis != nil {
            Button("Save suggested reading") {
              experienceModel.saveSetterLensSuggestion(from: rehearsalID)
            }
            .buttonStyle(.bordered)
          }
          Button("Save rehearsal") {
            experienceModel.saveRehearsalEdits(rehearsalID)
          }
          .buttonStyle(.borderedProminent)
        }
        .padding()
      }
    }
  }

  #if os(iOS)
    @available(iOS 15.0, *)
    @MainActor
    public struct LineWisePhoneExperienceHostView: View {
      @ObservedObject private var experienceModel: LineWiseExperienceViewModel
      @ObservedObject private var syncModel: LineWiseAppViewModel
      private let routeMediaLibrary: FoundationRouteMediaLibrary?
      private let routeMediaReadProvider: (any RouteMediaReadProviding)?

      public init(
        experienceModel: LineWiseExperienceViewModel,
        syncModel: LineWiseAppViewModel,
        routeMediaLibrary: FoundationRouteMediaLibrary? = nil,
        routeMediaReadProvider: (any RouteMediaReadProviding)? = nil
      ) {
        _experienceModel = ObservedObject(wrappedValue: experienceModel)
        _syncModel = ObservedObject(wrappedValue: syncModel)
        self.routeMediaLibrary = routeMediaLibrary
        self.routeMediaReadProvider = routeMediaReadProvider
      }

      public var body: some View {
        LineWiseExperienceRootView(
          model: experienceModel,
          supportingHealthKitSummary: syncModel.latestHealthKitWorkoutSummary,
          routeMediaLibrary: routeMediaLibrary,
          routeMediaReadProvider: routeMediaReadProvider
        )
        .onAppear {
          syncModel.activate()
          experienceModel.refreshFromPersistence()
        }
        .onChange(of: syncModel.projection) { _ in
          experienceModel.refreshFromPersistence()
        }
        .onChange(of: syncModel.syncStatus) { _ in
          experienceModel.refreshFromPersistence()
        }
      }
    }
  #endif

  private func normalizedOptional(_ value: String?) -> String? {
    value.flatMap { text in
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
  }

  private func captureFailureMessage(_ outcome: LineWiseAppOutcome) -> String {
    switch outcome {
    case .accepted, .duplicate, .selectionChanged:
      "The change was saved."
    case .conflict(let conflict):
      "This change conflicts with another record: \(conflict)."
    case .deferred(let reason):
      "This change is waiting for missing context: \(reason)."
    case .rejected(let reason):
      "This change was rejected: \(reason)."
    case .restRejected(let reason):
      "The rest interval was rejected: \(reason)."
    case .persistenceFailed(let reason):
      "Could not save this change: \(reason)"
    case .locallyRejected(let reason):
      "This action is not available right now: \(reason)."
    }
  }
#endif
