import Foundation

/// “记这一次”表单的纯数据草稿，与 SwiftData 解耦，方便测试与合并。
struct SessionDraft: Equatable, Sendable {
    var attemptCount: Int = 0
    var sent: Bool = false
    var fallHoldID: UUID?
    var fallStepIndex: Int?
    var reason: FailReason?
    var note: String = ""
    /// 无照片线的“掉在哪”文字版；有照片的线始终为空（用 `fallHoldID`）。
    var fallText: String = ""
    /// 展开“记每一次”时的逐次记录；未展开为空。
    var attempts: [AttemptRecord] = []
    /// 对上次提醒的回答（只在表单里出现了验证问句时才会写回记录）。
    var check: ReminderCheck?

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedFallText: String { fallText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 把这份草稿并进目标日期上已有的记录：次数相加、上了取或、掉哪/原因/验证以草稿为先、一句话拼接。
    func merged(into existing: SessionDraft) -> SessionDraft {
        var out = existing
        out.attemptCount = existing.attemptCount + attemptCount
        out.sent = existing.sent || sent
        if fallHoldID != nil {
            out.fallHoldID = fallHoldID
            out.fallStepIndex = fallStepIndex
        }
        if !trimmedFallText.isEmpty { out.fallText = trimmedFallText }
        if let reason { out.reason = reason }
        if let check { out.check = check }
        let notes = [existing.trimmedNote, trimmedNote].filter { !$0.isEmpty }
        out.note = notes.joined(separator: "；")
        if !existing.attempts.isEmpty || !attempts.isEmpty {
            out.attempts = AttemptSync.resized(existing.attempts, to: existing.attemptCount)
                + AttemptSync.resized(attempts, to: attemptCount)
        }
        return out
    }
}

/// “记每一次”的行与次数保持同步。
enum AttemptSync {
    /// 行数对齐到 `count`：多了从尾部截掉，少了在尾部补空行；已有行保留。
    static func resized(_ attempts: [AttemptRecord], to count: Int) -> [AttemptRecord] {
        let n = max(0, count)
        if attempts.count >= n { return Array(attempts.prefix(n)) }
        return attempts + (0..<(n - attempts.count)).map { _ in AttemptRecord() }
    }

    /// 从逐次记录推导汇总：任一次上了 → 上了；最后一次掉的点 → 掉在哪。
    static func summary(_ attempts: [AttemptRecord]) -> (sent: Bool, lastFallHoldID: UUID?) {
        let sent = attempts.contains { $0.sent }
        let lastFall = attempts.last(where: { !$0.sent && $0.fallHoldID != nil })?.fallHoldID
        return (sent, lastFall)
    }
}

/// 能参与“保存到哪条记录”判定的最小信息。
protocol SessionLike: HistoryFilterable {
    var id: UUID { get }
}

extension Session: SessionLike {}

/// 保存“记这一次”时写到哪条记录。
enum SessionSavePlan: Equatable {
    /// 直接写回这条（日期可能变了）。
    case overwrite(UUID)
    /// 目标日期已有另一条记录：并进去；`removing` 是需要删掉的原记录（若有）。
    case mergeInto(UUID, removing: UUID?)
    /// 目标日期没有记录：新建。
    case create

    /// 这次保存会写进的已有记录；新建时为 nil。
    var targetSessionID: UUID? {
        switch self {
        case .overwrite(let id), .mergeInto(let id, _): id
        case .create: nil
        }
    }

    /// - baseID: 正在编辑的记录（新建且没有预填时为 nil）
    /// - day: 用户选的日期（本地零点）
    /// - cycle: 当前轮次
    static func resolve<S: SessionLike>(baseID: UUID?, day: Date, cycle: Int, sessions: [S],
                                        calendar: Calendar = .current) -> SessionSavePlan {
        let target = calendar.startOfDay(for: day)
        if let other = sessions.first(where: { calendar.startOfDay(for: $0.date) == target && $0.cycle == cycle && $0.id != baseID }) {
            return .mergeInto(other.id, removing: baseID)
        }
        if let baseID { return .overwrite(baseID) }
        return .create
    }
}

/// 无照片线的“掉在哪”旧编码：第一轮把它塞进一句话的开头（`掉在 大球 · 右脚踩高`）。
/// 现在写入一律走 `Session.fallText`，这里只保留解码，读旧数据时把前缀拆回 `fallText`。
enum NoPhotoFall {
    static let prefix = "掉在 "
    static let separator = " · "

    static func decode(_ text: String?) -> (fall: String, note: String) {
        guard let text, text.hasPrefix(prefix) else { return ("", text ?? "") }
        let body = String(text.dropFirst(prefix.count))
        guard let range = body.range(of: separator) else { return (body, "") }
        return (String(body[..<range.lowerBound]), String(body[range.upperBound...]))
    }

    /// 从一条记录的字段还原 (fallText, note)：新字段优先；没有新字段但一句话带旧前缀时拆开。
    static func resolve(fallText: String?, note: String?) -> (fall: String, note: String) {
        if let fallText, !fallText.isEmpty {
            return (fallText, note ?? "")
        }
        return decode(note)
    }
}

extension Session {
    /// 旧无照片记录和新字段在历史、提醒、分享中使用同一种读法；照片线的自由备注不拆解。
    var reviewText: (fall: String, note: String) {
        guard line?.hasPhoto != true else { return (fallText ?? "", note ?? "") }
        return NoPhotoFall.resolve(fallText: fallText, note: note)
    }
}

/// 线路页头图副标题：墙区 · 难度 · 感觉 · 角度，去掉与线名（或前面部分）重复的片段。
/// 比较时忽略空格与 `·`，所以“直壁 · 黄”会吃掉墙区“直壁·黄”和角度“直壁”。
enum LineHeroSubtitle {
    static func make(name: String, area: String?, grade: String?, felt: String?, angle: String?, hasPhoto: Bool = true) -> String {
        var accepted: [String] = []
        var seen = normalize(name)
        for candidate in [area, grade, felt, angle] {
            guard let raw = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            let key = normalize(raw)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            accepted.append(raw)
            seen += key
        }
        if !hasPhoto { accepted.append("无照片") }
        return accepted.joined(separator: " · ")
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && $0 != "·" && $0 != "•" && $0 != "-" && $0 != "/" }
    }
}
