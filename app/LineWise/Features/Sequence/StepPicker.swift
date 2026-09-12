import SwiftUI

/// “记这一次”里选“掉在第几步”：横向一排快照（含第 0 格起步）。
/// `selectedStep`：0 = 起步，N = 第 N 步之后（即 `sequence.steps[N - 1]` 那一步）。再点一次取消。
struct StepPicker: View {
    let line: Line
    let sequence: ClimbSequence
    @Binding var selectedStep: Int?

    @Environment(AppState.self) private var appState
    @State private var thumbImage: UIImage?

    private static let cellWidth: CGFloat = 84

    var body: some View {
        let aspect = line.wall?.aspectRatio ?? 0.75
        let numbers = HoldNumbering.numbers(for: line.holds)
        let thumbSize = SequenceThumbnail.size(height: 76, aspect: aspect, maxWidth: Self.cellWidth)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(0...sequence.steps.count, id: \.self) { cell in
                        let selected = selectedStep == cell
                        Button {
                            Haptics.selection()
                            withAnimation(.snappy) {
                                selectedStep = selected ? nil : cell
                            }
                        } label: {
                            VStack(spacing: 6) {
                                SequenceThumbnail(line: line, image: thumbImage, sequence: sequence, stepIndex: cell,
                                                  size: thumbSize, profile: appState.bodyProfile, cornerRadius: 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(selected ? Color.accent : Color.white.opacity(0.1), lineWidth: selected ? 2 : 1)
                                    )
                                Text(caption(cell: cell, numbers: numbers))
                                    .font(.caption2.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Color.accent : Color.subtle)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .monospacedDigit()
                                    .frame(width: Self.cellWidth)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(cell)
                        .accessibilityLabel(caption(cell: cell, numbers: numbers).replacingOccurrences(of: "\n", with: " · "))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .onAppear {
                if let selectedStep { proxy.scrollTo(selectedStep, anchor: .center) }
            }
        }
        .task(id: line.wall?.photoFileName) {
            guard let name = line.wall?.photoFileName else { thumbImage = nil; return }
            let loaded = await ImageStore.loadAsync(fileName: name, maxPixel: SequenceThumbnail.imageMaxPixel)
            if !Task.isCancelled { thumbImage = loaded }
        }
    }

    private func caption(cell: Int, numbers: [UUID: Int]) -> String {
        guard cell > 0, cell <= sequence.steps.count else { return "起步" }
        let step = sequence.steps[cell - 1]
        let label = numbers[step.holdID].map(HoldLabel.circled) ?? "?"
        return "第 \(cell) 步\n\(step.limb.title) → \(label)"
    }
}

#if DEBUG
#Preview("掉在第几步") {
    struct Host: View {
        let demo = SequencePreviewData.make()
        @State private var selected: Int? = 2
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Panel("掉在第几步") {
                    StepPicker(line: demo.line, sequence: demo.line.planSequence ?? ClimbSequence(), selectedStep: $selected)
                }
                Text("选中：\(selected.map(String.init) ?? "无")").foregroundStyle(Color.subtle)
            }
            .padding(16)
            .inkBackground()
            .environment(AppState())
            .modelContainer(demo.container)
            .preferredColorScheme(.dark)
        }
    }
    return Host()
}
#endif
