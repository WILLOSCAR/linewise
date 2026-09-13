import SwiftUI

/// 分享按钮：弹出分享图预览（保存到相册 / 分享…）。可放在 `Menu` 或工具栏里。
///
/// 流程：首次先提示隐私 → 底部 sheet 预览卡片（低清照片先画，高清位图在后台补上）→ 保存 / 系统分享面板。
struct ShareLineButton: View {
    let line: Line
    var label: String = "分享"

    @Environment(AppState.self) private var appState

    var body: some View {
        Button(action: tapped) {
            Label(label, systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel(label)
        .accessibilityHint("预览这条线的分享图，然后保存或分享")
    }

    private func tapped() {
        if appState.hasSeenSharePrivacyHint {
            openPreview()
            return
        }
        SharePresenter.confirm(
            title: "照片里如有他人请注意隐私",
            message: "分享图在本机生成，只会通过你选择的方式发出，不会上传。",
            confirmTitle: "知道了"
        ) {
            appState.hasSeenSharePrivacyHint = true
            openPreview()
        }
    }

    private func openPreview() {
        Haptics.light()
        Self.presentPreview(for: line, profile: appState.bodyProfile)
    }

    /// 打开某条线的分享预览（调试入口也用它）。
    @MainActor
    static func presentPreview(for line: Line, profile: BodyProfile = .default) {
        let model = ShareCardModel(line: line, profile: profile)
        let fileName = line.wall?.photoFileName
        SharePresenter.presentSheet { close in
            SharePreviewSheet(model: model, photoFileName: fileName, onClose: close)
        }
    }
}
