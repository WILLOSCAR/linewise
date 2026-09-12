import SwiftUI

/// 分享按钮：生成分享图并弹出系统分享面板。可放在 `Menu` 或工具栏里。
///
/// 流程：首次先提示隐私 → 后台加载墙照片 → 主线程 `ImageRenderer` 渲染 1080×1920 → 系统分享面板。
struct ShareLineButton: View {
    let line: Line
    var label: String = "分享"

    @Environment(AppState.self) private var appState
    @State private var isRendering = false

    var body: some View {
        Button(action: tapped) {
            if isRendering {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("生成中…")
                }
            } else {
                Label(label, systemImage: "square.and.arrow.up")
            }
        }
        .disabled(isRendering)
        .accessibilityLabel(label)
        .accessibilityHint("生成一张分享图，然后打开系统分享面板")
    }

    private func tapped() {
        guard !isRendering else { return }
        if appState.hasSeenSharePrivacyHint {
            share()
            return
        }
        SharePresenter.confirm(
            title: "照片里如有他人请注意隐私",
            message: "分享图在本机生成，只会通过你选择的方式发出，不会上传。",
            confirmTitle: "知道了"
        ) {
            appState.hasSeenSharePrivacyHint = true
            share()
        }
    }

    private func share() {
        isRendering = true
        Haptics.light()
        let model = ShareCardModel(line: line)
        let profile = appState.bodyProfile
        let fileName = line.wall?.photoFileName
        Task { @MainActor in
            var photo: UIImage?
            if let fileName, !model.holds.isEmpty {
                photo = await ImageStore.loadAsync(fileName: fileName, maxPixel: 2048)
            }
            // 让按钮先画出 ProgressView，再做主线程渲染。
            await Task.yield()
            let rendered = ShareCardRenderer.render(model: model, image: photo, profile: profile)
            isRendering = false
            guard let rendered else {
                SharePresenter.info(title: "没能生成分享图", message: "请再试一次。")
                return
            }
            Haptics.success()
            SharePresenter.present(activityItems: [ShareCardActivityItem(image: rendered, title: model.shareTitle)])
        }
    }
}
