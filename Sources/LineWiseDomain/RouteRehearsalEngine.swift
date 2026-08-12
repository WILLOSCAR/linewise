public enum RehearsalAuthorship: String, Hashable, Codable, Sendable {
  case userAuthored
  case observed
  case suggested
}

public enum RehearsalAutomation: String, Hashable, Codable, Sendable {
  case manual
  case deterministicLocal
  case modelAdapter
}

public struct RehearsalProvenance: Hashable, Codable, Sendable {
  public let authorship: RehearsalAuthorship
  public let automation: RehearsalAutomation
  public let providerIdentifier: String
  public let version: String

  public init(
    authorship: RehearsalAuthorship,
    automation: RehearsalAutomation,
    providerIdentifier: String,
    version: String
  ) {
    self.authorship = authorship
    self.automation = automation
    self.providerIdentifier = providerIdentifier
    self.version = version
  }

  public static let manual = RehearsalProvenance(
    authorship: .userAuthored,
    automation: .manual,
    providerIdentifier: "manual",
    version: "1"
  )

  public var isSuggested: Bool { authorship == .suggested }

  public var isAIGenerated: Bool { automation == .modelAdapter }

  public var displayLabel: String {
    switch authorship {
    case .userAuthored: "User authored"
    case .observed: "Observed"
    case .suggested:
      automation == .deterministicLocal
        ? "Suggested · deterministic local" : "Suggested"
    }
  }
}

public struct StalePoseReason: Hashable, Codable, Sendable {
  public let upstreamKeyframeID: PoseKeyframeID?
  public let message: String

  public init(upstreamKeyframeID: PoseKeyframeID?, message: String) {
    self.upstreamKeyframeID = upstreamKeyframeID
    self.message = message
  }
}

public enum PoseValidity: Hashable, Codable, Sendable {
  case current
  case stale(StalePoseReason)

  public var isStale: Bool {
    if case .stale = self { return true }
    return false
  }
}

public struct PoseKeyframe: Equatable, Codable, Sendable {
  public let id: PoseKeyframeID
  public let label: String
  public let torsoPosition: Point2D
  public let contacts: [LimbContact]
  public let avatar: ClimberAvatar?
  public let confidence: SolverConfidence
  public let findings: [ConstraintFinding]
  public let validity: PoseValidity
  public let provenance: RehearsalProvenance

  public init(
    id: PoseKeyframeID,
    label: String,
    torsoPosition: Point2D,
    contacts: [LimbContact],
    avatar: ClimberAvatar? = nil,
    confidence: SolverConfidence = .low,
    findings: [ConstraintFinding] = [],
    validity: PoseValidity = .current,
    provenance: RehearsalProvenance
  ) {
    self.id = id
    self.label = label
    self.torsoPosition = torsoPosition
    self.contacts = Self.normalized(contacts)
    self.avatar = avatar
    self.confidence = confidence
    self.findings = findings
    self.validity = validity
    self.provenance = provenance
  }

  public func contact(for limb: Limb) -> LimbContact? {
    contacts.first { $0.limb == limb }
  }

  private static func normalized(_ contacts: [LimbContact]) -> [LimbContact] {
    let byLimb = contacts.reduce(into: [Limb: LimbContact]()) { result, contact in
      result[contact.limb] = contact
    }
    return Limb.allCases.map { byLimb[$0] ?? .unknown($0) }
  }

  fileprivate func replacing(
    torsoPosition: Point2D? = nil,
    contacts: [LimbContact]? = nil,
    avatar: ClimberAvatar? = nil,
    confidence: SolverConfidence? = nil,
    findings: [ConstraintFinding]? = nil,
    validity: PoseValidity? = nil,
    provenance: RehearsalProvenance? = nil,
    id: PoseKeyframeID? = nil,
    label: String? = nil
  ) -> PoseKeyframe {
    PoseKeyframe(
      id: id ?? self.id,
      label: label ?? self.label,
      torsoPosition: torsoPosition ?? self.torsoPosition,
      contacts: contacts ?? self.contacts,
      avatar: avatar ?? self.avatar,
      confidence: confidence ?? self.confidence,
      findings: findings ?? self.findings,
      validity: validity ?? self.validity,
      provenance: provenance ?? self.provenance
    )
  }
}

public struct ContactChange: Hashable, Codable, Sendable {
  public let limb: Limb
  public let from: ContactTarget
  public let to: ContactTarget

  public init(limb: Limb, from: ContactTarget, to: ContactTarget) {
    self.limb = limb
    self.from = from
    self.to = to
  }
}

public enum MovementFamily: String, CaseIterable, Hashable, Codable, Sendable {
  case staticMove
  case coordinated
  case dynamic
  case observed
}

public enum MovementPurpose: String, CaseIterable, Hashable, Codable, Sendable {
  case setup
  case progress
  case reposition
  case stabilize
  case commit
  case finish
  case investigate
}

public enum MovementIntentValidity: String, Hashable, Codable, Sendable {
  case current
  case needsReview
}

/// What the climber intends to try in one MovementStep. This remains a
/// rehearsal instruction, not a feasibility, safety, or setter-intent claim.
public struct MovementIntent: Equatable, Codable, Sendable {
  public let purpose: MovementPurpose
  public let family: MovementFamily
  public let expectedDurationSeconds: Double
  public let cue: String
  public let uncertainty: String?
  public let provenance: RehearsalProvenance
  public let validity: MovementIntentValidity

  public init(
    purpose: MovementPurpose,
    family: MovementFamily,
    expectedDurationSeconds: Double,
    cue: String,
    uncertainty: String? = nil,
    provenance: RehearsalProvenance,
    validity: MovementIntentValidity = .current
  ) {
    self.purpose = purpose
    self.family = family
    self.expectedDurationSeconds = max(expectedDurationSeconds, 0.05)
    self.cue = cue
    self.uncertainty = uncertainty
    self.provenance = provenance
    self.validity = validity
  }

  func markingNeedsReview() -> MovementIntent {
    MovementIntent(
      purpose: purpose,
      family: family,
      expectedDurationSeconds: expectedDurationSeconds,
      cue: cue,
      uncertainty: uncertainty,
      provenance: provenance,
      validity: .needsReview
    )
  }
}

public struct MovementStep: Equatable, Codable, Sendable {
  public let fromKeyframeID: PoseKeyframeID
  public let toKeyframeID: PoseKeyframeID
  public let changes: [ContactChange]
  public let retainedLimbs: [Limb]
  public let gainedLimbs: [Limb]
  public let releasedLimbs: [Limb]
  public let expectedDurationSeconds: Double
  public let family: MovementFamily
  public let explanation: String
  public let provenance: RehearsalProvenance
  public let intent: MovementIntent?

  public init(
    fromKeyframeID: PoseKeyframeID,
    toKeyframeID: PoseKeyframeID,
    changes: [ContactChange],
    retainedLimbs: [Limb],
    gainedLimbs: [Limb],
    releasedLimbs: [Limb],
    expectedDurationSeconds: Double,
    family: MovementFamily,
    explanation: String,
    provenance: RehearsalProvenance,
    intent: MovementIntent? = nil
  ) {
    self.fromKeyframeID = fromKeyframeID
    self.toKeyframeID = toKeyframeID
    self.changes = changes
    self.retainedLimbs = retainedLimbs
    self.gainedLimbs = gainedLimbs
    self.releasedLimbs = releasedLimbs
    self.expectedDurationSeconds = max(expectedDurationSeconds, 0.05)
    self.family = family
    self.explanation = explanation
    self.provenance = provenance
    self.intent = intent
  }

  public var effectiveDurationSeconds: Double {
    intent?.expectedDurationSeconds ?? expectedDurationSeconds
  }

  public var effectiveFamily: MovementFamily {
    intent?.family ?? family
  }

  func replacingIntent(_ intent: MovementIntent?) -> MovementStep {
    MovementStep(
      fromKeyframeID: fromKeyframeID,
      toKeyframeID: toKeyframeID,
      changes: changes,
      retainedLimbs: retainedLimbs,
      gainedLimbs: gainedLimbs,
      releasedLimbs: releasedLimbs,
      expectedDurationSeconds: expectedDurationSeconds,
      family: family,
      explanation: explanation,
      provenance: provenance,
      intent: intent
    )
  }
}

public enum RehearsalTrack: String, CaseIterable, Hashable, Codable, Sendable {
  case plan
  case actual
}

public struct RehearsalTimeline: Equatable, Codable, Sendable {
  public let keyframes: [PoseKeyframe]
  public let steps: [MovementStep]

  public init(keyframes: [PoseKeyframe], steps: [MovementStep] = []) {
    self.keyframes = keyframes
    self.steps = steps
  }
}

public struct RouteRehearsal: Equatable, Codable, Sendable {
  public let id: RouteRehearsalID
  public let scene: RouteScene
  public let bodyProfile: BodyProfile
  public let plan: RehearsalTimeline
  public let actual: RehearsalTimeline
  public let activeTrack: RehearsalTrack

  public init(
    id: RouteRehearsalID,
    scene: RouteScene,
    bodyProfile: BodyProfile,
    plan: RehearsalTimeline,
    actual: RehearsalTimeline = RehearsalTimeline(keyframes: []),
    activeTrack: RehearsalTrack = .plan
  ) {
    self.id = id
    self.scene = scene
    self.bodyProfile = bodyProfile
    self.plan = plan
    self.actual = actual
    self.activeTrack = activeTrack
  }

  public func timeline(for track: RehearsalTrack) -> RehearsalTimeline {
    track == .plan ? plan : actual
  }

  fileprivate func replacing(
    timeline: RehearsalTimeline,
    for track: RehearsalTrack
  ) -> RouteRehearsal {
    RouteRehearsal(
      id: id,
      scene: scene,
      bodyProfile: bodyProfile,
      plan: track == .plan ? timeline : plan,
      actual: track == .actual ? timeline : actual,
      activeTrack: activeTrack
    )
  }

  fileprivate func selecting(_ track: RehearsalTrack) -> RouteRehearsal {
    RouteRehearsal(
      id: id,
      scene: scene,
      bodyProfile: bodyProfile,
      plan: plan,
      actual: actual,
      activeTrack: track
    )
  }
}

public enum RouteRehearsalError: Error, Equatable, Sendable {
  case emptyPlan
  case duplicateKeyframeID(PoseKeyframeID)
  case keyframeNotFound(PoseKeyframeID)
  case lockedContact(Limb, PoseKeyframeID)
  case cannotDeleteLastKeyframe
  case invalidDestinationIndex(Int)
  case transitionNotAvailable(Int)
  case unsolvedKeyframe(PoseKeyframeID)
  case movementStepNotFound(from: PoseKeyframeID, to: PoseKeyframeID)
  case practiceSegmentStepCountOutOfRange
}

public struct RouteRehearsalEngine: Sendable {
  public private(set) var rehearsal: RouteRehearsal
  public private(set) var playback: RehearsalPlaybackState
  private let solver: Qualitative2DSolver

  public init(
    rehearsalID: RouteRehearsalID,
    scene: RouteScene,
    bodyProfile: BodyProfile,
    planKeyframes: [PoseKeyframe],
    actualKeyframes: [PoseKeyframe] = [],
    solver: Qualitative2DSolver = Qualitative2DSolver()
  ) throws {
    guard !planKeyframes.isEmpty else { throw RouteRehearsalError.emptyPlan }
    try Self.validateUniqueIDs(planKeyframes + actualKeyframes)
    self.solver = solver
    let plan = Self.solveAll(
      planKeyframes,
      scene: scene,
      bodyProfile: bodyProfile,
      solver: solver
    )
    let actual = Self.solveAll(
      actualKeyframes,
      scene: scene,
      bodyProfile: bodyProfile,
      solver: solver
    )
    rehearsal = RouteRehearsal(
      id: rehearsalID,
      scene: scene,
      bodyProfile: bodyProfile,
      plan: Self.timeline(plan),
      actual: Self.timeline(actual)
    )
    playback = .paused(
      PlaybackCursor(track: .plan, transitionIndex: 0, progress: 0)
    )
  }

  public init(
    reopening rehearsal: RouteRehearsal,
    solver: Qualitative2DSolver = Qualitative2DSolver()
  ) throws {
    guard !rehearsal.plan.keyframes.isEmpty else { throw RouteRehearsalError.emptyPlan }
    try Self.validateUniqueIDs(rehearsal.plan.keyframes + rehearsal.actual.keyframes)
    self.rehearsal = rehearsal
    self.solver = solver
    playback = .paused(
      PlaybackCursor(track: rehearsal.activeTrack, transitionIndex: 0, progress: 0)
    )
  }

  public mutating func selectTrack(_ track: RehearsalTrack) {
    rehearsal = rehearsal.selecting(track)
    playback = .paused(PlaybackCursor(track: track, transitionIndex: 0, progress: 0))
  }

  public mutating func replaceTimeline(
    for track: RehearsalTrack,
    with keyframes: [PoseKeyframe]
  ) throws {
    if track == .plan && keyframes.isEmpty {
      throw RouteRehearsalError.emptyPlan
    }
    let otherFrames = rehearsal.timeline(for: track == .plan ? .actual : .plan).keyframes
    try Self.validateUniqueIDs(keyframes + otherFrames)
    let solved = Self.solveAll(
      keyframes,
      scene: rehearsal.scene,
      bodyProfile: rehearsal.bodyProfile,
      solver: solver
    )
    rehearsal = rehearsal.replacing(
      timeline: Self.timeline(
        solved,
        preserving: rehearsal.timeline(for: track)
      ),
      for: track
    )
    normalizePlayback(afterEditing: track)
  }

  public mutating func replaceScene(_ scene: RouteScene) {
    let previousPlan = rehearsal.plan
    let previousActual = rehearsal.actual
    let solvedPlan = Self.solveAll(
      previousPlan.keyframes,
      scene: scene,
      bodyProfile: rehearsal.bodyProfile,
      solver: solver
    )
    let solvedActual = Self.solveAll(
      previousActual.keyframes,
      scene: scene,
      bodyProfile: rehearsal.bodyProfile,
      solver: solver
    )
    rehearsal = RouteRehearsal(
      id: rehearsal.id,
      scene: scene,
      bodyProfile: rehearsal.bodyProfile,
      plan: Self.timeline(
        solvedPlan,
        preserving: previousPlan,
        requiresIntentReview: true
      ),
      actual: Self.timeline(
        solvedActual,
        preserving: previousActual,
        requiresIntentReview: true
      ),
      activeTrack: rehearsal.activeTrack
    )
    normalizePlayback(afterEditing: rehearsal.activeTrack)
  }

  public mutating func setMovementIntent(
    _ intent: MovementIntent,
    from fromKeyframeID: PoseKeyframeID,
    to toKeyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    let timeline = rehearsal.timeline(for: track)
    guard
      let stepIndex = timeline.steps.firstIndex(where: {
        $0.fromKeyframeID == fromKeyframeID && $0.toKeyframeID == toKeyframeID
      })
    else {
      throw RouteRehearsalError.movementStepNotFound(
        from: fromKeyframeID,
        to: toKeyframeID
      )
    }
    var steps = timeline.steps
    steps[stepIndex] = steps[stepIndex].replacingIntent(
      MovementIntent(
        purpose: intent.purpose,
        family: intent.family,
        expectedDurationSeconds: intent.expectedDurationSeconds,
        cue: intent.cue,
        uncertainty: intent.uncertainty,
        provenance: intent.provenance,
        validity: .current
      )
    )
    rehearsal = rehearsal.replacing(
      timeline: RehearsalTimeline(keyframes: timeline.keyframes, steps: steps),
      for: track
    )
  }

  public mutating func clearMovementIntent(
    from fromKeyframeID: PoseKeyframeID,
    to toKeyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    let timeline = rehearsal.timeline(for: track)
    guard
      let stepIndex = timeline.steps.firstIndex(where: {
        $0.fromKeyframeID == fromKeyframeID && $0.toKeyframeID == toKeyframeID
      })
    else {
      throw RouteRehearsalError.movementStepNotFound(
        from: fromKeyframeID,
        to: toKeyframeID
      )
    }
    var steps = timeline.steps
    steps[stepIndex] = steps[stepIndex].replacingIntent(nil)
    rehearsal = rehearsal.replacing(
      timeline: RehearsalTimeline(keyframes: timeline.keyframes, steps: steps),
      for: track
    )
  }

  public var currentKeyframeID: PoseKeyframeID? {
    let cursor = playback.cursor
    let frames = rehearsal.timeline(for: cursor.track).keyframes
    guard !frames.isEmpty else { return nil }
    let index: Int
    if cursor.progress >= 1 {
      index = min(cursor.transitionIndex + 1, frames.count - 1)
    } else {
      index = min(cursor.transitionIndex, frames.count - 1)
    }
    return frames[index].id
  }

  public var currentMovementStep: MovementStep? {
    let cursor = playback.cursor
    let steps = rehearsal.timeline(for: cursor.track).steps
    guard steps.indices.contains(cursor.transitionIndex) else { return nil }
    return steps[cursor.transitionIndex]
  }

  public mutating func stepForward() throws {
    let cursor = playback.cursor
    let timeline = rehearsal.timeline(for: cursor.track)
    guard !timeline.keyframes.isEmpty else {
      throw RouteRehearsalError.transitionNotAvailable(0)
    }
    let currentIndex = keyframeIndex(for: cursor, frameCount: timeline.keyframes.count)
    playback = .paused(
      cursorForKeyframe(
        min(currentIndex + 1, timeline.keyframes.count - 1),
        track: cursor.track,
        frameCount: timeline.keyframes.count
      ))
  }

  public mutating func stepBackward() throws {
    let cursor = playback.cursor
    let timeline = rehearsal.timeline(for: cursor.track)
    guard !timeline.keyframes.isEmpty else {
      throw RouteRehearsalError.transitionNotAvailable(0)
    }
    let currentIndex = keyframeIndex(for: cursor, frameCount: timeline.keyframes.count)
    playback = .paused(
      cursorForKeyframe(
        max(currentIndex - 1, 0),
        track: cursor.track,
        frameCount: timeline.keyframes.count
      ))
  }

  public mutating func scrub(
    transitionIndex: Int,
    progress: Double
  ) throws {
    let track = playback.cursor.track
    let steps = rehearsal.timeline(for: track).steps
    guard steps.indices.contains(transitionIndex) else {
      throw RouteRehearsalError.transitionNotAvailable(transitionIndex)
    }
    playback = .paused(
      PlaybackCursor(track: track, transitionIndex: transitionIndex, progress: progress)
    )
  }

  public mutating func playCurrentStep(loop: Bool) throws {
    var cursor = playback.cursor
    let steps = rehearsal.timeline(for: cursor.track).steps
    guard steps.indices.contains(cursor.transitionIndex) else {
      throw RouteRehearsalError.transitionNotAvailable(cursor.transitionIndex)
    }
    if cursor.progress >= 1 {
      cursor = PlaybackCursor(
        track: cursor.track,
        transitionIndex: cursor.transitionIndex,
        progress: 0
      )
    }
    playback = .playingStep(cursor, loop: loop)
  }

  public mutating func playAll(loop: Bool) throws {
    var cursor = playback.cursor
    let steps = rehearsal.timeline(for: cursor.track).steps
    guard !steps.isEmpty else { throw RouteRehearsalError.transitionNotAvailable(0) }
    if cursor.transitionIndex >= steps.count - 1 && cursor.progress >= 1 {
      cursor = PlaybackCursor(track: cursor.track, transitionIndex: 0, progress: 0)
    }
    playback = .playingAll(cursor, loop: loop)
  }

  public mutating func playSegment(
    _ stepRange: ClosedRange<Int>,
    loop: Bool
  ) throws {
    let stepCount = stepRange.upperBound - stepRange.lowerBound + 1
    guard (1...3).contains(stepCount) else {
      throw RouteRehearsalError.practiceSegmentStepCountOutOfRange
    }
    let track = playback.cursor.track
    let steps = rehearsal.timeline(for: track).steps
    guard
      stepRange.lowerBound >= 0,
      stepRange.upperBound < steps.count
    else {
      throw RouteRehearsalError.transitionNotAvailable(stepRange.upperBound)
    }
    playback = .playingSegment(
      PlaybackCursor(
        track: track,
        transitionIndex: stepRange.lowerBound,
        progress: 0
      ),
      stepRange: stepRange,
      loop: loop
    )
  }

  public mutating func pause() {
    playback = .paused(playback.cursor)
  }

  public mutating func advancePlayback(by elapsedSeconds: Double) throws {
    let elapsedSeconds = max(elapsedSeconds, 0)
    switch playback {
    case .paused:
      return
    case .playingStep(let cursor, let loop):
      guard let step = step(at: cursor) else {
        throw RouteRehearsalError.transitionNotAvailable(cursor.transitionIndex)
      }
      let totalProgress = cursor.progress + (elapsedSeconds / step.effectiveDurationSeconds)
      if loop {
        let wrapped = totalProgress.truncatingRemainder(dividingBy: 1)
        playback = .playingStep(
          PlaybackCursor(
            track: cursor.track,
            transitionIndex: cursor.transitionIndex,
            progress: wrapped
          ),
          loop: true
        )
      } else if totalProgress >= 1 {
        playback = .paused(
          PlaybackCursor(
            track: cursor.track,
            transitionIndex: cursor.transitionIndex,
            progress: 1
          ))
      } else {
        playback = .playingStep(
          PlaybackCursor(
            track: cursor.track,
            transitionIndex: cursor.transitionIndex,
            progress: totalProgress
          ),
          loop: false
        )
      }
    case .playingAll(let startingCursor, let loop):
      try advanceContinuous(
        from: startingCursor,
        elapsedSeconds: elapsedSeconds,
        loop: loop
      )
    case .playingSegment(let startingCursor, let stepRange, let loop):
      try advanceSegment(
        from: startingCursor,
        stepRange: stepRange,
        elapsedSeconds: elapsedSeconds,
        loop: loop
      )
    }
  }

  public func currentAvatar() throws -> ClimberAvatar {
    let cursor = playback.cursor
    let timeline = rehearsal.timeline(for: cursor.track)
    guard !timeline.keyframes.isEmpty else {
      throw RouteRehearsalError.transitionNotAvailable(0)
    }
    guard !timeline.steps.isEmpty else {
      let frame = timeline.keyframes[0]
      guard let avatar = frame.avatar else {
        throw RouteRehearsalError.unsolvedKeyframe(frame.id)
      }
      return avatar
    }
    guard timeline.steps.indices.contains(cursor.transitionIndex) else {
      throw RouteRehearsalError.transitionNotAvailable(cursor.transitionIndex)
    }
    let from = timeline.keyframes[cursor.transitionIndex]
    let to = timeline.keyframes[cursor.transitionIndex + 1]
    guard let fromAvatar = from.avatar else {
      throw RouteRehearsalError.unsolvedKeyframe(from.id)
    }
    guard let toAvatar = to.avatar else {
      throw RouteRehearsalError.unsolvedKeyframe(to.id)
    }
    let jointKeys = Set(fromAvatar.joints.keys).union(toAvatar.joints.keys)
    let joints = jointKeys.reduce(into: [AvatarJoint: Point2D]()) { result, joint in
      if let start = fromAvatar.joints[joint], let end = toAvatar.joints[joint] {
        result[joint] = start.interpolated(to: end, progress: cursor.progress)
      } else {
        result[joint] = fromAvatar.joints[joint] ?? toAvatar.joints[joint]
      }
    }
    return ClimberAvatar(
      bodyProfileID: rehearsal.bodyProfile.id,
      joints: joints,
      contacts: cursor.progress >= 1 ? to.contacts : from.contacts
    )
  }

  public mutating func setContact(
    limb: Limb,
    target: ContactTarget,
    mode: ContactMode = .unspecified,
    in keyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    var frames = rehearsal.timeline(for: track).keyframes
    guard let index = frames.firstIndex(where: { $0.id == keyframeID }) else {
      throw RouteRehearsalError.keyframeNotFound(keyframeID)
    }
    let frame = frames[index]
    let existing = frame.contact(for: limb) ?? .unknown(limb)
    if existing.isLocked && existing.target != target {
      throw RouteRehearsalError.lockedContact(limb, keyframeID)
    }
    guard existing.target != target || existing.mode != mode else { return }
    let contacts = frame.contacts.map { contact in
      guard contact.limb == limb else { return contact }
      return LimbContact(
        limb: limb,
        target: target,
        mode: mode,
        isLocked: contact.isLocked
      )
    }
    frames[index] = solve(frame.replacing(contacts: contacts))
    markStale(after: index, upstream: keyframeID, in: &frames)
    replace(frames: frames, for: track)
  }

  public mutating func setContactLock(
    _ isLocked: Bool,
    limb: Limb,
    in keyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    var frames = rehearsal.timeline(for: track).keyframes
    guard let index = frames.firstIndex(where: { $0.id == keyframeID }) else {
      throw RouteRehearsalError.keyframeNotFound(keyframeID)
    }
    let frame = frames[index]
    let contacts = frame.contacts.map { contact in
      guard contact.limb == limb else { return contact }
      return LimbContact(
        limb: limb,
        target: contact.target,
        mode: contact.mode,
        isLocked: isLocked
      )
    }
    frames[index] = solve(frame.replacing(contacts: contacts))
    markStale(after: index, upstream: keyframeID, in: &frames)
    replace(frames: frames, for: track)
  }

  public mutating func addKeyframe(
    _ keyframe: PoseKeyframe,
    after sourceKeyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    let allFrames = rehearsal.plan.keyframes + rehearsal.actual.keyframes
    guard !allFrames.contains(where: { $0.id == keyframe.id }) else {
      throw RouteRehearsalError.duplicateKeyframeID(keyframe.id)
    }
    var frames = rehearsal.timeline(for: track).keyframes
    guard let sourceIndex = frames.firstIndex(where: { $0.id == sourceKeyframeID }) else {
      throw RouteRehearsalError.keyframeNotFound(sourceKeyframeID)
    }
    let insertionIndex = sourceIndex + 1
    frames.insert(solve(keyframe), at: insertionIndex)
    markStale(after: insertionIndex, upstream: keyframe.id, in: &frames)
    replace(frames: frames, for: track)
  }

  public mutating func duplicateKeyframe(
    _ sourceKeyframeID: PoseKeyframeID,
    as newKeyframeID: PoseKeyframeID,
    label: String? = nil,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    guard
      let source = rehearsal.timeline(for: track).keyframes.first(where: {
        $0.id == sourceKeyframeID
      })
    else {
      throw RouteRehearsalError.keyframeNotFound(sourceKeyframeID)
    }
    let duplicate = source.replacing(
      validity: .current,
      id: newKeyframeID,
      label: label ?? "\(source.label) copy"
    )
    try addKeyframe(duplicate, after: sourceKeyframeID, track: track)
  }

  public mutating func deleteKeyframe(
    _ keyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    var frames = rehearsal.timeline(for: track).keyframes
    guard let index = frames.firstIndex(where: { $0.id == keyframeID }) else {
      throw RouteRehearsalError.keyframeNotFound(keyframeID)
    }
    guard frames.count > 1 else { throw RouteRehearsalError.cannotDeleteLastKeyframe }
    frames.remove(at: index)
    markStale(
      from: index,
      upstream: keyframeID,
      message: "A preceding keyframe was deleted; recompute this sequence.",
      in: &frames
    )
    replace(frames: frames, for: track)
  }

  public mutating func moveKeyframe(
    _ keyframeID: PoseKeyframeID,
    to destinationIndex: Int,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    var frames = rehearsal.timeline(for: track).keyframes
    guard frames.indices.contains(destinationIndex) else {
      throw RouteRehearsalError.invalidDestinationIndex(destinationIndex)
    }
    guard let sourceIndex = frames.firstIndex(where: { $0.id == keyframeID }) else {
      throw RouteRehearsalError.keyframeNotFound(keyframeID)
    }
    guard sourceIndex != destinationIndex else { return }
    let frame = frames.remove(at: sourceIndex)
    frames.insert(frame, at: destinationIndex)
    markStale(
      from: min(sourceIndex, destinationIndex),
      upstream: keyframeID,
      message: "Keyframe order changed; recompute the affected sequence.",
      in: &frames
    )
    replace(frames: frames, for: track)
  }

  public mutating func recomputeKeyframe(
    _ keyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    var frames = rehearsal.timeline(for: track).keyframes
    guard let index = frames.firstIndex(where: { $0.id == keyframeID }) else {
      throw RouteRehearsalError.keyframeNotFound(keyframeID)
    }
    frames[index] = solve(frames[index])
    replace(frames: frames, for: track)
  }

  public mutating func recomputeDownstream(
    after keyframeID: PoseKeyframeID,
    track: RehearsalTrack? = nil
  ) throws {
    let track = track ?? rehearsal.activeTrack
    var frames = rehearsal.timeline(for: track).keyframes
    guard let index = frames.firstIndex(where: { $0.id == keyframeID }) else {
      throw RouteRehearsalError.keyframeNotFound(keyframeID)
    }
    guard index + 1 < frames.count else { return }
    for downstreamIndex in (index + 1)..<frames.count {
      frames[downstreamIndex] = solve(frames[downstreamIndex])
    }
    replace(frames: frames, for: track)
  }

  private static func validateUniqueIDs(_ frames: [PoseKeyframe]) throws {
    var seen = Set<PoseKeyframeID>()
    for frame in frames where !seen.insert(frame.id).inserted {
      throw RouteRehearsalError.duplicateKeyframeID(frame.id)
    }
  }

  private func keyframeIndex(for cursor: PlaybackCursor, frameCount: Int) -> Int {
    if cursor.progress >= 1 {
      return min(cursor.transitionIndex + 1, frameCount - 1)
    }
    return min(cursor.transitionIndex, frameCount - 1)
  }

  private func cursorForKeyframe(
    _ index: Int,
    track: RehearsalTrack,
    frameCount: Int
  ) -> PlaybackCursor {
    if index >= frameCount - 1 && frameCount > 1 {
      return PlaybackCursor(track: track, transitionIndex: frameCount - 2, progress: 1)
    }
    return PlaybackCursor(track: track, transitionIndex: index, progress: 0)
  }

  private func step(at cursor: PlaybackCursor) -> MovementStep? {
    let steps = rehearsal.timeline(for: cursor.track).steps
    guard steps.indices.contains(cursor.transitionIndex) else { return nil }
    return steps[cursor.transitionIndex]
  }

  private mutating func advanceContinuous(
    from startingCursor: PlaybackCursor,
    elapsedSeconds: Double,
    loop: Bool
  ) throws {
    let steps = rehearsal.timeline(for: startingCursor.track).steps
    guard !steps.isEmpty else {
      throw RouteRehearsalError.transitionNotAvailable(0)
    }
    var cursor = startingCursor
    var remaining = elapsedSeconds
    while remaining > 0 {
      guard steps.indices.contains(cursor.transitionIndex) else {
        throw RouteRehearsalError.transitionNotAvailable(cursor.transitionIndex)
      }
      let step = steps[cursor.transitionIndex]
      let secondsToEnd = (1 - cursor.progress) * step.effectiveDurationSeconds
      if remaining < secondsToEnd {
        cursor = PlaybackCursor(
          track: cursor.track,
          transitionIndex: cursor.transitionIndex,
          progress: cursor.progress + (remaining / step.effectiveDurationSeconds)
        )
        remaining = 0
      } else {
        remaining -= secondsToEnd
        if cursor.transitionIndex + 1 < steps.count {
          cursor = PlaybackCursor(
            track: cursor.track,
            transitionIndex: cursor.transitionIndex + 1,
            progress: 0
          )
        } else if loop {
          cursor = PlaybackCursor(track: cursor.track, transitionIndex: 0, progress: 0)
        } else {
          playback = .paused(
            PlaybackCursor(
              track: cursor.track,
              transitionIndex: steps.count - 1,
              progress: 1
            ))
          return
        }
      }
    }
    playback = .playingAll(cursor, loop: loop)
  }

  private mutating func advanceSegment(
    from startingCursor: PlaybackCursor,
    stepRange: ClosedRange<Int>,
    elapsedSeconds: Double,
    loop: Bool
  ) throws {
    let steps = rehearsal.timeline(for: startingCursor.track).steps
    guard
      stepRange.lowerBound >= 0,
      stepRange.upperBound < steps.count,
      stepRange.contains(startingCursor.transitionIndex)
    else {
      throw RouteRehearsalError.transitionNotAvailable(startingCursor.transitionIndex)
    }
    var cursor = startingCursor
    var remaining = elapsedSeconds
    while remaining > 0 {
      let step = steps[cursor.transitionIndex]
      let secondsToEnd = (1 - cursor.progress) * step.effectiveDurationSeconds
      if remaining < secondsToEnd {
        cursor = PlaybackCursor(
          track: cursor.track,
          transitionIndex: cursor.transitionIndex,
          progress: cursor.progress + (remaining / step.effectiveDurationSeconds)
        )
        remaining = 0
      } else {
        remaining -= secondsToEnd
        if cursor.transitionIndex < stepRange.upperBound {
          cursor = PlaybackCursor(
            track: cursor.track,
            transitionIndex: cursor.transitionIndex + 1,
            progress: 0
          )
        } else if loop {
          cursor = PlaybackCursor(
            track: cursor.track,
            transitionIndex: stepRange.lowerBound,
            progress: 0
          )
        } else {
          playback = .paused(
            PlaybackCursor(
              track: cursor.track,
              transitionIndex: stepRange.upperBound,
              progress: 1
            )
          )
          return
        }
      }
    }
    playback = .playingSegment(cursor, stepRange: stepRange, loop: loop)
  }

  private static func solveAll(
    _ frames: [PoseKeyframe],
    scene: RouteScene,
    bodyProfile: BodyProfile,
    solver: Qualitative2DSolver
  ) -> [PoseKeyframe] {
    frames.map { frame in
      let result = solver.solve(
        scene: scene,
        bodyProfile: bodyProfile,
        torsoPosition: frame.torsoPosition,
        contacts: frame.contacts
      )
      return frame.replacing(
        avatar: result.avatar,
        confidence: result.confidence,
        findings: result.findings,
        validity: .current
      )
    }
  }

  private func solve(_ frame: PoseKeyframe) -> PoseKeyframe {
    let result = solver.solve(
      scene: rehearsal.scene,
      bodyProfile: rehearsal.bodyProfile,
      torsoPosition: frame.torsoPosition,
      contacts: frame.contacts
    )
    return frame.replacing(
      avatar: result.avatar,
      confidence: result.confidence,
      findings: result.findings,
      validity: .current
    )
  }

  private func markStale(
    after index: Int,
    upstream: PoseKeyframeID?,
    in frames: inout [PoseKeyframe]
  ) {
    guard index + 1 < frames.count else { return }
    for downstreamIndex in (index + 1)..<frames.count {
      frames[downstreamIndex] = stale(
        frames[downstreamIndex],
        upstream: upstream,
        message: "An upstream keyframe changed; recompute this pose before relying on it."
      )
    }
  }

  private func markStale(
    from index: Int,
    upstream: PoseKeyframeID?,
    message: String,
    in frames: inout [PoseKeyframe]
  ) {
    guard index < frames.count else { return }
    for staleIndex in max(index, 0)..<frames.count {
      frames[staleIndex] = stale(
        frames[staleIndex],
        upstream: upstream,
        message: message
      )
    }
  }

  private func stale(
    _ frame: PoseKeyframe,
    upstream: PoseKeyframeID?,
    message: String
  ) -> PoseKeyframe {
    let finding = ConstraintFinding(
      kind: .downstreamInvalidated,
      severity: .unresolved,
      message: message
    )
    return frame.replacing(
      findings: frame.findings.filter { $0.kind != .downstreamInvalidated } + [finding],
      validity: .stale(StalePoseReason(upstreamKeyframeID: upstream, message: message))
    )
  }

  private mutating func replace(frames: [PoseKeyframe], for track: RehearsalTrack) {
    rehearsal = rehearsal.replacing(
      timeline: Self.timeline(
        frames,
        preserving: rehearsal.timeline(for: track)
      ),
      for: track
    )
    normalizePlayback(afterEditing: track)
  }

  private mutating func normalizePlayback(afterEditing track: RehearsalTrack) {
    let cursor = playback.cursor
    guard cursor.track == track else { return }
    let steps = rehearsal.timeline(for: track).steps
    guard !steps.isEmpty else {
      playback = .paused(PlaybackCursor(track: track, transitionIndex: 0, progress: 0))
      return
    }
    playback = .paused(
      PlaybackCursor(
        track: track,
        transitionIndex: min(cursor.transitionIndex, steps.count - 1),
        progress: cursor.progress
      ))
  }

  private static func timeline(
    _ frames: [PoseKeyframe],
    preserving previousTimeline: RehearsalTimeline? = nil,
    requiresIntentReview: Bool = false
  ) -> RehearsalTimeline {
    RehearsalTimeline(
      keyframes: frames,
      steps: movementSteps(
        for: frames,
        preserving: previousTimeline,
        requiresIntentReview: requiresIntentReview
      )
    )
  }

  private static func movementSteps(
    for frames: [PoseKeyframe],
    preserving previousTimeline: RehearsalTimeline?,
    requiresIntentReview: Bool
  ) -> [MovementStep] {
    guard frames.count > 1 else { return [] }
    let previousFrames =
      previousTimeline.map {
        Dictionary(uniqueKeysWithValues: $0.keyframes.map { ($0.id, $0) })
      } ?? [:]
    let previousSteps =
      previousTimeline.map {
        Dictionary(
          uniqueKeysWithValues: $0.steps.map {
            (MovementStepKey(from: $0.fromKeyframeID, to: $0.toKeyframeID), $0)
          }
        )
      } ?? [:]
    return zip(frames, frames.dropFirst()).map { from, to in
      let changes = Limb.allCases.compactMap { limb -> ContactChange? in
        let oldTarget = from.contact(for: limb)?.target ?? .unknown
        let newTarget = to.contact(for: limb)?.target ?? .unknown
        guard oldTarget != newTarget else { return nil }
        return ContactChange(limb: limb, from: oldTarget, to: newTarget)
      }
      let retained = Limb.allCases.filter { limb in
        let oldTarget = from.contact(for: limb)?.target ?? .unknown
        return oldTarget == (to.contact(for: limb)?.target ?? .unknown)
          && oldTarget.isSupportContact
      }
      let gained = changes.filter(\.to.isSupportContact).map(\.limb)
      let released = changes.filter(\.from.isSupportContact).map(\.limb)
      let family: MovementFamily = changes.count > 1 ? .coordinated : .staticMove
      let explanation =
        changes.isEmpty
        ? "No contact changes."
        : changes.map { "\($0.limb.label): \($0.from.shortLabel) → \($0.to.shortLabel)" }
          .joined(separator: "; ")
      let generated = MovementStep(
        fromKeyframeID: from.id,
        toKeyframeID: to.id,
        changes: changes,
        retainedLimbs: retained,
        gainedLimbs: gained,
        releasedLimbs: released,
        expectedDurationSeconds: 1,
        family: family,
        explanation: explanation,
        provenance: to.provenance
      )
      let key = MovementStepKey(from: from.id, to: to.id)
      guard let previousIntent = previousSteps[key]?.intent else { return generated }
      let contactOrTorsoChanged =
        previousFrames[from.id]?.contacts != from.contacts
        || previousFrames[to.id]?.contacts != to.contacts
        || previousFrames[from.id]?.torsoPosition != from.torsoPosition
        || previousFrames[to.id]?.torsoPosition != to.torsoPosition
      return generated.replacingIntent(
        contactOrTorsoChanged || requiresIntentReview
          ? previousIntent.markingNeedsReview() : previousIntent
      )
    }
  }
}

private struct MovementStepKey: Hashable {
  let from: PoseKeyframeID
  let to: PoseKeyframeID
}

extension ContactTarget {
  fileprivate var shortLabel: String {
    switch self {
    case .hold(let id): "hold \(id.rawValue)"
    case .wallRegion(let name, _): "wall \(name)"
    case .ground: "ground"
    case .free: "free"
    case .unknown: "unknown"
    }
  }
}

// Playback types are declared with the editor so persisted sessions can keep a
// stable cursor shape even when the UI and animation adapter live elsewhere.
public struct PlaybackCursor: Equatable, Codable, Sendable {
  public let track: RehearsalTrack
  public let transitionIndex: Int
  public let progress: Double

  public init(track: RehearsalTrack, transitionIndex: Int, progress: Double) {
    self.track = track
    self.transitionIndex = max(transitionIndex, 0)
    self.progress = min(max(progress, 0), 1)
  }
}

public enum RehearsalPlaybackState: Equatable, Codable, Sendable {
  case paused(PlaybackCursor)
  case playingStep(PlaybackCursor, loop: Bool)
  case playingAll(PlaybackCursor, loop: Bool)
  case playingSegment(
    PlaybackCursor,
    stepRange: ClosedRange<Int>,
    loop: Bool
  )

  public var cursor: PlaybackCursor {
    switch self {
    case .paused(let cursor), .playingStep(let cursor, _), .playingAll(let cursor, _),
      .playingSegment(let cursor, _, _):
      cursor
    }
  }

  public var isPlaying: Bool {
    if case .paused = self { return false }
    return true
  }
}
