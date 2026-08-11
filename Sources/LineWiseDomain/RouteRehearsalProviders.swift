public struct RouteReadRequest: Equatable, Codable, Sendable {
  public let sceneID: RouteSceneID
  public let name: String
  public let size: SceneSize
  public let metersPerSceneUnit: Double?
  public let candidateHolds: [Hold]

  public init(
    sceneID: RouteSceneID,
    name: String,
    size: SceneSize,
    metersPerSceneUnit: Double?,
    candidateHolds: [Hold]
  ) {
    self.sceneID = sceneID
    self.name = name
    self.size = size
    self.metersPerSceneUnit = metersPerSceneUnit
    self.candidateHolds = candidateHolds
  }
}

public struct RouteReadResult: Equatable, Codable, Sendable {
  public let scene: RouteScene
  public let provenance: RehearsalProvenance

  public init(scene: RouteScene, provenance: RehearsalProvenance) {
    self.scene = scene
    self.provenance = provenance
  }
}

public protocol RouteReadProvider: Sendable {
  var identifier: String { get }
  func read(_ request: RouteReadRequest) async throws -> RouteReadResult
}

public struct ManualRouteReadProvider: RouteReadProvider {
  public let identifier = "manual-route-read"

  public init() {}

  public func read(_ request: RouteReadRequest) async throws -> RouteReadResult {
    try readLocally(request)
  }

  public func readLocally(_ request: RouteReadRequest) throws -> RouteReadResult {
    RouteReadResult(
      scene: RouteScene(
        id: request.sceneID,
        name: request.name,
        size: request.size,
        metersPerSceneUnit: request.metersPerSceneUnit,
        holds: request.candidateHolds
      ),
      provenance: .manual
    )
  }
}

public struct DeterministicLocalRouteReadProvider: RouteReadProvider {
  public let identifier = "deterministic-local-route-read"
  public let algorithmVersion: String

  public init(algorithmVersion: String = "x0") {
    self.algorithmVersion = algorithmVersion
  }

  public func read(_ request: RouteReadRequest) async throws -> RouteReadResult {
    try readLocally(request)
  }

  public func readLocally(_ request: RouteReadRequest) throws -> RouteReadResult {
    let orderedHolds = request.candidateHolds.sorted(by: Self.holdOrder)
    return RouteReadResult(
      scene: RouteScene(
        id: request.sceneID,
        name: request.name,
        size: request.size,
        metersPerSceneUnit: request.metersPerSceneUnit,
        holds: orderedHolds
      ),
      provenance: RehearsalProvenance(
        authorship: .suggested,
        automation: .deterministicLocal,
        providerIdentifier: identifier,
        version: algorithmVersion
      )
    )
  }

  fileprivate static func holdOrder(_ lhs: Hold, _ rhs: Hold) -> Bool {
    if lhs.center.y != rhs.center.y { return lhs.center.y < rhs.center.y }
    if lhs.center.x != rhs.center.x { return lhs.center.x < rhs.center.x }
    return lhs.id.rawValue < rhs.id.rawValue
  }
}

public struct RehearsalSuggestionRequest: Equatable, Codable, Sendable {
  public let rehearsalID: RouteRehearsalID
  public let scene: RouteScene
  public let bodyProfile: BodyProfile
  public let seedKeyframes: [PoseKeyframe]
  public let maximumKeyframeCount: Int

  public init(
    rehearsalID: RouteRehearsalID,
    scene: RouteScene,
    bodyProfile: BodyProfile,
    seedKeyframes: [PoseKeyframe],
    maximumKeyframeCount: Int
  ) {
    self.rehearsalID = rehearsalID
    self.scene = scene
    self.bodyProfile = bodyProfile
    self.seedKeyframes = seedKeyframes
    self.maximumKeyframeCount = max(maximumKeyframeCount, 1)
  }
}

public struct RehearsalSuggestion: Equatable, Codable, Sendable {
  public let rehearsalID: RouteRehearsalID
  public let keyframes: [PoseKeyframe]
  public let provenance: RehearsalProvenance

  public init(
    rehearsalID: RouteRehearsalID,
    keyframes: [PoseKeyframe],
    provenance: RehearsalProvenance
  ) {
    self.rehearsalID = rehearsalID
    self.keyframes = keyframes
    self.provenance = provenance
  }
}

public protocol RehearsalSuggestionProvider: Sendable {
  var identifier: String { get }
  func suggest(_ request: RehearsalSuggestionRequest) async throws -> RehearsalSuggestion
}

public enum RehearsalProviderError: Error, Equatable, Sendable {
  case manualSeedRequired
  case routeHoldsRequired
}

public struct ManualRehearsalSuggestionProvider: RehearsalSuggestionProvider {
  public let identifier = "manual-rehearsal"

  public init() {}

  public func suggest(
    _ request: RehearsalSuggestionRequest
  ) async throws -> RehearsalSuggestion {
    try suggestLocally(request)
  }

  public func suggestLocally(
    _ request: RehearsalSuggestionRequest
  ) throws -> RehearsalSuggestion {
    guard !request.seedKeyframes.isEmpty else {
      throw RehearsalProviderError.manualSeedRequired
    }
    let manualFrames = request.seedKeyframes.map { frame in
      PoseKeyframe(
        id: frame.id,
        label: frame.label,
        torsoPosition: frame.torsoPosition,
        contacts: frame.contacts,
        provenance: .manual
      )
    }
    let engine = try RouteRehearsalEngine(
      rehearsalID: request.rehearsalID,
      scene: request.scene,
      bodyProfile: request.bodyProfile,
      planKeyframes: Array(manualFrames.prefix(request.maximumKeyframeCount))
    )
    return RehearsalSuggestion(
      rehearsalID: request.rehearsalID,
      keyframes: engine.rehearsal.plan.keyframes,
      provenance: .manual
    )
  }
}

public struct DeterministicLocalRehearsalSuggestionProvider: RehearsalSuggestionProvider {
  public let identifier = "deterministic-local-rehearsal"
  public let algorithmVersion: String

  public init(algorithmVersion: String = "x0") {
    self.algorithmVersion = algorithmVersion
  }

  public func suggest(
    _ request: RehearsalSuggestionRequest
  ) async throws -> RehearsalSuggestion {
    try suggestLocally(request)
  }

  public func suggestLocally(
    _ request: RehearsalSuggestionRequest
  ) throws -> RehearsalSuggestion {
    guard !request.scene.holds.isEmpty else {
      throw RehearsalProviderError.routeHoldsRequired
    }
    let provenance = RehearsalProvenance(
      authorship: .suggested,
      automation: .deterministicLocal,
      providerIdentifier: identifier,
      version: algorithmVersion
    )
    let orderedHolds = request.scene.holds.sorted(
      by: DeterministicLocalRouteReadProvider.holdOrder
    )
    var frames =
      request.seedKeyframes.isEmpty
      ? [defaultSeed(for: request, orderedHolds: orderedHolds, provenance: provenance)]
      : request.seedKeyframes.map { suggestedCopy($0, provenance: provenance) }
    frames = Array(frames.prefix(request.maximumKeyframeCount))

    let limbOrder: [Limb] = [.rightHand, .leftHand, .rightFoot, .leftFoot]
    while frames.count < request.maximumKeyframeCount {
      let prior = frames[frames.count - 1]
      let limb = limbOrder[(frames.count - 1) % limbOrder.count]
      let occupied = Set(
        prior.contacts.compactMap { contact -> HoldID? in
          guard contact.limb != limb else { return nil }
          return contact.target.holdID
        })
      let candidates = orderedHolds.filter { !occupied.contains($0.id) }
      let pool = candidates.isEmpty ? orderedHolds : candidates
      let currentTarget = prior.contact(for: limb)?.target.holdID
      let different = pool.filter { $0.id != currentTarget }
      let selectedPool = different.isEmpty ? pool : different
      guard !selectedPool.isEmpty else { break }
      let selected = selectedPool[(frames.count - 1) % selectedPool.count]
      let contacts = prior.contacts.map { contact in
        guard contact.limb == limb else { return contact }
        return LimbContact(
          limb: limb,
          target: .hold(selected.id),
          mode: limb.isHand ? .hand : .foot,
          isLocked: contact.isLocked
        )
      }
      let generatedID = uniqueKeyframeID(
        prefix: "\(request.rehearsalID.rawValue)-suggested-\(frames.count)",
        existing: Set(frames.map(\.id))
      )
      frames.append(
        PoseKeyframe(
          id: generatedID,
          label: "Suggested step \(frames.count)",
          torsoPosition: prior.torsoPosition,
          contacts: contacts,
          provenance: provenance
        ))
    }

    let engine = try RouteRehearsalEngine(
      rehearsalID: request.rehearsalID,
      scene: request.scene,
      bodyProfile: request.bodyProfile,
      planKeyframes: frames
    )
    return RehearsalSuggestion(
      rehearsalID: request.rehearsalID,
      keyframes: engine.rehearsal.plan.keyframes,
      provenance: provenance
    )
  }

  private func suggestedCopy(
    _ frame: PoseKeyframe,
    provenance: RehearsalProvenance
  ) -> PoseKeyframe {
    PoseKeyframe(
      id: frame.id,
      label: frame.label,
      torsoPosition: frame.torsoPosition,
      contacts: frame.contacts,
      provenance: provenance
    )
  }

  private func defaultSeed(
    for request: RehearsalSuggestionRequest,
    orderedHolds: [Hold],
    provenance: RehearsalProvenance
  ) -> PoseKeyframe {
    let assignments: [Limb: Int] = [
      .leftFoot: 0,
      .rightFoot: 1,
      .leftHand: 2,
      .rightHand: 3,
    ]
    let contacts = Limb.allCases.map { limb -> LimbContact in
      guard let index = assignments[limb], orderedHolds.indices.contains(index) else {
        return .unknown(limb)
      }
      return LimbContact(
        limb: limb,
        target: .hold(orderedHolds[index].id),
        mode: limb.isHand ? .hand : .foot
      )
    }
    let selected = contacts.compactMap { contact in
      contact.target.holdID.flatMap { id in request.scene.hold(id: id)?.center }
    }
    let torso: Point2D
    if selected.isEmpty {
      torso = Point2D(x: request.scene.size.width / 2, y: request.scene.size.height / 3)
    } else {
      torso = Point2D(
        x: selected.map(\.x).reduce(0, +) / Double(selected.count),
        y: selected.map(\.y).reduce(0, +) / Double(selected.count)
      )
    }
    return PoseKeyframe(
      id: PoseKeyframeID("\(request.rehearsalID.rawValue)-suggested-0"),
      label: "Suggested start",
      torsoPosition: torso,
      contacts: contacts,
      provenance: provenance
    )
  }

  private func uniqueKeyframeID(
    prefix: String,
    existing: Set<PoseKeyframeID>
  ) -> PoseKeyframeID {
    var suffix = 0
    var candidate = PoseKeyframeID(prefix)
    while existing.contains(candidate) {
      suffix += 1
      candidate = PoseKeyframeID("\(prefix)-\(suffix)")
    }
    return candidate
  }
}
