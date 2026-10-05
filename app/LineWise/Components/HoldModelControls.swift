import SwiftUI

/// A non-blocking download/recognition status; manual circles and saving remain available.
struct HoldModelControls: View {
    @Bindable var manager: HoldModelManager
    var phase: HoldSegmentationSession.Phase = .idle
    var onRetry: () -> Void = {}

    var body: some View {
        switch manager.state {
        case .checking:
            EmptyView()
        case .notDownloaded, .failed:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(manager.state == .failed ? "下载未完成" : "抠出岩点轮廓").font(.subheadline.weight(.medium))
                    Text(manager.state == .failed ? "仍可手动点亮，稍后重试" : "首次下载约 80 MB，之后在本机识别")
                        .font(.caption).foregroundStyle(Color.subtle)
                }
                Spacer(minLength: 0)
                Button(manager.state == .failed ? "重试下载" : "下载") { manager.download() }
                    .buttonStyle(.bordered).tint(.accent)
                    .accessibilityIdentifier("hold-model-download")
            }
        case .downloading(let value):
            progress(title: "模型下载 \(Int(value * 100))%", value: value) {
                Button("取消") { manager.cancel() }.font(.caption)
            }
        case .cancelling:
            Text("正在取消下载").font(.caption).foregroundStyle(Color.subtle)
        case .ready:
            switch phase {
            case .idle:
                Text("点一下，圆圈会变成岩点轮廓").font(.caption).foregroundStyle(Color.subtle)
            case .preparing(let value):
                progress(title: "准备识别这张照片", value: value) { EmptyView() }
            case .processing(let completed, let total):
                progress(title: "正在抠形 · \(completed)/\(total)", value: Double(completed) / Double(max(1, total))) { EmptyView() }
            case .failed:
                HStack {
                    Text("暂时没能抠形，圆圈已保留").font(.caption).foregroundStyle(Color.subtle)
                    Spacer()
                    Button("重试抠形", action: onRetry).font(.caption)
                }
            }
        }
    }

    private func progress<Control: View>(title: String, value: Double, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.caption).foregroundStyle(Color.subtle)
                ProgressView(value: min(1, max(0, value))).tint(.accent)
            }
            control()
        }
        .accessibilityElement(children: .combine)
    }
}
