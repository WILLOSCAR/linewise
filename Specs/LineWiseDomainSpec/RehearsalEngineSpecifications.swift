import Foundation
import LineWiseDomain

private enum RehearsalSpecFailure: Error {
  case expected(String)
}

private func rehearsalExpect(
  _ condition: @autoclosure () -> Bool,
  _ message: String
) throws {
  guard condition() else {
    throw RehearsalSpecFailure.expected(message)
  }
}

private func manualSceneAndSolverProduceFourExplicitContacts() throws {
  let scene = rehearsalScene()
  let profile = BodyProfile.generic(id: BodyProfileID("body-generic"))
  let contacts = rehearsalContacts(locked: true)

  let result = Qualitative2DSolver().solve(
    scene: scene,
    bodyProfile: profile,
    torsoPosition: Point2D(x: 1.3, y: 1.7),
    contacts: contacts
  )

  try rehearsalExpect(result.avatar.contacts.count == 4, "all four limbs must be explicit")
  try rehearsalExpect(
    Set(result.avatar.contacts.map(\.limb)) == Set(Limb.allCases),
    "the avatar must contain LH, RH, LF, and RF"
  )
  try rehearsalExpect(
    result.avatar.joints[.leftHand] == Point2D(x: 1.0, y: 2.3),
    "a locked hand must remain exactly on its hold"
  )
}

private func rehearsalScene() -> RouteScene {
  RouteScene(
    id: RouteSceneID("scene-manual"),
    name: "Blue slab",
    size: SceneSize(width: 3, height: 4),
    metersPerSceneUnit: 1,
    holds: [
      Hold(id: HoldID("lh"), center: Point2D(x: 1.0, y: 2.3), radius: 0.12),
      Hold(id: HoldID("rh"), center: Point2D(x: 1.6, y: 2.4), radius: 0.12),
      Hold(id: HoldID("lf"), center: Point2D(x: 1.1, y: 1.1), radius: 0.12),
      Hold(id: HoldID("rf"), center: Point2D(x: 1.5, y: 1.0), radius: 0.12),
      Hold(id: HoldID("next"), center: Point2D(x: 2.0, y: 2.8), radius: 0.12),
    ]
  )
}

private func rehearsalContacts(locked: Bool = false) -> [LimbContact] {
  Limb.allCases.map { limb in
    LimbContact(
      limb: limb,
      target: .hold(HoldID(limb.rawValue)),
      isLocked: locked
    )
  }
}

private func rehearsalFrame(
  id: String,
  contacts: [LimbContact]? = nil,
  provenance: RehearsalProvenance = .manual
) -> PoseKeyframe {
  PoseKeyframe(
    id: PoseKeyframeID(id),
    label: id,
    torsoPosition: Point2D(x: 1.3, y: 1.7),
    contacts: contacts ?? rehearsalContacts(),
    provenance: provenance
  )
}

private func replacingContact(
  _ contacts: [LimbContact],
  limb: Limb,
  target: ContactTarget
) -> [LimbContact] {
  contacts.map { contact in
    guard contact.limb == limb else { return contact }
    return LimbContact(
      limb: limb,
      target: target,
      mode: contact.mode,
      isLocked: contact.isLocked
    )
  }
}

private func lockedContactsCannotMoveAndAnEditMarksOnlyDownstreamFramesStale() throws {
  var lockedEngine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("locked"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [rehearsalFrame(id: "k1", contacts: rehearsalContacts(locked: true))]
  )
  let before = lockedEngine.rehearsal
  do {
    try lockedEngine.setContact(
      limb: .leftHand,
      target: .hold(HoldID("next")),
      in: PoseKeyframeID("k1")
    )
    throw RehearsalSpecFailure.expected("a locked contact change should fail")
  } catch let error as RouteRehearsalError {
    try rehearsalExpect(
      error == .lockedContact(.leftHand, PoseKeyframeID("k1")),
      "the failure should identify the locked limb and keyframe"
    )
  }
  try rehearsalExpect(lockedEngine.rehearsal == before, "a rejected edit must be atomic")

  var engine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("stale"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [rehearsalFrame(id: "k1"), rehearsalFrame(id: "k2")]
  )
  try engine.setContact(
    limb: .leftHand,
    target: .hold(HoldID("next")),
    in: PoseKeyframeID("k1")
  )
  let frames = engine.rehearsal.timeline(for: .plan).keyframes
  try rehearsalExpect(
    frames[0].contact(for: .leftHand)?.target == .hold(HoldID("next")),
    "the selected limb should move"
  )
  try rehearsalExpect(frames[0].validity == .current, "the edited frame should be recomputed")
  try rehearsalExpect(frames[1].validity.isStale, "only downstream poses should become stale")
}

private func keyframesCanBeAddedDuplicatedDeletedReorderedAndRecomputed() throws {
  var engine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("timeline-editing"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [
      rehearsalFrame(id: "k1"),
      rehearsalFrame(id: "k2"),
      rehearsalFrame(id: "k3"),
    ]
  )

  try engine.duplicateKeyframe(
    PoseKeyframeID("k1"),
    as: PoseKeyframeID("k1-copy"),
    label: "copy"
  )
  var frames = engine.rehearsal.plan.keyframes
  try rehearsalExpect(
    frames.map(\.id) == [
      PoseKeyframeID("k1"), PoseKeyframeID("k1-copy"), PoseKeyframeID("k2"),
      PoseKeyframeID("k3"),
    ],
    "duplicate should be inserted directly after its source"
  )
  try rehearsalExpect(frames[1].validity == .current, "the duplicate should be immediately usable")
  try rehearsalExpect(
    frames[2...].allSatisfy(\.validity.isStale),
    "existing downstream frames should become stale after insertion"
  )

  try engine.deleteKeyframe(PoseKeyframeID("k1-copy"))
  frames = engine.rehearsal.plan.keyframes
  try rehearsalExpect(
    frames.map(\.id) == [PoseKeyframeID("k1"), PoseKeyframeID("k2"), PoseKeyframeID("k3")],
    "delete should remove only the named keyframe"
  )

  try engine.addKeyframe(rehearsalFrame(id: "k4"), after: PoseKeyframeID("k1"))
  try engine.moveKeyframe(PoseKeyframeID("k3"), to: 1)
  frames = engine.rehearsal.plan.keyframes
  try rehearsalExpect(
    frames.map(\.id) == [
      PoseKeyframeID("k1"), PoseKeyframeID("k3"), PoseKeyframeID("k4"), PoseKeyframeID("k2"),
    ],
    "move should use the requested final index"
  )
  try rehearsalExpect(
    frames.dropFirst().allSatisfy(\.validity.isStale),
    "reordering should invalidate the affected downstream sequence"
  )

  try engine.recomputeDownstream(after: PoseKeyframeID("k1"))
  frames = engine.rehearsal.plan.keyframes
  try rehearsalExpect(
    frames.allSatisfy { $0.validity == .current },
    "explicit downstream recompute should clear stale state"
  )
  try rehearsalExpect(
    engine.rehearsal.plan.steps.count == frames.count - 1,
    "each adjacent keyframe pair should have one MovementStep"
  )
}

private func planAndActualRemainIndependentAndStepsExposeContactDiffs() throws {
  let planSecondContacts = replacingContact(
    rehearsalContacts(),
    limb: .rightHand,
    target: .hold(HoldID("next"))
  )
  let observed = RehearsalProvenance(
    authorship: .observed,
    automation: .manual,
    providerIdentifier: "user-video-review",
    version: "1"
  )
  var engine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("plan-actual"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [
      rehearsalFrame(id: "p1"),
      rehearsalFrame(id: "p2", contacts: planSecondContacts),
    ],
    actualKeyframes: [rehearsalFrame(id: "a1", provenance: observed)]
  )

  let step = try { () throws -> MovementStep in
    guard let step = engine.rehearsal.plan.steps.first else {
      throw RehearsalSpecFailure.expected("the plan should expose a MovementStep")
    }
    return step
  }()
  try rehearsalExpect(
    step.changes == [
      ContactChange(
        limb: .rightHand,
        from: .hold(HoldID("rh")),
        to: .hold(HoldID("next"))
      )
    ],
    "MovementStep should identify the exact limb and contact diff"
  )
  try rehearsalExpect(
    Set(step.retainedLimbs) == Set([.leftHand, .leftFoot, .rightFoot]),
    "MovementStep should expose retained contacts"
  )

  let planBeforeActualEdit = engine.rehearsal.plan
  engine.selectTrack(.actual)
  try engine.setContact(
    limb: .leftHand,
    target: .hold(HoldID("next")),
    in: PoseKeyframeID("a1")
  )
  try rehearsalExpect(engine.rehearsal.activeTrack == .actual, "Actual should be selectable")
  try rehearsalExpect(
    engine.rehearsal.plan == planBeforeActualEdit,
    "editing Actual must not rewrite the planned rehearsal"
  )
  try rehearsalExpect(
    engine.rehearsal.actual.keyframes[0].provenance.authorship == .observed,
    "Actual should retain observed provenance"
  )
}

private func playbackSupportsStepScrubLoopAndContinuousCompletion() throws {
  let secondContacts = replacingContact(
    rehearsalContacts(),
    limb: .rightHand,
    target: .hold(HoldID("next"))
  )
  let thirdContacts = replacingContact(
    secondContacts,
    limb: .leftHand,
    target: .hold(HoldID("rh"))
  )
  var engine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("playback"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [
      rehearsalFrame(id: "k1"),
      rehearsalFrame(id: "k2", contacts: secondContacts),
      rehearsalFrame(id: "k3", contacts: thirdContacts),
    ]
  )

  try engine.stepForward()
  try rehearsalExpect(
    engine.currentKeyframeID == PoseKeyframeID("k2"),
    "single-step forward should select the next keyframe"
  )
  try engine.stepBackward()
  try rehearsalExpect(
    engine.currentKeyframeID == PoseKeyframeID("k1"),
    "single-step backward should select the previous keyframe"
  )

  try engine.scrub(transitionIndex: 0, progress: 0.5)
  let interpolated = try engine.currentAvatar()
  try rehearsalExpect(
    interpolated.joints[.leftHand] == Point2D(x: 1.0, y: 2.3),
    "a retained contact must remain visually attached while scrubbing"
  )

  try engine.playCurrentStep(loop: true)
  try engine.advancePlayback(by: 1.2)
  try rehearsalExpect(engine.playback.isPlaying, "loop playback should keep playing")
  try rehearsalExpect(
    abs(engine.playback.cursor.progress - 0.7) < 0.000_1,
    "loop playback should wrap elapsed time within the transition"
  )

  try engine.scrub(transitionIndex: 0, progress: 0)
  try engine.playAll(loop: false)
  try engine.advancePlayback(by: 3)
  try rehearsalExpect(!engine.playback.isPlaying, "continuous playback should stop at the end")
  try rehearsalExpect(
    engine.currentKeyframeID == PoseKeyframeID("k3"),
    "continuous playback should land on the final keyframe"
  )
  try rehearsalExpect(
    engine.playback.cursor.transitionIndex == 1 && engine.playback.cursor.progress == 1,
    "the final cursor should represent the final timeline frame exactly"
  )
}

private func solverFindingsAreDeterministicQualitativeAndNotSafetyClaims() throws {
  let scene = RouteScene(
    id: RouteSceneID("unknown-scale"),
    name: "Unknown scale",
    size: SceneSize(width: 3, height: 4),
    metersPerSceneUnit: nil,
    holds: [Hold(id: HoldID("far"), center: Point2D(x: 12, y: 12), radius: 0.1)]
  )
  let contacts = [
    LimbContact(limb: .leftHand, target: .hold(HoldID("far")), isLocked: true),
    LimbContact(limb: .rightHand, target: .free),
    LimbContact(limb: .leftFoot, target: .ground(Point2D(x: 1, y: 0)), isLocked: true),
    LimbContact(limb: .rightFoot, target: .ground(Point2D(x: 1.5, y: 0)), isLocked: true),
  ]
  let solver = Qualitative2DSolver()
  let first = solver.solve(
    scene: scene,
    bodyProfile: .generic(id: BodyProfileID("body")),
    torsoPosition: Point2D(x: 1.3, y: 1.7),
    contacts: contacts
  )
  let second = solver.solve(
    scene: scene,
    bodyProfile: .generic(id: BodyProfileID("body")),
    torsoPosition: Point2D(x: 1.3, y: 1.7),
    contacts: contacts
  )

  try rehearsalExpect(first == second, "the same qualitative solve must be deterministic")
  try rehearsalExpect(
    first.findings.contains { $0.kind == .scaleUncertainty },
    "unknown scale should remain visible"
  )
  try rehearsalExpect(
    first.findings.contains { $0.kind == .reachLimit && $0.limb == .leftHand },
    "an extreme target should produce a qualitative reach finding"
  )
  try rehearsalExpect(
    first.findings.allSatisfy { !$0.isSafetyJudgment },
    "ConstraintFinding must never present itself as a safety judgment"
  )
}

private func manualAndDeterministicProvidersPreserveHonestProvenance() throws {
  let request = RouteReadRequest(
    sceneID: RouteSceneID("provider-scene"),
    name: "Provider scene",
    size: SceneSize(width: 3, height: 4),
    metersPerSceneUnit: 1,
    candidateHolds: Array(rehearsalScene().holds.reversed())
  )
  let manualRouteRead = try ManualRouteReadProvider().readLocally(request)
  let deterministicRouteProvider = DeterministicLocalRouteReadProvider(algorithmVersion: "x0")
  let deterministicRouteRead = try deterministicRouteProvider.readLocally(request)
  let repeatedRouteRead = try deterministicRouteProvider.readLocally(request)

  try rehearsalExpect(
    manualRouteRead.scene.holds == Array(request.candidateHolds),
    "manual route reading should preserve user-authored hold order"
  )
  try rehearsalExpect(
    !manualRouteRead.provenance.isSuggested,
    "manual input must not be relabeled as a suggestion"
  )
  try rehearsalExpect(
    deterministicRouteRead == repeatedRouteRead,
    "deterministic local route reading should be replayable"
  )
  try rehearsalExpect(
    deterministicRouteRead.provenance.isSuggested
      && deterministicRouteRead.provenance.automation == .deterministicLocal
      && !deterministicRouteRead.provenance.isAIGenerated,
    "local heuristics must say Suggested without pretending to be AI"
  )

  let suggestionRequest = RehearsalSuggestionRequest(
    rehearsalID: RouteRehearsalID("provider-rehearsal"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    seedKeyframes: [rehearsalFrame(id: "seed")],
    maximumKeyframeCount: 3
  )
  let manualSuggestion = try ManualRehearsalSuggestionProvider().suggestLocally(
    suggestionRequest
  )
  let deterministicProvider = DeterministicLocalRehearsalSuggestionProvider(
    algorithmVersion: "x0"
  )
  let suggestion = try deterministicProvider.suggestLocally(suggestionRequest)
  let repeatedSuggestion = try deterministicProvider.suggestLocally(suggestionRequest)

  try rehearsalExpect(
    !manualSuggestion.provenance.isSuggested,
    "the manual rehearsal provider should remain user-authored"
  )
  try rehearsalExpect(suggestion == repeatedSuggestion, "local suggestions must be deterministic")
  try rehearsalExpect(
    suggestion.provenance.isSuggested && !suggestion.provenance.isAIGenerated,
    "rehearsal heuristics must remain explicitly suggested and non-AI"
  )
  try rehearsalExpect(
    suggestion.keyframes.count == 3
      && suggestion.keyframes.allSatisfy { $0.contacts.count == 4 },
    "the suggestion should provide the requested editable four-contact timeline"
  )

  let routeProtocolValue: any RouteReadProvider = deterministicRouteProvider
  let rehearsalProtocolValue: any RehearsalSuggestionProvider = deterministicProvider
  try rehearsalExpect(
    routeProtocolValue.identifier == "deterministic-local-route-read"
      && rehearsalProtocolValue.identifier == "deterministic-local-rehearsal",
    "provider protocols should expose stable adapter identifiers"
  )
}

private func actualCanStartLaterAndARehearsalCanBeSavedAndReopened() throws {
  var engine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("reopen"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [rehearsalFrame(id: "p1"), rehearsalFrame(id: "p2")]
  )
  let planBeforeActual = engine.rehearsal.plan
  let observed = RehearsalProvenance(
    authorship: .observed,
    automation: .manual,
    providerIdentifier: "actual-entry",
    version: "1"
  )
  try engine.replaceTimeline(
    for: .actual,
    with: [
      rehearsalFrame(id: "a1", provenance: observed),
      rehearsalFrame(id: "a2", provenance: observed),
    ]
  )

  try rehearsalExpect(
    engine.rehearsal.plan == planBeforeActual, "starting Actual must preserve Plan")
  try rehearsalExpect(
    engine.rehearsal.actual.keyframes.count == 2 && engine.rehearsal.actual.steps.count == 1,
    "Actual should be startable after the planned timeline exists"
  )

  let encoded = try JSONEncoder().encode(engine.rehearsal)
  let decoded = try JSONDecoder().decode(RouteRehearsal.self, from: encoded)
  let reopened = try RouteRehearsalEngine(reopening: decoded)
  try rehearsalExpect(
    reopened.rehearsal == engine.rehearsal,
    "the complete manual Plan/Actual rehearsal should survive save and reopen"
  )
}

private func movementIntentSurvivesUnrelatedEditsAndNeedsReviewAfterContactChange() throws {
  let secondContacts = replacingContact(
    rehearsalContacts(),
    limb: .rightHand,
    target: .hold(HoldID("next"))
  )
  var engine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("movement-intent"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [
      rehearsalFrame(id: "k1"),
      rehearsalFrame(id: "k2", contacts: secondContacts),
      rehearsalFrame(id: "k3", contacts: secondContacts),
    ]
  )
  let intent = MovementIntent(
    purpose: .progress,
    family: .staticMove,
    expectedDurationSeconds: 1.6,
    cue: "Keep the right foot loaded, then bring the hips up.",
    uncertainty: "Wall angle is still estimated.",
    provenance: .manual
  )

  try engine.setMovementIntent(
    intent,
    from: PoseKeyframeID("k1"),
    to: PoseKeyframeID("k2")
  )
  var firstStep = try rehearsalRequired(
    engine.rehearsal.plan.steps.first,
    "annotated first movement step"
  )
  try rehearsalExpect(firstStep.intent == intent, "the named step should retain its intent")
  try rehearsalExpect(
    firstStep.effectiveDurationSeconds == 1.6,
    "playback should use the user-authored rhythm"
  )

  try engine.setContact(
    limb: .leftHand,
    target: .hold(HoldID("next")),
    in: PoseKeyframeID("k3")
  )
  firstStep = try rehearsalRequired(
    engine.rehearsal.plan.steps.first,
    "first movement step after unrelated edit"
  )
  try rehearsalExpect(
    firstStep.intent?.validity == .current,
    "an unrelated later edit must not invalidate this movement intent"
  )

  try engine.setContact(
    limb: .leftFoot,
    target: .free,
    in: PoseKeyframeID("k2")
  )
  firstStep = try rehearsalRequired(
    engine.rehearsal.plan.steps.first,
    "first movement step after related edit"
  )
  try rehearsalExpect(
    firstStep.intent?.validity == .needsReview,
    "a changed contact in the step must make its old intent visibly stale"
  )
  try rehearsalExpect(
    firstStep.intent?.cue == intent.cue,
    "stale guidance should remain available for explicit review instead of disappearing"
  )

  try engine.setMovementIntent(
    intent,
    from: PoseKeyframeID("k1"),
    to: PoseKeyframeID("k2")
  )
  let revisedScene = RouteScene(
    id: rehearsalScene().id,
    name: "Blue slab · corrected geometry",
    size: rehearsalScene().size,
    metersPerSceneUnit: rehearsalScene().metersPerSceneUnit,
    holds: rehearsalScene().holds.map { hold in
      guard hold.id == HoldID("next") else { return hold }
      return Hold(
        id: hold.id,
        center: Point2D(x: hold.center.x + 0.2, y: hold.center.y),
        radius: hold.radius,
        kind: hold.kind,
        routeRole: hold.routeRole
      )
    }
  )
  engine.replaceScene(revisedScene)
  firstStep = try rehearsalRequired(
    engine.rehearsal.plan.steps.first,
    "first movement step after scene correction"
  )
  try rehearsalExpect(
    firstStep.intent?.validity == .needsReview && firstStep.intent?.cue == intent.cue,
    "a scene correction should preserve the movement idea but require explicit review"
  )

  let reopened = try JSONDecoder().decode(
    RouteRehearsal.self,
    from: JSONEncoder().encode(engine.rehearsal)
  )
  try rehearsalExpect(
    reopened.plan.steps.first?.intent == firstStep.intent,
    "movement intent and review state should survive save and reopen"
  )
}

private func practiceSegmentPlaybackStopsAndLoopsInsideOneToThreeSteps() throws {
  let secondContacts = replacingContact(
    rehearsalContacts(),
    limb: .rightHand,
    target: .hold(HoldID("next"))
  )
  let thirdContacts = replacingContact(
    secondContacts,
    limb: .leftHand,
    target: .hold(HoldID("rh"))
  )
  let fourthContacts = replacingContact(
    thirdContacts,
    limb: .leftFoot,
    target: .free
  )
  var engine = try RouteRehearsalEngine(
    rehearsalID: RouteRehearsalID("practice-segment"),
    scene: rehearsalScene(),
    bodyProfile: .generic(id: BodyProfileID("body")),
    planKeyframes: [
      rehearsalFrame(id: "k1"),
      rehearsalFrame(id: "k2", contacts: secondContacts),
      rehearsalFrame(id: "k3", contacts: thirdContacts),
      rehearsalFrame(id: "k4", contacts: fourthContacts),
    ]
  )

  try engine.playSegment(1...2, loop: false)
  try engine.advancePlayback(by: 2.5)
  try rehearsalExpect(!engine.playback.isPlaying, "a finite practice segment should stop")
  try rehearsalExpect(
    engine.playback.cursor.transitionIndex == 2 && engine.playback.cursor.progress == 1,
    "practice playback should stop on the exact selected segment end"
  )

  try engine.playSegment(1...2, loop: true)
  try engine.advancePlayback(by: 2.25)
  try rehearsalExpect(engine.playback.isPlaying, "a looped practice segment should keep playing")
  try rehearsalExpect(
    engine.playback.cursor.transitionIndex == 1 && engine.playback.cursor.progress == 0.25,
    "looping should wrap to the selected segment start, not the full timeline start"
  )

  do {
    try engine.playSegment(0...3, loop: false)
    throw RehearsalSpecFailure.expected(
      "a StickFigureCue practice segment must stay within 1-3 steps")
  } catch let error as RouteRehearsalError {
    try rehearsalExpect(
      error == .practiceSegmentStepCountOutOfRange,
      "the 1-3 step product bound should be explicit"
    )
  }
}

private func rehearsalRequired<Value>(_ value: Value?, _ label: String) throws -> Value {
  guard let value else {
    throw RehearsalSpecFailure.expected("missing \(label)")
  }
  return value
}

public func rehearsalEngineSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "manual scene and solver produce four explicit contacts",
      manualSceneAndSolverProduceFourExplicitContacts
    ),
    (
      "locked contacts cannot move and an edit marks only downstream frames stale",
      lockedContactsCannotMoveAndAnEditMarksOnlyDownstreamFramesStale
    ),
    (
      "keyframes can be added duplicated deleted reordered and recomputed",
      keyframesCanBeAddedDuplicatedDeletedReorderedAndRecomputed
    ),
    (
      "plan and actual remain independent and steps expose contact diffs",
      planAndActualRemainIndependentAndStepsExposeContactDiffs
    ),
    (
      "playback supports step scrub loop and continuous completion",
      playbackSupportsStepScrubLoopAndContinuousCompletion
    ),
    (
      "solver findings are deterministic qualitative and not safety claims",
      solverFindingsAreDeterministicQualitativeAndNotSafetyClaims
    ),
    (
      "manual and deterministic providers preserve honest provenance",
      manualAndDeterministicProvidersPreserveHonestProvenance
    ),
    (
      "actual can start later and a rehearsal can be saved and reopened",
      actualCanStartLaterAndARehearsalCanBeSavedAndReopened
    ),
    (
      "movement intent survives unrelated edits and needs review after contact change",
      movementIntentSurvivesUnrelatedEditsAndNeedsReviewAfterContactChange
    ),
    (
      "practice segment playback stops and loops inside one to three steps",
      practiceSegmentPlaybackStopsAndLoopsInsideOneToThreeSteps
    ),
  ]
}
