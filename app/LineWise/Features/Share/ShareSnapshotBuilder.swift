import Foundation
import SwiftUI

/// 分享图快照带里的一格：第几步、这一步的动作、对应姿态。
struct ShareSnapshot: Identifiable, Hashable {
    var stepIndex: Int
    var step: SequenceStep
    var pose: StickFigurePose

    var id: Int { stepIndex }
    var stepNumber: Int { stepIndex + 1 }
}

/// 把实际顺序变成最多 `maxCount` 格快照（多则等距抽样，首尾保留）。纯逻辑，可测。
enum ShareSnapshotBuilder {
    static let defaultMaxCount = 8
    /// 等比空间里的地面高度。
    static let groundY: CGFloat = 0.985

    /// 从 `count` 步里等距选出最多 `max` 个索引；第一步和最后一步一定在内。
    static func sampleIndices(count: Int, max: Int) -> [Int] {
        guard count > 0, max > 0 else { return [] }
        guard count > max else { return Array(0..<count) }
        guard max > 1 else { return [count - 1] }
        var result: [Int] = []
        for i in 0..<max {
            let idx = Int((Double(i) * Double(count - 1) / Double(max - 1)).rounded())
            if result.last != idx { result.append(idx) }
        }
        return result
    }

    static func snapshots(holds: [Hold], startHoldIDs: [UUID], sequence: ClimbSequence?,
                          aspect: Double, profile: BodyProfile, maxCount: Int = defaultMaxCount) -> [ShareSnapshot] {
        guard let sequence, !sequence.steps.isEmpty, !holds.isEmpty else { return [] }
        let initial = SequenceReplay.initialState(startHoldIDs: startHoldIDs, holds: holds)
        let states = SequenceReplay.states(of: sequence, initial: initial)
        let proportions = StickFigureSolver.Proportions.make(profile: profile)
        let byID = Dictionary(holds.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let bounds = CGRect(x: 0, y: 0, width: aspect, height: 1)

        /// 与 `SpotlightGeometry.toIso` 相同的映射：y ∈ 0…1，x ∈ 0…aspect。
        func iso(_ holdID: UUID?) -> CGPoint? {
            guard let holdID, let h = byID[holdID] else { return nil }
            return CGPoint(x: h.x * aspect, y: h.y)
        }

        return sampleIndices(count: sequence.steps.count, max: maxCount).map { i in
            let state = states[min(i + 1, states.count - 1)]
            let contacts = StickFigureSolver.Contacts(
                leftHand: iso(state[.leftHand]),
                rightHand: iso(state[.rightHand]),
                leftFoot: iso(state[.leftFoot]),
                rightFoot: iso(state[.rightFoot])
            )
            let pose = StickFigureSolver.solve(contacts: contacts, proportions: proportions, groundY: groundY, bounds: bounds)
            return ShareSnapshot(stepIndex: i, step: sequence.steps[i], pose: pose)
        }
    }
}
