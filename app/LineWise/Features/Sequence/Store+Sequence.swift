import Foundation

extension Store {
    /// 写回计划 / 实际顺序。空序列存 nil。
    func saveSequence(_ sequence: ClimbSequence?, kind: SequenceKind, line: Line) {
        let value = (sequence?.isEmpty ?? true) ? nil : sequence
        switch kind {
        case .plan: line.planSequence = value
        case .actual: line.actualSequence = value
        }
        line.updatedAt = .now
        save()
    }

    /// “复制为实际”：把计划整份复制到实际。返回撤销闭包。
    @discardableResult
    func copyPlanToActual(_ line: Line) -> () -> Void {
        let previous = line.actualSequence
        line.actualSequence = line.planSequence
        line.updatedAt = .now
        save()
        return { [self] in
            line.actualSequence = previous
            save()
        }
    }
}

extension Line {
    func sequence(for kind: SequenceKind) -> ClimbSequence? {
        kind == .plan ? planSequence : actualSequence
    }

    /// 计划与实际都存在时，不同的步骤数；否则 nil。
    var sequenceDifferenceCount: Int? {
        guard let plan = planSequence, let actual = actualSequence else { return nil }
        return SequenceReplay.differingStepIndices(plan: plan, actual: actual).count
    }
}
