import SwiftUI

// MARK: - 筛选条

/// 首页筛选胶囊：选中态是一块会滑动的黄色底（`matchedGeometryEffect`），而不是各自变色。
struct HomeFilterBar: View {
    @Binding var selection: HomeFilter
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HomeFilter.allCases) { f in
                let selected = selection == f
                Button {
                    guard !selected else { return }
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                        selection = f
                    }
                } label: {
                    Text(f.title)
                        .font(.subheadline.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.ink : Color.white.opacity(0.8))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.accent)
                                    .matchedGeometryEffect(id: "selection", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(f.title)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("筛选")
    }
}

// MARK: - 状态胶囊

/// 卡片上的小胶囊：已上 / 拆了 / 第 N 轮。
struct StatusCapsule: View {
    var title: String
    var systemImage: String?
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 9, weight: .bold)) }
            Text(title)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }
}

// MARK: - “+” 发光按钮

/// 首页右下角的黄色发光按钮：按压缩放 + 触感。
struct GlowPlusButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.ink)
                .frame(width: 58, height: 58)
                .background(Color.accent, in: Circle())
        }
        .buttonStyle(GlowPressStyle())
        .accessibilityLabel("建一条线")
    }
}

/// 按下时缩到 0.92、光晕收紧；松开弹回。
struct GlowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .shadow(color: Color.accent.opacity(pressed ? 0.2 : 0.42), radius: pressed ? 8 : 18, y: 2)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            .scaleEffect(pressed ? 0.92 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.25), value: pressed)
    }
}

// MARK: - 页码

/// 页码：`1 / 6`，字小、无底板，只是个位置提示。
/// 选它而不是圆点：首页的图本身就是一排发光圆点，再放一排圆点会打架；数字对任意条数都稳定。
struct PageLabel: View {
    var index: Int
    var count: Int

    var body: some View {
        if let text = HomeCardText.pageLabel(index: index, count: count) {
            Text(text)
                .font(.system(.caption, design: .rounded).weight(.medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
                .contentTransition(.numericText())
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .accessibilityLabel("第 \(index + 1) 条，共 \(count) 条")
        }
    }
}

// MARK: - 首页 → 线路页 缩放转场（iOS 18+）

extension View {
    /// 卡片上的图作为缩放转场的起点；iOS 17 原样返回。
    @ViewBuilder
    func homeZoomSource(id: UUID, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18, *), let namespace {
            matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        } else {
            self
        }
    }

    /// 线路页从卡片放大进来；iOS 17 退回普通 push。
    @ViewBuilder
    func homeZoomDestination(id: UUID?, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18, *), let id, let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
