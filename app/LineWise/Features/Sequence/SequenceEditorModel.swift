import Foundation

/// 顺序编辑器的纯状态机：一串步骤 + “当前停在第几步之后”。
/// 不含视图、不含持久化，方便单测。视图层只负责把手势翻译成 `apply / rewind / undo`。
struct SequenceEditorModel: Equatable {
    struct ApplyResult: Equatable {
        /// 因为从中间某一步继续拖而被替换掉的后续步骤（放进撤销条）。
        var truncated: [SequenceStep]
        /// 这一步是否让顺序刚好达到“完成”（双手都到结束点）。
        var justCompleted: Bool
    }

    private(set) var sequence: ClimbSequence
    /// 当前显示的是第几步之后的状态：-1 为起步，`steps.count - 1` 为最后一步。
    private(set) var currentIndex: Int
    let initial: ContactState
    let finishHoldID: UUID?

    init(sequence: ClimbSequence?, initial: ContactState, finishHoldID: UUID?) {
        let seq = sequence ?? ClimbSequence()
        self.sequence = seq
        self.initial = initial
        self.finishHoldID = finishHoldID
        self.currentIndex = seq.steps.count - 1
    }

    // MARK: 读

    var steps: [SequenceStep] { sequence.steps }
    var stepCount: Int { sequence.steps.count }

    /// 当前格索引：0 = 起步，N = 第 N 步之后。与右侧列表的格子一一对应。
    var currentCell: Int { currentIndex + 1 }

    var currentState: ContactState { state(atCell: currentCell) }

    /// 每一格的状态，第 0 个为起步。
    var states: [ContactState] { SequenceReplay.states(of: sequence, initial: initial) }

    func state(atCell cell: Int) -> ContactState {
        SequenceReplay.state(of: sequence, after: cell, initial: initial)
    }

    /// 当前格是否已完成。
    var isComplete: Bool { SequenceReplay.isComplete(currentState, finishHoldID: finishHoldID) }

    /// 整条顺序（最后一格）是否完成。
    var isSequenceComplete: Bool { isComplete(atCell: stepCount) }

    func isComplete(atCell cell: Int) -> Bool {
        SequenceReplay.isComplete(state(atCell: cell), finishHoldID: finishHoldID)
    }

    var canUndo: Bool { !sequence.isEmpty }

    /// 是否停在中间某一步：此时再拖会替换后面的步骤。
    var isRewound: Bool { currentIndex < stepCount - 1 }

    // MARK: 写

    /// 把某只手/脚放到某个点。拖到它当前所在的点视为无操作（返回 nil）。
    @discardableResult
    mutating func apply(limb: Limb, holdID: UUID) -> ApplyResult? {
        guard currentState[limb] != holdID else { return nil }
        let wasComplete = isComplete
        let truncated = Array(sequence.steps.dropFirst(currentIndex + 1))
        sequence = sequence.appending(SequenceStep(limb: limb, holdID: holdID), after: currentIndex)
        currentIndex = sequence.steps.count - 1
        return ApplyResult(truncated: truncated, justCompleted: !wasComplete && isComplete)
    }

    /// 回到某一格（0 = 起步）。越界会被夹回范围。
    mutating func rewind(toCell cell: Int) {
        currentIndex = min(max(cell, 0), stepCount) - 1
    }

    /// 移除最后一步；当前位置若超出则跟着回退。
    mutating func undo() {
        guard canUndo else { return }
        sequence = sequence.removingLast()
        currentIndex = min(currentIndex, stepCount - 1)
    }

    /// 整体替换（撤销条恢复、复制等），位置回到最后一步。
    mutating func replace(with sequence: ClimbSequence?) {
        self.sequence = sequence ?? ClimbSequence()
        currentIndex = stepCount - 1
    }
}
