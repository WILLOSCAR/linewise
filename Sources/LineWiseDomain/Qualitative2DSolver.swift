import Foundation

public struct Qualitative2DSolver: Sendable {
  public init() {}

  public func solve(
    scene: RouteScene,
    bodyProfile: BodyProfile,
    torsoPosition: Point2D,
    contacts: [LimbContact]
  ) -> PoseSolution {
    let normalized = normalize(contacts)
    let scale =
      scene.metersPerSceneUnit
      ?? inferredScale(
        scene: scene,
        heightMeters: bodyProfile.heightMeters
      )
    let body = BodyGeometry(profile: bodyProfile, metersPerSceneUnit: scale)
    let roots = limbRoots(torso: torsoPosition, body: body)
    var findings = contactShapeFindings(raw: contacts, normalized: normalized)
    var joints: [AvatarJoint: Point2D] = [
      .torso: torsoPosition,
      .pelvis: Point2D(x: torsoPosition.x, y: torsoPosition.y - body.torsoToPelvis),
      .leftShoulder: roots[.leftHand]!,
      .rightShoulder: roots[.rightHand]!,
      .leftHip: roots[.leftFoot]!,
      .rightHip: roots[.rightFoot]!,
    ]

    if scene.metersPerSceneUnit == nil {
      findings.append(
        ConstraintFinding(
          kind: .scaleUncertainty,
          severity: .unresolved,
          message: "Scene scale is unknown; reach is only a qualitative estimate."
        ))
    }

    for contact in normalized {
      let root = roots[contact.limb]!
      let target = targetPoint(for: contact.target, in: scene)
      let segmentLength = contact.limb.isHand ? body.armSegment : body.legSegment
      let jointsForLimb = solveLimb(
        limb: contact.limb,
        root: root,
        target: target,
        segmentLength: segmentLength,
        scene: scene,
        contact: contact,
        findings: &findings
      )
      joints.merge(jointsForLimb) { _, new in new }
    }

    if normalized.filter({ $0.target.isSupportContact }).count < 2 {
      findings.append(
        ConstraintFinding(
          kind: .balanceOrSupportConcern,
          severity: .unresolved,
          message: "Fewer than two explicit support contacts are available."
        ))
    }

    if torsoPosition.x < 0 || torsoPosition.x > scene.size.width || torsoPosition.y < 0
      || torsoPosition.y > scene.size.height
    {
      findings.append(
        ConstraintFinding(
          kind: .wallOrBodyCollision,
          severity: .warning,
          message: "Torso lies outside the represented wall bounds."
        ))
    }

    let confidence: SolverConfidence
    if findings.contains(where: { $0.severity == .warning }) {
      confidence = .low
    } else if findings.contains(where: { $0.severity == .unresolved }) {
      confidence = .medium
    } else {
      confidence = .high
    }

    return PoseSolution(
      avatar: ClimberAvatar(
        bodyProfileID: bodyProfile.id,
        joints: joints,
        contacts: normalized
      ),
      findings: findings,
      confidence: confidence
    )
  }

  private func normalize(_ contacts: [LimbContact]) -> [LimbContact] {
    let byLimb = contacts.reduce(into: [Limb: LimbContact]()) { result, contact in
      result[contact.limb] = contact
    }
    return Limb.allCases.map { byLimb[$0] ?? .unknown($0) }
  }

  /// Reports each limb whose contact the user has not actually resolved.
  ///
  /// The check reads the *normalized* contacts, because a limb the caller never
  /// mentioned and a limb the user explicitly marked `.unknown` are the same
  /// honest state and must both stay visible: back-filling a missing limb is a
  /// representation detail, never evidence that the pose is settled. Duplicate
  /// records are still detected from the raw array, since normalizing collapses
  /// them.
  private func contactShapeFindings(
    raw: [LimbContact],
    normalized: [LimbContact]
  ) -> [ConstraintFinding] {
    Limb.allCases.compactMap { limb in
      if raw.filter({ $0.limb == limb }).count > 1 {
        return ConstraintFinding(
          kind: .contactConflict,
          severity: .unresolved,
          limb: limb,
          message: "\(limb.label) has more than one contact record."
        )
      }
      guard normalized.first(where: { $0.limb == limb })?.target == .unknown else {
        return nil
      }
      return ConstraintFinding(
        kind: .contactConflict,
        severity: .unresolved,
        limb: limb,
        message: "\(limb.label) contact is unknown."
      )
    }
  }

  private func inferredScale(scene: RouteScene, heightMeters: Double) -> Double {
    let sceneHeight = max(scene.size.height, 0.1)
    return heightMeters / (sceneHeight * 0.45)
  }

  private func limbRoots(torso: Point2D, body: BodyGeometry) -> [Limb: Point2D] {
    [
      .leftHand: Point2D(
        x: torso.x - (body.shoulderWidth / 2),
        y: torso.y + body.torsoToShoulder
      ),
      .rightHand: Point2D(
        x: torso.x + (body.shoulderWidth / 2),
        y: torso.y + body.torsoToShoulder
      ),
      .leftFoot: Point2D(
        x: torso.x - (body.hipWidth / 2),
        y: torso.y - body.torsoToPelvis
      ),
      .rightFoot: Point2D(
        x: torso.x + (body.hipWidth / 2),
        y: torso.y - body.torsoToPelvis
      ),
    ]
  }

  private func targetPoint(for target: ContactTarget, in scene: RouteScene) -> Point2D? {
    switch target {
    case .hold(let holdID): scene.hold(id: holdID)?.center
    case .wallRegion(_, let point), .ground(let point): point
    case .free, .unknown: nil
    }
  }

  private func solveLimb(
    limb: Limb,
    root: Point2D,
    target: Point2D?,
    segmentLength: Double,
    scene: RouteScene,
    contact: LimbContact,
    findings: inout [ConstraintFinding]
  ) -> [AvatarJoint: Point2D] {
    guard let target else {
      if case .hold(let holdID) = contact.target {
        findings.append(
          ConstraintFinding(
            kind: .contactConflict,
            severity: .warning,
            limb: limb,
            message: "\(limb.label) references missing hold \(holdID.rawValue)."
          ))
      }
      let direction = limb.isHand ? 1.0 : -1.0
      let endpoint = Point2D(x: root.x, y: root.y + (direction * segmentLength * 1.5))
      let midpoint = root.interpolated(to: endpoint, progress: 0.5)
      return jointMap(limb: limb, midpoint: midpoint, endpoint: endpoint)
    }

    let distance = root.distance(to: target)
    let maximumReach = segmentLength * 2
    if distance > maximumReach {
      findings.append(
        ConstraintFinding(
          kind: .reachLimit,
          severity: .warning,
          limb: limb,
          message: "\(limb.label) target exceeds this qualitative two-segment reach estimate."
        ))
    } else if distance < segmentLength * 0.28 {
      findings.append(
        ConstraintFinding(
          kind: .jointRangeTension,
          severity: .unresolved,
          limb: limb,
          message: "\(limb.label) target may require a tightly folded joint position."
        ))
    }

    let clampedDistance = min(max(distance, 0.000_1), maximumReach - 0.000_1)
    let along = clampedDistance / 2
    let perpendicular = sqrt(max((segmentLength * segmentLength) - (along * along), 0))
    let dx = (target.x - root.x) / max(distance, 0.000_1)
    let dy = (target.y - root.y) / max(distance, 0.000_1)
    let bendSign = limb == .leftHand || limb == .rightFoot ? -1.0 : 1.0
    let midpoint = Point2D(
      x: root.x + (dx * along) + (-dy * perpendicular * bendSign),
      y: root.y + (dy * along) + (dx * perpendicular * bendSign)
    )
    return jointMap(limb: limb, midpoint: midpoint, endpoint: target)
  }

  private func jointMap(
    limb: Limb,
    midpoint: Point2D,
    endpoint: Point2D
  ) -> [AvatarJoint: Point2D] {
    switch limb {
    case .leftHand: [.leftElbow: midpoint, .leftHand: endpoint]
    case .rightHand: [.rightElbow: midpoint, .rightHand: endpoint]
    case .leftFoot: [.leftKnee: midpoint, .leftFoot: endpoint]
    case .rightFoot: [.rightKnee: midpoint, .rightFoot: endpoint]
    }
  }
}

private struct BodyGeometry {
  let shoulderWidth: Double
  let hipWidth: Double
  let torsoToShoulder: Double
  let torsoToPelvis: Double
  let armSegment: Double
  let legSegment: Double

  init(profile: BodyProfile, metersPerSceneUnit: Double) {
    let metersPerSceneUnit = max(metersPerSceneUnit, 0.000_1)
    shoulderWidth = profile.shoulderWidthMeters / metersPerSceneUnit
    hipWidth = profile.hipWidthMeters / metersPerSceneUnit
    torsoToShoulder = (profile.heightMeters * 0.14) / metersPerSceneUnit
    torsoToPelvis = (profile.heightMeters * 0.13) / metersPerSceneUnit
    armSegment = max(
      ((profile.armSpanMeters - profile.shoulderWidthMeters) / 4) / metersPerSceneUnit,
      0.05
    )
    legSegment = max((profile.inseamMeters / 2) / metersPerSceneUnit, 0.05)
  }
}
