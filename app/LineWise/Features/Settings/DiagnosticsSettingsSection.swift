import SwiftUI

/// 建线时长的本地埋点统计（PRD §10.5）。纯逻辑，可测。
struct BuildDurationStats: Equatable {
    /// `UserDefaults` 里的键：`[Double]`，每次建线从拍照到完成的秒数。
    static let defaultsKey = "buildDurations"
    /// PRD 目标：中位 ≤ 15s，P90 ≤ 25s。
    static let medianTarget: Double = 15
    static let p90Target: Double = 25

    let samples: [Double]

    init(samples: [Double]) {
        self.samples = samples.filter { $0.isFinite && $0 >= 0 }
    }

    static func load(from defaults: UserDefaults = .standard) -> BuildDurationStats {
        let raw = defaults.array(forKey: defaultsKey) as? [Double] ?? []
        return BuildDurationStats(samples: raw)
    }

    var count: Int { samples.count }
    var isEmpty: Bool { samples.isEmpty }

    /// 中位数：偶数个取中间两个的平均。
    var median: Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    /// P90：最近秩法（nearest-rank）。
    var p90: Double? { percentile(0.9) }

    func percentile(_ p: Double) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let rank = Int((p * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank, 1), sorted.count) - 1]
    }

    /// 秒数显示：10 秒以下保留一位小数，之后取整；超过一分钟用“分 秒”。
    static func format(seconds: Double) -> String {
        if seconds < 10 { return String(format: "%.1f 秒", seconds) }
        if seconds < 60 { return "\(Int(seconds.rounded())) 秒" }
        let total = Int(seconds.rounded())
        return "\(total / 60) 分 \(total % 60) 秒"
    }
}

/// 设置 · 诊断：建线时长次数、中位、P90。
struct DiagnosticsSettingsSection: View {
    @State private var stats = BuildDurationStats(samples: [])

    var body: some View {
        Section {
            Group {
                if stats.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .foregroundStyle(Color.subtle)
                            .frame(width: 22)
                        Text("还没有建线记录")
                            .foregroundStyle(Color.subtle)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 0) {
                        metric("次数", value: "\(stats.count)", ok: nil)
                        metric("中位", value: stats.median.map(BuildDurationStats.format) ?? "—",
                               ok: stats.median.map { $0 <= BuildDurationStats.medianTarget })
                        metric("P90", value: stats.p90.map(BuildDurationStats.format) ?? "—",
                               ok: stats.p90.map { $0 <= BuildDurationStats.p90Target })
                    }
                    .padding(.vertical, 4)
                }
            }
            .onAppear { stats = BuildDurationStats.load() }
        } header: {
            SettingsHeader("诊断")
        } footer: {
            SettingsFooter("建线时长：从拍照到完成。目标中位 ≤ 15 秒、P90 ≤ 25 秒。只记在本机，不上传。")
        }
        .settingsRow()
    }

    private func metric(_ title: String, value: String, ok: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.subtle)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ok == false ? Color.coral : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
