import Foundation

public enum CompareEvidenceKind: String, Hashable, Codable, Sendable {
  case manual
  case observed
  case inferred
  case missing
}

public enum CompareCertainty: String, Hashable, Codable, Sendable {
  case certain
  case uncertain
  case missing
}

public struct CompareEvidence: Hashable, Codable, Sendable {
  public let kind: CompareEvidenceKind
  public let certainty: CompareCertainty
  public let providerIdentifier: String?
  public let version: String?

  public init(
    kind: CompareEvidenceKind,
    certainty: CompareCertainty,
    providerIdentifier: String?,
    version: String?
  ) {
    self.kind = kind
    self.certainty = certainty
    self.providerIdentifier = providerIdentifier
    self.version = version
  }

  public static let missing = CompareEvidence(
    kind: .missing,
    certainty: .missing,
    providerIdentifier: nil,
    version: nil
  )

  public static func preserving(_ provenance: RehearsalProvenance) -> CompareEvidence {
    switch provenance.authorship {
    case .userAuthored:
      CompareEvidence(
        kind: .manual,
        certainty: .certain,
        providerIdentifier: provenance.providerIdentifier,
        version: provenance.version
      )
    case .observed:
      CompareEvidence(
        kind: .observed,
        certainty: .certain,
        providerIdentifier: provenance.providerIdentifier,
        version: provenance.version
      )
    case .suggested:
      CompareEvidence(
        kind: .inferred,
        certainty: .uncertain,
        providerIdentifier: provenance.providerIdentifier,
        version: provenance.version
      )
    }
  }
}

public enum AlignmentState: String, Hashable, Codable, Sendable {
  case aligned
  case missingPlan = "missing_plan"
  case missingActual = "missing_actual"
}

public enum DivergenceState: String, Hashable, Codable, Sendable {
  case same
  case different
  case uncertain
  case missingPlan = "missing_plan"
  case missingActual = "missing_actual"
  case notEvaluated = "not_evaluated"
}

public struct LimbContactDivergence: Equatable, Codable, Sendable {
  public let limb: Limb
  public let planTarget: ContactTarget?
  public let actualTarget: ContactTarget?
  public let planEvidence: CompareEvidence
  public let actualEvidence: CompareEvidence
  public let state: DivergenceState

  public init(
    limb: Limb,
    planTarget: ContactTarget?,
    actualTarget: ContactTarget?,
    planEvidence: CompareEvidence,
    actualEvidence: CompareEvidence,
    state: DivergenceState
  ) {
    self.limb = limb
    self.planTarget = planTarget
    self.actualTarget = actualTarget
    self.planEvidence = planEvidence
    self.actualEvidence = actualEvidence
    self.state = state
  }
}

public struct TorsoDivergence: Equatable, Codable, Sendable {
  public let planPosition: Point2D?
  public let actualPosition: Point2D?
  public let deltaX: Double?
  public let deltaY: Double?
  public let distance: Double?
  public let planEvidence: CompareEvidence
  public let actualEvidence: CompareEvidence
  public let state: DivergenceState

  public init(
    planPosition: Point2D?,
    actualPosition: Point2D?,
    deltaX: Double?,
    deltaY: Double?,
    distance: Double?,
    planEvidence: CompareEvidence,
    actualEvidence: CompareEvidence,
    state: DivergenceState
  ) {
    self.planPosition = planPosition
    self.actualPosition = actualPosition
    self.deltaX = deltaX
    self.deltaY = deltaY
    self.distance = distance
    self.planEvidence = planEvidence
    self.actualEvidence = actualEvidence
    self.state = state
  }
}

public struct TimingDivergence: Equatable, Codable, Sendable {
  public let planDurationSeconds: Double?
  public let actualDurationSeconds: Double?
  public let deltaSeconds: Double?
  public let planEvidence: CompareEvidence
  public let actualEvidence: CompareEvidence
  public let state: DivergenceState

  public init(
    planDurationSeconds: Double?,
    actualDurationSeconds: Double?,
    deltaSeconds: Double?,
    planEvidence: CompareEvidence,
    actualEvidence: CompareEvidence,
    state: DivergenceState
  ) {
    self.planDurationSeconds = planDurationSeconds
    self.actualDurationSeconds = actualDurationSeconds
    self.deltaSeconds = deltaSeconds
    self.planEvidence = planEvidence
    self.actualEvidence = actualEvidence
    self.state = state
  }
}

public struct AlignedMovementStep: Equatable, Codable, Sendable {
  public let alignmentIndex: Int
  public let planStepIndex: Int?
  public let actualStepIndex: Int?
  public let planStep: MovementStep?
  public let actualStep: MovementStep?
  public let alignmentState: AlignmentState
  public let planEvidence: CompareEvidence
  public let actualEvidence: CompareEvidence
  public let limbDivergences: [LimbContactDivergence]
  public let torsoDivergence: TorsoDivergence
  public let timingDivergence: TimingDivergence

  public init(
    alignmentIndex: Int,
    planStepIndex: Int?,
    actualStepIndex: Int?,
    planStep: MovementStep?,
    actualStep: MovementStep?,
    alignmentState: AlignmentState,
    planEvidence: CompareEvidence,
    actualEvidence: CompareEvidence,
    limbDivergences: [LimbContactDivergence],
    torsoDivergence: TorsoDivergence,
    timingDivergence: TimingDivergence
  ) {
    self.alignmentIndex = alignmentIndex
    self.planStepIndex = planStepIndex
    self.actualStepIndex = actualStepIndex
    self.planStep = planStep
    self.actualStep = actualStep
    self.alignmentState = alignmentState
    self.planEvidence = planEvidence
    self.actualEvidence = actualEvidence
    self.limbDivergences = limbDivergences
    self.torsoDivergence = torsoDivergence
    self.timingDivergence = timingDivergence
  }
}

public struct RehearsalComparison: Equatable, Codable, Sendable {
  public let rehearsalID: RouteRehearsalID
  public let sceneSnapshot: RouteScene
  public let bodyProfileSnapshot: BodyProfile
  public let planSnapshot: RehearsalTimeline
  public let actualSnapshot: RehearsalTimeline
  public let planTimelineVersion: String
  public let actualTimelineVersion: String
  public let alignedSteps: [AlignedMovementStep]

  public init(
    rehearsalID: RouteRehearsalID,
    sceneSnapshot: RouteScene,
    bodyProfileSnapshot: BodyProfile,
    planSnapshot: RehearsalTimeline,
    actualSnapshot: RehearsalTimeline,
    planTimelineVersion: String,
    actualTimelineVersion: String,
    alignedSteps: [AlignedMovementStep]
  ) {
    self.rehearsalID = rehearsalID
    self.sceneSnapshot = sceneSnapshot
    self.bodyProfileSnapshot = bodyProfileSnapshot
    self.planSnapshot = planSnapshot
    self.actualSnapshot = actualSnapshot
    self.planTimelineVersion = planTimelineVersion
    self.actualTimelineVersion = actualTimelineVersion
    self.alignedSteps = alignedSteps
  }
}

public struct StickFigureCueID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct StickFigureCuePin: Equatable, Codable, Sendable {
  public let scene: RouteScene
  public let bodyProfile: BodyProfile
  public let timelineVersion: String

  public init(scene: RouteScene, bodyProfile: BodyProfile, timelineVersion: String) {
    self.scene = scene
    self.bodyProfile = bodyProfile
    self.timelineVersion = timelineVersion
  }
}

public struct StickFigureCue: Equatable, Codable, Sendable {
  public let id: StickFigureCueID
  public let rehearsalID: RouteRehearsalID
  public let sceneSnapshot: RouteScene
  public let bodyProfileSnapshot: BodyProfile
  public let track: RehearsalTrack
  public let timelineVersion: String
  public let sourceAlignmentIndices: [Int]
  public let alignedSteps: [AlignedMovementStep]
  public let keyframes: [PoseKeyframe]
  public let steps: [MovementStep]

  public init(
    id: StickFigureCueID,
    rehearsalID: RouteRehearsalID,
    sceneSnapshot: RouteScene,
    bodyProfileSnapshot: BodyProfile,
    track: RehearsalTrack,
    timelineVersion: String,
    sourceAlignmentIndices: [Int],
    alignedSteps: [AlignedMovementStep],
    keyframes: [PoseKeyframe],
    steps: [MovementStep]
  ) {
    self.id = id
    self.rehearsalID = rehearsalID
    self.sceneSnapshot = sceneSnapshot
    self.bodyProfileSnapshot = bodyProfileSnapshot
    self.track = track
    self.timelineVersion = timelineVersion
    self.sourceAlignmentIndices = sourceAlignmentIndices
    self.alignedSteps = alignedSteps
    self.keyframes = keyframes
    self.steps = steps
  }

  public func replay() -> RehearsalTimeline {
    RehearsalTimeline(keyframes: keyframes, steps: steps)
  }

  public var isSafetyJudgment: Bool { false }
}

public enum SuggestedArtifactStatus: String, Equatable, Codable, Sendable {
  case suggested
}

public struct SuggestedMoveCueCandidate: Equatable, Codable, Sendable {
  public let routeCardID: RouteCardID
  public let sourceCueID: StickFigureCueID
  public let text: String
  public let status: SuggestedArtifactStatus
  public let evidence: CompareEvidence

  public init(
    routeCardID: RouteCardID,
    sourceCueID: StickFigureCueID,
    text: String,
    status: SuggestedArtifactStatus,
    evidence: CompareEvidence
  ) {
    self.routeCardID = routeCardID
    self.sourceCueID = sourceCueID
    self.text = text
    self.status = status
    self.evidence = evidence
  }

  public var isSafetyJudgment: Bool { false }
}

public struct SuggestedProofCheckCandidate: Equatable, Codable, Sendable {
  public let routeCardID: RouteCardID
  public let sourceCueID: StickFigureCueID
  public let question: String
  public let status: SuggestedArtifactStatus
  public let evidence: CompareEvidence

  public init(
    routeCardID: RouteCardID,
    sourceCueID: StickFigureCueID,
    question: String,
    status: SuggestedArtifactStatus,
    evidence: CompareEvidence
  ) {
    self.routeCardID = routeCardID
    self.sourceCueID = sourceCueID
    self.question = question
    self.status = status
    self.evidence = evidence
  }

  public var isSafetyJudgment: Bool { false }
}

public struct SuggestedLearningArtifacts: Equatable, Codable, Sendable {
  public let moveCue: SuggestedMoveCueCandidate
  public let proofCheck: SuggestedProofCheckCandidate

  public init(moveCue: SuggestedMoveCueCandidate, proofCheck: SuggestedProofCheckCandidate) {
    self.moveCue = moveCue
    self.proofCheck = proofCheck
  }
}

public enum RehearsalCompareError: Error, Equatable, Sendable {
  case cueStepCountOutOfRange
  case alignedRangeOutOfBounds
  case cueStepsNotContinuous
  case cueFrameMissing(PoseKeyframeID)
  case pinnedSceneMismatch
  case pinnedBodyProfileMismatch
  case pinnedTimelineVersionMismatch(expected: String, actual: String)
}

public enum RehearsalCompare {
  public static func align(
    rehearsal: RouteRehearsal,
    planTimelineVersion: String,
    actualTimelineVersion: String
  ) -> RehearsalComparison {
    let pairs = deterministicAlignment(
      plan: rehearsal.plan,
      actual: rehearsal.actual,
      scene: rehearsal.scene
    )
    let planFrames = frameLookup(rehearsal.plan)
    let actualFrames = frameLookup(rehearsal.actual)
    let aligned = pairs.enumerated().map { alignmentIndex, pair in
      compare(
        alignmentIndex: alignmentIndex,
        planIndex: pair.plan,
        actualIndex: pair.actual,
        plan: rehearsal.plan,
        actual: rehearsal.actual,
        planFrames: planFrames,
        actualFrames: actualFrames
      )
    }
    return RehearsalComparison(
      rehearsalID: rehearsal.id,
      sceneSnapshot: rehearsal.scene,
      bodyProfileSnapshot: rehearsal.bodyProfile,
      planSnapshot: rehearsal.plan,
      actualSnapshot: rehearsal.actual,
      planTimelineVersion: planTimelineVersion,
      actualTimelineVersion: actualTimelineVersion,
      alignedSteps: aligned
    )
  }

  public static func makeStickFigureCue(
    id: StickFigureCueID,
    comparison: RehearsalComparison,
    alignedStepRange: ClosedRange<Int>,
    preferredTrack: RehearsalTrack,
    pin: StickFigureCuePin
  ) throws -> StickFigureCue {
    let count = alignedStepRange.upperBound - alignedStepRange.lowerBound + 1
    guard (1...3).contains(count) else {
      throw RehearsalCompareError.cueStepCountOutOfRange
    }
    guard alignedStepRange.lowerBound >= 0,
      alignedStepRange.upperBound < comparison.alignedSteps.count
    else {
      throw RehearsalCompareError.alignedRangeOutOfBounds
    }
    guard pin.scene == comparison.sceneSnapshot else {
      throw RehearsalCompareError.pinnedSceneMismatch
    }
    guard pin.bodyProfile == comparison.bodyProfileSnapshot else {
      throw RehearsalCompareError.pinnedBodyProfileMismatch
    }

    let slice = Array(comparison.alignedSteps[alignedStepRange])
    let selection = try selectContinuousTimeline(
      preferredTrack: preferredTrack,
      slice: slice,
      comparison: comparison
    )
    guard pin.timelineVersion == selection.version else {
      throw RehearsalCompareError.pinnedTimelineVersionMismatch(
        expected: selection.version,
        actual: pin.timelineVersion
      )
    }

    let steps = selection.indices.map { selection.timeline.steps[$0] }
    guard let first = steps.first else {
      throw RehearsalCompareError.cueStepCountOutOfRange
    }
    var frameIDs = [first.fromKeyframeID]
    for step in steps {
      guard frameIDs.last == step.fromKeyframeID else {
        throw RehearsalCompareError.cueStepsNotContinuous
      }
      frameIDs.append(step.toKeyframeID)
    }
    let framesByID = frameLookup(selection.timeline)
    let frames = try frameIDs.map { frameID in
      guard let frame = framesByID[frameID] else {
        throw RehearsalCompareError.cueFrameMissing(frameID)
      }
      return frame
    }

    return StickFigureCue(
      id: id,
      rehearsalID: comparison.rehearsalID,
      sceneSnapshot: pin.scene,
      bodyProfileSnapshot: pin.bodyProfile,
      track: selection.track,
      timelineVersion: pin.timelineVersion,
      sourceAlignmentIndices: slice.map(\.alignmentIndex),
      alignedSteps: slice,
      keyframes: frames,
      steps: steps
    )
  }

  public static func suggestLearningArtifacts(
    from cue: StickFigureCue,
    routeCardID: RouteCardID
  ) -> SuggestedLearningArtifacts {
    let contact = cue.alignedSteps
      .flatMap(\.limbDivergences)
      .first { $0.state != .same }
    let torso = cue.alignedSteps.first { $0.torsoDivergence.state != .same }
    let timing = cue.alignedSteps.first { $0.timingDivergence.state != .same }

    let focus: String
    if let contact {
      focus = "Review \(contact.limb.label) contact choice against the pinned Plan/Actual cue"
    } else if torso != nil {
      focus = "Review torso path against the pinned Plan/Actual cue"
    } else if timing != nil {
      focus = "Review movement timing against the pinned Plan/Actual cue"
    } else {
      focus = "Replay the pinned movement and check whether the intended cue is observable"
    }
    let evidence = CompareEvidence(
      kind: .inferred,
      certainty: .uncertain,
      providerIdentifier: "linewise-rehearsal-compare",
      version: "1"
    )
    return SuggestedLearningArtifacts(
      moveCue: SuggestedMoveCueCandidate(
        routeCardID: routeCardID,
        sourceCueID: cue.id,
        text: focus,
        status: .suggested,
        evidence: evidence
      ),
      proofCheck: SuggestedProofCheckCandidate(
        routeCardID: routeCardID,
        sourceCueID: cue.id,
        question: "On the next attempt, was the highlighted change observable in the same segment?",
        status: .suggested,
        evidence: evidence
      )
    )
  }
}

extension RehearsalCompare {
  fileprivate struct AlignmentPair {
    let plan: Int?
    let actual: Int?
  }

  fileprivate enum AlignmentChoice {
    case match
    case missingActual
    case missingPlan
  }

  fileprivate struct TimelineSelection {
    let track: RehearsalTrack
    let timeline: RehearsalTimeline
    let version: String
    let indices: [Int]
  }

  fileprivate static func deterministicAlignment(
    plan: RehearsalTimeline,
    actual: RehearsalTimeline,
    scene: RouteScene
  ) -> [AlignmentPair] {
    let planCount = plan.steps.count
    let actualCount = actual.steps.count
    let gapCost = 2.0
    var costs = Array(
      repeating: Array(repeating: Double.infinity, count: actualCount + 1),
      count: planCount + 1
    )
    var choices = Array(
      repeating: [AlignmentChoice?](repeating: nil, count: actualCount + 1),
      count: planCount + 1
    )
    costs[0][0] = 0
    if planCount > 0 {
      for index in 1...planCount {
        costs[index][0] = Double(index) * gapCost
        choices[index][0] = .missingActual
      }
    }
    if actualCount > 0 {
      for index in 1...actualCount {
        costs[0][index] = Double(index) * gapCost
        choices[0][index] = .missingPlan
      }
    }

    let planFrames = frameLookup(plan)
    let actualFrames = frameLookup(actual)
    if planCount > 0 && actualCount > 0 {
      for planIndex in 1...planCount {
        for actualIndex in 1...actualCount {
          let match =
            costs[planIndex - 1][actualIndex - 1]
            + matchCost(
              planStep: plan.steps[planIndex - 1],
              actualStep: actual.steps[actualIndex - 1],
              planFrames: planFrames,
              actualFrames: actualFrames,
              scene: scene
            )
          let missingActual = costs[planIndex - 1][actualIndex] + gapCost
          let missingPlan = costs[planIndex][actualIndex - 1] + gapCost

          // Stable tie-breaking: match, then a missing Actual step, then a missing Plan step.
          let candidates: [(Double, AlignmentChoice, Int)] = [
            (match, .match, 0),
            (missingActual, .missingActual, 1),
            (missingPlan, .missingPlan, 2),
          ]
          let best = candidates.min { lhs, rhs in
            if abs(lhs.0 - rhs.0) > 0.000_000_1 { return lhs.0 < rhs.0 }
            return lhs.2 < rhs.2
          }!
          costs[planIndex][actualIndex] = best.0
          choices[planIndex][actualIndex] = best.1
        }
      }
    }

    var planIndex = planCount
    var actualIndex = actualCount
    var reversed: [AlignmentPair] = []
    while planIndex > 0 || actualIndex > 0 {
      switch choices[planIndex][actualIndex] {
      case .match:
        reversed.append(AlignmentPair(plan: planIndex - 1, actual: actualIndex - 1))
        planIndex -= 1
        actualIndex -= 1
      case .missingActual:
        reversed.append(AlignmentPair(plan: planIndex - 1, actual: nil))
        planIndex -= 1
      case .missingPlan:
        reversed.append(AlignmentPair(plan: nil, actual: actualIndex - 1))
        actualIndex -= 1
      case nil:
        // Only (0, 0) has no choice, so reaching nil elsewhere is defensive.
        if planIndex > 0 {
          reversed.append(AlignmentPair(plan: planIndex - 1, actual: nil))
          planIndex -= 1
        } else {
          reversed.append(AlignmentPair(plan: nil, actual: actualIndex - 1))
          actualIndex -= 1
        }
      }
    }
    return reversed.reversed()
  }

  fileprivate static func matchCost(
    planStep: MovementStep,
    actualStep: MovementStep,
    planFrames: [PoseKeyframeID: PoseKeyframe],
    actualFrames: [PoseKeyframeID: PoseKeyframe],
    scene: RouteScene
  ) -> Double {
    guard
      let planFrame = planFrames[planStep.toKeyframeID],
      let actualFrame = actualFrames[actualStep.toKeyframeID]
    else { return 1.9 }
    let contactCost =
      Double(
        Limb.allCases.filter {
          planFrame.contact(for: $0)?.target != actualFrame.contact(for: $0)?.target
        }.count
      ) * 0.75
    let diagonal = max(hypot(scene.size.width, scene.size.height), 0.000_1)
    let torsoCost = (planFrame.torsoPosition.distance(to: actualFrame.torsoPosition) / diagonal) * 2
    let maxDuration = max(
      planStep.expectedDurationSeconds,
      actualStep.expectedDurationSeconds,
      0.05
    )
    let timingCost =
      abs(planStep.expectedDurationSeconds - actualStep.expectedDurationSeconds) / maxDuration
      * 0.5
    return contactCost + torsoCost + timingCost
  }

  fileprivate static func frameLookup(
    _ timeline: RehearsalTimeline
  ) -> [PoseKeyframeID: PoseKeyframe] {
    timeline.keyframes.reduce(into: [:]) { result, frame in
      if result[frame.id] == nil {
        result[frame.id] = frame
      }
    }
  }

  fileprivate static func compare(
    alignmentIndex: Int,
    planIndex: Int?,
    actualIndex: Int?,
    plan: RehearsalTimeline,
    actual: RehearsalTimeline,
    planFrames: [PoseKeyframeID: PoseKeyframe],
    actualFrames: [PoseKeyframeID: PoseKeyframe]
  ) -> AlignedMovementStep {
    let planStep = planIndex.map { plan.steps[$0] }
    let actualStep = actualIndex.map { actual.steps[$0] }
    let planFrame = planStep.flatMap { planFrames[$0.toKeyframeID] }
    let actualFrame = actualStep.flatMap { actualFrames[$0.toKeyframeID] }
    let planEvidence = planStep.map { CompareEvidence.preserving($0.provenance) } ?? .missing
    let actualEvidence = actualStep.map { CompareEvidence.preserving($0.provenance) } ?? .missing
    let alignmentState: AlignmentState =
      switch (planStep, actualStep) {
      case (.some, .some): .aligned
      case (.none, .some): .missingPlan
      case (.some, .none), (.none, .none): .missingActual
      }

    let limbDivergences = Limb.allCases.map { limb in
      let planTarget = planFrame?.contact(for: limb)?.target
      let actualTarget = actualFrame?.contact(for: limb)?.target
      return LimbContactDivergence(
        limb: limb,
        planTarget: planTarget,
        actualTarget: actualTarget,
        planEvidence: planEvidence,
        actualEvidence: actualEvidence,
        state: divergenceState(
          planValueExists: planTarget != nil,
          actualValueExists: actualTarget != nil,
          valuesEqual: planTarget == actualTarget,
          planEvidence: planEvidence,
          actualEvidence: actualEvidence
        )
      )
    }

    let planPosition = planFrame?.torsoPosition
    let actualPosition = actualFrame?.torsoPosition
    let torsoState = divergenceState(
      planValueExists: planPosition != nil,
      actualValueExists: actualPosition != nil,
      valuesEqual: planPosition == actualPosition,
      planEvidence: planEvidence,
      actualEvidence: actualEvidence
    )
    let torsoDelta: (x: Double, y: Double, distance: Double)? = {
      guard let planPosition, let actualPosition else { return nil }
      return (
        x: actualPosition.x - planPosition.x,
        y: actualPosition.y - planPosition.y,
        distance: planPosition.distance(to: actualPosition)
      )
    }()
    let torso = TorsoDivergence(
      planPosition: planPosition,
      actualPosition: actualPosition,
      deltaX: torsoDelta?.x,
      deltaY: torsoDelta?.y,
      distance: torsoDelta?.distance,
      planEvidence: planEvidence,
      actualEvidence: actualEvidence,
      state: torsoState
    )

    let planDuration = planStep?.expectedDurationSeconds
    let actualDuration = actualStep?.expectedDurationSeconds
    let timingDelta: Double? = {
      guard let planDuration, let actualDuration else { return nil }
      return actualDuration - planDuration
    }()
    let timing = TimingDivergence(
      planDurationSeconds: planDuration,
      actualDurationSeconds: actualDuration,
      deltaSeconds: timingDelta,
      planEvidence: planEvidence,
      actualEvidence: actualEvidence,
      state: divergenceState(
        planValueExists: planDuration != nil,
        actualValueExists: actualDuration != nil,
        valuesEqual: planDuration == actualDuration,
        planEvidence: planEvidence,
        actualEvidence: actualEvidence
      )
    )

    return AlignedMovementStep(
      alignmentIndex: alignmentIndex,
      planStepIndex: planIndex,
      actualStepIndex: actualIndex,
      planStep: planStep,
      actualStep: actualStep,
      alignmentState: alignmentState,
      planEvidence: planEvidence,
      actualEvidence: actualEvidence,
      limbDivergences: limbDivergences,
      torsoDivergence: torso,
      timingDivergence: timing
    )
  }

  fileprivate static func divergenceState(
    planValueExists: Bool,
    actualValueExists: Bool,
    valuesEqual: Bool,
    planEvidence: CompareEvidence,
    actualEvidence: CompareEvidence
  ) -> DivergenceState {
    guard planValueExists else { return .missingPlan }
    guard actualValueExists else { return .missingActual }
    if planEvidence.certainty == .uncertain || actualEvidence.certainty == .uncertain {
      return .uncertain
    }
    return valuesEqual ? .same : .different
  }

  fileprivate static func selectContinuousTimeline(
    preferredTrack: RehearsalTrack,
    slice: [AlignedMovementStep],
    comparison: RehearsalComparison
  ) throws -> TimelineSelection {
    if let selection = timelineSelection(
      track: preferredTrack,
      slice: slice,
      comparison: comparison
    ) {
      return selection
    }
    let fallback: RehearsalTrack = preferredTrack == .plan ? .actual : .plan
    if let selection = timelineSelection(
      track: fallback,
      slice: slice,
      comparison: comparison
    ) {
      return selection
    }
    throw RehearsalCompareError.cueStepsNotContinuous
  }

  fileprivate static func timelineSelection(
    track: RehearsalTrack,
    slice: [AlignedMovementStep],
    comparison: RehearsalComparison
  ) -> TimelineSelection? {
    let optionalIndices: [Int?] = slice.map {
      track == .plan ? $0.planStepIndex : $0.actualStepIndex
    }
    guard optionalIndices.allSatisfy({ $0 != nil }) else { return nil }
    let indices = optionalIndices.compactMap { $0 }
    guard zip(indices, indices.dropFirst()).allSatisfy({ $1 == $0 + 1 }) else {
      return nil
    }
    return TimelineSelection(
      track: track,
      timeline: track == .plan ? comparison.planSnapshot : comparison.actualSnapshot,
      version: track == .plan
        ? comparison.planTimelineVersion : comparison.actualTimelineVersion,
      indices: indices
    )
  }
}
