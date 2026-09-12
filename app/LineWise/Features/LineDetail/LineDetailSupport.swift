import SwiftUI
import UIKit

/// 自动换行的胶囊布局（原因 8 选 1、筛选胶囊）。
struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: maxWidth == .infinity ? widest : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// 圆角按钮：次要动作（“记这一次 →”）。
struct SecondaryActionButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if let systemImage { Image(systemName: systemImage).font(.footnote.weight(.semibold)) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 隐藏系统返回键后，SwiftUI 会连带关掉边缘右滑返回；这里把手势接回来，只在栈深 > 1 时生效。
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        private weak var nav: UINavigationController?
        private weak var previousDelegate: UIGestureRecognizerDelegate?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let nav = findNavigationController(), let gesture = nav.interactivePopGestureRecognizer else { return }
            if gesture.delegate !== self {
                previousDelegate = gesture.delegate
                self.nav = nav
                gesture.delegate = self
                gesture.isEnabled = true
            }
        }

        override func willMove(toParent parent: UIViewController?) {
            if parent == nil, let gesture = nav?.interactivePopGestureRecognizer, gesture.delegate === self {
                gesture.delegate = previousDelegate
            }
            super.willMove(toParent: parent)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (nav?.viewControllers.count ?? 0) > 1
        }

        private func findNavigationController() -> UINavigationController? {
            var current: UIViewController? = self
            while let c = current {
                if let nav = c as? UINavigationController { return nav }
                if let nav = c.navigationController { return nav }
                current = c.parent
            }
            return nil
        }
    }
}

extension View {
    /// 让自定义返回按钮的页面仍能边缘右滑返回。
    func swipeBackEnabled() -> some View {
        background(SwipeBackEnabler().frame(width: 0, height: 0))
    }
}
