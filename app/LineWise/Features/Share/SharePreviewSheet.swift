import Photos
import SwiftUI

/// 分享前的预览：卡片缩放到屏宽弹出，下面两个按钮“保存到相册 / 分享…”。
///
/// 打开时先用低清照片直接画 SwiftUI 卡片（不卡），等 sheet 弹完再在主线程渲染 1080×1920 的位图备用；
/// 用户比渲染先一步点按钮时，按钮上转一下再继续。
struct SharePreviewSheet: View {
    let model: ShareCardModel
    let photoFileName: String?
    var onClose: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var previewImage: UIImage?
    @State private var fullImage: UIImage?
    @State private var rendered: UIImage?
    @State private var appeared = false
    @State private var busy: Action?
    @State private var savedFlash = false
    @State private var errorText: String?
    @State private var includesSnapshots = true

    enum Action { case save, share }

    /// 高清渲染用的照片长边；预览用一半就够。
    static let fullPhotoPixel = 2048
    static let previewPhotoPixel = 1024

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geo in
                let scale = Self.cardScale(in: geo.size)
                previewCard
                    .scaleEffect(scale, anchor: .center)
                    .frame(width: ShareCardView.size.width * scale, height: ShareCardView.size.height * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .animation(.easeOut(duration: 0.25), value: previewImage == nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            if model.actualSequence?.steps.isEmpty == false {
                Toggle("附上实际顺序", isOn: $includesSnapshots)
                    .font(.subheadline)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .disabled(busy != nil)
            }
            buttons
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(Color.coral)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .inkBackground()
        .preferredColorScheme(.dark)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) { appeared = true }
            }
        }
        .task(id: includesSnapshots) {
            rendered = nil
            await loadAndPrerender()
        }
        .onChange(of: includesSnapshots) { _, _ in rendered = nil }
    }

    private var previewCard: ShareCardView {
        var card = ShareCardView(model: model, image: fullImage ?? previewImage)
        card.includesSnapshots = includesSnapshots
        return card
    }

    // MARK: 子视图

    private var header: some View {
        HStack {
            Text("分享图")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("关闭")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button { Task { await perform(.save) } } label: {
                actionLabel(
                    savedFlash ? "已保存" : "保存到相册",
                    systemImage: savedFlash ? "checkmark" : "square.and.arrow.down",
                    spinning: busy == .save
                )
            }
            .buttonStyle(ShareActionButtonStyle(prominent: false))
            .disabled(busy != nil)
            .accessibilityLabel("保存到相册")

            Button { Task { await perform(.share) } } label: {
                actionLabel("分享…", systemImage: "square.and.arrow.up", spinning: busy == .share)
            }
            .buttonStyle(ShareActionButtonStyle(prominent: true))
            .disabled(busy != nil)
            .accessibilityLabel("分享")
        }
    }

    private func actionLabel(_ title: String, systemImage: String, spinning: Bool) -> some View {
        HStack(spacing: 8) {
            if spinning {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: systemImage).font(.body.weight(.semibold))
            }
            Text(title)
        }
        .contentTransition(.opacity)
        .animation(.snappy(duration: 0.2), value: title)
    }

    // MARK: 逻辑

    /// 卡片缩到可用区域里（宽优先）。
    static func cardScale(in available: CGSize) -> CGFloat {
        guard available.width > 0, available.height > 0 else { return 0.5 }
        let byWidth = available.width / ShareCardView.size.width
        let byHeight = available.height / ShareCardView.size.height
        return max(0.2, min(byWidth, byHeight))
    }

    @MainActor
    private func loadAndPrerender() async {
        if let photoFileName, model.hasHolds {
            previewImage = await ImageStore.loadAsync(fileName: photoFileName, maxPixel: Self.previewPhotoPixel)
            fullImage = await ImageStore.loadAsync(fileName: photoFileName, maxPixel: Self.fullPhotoPixel)
        }
        // 等弹出动画结束再占主线程渲染高清图。
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled, rendered == nil else { return }
        rendered = ShareCardRenderer.render(model: model, image: fullImage ?? previewImage, includesSnapshots: includesSnapshots)
    }

    @MainActor
    private func ensureRendered() async -> UIImage? {
        if let rendered { return rendered }
        if fullImage == nil, let photoFileName, model.hasHolds {
            fullImage = await ImageStore.loadAsync(fileName: photoFileName, maxPixel: Self.fullPhotoPixel)
        }
        await Task.yield()
        let image = ShareCardRenderer.render(model: model, image: fullImage ?? previewImage, includesSnapshots: includesSnapshots)
        rendered = image
        return image
    }

    @MainActor
    private func perform(_ action: Action) async {
        guard busy == nil else { return }
        busy = action
        Haptics.light()
        errorText = nil
        defer { busy = nil }
        guard let image = await ensureRendered() else {
            errorText = "没能生成分享图，请再试一次。"
            return
        }
        switch action {
        case .share:
            Haptics.success()
            SharePresenter.present(activityItems: [ShareCardActivityItem(image: image, title: model.shareTitle)])
        case .save:
            do {
                try await SharePhotoSaver.save(image)
                Haptics.success()
                withAnimation(.snappy(duration: 0.2)) { savedFlash = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.snappy(duration: 0.2)) { savedFlash = false }
                }
            } catch {
                Haptics.warning()
                errorText = error.localizedDescription
            }
        }
    }
}

/// 预览面板的两个按钮：卡片里已经满是黄色亮点，按钮改用白 / 材质，不再抢一个黄。
struct ShareActionButtonStyle: ButtonStyle {
    var prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(prominent ? Color.white : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(prominent ? Color.ink : .white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.5)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// 存到相册（只申请“添加”权限）。
enum SharePhotoSaver {
    enum SaveError: LocalizedError {
        case denied
        var errorDescription: String? {
            "没有相册写入权限。可以在系统设置里打开，或直接用“分享…”。"
        }
    }

    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

#if DEBUG
#Preview("分享预览") {
    let model = ShareCardModel.demo()
    Color.ink.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            SharePreviewSheet(model: model, photoFileName: nil)
                .presentationDetents([.large])
        }
        .preferredColorScheme(.dark)
}
#endif
