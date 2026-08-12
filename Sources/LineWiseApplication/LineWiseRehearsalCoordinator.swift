import Foundation
import LineWiseDomain

public enum RehearsalImportProvider: Equatable, Sendable {
  case manual
  case deterministicLocal(version: String)
}

public enum RehearsalPlaybackScope: Equatable, Sendable {
  case currentStep
  case fullTimeline
}

public enum LineWiseRehearsalIntent: Equatable, Sendable {
  case selectTrack(RehearsalTrack)
  case selectKeyframe(PoseKeyframeID)
  case selectLimb(Limb)
  case assignHold(
    holdID: HoldID,
    limb: Limb? = nil,
    keyframeID: PoseKeyframeID? = nil
  )
  case clearContact(limb: Limb? = nil, keyframeID: PoseKeyframeID? = nil)
  case setContactLock(
    Bool,
    limb: Limb? = nil,
    keyframeID: PoseKeyframeID? = nil
  )
  case addKeyframe(
    id: PoseKeyframeID,
    label: String,
    after: PoseKeyframeID? = nil
  )
  case duplicateKeyframe(
    PoseKeyframeID,
    as: PoseKeyframeID,
    label: String? = nil
  )
  case deleteKeyframe(PoseKeyframeID)
  case moveKeyframe(PoseKeyframeID, to: Int)
  case recomputeKeyframe(PoseKeyframeID)
  case recomputeDownstream(after: PoseKeyframeID)
  case stepForward
  case stepBackward
  case scrub(transitionIndex: Int, progress: Double)
  case play(scope: RehearsalPlaybackScope, loop: Bool)
  case playPracticeSegment(stepCount: Int, loop: Bool)
  case pause
  case tick(elapsedSeconds: Double)
  case setCurrentMovementIntent(MovementIntent)
  case clearCurrentMovementIntent
  case importRoute(request: RouteReadRequest, provider: RehearsalImportProvider)
  case importTimeline(
    track: RehearsalTrack,
    seedKeyframes: [PoseKeyframe],
    maximumKeyframeCount: Int,
    provider: RehearsalImportProvider
  )
  case copyPlanIntoActualDraft
}

public enum LineWiseRehearsalFailure: Equatable, Sendable {
  case noSelectedKeyframe
  case noSourceKeyframe
  case noCurrentMovementStep
  case holdNotFound(HoldID)
  case keyframeNotFound(PoseKeyframeID)
  case engine(RouteRehearsalError)
  case provider(RehearsalProviderError)
  case actualAttemptRequired
  case actualDraftAlreadyExists
  case unexpected(String)
}

public enum LineWiseRehearsalOutcome: Equatable, Sendable {
  case accepted
  case rejected(LineWiseRehearsalFailure)
}

public struct RehearsalTrackProjection: Equatable, Sendable {
  public let track: RehearsalTrack
  public let keyframeCount: Int
  public let staleKeyframeCount: Int
  public let importProvenance: RehearsalProvenance?

  public init(
    track: RehearsalTrack,
    keyframeCount: Int,
    staleKeyframeCount: Int,
    importProvenance: RehearsalProvenance?
  ) {
    self.track = track
    self.keyframeCount = keyframeCount
    self.staleKeyframeCount = staleKeyframeCount
    self.importProvenance = importProvenance
  }
}

public struct LineWiseRehearsalProjection: Equatable, Sendable {
  public let routeCardID: RouteCardID
  public let rehearsalID: RouteRehearsalID
  public let scene: RouteScene
  public let bodyProfile: BodyProfile
  public let activeTrack: RehearsalTrack
  public let tracks: [RehearsalTrackProjection]
  public let keyframes: [PoseKeyframe]
  public let movementSteps: [MovementStep]
  public let selectedKeyframeID: PoseKeyframeID?
  public let selectedKeyframeIndex: Int?
  public let selectedLimb: Limb
  public let selectedHoldID: HoldID?
  public let selectedContactIsLocked: Bool
  public let avatar: ClimberAvatar?
  public let findings: [ConstraintFinding]
  public let playback: RehearsalPlaybackState
  public let routeReadProvenance: RehearsalProvenance
  public let timelineImportProvenance: RehearsalProvenance?
  public let selectedFrameWasManuallyEdited: Bool
  public let actualAttemptID: AttemptID?
  public let canCreateActualDraft: Bool
  public let focusedComparisonStep: AlignedMovementStep?

  public init(
    routeCardID: RouteCardID,
    rehearsalID: RouteRehearsalID,
    scene: RouteScene,
    bodyProfile: BodyProfile,
    activeTrack: RehearsalTrack,
    tracks: [RehearsalTrackProjection],
    keyframes: [PoseKeyframe],
    movementSteps: [MovementStep],
    selectedKeyframeID: PoseKeyframeID?,
    selectedKeyframeIndex: Int?,
    selectedLimb: Limb,
    selectedHoldID: HoldID?,
    selectedContactIsLocked: Bool,
    avatar: ClimberAvatar?,
    findings: [ConstraintFinding],
    playback: RehearsalPlaybackState,
    routeReadProvenance: RehearsalProvenance,
    timelineImportProvenance: RehearsalProvenance?,
    selectedFrameWasManuallyEdited: Bool,
    actualAttemptID: AttemptID?,
    canCreateActualDraft: Bool,
    focusedComparisonStep: AlignedMovementStep?
  ) {
    self.routeCardID = routeCardID
    self.rehearsalID = rehearsalID
    self.scene = scene
    self.bodyProfile = bodyProfile
    self.activeTrack = activeTrack
    self.tracks = tracks
    self.keyframes = keyframes
    self.movementSteps = movementSteps
    self.selectedKeyframeID = selectedKeyframeID
    self.selectedKeyframeIndex = selectedKeyframeIndex
    self.selectedLimb = selectedLimb
    self.selectedHoldID = selectedHoldID
    self.selectedContactIsLocked = selectedContactIsLocked
    self.avatar = avatar
    self.findings = findings
    self.playback = playback
    self.routeReadProvenance = routeReadProvenance
    self.timelineImportProvenance = timelineImportProvenance
    self.selectedFrameWasManuallyEdited = selectedFrameWasManuallyEdited
    self.actualAttemptID = actualAttemptID
    self.canCreateActualDraft = canCreateActualDraft
    self.focusedComparisonStep = focusedComparisonStep
  }

  public var selectedKeyframe: PoseKeyframe? {
    selectedKeyframeID.flatMap { id in keyframes.first { $0.id == id } }
  }

  public var isPlaying: Bool { playback.isPlaying }

  public var isLooping: Bool {
    switch playback {
    case .paused: false
    case .playingStep(_, let loop), .playingAll(_, let loop),
      .playingSegment(_, _, let loop):
      loop
    }
  }

  public var currentMovementStep: MovementStep? {
    let index = playback.cursor.transitionIndex
    guard movementSteps.indices.contains(index) else { return nil }
    return movementSteps[index]
  }
}

public struct LineWiseRehearsalFeedback: Equatable, Sendable {
  public let outcome: LineWiseRehearsalOutcome
  public let projection: LineWiseRehearsalProjection

  public init(
    outcome: LineWiseRehearsalOutcome,
    projection: LineWiseRehearsalProjection
  ) {
    self.outcome = outcome
    self.projection = projection
  }

  public var isSuccess: Bool {
    if case .accepted = outcome { return true }
    return false
  }
}

public struct LineWiseRehearsalCoordinator: Sendable {
  public let routeCardID: RouteCardID
  public let actualAttemptID: AttemptID?
  public private(set) var engine: RouteRehearsalEngine

  private var selectedKeyframeID: PoseKeyframeID?
  private var selectedLimb: Limb
  private var routeReadProvenance: RehearsalProvenance
  private var timelineImportProvenance: [RehearsalTrack: RehearsalProvenance]
  private var manuallyEditedFrameIDs: Set<PoseKeyframeID>

  public init(
    routeCardID: RouteCardID,
    engine: RouteRehearsalEngine,
    routeReadProvenance: RehearsalProvenance = .manual,
    timelineImportProvenance: [RehearsalTrack: RehearsalProvenance] = [:],
    selectedLimb: Limb = .leftHand,
    actualAttemptID: AttemptID? = nil
  ) {
    self.routeCardID = routeCardID
    self.actualAttemptID = actualAttemptID
    self.engine = engine
    self.routeReadProvenance = routeReadProvenance
    self.timelineImportProvenance = timelineImportProvenance
    self.selectedLimb = selectedLimb
    selectedKeyframeID =
      engine.currentKeyframeID
      ?? engine.rehearsal.plan.keyframes.first?.id
    manuallyEditedFrameIDs = []
  }

  public init(
    routeCardID: RouteCardID,
    rehearsalID: RouteRehearsalID,
    scene: RouteScene,
    bodyProfile: BodyProfile,
    planKeyframes: [PoseKeyframe],
    actualKeyframes: [PoseKeyframe] = [],
    routeReadProvenance: RehearsalProvenance = .manual,
    actualAttemptID: AttemptID? = nil
  ) throws {
    let engine = try RouteRehearsalEngine(
      rehearsalID: rehearsalID,
      scene: scene,
      bodyProfile: bodyProfile,
      planKeyframes: planKeyframes,
      actualKeyframes: actualKeyframes
    )
    self.init(
      routeCardID: routeCardID,
      engine: engine,
      routeReadProvenance: routeReadProvenance,
      timelineImportProvenance: [
        .plan: planKeyframes.first?.provenance ?? .manual
      ],
      actualAttemptID: actualAttemptID
    )
    if let provenance = actualKeyframes.first?.provenance {
      timelineImportProvenance[.actual] = provenance
    }
  }

  public var projection: LineWiseRehearsalProjection {
    let rehearsal = engine.rehearsal
    let track = rehearsal.activeTrack
    let timeline = rehearsal.timeline(for: track)
    let selectedFrame = selectedKeyframeID.flatMap { id in
      timeline.keyframes.first { $0.id == id }
    }
    let contact = selectedFrame?.contact(for: selectedLimb)
    let displayedFrameID = engine.currentKeyframeID ?? selectedKeyframeID
    let displayedFrame = displayedFrameID.flatMap { id in
      timeline.keyframes.first { $0.id == id }
    }

    return LineWiseRehearsalProjection(
      routeCardID: routeCardID,
      rehearsalID: rehearsal.id,
      scene: rehearsal.scene,
      bodyProfile: rehearsal.bodyProfile,
      activeTrack: track,
      tracks: RehearsalTrack.allCases.map { candidate in
        let candidateTimeline = rehearsal.timeline(for: candidate)
        return RehearsalTrackProjection(
          track: candidate,
          keyframeCount: candidateTimeline.keyframes.count,
          staleKeyframeCount: candidateTimeline.keyframes.filter(\.validity.isStale).count,
          importProvenance: timelineImportProvenance[candidate]
        )
      },
      keyframes: timeline.keyframes,
      movementSteps: timeline.steps,
      selectedKeyframeID: selectedKeyframeID,
      selectedKeyframeIndex: selectedKeyframeID.flatMap { id in
        timeline.keyframes.firstIndex { $0.id == id }
      },
      selectedLimb: selectedLimb,
      selectedHoldID: contact?.target.holdID,
      selectedContactIsLocked: contact?.isLocked ?? false,
      avatar: try? engine.currentAvatar(),
      findings: displayedFrame?.findings ?? [],
      playback: engine.playback,
      routeReadProvenance: routeReadProvenance,
      timelineImportProvenance: timelineImportProvenance[track],
      selectedFrameWasManuallyEdited: selectedKeyframeID.map {
        manuallyEditedFrameIDs.contains($0)
      } ?? false,
      actualAttemptID: actualAttemptID,
      canCreateActualDraft: actualAttemptID != nil && rehearsal.actual.keyframes.isEmpty,
      focusedComparisonStep: focusedComparisonStep(
        in: rehearsal,
        track: track,
        stepIndex: engine.playback.cursor.transitionIndex
      )
    )
  }

  public func timelineVersion(for track: RehearsalTrack) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(engine.rehearsal.timeline(for: track)) else {
      return "timeline-v2:\(track.rawValue):unavailable"
    }
    var hash: UInt64 = 1_469_598_103_934_665_603
    for byte in data {
      hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
    return "timeline-v2:\(track.rawValue):\(String(hash, radix: 16))"
  }

  public func makeCurrentStickFigureCue(
    id: StickFigureCueID,
    stepCount: Int
  ) throws -> StickFigureCue {
    guard (1...3).contains(stepCount) else {
      throw RehearsalCompareError.cueStepCountOutOfRange
    }
    let rehearsal = engine.rehearsal
    let track = rehearsal.activeTrack
    let startIndex = engine.playback.cursor.transitionIndex
    let endIndex = startIndex + stepCount - 1
    guard rehearsal.timeline(for: track).steps.indices.contains(endIndex) else {
      throw RehearsalCompareError.alignedRangeOutOfBounds
    }
    let comparison = RehearsalCompare.align(
      rehearsal: rehearsal,
      planTimelineVersion: timelineVersion(for: .plan),
      actualTimelineVersion: timelineVersion(for: .actual)
    )
    let selected = comparison.alignedSteps.filter { aligned in
      let index = track == .plan ? aligned.planStepIndex : aligned.actualStepIndex
      return index.map { startIndex...endIndex ~= $0 } ?? false
    }
    guard selected.count == stepCount,
      let first = selected.first,
      let last = selected.last,
      last.alignmentIndex - first.alignmentIndex + 1 == stepCount
    else {
      throw RehearsalCompareError.cueStepsNotContinuous
    }
    let version = timelineVersion(for: track)
    return try RehearsalCompare.makeStickFigureCue(
      id: id,
      comparison: comparison,
      alignedStepRange: first.alignmentIndex...last.alignmentIndex,
      preferredTrack: track,
      pin: StickFigureCuePin(
        scene: rehearsal.scene,
        bodyProfile: rehearsal.bodyProfile,
        timelineVersion: version
      )
    )
  }

  @discardableResult
  public mutating func handle(
    _ intent: LineWiseRehearsalIntent
  ) -> LineWiseRehearsalFeedback {
    do {
      try apply(intent)
      return LineWiseRehearsalFeedback(outcome: .accepted, projection: projection)
    } catch let error as LineWiseRehearsalOperationError {
      return LineWiseRehearsalFeedback(
        outcome: .rejected(error.failure),
        projection: projection
      )
    } catch let error as RouteRehearsalError {
      return LineWiseRehearsalFeedback(
        outcome: .rejected(.engine(error)),
        projection: projection
      )
    } catch let error as RehearsalProviderError {
      return LineWiseRehearsalFeedback(
        outcome: .rejected(.provider(error)),
        projection: projection
      )
    } catch {
      return LineWiseRehearsalFeedback(
        outcome: .rejected(.unexpected(String(describing: error))),
        projection: projection
      )
    }
  }

  private mutating func apply(_ intent: LineWiseRehearsalIntent) throws {
    switch intent {
    case .selectTrack(let track):
      engine.selectTrack(track)
      selectedKeyframeID = engine.rehearsal.timeline(for: track).keyframes.first?.id

    case .selectKeyframe(let keyframeID):
      try selectKeyframe(keyframeID)

    case .selectLimb(let limb):
      selectedLimb = limb

    case .assignHold(let holdID, let limb, let keyframeID):
      guard engine.rehearsal.scene.hold(id: holdID) != nil else {
        throw LineWiseRehearsalOperationError(.holdNotFound(holdID))
      }
      let targetFrameID = try resolvedKeyframeID(keyframeID)
      let targetLimb = limb ?? selectedLimb
      try engine.setContact(
        limb: targetLimb,
        target: .hold(holdID),
        mode: targetLimb.isHand ? .hand : .foot,
        in: targetFrameID
      )
      recordManualEdit(targetFrameID)

    case .clearContact(let limb, let keyframeID):
      let targetFrameID = try resolvedKeyframeID(keyframeID)
      try engine.setContact(
        limb: limb ?? selectedLimb,
        target: .free,
        in: targetFrameID
      )
      recordManualEdit(targetFrameID)

    case .setContactLock(let isLocked, let limb, let keyframeID):
      let targetFrameID = try resolvedKeyframeID(keyframeID)
      try engine.setContactLock(
        isLocked,
        limb: limb ?? selectedLimb,
        in: targetFrameID
      )
      recordManualEdit(targetFrameID)

    case .addKeyframe(let id, let label, let sourceID):
      try addKeyframe(id: id, label: label, after: sourceID)

    case .duplicateKeyframe(let sourceID, let newID, let label):
      try requireAttemptBeforeCreatingActual()
      try engine.duplicateKeyframe(sourceID, as: newID, label: label)
      selectedKeyframeID = newID
      recordManualEdit(newID)
      try syncPlaybackToSelection()

    case .deleteKeyframe(let keyframeID):
      let oldTimeline = activeTimeline
      let oldIndex = oldTimeline.keyframes.firstIndex { $0.id == keyframeID }
      try engine.deleteKeyframe(keyframeID)
      manuallyEditedFrameIDs.remove(keyframeID)
      let frames = activeTimeline.keyframes
      if frames.isEmpty {
        selectedKeyframeID = nil
      } else {
        selectedKeyframeID = frames[min(oldIndex ?? 0, frames.count - 1)].id
        try syncPlaybackToSelection()
      }

    case .moveKeyframe(let keyframeID, let destinationIndex):
      try engine.moveKeyframe(keyframeID, to: destinationIndex)
      selectedKeyframeID = keyframeID
      recordManualEdit(keyframeID)
      try syncPlaybackToSelection()

    case .recomputeKeyframe(let keyframeID):
      try engine.recomputeKeyframe(keyframeID)

    case .recomputeDownstream(let keyframeID):
      try engine.recomputeDownstream(after: keyframeID)

    case .stepForward:
      try engine.stepForward()
      selectedKeyframeID = engine.currentKeyframeID

    case .stepBackward:
      try engine.stepBackward()
      selectedKeyframeID = engine.currentKeyframeID

    case .scrub(let transitionIndex, let progress):
      try engine.scrub(transitionIndex: transitionIndex, progress: progress)
      selectedKeyframeID = engine.currentKeyframeID

    case .play(let scope, let loop):
      switch scope {
      case .currentStep: try engine.playCurrentStep(loop: loop)
      case .fullTimeline: try engine.playAll(loop: loop)
      }

    case .playPracticeSegment(let stepCount, let loop):
      guard (1...3).contains(stepCount) else {
        throw RouteRehearsalError.practiceSegmentStepCountOutOfRange
      }
      let startIndex = engine.playback.cursor.transitionIndex
      try engine.playSegment(
        startIndex...(startIndex + stepCount - 1),
        loop: loop
      )

    case .pause:
      engine.pause()
      selectedKeyframeID = engine.currentKeyframeID

    case .tick(let elapsedSeconds):
      try engine.advancePlayback(by: elapsedSeconds)
      selectedKeyframeID = engine.currentKeyframeID

    case .setCurrentMovementIntent(let intent):
      guard let step = engine.currentMovementStep else {
        throw LineWiseRehearsalOperationError(.noCurrentMovementStep)
      }
      try engine.setMovementIntent(
        intent,
        from: step.fromKeyframeID,
        to: step.toKeyframeID
      )

    case .clearCurrentMovementIntent:
      guard let step = engine.currentMovementStep else {
        throw LineWiseRehearsalOperationError(.noCurrentMovementStep)
      }
      try engine.clearMovementIntent(
        from: step.fromKeyframeID,
        to: step.toKeyframeID
      )

    case .importRoute(let request, let provider):
      try importRoute(request: request, provider: provider)

    case .importTimeline(let track, let seeds, let maximumCount, let provider):
      try importTimeline(
        track: track,
        seedKeyframes: seeds,
        maximumKeyframeCount: maximumCount,
        provider: provider
      )

    case .copyPlanIntoActualDraft:
      try copyPlanIntoActualDraft()
    }
  }

  private var activeTimeline: RehearsalTimeline {
    engine.rehearsal.timeline(for: engine.rehearsal.activeTrack)
  }

  private func focusedComparisonStep(
    in rehearsal: RouteRehearsal,
    track: RehearsalTrack,
    stepIndex: Int
  ) -> AlignedMovementStep? {
    guard !rehearsal.plan.steps.isEmpty || !rehearsal.actual.steps.isEmpty else {
      return nil
    }
    let comparison = RehearsalCompare.align(
      rehearsal: rehearsal,
      planTimelineVersion: timelineVersion(for: .plan),
      actualTimelineVersion: timelineVersion(for: .actual)
    )
    return comparison.alignedSteps.first { aligned in
      track == .plan ? aligned.planStepIndex == stepIndex : aligned.actualStepIndex == stepIndex
    }
  }

  private mutating func selectKeyframe(_ keyframeID: PoseKeyframeID) throws {
    guard activeTimeline.keyframes.contains(where: { $0.id == keyframeID }) else {
      throw LineWiseRehearsalOperationError(.keyframeNotFound(keyframeID))
    }
    selectedKeyframeID = keyframeID
    try syncPlaybackToSelection()
  }

  private mutating func syncPlaybackToSelection() throws {
    guard
      let selectedKeyframeID,
      let index = activeTimeline.keyframes.firstIndex(where: { $0.id == selectedKeyframeID }),
      activeTimeline.keyframes.count > 1
    else { return }
    if index == activeTimeline.keyframes.count - 1 {
      try engine.scrub(transitionIndex: index - 1, progress: 1)
    } else {
      try engine.scrub(transitionIndex: index, progress: 0)
    }
  }

  private func resolvedKeyframeID(_ requested: PoseKeyframeID?) throws -> PoseKeyframeID {
    guard let result = requested ?? selectedKeyframeID else {
      throw LineWiseRehearsalOperationError(.noSelectedKeyframe)
    }
    guard activeTimeline.keyframes.contains(where: { $0.id == result }) else {
      throw LineWiseRehearsalOperationError(.keyframeNotFound(result))
    }
    return result
  }

  private mutating func addKeyframe(
    id: PoseKeyframeID,
    label: String,
    after requestedSourceID: PoseKeyframeID?
  ) throws {
    try requireAttemptBeforeCreatingActual()
    let activeTrack = engine.rehearsal.activeTrack
    if activeTimeline.keyframes.isEmpty {
      guard let source = engine.rehearsal.plan.keyframes.first else {
        throw LineWiseRehearsalOperationError(.noSourceKeyframe)
      }
      let frame = manualCopy(source, id: id, label: label)
      try engine.replaceTimeline(for: activeTrack, with: [frame])
    } else {
      guard
        let sourceID = requestedSourceID ?? selectedKeyframeID,
        let source = activeTimeline.keyframes.first(where: { $0.id == sourceID })
      else {
        throw LineWiseRehearsalOperationError(.noSourceKeyframe)
      }
      try engine.addKeyframe(
        manualCopy(source, id: id, label: label),
        after: sourceID
      )
    }
    selectedKeyframeID = id
    timelineImportProvenance[activeTrack] = .manual
    recordManualEdit(id)
    try syncPlaybackToSelection()
  }

  private func manualCopy(
    _ source: PoseKeyframe,
    id: PoseKeyframeID,
    label: String
  ) -> PoseKeyframe {
    PoseKeyframe(
      id: id,
      label: label,
      torsoPosition: source.torsoPosition,
      contacts: source.contacts,
      provenance: .manual
    )
  }

  private mutating func importRoute(
    request: RouteReadRequest,
    provider: RehearsalImportProvider
  ) throws {
    let result: RouteReadResult
    switch provider {
    case .manual:
      result = try ManualRouteReadProvider().readLocally(request)
    case .deterministicLocal(let version):
      result = try DeterministicLocalRouteReadProvider(
        algorithmVersion: version
      ).readLocally(request)
    }

    engine.replaceScene(result.scene)
    routeReadProvenance = result.provenance
    normalizeSelection()
    try syncPlaybackToSelection()
  }

  private mutating func importTimeline(
    track: RehearsalTrack,
    seedKeyframes: [PoseKeyframe],
    maximumKeyframeCount: Int,
    provider: RehearsalImportProvider
  ) throws {
    if track == .actual, actualAttemptID == nil {
      throw LineWiseRehearsalOperationError(.actualAttemptRequired)
    }
    let rehearsal = engine.rehearsal
    let request = RehearsalSuggestionRequest(
      rehearsalID: rehearsal.id,
      scene: rehearsal.scene,
      bodyProfile: rehearsal.bodyProfile,
      seedKeyframes: seedKeyframes,
      maximumKeyframeCount: maximumKeyframeCount
    )
    let suggestion: RehearsalSuggestion
    switch provider {
    case .manual:
      suggestion = try ManualRehearsalSuggestionProvider().suggestLocally(request)
    case .deterministicLocal(let version):
      suggestion = try DeterministicLocalRehearsalSuggestionProvider(
        algorithmVersion: version
      ).suggestLocally(request)
    }

    let uniqueFrames = uniqueKeyframes(suggestion.keyframes, replacing: track)
    try engine.replaceTimeline(for: track, with: uniqueFrames)
    engine.selectTrack(track)
    timelineImportProvenance[track] = suggestion.provenance
    manuallyEditedFrameIDs.subtract(uniqueFrames.map(\.id))
    selectedKeyframeID = uniqueFrames.first?.id
  }

  private mutating func copyPlanIntoActualDraft() throws {
    guard actualAttemptID != nil else {
      throw LineWiseRehearsalOperationError(.actualAttemptRequired)
    }
    guard engine.rehearsal.actual.keyframes.isEmpty else {
      throw LineWiseRehearsalOperationError(.actualDraftAlreadyExists)
    }
    let copies = engine.rehearsal.plan.keyframes.enumerated().map { index, source in
      manualCopy(
        source,
        id: PoseKeyframeID("\(engine.rehearsal.id.rawValue)/actual-draft-\(index + 1)"),
        label: "\(source.label) · Actual draft"
      )
    }
    try engine.replaceTimeline(for: .actual, with: copies)
    engine.selectTrack(.actual)
    timelineImportProvenance[.actual] = .manual
    manuallyEditedFrameIDs.formUnion(copies.map(\.id))
    selectedKeyframeID = copies.first?.id
    try syncPlaybackToSelection()
  }

  private func requireAttemptBeforeCreatingActual() throws {
    if engine.rehearsal.activeTrack == .actual, actualAttemptID == nil {
      throw LineWiseRehearsalOperationError(.actualAttemptRequired)
    }
  }

  private func uniqueKeyframes(
    _ frames: [PoseKeyframe],
    replacing track: RehearsalTrack
  ) -> [PoseKeyframe] {
    let otherTrack: RehearsalTrack = track == .plan ? .actual : .plan
    var used = Set(engine.rehearsal.timeline(for: otherTrack).keyframes.map(\.id))
    return frames.enumerated().map { index, frame in
      var candidate = frame.id
      var suffix = 0
      while used.contains(candidate) {
        suffix += 1
        candidate = PoseKeyframeID("\(frame.id.rawValue)-\(track.rawValue)-\(suffix)")
      }
      used.insert(candidate)
      guard candidate != frame.id else { return frame }
      return PoseKeyframe(
        id: candidate,
        label: frame.label.isEmpty ? "Frame \(index + 1)" : frame.label,
        torsoPosition: frame.torsoPosition,
        contacts: frame.contacts,
        provenance: frame.provenance
      )
    }
  }

  private mutating func normalizeSelection() {
    let frames = activeTimeline.keyframes
    if let selectedKeyframeID, frames.contains(where: { $0.id == selectedKeyframeID }) {
      return
    }
    selectedKeyframeID = frames.first?.id
  }

  private mutating func recordManualEdit(_ keyframeID: PoseKeyframeID) {
    manuallyEditedFrameIDs.insert(keyframeID)
  }
}

private struct LineWiseRehearsalOperationError: Error {
  let failure: LineWiseRehearsalFailure

  init(_ failure: LineWiseRehearsalFailure) {
    self.failure = failure
  }
}
