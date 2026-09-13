import SwiftUI

/// 首次引导：一张“点亮的墙”示意 + 三句话 + 一个黄色按钮。
struct IntroView: View {
    var onStart: () -> Void
    var onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?
    @State private var finished = false

    private static let revealDuration: Double = 1.2

    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(alignment: .leading, spacing: 22) {
                step(n: 1, title: "拍一面墙", detail: "一张照片就是一面墙，上面可以有好几条线。")
                step(n: 2, title: "点亮你的线", detail: "墙暗下去，只留你要爬的点。")
                step(n: 3, title: "记下掉在哪", detail: "下次进馆先看这一眼：掉在哪、为什么、试什么。")
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            Spacer(minLength: 16)
            VStack(spacing: 14) {
                Button("拍第一面墙", action: onStart).buttonStyle(BigButtonStyle())
                Button("先看看", action: onSkip)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.subtle)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .inkBackground()
        .presentationDragIndicator(.hidden)
        .task {
            // 一次性的“点亮”：光带从下往上扫过示意线，解释“点亮”是什么意思；减少动态时直接到位。
            guard !reduceMotion else { finished = true; return }
            try? await Task.sleep(for: .milliseconds(350))
            startedAt = .now
            try? await Task.sleep(for: .seconds(Self.revealDuration + 0.05))
            finished = true
        }
    }

    private func progress(at date: Date) -> Double {
        if finished || reduceMotion { return 1 }
        guard let startedAt else { return 0 }
        let t = min(max(date.timeIntervalSince(startedAt) / Self.revealDuration, 0), 1)
        return RevealView.easeInOut(t)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            TimelineView(.animation(paused: startedAt == nil || finished)) { context in
                SpotlightImage(
                    image: nil, aspect: 0.9, holds: HomeArt.sampleHolds,
                    startHoldIDs: [HomeArt.sampleHolds[0].id], finishHoldID: HomeArt.sampleHolds.last?.id,
                    fill: true, showNumbers: false, dim: 0.42, reveal: progress(at: context.date)
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 330)
            .mask(
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.62),
                    .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("线感")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("把墙关灯，只留你的线。")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtle)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 4)
        }
    }

    private func step(n: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.accent.opacity(0.14)).frame(width: 30, height: 30)
                Circle().strokeBorder(Color.accent, lineWidth: 1.5).frame(width: 30, height: 30)
                Text("\(n)").font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(Color.accent)
            }
            .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.subheadline).foregroundStyle(Color.subtle).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("首次引导") {
    IntroView(onStart: {}, onSkip: {})
        .preferredColorScheme(.dark)
}
#endif
