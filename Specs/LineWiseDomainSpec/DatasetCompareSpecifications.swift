import Foundation
import LineWiseDomain

private enum DatasetCompareSpecFailure: Error {
  case expected(String)
}

private func datasetCompareExpect(
  _ condition: @autoclosure () -> Bool,
  _ message: String
) throws {
  guard condition() else {
    throw DatasetCompareSpecFailure.expected(message)
  }
}

private let datasetCompareObserved = RehearsalProvenance(
  authorship: .observed,
  automation: .manual,
  providerIdentifier: "user-video-review",
  version: "1"
)

private let datasetCompareInferred = RehearsalProvenance(
  authorship: .suggested,
  automation: .deterministicLocal,
  providerIdentifier: "compare-fixture",
  version: "1"
)

private func datasetScene() -> RouteScene {
  RouteScene(
    id: RouteSceneID("dataset-scene"),
    name: "Dataset wall",
    size: SceneSize(width: 3, height: 4),
    metersPerSceneUnit: 1,
    holds: [
      Hold(id: HoldID("lh"), center: Point2D(x: 0.8, y: 2.1), radius: 0.1),
      Hold(id: HoldID("rh"), center: Point2D(x: 1.5, y: 2.2), radius: 0.1),
      Hold(id: HoldID("lf"), center: Point2D(x: 0.9, y: 0.8), radius: 0.1),
      Hold(id: HoldID("rf"), center: Point2D(x: 1.4, y: 0.9), radius: 0.1),
      Hold(id: HoldID("p-next"), center: Point2D(x: 1.9, y: 2.7), radius: 0.1),
      Hold(id: HoldID("a-next"), center: Point2D(x: 2.2, y: 2.5), radius: 0.1),
      Hold(id: HoldID("top"), center: Point2D(x: 1.7, y: 3.4), radius: 0.1),
    ]
  )
}

private func datasetContacts(
  rightHand: HoldID = HoldID("rh"),
  leftHand: HoldID = HoldID("lh")
) -> [LimbContact] {
  [
    LimbContact(limb: .leftHand, target: .hold(leftHand)),
    LimbContact(limb: .rightHand, target: .hold(rightHand)),
    LimbContact(limb: .leftFoot, target: .hold(HoldID("lf"))),
    LimbContact(limb: .rightFoot, target: .hold(HoldID("rf"))),
  ]
}

private func datasetFrame(
  _ id: String,
  torso: Point2D,
  rightHand: HoldID = HoldID("rh"),
  leftHand: HoldID = HoldID("lh"),
  provenance: RehearsalProvenance = .manual
) -> PoseKeyframe {
  PoseKeyframe(
    id: PoseKeyframeID(id),
    label: id,
    torsoPosition: torso,
    contacts: datasetContacts(rightHand: rightHand, leftHand: leftHand),
    provenance: provenance
  )
}

private func datasetStep(
  from: PoseKeyframe,
  to: PoseKeyframe,
  duration: Double,
  provenance: RehearsalProvenance
) -> MovementStep {
  let changes = Limb.allCases.compactMap { limb -> ContactChange? in
    guard
      let old = from.contact(for: limb)?.target,
      let new = to.contact(for: limb)?.target,
      old != new
    else { return nil }
    return ContactChange(limb: limb, from: old, to: new)
  }
  return MovementStep(
    fromKeyframeID: from.id,
    toKeyframeID: to.id,
    changes: changes,
    retainedLimbs: Limb.allCases.filter { limb in
      from.contact(for: limb)?.target == to.contact(for: limb)?.target
    },
    gainedLimbs: changes.filter(\.to.isSupportContact).map(\.limb),
    releasedLimbs: changes.filter(\.from.isSupportContact).map(\.limb),
    expectedDurationSeconds: duration,
    family: provenance.authorship == .observed ? .observed : .staticMove,
    explanation: "fixture",
    provenance: provenance
  )
}

private func datasetRehearsal() -> RouteRehearsal {
  let p0 = datasetFrame("p0", torso: Point2D(x: 1.1, y: 1.5))
  let p1 = datasetFrame(
    "p1", torso: Point2D(x: 1.3, y: 1.8), rightHand: HoldID("p-next"))
  let p2 = datasetFrame(
    "p2", torso: Point2D(x: 1.5, y: 2.2), rightHand: HoldID("p-next"),
    leftHand: HoldID("a-next"))
  let p3 = datasetFrame(
    "p3", torso: Point2D(x: 1.6, y: 2.8), rightHand: HoldID("top"),
    leftHand: HoldID("a-next"))

  let a0 = datasetFrame(
    "a0", torso: Point2D(x: 1.1, y: 1.5), provenance: datasetCompareObserved)
  let a1 = datasetFrame(
    "a1", torso: Point2D(x: 1.5, y: 1.7), rightHand: HoldID("a-next"),
    provenance: datasetCompareObserved)
  let a2 = datasetFrame(
    "a2", torso: Point2D(x: 1.7, y: 2.3), rightHand: HoldID("a-next"),
    leftHand: HoldID("a-next"), provenance: datasetCompareInferred)

  return RouteRehearsal(
    id: RouteRehearsalID("dataset-rehearsal"),
    scene: datasetScene(),
    bodyProfile: .generic(id: BodyProfileID("dataset-body")),
    plan: RehearsalTimeline(
      keyframes: [p0, p1, p2, p3],
      steps: [
        datasetStep(from: p0, to: p1, duration: 1, provenance: .manual),
        datasetStep(from: p1, to: p2, duration: 1.5, provenance: .manual),
        datasetStep(from: p2, to: p3, duration: 1, provenance: .manual),
      ]
    ),
    actual: RehearsalTimeline(
      keyframes: [a0, a1, a2],
      steps: [
        datasetStep(from: a0, to: a1, duration: 1.4, provenance: datasetCompareObserved),
        datasetStep(from: a1, to: a2, duration: 2.1, provenance: datasetCompareInferred),
      ]
    )
  )
}

private func datasetAsset(
  id: RouteMediaAssetID,
  origin: MediaAssetOrigin = .source
) -> RouteMediaAsset {
  RouteMediaAsset(
    id: id,
    routeCardID: RouteCardID("route-blue"),
    localReference: LocalMediaReference(
      fileIdentifier: "local-\(id.rawValue)",
      sandboxRelativePath: "Media/\(id.rawValue).mov"
    ),
    kind: .actualVideo,
    mimeType: "video/quicktime",
    byteCount: 100,
    dimensions: MediaDimensions(pixelWidth: 100, pixelHeight: 100),
    contentDigest: MediaContentDigest(algorithm: .sha256, hexValue: "hash-\(id.rawValue)"),
    purpose: .personalMovementReview,
    consent: MediaConsent(
      status: .granted,
      scope: .onDevicePersonalAnalysis,
      recordedAt: Instant(millisecondsSince1970: 1_000)
    ),
    captureProvenance: MediaCaptureProvenance(
      capturedAt: Instant(millisecondsSince1970: 900),
      deviceClass: .phone,
      method: .cameraCapture,
      importedByUser: true
    ),
    origin: origin,
    quality: .unreviewed,
    retention: .keepUntilUserDeletes
  )
}

private func sourceAndDerivedMediaRemainDistinctInExport() throws {
  var dataset = PersonalDataset()
  let source = RouteMediaAsset(
    id: RouteMediaAssetID("source-video"),
    routeCardID: RouteCardID("route-blue"),
    localReference: LocalMediaReference(
      fileIdentifier: "local-source-1",
      sandboxRelativePath: "Media/source-video.mov"
    ),
    kind: .actualVideo,
    mimeType: "video/quicktime",
    byteCount: 12_345,
    dimensions: MediaDimensions(pixelWidth: 1_920, pixelHeight: 1_080),
    contentDigest: MediaContentDigest(algorithm: .sha256, hexValue: "abc123"),
    purpose: .personalMovementReview,
    consent: MediaConsent(
      status: .granted,
      scope: .onDevicePersonalAnalysis,
      recordedAt: Instant(millisecondsSince1970: 1_000)
    ),
    captureProvenance: MediaCaptureProvenance(
      capturedAt: Instant(millisecondsSince1970: 900),
      deviceClass: .phone,
      method: .cameraCapture,
      importedByUser: true
    ),
    origin: .source,
    quality: .usable,
    retention: .keepUntilUserDeletes
  )
  let derived = RouteMediaAsset(
    id: RouteMediaAssetID("derived-frame"),
    routeCardID: RouteCardID("route-blue"),
    localReference: LocalMediaReference(
      fileIdentifier: "local-derived-1",
      sandboxRelativePath: "Media/derived-frame.heic"
    ),
    kind: .extractedFrame,
    mimeType: "image/heic",
    byteCount: 2_345,
    dimensions: MediaDimensions(pixelWidth: 1_920, pixelHeight: 1_080),
    contentDigest: MediaContentDigest(algorithm: .sha256, hexValue: "def456"),
    purpose: .planActualComparison,
    consent: source.consent,
    captureProvenance: source.captureProvenance,
    origin: .derived(
      sourceAssetIDs: [source.id],
      transform: MediaDerivation(
        kind: .frameExtraction,
        implementationIdentifier: "linewise-local-frame-extractor",
        version: "1"
      )
    ),
    quality: .limited([.motionBlur]),
    retention: .expiresAt(Instant(millisecondsSince1970: 99_000))
  )

  try dataset.add(source)
  try dataset.add(derived)
  let manifest = dataset.exportManifest(createdAt: Instant(millisecondsSince1970: 2_000))
  let decoded = try JSONDecoder().decode(
    DatasetExportManifest.self,
    from: JSONEncoder().encode(manifest)
  )

  try datasetCompareExpect(decoded == manifest, "the export manifest must be Codable")
  try datasetCompareExpect(
    decoded.activeAssets.map(\.id) == [derived.id, source.id],
    "the export must be deterministic by asset ID"
  )
  try datasetCompareExpect(source.isSource && !derived.isSource, "source and derived must not blur")
  try datasetCompareExpect(
    derived.sourceAssetIDs == [source.id],
    "a derived asset must retain immutable source lineage"
  )
}

private func modelSuggestionsCannotBecomeConfirmedAnnotations() throws {
  var dataset = PersonalDataset()
  let asset = datasetAsset(id: RouteMediaAssetID("annotation-asset"))
  try dataset.add(asset)

  let suggested = MediaAnnotationRevision(
    id: MediaAnnotationRevisionID("annotation-suggested-r1"),
    annotationID: MediaAnnotationID("hold-annotation"),
    assetID: asset.id,
    revision: 1,
    payload: .hold(
      HoldAnnotation(
        holdID: HoldID("maybe-hold"),
        center: Point2D(x: 0.4, y: 0.5),
        radius: 0.08
      )
    ),
    assertionState: .suggested,
    evidence: .modelSuggestion(providerIdentifier: "route-reader", version: "v1"),
    createdAt: Instant(millisecondsSince1970: 2_000)
  )
  try dataset.recordAnnotation(suggested)

  let invalidConfirmation = MediaAnnotationRevision(
    id: MediaAnnotationRevisionID("annotation-invalid-r2"),
    annotationID: suggested.annotationID,
    assetID: asset.id,
    revision: 2,
    payload: suggested.payload,
    assertionState: .confirmed,
    evidence: .modelSuggestion(providerIdentifier: "route-reader", version: "v1"),
    createdAt: Instant(millisecondsSince1970: 3_000)
  )
  do {
    try dataset.recordAnnotation(invalidConfirmation)
    throw DatasetCompareSpecFailure.expected("model suggestions must not be stored as confirmed")
  } catch let error as PersonalDatasetError {
    try datasetCompareExpect(
      error == .suggestionCannotBeConfirmed,
      "the rejected transition should explain the epistemic violation"
    )
  }

  let correction = MediaCorrectionRevision(
    id: MediaCorrectionRevisionID("correction-r1"),
    annotationID: suggested.annotationID,
    assetID: asset.id,
    revision: 1,
    replacesAnnotationRevisionID: suggested.id,
    replacement: .hold(
      HoldAnnotation(
        holdID: HoldID("confirmed-hold"),
        center: Point2D(x: 0.42, y: 0.51),
        radius: 0.09
      )
    ),
    reason: "user corrected the detected boundary",
    assertionState: .confirmed,
    evidence: .manualUser,
    createdAt: Instant(millisecondsSince1970: 4_000)
  )
  try dataset.recordCorrection(correction)

  try datasetCompareExpect(
    dataset.annotationHistory(for: suggested.annotationID) == [suggested],
    "the suggestion must remain immutable in annotation history"
  )
  try datasetCompareExpect(
    dataset.correctionHistory(for: suggested.annotationID) == [correction],
    "a user correction should be a separate confirmed fact"
  )
}

private func deletionLeavesAReplayableTombstoneWithoutErasingLineage() throws {
  var dataset = PersonalDataset()
  let source = datasetAsset(id: RouteMediaAssetID("delete-source"))
  let derived = datasetAsset(
    id: RouteMediaAssetID("keep-derived"),
    origin: .derived(
      sourceAssetIDs: [source.id],
      transform: MediaDerivation(
        kind: .poseOverlay,
        implementationIdentifier: "local-overlay",
        version: "1"
      )
    )
  )
  try dataset.add(source)
  try dataset.add(derived)

  let tombstone = try dataset.deleteAsset(
    source.id,
    at: Instant(millisecondsSince1970: 5_000),
    reason: .userRequested
  )
  let manifest = dataset.exportManifest(createdAt: Instant(millisecondsSince1970: 6_000))

  try datasetCompareExpect(dataset.asset(id: source.id) == nil, "deleted bytes must not be active")
  try datasetCompareExpect(
    manifest.deletionTombstones == [tombstone],
    "export must carry a deterministic deletion tombstone"
  )
  try datasetCompareExpect(
    dataset.asset(id: derived.id)?.sourceAssetIDs == [source.id],
    "deleting source bytes must not rewrite derived provenance"
  )
  do {
    try dataset.add(source)
    throw DatasetCompareSpecFailure.expected("a tombstoned asset ID must not be silently reused")
  } catch let error as PersonalDatasetError {
    try datasetCompareExpect(error == .assetIDTombstoned(source.id), "ID reuse should be explicit")
  }
}

private func deterministicCompareKeepsFourLimbTorsoTimingAndEvidenceStateExplicit() throws {
  let rehearsal = datasetRehearsal()
  let first = RehearsalCompare.align(
    rehearsal: rehearsal,
    planTimelineVersion: "plan-v3",
    actualTimelineVersion: "actual-v2"
  )
  let second = RehearsalCompare.align(
    rehearsal: rehearsal,
    planTimelineVersion: "plan-v3",
    actualTimelineVersion: "actual-v2"
  )

  try datasetCompareExpect(first == second, "alignment must be deterministic")
  try datasetCompareExpect(
    first.alignedSteps.allSatisfy { $0.limbDivergences.map(\.limb) == Limb.allCases },
    "every aligned step must report LH, RH, LF and RF in stable order"
  )
  try datasetCompareExpect(
    first.alignedSteps.contains { $0.actualStep == nil && $0.alignmentState == .missingActual },
    "a shorter Actual timeline must remain explicitly missing"
  )
  try datasetCompareExpect(
    first.alignedSteps.contains {
      $0.actualEvidence.kind == .observed && $0.planEvidence.kind == .manual
    },
    "manual plan and observed actual evidence must remain distinct"
  )
  try datasetCompareExpect(
    first.alignedSteps.contains {
      $0.actualEvidence.kind == .inferred && $0.actualEvidence.certainty == .uncertain
    },
    "inferred actual data must remain visibly uncertain"
  )
  try datasetCompareExpect(
    first.alignedSteps.allSatisfy {
      $0.torsoDivergence.state != .notEvaluated
        && $0.timingDivergence.state != .notEvaluated
    },
    "torso and timing must never disappear into an implicit nil"
  )
}

private func oneToThreeContinuousStepsProduceAPinnedReplayableStickFigureCue() throws {
  let rehearsal = datasetRehearsal()
  let comparison = RehearsalCompare.align(
    rehearsal: rehearsal,
    planTimelineVersion: "plan-v3",
    actualTimelineVersion: "actual-v2"
  )
  let cue = try RehearsalCompare.makeStickFigureCue(
    id: StickFigureCueID("cue-1"),
    comparison: comparison,
    alignedStepRange: 0...1,
    preferredTrack: .plan,
    pin: StickFigureCuePin(
      scene: rehearsal.scene,
      bodyProfile: rehearsal.bodyProfile,
      timelineVersion: "plan-v3"
    )
  )
  let roundTripped = try JSONDecoder().decode(
    StickFigureCue.self,
    from: JSONEncoder().encode(cue)
  )

  try datasetCompareExpect(cue == roundTripped, "a cue should survive save and reopen")
  try datasetCompareExpect(cue.steps.count == 2, "the cue should contain the selected steps")
  try datasetCompareExpect(
    cue.keyframes.count == 3
      && cue.replay()
        == RehearsalTimeline(
          keyframes: cue.keyframes,
          steps: cue.steps
        ),
    "the pinned snapshots should replay without reading mutable current state"
  )
  try datasetCompareExpect(
    cue.sceneSnapshot == rehearsal.scene
      && cue.bodyProfileSnapshot == rehearsal.bodyProfile
      && cue.timelineVersion == "plan-v3",
    "scene, body and timeline version must be pinned together"
  )

  do {
    _ = try RehearsalCompare.makeStickFigureCue(
      id: StickFigureCueID("too-long"),
      comparison: comparison,
      alignedStepRange: 0...3,
      preferredTrack: .plan,
      pin: StickFigureCuePin(
        scene: rehearsal.scene,
        bodyProfile: rehearsal.bodyProfile,
        timelineVersion: "plan-v3"
      )
    )
    throw DatasetCompareSpecFailure.expected("a cue must contain at most three steps")
  } catch let error as RehearsalCompareError {
    try datasetCompareExpect(error == .cueStepCountOutOfRange, "the bound should be explicit")
  }
}

private func learningCandidatesStaySuggestedAndNonSafety() throws {
  let rehearsal = datasetRehearsal()
  let comparison = RehearsalCompare.align(
    rehearsal: rehearsal,
    planTimelineVersion: "plan-v3",
    actualTimelineVersion: "actual-v2"
  )
  let cue = try RehearsalCompare.makeStickFigureCue(
    id: StickFigureCueID("cue-learning"),
    comparison: comparison,
    alignedStepRange: 0...0,
    preferredTrack: .actual,
    pin: StickFigureCuePin(
      scene: rehearsal.scene,
      bodyProfile: rehearsal.bodyProfile,
      timelineVersion: "actual-v2"
    )
  )
  let artifacts = RehearsalCompare.suggestLearningArtifacts(
    from: cue,
    routeCardID: RouteCardID("route-blue")
  )

  try datasetCompareExpect(
    artifacts.moveCue.status == .suggested && artifacts.proofCheck.status == .suggested,
    "compare output must remain candidate material"
  )
  try datasetCompareExpect(
    !artifacts.moveCue.isSafetyJudgment && !artifacts.proofCheck.isSafetyJudgment,
    "qualitative comparisons must never make safety claims"
  )
  try datasetCompareExpect(
    artifacts.moveCue.sourceCueID == cue.id && artifacts.proofCheck.sourceCueID == cue.id,
    "candidate artifacts must link back to their replayable evidence"
  )
}

public func datasetCompareSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "source and derived media remain distinct in export",
      sourceAndDerivedMediaRemainDistinctInExport
    ),
    (
      "model suggestions cannot become confirmed annotations",
      modelSuggestionsCannotBecomeConfirmedAnnotations
    ),
    (
      "deletion leaves a replayable tombstone without erasing lineage",
      deletionLeavesAReplayableTombstoneWithoutErasingLineage
    ),
    (
      "deterministic compare keeps four-limb torso timing and evidence state explicit",
      deterministicCompareKeepsFourLimbTorsoTimingAndEvidenceStateExplicit
    ),
    (
      "one to three continuous steps produce a pinned replayable stick-figure cue",
      oneToThreeContinuousStepsProduceAPinnedReplayableStickFigureCue
    ),
    (
      "learning candidates stay suggested and non-safety",
      learningCandidatesStaySuggestedAndNonSafety
    ),
  ]
}
