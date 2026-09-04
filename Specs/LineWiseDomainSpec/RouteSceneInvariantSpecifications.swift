import Foundation
import LineWiseDomain

// A RouteScene is the geometric ground truth a qualitative rehearsal solve reads.
// Two of its numbers decide whether the solve can be honest:
//
//   * `metersPerSceneUnit` — the scale. When it is unknown the solver reports
//     `scaleUncertainty` and refuses high confidence. A scale that is present but
//     unusable (non-positive, finer than the geometry can represent, or not a
//     number at all) is indistinguishable from unknown: the geometry has to clamp
//     it, which silently inflates every limb until no reach can be exceeded. So an
//     unusable scale must be reported as unknown, never stored as if it were real.
//
//   * `Hold.radius` — a length. It is divided by the scene width when a hold is
//     drawn, so a negative or non-numeric radius propagates into the surfaces.
//
// These specifications pin the invariant on the type itself, for every way a
// scene can be built: constructed in code, or decoded from an older writer or a
// remote model's JSON.

private enum RouteSceneInvariantSpecFailure: Error {
  case expected(String)
}

private func sceneInvariantExpect(
  _ condition: @autoclosure () -> Bool,
  _ message: String
) throws {
  guard condition() else {
    throw RouteSceneInvariantSpecFailure.expected(message)
  }
}

/// Every scale a scene must refuse to store as a real measurement, with the
/// reason it is unusable.
private let unusableScales: [(Double, String)] = [
  (-4, "a negative scale"),
  (0, "a zero scale"),
  (1e-300, "a scale finer than the geometry can represent"),
  (.nan, "a scale that is not a number"),
  (.infinity, "an infinite scale"),
  (-.infinity, "a negatively infinite scale"),
]

private func sceneWithScale(_ scale: Double?) -> RouteScene {
  RouteScene(
    id: RouteSceneID("scene-invariant"),
    name: "Invariant route",
    size: SceneSize(width: 10, height: 20),
    metersPerSceneUnit: scale,
    holds: [
      Hold(id: HoldID("hold-invariant"), center: Point2D(x: 9, y: 19), radius: 0.2)
    ]
  )
}

/// The consequence the invariant exists for: with no usable scale the solver
/// must say so and must not claim high confidence.
private func expectSolverStaysHonest(about scene: RouteScene, _ label: String) throws {
  let solution = Qualitative2DSolver().solve(
    scene: scene,
    bodyProfile: .generic(id: BodyProfileID("body-invariant")),
    torsoPosition: Point2D(x: 5, y: 10),
    contacts: scene.holds.map { LimbContact(limb: .leftHand, target: .hold($0.id), mode: .hand) }
  )
  try sceneInvariantExpect(
    solution.findings.contains { $0.kind == .scaleUncertainty },
    "\(label) must still make the solver report scale uncertainty"
  )
  try sceneInvariantExpect(
    solution.confidence != .high,
    "\(label) must not let the solve be reported as high confidence"
  )
}

private func anUnusableSceneScaleIsReportedAsUnknown() throws {
  for (scale, label) in unusableScales {
    let scene = sceneWithScale(scale)
    try sceneInvariantExpect(
      scene.metersPerSceneUnit == nil,
      "\(label) must be reported as an unknown scale, not stored"
    )
    try expectSolverStaysHonest(about: scene, label)
  }

  // A usable scale is kept exactly as given — the invariant narrows nothing else.
  let usable = sceneWithScale(0.05)
  try sceneInvariantExpect(
    usable.metersPerSceneUnit == 0.05,
    "a usable scale must be preserved unchanged"
  )
  try sceneInvariantExpect(
    Qualitative2DSolver().solve(
      scene: usable,
      bodyProfile: .generic(id: BodyProfileID("body-invariant")),
      torsoPosition: Point2D(x: 5, y: 10),
      contacts: [LimbContact(limb: .leftHand, target: .hold(HoldID("hold-invariant")), mode: .hand)]
    ).findings.allSatisfy { $0.kind != .scaleUncertainty },
    "a usable scale must not be reported as uncertain"
  )
}

private func aHoldRadiusIsAlwaysANonNegativeNumber() throws {
  for radius in [-3, .nan, -.infinity] as [Double] {
    let hold = Hold(
      id: HoldID("hold-invariant"),
      center: Point2D(x: 1, y: 2),
      radius: radius
    )
    try sceneInvariantExpect(
      hold.radius.isFinite && hold.radius >= 0,
      "a hold built with radius \(radius) must expose a non-negative finite radius"
    )
  }

  let measured = Hold(id: HoldID("hold-invariant"), center: Point2D(x: 1, y: 2), radius: 0.4)
  try sceneInvariantExpect(
    measured.radius == 0.4,
    "a real radius must be preserved unchanged"
  )
}

/// Decoding is the untrusted path: an older writer's archive or a remote model's
/// JSON. It must land on the same invariant as construction, not bypass it.
private func aDecodedSceneLandsOnTheSameInvariantAsAConstructedOne() throws {
  for (scale, label) in unusableScales where scale.isFinite {
    let json = Data(
      """
      {
        "id": "scene-invariant",
        "name": "Invariant route",
        "size": { "width": 10, "height": 20 },
        "metersPerSceneUnit": \(scale),
        "holds": [
          {
            "id": "hold-invariant",
            "center": { "x": 9, "y": 19 },
            "radius": -3,
            "kind": "hold",
            "routeRole": "route"
          }
        ]
      }
      """.utf8
    )

    let decoded = try JSONDecoder().decode(RouteScene.self, from: json)
    try sceneInvariantExpect(
      decoded.metersPerSceneUnit == nil,
      "a decoded scene declaring \(label) must report the scale as unknown"
    )
    try sceneInvariantExpect(
      decoded.holds.allSatisfy { $0.radius.isFinite && $0.radius >= 0 },
      "a decoded scene must not carry a negative hold radius"
    )
    try expectSolverStaysHonest(about: decoded, "a decoded scene declaring \(label)")
  }

  // A scene that round-trips through its own Codable is unchanged, so honouring
  // the invariant on decode does not corrupt legitimately archived scenes.
  let original = sceneWithScale(0.05)
  let restored = try JSONDecoder().decode(
    RouteScene.self,
    from: try JSONEncoder().encode(original)
  )
  try sceneInvariantExpect(
    restored == original,
    "a scene with usable numbers must survive an encode and decode round trip"
  )
}

func routeSceneInvariantSpecifications() -> [(String, () throws -> Void)] {
  [
    (
      "an unusable scene scale is reported as an unknown scale",
      anUnusableSceneScaleIsReportedAsUnknown
    ),
    (
      "a hold radius is always a non-negative finite number",
      aHoldRadiusIsAlwaysANonNegativeNumber
    ),
    (
      "a decoded scene honours the same invariant as a constructed one",
      aDecodedSceneLandsOnTheSameInvariantAsAConstructedOne
    ),
  ]
}
