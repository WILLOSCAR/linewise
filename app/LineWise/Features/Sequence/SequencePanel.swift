import SwiftData
import SwiftUI

/// 线路页里的“顺序”区块：计划 / 实际两张卡，或一句话 + “开始规划”；点卡进编辑器。
struct SequencePanel: View {
    let line: Line

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(UndoCenter.self) private var undoCenter
    @State private var editing: SequenceKind?
    @State private var thumbImage: UIImage?

    var body: some View {
        Panel("顺序") {
            content
        }
        .fullScreenCover(item: $editing) { kind in
            SequenceEditorView(line: line, kind: kind) { editing = nil }
        }
        .task(id: line.wall?.photoFileName) {
            guard line.hasPhoto, let name = line.wall?.photoFileName else { thumbImage = nil; return }
            let loaded = await ImageStore.loadAsync(fileName: name, maxPixel: SequenceThumbnail.imageMaxPixel)
            if !Task.isCancelled { thumbImage = loaded }
        }
    }

    @ViewBuilder
    private var content: some View {
        if scene.holds.isEmpty {
            // 没有点位就没法拖手脚；没照片但有点位的线用底板 + 点位示意，一样能规划。
            Text("没有点位的线不能规划顺序")
                .font(.subheadline)
                .foregroundStyle(Color.subtle)
        } else if line.planSequence == nil && line.actualSequence == nil {
            emptyState
        } else {
            cards
        }
    }

    private var scene: SequenceScene { SequenceScene(line: line) }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("爬前把手脚拖上墙，把读线留下来")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Button {
                Haptics.light()
                editing = .plan
            } label: {
                Label("开始规划", systemImage: "figure.climbing")
            }
            .buttonStyle(CompactButtonStyle())
        }
    }

    private var cards: some View {
        let scene = scene
        // 缩略图取景到这条线（与编辑器同一套 focus），形状跟着取景区域走。
        let thumbSize = SequenceThumbnail.size(height: 132, aspect: scene.focusAspect, maxWidth: 150)
        // 两张卡等高：小图 + 标题行 (+ 差异小字)。
        let showsDifference = line.sequenceDifferenceCount != nil
        let cardHeight = thumbSize.height + 20 + 8 + 20 + (showsDifference ? 20 : 0)
        return HStack(alignment: .top, spacing: 12) {
            card(kind: .plan, scene: scene, thumbSize: thumbSize, height: cardHeight)
            card(kind: .actual, scene: scene, thumbSize: thumbSize, height: cardHeight)
        }
    }

    @ViewBuilder
    private func card(kind: SequenceKind, scene: SequenceScene, thumbSize: CGSize, height: CGFloat) -> some View {
        if let seq = line.sequence(for: kind), !seq.isEmpty {
            filledCard(kind: kind, scene: scene, sequence: seq, thumbSize: thumbSize, height: height)
        } else {
            emptyCard(kind: kind, height: height)
        }
    }

    private func filledCard(kind: SequenceKind, scene: SequenceScene, sequence: ClimbSequence, thumbSize: CGSize, height: CGFloat) -> some View {
        let complete = SequenceReplay.isComplete(SequenceReplay.state(of: sequence, after: sequence.steps.count, initial: scene.initial), finishHoldID: scene.finishHoldID)
        let difference = kind == .actual ? line.sequenceDifferenceCount : nil
        return Button {
            Haptics.light()
            editing = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                SequenceThumbnail(line: line, image: thumbImage, sequence: sequence, stepIndex: sequence.steps.count,
                                  size: thumbSize, profile: appState.bodyProfile, cornerRadius: 12, scene: scene)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                    Text(kind.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(sequence.steps.count) 步")
                        .font(.caption)
                        .foregroundStyle(Color.subtle)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    if complete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.accent)
                            .accessibilityLabel("已完成")
                    }
                }
                if let difference {
                    differenceText(difference)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .top)
            .background(Color.panelElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title)顺序，\(sequence.steps.count) 步" + (difference.map { $0 > 0 ? "，与计划不同 \($0) 步" : "，与计划一致" } ?? ""))
    }

    /// 差异步数：coral 小字（Coral 只用于“不一样/掉了”这一类信息）。
    private func differenceText(_ count: Int) -> some View {
        let differs = count > 0
        return Text(differs ? "与计划不同 \(count) 步" : "与计划一致")
            .font(.caption2.weight(differs ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(differs ? Color.coral : Color.subtle)
    }

    private func emptyCard(kind: SequenceKind, height: CGFloat) -> some View {
        let canCopy = kind == .actual && (line.planSequence?.isEmpty == false)
        return Button {
            Haptics.light()
            if canCopy {
                let undo = Store(context).copyPlanToActual(line)
                undoCenter.offer("已从计划复制", undo: undo)
            }
            editing = kind
        } label: {
            VStack(spacing: 8) {
                Image(systemName: canCopy ? "doc.on.doc" : "figure.climbing")
                    .font(.title3)
                    .foregroundStyle(Color.accent)
                Text(canCopy ? "复制计划后修改" : (kind == .plan ? "规划一份" : "记实际顺序"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Text(kind.title)
                    .font(.caption)
                    .foregroundStyle(Color.subtle)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 区块内的小按钮（比 BigButtonStyle 轻）。
private struct CompactButtonStyle: ButtonStyle {
    var prominent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(prominent ? Color.accent : Color.white.opacity(0.1), in: Capsule())
            .foregroundStyle(prominent ? Color.ink : .white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("区块 · 计划 + 实际") {
    let demo = SequencePreviewData.make(plan: true, actual: true)
    return ScrollView {
        VStack(spacing: 12) {
            SequencePanel(line: demo.line)
        }
        .padding(16)
    }
    .inkBackground()
    .environment(AppState())
    .environment(UndoCenter())
    .modelContainer(demo.container)
    .preferredColorScheme(.dark)
}

#Preview("区块 · 只有计划 / 空 / 无照片") {
    let planOnly = SequencePreviewData.make(plan: true, actual: false)
    let empty = SequencePreviewData.make(plan: false)
    let noPhoto = SequencePreviewData.make(withPhoto: false, plan: false)
    return ScrollView {
        VStack(spacing: 12) {
            SequencePanel(line: planOnly.line).modelContainer(planOnly.container)
            SequencePanel(line: empty.line).modelContainer(empty.container)
            SequencePanel(line: noPhoto.line).modelContainer(noPhoto.container)
        }
        .padding(16)
    }
    .inkBackground()
    .environment(AppState())
    .environment(UndoCenter())
    .preferredColorScheme(.dark)
}
#endif
