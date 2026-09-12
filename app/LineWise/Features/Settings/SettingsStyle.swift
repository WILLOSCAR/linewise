import SwiftUI

/// 设置页统一的区块标题（与 `Panel` 的标题风格一致）。
struct SettingsHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.subtle)
            .textCase(nil)
    }
}

/// 设置页的区块说明。
struct SettingsFooter: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.subtle)
    }
}

/// 左标签右数值的一行。
struct SettingsValueRow: View {
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.subtle)
                    .frame(width: 22)
            }
            Text(title).foregroundStyle(.white)
            Spacer()
            Text(value)
                .foregroundStyle(Color.subtle)
                .monospacedDigit()
        }
    }
}

extension View {
    /// 设置页每一行的底色与分隔线，与全 App 的 `Panel` 一致。
    func settingsRow() -> some View {
        listRowBackground(Color.panel)
            .listRowSeparatorTint(.white.opacity(0.08))
    }
}
