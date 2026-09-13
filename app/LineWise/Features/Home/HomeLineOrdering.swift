import Foundation

/// 首页卡片的筛选与排序：纯函数，方便测试，也方便 `HomeView` 缓存结果而不是每帧重算。
enum HomeLineOrdering {
    /// 一条线里会影响首页顺序 / 筛选结果的字段快照。数组整体相等 → 排序结果一定相同。
    struct Key: Hashable {
        var id: UUID
        var status: String
        var gymID: UUID?
        var createdAt: Date
        var updatedAt: Date
        var sessionCount: Int
        var latestDate: Date?
        var hasToday: Bool
    }

    static func key(for line: Line, today: Date) -> Key {
        var latest: Date?
        var hasToday = false
        for s in line.sessions {
            if latest == nil || s.date > latest! { latest = s.date }
            if s.date == today { hasToday = true }
        }
        return Key(
            id: line.id, status: line.statusRaw, gymID: line.wall?.gym?.id,
            createdAt: line.createdAt, updatedAt: line.updatedAt, sessionCount: line.sessions.count,
            latestDate: latest, hasToday: hasToday
        )
    }

    /// 只遍历一遍、不排序的“指纹”；`HomeView` 用它判断要不要重算。
    static func signature(_ lines: [Line], filter: HomeFilter, gymID: UUID?, today: Date) -> Int {
        var hasher = Hasher()
        hasher.combine(filter)
        hasher.combine(gymID)
        for line in lines { hasher.combine(key(for: line, today: today)) }
        return hasher.finalize()
    }

    static func matches(_ line: Line, filter: HomeFilter, gymID: UUID?, today: Date) -> Bool {
        if let gymID, line.wall?.gym?.id != gymID { return false }
        switch filter {
        case .projecting: return line.status == .projecting
        case .today: return line.sessions.contains { $0.date == today }
        case .sent: return line.status == .sent
        case .all: return true
        }
    }

    /// 最近有记录的优先，同一天按 `updatedAt`；尚未爬过的线随后按创建时间排列。
    static func ordered(_ lines: [Line], filter: HomeFilter, gymID: UUID?, today: Date = Calendar.current.startOfDay(for: .now)) -> [Line] {
        let filtered = lines.filter { matches($0, filter: filter, gymID: gymID, today: today) }
        // 先把排序键算一遍，避免比较时反复 sort sessions
        let keyed = filtered.map { line -> (Line, Date?, Date) in
            let latest = line.sessions.map(\.date).max()
            return (line, latest, line.updatedAt)
        }
        return keyed.sorted { a, b in
            switch (a.1, b.1) {
            case let (.some(left), .some(right)):
                if left != right { return left > right }
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none):
                if a.0.createdAt != b.0.createdAt { return a.0.createdAt > b.0.createdAt }
            }
            if a.2 != b.2 { return a.2 > b.2 }
            return a.0.id.uuidString < b.0.id.uuidString
        }.map(\.0)
    }
}

/// 首页卡片文字：三行以内，纯函数。
enum HomeCardText {
    /// 第一行：墙区 · 难度（都没有时用线名）。
    static func headline(area: String?, grade: String?, fallbackName: String) -> String {
        var parts: [String] = []
        if let area, !area.isEmpty { parts.append(area) }
        if let grade, !grade.isEmpty { parts.append(grade) }
        return parts.isEmpty ? fallbackName : parts.joined(separator: " · ")
    }

    /// 第二行：第 N 次来 · 上次掉在 ⑤ · 身体。没来过 → nil（由引导句代替）。
    static func visitLine(visitCount: Int, lastFall: String?) -> String? {
        guard visitCount > 0 else { return nil }
        var parts = ["第 \(visitCount) 次来"]
        if let lastFall, !lastFall.isEmpty { parts.append(lastFall) }
        return parts.joined(separator: " · ")
    }

    /// 页码文字。
    static func pageLabel(index: Int, count: Int) -> String? {
        guard count > 1, index >= 0, index < count else { return nil }
        return "\(index + 1) / \(count)"
    }
}
