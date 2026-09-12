import Foundation
import LineWiseApplication
import LineWiseDomain

func rehearsalCoordinatorSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "rehearsal coordinator preserves route and timeline provenance",
      rehearsalCoordinatorPreservesProviderProvenance
    ),
    (
      "rehearsal coordinator edits four-limb timeline and recomputes stale poses",
      rehearsalCoordinatorEditsTimelineAndRecomputesStalePoses
    ),
    (
      "rehearsal coordinator supports step scrub continuous and loop playback",
      rehearsalCoordinatorSupportsPlaybackModes
    ),
    (
      "Actual draft requires an Attempt and copied Plan remains user authored",
      actualDraftRequiresAttemptAndRemainsUserAuthored
    ),
    (
      "movement focus annotates loops pins and compares one practice segment",
      movementFocusAnnotatesLoopsPinsAndComparesPracticeSegment
    ),
    (
      "qualitative analysis request pins only this route's confirmed history",
      qualitativeAnalysisRequestPinsOnlyThisRoutesConfirmedHistory
    ),
    (
      "a StickFigureCue pinned before a save still matches its timeline after reopening",
      aPinnedCueStillMatchesItsTimelineAfterReopening
    ),
  ]
}

/// A StickFigureCue is pinned to a timeline version so a later replay can prove
/// it still describes the same movement. Saving and reopening the rehearsal does
/// not change that movement, so the pin must still match.
private func aPinnedCueStillMatchesItsTimelineAfterReopening() throws {
  var coordinator = try makeRehearsalCoordinator()
  let cue = try coordinator.makeCurrentStickFigureCue(
    id: StickFigureCueID("pinned-across-reload"),
    stepCount: 2
  )
  let versionBeforeSave = coordinator.timelineVersion(for: .plan)
  try expect(
    cue.timelineVersion == versionBeforeSave,
    "a freshly cut cue should be pinned to the current timeline version"
  )

  let reloadedRehearsal = try JSONDecoder().decode(
    RouteRehearsal.self,
    from: JSONEncoder().encode(coordinator.engine.rehearsal)
  )
  try expect(
    reloadedRehearsal == coordinator.engine.rehearsal,
    "the saved rehearsal should reload as the same value"
  )
  let reopened = LineWiseRehearsalCoordinator(
    routeCardID: coordinator.routeCardID,
    engine: try RouteRehearsalEngine(reopening: reloadedRehearsal),
    actualAttemptID: coordinator.actualAttemptID
  )

  try expect(
    reopened.timelineVersion(for: .plan) == versionBeforeSave,
    "reopening an unchanged rehearsal must report the same timeline version"
  )

  let comparison = RehearsalCompare.align(
    rehearsal: reopened.engine.rehearsal,
    planTimelineVersion: reopened.timelineVersion(for: .plan),
    actualTimelineVersion: reopened.timelineVersion(for: .actual)
  )
  _ = try RehearsalCompare.makeStickFigureCue(
    id: cue.id,
    comparison: comparison,
    alignedStepRange: 0...1,
    preferredTrack: .plan,
    pin: StickFigureCuePin(
      scene: cue.sceneSnapshot,
      bodyProfile: cue.bodyProfileSnapshot,
      timelineVersion: cue.timelineVersion
    )
  )

  let edited = coordinator.handle(.assignHold(holdID: HoldID("hold-top")))
  try expect(edited.isSuccess, "the spec should be able to make a real timeline edit")
  try expect(
    coordinator.timelineVersion(for: .plan) != versionBeforeSave,
    "a real timeline edit must change the version so an old pin stops matching"
  )
}

private func qualitativeAnalysisRequestPinsOnlyThisRoutesConfirmedHistory() throws {
  let coordinator = try makeRehearsalCoordinator()
  let thisRoute = coordinator.routeCardID
  let otherRoute = RouteCardID("route-card-other")

  let ownFailure = FailureEpisodeSnapshot(
    id: FailureEpisodeID("failure-own"),
    attemptID: AttemptID("attempt-own"),
    routeCardID: thisRoute,
    primaryBlocker: .reachOrLockoff,
    locationNote: "Crux lockoff before the top.",
    status: .userConfirmed,
    suggestionProvenance: nil,
    createdAt: Instant(millisecondsSince1970: 1_000),
    updatedAt: Instant(millisecondsSince1970: 1_000)
  )
  let otherFailure = FailureEpisodeSnapshot(
    id: FailureEpisodeID("failure-other"),
    attemptID: AttemptID("attempt-other"),
    routeCardID: otherRoute,
    primaryBlocker: .footwork,
    locationNote: "Different route entirely.",
    status: .userConfirmed,
    suggestionProvenance: nil,
    createdAt: Instant(millisecondsSince1970: 1_100),
    updatedAt: Instant(millisecondsSince1970: 1_100)
  )
  let ownCue = MoveCueSnapshot(
    id: MoveCueID("cue-own"),
    failureEpisodeID: ownFailure.id,
    routeCardID: thisRoute,
    text: "Keep the left toe pressed while the hips rise.",
    status: .userConfirmed,
    suggestionProvenance: nil,
    createdAt: Instant(millisecondsSince1970: 1_200),
    updatedAt: Instant(millisecondsSince1970: 1_200)
  )
  let otherCue = MoveCueSnapshot(
    id: MoveCueID("cue-other"),
    failureEpisodeID: otherFailure.id,
    routeCardID: otherRoute,
    text: "Match hands on the jug.",
    status: .userConfirmed,
    suggestionProvenance: nil,
    createdAt: Instant(millisecondsSince1970: 1_300),
    updatedAt: Instant(millisecondsSince1970: 1_300)
  )

  let request = coordinator.qualitativeAnalysisRequest(
    confirmedFailureEpisodes: [otherFailure, ownFailure],
    confirmedMoveCues: [otherCue, ownCue],
    stickFigureCue: nil
  )

  try expect(
    request.routeCardID == thisRoute,
    "the request should target the coordinator's own RouteCard"
  )
  try expect(
    request.confirmedFailureEpisodes.map(\.id) == [ownFailure.id],
    "only this route's confirmed FailureEpisode should be pinned"
  )
  try expect(
    request.confirmedMoveCues.map(\.id) == [ownCue.id],
    "only this route's confirmed MoveCue should be pinned"
  )
}

private func movementFocusAnnotatesLoopsPinsAndComparesPracticeSegment() throws {
  var coordinator = try makeRehearsalCoordinator()
  let intent = MovementIntent(
    purpose: .stabilize,
    family: .staticMove,
    expectedDurationSeconds: 1.25,
    cue: "Keep pressure through the left toe while the hips rise.",
    uncertainty: "The wall angle is approximate.",
    provenance: .manual
  )
  let annotated = coordinator.handle(.setCurrentMovementIntent(intent))
  try expect(annotated.isSuccess, "the current movement should accept a user-authored intent")
  try expect(
    annotated.projection.currentMovementStep?.intent == intent,
    "the current step should expose its purpose, rhythm, cue, and uncertainty"
  )

  let cue = try coordinator.makeCurrentStickFigureCue(
    id: StickFigureCueID("focused-cue"),
    stepCount: 2
  )
  try expect(
    cue.track == .plan && cue.steps.count == 2 && cue.keyframes.count == 3,
    "the focused StickFigureCue should pin two continuous Plan steps"
  )
  try expect(
    cue.steps.first?.intent == intent,
    "the pinned cue should preserve the user-authored MovementIntent"
  )

  let playing = coordinator.handle(.playPracticeSegment(stepCount: 2, loop: true))
  try expect(playing.isSuccess && playing.projection.isLooping, "focused playback should loop")
  let advanced = coordinator.handle(.tick(elapsedSeconds: 2.5))
  try expect(
    advanced.projection.playback.cursor.transitionIndex == 0
      && advanced.projection.playback.cursor.progress == 0.2,
    "focused playback should wrap inside the two-step segment using its authored rhythm"
  )

  let copied = coordinator.handle(.copyPlanIntoActualDraft)
  try expect(copied.isSuccess, "the linked Attempt should allow an Actual draft")
  let actualSecondID = try required(
    coordinator.projection.keyframes.dropFirst().first?.id,
    "second Actual keyframe"
  )
  _ = coordinator.handle(.selectKeyframe(actualSecondID))
  _ = coordinator.handle(.selectLimb(.rightHand))
  let changed = coordinator.handle(.assignHold(holdID: HoldID("hold-mid-left")))
  try expect(changed.isSuccess, "the Actual contact should remain editable")
  let actualFirstID = try required(
    coordinator.projection.keyframes.first?.id,
    "first Actual keyframe"
  )
  _ = coordinator.handle(.selectKeyframe(actualFirstID))
  let focused = try required(
    coordinator.projection.focusedComparisonStep,
    "focused Plan/Actual comparison"
  )
  try expect(
    focused.limbDivergences.contains {
      $0.limb == .rightHand && $0.state == .different
    },
    "the focused comparison should expose the changed right-hand choice"
  )
}

private func actualDraftRequiresAttemptAndRemainsUserAuthored() throws {
  var withoutAttempt = try makeRehearsalCoordinator(actualAttemptID: nil)
  let rejected = withoutAttempt.handle(.copyPlanIntoActualDraft)
  try expect(
    rejected.outcome == .rejected(.actualAttemptRequired),
    "Actual creation should require a real associated Attempt"
  )
  try expect(
    withoutAttempt.engine.rehearsal.actual.keyframes.isEmpty,
    "rejected Actual creation must not mutate the timeline"
  )
  try expect(
    !rejected.projection.canCreateActualDraft,
    "UI projection should disable Actual drafting without an Attempt"
  )

  let attemptID = AttemptID("actual-draft-attempt")
  var linked = try makeRehearsalCoordinator(actualAttemptID: attemptID)
  let copied = linked.handle(.copyPlanIntoActualDraft)
  try expect(copied.isSuccess, "Attempt-linked Plan should copy into an Actual draft")
  try expect(
    copied.projection.actualAttemptID == attemptID, "Attempt identity should remain visible")
  try expect(copied.projection.activeTrack == .actual, "copied draft should open Actual")
  try expect(
    copied.projection.keyframes.allSatisfy {
      $0.provenance.authorship == .userAuthored
        && $0.provenance.automation == .manual
    },
    "copied Plan is a user-authored manual draft, never observed movement"
  )
  try expect(
    copied.projection.timelineImportProvenance == .manual,
    "Actual draft track provenance should be manual"
  )
}

private func rehearsalCoordinatorPreservesProviderProvenance() throws {
  var coordinator = try makeRehearsalCoordinator()
  let scene = coordinator.projection.scene

  let routeImport = coordinator.handle(
    .importRoute(
      request: RouteReadRequest(
        sceneID: scene.id,
        name: scene.name,
        size: scene.size,
        metersPerSceneUnit: scene.metersPerSceneUnit,
        candidateHolds: Array(scene.holds.reversed())
      ),
      provider: .deterministicLocal(version: "route-spec-v2")
    ))
  try expect(routeImport.isSuccess, "expected deterministic route import")
  try expect(
    routeImport.projection.routeReadProvenance.automation == .deterministicLocal,
    "expected deterministic route provenance"
  )
  try expect(
    routeImport.projection.routeReadProvenance.version == "route-spec-v2",
    "expected route provider version to survive import"
  )
  try expect(
    routeImport.projection.scene.holds.map(\.center.y)
      == routeImport.projection.scene.holds.map(\.center.y).sorted(),
    "expected deterministic route reader order"
  )

  let seedCount = coordinator.projection.keyframes.count
  let generated = coordinator.handle(
    .importTimeline(
      track: .plan,
      seedKeyframes: coordinator.projection.keyframes,
      maximumKeyframeCount: 5,
      provider: .deterministicLocal(version: "movement-spec-v3")
    ))
  try expect(generated.isSuccess, "expected deterministic movement import")
  try expect(generated.projection.keyframes.count == 5, "expected generated movement frames")
  try expect(
    generated.projection.timelineImportProvenance?.providerIdentifier
      == "deterministic-local-rehearsal",
    "expected movement provider identity"
  )
  try expect(
    generated.projection.timelineImportProvenance?.version == "movement-spec-v3",
    "expected movement provider version"
  )
  try expect(
    generated.projection.keyframes.prefix(seedCount).allSatisfy {
      $0.provenance == .manual
    },
    "expected the user-authored frames the suggester extended to stay user authored"
  )
  try expect(
    generated.projection.keyframes.dropFirst(seedCount).allSatisfy {
      $0.provenance.isSuggested && $0.provenance.automation == .deterministicLocal
    },
    "expected the frames the suggester generated to be labelled as its suggestion"
  )

  let copiedToActual = coordinator.handle(
    .importTimeline(
      track: .actual,
      seedKeyframes: coordinator.engine.rehearsal.plan.keyframes,
      maximumKeyframeCount: 5,
      provider: .manual
    ))
  try expect(copiedToActual.isSuccess, "expected plan frames to seed Actual")
  try expect(copiedToActual.projection.activeTrack == .actual, "expected Actual to become active")
  try expect(
    Set(copiedToActual.projection.keyframes.map(\.id)).isDisjoint(
      with: Set(coordinator.engine.rehearsal.plan.keyframes.map(\.id))
    ),
    "expected cross-track frame IDs to remain unique"
  )
  try expect(
    copiedToActual.projection.timelineImportProvenance == .manual,
    "expected manual Actual provenance"
  )
}

private func rehearsalCoordinatorEditsTimelineAndRecomputesStalePoses() throws {
  var coordinator = try makeRehearsalCoordinator()
  let firstID = try required(coordinator.projection.keyframes.first?.id, "first frame")
  let secondID = try required(
    coordinator.projection.keyframes.dropFirst().first?.id, "second frame")
  let newHoldID = HoldID("hold-upper-left")

  _ = coordinator.handle(.selectKeyframe(firstID))
  _ = coordinator.handle(.selectLimb(.leftHand))
  try expect(
    coordinator.handle(.setContactLock(true)).isSuccess,
    "expected selected left hand to lock"
  )
  let lockedEdit = coordinator.handle(.assignHold(holdID: newHoldID))
  try expect(!lockedEdit.isSuccess, "expected a locked contact to reject reassignment")
  try expect(
    lockedEdit.outcome == .rejected(.engine(.lockedContact(.leftHand, firstID))),
    "expected exact locked-contact rejection"
  )

  _ = coordinator.handle(.setContactLock(false))
  let moved = coordinator.handle(.assignHold(holdID: newHoldID))
  try expect(moved.isSuccess, "expected unlocked left hand to move")
  try expect(
    moved.projection.selectedKeyframe?.contact(for: .leftHand)?.target.holdID == newHoldID,
    "expected selected hold assignment"
  )
  try expect(
    moved.projection.keyframes.dropFirst().allSatisfy(\.validity.isStale),
    "expected an upstream edit to stale downstream poses"
  )
  try expect(
    moved.projection.selectedFrameWasManuallyEdited,
    "expected imported-source provenance to coexist with manual edit audit"
  )

  let recomputed = coordinator.handle(.recomputeDownstream(after: firstID))
  try expect(recomputed.isSuccess, "expected downstream recompute")
  try expect(
    recomputed.projection.keyframes.allSatisfy { !$0.validity.isStale },
    "expected recompute to clear stale markers"
  )

  let addedID = PoseKeyframeID("frame-added")
  try expect(
    coordinator.handle(.addKeyframe(id: addedID, label: "Added", after: secondID)).isSuccess,
    "expected keyframe add"
  )
  let duplicateID = PoseKeyframeID("frame-duplicate")
  try expect(
    coordinator.handle(
      .duplicateKeyframe(addedID, as: duplicateID, label: "Duplicate")
    ).isSuccess,
    "expected keyframe duplicate"
  )
  try expect(
    coordinator.handle(.moveKeyframe(duplicateID, to: 0)).isSuccess,
    "expected keyframe reorder"
  )
  try expect(
    coordinator.projection.keyframes.first?.id == duplicateID,
    "expected reordered frame at destination"
  )
  try expect(
    coordinator.handle(.deleteKeyframe(addedID)).isSuccess,
    "expected keyframe delete"
  )
  try expect(
    !coordinator.projection.keyframes.contains { $0.id == addedID },
    "expected deleted frame to leave timeline"
  )

  _ = coordinator.handle(.selectTrack(.actual))
  try expect(coordinator.projection.keyframes.isEmpty, "expected initially empty Actual")
  let observedID = PoseKeyframeID("actual-first")
  let observed = coordinator.handle(
    .addKeyframe(id: observedID, label: "Observed start", after: nil)
  )
  try expect(observed.isSuccess, "expected first Actual frame to seed from Plan")
  try expect(observed.projection.keyframes.map(\.id) == [observedID], "expected one Actual frame")
  try expect(
    observed.projection.keyframes.first?.provenance == .manual,
    "expected manually added Actual provenance"
  )
}

private func rehearsalCoordinatorSupportsPlaybackModes() throws {
  var coordinator = try makeRehearsalCoordinator()
  try expect(coordinator.projection.avatar != nil, "expected solved avatar before playback")

  let forward = coordinator.handle(.stepForward)
  try expect(forward.isSuccess, "expected single-step forward")
  try expect(forward.projection.selectedKeyframeIndex == 1, "expected second frame selected")

  let backward = coordinator.handle(.stepBackward)
  try expect(backward.isSuccess, "expected single-step backward")
  try expect(backward.projection.selectedKeyframeIndex == 0, "expected first frame selected")

  let scrubbed = coordinator.handle(.scrub(transitionIndex: 1, progress: 0.5))
  try expect(scrubbed.isSuccess, "expected timeline scrub")
  try expect(
    scrubbed.projection.playback.cursor.transitionIndex == 1
      && scrubbed.projection.playback.cursor.progress == 0.5,
    "expected exact scrub cursor"
  )
  try expect(scrubbed.projection.avatar != nil, "expected interpolated stick figure")

  _ = coordinator.handle(.scrub(transitionIndex: 0, progress: 0))
  let playing = coordinator.handle(.play(scope: .fullTimeline, loop: true))
  try expect(playing.isSuccess && playing.projection.isPlaying, "expected continuous playback")
  try expect(playing.projection.isLooping, "expected continuous loop flag")

  let advanced = coordinator.handle(.tick(elapsedSeconds: 1.25))
  try expect(advanced.isSuccess, "expected playback tick")
  try expect(
    advanced.projection.playback.cursor.transitionIndex == 1
      && advanced.projection.playback.cursor.progress == 0.25,
    "expected tick to advance across movement boundary"
  )

  let looped = coordinator.handle(.tick(elapsedSeconds: 3))
  try expect(looped.isSuccess && looped.projection.isPlaying, "expected loop to remain playing")
  try expect(looped.projection.avatar != nil, "expected avatar after loop wrap")

  let paused = coordinator.handle(.pause)
  try expect(paused.isSuccess && !paused.projection.isPlaying, "expected pause")

  _ = coordinator.handle(.scrub(transitionIndex: 0, progress: 0))
  _ = coordinator.handle(.play(scope: .currentStep, loop: false))
  let completedStep = coordinator.handle(.tick(elapsedSeconds: 1.5))
  try expect(!completedStep.projection.isPlaying, "expected non-looping step to pause at its end")
  try expect(
    completedStep.projection.playback.cursor.progress == 1,
    "expected exact final pose for single-step playback"
  )
}

private func makeRehearsalCoordinator(
  actualAttemptID: AttemptID? = AttemptID("rehearsal-spec-attempt")
) throws -> LineWiseRehearsalCoordinator {
  let holds = [
    Hold(id: HoldID("hold-lower-left"), center: Point2D(x: 25, y: 20), radius: 4),
    Hold(id: HoldID("hold-lower-right"), center: Point2D(x: 55, y: 22), radius: 4),
    Hold(id: HoldID("hold-mid-left"), center: Point2D(x: 28, y: 65), radius: 4),
    Hold(id: HoldID("hold-mid-right"), center: Point2D(x: 62, y: 72), radius: 4),
    Hold(id: HoldID("hold-upper-left"), center: Point2D(x: 34, y: 118), radius: 4),
    Hold(
      id: HoldID("hold-top"),
      center: Point2D(x: 58, y: 168),
      radius: 5,
      routeRole: .top
    ),
  ]
  let scene = RouteScene(
    id: RouteSceneID("scene-spec"),
    name: "Spec wall",
    size: SceneSize(width: 100, height: 190),
    metersPerSceneUnit: 0.025,
    holds: holds
  )
  let body = BodyProfile(
    id: BodyProfileID("body-spec"),
    heightMeters: 1.72,
    armSpanMeters: 1.76,
    inseamMeters: 0.80,
    shoulderWidthMeters: 0.39,
    hipWidthMeters: 0.31
  )
  let frames = [
    makeFrame(
      id: "frame-0",
      label: "Start",
      torso: Point2D(x: 42, y: 48),
      leftHand: "hold-mid-left",
      rightHand: "hold-mid-right",
      leftFoot: "hold-lower-left",
      rightFoot: "hold-lower-right"
    ),
    makeFrame(
      id: "frame-1",
      label: "Reach",
      torso: Point2D(x: 45, y: 82),
      leftHand: "hold-mid-left",
      rightHand: "hold-upper-left",
      leftFoot: "hold-lower-left",
      rightFoot: "hold-lower-right"
    ),
    makeFrame(
      id: "frame-2",
      label: "Finish",
      torso: Point2D(x: 50, y: 128),
      leftHand: "hold-upper-left",
      rightHand: "hold-top",
      leftFoot: "hold-mid-left",
      rightFoot: "hold-mid-right"
    ),
  ]
  return try LineWiseRehearsalCoordinator(
    routeCardID: RouteCardID("route-card-spec"),
    rehearsalID: RouteRehearsalID("rehearsal-spec"),
    scene: scene,
    bodyProfile: body,
    planKeyframes: frames,
    actualAttemptID: actualAttemptID
  )
}

private func makeFrame(
  id: String,
  label: String,
  torso: Point2D,
  leftHand: String,
  rightHand: String,
  leftFoot: String,
  rightFoot: String
) -> PoseKeyframe {
  PoseKeyframe(
    id: PoseKeyframeID(id),
    label: label,
    torsoPosition: torso,
    contacts: [
      LimbContact(limb: .leftHand, target: .hold(HoldID(leftHand)), mode: .hand),
      LimbContact(limb: .rightHand, target: .hold(HoldID(rightHand)), mode: .hand),
      LimbContact(limb: .leftFoot, target: .hold(HoldID(leftFoot)), mode: .foot),
      LimbContact(limb: .rightFoot, target: .hold(HoldID(rightFoot)), mode: .foot),
    ],
    provenance: .manual
  )
}

private func required<Value>(_ value: Value?, _ label: String) throws -> Value {
  guard let value else {
    throw ApplicationSpecFailure.expected("missing \(label)")
  }
  return value
}
