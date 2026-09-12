import SwiftUI

/// 设置 · 关于：版本、隐私、不做的事。
struct AboutSettingsSection: View {
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private let promises: [(symbol: String, text: String)] = [
        ("xmark.circle", "不判定你上没上，只记你自己说的"),
        ("xmark.circle", "不评价动作，火柴人只是你摆的样子"),
        ("xmark.circle", "不做医疗、安全或伤病建议"),
    ]

    var body: some View {
        Section {
            SettingsValueRow(title: "版本", value: Self.versionText, systemImage: "info.circle")
            VStack(alignment: .leading, spacing: 6) {
                Label("隐私", systemImage: "lock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("全部数据只保存在这台手机上：不请求定位，不请求相册全量访问，不上传任何内容。分享图和导出文件都由你自己发出。")
                    .font(.footnote)
                    .foregroundStyle(Color.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                Text("不做的事")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                ForEach(promises, id: \.text) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.symbol)
                            .font(.footnote)
                            .foregroundStyle(Color.subtle)
                        Text(item.text)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            SettingsHeader("关于")
        } footer: {
            HStack(spacing: 6) {
                Circle().fill(Color.accent).frame(width: 6, height: 6)
                Text("线感 LineWise · 一条线，一面暗下去的墙。")
            }
            .font(.footnote)
            .foregroundStyle(Color.subtle)
            .padding(.top, 4)
        }
        .settingsRow()
    }
}
