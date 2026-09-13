import LinkPresentation
import SwiftUI
import UIKit

/// 从最上层的 UIViewController 弹系统面板。
/// 用 UIKit 而不是 `.sheet`/`.alert`：分享按钮可能放在 `Menu` 里，那里挂的 SwiftUI 弹层不会出现。
@MainActor
enum SharePresenter {
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        let windows = scenes.flatMap(\.windows)
        let window = windows.first(where: \.isKeyWindow) ?? windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// 系统分享面板。
    static func present(activityItems: [Any], completion: (() -> Void)? = nil) {
        guard let top = topViewController() else { return }
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.overrideUserInterfaceStyle = .dark
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 1, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        vc.completionWithItemsHandler = { _, _, _, _ in completion?() }
        top.present(vc, animated: true)
    }

    /// 分享预览：把 SwiftUI 面板作为底部 sheet 盖在最上层（按钮在 `Menu` 里时 `.sheet` 不会出现，所以走 UIKit）。
    /// `content` 收到一个关闭闭包。
    @discardableResult
    static func presentSheet<V: View>(_ content: (@escaping () -> Void) -> V) -> UIViewController? {
        guard let top = topViewController() else { return nil }
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        let close: () -> Void = { [weak host] in host?.dismiss(animated: true) }
        host.rootView = AnyView(content(close))
        host.overrideUserInterfaceStyle = .dark
        host.view.backgroundColor = UIColor(Color.ink)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        top.present(host, animated: true)
        return host
    }

    /// 二选一确认框。
    static func confirm(title: String, message: String, confirmTitle: String, cancelTitle: String = "取消", onConfirm: @escaping () -> Void) {
        guard let top = topViewController() else { onConfirm(); return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: .default) { _ in onConfirm() })
        top.present(alert, animated: true)
    }

    /// 只有一个“好”的提示。
    static func info(title: String, message: String) {
        guard let top = topViewController() else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "好", style: .default))
        top.present(alert, animated: true)
    }
}

/// 分享面板里的图片项：带标题与缩略图预览。
final class ShareCardActivityItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String
    private lazy var thumbnail: UIImage = ImageStore.downsample(image, maxLongEdge: 480)

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let meta = LPLinkMetadata()
        meta.title = title
        meta.imageProvider = NSItemProvider(object: thumbnail)
        meta.iconProvider = NSItemProvider(object: thumbnail)
        return meta
    }
}
