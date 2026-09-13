import SwiftUI

/// 全屏聚光灯图：默认整图 fit；双击在“整图 ↔ 取景到线”之间切换；捏合缩放、拖动；未放大时下拉关闭。
/// 自己做淡入淡出（呈现方用 `presentationBackground(.clear)` + 关掉系统转场）。
struct FullscreenSpotlightViewer: View {
    let line: Line
    var fallMarks: [FallMark] = []
    /// 关闭回调；不给则用 `dismiss`。
    var onClose: (() -> Void)? = nil
    /// 一进来就取景到线（截图 / 调试用）。
    var startFocused: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    /// 整体淡入淡出。
    @State private var shown = false
    /// 未放大时下拉关闭的位移。
    @State private var pull: CGSize = .zero
    @State private var closing = false

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5
    private static let focusPadding = 0.3
    private static let focusMinSize = 0.5

    private var aspect: Double { line.wall?.aspectRatio ?? 0.75 }
    private var isZoomed: Bool { scale > 1.05 }
    private var pullProgress: CGFloat { min(1, max(0, pull.height / 260)) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                ZStack {
                    Color.black
                        .opacity(1 - pullProgress * 0.6)
                    LineSpotlight(line: line, fill: false, maxPixel: 2048, showNumbers: true, fallMarks: fallMarks)
                        .scaleEffect(scale * (1 - pullProgress * 0.12))
                        .offset(CGSize(width: offset.width + pull.width, height: offset.height + pull.height))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .gesture(magnify(in: proxy.size).simultaneously(with: drag(in: proxy.size)))
                        .onTapGesture(count: 2) { location in
                            toggleZoom(at: location, in: proxy.size)
                        }
                        .accessibilityLabel("\(line.name) 的聚光灯图，双指缩放，双击取景到线")
                }
                .onAppear {
                    if startFocused { zoomToLine(in: proxy.size, animated: false) }
                }
            }
            .ignoresSafeArea()

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.1)))
            }
            .accessibilityLabel("关闭")
            .padding(.trailing, 16)
            .padding(.top, 8)
            .opacity(1 - pullProgress)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                Text(line.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(isZoomed ? "双击看整图" : "双击取景到线 · 下拉关闭")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.bottom, 12)
            .opacity(1 - pullProgress)
        }
        .animation(reduceMotion ? nil : .snappy, value: isZoomed)
        .opacity(shown ? 1 : 0)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) { shown = true }
        }
    }

    // MARK: 手势

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = clampScale(steadyScale * value.magnification)
                offset = clampedOffset(offset, size: size)
            }
            .onEnded { _ in
                steadyScale = scale
                settle(size: size)
            }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: isZoomed ? 6 : 14)
            .onChanged { value in
                if isZoomed {
                    let proposed = CGSize(width: steadyOffset.width + value.translation.width,
                                          height: steadyOffset.height + value.translation.height)
                    offset = clampedOffset(proposed, size: size)
                } else {
                    // 未放大：跟手下拉，准备关闭
                    pull = CGSize(width: value.translation.width * 0.4, height: max(0, value.translation.height))
                }
            }
            .onEnded { value in
                if isZoomed {
                    steadyOffset = offset
                    return
                }
                if value.translation.height > 120 || value.predictedEndTranslation.height > 260 {
                    close()
                } else {
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) { pull = .zero }
                }
            }
    }

    /// 双击：放大了就回整图；整图状态下取景到这条线。
    private func toggleZoom(at location: CGPoint, in size: CGSize) {
        Haptics.light()
        if isZoomed {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                scale = 1
                offset = .zero
                steadyScale = 1
                steadyOffset = .zero
            }
        } else {
            zoomToLine(in: size, animated: !reduceMotion)
        }
    }

    /// 把线的包围盒放到视图中央：等价于 `SpotlightGeometry(focus:)`，但通过 scale/offset 实现，好做动画。
    private func zoomToLine(in size: CGSize, animated: Bool) {
        guard let target = Self.focusTransform(holds: line.holds, aspect: aspect, size: size, maxScale: maxScale) else { return }
        let apply = {
            scale = target.scale
            offset = clampedOffset(target.offset, size: size, scale: target.scale)
            steadyScale = scale
            steadyOffset = offset
        }
        if animated { withAnimation(.spring(duration: 0.35), apply) } else { apply() }
    }

    /// 整图 fit 的基础上，要把 `holds` 的取景框放大到视图里所需的 scale 与 offset（scaleEffect 以中心为锚）。
    static func focusTransform(holds: [Hold], aspect: Double, size: CGSize, maxScale: CGFloat,
                               padding: Double = focusPadding, minSize: Double = focusMinSize) -> (scale: CGFloat, offset: CGSize)? {
        guard size.width > 0, size.height > 0,
              let focus = SpotlightGeometry.focusRect(for: holds, padding: padding, minSize: minSize) else { return nil }
        let base = SpotlightGeometry(size: size, aspect: aspect, fill: false)
        let focusW = focus.width * base.rect.width
        let focusH = focus.height * base.rect.height
        guard focusW > 0, focusH > 0 else { return nil }
        let s = min(maxScale, max(1, min(size.width / focusW, size.height / focusH)))
        let focusCenter = base.point(focus.midX, focus.midY)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let offset = CGSize(width: (center.x - focusCenter.x) * s, height: (center.y - focusCenter.y) * s)
        return (s, offset)
    }

    private func settle(size: CGSize) {
        withAnimation(reduceMotion ? nil : .snappy) {
            if scale < 1.02 {
                scale = 1
                offset = .zero
            } else {
                offset = clampedOffset(offset, size: size)
            }
            steadyScale = scale
            steadyOffset = offset
        }
    }

    private func close() {
        guard !closing else { return }
        closing = true
        Haptics.light()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            shown = false
            pull.height += 80
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 200))
            if let onClose { onClose() } else { dismiss() }
        }
    }

    private func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minScale * 0.8), maxScale)
    }

    /// 拖动范围：放大后的图不露出黑边；某个方向上图仍比视图小时，就在那个方向居中。
    private func clampedOffset(_ proposed: CGSize, size: CGSize, scale: CGFloat? = nil) -> CGSize {
        let s = scale ?? self.scale
        guard s > 1 else { return .zero }
        let base = SpotlightGeometry(size: size, aspect: aspect, fill: false).rect
        let maxX = max(0, (base.width * s - size.width) / 2)
        let maxY = max(0, (base.height * s - size.height) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }
}

#if DEBUG
#Preview("查看器 · 整图") {
    let sample = LineDetailPreviewData.make()
    return FullscreenSpotlightViewer(line: sample.line)
        .modelContainer(sample.container)
        .preferredColorScheme(.dark)
}

#Preview("查看器 · 取景") {
    let sample = LineDetailPreviewData.make()
    return FullscreenSpotlightViewer(line: sample.line, startFocused: true)
        .modelContainer(sample.container)
        .preferredColorScheme(.dark)
}
#endif
