#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 调试入口：不改 RootView，用启动参数直接把顺序界面盖到当前窗口上，方便命令行截图。
///
///   xcrun simctl launch <udid> com.linewise.app -seedDemo -openSequenceEditor          # 编辑器（计划）
///   xcrun simctl launch <udid> com.linewise.app -seedDemo -openSequenceEditor actual   # 编辑器（实际）
///   xcrun simctl launch <udid> com.linewise.app -seedDemo -openSequencePanel           # 线路页区块 + 掉落步选择
///   xcrun simctl launch <udid> com.linewise.app -seedDemo -openSequencePanel empty     # 区块空态
///   附加 -seedActual：给演示线造一份与计划差两步的实际顺序
///   附加 -sequenceScript "rewind:3,rf:3,lh:7,rh:7,miss,undo"：在编辑器里回放一段拖拽（见 SequenceEditorView）
///
/// 由 `SequenceDebugBoot.m` 的 `+load` 在应用启动完成后调用。
@objc(LWSequenceDebugLauncher)
final class SequenceDebugLauncher: NSObject {
    enum Mode {
        case editor(SequenceKind)
        case panel
    }

    @objc static func installIfRequested() {
        let args = CommandLine.arguments
        let mode: Mode?
        if let i = args.firstIndex(of: "-openSequenceEditor") {
            let kind = (i + 1 < args.count && args[i + 1] == "actual") ? SequenceKind.actual : .plan
            mode = .editor(kind)
        } else if args.contains("-openSequencePanel") {
            mode = .panel
        } else {
            mode = nil
        }
        guard let mode else { return }
        Task { @MainActor in
            // 等 RootView 的 onAppear 把演示数据写完。
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(600))
                if present(mode) { return }
            }
        }
    }

    @MainActor
    @discardableResult
    private static func present(_ mode: Mode) -> Bool {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
              var top = window.rootViewController else { return false }
        while let presented = top.presentedViewController { top = presented }

        let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
        let config = ModelConfiguration("LineWise", schema: schema, isStoredInMemoryOnly: false)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else { return false }
        let context = container.mainContext
        let lines = (try? context.fetch(FetchDescriptor<Line>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        // `-openSequencePanel empty` 看没有任何顺序的线的空态。
        let wantsEmpty = CommandLine.arguments.contains("empty")
        let picked = wantsEmpty
            ? lines.first(where: { $0.hasPhoto && $0.planSequence == nil && $0.actualSequence == nil })
            : lines.first(where: { $0.hasPhoto && $0.planSequence != nil })
        guard let line = picked ?? lines.first(where: \.hasPhoto) else { return false }

        // `-seedActual`：给演示线造一份和计划差两步的“实际”，方便看差异标注。
        if CommandLine.arguments.contains("-seedActual"), line.actualSequence == nil, let plan = line.planSequence, plan.steps.count >= 3 {
            var steps = plan.steps
            steps[steps.count - 2].limb = steps[steps.count - 2].limb == .leftHand ? .rightHand : .leftHand
            steps.removeLast()
            line.actualSequence = ClimbSequence(steps: steps)
            Store(context).save()
        }

        let root = SequenceDebugScreen(line: line, mode: mode)
            .environment(AppState())
            .environment(UndoCenter())
            .modelContainer(container)
            .preferredColorScheme(.dark)
            .tint(.accent)
        let host = UIHostingController(rootView: root)
        host.modalPresentationStyle = .fullScreen
        top.present(host, animated: false)
        return true
    }
}

private struct SequenceDebugScreen: View {
    let line: Line
    let mode: SequenceDebugLauncher.Mode

    @State private var selectedStep: Int? = 3

    var body: some View {
        switch mode {
        case .editor(let kind):
            SequenceEditorView(line: line, kind: kind, onClose: {})
        case .panel:
            ScrollView {
                VStack(spacing: 12) {
                    SequencePanel(line: line)
                    if let seq = line.actualSequence ?? line.planSequence {
                        Panel("掉在第几步") {
                            StepPicker(line: line, sequence: seq, selectedStep: $selectedStep)
                        }
                    }
                }
                .padding(16)
                .padding(.top, 40)
            }
            .inkBackground()
        }
    }
}
#endif
