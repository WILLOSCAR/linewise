import Foundation

public struct RehearsalScopedID<Scope>: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum RouteSceneIDScope: Sendable {}
public enum HoldIDScope: Sendable {}
public enum BodyProfileIDScope: Sendable {}
public enum RouteRehearsalIDScope: Sendable {}
public enum PoseKeyframeIDScope: Sendable {}

public typealias RouteSceneID = RehearsalScopedID<RouteSceneIDScope>
public typealias HoldID = RehearsalScopedID<HoldIDScope>
public typealias BodyProfileID = RehearsalScopedID<BodyProfileIDScope>
public typealias RouteRehearsalID = RehearsalScopedID<RouteRehearsalIDScope>
public typealias PoseKeyframeID = RehearsalScopedID<PoseKeyframeIDScope>

public struct Point2D: Hashable, Codable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  public func distance(to other: Point2D) -> Double {
    hypot(other.x - x, other.y - y)
  }

  public func interpolated(to other: Point2D, progress: Double) -> Point2D {
    // NaN survives `min`/`max`, so clamping alone would let it reach a drawn
    // joint position. An unusable progress value falls back to this endpoint.
    let progress = progress.isFinite ? min(max(progress, 0), 1) : (progress > 0 ? 1 : 0)
    return Point2D(
      x: x + ((other.x - x) * progress),
      y: y + ((other.y - y) * progress)
    )
  }
}

public struct SceneSize: Hashable, Codable, Sendable {
  public let width: Double
  public let height: Double

  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
}

public enum HoldKind: String, Hashable, Codable, Sendable {
  case hold
  case volume
  case wallRegion
}

public enum HoldRouteRole: String, Hashable, Codable, Sendable {
  case route
  case start
  case zone
  case top
  case unknown
}

public struct Hold: Hashable, Codable, Sendable {
  public let id: HoldID
  public let center: Point2D
  public let radius: Double
  public let kind: HoldKind
  public let routeRole: HoldRouteRole

  public init(
    id: HoldID,
    center: Point2D,
    radius: Double,
    kind: HoldKind = .hold,
    routeRole: HoldRouteRole = .route
  ) {
    self.id = id
    self.center = center
    self.radius = radius.isFinite ? max(radius, 0) : 0
    self.kind = kind
    self.routeRole = routeRole
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case center
    case radius
    case kind
    case routeRole
  }

  /// Decoded holds may come from a remote model or an older writer, so they are
  /// funnelled through the initializer that clamps `radius` rather than trusting
  /// the wire value.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try container.decode(HoldID.self, forKey: .id),
      center: try container.decode(Point2D.self, forKey: .center),
      radius: try container.decode(Double.self, forKey: .radius),
      kind: try container.decode(HoldKind.self, forKey: .kind),
      routeRole: try container.decode(HoldRouteRole.self, forKey: .routeRole)
    )
  }
}

public struct RouteScene: Equatable, Codable, Sendable {
  /// The smallest scale a qualitative solve can honour as written. A scene unit
  /// finer than this is indistinguishable from "scale unknown": the geometry
  /// would have to clamp it, silently inflating every limb so that no reach can
  /// ever be exceeded. Reporting such a value as unknown keeps the read honest.
  public static let minimumUsableMetersPerSceneUnit = 0.000_1

  public let id: RouteSceneID
  public let name: String
  public let size: SceneSize
  public let metersPerSceneUnit: Double?
  public let holds: [Hold]

  public init(
    id: RouteSceneID,
    name: String,
    size: SceneSize,
    metersPerSceneUnit: Double?,
    holds: [Hold]
  ) {
    self.id = id
    self.name = name
    self.size = size
    self.metersPerSceneUnit = metersPerSceneUnit.flatMap {
      $0.isFinite && $0 >= Self.minimumUsableMetersPerSceneUnit ? $0 : nil
    }
    self.holds = holds
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case size
    case metersPerSceneUnit
    case holds
  }

  /// A decoded scene is untrusted input — a remote model adapter or an older
  /// writer supplies it. Decoding funnels through the initializer so an
  /// unusable `metersPerSceneUnit` is reported as an honest unknown scale
  /// instead of silently suppressing the solver's scale uncertainty.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try container.decode(RouteSceneID.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      size: try container.decode(SceneSize.self, forKey: .size),
      metersPerSceneUnit: try container.decodeIfPresent(Double.self, forKey: .metersPerSceneUnit),
      holds: try container.decode([Hold].self, forKey: .holds)
    )
  }

  public func hold(id: HoldID) -> Hold? {
    holds.first { $0.id == id }
  }
}

public enum DominantSide: String, Hashable, Codable, Sendable {
  case left
  case right
  case unspecified
}

public enum ProfileConfidence: String, Hashable, Codable, Sendable {
  case generic
  case userEstimated
  case measured
}

public struct BodyProfile: Hashable, Codable, Sendable {
  public let id: BodyProfileID
  public let heightMeters: Double
  public let armSpanMeters: Double
  public let inseamMeters: Double
  public let shoulderWidthMeters: Double
  public let hipWidthMeters: Double
  public let dominantSide: DominantSide
  public let confidence: ProfileConfidence

  public init(
    id: BodyProfileID,
    heightMeters: Double,
    armSpanMeters: Double,
    inseamMeters: Double,
    shoulderWidthMeters: Double,
    hipWidthMeters: Double,
    dominantSide: DominantSide = .unspecified,
    confidence: ProfileConfidence = .userEstimated
  ) {
    self.id = id
    self.heightMeters = max(heightMeters, 0.5)
    self.armSpanMeters = max(armSpanMeters, 0.5)
    self.inseamMeters = max(inseamMeters, 0.2)
    self.shoulderWidthMeters = max(shoulderWidthMeters, 0.1)
    self.hipWidthMeters = max(hipWidthMeters, 0.1)
    self.dominantSide = dominantSide
    self.confidence = confidence
  }

  public static func generic(id: BodyProfileID) -> BodyProfile {
    BodyProfile(
      id: id,
      heightMeters: 1.70,
      armSpanMeters: 1.70,
      inseamMeters: 0.78,
      shoulderWidthMeters: 0.38,
      hipWidthMeters: 0.30,
      confidence: .generic
    )
  }
}

public enum Limb: String, CaseIterable, Hashable, Codable, Sendable {
  case leftHand = "lh"
  case rightHand = "rh"
  case leftFoot = "lf"
  case rightFoot = "rf"

  public var label: String {
    switch self {
    case .leftHand: "LH"
    case .rightHand: "RH"
    case .leftFoot: "LF"
    case .rightFoot: "RF"
    }
  }

  public var isHand: Bool {
    self == .leftHand || self == .rightHand
  }
}

public enum ContactMode: String, Hashable, Codable, Sendable {
  case hand
  case foot
  case heel
  case toe
  case hook
  case compression
  case smear
  case match
  case unspecified
}

public enum ContactTarget: Hashable, Codable, Sendable {
  case hold(HoldID)
  case wallRegion(String, Point2D)
  case ground(Point2D)
  case free
  case unknown

  public var holdID: HoldID? {
    guard case .hold(let id) = self else { return nil }
    return id
  }

  public var isSupportContact: Bool {
    switch self {
    case .hold, .wallRegion, .ground: true
    case .free, .unknown: false
    }
  }
}

public struct LimbContact: Hashable, Codable, Sendable {
  public let limb: Limb
  public let target: ContactTarget
  public let mode: ContactMode
  public let isLocked: Bool

  public init(
    limb: Limb,
    target: ContactTarget,
    mode: ContactMode = .unspecified,
    isLocked: Bool = false
  ) {
    self.limb = limb
    self.target = target
    self.mode = mode
    self.isLocked = isLocked
  }

  public static func unknown(_ limb: Limb) -> LimbContact {
    LimbContact(limb: limb, target: .unknown)
  }
}

public enum AvatarJoint: String, CaseIterable, Hashable, Codable, Sendable {
  case torso
  case pelvis
  case leftShoulder
  case rightShoulder
  case leftElbow
  case rightElbow
  case leftHand
  case rightHand
  case leftHip
  case rightHip
  case leftKnee
  case rightKnee
  case leftFoot
  case rightFoot
}

public struct ClimberAvatar: Equatable, Codable, Sendable {
  public let bodyProfileID: BodyProfileID
  public let joints: [AvatarJoint: Point2D]
  public let contacts: [LimbContact]

  public init(
    bodyProfileID: BodyProfileID,
    joints: [AvatarJoint: Point2D],
    contacts: [LimbContact]
  ) {
    self.bodyProfileID = bodyProfileID
    self.joints = joints
    self.contacts = contacts.sorted { $0.limb.rawValue < $1.limb.rawValue }
  }

  private enum CodingKeys: String, CodingKey {
    case bodyProfileID
    case joints
    case contacts
  }

  /// A joint map entry, persisted as an ordered array rather than letting Swift
  /// emit an enum-keyed Dictionary.
  ///
  /// Swift encodes a Dictionary whose key is neither String nor Int as a flat
  /// unkeyed array in iteration order, which per-process `Hashable` seeding
  /// randomizes; `.sortedKeys` cannot reorder it. Because callers fingerprint an
  /// encoded timeline to pin a StickFigureCue to the state it was cut from, that
  /// randomness would make byte-identical state hash differently on every
  /// launch. Writing the joints in a fixed order keeps the fingerprint stable.
  private struct JointEntry: Codable {
    let joint: AvatarJoint
    let position: Point2D
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      bodyProfileID: try container.decode(BodyProfileID.self, forKey: .bodyProfileID),
      joints: try Self.decodeJoints(from: container),
      contacts: try container.decode([LimbContact].self, forKey: .contacts)
    )
  }

  /// Reads the joint map in the current form, falling back to the form earlier
  /// builds wrote.
  ///
  /// Reopening a rehearsal trusts the persisted pose rather than re-solving it,
  /// so an avatar already on disk has to keep loading: refusing it would report
  /// the user's whole saved history as corrupt. The older layout is what Swift
  /// emits for an enum-keyed Dictionary — a flat array alternating joint name and
  /// position — and it is rewritten in the current form on the next save.
  private static func decodeJoints(
    from container: KeyedDecodingContainer<CodingKeys>
  ) throws -> [AvatarJoint: Point2D] {
    if let entries = try? container.decode([JointEntry].self, forKey: .joints) {
      return entries.reduce(into: [AvatarJoint: Point2D]()) { result, entry in
        result[entry.joint] = entry.position
      }
    }
    return try container.decode([AvatarJoint: Point2D].self, forKey: .joints)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(bodyProfileID, forKey: .bodyProfileID)
    try container.encode(
      AvatarJoint.allCases.compactMap { joint in
        joints[joint].map { JointEntry(joint: joint, position: $0) }
      },
      forKey: .joints
    )
    try container.encode(contacts, forKey: .contacts)
  }
}

public enum ConstraintFindingKind: String, Hashable, Codable, Sendable {
  case reachLimit
  case jointRangeTension
  case contactConflict
  case wallOrBodyCollision
  case scaleUncertainty
  case wallAngleUncertainty
  case balanceOrSupportConcern
  case occludedHold
  case downstreamInvalidated
  case dynamicMoveRequiresDifferentModel
}

public enum ConstraintFindingSeverity: String, Hashable, Codable, Sendable {
  case information
  case unresolved
  case warning
}

public struct ConstraintFinding: Hashable, Codable, Sendable {
  public let kind: ConstraintFindingKind
  public let severity: ConstraintFindingSeverity
  public let limb: Limb?
  public let message: String

  public init(
    kind: ConstraintFindingKind,
    severity: ConstraintFindingSeverity,
    limb: Limb? = nil,
    message: String
  ) {
    self.kind = kind
    self.severity = severity
    self.limb = limb
    self.message = message
  }

  public var isSafetyJudgment: Bool { false }
}

public enum SolverConfidence: String, Hashable, Codable, Sendable {
  case low
  case medium
  case high
}

public struct PoseSolution: Equatable, Codable, Sendable {
  public let avatar: ClimberAvatar
  public let findings: [ConstraintFinding]
  public let confidence: SolverConfidence

  public init(
    avatar: ClimberAvatar,
    findings: [ConstraintFinding],
    confidence: SolverConfidence
  ) {
    self.avatar = avatar
    self.findings = findings
    self.confidence = confidence
  }
}
