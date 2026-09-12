import Foundation

/// “记这一次”表单的纯数据草稿，与 SwiftData 解耦，方便测试与合并。
struct SessionDraft: Equatable, Sendable {
    var attemptCount: Int = 0
    var sent: Bool = false
    var fallHoldID: UUID?
    var fallStepIndex: Int?
    var reason: FailReason?
    var note: String = ""
    /// 展开“记每一次”时的逐次记录；未展开为空。
    var attempts: [AttemptRecord] = []

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 把这份草稿并进目标日期上已有的记录：次数相加、上了取或、掉哪/原因以草稿为先、一句话拼接。
    func merged(into existing: SessionDraft) -> SessionDraft {
        var out = existing
        out.attemptCount = existing.attemptCount + attemptCount
        out.sent = existing.sent || sent
        if fallHoldID != nil {
            out.fallHoldID = fallHoldID
            out.fallStepIndex = fallStepIndex
        }
        if let reason { out.reason = reason }
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

/// 无照片的线没有点可选，“掉在哪”退化成文字，存进一句话的开头。
/// 编码：`掉在 大球 · 右脚踩高`；解码时按第一个分隔符拆开。
enum NoPhotoFall {
    static let prefix = "掉在 "
    static let separator = " · "

    static func encode(fall: String, note: String) -> String {
        let f = fall.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (f.isEmpty, n.isEmpty) {
        case (true, _): return n
        case (false, true): return prefix + f
        case (false, false): return prefix + f + separator + n
        }
    }

    static func decode(_ text: String?) -> (fall: String, note: String) {
        guard let text, text.hasPrefix(prefix) else { return ("", text ?? "") }
        let body = String(text.dropFirst(prefix.count))
        guard let range = body.range(of: separator) else { return (body, "") }
        return (String(body[..<range.lowerBound]), String(body[range.upperBound...]))
    }
}
