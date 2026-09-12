import SwiftUI

extension Color {
    /// 聚光灯黄。与 Assets 里的 AccentColor 保持一致。
    static let accent = Color(red: 1.0, green: 0.82, blue: 0.18)
    static let coral = Color(red: 1.0, green: 0.45, blue: 0.38)
    static let ink = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let panel = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let panelElevated = Color(red: 0.16, green: 0.16, blue: 0.2)
    static let subtle = Color.white.opacity(0.55)
}

/// 胶囊选择项。
struct Chip: View {
    var title: String
    var selected: Bool
    var systemImage: String?
    /// 紧凑尺寸：用于列表行内、筛选条等次级位置。
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font((compact ? Font.caption2 : Font.caption).weight(.semibold)) }
                Text(title)
            }
            .font((compact ? Font.footnote : Font.subheadline).weight(selected ? .semibold : .regular))
            .padding(.horizontal, compact ? 10 : 13)
            .padding(.vertical, compact ? 6 : 8)
            .background(selected ? Color.accent : Color.white.opacity(0.08), in: Capsule())
            .foregroundStyle(selected ? Color.ink : Color.white.opacity(0.85))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: selected)
    }
}

/// 区块容器：线路页下半屏的每一块。
struct Panel<Content: View>: View {
    var title: String?
    var trailing: AnyView?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = nil
        self.content = content()
    }

    init<T: View>(_ title: String?, trailing: T, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = AnyView(trailing)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || trailing != nil {
                HStack {
                    if let title {
                        Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color.subtle).textCase(nil)
                    }
                    Spacer()
                    trailing
                }
            }
            content
        }
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 大按钮（馆内用）。
struct BigButtonStyle: ButtonStyle {
    var prominent: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(prominent ? Color.accent : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(prominent ? Color.ink : .white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.4)
            .saturation(isEnabled ? 1 : 0.6)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .animation(.snappy(duration: 0.2), value: isEnabled)
    }
}

/// 卡片底部渐变，让文字可读。
struct BottomScrim: View {
    var height: CGFloat = 260
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(0.55), location: 0.55),
                .init(color: .black.opacity(0.85), location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}

extension View {
    /// 统一的深色页面背景。
    func inkBackground() -> some View {
        background(Color.ink.ignoresSafeArea())
    }
}

/// 日期显示。
enum DateText {
    static func short(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        let sameYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        f.dateFormat = sameYear ? "M月d日" : "yyyy年M月d日"
        return f.string(from: date)
    }
}
