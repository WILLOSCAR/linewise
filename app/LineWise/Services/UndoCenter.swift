import Foundation
import SwiftUI

/// 5 秒撤销条。同一时间只有一条；新的到来时旧的视为已确认。
/// 标为 MainActor：`offer` 里的自动消失 Task 需要在主线程更新状态，否则 SwiftUI 不响应。
@MainActor
@Observable
final class UndoCenter {
    struct Offer: Identifiable {
        let id = UUID()
        let title: String
        let undo: () -> Void
    }

    private(set) var current: Offer?
    private var dismissTask: Task<Void, Never>?

    func offer(_ title: String, seconds: Double = 5, undo: @escaping () -> Void) {
        dismissTask?.cancel()
        let offer = Offer(title: title, undo: undo)
        withAnimation(.snappy) { current = offer }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            guard let self, self.current?.id == offer.id else { return }
            withAnimation(.snappy) { self.current = nil }
        }
    }

    func performUndo() {
        guard let offer = current else { return }
        dismissTask?.cancel()
        withAnimation(.snappy) { current = nil }
        offer.undo()
        Haptics.light()
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.snappy) { current = nil }
    }
}

// MARK: - 窗口级撤销条

/// 把撤销条挂在独立的 UIWindow 上：无论下面是 sheet 还是 fullScreenCover，都在最上层可见。
/// 只有撤销条自身的区域接收触摸，其余位置全部穿透。
@MainActor
final class UndoToastWindow {
    static let shared = UndoToastWindow()

    private final class FrameBox { var rect: CGRect = .zero }

    private final class PassthroughWindow: UIWindow {
        var interactiveFrame: () -> CGRect = { .zero }
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard interactiveFrame().contains(point) else { return nil }
            return super.hitTest(point, with: event)
        }
    }

    private struct Root: View {
        let undoCenter: UndoCenter
        let onFrame: (CGRect) -> Void

        var body: some View {
            VStack {
                Spacer()
                UndoToast()
                    .padding(.bottom, 8)
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .onAppear { onFrame(g.frame(in: .global)) }
                                .onChange(of: g.frame(in: .global)) { _, f in onFrame(f) }
                                .onDisappear { onFrame(.zero) }
                        }
                    )
            }
            .environment(undoCenter)
        }
    }

    private var window: PassthroughWindow?

    func install(in scene: UIWindowScene, undoCenter: UndoCenter) {
        guard window == nil else { return }
        let box = FrameBox()
        let w = PassthroughWindow(windowScene: scene)
        w.windowLevel = .alert - 1
        w.backgroundColor = .clear
        w.interactiveFrame = { box.rect }
        let host = UIHostingController(rootView: Root(undoCenter: undoCenter, onFrame: { box.rect = $0 }))
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.isHidden = false
        window = w
    }
}

/// 放在根视图的 background 里：拿到 UIWindowScene 后安装窗口级撤销条。
struct UndoToastWindowInstaller: UIViewRepresentable {
    let undoCenter: UndoCenter

    final class Probe: UIView {
        var onScene: ((UIWindowScene) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { onScene?(scene) }
        }
    }

    func makeUIView(context: Context) -> Probe {
        let v = Probe()
        v.isUserInteractionEnabled = false
        v.onScene = { scene in UndoToastWindow.shared.install(in: scene, undoCenter: undoCenter) }
        return v
    }

    func updateUIView(_ uiView: Probe, context: Context) {}
}

/// 撤销条视图。默认由 `UndoToastWindow` 挂在窗口级；预览或独立场景可直接使用。
struct UndoToast: View {
    @Environment(UndoCenter.self) private var undoCenter

    var body: some View {
        if let offer = undoCenter.current {
            HStack(spacing: 12) {
                Text(offer.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("撤销") { undoCenter.performUndo() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(offer.id)
        }
    }
}
