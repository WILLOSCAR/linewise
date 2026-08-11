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
    let progress = min(max(progress, 0), 1)
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
    self.radius = max(radius, 0)
    self.kind = kind
    self.routeRole = routeRole
  }
}

public struct RouteScene: Equatable, Codable, Sendable {
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
    self.metersPerSceneUnit = metersPerSceneUnit.flatMap { $0 > 0 ? $0 : nil }
    self.holds = holds
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

public enum AvatarJoint: String, Hashable, Codable, Sendable {
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
