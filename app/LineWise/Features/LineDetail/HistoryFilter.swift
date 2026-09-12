import Foundation

/// 历史列表的时间范围。
enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case all
    case days30
    case days90

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .days30: "30 天"
        case .days90: "90 天"
        }
    }

    var days: Int? {
        switch self {
        case .all: nil
        case .days30: 30
        case .days90: 90
        }
    }
}

/// 能被历史筛选的最小信息（`Session` 与测试替身都实现）。
protocol HistoryFilterable {
    var date: Date { get }
    var cycle: Int { get }
}

extension Session: HistoryFilterable {}

/// 线路页历史筛选：轮次 + 时间范围。两者都是“nil / all = 不筛”。
struct HistoryFilter: Equatable, Sendable {
    var cycle: Int? = nil
    var range: HistoryRange = .all

    var isActive: Bool { cycle != nil || range != .all }

    /// 时间范围的起点（含）。`nil` 表示不限。
    func cutoff(now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let days = range.days else { return nil }
        return calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))
    }

    func apply<S: HistoryFilterable>(_ sessions: [S], now: Date = .now, calendar: Calendar = .current) -> [S] {
        let cutoff = cutoff(now: now, calendar: calendar)
        return sessions.filter { s in
            if let cycle, s.cycle != cycle { return false }
            if let cutoff, s.date < cutoff { return false }
            return true
        }
    }

    /// 轮次胶囊要列出的选项：`nil`（全部）+ 1…cycle。只有多轮时才有意义。
    static func cycleOptions(maxCycle: Int) -> [Int?] {
        guard maxCycle > 1 else { return [] }
        return [nil] + (1...maxCycle).map { Optional($0) }
    }
}
