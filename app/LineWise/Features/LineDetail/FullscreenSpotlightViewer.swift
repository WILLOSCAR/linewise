import SwiftUI

/// 全屏可缩放的聚光灯图：双指缩放、拖动、双击复位。
struct FullscreenSpotlightViewer: View {
    let line: Line
    var fallMarks: [FallMark] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                ZStack {
                    Color.black
                    LineSpotlight(line: line, fill: false, maxPixel: 2048, showNumbers: true, fallMarks: fallMarks)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .gesture(magnify(in: proxy.size).simultaneously(with: drag(in: proxy.size)))
                        .onTapGesture(count: 2) { location in
                            toggleZoom(at: location, in: proxy.size)
                        }
                        .accessibilityLabel("\(line.name) 的聚光灯图，双指缩放")
                }
            }
            .ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("关闭")
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if scale > 1.05 {
                Text("双击复位")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: scale > 1.05)
        .statusBarHidden()
        .preferredColorScheme(.dark)
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
        DragGesture(minimumDistance: scale > 1 ? 6 : 20)
            .onChanged { value in
                guard scale > 1 else { return }
                let proposed = CGSize(width: steadyOffset.width + value.translation.width,
                                      height: steadyOffset.height + value.translation.height)
                offset = clampedOffset(proposed, size: size)
            }
            .onEnded { value in
                if scale <= 1 {
                    // 未放大时向下拉关闭
                    if value.translation.height > 120 { dismiss() }
                    return
                }
                steadyOffset = offset
            }
    }

    private func toggleZoom(at location: CGPoint, in size: CGSize) {
        let animation: Animation? = reduceMotion ? nil : .spring(duration: 0.35)
        withAnimation(animation) {
            if scale > 1.05 {
                scale = 1
                offset = .zero
            } else {
                scale = 2.5
                // 以双击点为中心放大
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let proposed = CGSize(width: (center.x - location.x) * (scale - 1),
                                      height: (center.y - location.y) * (scale - 1))
                offset = clampedOffset(proposed, size: size)
            }
            steadyScale = scale
            steadyOffset = offset
        }
        Haptics.light()
    }

    private func settle(size: CGSize) {
        let animation: Animation? = reduceMotion ? nil : .snappy
        withAnimation(animation) {
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

    private func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minScale * 0.8), maxScale)
    }

    private func clampedOffset(_ proposed: CGSize, size: CGSize) -> CGSize {
        guard scale > 1 else { return .zero }
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }
}
