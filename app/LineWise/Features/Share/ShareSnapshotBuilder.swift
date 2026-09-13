import Foundation
import SwiftUI

/// 分享图需要的一次记录：日期、次数、掉在哪、上了没。从 `Session` 抽出，纯值类型。
struct ShareVisit: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var attemptCount: Int
    var sent: Bool
    var fallHoldID: UUID?
    /// 无照片线的“掉在哪”文字版。
    var fallText: String?

    init(id: UUID = UUID(), date: Date, attemptCount: Int, sent: Bool = false, fallHoldID: UUID? = nil, fallText: String? = nil) {
        self.id = id
        self.date = date
        self.attemptCount = attemptCount
        self.sent = sent
        self.fallHoldID = fallHoldID
        self.fallText = fallText
    }

    init(session: Session) {
        self.init(id: session.id, date: session.date, attemptCount: session.attemptCount, sent: session.sent,
                  fallHoldID: session.fallHoldID, fallText: session.reviewText.fall.isEmpty ? nil : session.reviewText.fall)
    }
}

/// 分享图快照带里的一格：第几次来、这一次的记录。
struct ShareSnapshot: Identifiable, Hashable {
    /// 在全部记录里的序号（0 起）。
    var visitIndex: Int
    var visit: ShareVisit

    var id: UUID { visit.id }
    var visitNumber: Int { visitIndex + 1 }
}

/// 分享实际顺序时保留原始步号，姿态与编辑器共用同一场景求解。
struct ShareSequenceSnapshot: Identifiable, Hashable {
    var stepIndex: Int
    var step: SequenceStep
    var pose: StickFigurePose
    var id: Int { stepIndex }
}

/// 把记录变成最多 `maxCount` 格快照（多则等距抽样，首尾保留）。纯逻辑，可测。
enum ShareSnapshotBuilder {
    static let defaultMaxCount = 8

    static func sequenceSnapshots(holds: [Hold], startHoldIDs: [UUID], sequence: ClimbSequence?,
                                  aspect: Double, profile: BodyProfile, maxCount: Int = defaultMaxCount) -> [ShareSequenceSnapshot] {
        guard let sequence, !holds.isEmpty else { return [] }
        let scene = SequenceScene(holds: holds, aspect: aspect, startHoldIDs: startHoldIDs)
        let states = SequenceReplay.states(of: sequence, initial: scene.initial)
        return sampleIndices(count: sequence.steps.count, max: maxCount).map { index in
            ShareSequenceSnapshot(stepIndex: index, step: sequence.steps[index],
                                  pose: scene.pose(state: states[index + 1], profile: profile))
        }
    }

    /// 从 `count` 条里等距选出最多 `max` 个索引；第一条和最后一条一定在内。
    static func sampleIndices(count: Int, max: Int) -> [Int] {
        guard count > 0, max > 0 else { return [] }
        guard count > max else { return Array(0..<count) }
        guard max > 1 else { return [count - 1] }
        var result: [Int] = []
        for i in 0..<max {
            let idx = Int((Double(i) * Double(count - 1) / Double(max - 1)).rounded())
            if result.last != idx { result.append(idx) }
        }
        return result
    }

    /// 只保留有内容的记录（有次数、掉过或上了），按日期升序抽样。
    static func snapshots(visits: [ShareVisit], maxCount: Int = defaultMaxCount) -> [ShareSnapshot] {
        let meaningful = visits
            .filter { $0.attemptCount > 0 || $0.sent || $0.fallHoldID != nil || $0.fallText?.isEmpty == false }
            .sorted { $0.date < $1.date }
        return sampleIndices(count: meaningful.count, max: maxCount).map { i in
            ShareSnapshot(visitIndex: i, visit: meaningful[i])
        }
    }

    /// 一格下面那行小字：“5 次 · 掉在 ⑤” / “2 次 · 上了” / “掉在 ⑤” / “上了”。
    /// `label` 把点位 id 变成带圈编号；无照片线退回 `fallText`。
    static func caption(for visit: ShareVisit, label: (UUID?) -> String?) -> String {
        var parts: [String] = []
        if visit.attemptCount > 0 { parts.append("\(visit.attemptCount) 次") }
        if visit.sent {
            parts.append("上了")
        } else if let l = label(visit.fallHoldID) {
            parts.append("掉在 \(l)")
        } else if let t = visit.fallText, !t.isEmpty {
            parts.append("掉在 \(t)")
        }
        return parts.joined(separator: " · ")
    }

    /// 历史掉落点 → 标记（与 `Line.fallMarks(from:)` 同一算法，但只依赖值类型，分享图和测试都能用）。
    static func fallMarks(visits: [ShareVisit]) -> [FallMark] {
        let list = visits.filter { $0.fallHoldID != nil }
        guard !list.isEmpty else { return [] }
        let dates = Array(Set(list.map(\.date))).sorted()
        var grouped: [UUID: (count: Int, latest: Date)] = [:]
        for v in list {
            let id = v.fallHoldID!
            let cur = grouped[id]
            grouped[id] = (count: (cur?.count ?? 0) + 1, latest: max(cur?.latest ?? .distantPast, v.date))
        }
        return grouped
            .map { id, v in
                let rank = dates.firstIndex(of: v.latest) ?? 0
                let recency = dates.count > 1 ? Double(rank) / Double(dates.count - 1) : 1
                return FallMark(holdID: id, count: v.count, recency: recency)
            }
            .sorted { $0.recency < $1.recency }
    }
}

extension SpotlightGeometry {
    /// 分享图用的取景：先按 `focusRect` 把这条线的包围盒放大，再把关注区域扩到与视图同宽高比，
    /// 让图正好填满视图、不露底板（除非照片本身在那个方向不够大）。
    static func fillingFocusRect(for holds: [Hold], aspect: Double, viewSize: CGSize,
                                 padding: Double = 0.3, minSize: Double = 0.5) -> CGRect? {
        guard var f = focusRect(for: holds, padding: padding, minSize: minSize),
              viewSize.width > 0, viewSize.height > 0 else { return nil }
        let a = max(aspect, 0.05)
        let viewRatio = viewSize.width / viewSize.height
        let focusRatio = (f.width * a) / f.height
        if focusRatio < viewRatio {
            // 关注区域太“瘦”：加宽
            let newW = f.height * viewRatio / a
            f = f.insetBy(dx: -(newW - f.width) / 2, dy: 0)
        } else if focusRatio > viewRatio {
            // 关注区域太“扁”：加高
            let newH = f.width * a / viewRatio
            f = f.insetBy(dx: 0, dy: -(newH - f.height) / 2)
        }
        // 先平移回图内（尽量保住尺寸），再夹在 0…1
        if f.minX < 0 { f.origin.x = 0 }
        if f.maxX > 1 { f.origin.x = 1 - f.width }
        if f.minY < 0 { f.origin.y = 0 }
        if f.maxY > 1 { f.origin.y = 1 - f.height }
        return f.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}
