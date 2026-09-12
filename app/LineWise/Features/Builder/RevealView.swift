import SwiftUI

/// 完成后的揭示动画：一道光从下往上扫过，点依次亮起。约 1.2 秒，轻触跳过。
struct RevealView: View {
    let image: UIImage?
    let aspect: Double
    let holds: [Hold]
    let startHoldIDs: [UUID]
    let finishHoldID: UUID?
    let title: String
    let subtitle: String?
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date = .now
    @State private var skipped = false
    @State private var completed = false
    @State private var finishTask: Task<Void, Never>?

    static let duration: Double = 1.2
    static let holdAfter: Double = 0.4

    var body: some View {
        VStack(spacing: 0) {
            BuilderTopBar(step: 2) { EmptyView() } trailing: { EmptyView() }
            TimelineView(.animation(paused: completed || skipped || reduceMotion)) { context in
                let progress = progress(at: context.date)
                ZStack {
                    Color.ink
                    SpotlightImage(
                        image: image,
                        aspect: aspect,
                        holds: holds,
                        startHoldIDs: startHoldIDs,
                        finishHoldID: finishHoldID,
                        fill: false,
                        showNumbers: true,
                        reveal: progress
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { skip() }
            .accessibilityLabel("正在点亮你的线")
            .accessibilityHint("轻触跳过动画")
            footer
        }
        .inkBackground()
        .task { await run() }
        .onDisappear { finishTask?.cancel() }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(completed ? "建好了" : "点亮中…")
                .font(.headline)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
            if completed {
                Text([title, subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Color.subtle)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text("轻触任意位置跳过")
                    .font(.caption)
                    .foregroundStyle(Color.subtle)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .padding(.horizontal, 16)
        .background(Color.ink)
        .animation(.snappy(duration: 0.3), value: completed)
    }

    // MARK: 进度

    private func progress(at date: Date) -> Double {
        if reduceMotion || skipped || completed { return 1 }
        let t = min(max(date.timeIntervalSince(startedAt) / Self.duration, 0), 1)
        return Self.easeInOut(t)
    }

    static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func run() async {
        startedAt = .now
        if !reduceMotion {
            try? await Task.sleep(for: .seconds(Self.duration))
        }
        guard !Task.isCancelled, !skipped else { return }
        await finish()
    }

    private func skip() {
        guard !completed, !skipped else { return }
        skipped = true
        finishTask?.cancel()
        finishTask = Task { @MainActor in
            await finish()
        }
    }

    @MainActor
    private func finish() async {
        guard !completed else { return }
        withAnimation(.snappy) { completed = true }
        Haptics.success()
        try? await Task.sleep(for: .seconds(Self.holdAfter))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}
