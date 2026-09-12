import Foundation

/// 体型（只影响火柴人比例）。
struct BodyProfile: Codable, Hashable, Sendable {
    var heightCm: Double = 170
    var armSpanCm: Double = 170

    static let `default` = BodyProfile()

    /// 臂展 / 身高，限制在合理范围。
    var apeIndex: Double { min(max(armSpanCm / max(heightCm, 100), 0.9), 1.15) }
}

/// 一个姿态的所有关节位置。坐标系与输入一致（等比空间）。
struct StickFigurePose: Hashable, Sendable {
    var head: CGPoint
    var neck: CGPoint
    var hipCenter: CGPoint
    var leftShoulder: CGPoint
    var rightShoulder: CGPoint
    var leftHip: CGPoint
    var rightHip: CGPoint
    var leftElbow: CGPoint
    var rightElbow: CGPoint
    var leftHand: CGPoint
    var rightHand: CGPoint
    var leftKnee: CGPoint
    var rightKnee: CGPoint
    var leftFoot: CGPoint
    var rightFoot: CGPoint
    var headRadius: CGFloat
}

/// 火柴人姿态求解：只跟随四肢接触点，不做物理、不判定可行性。
///
/// 输入坐标使用“等比空间”：y ∈ [0, 1]，x ∈ [0, aspect]，这样距离是各向同性的。
enum StickFigureSolver {
    struct Proportions: Sendable {
        var figureHeight: CGFloat      // 相对等比空间高度 1
        var headRadius: CGFloat
        var torso: CGFloat
        var shoulderHalf: CGFloat
        var hipHalf: CGFloat
        var upperArm: CGFloat
        var forearm: CGFloat
        var thigh: CGFloat
        var shin: CGFloat

        var armLength: CGFloat { upperArm + forearm }
        var legLength: CGFloat { thigh + shin }

        static func make(profile: BodyProfile, figureHeight: CGFloat = 0.30) -> Proportions {
            let h = figureHeight
            let ape = CGFloat(profile.apeIndex)
            return Proportions(
                figureHeight: h,
                headRadius: 0.062 * h,
                torso: 0.30 * h,
                shoulderHalf: 0.11 * h,
                hipHalf: 0.07 * h,
                upperArm: 0.19 * h * ape,
                forearm: 0.20 * h * ape,
                thigh: 0.24 * h,
                shin: 0.24 * h
            )
        }
    }

    /// 四肢接触位置；`nil` 表示地面（由求解器放置）。
    struct Contacts: Sendable {
        var leftHand: CGPoint?
        var rightHand: CGPoint?
        var leftFoot: CGPoint?
        var rightFoot: CGPoint?
    }

    static func solve(contacts: Contacts, proportions p: Proportions, groundY: CGFloat, bounds: CGRect) -> StickFigurePose {
        // 1. 初始髋部位置估计
        let hands = [contacts.leftHand, contacts.rightHand].compactMap { $0 }
        let feetOnHolds = [contacts.leftFoot, contacts.rightFoot].compactMap { $0 }
        let handsCenter = average(hands)
        var hip: CGPoint
        if let hc = handsCenter {
            if let fc = average(feetOnHolds) {
                // 手脚都在墙上：髋在两者之间，偏向脚
                hip = CGPoint(x: fc.x * 0.55 + hc.x * 0.45, y: fc.y * 0.55 + hc.y * 0.45)
            } else {
                // 脚在地面：髋在手的正下方一段距离，但不低于地面 - 腿长
                let y = min(hc.y + p.torso + p.armLength * 0.75, groundY - p.legLength * 0.8)
                hip = CGPoint(x: hc.x, y: y)
            }
        } else if let fc = average(feetOnHolds) {
            hip = CGPoint(x: fc.x, y: fc.y - p.legLength * 0.8)
        } else {
            // 站在地面
            hip = CGPoint(x: bounds.midX, y: groundY - p.legLength * 0.95)
        }

        // 2. 地面脚位置（跟随髋；够不到地面时自然下垂，不拉扯髋）
        func groundFoot(isLeft: Bool) -> CGPoint {
            let spread = p.hipHalf + 0.06 * p.figureHeight
            let y = min(groundY, hip.y + p.legLength * 0.97)
            return CGPoint(x: hip.x + (isLeft ? -spread : spread), y: y)
        }

        // 3. 迭代松弛：肩到手、髋到（墙上的）脚尽量不超过肢长
        for _ in 0..<10 {
            var shoulder = CGPoint(x: hip.x, y: hip.y - p.torso)
            for hand in hands {
                let d = distance(shoulder, hand)
                if d > p.armLength, d > 0 {
                    let k = (d - p.armLength) / d * 0.6
                    shoulder = CGPoint(x: shoulder.x + (hand.x - shoulder.x) * k, y: shoulder.y + (hand.y - shoulder.y) * k)
                }
            }
            hip = CGPoint(x: shoulder.x, y: shoulder.y + p.torso)

            for foot in feetOnHolds {
                let d = distance(hip, foot)
                if d > p.legLength, d > 0 {
                    let k = (d - p.legLength) / d * 0.4
                    hip = CGPoint(x: hip.x + (foot.x - hip.x) * k, y: hip.y + (foot.y - hip.y) * k)
                }
            }
            // 髋不低于地面
            hip.y = min(hip.y, groundY - p.legLength * 0.35)
            hip.x = min(max(hip.x, bounds.minX + p.shoulderHalf), bounds.maxX - p.shoulderHalf)
        }

        // 4. 关节
        let neck = CGPoint(x: hip.x, y: hip.y - p.torso)
        let head = CGPoint(x: neck.x, y: neck.y - p.headRadius * 1.25)
        let ls = CGPoint(x: neck.x - p.shoulderHalf, y: neck.y + p.headRadius * 0.3)
        let rs = CGPoint(x: neck.x + p.shoulderHalf, y: neck.y + p.headRadius * 0.3)
        let lh = CGPoint(x: hip.x - p.hipHalf, y: hip.y)
        let rh = CGPoint(x: hip.x + p.hipHalf, y: hip.y)

        let leftHand = contacts.leftHand ?? CGPoint(x: lh.x - p.armLength * 0.15, y: hip.y + p.armLength * 0.9)
        let rightHand = contacts.rightHand ?? CGPoint(x: rh.x + p.armLength * 0.15, y: hip.y + p.armLength * 0.9)
        let leftFoot = contacts.leftFoot ?? groundFoot(isLeft: true)
        let rightFoot = contacts.rightFoot ?? groundFoot(isLeft: false)

        // 肘向外弯，膝向外弯（像攀爬时的开髋）
        let leftElbow = twoBoneJoint(root: ls, end: leftHand, l1: p.upperArm, l2: p.forearm, bendLeft: true)
        let rightElbow = twoBoneJoint(root: rs, end: rightHand, l1: p.upperArm, l2: p.forearm, bendLeft: false)
        let leftKnee = twoBoneJoint(root: lh, end: leftFoot, l1: p.thigh, l2: p.shin, bendLeft: true)
        let rightKnee = twoBoneJoint(root: rh, end: rightFoot, l1: p.thigh, l2: p.shin, bendLeft: false)

        return StickFigurePose(
            head: head, neck: neck, hipCenter: hip,
            leftShoulder: ls, rightShoulder: rs, leftHip: lh, rightHip: rh,
            leftElbow: leftElbow, rightElbow: rightElbow, leftHand: leftHand, rightHand: rightHand,
            leftKnee: leftKnee, rightKnee: rightKnee, leftFoot: leftFoot, rightFoot: rightFoot,
            headRadius: p.headRadius
        )
    }

    /// 双骨 IK：返回中间关节位置。`bendLeft` 决定关节落在根→末端连线的哪一侧。
    static func twoBoneJoint(root: CGPoint, end: CGPoint, l1: CGFloat, l2: CGFloat, bendLeft: Bool) -> CGPoint {
        let dx = end.x - root.x
        let dy = end.y - root.y
        let dRaw = sqrt(dx * dx + dy * dy)
        guard dRaw > 0.0001 else {
            return CGPoint(x: root.x + (bendLeft ? -l1 : l1), y: root.y)
        }
        let d = min(max(dRaw, abs(l1 - l2) + 0.0001), l1 + l2 - 0.0001)
        let a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        let h = sqrt(max(0, l1 * l1 - a * a))
        let ux = dx / dRaw
        let uy = dy / dRaw
        let mid = CGPoint(x: root.x + ux * a, y: root.y + uy * a)
        // 垂直向量；选择使关节在“外侧”的方向
        var px = -uy
        var py = ux
        // 当肢体大致向下时，(−uy, ux) 指向右侧；左侧肢体需要取反
        if bendLeft { px = -px; py = -py }
        // 若肢体向上（手在肩上方），翻转保证肘仍向外
        if uy < 0 { px = -px; py = -py }
        return CGPoint(x: mid.x + px * h, y: mid.y + py * h)
    }

    private static func average(_ points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sx = points.reduce(0) { $0 + $1.x }
        let sy = points.reduce(0) { $0 + $1.y }
        return CGPoint(x: sx / CGFloat(points.count), y: sy / CGFloat(points.count))
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
