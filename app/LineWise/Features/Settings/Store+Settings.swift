import Foundation
import SwiftData

/// 设置页需要的几个读写操作（不改 `Store.swift`）。
extension Store {
    /// 重命名岩馆；空名字忽略。
    func renameGym(_ gym: Gym, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != gym.name else { return }
        gym.name = trimmed
        save()
    }

    /// 可见的线（未删除、未合并）数量。
    func visibleLineCount() -> Int {
        let d = FetchDescriptor<Line>(predicate: #Predicate { $0.deletedAt == nil && $0.mergedIntoLineID == nil })
        return (try? context.fetchCount(d)) ?? 0
    }

    /// 全部记录数量。
    func sessionCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<Session>())) ?? 0
    }

    /// 某个岩馆下可见的线数量。
    func visibleLineCount(in gym: Gym) -> Int {
        gym.walls.reduce(0) { $0 + $1.activeLines.count }
    }
}
