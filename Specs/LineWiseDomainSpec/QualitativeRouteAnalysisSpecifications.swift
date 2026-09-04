import LineWiseDomain

private enum QualitativeRouteAnalysisSpecFailure: Error {
  case expected(String)
}

private func qualitativeExpect(
  _ condition: @autoclosure () -> Bool,
  _ message: String
) throws {
  guard condition() else {
    throw QualitativeRouteAnalysisSpecFailure.expected(message)
  }
}

private func qualitativeEmptyVisitSnapshot() -> VisitSnapshot {
  VisitSnapshot(
    visits: [],
    attempts: [],
    routeCards: [],
    projects: [],
    pendingActionIDs: [],
    reconciliationIssues: []
  )
}

private func qualitativeScene(id: String = "scene-lens") -> RouteScene {
  RouteScene(
    id: RouteSceneID(id),
    name: "Blue slab",
    size: SceneSize(width: 10, height: 18),
    metersPerSceneUnit: nil,
    holds: [
      Hold(
        id: HoldID("left-foot"),
        center: Point2D(x: 3, y: 4),
        radius: 0.25,
        routeRole: .start
      ),
      Hold(
        id: HoldID("right-hand"),
        center: Point2D(x: 6, y: 10),
        radius: 0.3
      ),
    ]
  )
}

private func confirmedFailure(
  routeCardID: RouteCardID = RouteCardID("route-lens")
) -> FailureEpisodeSnapshot {
  FailureEpisodeSnapshot(
    id: FailureEpisodeID("failure-lens"),
    attemptID: AttemptID("attempt-lens"),
    routeCardID: routeCardID,
    primaryBlocker: .bodyPosition,
    locationNote: "third move",
    status: .userConfirmed,
    suggestionProvenance: nil,
    createdAt: Instant(millisecondsSince1970: 1_000),
    updatedAt: Instant(millisecondsSince1970: 2_000)
  )
}

private func deterministicAnalysisIsPinnedSuggestedAndRepeatable() throws {
  let request = QualitativeRouteAnalysisRequest(
    routeCardID: RouteCardID("route-lens"),
    routeScene: qualitativeScene(),
    routeSceneVersion: "scene-v4",
    bodyProfile: .generic(id: BodyProfileID("body-lens")),
    bodyProfileVersion: "body-v2",
    rehearsalComparison: nil,
    stickFigureCue: nil,
    confirmedFailureEpisodes: [confirmedFailure()],
    confirmedMoveCues: []
  )
  let provider = DeterministicLocalQualitativeRouteAnalysisProvider(
    algorithmVersion: "taxonomy-v1"
  )

  let first = try provider.analyzeLocally(request)
  let second = try provider.analyzeLocally(request)

  try qualitativeExpect(first == second, "the same pinned evidence must be deterministic")
  try qualitativeExpect(
    first.provenance.authorship == .suggested
      && first.provenance.evidenceTreatment == .inferred
      && first.provenance.automation == .deterministicLocal,
    "local qualitative analysis must remain an inferred suggestion"
  )
  try qualitativeExpect(
    first.provenance.providerIdentifier == provider.identifier
      && first.provenance.version == "taxonomy-v1",
    "the exact local algorithm must remain visible"
  )
  try qualitativeExpect(
    first.candidateMovementFamily == .balanceAndWeightShift
      && first.candidateConstraint == .requiredCenterOfMassShift,
    "a user-confirmed body-position blocker should map into the bounded taxonomy"
  )
  try qualitativeExpect(
    Set(first.evidenceReferences.map(\.kind)) == [.routeScene, .failureEpisode],
    "the analysis must cite only the pinned evidence that supported it"
  )
  try qualitativeExpect(
    first.evidenceReferences.contains {
      $0.kind == .routeScene && $0.version == "scene-v4"
    },
    "the exact scene version must remain pinned"
  )
}

private func emptyEvidenceIsRejected() throws {
  let request = QualitativeRouteAnalysisRequest(
    routeCardID: RouteCardID("route-empty"),
    routeScene: RouteScene(
      id: RouteSceneID("scene-empty"),
      name: "Empty scene",
      size: SceneSize(width: 10, height: 18),
      metersPerSceneUnit: nil,
      holds: []
    ),
    routeSceneVersion: "scene-v1",
    bodyProfile: .generic(id: BodyProfileID("body-empty")),
    bodyProfileVersion: "body-v1",
    rehearsalComparison: nil,
    stickFigureCue: nil,
    confirmedFailureEpisodes: [],
    confirmedMoveCues: []
  )

  do {
    _ = try DeterministicLocalQualitativeRouteAnalysisProvider().analyzeLocally(request)
    throw QualitativeRouteAnalysisSpecFailure.expected("empty evidence should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    try qualitativeExpect(error == .emptyEvidence, "empty evidence should be explicit")
  }
}

private func unconfirmedFailureEvidenceIsRejected() throws {
  let suggestedFailure = FailureEpisodeSnapshot(
    id: FailureEpisodeID("failure-suggested"),
    attemptID: AttemptID("attempt-suggested"),
    routeCardID: RouteCardID("route-lens"),
    primaryBlocker: .footwork,
    locationNote: nil,
    status: .suggested,
    suggestionProvenance: SuggestionProvenance(
      suggestionID: "model-failure",
      source: .model,
      sourceReference: "route-read",
      sourceVersion: "1",
      confidence: 0.4,
      decision: .pending
    ),
    createdAt: Instant(millisecondsSince1970: 1_000),
    updatedAt: Instant(millisecondsSince1970: 2_000)
  )
  let request = QualitativeRouteAnalysisRequest(
    routeCardID: RouteCardID("route-lens"),
    routeScene: qualitativeScene(),
    routeSceneVersion: "scene-v4",
    bodyProfile: .generic(id: BodyProfileID("body-lens")),
    bodyProfileVersion: "body-v2",
    rehearsalComparison: nil,
    stickFigureCue: nil,
    confirmedFailureEpisodes: [suggestedFailure],
    confirmedMoveCues: []
  )

  do {
    _ = try DeterministicLocalQualitativeRouteAnalysisProvider().analyzeLocally(request)
    throw QualitativeRouteAnalysisSpecFailure.expected("unconfirmed failure should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    try qualitativeExpect(
      error == .failureEpisodeIsNotUserConfirmed(suggestedFailure.id),
      "suggested evidence must never be treated as user-confirmed"
    )
  }
}

private func comparisonMustMatchPinnedSceneAndBody() throws {
  let requestScene = qualitativeScene()
  let body = BodyProfile.generic(id: BodyProfileID("body-lens"))
  let mismatchedComparison = RehearsalComparison(
    rehearsalID: RouteRehearsalID("rehearsal-mismatch"),
    sceneSnapshot: qualitativeScene(id: "other-scene"),
    bodyProfileSnapshot: body,
    planSnapshot: RehearsalTimeline(keyframes: []),
    actualSnapshot: RehearsalTimeline(keyframes: []),
    planTimelineVersion: "plan-v1",
    actualTimelineVersion: "actual-v1",
    alignedSteps: []
  )
  let request = QualitativeRouteAnalysisRequest(
    routeCardID: RouteCardID("route-lens"),
    routeScene: requestScene,
    routeSceneVersion: "scene-v4",
    bodyProfile: body,
    bodyProfileVersion: "body-v2",
    rehearsalComparison: mismatchedComparison,
    stickFigureCue: nil,
    confirmedFailureEpisodes: [confirmedFailure()],
    confirmedMoveCues: []
  )

  do {
    _ = try DeterministicLocalQualitativeRouteAnalysisProvider().analyzeLocally(request)
    throw QualitativeRouteAnalysisSpecFailure.expected("mismatched pin should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    try qualitativeExpect(error == .pinnedSceneMismatch, "scene mismatch should be explicit")
  }
}

private func resultContractRejectsUnboundedOrUnpinnedClaims() throws {
  let request = QualitativeRouteAnalysisRequest(
    routeCardID: RouteCardID("route-lens"),
    routeScene: qualitativeScene(),
    routeSceneVersion: "scene-v4",
    bodyProfile: .generic(id: BodyProfileID("body-lens")),
    bodyProfileVersion: "body-v2",
    rehearsalComparison: nil,
    stickFigureCue: nil,
    confirmedFailureEpisodes: [confirmedFailure()],
    confirmedMoveCues: []
  )
  let base = try DeterministicLocalQualitativeRouteAnalysisProvider().analyzeLocally(request)
  let excessiveConfidence = QualitativeRouteAnalysisResult(
    observations: base.observations,
    candidateMovementFamily: base.candidateMovementFamily,
    candidateConstraint: base.candidateConstraint,
    candidateCrux: base.candidateCrux,
    alternative: base.alternative,
    uncertainties: base.uncertainties,
    evidenceReferences: base.evidenceReferences,
    confidence: 1.01,
    provenance: base.provenance
  )
  do {
    try QualitativeRouteAnalysisContract.validate(excessiveConfidence, for: request)
    throw QualitativeRouteAnalysisSpecFailure.expected("out-of-range confidence should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    try qualitativeExpect(error == .confidenceOutOfRange, "confidence bounds should be explicit")
  }

  let forgedReference = QualitativeEvidenceReference(
    id: "not-in-request",
    kind: .rehearsalComparison,
    version: "invented-v1"
  )
  let forgedEvidence = QualitativeRouteAnalysisResult(
    observations: [
      QualitativeObservation(text: "A contact differs.", evidenceReferences: [forgedReference])
    ],
    candidateMovementFamily: base.candidateMovementFamily,
    candidateConstraint: base.candidateConstraint,
    candidateCrux: nil,
    alternative: QualitativeAlternative(
      movementFamily: .unknownOrMixed,
      constraint: .unresolved,
      explanation: "Another explanation remains possible.",
      evidenceReferences: [forgedReference]
    ),
    uncertainties: [],
    evidenceReferences: [forgedReference],
    confidence: 0.2,
    provenance: base.provenance
  )
  do {
    try QualitativeRouteAnalysisContract.validate(forgedEvidence, for: request)
    throw QualitativeRouteAnalysisSpecFailure.expected("forged evidence should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    try qualitativeExpect(
      error == .evidenceReferenceIsNotPinned(forgedReference),
      "a provider cannot cite evidence outside the request"
    )
  }

  let overclaim = QualitativeRouteAnalysisResult(
    observations: [
      QualitativeObservation(
        text: "This is the official setter intent and is physically safe.",
        evidenceReferences: [base.evidenceReferences[0]]
      )
    ],
    candidateMovementFamily: base.candidateMovementFamily,
    candidateConstraint: base.candidateConstraint,
    candidateCrux: nil,
    alternative: base.alternative,
    uncertainties: base.uncertainties,
    evidenceReferences: base.evidenceReferences,
    confidence: 0.4,
    provenance: base.provenance
  )
  do {
    try QualitativeRouteAnalysisContract.validate(overclaim, for: request)
    throw QualitativeRouteAnalysisSpecFailure.expected("prohibited claim should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    guard case .prohibitedClaim = error else {
      throw QualitativeRouteAnalysisSpecFailure.expected(
        "official intent and safety claims must be rejected"
      )
    }
  }

  let undeclaredReference = base.evidenceReferences.first { $0.kind == .routeScene }!
  let declaredReference = base.evidenceReferences.first { $0.kind == .failureEpisode }!
  let undeclaredUsage = QualitativeRouteAnalysisResult(
    observations: [
      QualitativeObservation(
        text: "The pinned scene contains route contacts.",
        evidenceReferences: [undeclaredReference]
      )
    ],
    candidateMovementFamily: base.candidateMovementFamily,
    candidateConstraint: base.candidateConstraint,
    candidateCrux: nil,
    alternative: QualitativeAlternative(
      movementFamily: .unknownOrMixed,
      constraint: .unresolved,
      explanation: "Another explanation remains possible.",
      evidenceReferences: [declaredReference]
    ),
    uncertainties: [],
    evidenceReferences: [declaredReference],
    confidence: 0.3,
    provenance: base.provenance
  )
  do {
    try QualitativeRouteAnalysisContract.validate(undeclaredUsage, for: request)
    throw QualitativeRouteAnalysisSpecFailure.expected("undeclared evidence should fail")
  } catch let error as QualitativeRouteAnalysisContractError {
    try qualitativeExpect(
      error == .evidenceReferenceIsNotDeclared(undeclaredReference),
      "field-level citations must appear in the result evidence manifest"
    )
  }
}

private func qualitativeComparison(
  scene: RouteScene,
  body: BodyProfile
) -> RehearsalComparison {
  let finding = ConstraintFinding(
    kind: .reachLimit,
    severity: .unresolved,
    limb: .rightHand,
    message: "The qualitative reach model is near its current limit."
  )
  let planFrame = PoseKeyframe(
    id: PoseKeyframeID("plan-frame-lens"),
    label: "Plan crux",
    torsoPosition: Point2D(x: 4, y: 7),
    contacts: Limb.allCases.map(LimbContact.unknown),
    findings: [finding],
    provenance: .manual
  )
  let planEvidence = CompareEvidence(
    kind: .manual,
    certainty: .certain,
    providerIdentifier: "manual",
    version: "1"
  )
  let actualEvidence = CompareEvidence(
    kind: .observed,
    certainty: .certain,
    providerIdentifier: "user-observation",
    version: "2"
  )
  let divergences = Limb.allCases.map { limb in
    LimbContactDivergence(
      limb: limb,
      planTarget: .hold(HoldID(limb == .leftFoot ? "left-foot" : "right-hand")),
      actualTarget: .hold(HoldID(limb == .leftFoot ? "right-hand" : "right-hand")),
      planEvidence: planEvidence,
      actualEvidence: actualEvidence,
      state: limb == .leftFoot ? .different : .same
    )
  }
  let aligned = AlignedMovementStep(
    alignmentIndex: 0,
    planStepIndex: nil,
    actualStepIndex: nil,
    planStep: nil,
    actualStep: nil,
    alignmentState: .aligned,
    planEvidence: planEvidence,
    actualEvidence: actualEvidence,
    limbDivergences: divergences,
    torsoDivergence: TorsoDivergence(
      planPosition: Point2D(x: 4, y: 7),
      actualPosition: Point2D(x: 5, y: 7),
      deltaX: 1,
      deltaY: 0,
      distance: 1,
      planEvidence: planEvidence,
      actualEvidence: actualEvidence,
      state: .different
    ),
    timingDivergence: TimingDivergence(
      planDurationSeconds: 1,
      actualDurationSeconds: 1.6,
      deltaSeconds: 0.6,
      planEvidence: planEvidence,
      actualEvidence: actualEvidence,
      state: .different
    )
  )
  return RehearsalComparison(
    rehearsalID: RouteRehearsalID("rehearsal-lens"),
    sceneSnapshot: scene,
    bodyProfileSnapshot: body,
    planSnapshot: RehearsalTimeline(keyframes: [planFrame]),
    actualSnapshot: RehearsalTimeline(keyframes: []),
    planTimelineVersion: "plan-v8",
    actualTimelineVersion: "actual-v5",
    alignedSteps: [aligned]
  )
}

private func comparisonAndFindingsFeedTheBoundedTaxonomy() throws {
  let scene = qualitativeScene()
  let body = BodyProfile.generic(id: BodyProfileID("body-lens"))
  let request = QualitativeRouteAnalysisRequest(
    routeCardID: RouteCardID("route-lens"),
    routeScene: scene,
    routeSceneVersion: "scene-v4",
    bodyProfile: body,
    bodyProfileVersion: "body-v2",
    rehearsalComparison: qualitativeComparison(scene: scene, body: body),
    stickFigureCue: nil,
    confirmedFailureEpisodes: [],
    confirmedMoveCues: []
  )

  let result = try DeterministicLocalQualitativeRouteAnalysisProvider().analyzeLocally(request)

  try qualitativeExpect(
    result.candidateMovementFamily == .lockOffOrReachManagement
      && result.candidateConstraint == .distanceBetweenUsefulContacts,
    "a qualitative reach finding should map into the finite taxonomy"
  )
  try qualitativeExpect(
    result.observations.contains { $0.text.contains("left foot contact") },
    "a four-limb divergence should remain an evidence-backed observation"
  )
  try qualitativeExpect(
    Set(result.evidenceReferences.map(\.kind)).isSuperset(
      of: [.routeScene, .rehearsalComparison, .constraintFinding]
    ),
    "comparison and the exact finding must remain pinned"
  )
  try qualitativeExpect(
    result.evidenceReferences.contains {
      $0.kind == .rehearsalComparison && $0.version == "plan-v8|actual-v5"
    },
    "both comparison timeline versions must survive"
  )
}

private func setterLensBridgeCannotConfirmForTheUser() throws {
  let request = QualitativeRouteAnalysisRequest(
    routeCardID: RouteCardID("route-lens"),
    routeScene: qualitativeScene(),
    routeSceneVersion: "scene-v4",
    bodyProfile: .generic(id: BodyProfileID("body-lens")),
    bodyProfileVersion: "body-v2",
    rehearsalComparison: nil,
    stickFigureCue: nil,
    confirmedFailureEpisodes: [confirmedFailure()],
    confirmedMoveCues: []
  )
  let result = try DeterministicLocalQualitativeRouteAnalysisProvider(
    algorithmVersion: "taxonomy-v3"
  ).analyzeLocally(request)
  let readingID = SetterLensReadingID("reading-from-analysis")
  let command = try QualitativeSetterLensBridge.suggestSetterLensReading(
    from: result,
    request: request,
    actionID: ActionID("suggest-reading-from-analysis"),
    readingID: readingID,
    occurredAt: Instant(millisecondsSince1970: 4_000)
  )
  var transition = LearningLoop.apply(
    command,
    visitSnapshot: qualitativeEmptyVisitSnapshot(),
    recallSnapshot: RecallTrainingState().snapshot,
    catalog: ApprovedMicroDrillCatalog(drills: []),
    to: LearningLoopState()
  )

  try qualitativeExpect(transition.outcome == .accepted, "the bridge command should be valid")
  try qualitativeExpect(
    transition.state.snapshot.setterLensReadings.first?.status == .suggested
      && transition.state.snapshot.setterLensReadings.first?.suggestionProvenance.decision
        == .pending,
    "the bridge must not confirm its own suggestion"
  )
  try qualitativeExpect(
    transition.state.snapshot.setterLensReadings.first?.evidence.map(\.version)
      == ["2000", "scene-v4"],
    "SetterLens evidence must retain the exact pinned versions"
  )

  transition = LearningLoop.apply(
    .acceptSetterLensReading(
      actionID: ActionID("accept-reading-from-analysis"),
      readingID: readingID,
      interpretationOverride: "User edit: shift weight before the reach.",
      occurredAt: Instant(millisecondsSince1970: 5_000)
    ),
    visitSnapshot: qualitativeEmptyVisitSnapshot(),
    recallSnapshot: RecallTrainingState().snapshot,
    catalog: ApprovedMicroDrillCatalog(drills: []),
    to: transition.state
  )
  try qualitativeExpect(
    transition.state.snapshot.setterLensReadings.first?.status == .userConfirmed
      && transition.state.snapshot.setterLensReadings.first?.suggestionProvenance.decision
        == .edited,
    "only a separate user accept/edit command may confirm the reading"
  )
}

public func qualitativeRouteAnalysisSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "deterministic qualitative analysis is pinned suggested and repeatable",
      deterministicAnalysisIsPinnedSuggestedAndRepeatable
    ),
    ("empty qualitative evidence is rejected", emptyEvidenceIsRejected),
    ("unconfirmed failure evidence is rejected", unconfirmedFailureEvidenceIsRejected),
    (
      "qualitative comparison matches pinned scene and body",
      comparisonMustMatchPinnedSceneAndBody
    ),
    (
      "qualitative result rejects unbounded or unpinned claims",
      resultContractRejectsUnboundedOrUnpinnedClaims
    ),
    (
      "comparison and findings feed the bounded qualitative taxonomy",
      comparisonAndFindingsFeedTheBoundedTaxonomy
    ),
    (
      "SetterLens bridge cannot confirm for the user",
      setterLensBridgeCannotConfirmForTheUser
    ),
  ]
}
