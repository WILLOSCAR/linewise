import Foundation

/// 顺序里的一步：哪只手脚到了哪个点。
struct SequenceStep: Codable, Hashable, Sendable {
    var limb: Limb
    var holdID: UUID
}

/// 火柴人的一串步骤。只存步骤，姿态由回放推导。
struct ClimbSequence: Codable, Hashable, Sendable {
    var steps: [SequenceStep] = []

    var isEmpty: Bool { steps.isEmpty }

    /// 在 `index`（含）之后追加一步：先截断后面的步骤，再追加。
    /// `index == -1` 表示从初始状态开始。
    func appending(_ step: SequenceStep, after index: Int) -> ClimbSequence {
        var copy = self
        let keep = max(0, min(index + 1, steps.count))
        copy.steps = Array(steps.prefix(keep))
        copy.steps.append(step)
        return copy
    }

    func removingLast() -> ClimbSequence {
        var copy = self
        if !copy.steps.isEmpty { copy.steps.removeLast() }
        return copy
    }
}

/// 某一步之后，四肢各在哪里。`nil` 表示在地面。
struct ContactState: Hashable, Sendable {
    var contacts: [Limb: UUID?]

    subscript(limb: Limb) -> UUID? {
        get { contacts[limb] ?? nil }
        set { contacts[limb] = newValue }
    }

    func isOnHold(_ limb: Limb) -> Bool { self[limb] != nil }
}

/// 回放：从起步姿态开始，逐步应用。
enum SequenceReplay {
    /// 初始姿态：双手在起步点，双脚在地面。
    /// 一个起步点：双手同点；两个：按左右分配；没有：双手也在地面（站着）。
    static func initialState(startHoldIDs: [UUID], holds: [Hold]) -> ContactState {
        var state = ContactState(contacts: [.leftFoot: nil, .rightFoot: nil, .leftHand: nil, .rightHand: nil])
        let starts = holds.filter { startHoldIDs.contains($0.id) }.sorted { $0.x < $1.x }
        switch starts.count {
        case 0:
            break
        case 1:
            state[.leftHand] = starts[0].id
            state[.rightHand] = starts[0].id
        default:
            state[.leftHand] = starts[0].id
            state[.rightHand] = starts[1].id
        }
        return state
    }

    /// 应用前 `count` 步之后的状态。
    static func state(of sequence: ClimbSequence, after count: Int, initial: ContactState) -> ContactState {
        var state = initial
        for step in sequence.steps.prefix(max(0, count)) {
            state[step.limb] = step.holdID
        }
        return state
    }

    /// 每一步之后的状态列表，第 0 个为初始。
    static func states(of sequence: ClimbSequence, initial: ContactState) -> [ContactState] {
        var result: [ContactState] = [initial]
        var state = initial
        for step in sequence.steps {
            state[step.limb] = step.holdID
            result.append(state)
        }
        return result
    }

    /// 完成判定：双手都在结束点。
    static func isComplete(_ state: ContactState, finishHoldID: UUID?) -> Bool {
        guard let finish = finishHoldID else { return false }
        return state[.leftHand] == finish && state[.rightHand] == finish
    }

    /// 计划与实际的差异：返回步骤索引（以较长者为准），两边不同或一边缺失即为差异。
    static func differingStepIndices(plan: ClimbSequence, actual: ClimbSequence) -> Set<Int> {
        var result: Set<Int> = []
        let n = max(plan.steps.count, actual.steps.count)
        for i in 0..<n {
            let a = i < plan.steps.count ? plan.steps[i] : nil
            let b = i < actual.steps.count ? actual.steps[i] : nil
            if a != b { result.insert(i) }
        }
        return result
    }
}
