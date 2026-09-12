import SwiftUI

// STUB — 由 Sequence 负责人替换为完整实现。以下三个类型的接口保持不变。

enum SequenceKind: String, CaseIterable, Identifiable {
    case plan
    case actual

    var id: String { rawValue }
    var title: String { self == .plan ? "计划" : "实际" }
}

/// 火柴人顺序编辑器（全屏）。
struct SequenceEditorView: View {
    let line: Line
    let kind: SequenceKind
    var onClose: () -> Void

    var body: some View {
        VStack {
            Text("顺序编辑器（待实现）")
            Button("关闭", action: onClose)
        }
        .inkBackground()
    }
}

/// 线路页里的“顺序”区块：计划/实际两张缩略图或“开始规划”，点进编辑器。
struct SequencePanel: View {
    let line: Line

    var body: some View {
        Panel("顺序") {
            Text("（待实现）").foregroundStyle(Color.subtle)
        }
    }
}

/// “记这一次”里选“掉在第几步”：横向一排快照，选中某一步。
struct StepPicker: View {
    let line: Line
    let sequence: ClimbSequence
    @Binding var selectedStep: Int?

    var body: some View {
        Text("步骤选择（待实现）").foregroundStyle(Color.subtle)
    }
}
