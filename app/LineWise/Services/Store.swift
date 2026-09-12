import Foundation
import SwiftData
import UIKit

/// 所有写操作集中在这里：立即保存，并尽可能返回可撤销闭包。
struct Store {
    let context: ModelContext

    init(_ context: ModelContext) {
        self.context = context
    }

    // MARK: 保存

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("save failed: \(error)")
        }
    }

    // MARK: 岩馆

    func gyms() -> [Gym] {
        let descriptor = FetchDescriptor<Gym>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func gym(id: UUID?) -> Gym? {
        guard let id else { return nil }
        var d = FetchDescriptor<Gym>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    /// 保证至少有一个岩馆；返回当前应选中的岩馆。
    @discardableResult
    func ensureDefaultGym(named name: String = "我的岩馆") -> Gym {
        if let first = gyms().first { return first }
        let gym = Gym(name: name)
        context.insert(gym)
        save()
        return gym
    }

    func addGym(name: String) -> Gym {
        let gym = Gym(name: name.trimmingCharacters(in: .whitespaces))
        context.insert(gym)
        save()
        return gym
    }

    func deleteGym(_ gym: Gym) {
        for wall in gym.walls {
            if let f = wall.photoFileName { ImageStore.delete(fileName: f) }
        }
        context.delete(gym)
        save()
    }

    // MARK: 墙与线

    func createWall(gym: Gym, image: UIImage?, areaName: String?, angle: WallAngle) throws -> Wall {
        var fileName: String?
        var w = 0, h = 0
        if let image {
            let saved = try ImageStore.save(image)
            fileName = saved.fileName
            w = saved.width
            h = saved.height
        }
        let wall = Wall(gym: gym, photoFileName: fileName, imageWidth: w, imageHeight: h,
                        areaName: areaName?.isEmpty == true ? nil : areaName, angle: angle)
        context.insert(wall)
        gym.walls.append(wall)
        save()
        return wall
    }

    func createLine(wall: Wall, holds: [Hold], startHoldIDs: [UUID], finishHoldID: UUID?,
                    gradeText: String?, gradeSource: GradeSource?, name: String?) -> Line {
        let defaultName = Self.defaultLineName(area: wall.areaName, date: .now)
        let line = Line(wall: wall, holds: holds, startHoldIDs: startHoldIDs, finishHoldID: finishHoldID,
                        gradeText: gradeText?.isEmpty == true ? nil : gradeText, gradeSource: gradeSource,
                        name: name?.isEmpty == false ? name! : defaultName)
        context.insert(line)
        wall.lines.append(line)
        save()
        return line
    }

    static func defaultLineName(area: String?, date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        let areaPart = (area?.isEmpty == false) ? area! : "新线"
        return "\(areaPart) · \(f.string(from: date))"
    }

    func touch(_ line: Line) {
        line.updatedAt = .now
        save()
    }

    // MARK: 记录

    /// 今天在当前轮次的记录；没有就新建。
    func todaySession(for line: Line, source: SessionSource) -> Session {
        let today = Calendar.current.startOfDay(for: .now)
        if let s = line.sessions.first(where: { $0.date == today && $0.cycle == line.cycle }) {
            return s
        }
        let s = Session(line: line, date: today, cycle: line.cycle, source: source)
        context.insert(s)
        line.sessions.append(s)
        line.updatedAt = .now
        save()
        return s
    }

    /// 馆内 +1。返回撤销闭包。
    func incrementAttempt(_ line: Line) -> () -> Void {
        let session = todaySession(for: line, source: .inGym)
        let wasNew = session.attemptCount == 0 && !session.hasContent
        session.attemptCount += 1
        session.updatedAt = .now
        line.updatedAt = .now
        save()
        let sid = session.id
        return { [self] in
            guard let s = line.sessions.first(where: { $0.id == sid }) else { return }
            s.attemptCount = max(0, s.attemptCount - 1)
            if wasNew, s.attemptCount == 0, !s.hasContent, !s.sent {
                line.sessions.removeAll { $0.id == sid }
                context.delete(s)
            }
            save()
        }
    }

    /// 馆内“上了”开关。
    func setSentToday(_ line: Line, sent: Bool) -> () -> Void {
        let session = todaySession(for: line, source: .inGym)
        let previous = session.sent
        let previousStatus = line.status
        session.sent = sent
        session.updatedAt = .now
        if sent, line.status == .projecting { line.status = .sent }
        line.updatedAt = .now
        save()
        let sid = session.id
        return { [self] in
            guard let s = line.sessions.first(where: { $0.id == sid }) else { return }
            s.sent = previous
            line.status = previousStatus
            save()
        }
    }

    /// 保存“记这一次”表单。会更新提醒。
    func commitSession(_ session: Session, line: Line, fallLabel: String?) {
        session.updatedAt = .now
        if !Calendar.current.isDateInToday(session.date) { session.source = .backfill }
        else if session.source != .inGym { session.source = .after }
        if session.sent, line.status == .projecting { line.status = .sent }

        // 提醒：有内容就替换为最新
        if session.hasContent, let text = ReminderComposer.compose(fallLabel: fallLabel, reason: session.reason, note: session.note) {
            line.reminderText = text
            line.reminderSessionID = session.id
            line.reminderVerified = false
        }
        line.updatedAt = .now
        save()
    }

    func newSession(for line: Line, date: Date) -> Session {
        let day = Calendar.current.startOfDay(for: date)
        if let existing = line.sessions.first(where: { $0.date == day && $0.cycle == line.cycle }) {
            return existing
        }
        let s = Session(line: line, date: day, cycle: line.cycle, source: Calendar.current.isDateInToday(day) ? .after : .backfill)
        context.insert(s)
        line.sessions.append(s)
        save()
        return s
    }

    func deleteSession(_ session: Session, from line: Line) -> () -> Void {
        // 软删除做法：先从关系里摘掉，撤销时放回；真正删除在确认后。
        let snapshot = SessionSnapshot(session)
        line.sessions.removeAll { $0.id == session.id }
        context.delete(session)
        if line.reminderSessionID == snapshot.id {
            line.reminderText = nil
            line.reminderSessionID = nil
            line.reminderVerified = false
        }
        line.updatedAt = .now
        save()
        return { [self] in
            let restored = snapshot.restore(into: line)
            context.insert(restored)
            line.sessions.append(restored)
            if let label = line.label(for: restored.fallHoldID), restored.hasContent,
               line.reminderText == nil,
               let text = ReminderComposer.compose(fallLabel: label, reason: restored.reason, note: restored.note) {
                line.reminderText = text
                line.reminderSessionID = restored.id
            }
            save()
        }
    }

    /// 回答“上次这句有用吗？”
    func answerCheck(_ session: Session, line: Line, check: ReminderCheck) -> () -> Void {
        let previous = session.check
        let previousVerified = line.reminderVerified
        session.check = check
        session.updatedAt = .now
        switch check {
        case .worked:
            line.reminderVerified = true
        case .differentProblem:
            // 提醒由这条记录的内容替换（若有）；没有内容时保留旧提醒但不再标记验证
            if session.hasContent, let text = ReminderComposer.compose(fallLabel: line.label(for: session.fallHoldID), reason: session.reason, note: session.note) {
                line.reminderText = text
                line.reminderSessionID = session.id
            }
            line.reminderVerified = false
        case .noChange, .notTested:
            break
        }
        save()
        return { [self] in
            session.check = previous
            line.reminderVerified = previousVerified
            save()
        }
    }

    func updateReminder(_ line: Line, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        line.reminderText = trimmed.isEmpty ? nil : trimmed
        if trimmed.isEmpty { line.reminderSessionID = nil }
        line.reminderVerified = false
        line.updatedAt = .now
        save()
    }

    // MARK: 状态

    func apply(_ action: LineAction, to line: Line) -> (() -> Void)? {
        guard let next = LineStatusMachine.apply(action, status: line.status, cycle: line.cycle) else { return nil }
        let prevStatus = line.status
        let prevCycle = line.cycle
        line.status = next.status
        line.cycle = next.cycle
        line.updatedAt = .now
        save()
        return { [self] in
            line.status = prevStatus
            line.cycle = prevCycle
            save()
        }
    }

    /// 整面墙换线：所有非 gone 的线批量置 gone。
    func resetWall(_ wall: Wall) -> () -> Void {
        let affected = wall.activeLines.filter { $0.status != .gone }
        let previous = affected.map { ($0, $0.status) }
        for line in affected {
            line.status = .gone
            line.updatedAt = .now
        }
        let prevReset = wall.resetAt
        wall.resetAt = .now
        save()
        return { [self] in
            for (line, status) in previous { line.status = status }
            wall.resetAt = prevReset
            save()
        }
    }

    // MARK: 删除 / 合并

    func softDelete(_ line: Line) -> () -> Void {
        line.deletedAt = .now
        save()
        return { [self] in
            line.deletedAt = nil
            save()
        }
    }

    /// 清理超过一天的软删除线（启动时调用）。
    func purgeDeleted() {
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        let d = FetchDescriptor<Line>(predicate: #Predicate { $0.deletedAt != nil && $0.deletedAt! < cutoff })
        for line in (try? context.fetch(d)) ?? [] {
            context.delete(line)
        }
        save()
    }

    /// 把 `line` 的记录并入 `target`。
    func merge(_ line: Line, into target: Line) -> () -> Void {
        let moved = line.sessions
        for s in moved {
            s.line = target
            target.sessions.append(s)
        }
        line.sessions.removeAll()
        line.mergedIntoLineID = target.id
        let prevReminder = (target.reminderText, target.reminderSessionID, target.reminderVerified)
        if target.reminderText == nil, let r = line.reminderText {
            target.reminderText = r
            target.reminderSessionID = line.reminderSessionID
            target.reminderVerified = line.reminderVerified
        }
        target.updatedAt = .now
        save()
        return { [self] in
            for s in moved {
                s.line = line
                target.sessions.removeAll { $0.id == s.id }
                line.sessions.append(s)
            }
            line.mergedIntoLineID = nil
            target.reminderText = prevReminder.0
            target.reminderSessionID = prevReminder.1
            target.reminderVerified = prevReminder.2
            save()
        }
    }

    // MARK: 全部删除

    func deleteEverything() {
        for gym in gyms() { deleteGym(gym) }
        let orphanWalls = (try? context.fetch(FetchDescriptor<Wall>())) ?? []
        for w in orphanWalls {
            if let f = w.photoFileName { ImageStore.delete(fileName: f) }
            context.delete(w)
        }
        save()
    }
}

/// 用于撤销删除的记录快照。
private struct SessionSnapshot {
    let id: UUID
    let date: Date
    let attemptCount: Int
    let sent: Bool
    let fallHoldID: UUID?
    let fallStepIndex: Int?
    let reasonRaw: String?
    let note: String?
    let checkRaw: String?
    let reminderSnapshot: String?
    let sourceRaw: String
    let cycle: Int
    let createdAt: Date
    let attemptsData: Data?

    init(_ s: Session) {
        id = s.id; date = s.date; attemptCount = s.attemptCount; sent = s.sent
        fallHoldID = s.fallHoldID; fallStepIndex = s.fallStepIndex; reasonRaw = s.reasonRaw
        note = s.note; checkRaw = s.checkRaw; reminderSnapshot = s.reminderSnapshot
        sourceRaw = s.sourceRaw; cycle = s.cycle; createdAt = s.createdAt; attemptsData = s.attemptsData
    }

    func restore(into line: Line) -> Session {
        let s = Session(id: id, line: line, date: date, cycle: cycle, source: SessionSource(rawValue: sourceRaw) ?? .after, createdAt: createdAt)
        s.attemptCount = attemptCount
        s.sent = sent
        s.fallHoldID = fallHoldID
        s.fallStepIndex = fallStepIndex
        s.reasonRaw = reasonRaw
        s.note = note
        s.checkRaw = checkRaw
        s.reminderSnapshot = reminderSnapshot
        s.attemptsData = attemptsData
        return s
    }
}
