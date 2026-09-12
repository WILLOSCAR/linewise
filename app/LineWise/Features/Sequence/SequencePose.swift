import Foundation
import SwiftUI

/// 把“四肢在哪个点”翻译成火柴人姿态：接触状态 → 等比空间坐标 → 求解。
enum SequencePoseBuilder {
    /// 地面在等比空间里的 y。
    static let groundY: CGFloat = 0.985

    /// 火柴人高度（等比空间单位）：由整条线的点在竖直方向的跨度推导，
    /// 让人和线的尺度大致匹配；夹在 0.22…0.38。
    static func figureHeight(holds: [Hold]) -> CGFloat {
        guard let minY = holds.map(\.y).min(), let maxY = holds.map(\.y).max() else { return 0.30 }
        return clampFigureHeight(CGFloat(maxY - minY) / 2.6)
    }

    static func clampFigureHeight(_ raw: CGFloat) -> CGFloat {
        min(max(raw, 0.22), 0.38)
    }

    /// 拖拽中的临时覆盖：某只手/脚不在点上，而在手指所在的等比坐标。
    struct Override: Equatable {
        var limb: Limb
        var point: CGPoint
    }

    static func contacts(state: ContactState, holds: [Hold], aspect: Double, override: Override? = nil) -> StickFigureSolver.Contacts {
        let byID = Dictionary(uniqueKeysWithValues: holds.map { ($0.id, $0) })
        func point(for limb: Limb) -> CGPoint? {
            if let override, override.limb == limb { return override.point }
            guard let id = state[limb], let hold = byID[id] else { return nil }
            return SpotlightGeometry.isoPoint(of: hold, aspect: aspect)
        }
        return StickFigureSolver.Contacts(
            leftHand: point(for: .leftHand),
            rightHand: point(for: .rightHand),
            leftFoot: point(for: .leftFoot),
            rightFoot: point(for: .rightFoot)
        )
    }

    static func pose(state: ContactState, holds: [Hold], aspect: Double, profile: BodyProfile, override: Override? = nil) -> StickFigurePose {
        let proportions = StickFigureSolver.Proportions.make(profile: profile, figureHeight: figureHeight(holds: holds))
        return StickFigureSolver.solve(
            contacts: contacts(state: state, holds: holds, aspect: aspect, override: override),
            proportions: proportions,
            groundY: groundY,
            bounds: CGRect(x: 0, y: 0, width: aspect, height: 1)
        )
    }

    /// 四个末端在等比空间的位置。
    static func endpoints(of pose: StickFigurePose) -> [(limb: Limb, point: CGPoint)] {
        [(.leftHand, pose.leftHand), (.rightHand, pose.rightHand), (.leftFoot, pose.leftFoot), (.rightFoot, pose.rightFoot)]
    }
}

/// 画布上的命中测试（视图坐标）。纯函数，便于测试。
enum SequenceHitTesting {
    /// 按下时找最近的手脚末端（阈值内）。
    /// 几个末端叠在同一个点上时（双手同点、手脚同点），按手指相对末端的方位选：
    /// 偏左 → 左侧肢体，偏上 → 手，偏下 → 脚。
    static func nearestEndpoint(to point: CGPoint, pose: StickFigurePose, geo: SpotlightGeometry, aspect: Double, threshold: CGFloat) -> (limb: Limb, view: CGPoint)? {
        let candidates: [(limb: Limb, view: CGPoint, distance: CGFloat)] = SequencePoseBuilder.endpoints(of: pose).compactMap { end in
            let v = geo.fromIso(end.point, aspect: aspect)
            let d = hypot(v.x - point.x, v.y - point.y)
            return d <= threshold ? (end.limb, v, d) : nil
        }
        guard let nearest = candidates.min(by: { $0.distance < $1.distance }) else { return nil }
        let tied = candidates.filter { abs($0.distance - nearest.distance) < 1 }
        guard tied.count > 1 else { return (nearest.limb, nearest.view) }

        func score(_ c: (limb: Limb, view: CGPoint, distance: CGFloat)) -> Int {
            var s = 0
            if (point.x < c.view.x) == c.limb.isLeft { s += 1 }
            if (point.y < c.view.y) == c.limb.isHand { s += 1 }
            return s
        }
        // 分数相同取先出现的（左手、右手、左脚、右脚）。
        var best = tied[0]
        for c in tied.dropFirst() where score(c) > score(best) { best = c }
        return (best.limb, best.view)
    }

    /// 拖动中可吸附的点：阈值 = max(半径 × 2, minThreshold)，取最近。
    static func nearestSnapHold(to limbView: CGPoint, holds: [Hold], geo: SpotlightGeometry, minThreshold: CGFloat) -> Hold? {
        var nearest: (hold: Hold, distance: CGFloat)?
        for hold in holds {
            let c = geo.point(hold)
            let d = hypot(c.x - limbView.x, c.y - limbView.y)
            guard d <= max(geo.radius(hold) * 2, minThreshold) else { continue }
            if nearest == nil || d < nearest!.distance { nearest = (hold, d) }
        }
        return nearest?.hold
    }
}

extension SpotlightGeometry {
    /// 不依赖实例的 `toIso`：把归一化点转到等比空间（y ∈ 0…1，x ∈ 0…aspect）。
    static func isoPoint(of hold: Hold, aspect: Double) -> CGPoint {
        CGPoint(x: hold.x * aspect, y: hold.y)
    }

    /// 视图坐标 → 等比空间（不裁掉越界，调用方自行夹取）。
    func isoPoint(fromView p: CGPoint, aspect: Double) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGPoint(x: (p.x - rect.minX) / rect.width * aspect, y: (p.y - rect.minY) / rect.height)
    }
}

// MARK: - 可动画的姿态

/// 把 `StickFigurePose` 摊平成向量，供 SwiftUI 在两个姿态之间插值。
struct PoseVector: VectorArithmetic {
    var values: [Double]

    static let count = 31

    init(values: [Double]) { self.values = values }

    init(_ pose: StickFigurePose) {
        var v: [Double] = []
        v.reserveCapacity(Self.count)
        for p in [pose.head, pose.neck, pose.hipCenter,
                  pose.leftShoulder, pose.rightShoulder, pose.leftHip, pose.rightHip,
                  pose.leftElbow, pose.rightElbow, pose.leftHand, pose.rightHand,
                  pose.leftKnee, pose.rightKnee, pose.leftFoot, pose.rightFoot] {
            v.append(p.x)
            v.append(p.y)
        }
        v.append(pose.headRadius)
        values = v
    }

    /// 还原为姿态；向量长度不足时缺的分量按 0 处理（只会出现在 `zero`）。
    var pose: StickFigurePose {
        func at(_ i: Int) -> Double { i < values.count ? values[i] : 0 }
        func point(_ i: Int) -> CGPoint { CGPoint(x: at(i * 2), y: at(i * 2 + 1)) }
        return StickFigurePose(
            head: point(0), neck: point(1), hipCenter: point(2),
            leftShoulder: point(3), rightShoulder: point(4), leftHip: point(5), rightHip: point(6),
            leftElbow: point(7), rightElbow: point(8), leftHand: point(9), rightHand: point(10),
            leftKnee: point(11), rightKnee: point(12), leftFoot: point(13), rightFoot: point(14),
            headRadius: at(30)
        )
    }

    static var zero: PoseVector { PoseVector(values: []) }

    static func + (lhs: PoseVector, rhs: PoseVector) -> PoseVector { combine(lhs, rhs, +) }
    static func - (lhs: PoseVector, rhs: PoseVector) -> PoseVector { combine(lhs, rhs, -) }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

    private static func combine(_ a: PoseVector, _ b: PoseVector, _ op: (Double, Double) -> Double) -> PoseVector {
        let n = max(a.values.count, b.values.count)
        var out: [Double] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let x = i < a.values.count ? a.values[i] : 0
            let y = i < b.values.count ? b.values[i] : 0
            out.append(op(x, y))
        }
        return PoseVector(values: out)
    }
}

/// 带火柴人的聚光灯画布；姿态变化时由 SwiftUI 逐帧插值（`withAnimation` 驱动）。
struct SequenceCanvas: View, Animatable {
    var image: UIImage?
    var aspect: Double
    var holds: [Hold]
    var startHoldIDs: [UUID] = []
    var finishHoldID: UUID?
    var highlightedHoldID: UUID?
    var pose: PoseVector
    var showNumbers: Bool = true
    var dim: Double = 0.66
    var ringWidth: CGFloat = 2

    var animatableData: PoseVector {
        get { pose }
        set { pose = newValue }
    }

    var body: some View {
        SpotlightImage(
            image: image,
            aspect: aspect,
            holds: holds,
            startHoldIDs: startHoldIDs,
            finishHoldID: finishHoldID,
            highlightedHoldID: highlightedHoldID,
            pose: pose.pose,
            poseIsoAspect: aspect,
            showNumbers: showNumbers,
            dim: dim,
            ringWidth: ringWidth
        )
    }
}
