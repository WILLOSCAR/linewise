import SwiftUI

/// 编辑器底部的胶片条：左侧播放键 + 横向一排步骤快照。
/// 当前格黄框并自动滚到中间；点某格回退；停在中间时其后的格半透明，预示再拖会被替换。
struct SequenceFilmstrip: View {
    static let height: CGFloat = 96
    static let thumbHeight: CGFloat = 60

    let line: Line
    let scene: SequenceScene
    let image: UIImage?
    let model: SequenceEditorModel
    let profile: BodyProfile
    /// 与另一份顺序不同的步骤索引（0 起）。
    let differing: Set<Int>
    let isPlaying: Bool
    var onSelect: (Int) -> Void
    var onTogglePlay: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrolledCell: Int?

    var body: some View {
        let numbers = scene.numbers
        let thumbSize = SequenceThumbnail.size(height: Self.thumbHeight, aspect: scene.focusAspect, maxWidth: 84)
        HStack(spacing: 6) {
            playButton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(0...model.stepCount, id: \.self) { cell in
                        let step = cell == 0 ? nil : model.steps[cell - 1]
                        FilmCell(
                            cell: cell,
                            step: step,
                            holdLabel: step.flatMap { numbers[$0.holdID] }.map(HoldLabel.circled),
                            isCurrent: cell == model.currentCell,
                            willBeReplaced: model.willBeReplaced(cell: cell),
                            isComplete: cell == model.stepCount && cell > 0 && model.isSequenceComplete,
                            differs: cell > 0 && differing.contains(cell - 1),
                            thumbnail: SequenceThumbnail(
                                line: line, image: image, sequence: model.sequence, stepIndex: cell,
                                size: thumbSize, profile: profile, cornerRadius: 10, scene: scene
                            )
                        )
                        .id(cell)
                        .onTapGesture { onSelect(cell) }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .animation(reduceMotion ? nil : .snappy, value: model.stepCount)
            }
            .scrollPosition(id: $scrolledCell, anchor: .center)
            .onChange(of: model.currentCell, initial: true) { _, cell in
                withAnimation(reduceMotion ? nil : .snappy) { scrolledCell = cell }
            }
            .onChange(of: model.stepCount) { _, _ in
                // 刚追加的格要等布局出来再滚过去。
                let cell = model.currentCell
                Task { @MainActor in
                    withAnimation(reduceMotion ? nil : .snappy) { scrolledCell = cell }
                }
            }
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("步骤")
    }

    private var playButton: some View {
        Button(action: onTogglePlay) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(isPlaying ? Color.accent.opacity(0.18) : Color.white.opacity(0.08), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .foregroundStyle(isPlaying ? Color.accent : .white)
        .disabled(model.stepCount == 0)
        .opacity(model.stepCount == 0 ? 0.35 : 1)
        .animation(.snappy(duration: 0.2), value: isPlaying)
        .accessibilityLabel(isPlaying ? "停止回放" : "回放顺序")
        .padding(.leading, 2)
        // 与缩略图（不含说明文字）垂直居中。
        .frame(height: Self.thumbHeight + 6, alignment: .center)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// 胶片条的一格：小图（左上角步号）+ 一行“右手 → ③”。
private struct FilmCell: View {
    let cell: Int
    let step: SequenceStep?
    let holdLabel: String?
    let isCurrent: Bool
    let willBeReplaced: Bool
    let isComplete: Bool
    let differs: Bool
    let thumbnail: SequenceThumbnail

    var body: some View {
        VStack(spacing: 5) {
            thumbnail
                .overlay(alignment: .topLeading) { badge }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isCurrent ? Color.accent : Color.white.opacity(0.10), lineWidth: isCurrent ? 2 : 1)
                )
            caption
        }
        .opacity(willBeReplaced ? 0.42 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
    }

    private var badge: some View {
        Group {
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 16, height: 16)
            } else if cell > 0 {
                Text("\(cell)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 16, minHeight: 16)
            }
        }
        .foregroundStyle(isCurrent || isComplete ? Color.ink : .white)
        .background(isCurrent || isComplete ? Color.accent : Color.black.opacity(0.55), in: Capsule())
        .padding(4)
    }

    private var caption: some View {
        HStack(spacing: 3) {
            if let step {
                Image(systemName: step.limb.symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(step.limb.isLeft ? Color.white.opacity(0.9) : Color.accent)
                Text("→ \(holdLabel ?? "?")")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isCurrent ? .white : Color.subtle)
            } else {
                Text("起步")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isCurrent ? .white : Color.subtle)
            }
            if differs {
                Circle().fill(Color.coral).frame(width: 5, height: 5)
            }
        }
        .lineLimit(1)
        .frame(height: 14)
    }

    private var accessibilityText: String {
        guard let step else { return "起步，双手在起步点" }
        var text = "第 \(cell) 步，\(step.limb.title)到\(holdLabel ?? "")"
        if isComplete { text += "，完成" }
        if differs { text += "，与另一份不同" }
        if willBeReplaced { text += "，再拖会被替换" }
        return text
    }
}
