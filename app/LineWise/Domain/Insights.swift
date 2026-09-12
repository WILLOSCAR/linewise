import Foundation

/// 提醒：由“掉哪 · 原因 · 一句话”自动拼成，可改。
enum ReminderComposer {
    static func compose(fallLabel: String?, reason: FailReason?, note: String?) -> String? {
        var parts: [String] = []
        if let fallLabel, !fallLabel.isEmpty { parts.append("掉在 \(fallLabel)") }
        if let reason { parts.append(reason.title) }
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { parts.append(note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 一次记录的摘要，供纯逻辑使用（与存储层解耦）。
struct SessionDigest: Hashable, Sendable {
    var date: Date
    var attemptCount: Int
    var sent: Bool
    var fallNumber: Int?
    var reason: FailReason?
    var note: String?
    var check: ReminderCheck?
    var cycle: Int
}

struct LineDigest: Hashable, Sendable {
    /// 按日期升序
    var sessions: [SessionDigest]
    var reminder: String?
    var reminderVerified: Bool
    var reminderAnswered: Bool
    var status: LineStatus
    var cycle: Int
}

/// 教练几句：只引用这条线自己的记录，2–3 句。
enum CoachSummary {
    static func sentences(for line: LineDigest) -> [String] {
        let sessions = line.sessions.sorted { $0.date < $1.date }
        guard !sessions.isEmpty else { return [] }
        var out: [String] = []

        // 1. 掉落集中点
        let falls = sessions.compactMap { s -> (Int, FailReason?)? in
            guard let n = s.fallNumber else { return nil }
            return (n, s.reason)
        }
        if !falls.isEmpty {
            var counts: [Int: Int] = [:]
            var reasons: [Int: [FailReason]] = [:]
            for (n, r) in falls {
                counts[n, default: 0] += 1
                if let r, r != .unknown { reasons[n, default: []].append(r) }
            }
            if let (hold, count) = counts.max(by: { a, b in a.value == b.value ? a.key < b.key : a.value < b.value }) {
                let label = HoldLabel.circled(hold)
                if count >= 2 {
                    var s = "你在 \(label) 掉了 \(count) 次"
                    if let top = majority(reasons[hold] ?? []) {
                        s += "，其中 \(top.count) 次说是\(top.reason.title)"
                    }
                    out.append(s + "。")
                } else if sessions.count == 1 {
                    var s = "第一次掉在 \(label)"
                    if let r = falls[0].1, r != .unknown { s += "，原因记的是\(r.title)" }
                    out.append(s + "。")
                }
            }
        }

        // 2. 进步 / 上了
        if let last = sessions.last, last.sent {
            let visits = sessions.count
            let attempts = sessions.reduce(0) { $0 + $1.attemptCount }
            if visits == 1, attempts <= 1 {
                out.append("一次就上了。")
            } else {
                out.append("这条线你用了 \(visits) 次馆访、共 \(attempts) 次尝试上的。")
            }
        } else if sessions.count >= 2 {
            let first = sessions[0]
            let last = sessions[sessions.count - 1]
            if let f = first.fallNumber, let l = last.fallNumber, l > f {
                out.append("上次掉在 \(HoldLabel.circled(l))，比第一次的 \(HoldLabel.circled(f)) 高了 \(l - f) 个点。")
            } else if let f = first.fallNumber,
                      sessions.suffix(2).allSatisfy({ $0.fallNumber != f }),
                      let idx = sessions.firstIndex(where: { $0.fallNumber != f }) {
                out.append("从第 \(idx + 1) 次起没再掉在 \(HoldLabel.circled(f))。")
            } else if first.attemptCount > 0, last.attemptCount > 0, last.attemptCount < first.attemptCount {
                out.append("最近一次试了 \(last.attemptCount) 次，第一次是 \(first.attemptCount) 次。")
            }
        }

        // 3. 提醒
        if let reminder = line.reminder, !reminder.isEmpty {
            if line.reminderVerified {
                out.append("“\(reminder)”你已经验证过有用。")
            } else if let last = sessions.last, last.check == .differentProblem {
                out.append("你说问题变了，提醒已经换成新的。")
            } else if sessions.count >= 2, !line.reminderAnswered {
                out.append("上次提醒是“\(reminder)”，还没回答有没有用。")
            }
        }

        return Array(out.prefix(3))
    }

    private static func majority(_ reasons: [FailReason]) -> (reason: FailReason, count: Int)? {
        guard !reasons.isEmpty else { return nil }
        var counts: [FailReason: Int] = [:]
        for r in reasons { counts[r, default: 0] += 1 }
        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        return best.value >= 2 ? (best.key, best.value) : nil
    }
}

/// 从 OCR 文本里找难度标签。
enum GradeParser {
    private static let vGrade = try! NSRegularExpression(pattern: #"(?i)\bV(B|\d{1,2})[+\-]?(?!\w)"#)
    private static let fontGrade = try! NSRegularExpression(pattern: #"\b([3-9][abcABC]\+?)(?!\w)"#)
    private static let bareDigit = try! NSRegularExpression(pattern: #"^\s*([1-9]|1[0-2])\s*$"#)

    /// 按可信度排序返回候选；第一个可直接预填。
    static func candidates(from texts: [String]) -> [String] {
        var v: [String] = []
        var font: [String] = []
        var bare: [String] = []
        for text in texts {
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            for m in vGrade.matches(in: text, range: range) {
                v.append(ns.substring(with: m.range).uppercased())
            }
            for m in fontGrade.matches(in: text, range: range) {
                font.append(ns.substring(with: m.range(at: 1)).uppercased())
            }
            if let m = bareDigit.firstMatch(in: text, range: range) {
                bare.append(ns.substring(with: m.range(at: 1)))
            }
        }
        var seen: Set<String> = []
        return (v + font + bare).filter { seen.insert($0).inserted }
    }
}
