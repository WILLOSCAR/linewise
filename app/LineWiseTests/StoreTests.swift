import Foundation
import SwiftData
import Testing
import UIKit
@testable import LineWise

/// 每个测试一套独立的内存容器。
@MainActor
struct StoreFixture {
    let container: ModelContainer
    let context: ModelContext
    let store: Store

    init() throws {
        let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        store = Store(context)
    }

    /// 一个岩馆 + 一面无照片墙 + 一条 `holdCount` 个点的线（从下到上）。
    func makeLine(holdCount: Int = 5, area: String? = "斜板墙", grade: String? = "V3", name: String? = nil) throws -> (Gym, Wall, Line) {
        let gym = store.ensureDefaultGym()
        let wall = try store.createWall(gym: gym, image: nil, areaName: area, angle: .slab)
        let holds = (0..<holdCount).map { i in
            Hold(x: 0.3 + Double(i) * 0.08, y: 0.9 - Double(i) * (0.8 / Double(max(holdCount - 1, 1))), r: 0.04)
        }
        let sf = HoldNumbering.defaultStartAndFinish(holds)
        let line = store.createLine(wall: wall, holds: holds, startHoldIDs: sf.start, finishHoldID: sf.finish,
                                    gradeText: grade, gradeSource: .manual, name: name)
        return (gym, wall, line)
    }

    func daysAgo(_ n: Int) -> Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -n, to: .now)!)
    }

    func fetchLines() throws -> [Line] {
        try context.fetch(FetchDescriptor<Line>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    func fetchSessions() throws -> [Session] {
        try context.fetch(FetchDescriptor<Session>())
    }
}

// MARK: - 岩馆 / 墙 / 线

@MainActor
@Suite("Store · 岩馆与线")
struct StoreGymAndLineTests {
    let f: StoreFixture
    init() throws { f = try StoreFixture() }

    @Test("ensureDefaultGym 幂等")
    func ensureDefaultGymIsIdempotent() {
        let a = f.store.ensureDefaultGym()
        let b = f.store.ensureDefaultGym(named: "别的名字")
        #expect(a.id == b.id)
        #expect(f.store.gyms().count == 1)
        #expect(a.name == "我的岩馆")
    }

    @Test("addGym 去掉首尾空格并按创建顺序返回")
    func addGym() {
        let first = f.store.ensureDefaultGym()
        let gym = f.store.addGym(name: "  岩时·望京 ")
        #expect(gym.name == "岩时·望京")
        #expect(f.store.gyms().map(\.id) == [first.id, gym.id])
        #expect(f.store.gym(id: gym.id)?.id == gym.id)
        #expect(f.store.gym(id: nil) == nil)
    }

    @Test("无照片墙 + 新线：默认名、projecting、cycle 1")
    func createWallAndLine() throws {
        let (gym, wall, line) = try f.makeLine()
        #expect(wall.photoFileName == nil)
        #expect(wall.hasPhoto == false)
        #expect(wall.aspectRatio == 0.75)
        #expect(gym.walls.count == 1)
        #expect(wall.lines.count == 1)
        #expect(line.name == Store.defaultLineName(area: "斜板墙", date: .now))
        #expect(line.status == .projecting)
        #expect(line.cycle == 1)
        #expect(line.gradeText == "V3")
        #expect(line.holds.count == 5)
        #expect(line.startHoldIDs.count == 1)
        #expect(line.finishHoldID != nil)
        #expect(line.isVisible)
    }

    @Test("空名字与空难度都归一为默认/nil")
    func createLineNormalizesEmptyStrings() throws {
        let gym = f.store.ensureDefaultGym()
        let wall = try f.store.createWall(gym: gym, image: nil, areaName: "", angle: .unknown)
        #expect(wall.areaName == nil)
        let line = f.store.createLine(wall: wall, holds: [], startHoldIDs: [], finishHoldID: nil,
                                      gradeText: "", gradeSource: nil, name: "")
        #expect(line.gradeText == nil)
        #expect(line.name == Store.defaultLineName(area: nil, date: .now))
        #expect(line.name.hasPrefix("新线 · "))
    }

    @Test("deleteGym 连带墙和线")
    func deleteGymCascades() throws {
        let (gym, _, _) = try f.makeLine()
        f.store.deleteGym(gym)
        #expect(f.store.gyms().isEmpty)
        #expect(try f.fetchLines().isEmpty)
        #expect(try f.context.fetch(FetchDescriptor<Wall>()).isEmpty)
    }
}

// MARK: - 记录

@MainActor
@Suite("Store · 记录")
struct StoreSessionTests {
    let f: StoreFixture
    init() throws { f = try StoreFixture() }

    @Test("+1 三次 → 3；撤销一次 → 2")
    func incrementAttempt() throws {
        let (_, _, line) = try f.makeLine()
        _ = f.store.incrementAttempt(line)
        _ = f.store.incrementAttempt(line)
        let undo = f.store.incrementAttempt(line)
        #expect(line.sessions.count == 1)
        let today = try #require(line.latestSession)
        #expect(today.attemptCount == 3)
        #expect(today.isToday)
        #expect(today.source == .inGym)
        #expect(today.cycle == 1)
        undo()
        #expect(today.attemptCount == 2)
        #expect(line.sessions.count == 1)
    }

    @Test("新建的空记录撤销到 0 时被删掉")
    func incrementUndoRemovesEmptySession() throws {
        let (_, _, line) = try f.makeLine()
        let undo = f.store.incrementAttempt(line)
        #expect(line.sessions.count == 1)
        undo()
        #expect(line.sessions.isEmpty)
        #expect(try f.fetchSessions().isEmpty)
    }

    @Test("setSentToday(true) → session.sent 且 line.status == .sent；撤销恢复")
    func setSentToday() throws {
        let (_, _, line) = try f.makeLine()
        let undo = f.store.setSentToday(line, sent: true)
        let s = try #require(line.latestSession)
        #expect(s.sent)
        #expect(line.status == .sent)
        undo()
        #expect(s.sent == false)
        #expect(line.status == .projecting)
    }

    @Test("newSession 同一天返回同一条")
    func newSessionSameDay() throws {
        let (_, _, line) = try f.makeLine()
        let a = f.store.newSession(for: line, date: .now)
        let b = f.store.newSession(for: line, date: .now.addingTimeInterval(60))
        #expect(a.id == b.id)
        #expect(line.sessions.count == 1)
        #expect(a.source == .after)
        let past = f.store.newSession(for: line, date: f.daysAgo(3))
        #expect(past.id != a.id)
        #expect(past.source == .backfill)
        #expect(line.sessions.count == 2)
    }

    @Test("commitSession 有内容 → 生成提醒；无内容不覆盖旧提醒")
    func commitSessionComposesReminder() throws {
        let (_, _, line) = try f.makeLine()
        let ordered = HoldNumbering.ordered(line.holds)
        let a = f.store.newSession(for: line, date: f.daysAgo(5))
        a.fallHoldID = ordered[0].id
        a.reason = .feet
        a.note = "xxx"
        f.store.commitSession(a, line: line, fallLabel: line.label(for: a.fallHoldID))
        #expect(line.reminderText == "掉在 ① · 脚 · xxx")
        #expect(line.reminderSessionID == a.id)
        #expect(line.reminderVerified == false)

        let b = f.store.newSession(for: line, date: f.daysAgo(1))
        b.attemptCount = 4
        f.store.commitSession(b, line: line, fallLabel: nil)
        #expect(b.hasContent == false)
        #expect(line.reminderText == "掉在 ① · 脚 · xxx")
        #expect(line.reminderSessionID == a.id)
    }

    @Test("commitSession 里 sent → line.status == .sent")
    func commitSessionMarksSent() throws {
        let (_, _, line) = try f.makeLine()
        let s = f.store.newSession(for: line, date: .now)
        s.sent = true
        f.store.commitSession(s, line: line, fallLabel: nil)
        #expect(line.status == .sent)
    }

    @Test("把日期改到过去 → source == .backfill")
    func commitSessionBackfill() throws {
        let (_, _, line) = try f.makeLine()
        let s = f.store.newSession(for: line, date: .now)
        #expect(s.source == .after)
        s.date = f.daysAgo(2)
        f.store.commitSession(s, line: line, fallLabel: nil)
        #expect(s.source == .backfill)
    }

    @Test("今天的馆内记录 commit 后保持 inGym")
    func commitSessionKeepsInGym() throws {
        let (_, _, line) = try f.makeLine()
        _ = f.store.incrementAttempt(line)
        let s = try #require(line.latestSession)
        f.store.commitSession(s, line: line, fallLabel: nil)
        #expect(s.source == .inGym)
    }

    @Test("deleteSession + 撤销：记录恢复且字段一致")
    func deleteSessionUndoRestoresFields() throws {
        let (_, _, line) = try f.makeLine()
        let ordered = HoldNumbering.ordered(line.holds)
        let s = f.store.newSession(for: line, date: f.daysAgo(4))
        s.attemptCount = 7
        s.sent = false
        s.fallHoldID = ordered[2].id
        s.fallStepIndex = 3
        s.reason = .timing
        s.note = "先看清再出手"
        s.check = .noChange
        s.reminderSnapshot = "旧的一句"
        s.attempts = [AttemptRecord(sent: false, fallHoldID: ordered[1].id), AttemptRecord(sent: true, fallHoldID: nil)]
        f.store.commitSession(s, line: line, fallLabel: line.label(for: s.fallHoldID))
        let expected = (id: s.id, date: s.date, createdAt: s.createdAt, cycle: s.cycle, attempts: s.attempts)
        #expect(line.reminderSessionID == s.id)

        let undo = f.store.deleteSession(s, from: line)
        #expect(line.sessions.isEmpty)
        #expect(try f.fetchSessions().isEmpty)
        #expect(line.reminderText == nil)
        #expect(line.reminderSessionID == nil)

        undo()
        #expect(line.sessions.count == 1)
        let r = try #require(line.sessions.first)
        #expect(r.id == expected.id)
        #expect(r.date == expected.date)
        #expect(r.createdAt == expected.createdAt)
        #expect(r.cycle == expected.cycle)
        #expect(r.attemptCount == 7)
        #expect(r.sent == false)
        #expect(r.fallHoldID == ordered[2].id)
        #expect(r.fallStepIndex == 3)
        #expect(r.reason == .timing)
        #expect(r.note == "先看清再出手")
        #expect(r.check == .noChange)
        #expect(r.reminderSnapshot == "旧的一句")
        #expect(r.source == .backfill)
        #expect(r.attempts == expected.attempts)
        // 提醒也回来了
        #expect(line.reminderText == "掉在 ③ · 时机 · 先看清再出手")
        #expect(line.reminderSessionID == r.id)
    }

    @Test("deleteSession 撤销：只有原因没有掉落点的记录，提醒也应恢复")
    func deleteSessionUndoRestoresReminderWithoutFall() throws {
        let (_, _, line) = try f.makeLine()
        let s = f.store.newSession(for: line, date: f.daysAgo(2))
        s.reason = .power
        f.store.commitSession(s, line: line, fallLabel: nil)
        #expect(line.reminderText == "没力")
        let undo = f.store.deleteSession(s, from: line)
        #expect(line.reminderText == nil)
        undo()
        #expect(line.reminderText == "没力")
        #expect(line.reminderSessionID == s.id)
    }
}

// MARK: - 提醒验证

@MainActor
@Suite("Store · 提醒验证")
struct StoreReminderCheckTests {
    let f: StoreFixture
    init() throws { f = try StoreFixture() }

    /// 有提醒（来自 5 天前的记录 A）+ 一条昨天新建的空记录 B。
    private func lineWithReminderAndFollowUp() throws -> (Line, Session, Session) {
        let (_, _, line) = try f.makeLine()
        let ordered = HoldNumbering.ordered(line.holds)
        let a = f.store.newSession(for: line, date: f.daysAgo(5))
        a.fallHoldID = ordered[0].id
        a.reason = .feet
        a.note = "xxx"
        f.store.commitSession(a, line: line, fallLabel: line.label(for: a.fallHoldID))
        let b = f.store.newSession(for: line, date: f.daysAgo(1))
        return (line, a, b)
    }

    @Test("提醒之后新建一条记录 → pendingCheckSession 是它")
    func pendingCheckSession() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        #expect(line.pendingCheckSession?.id == b.id)
    }

    @Test("没有提醒或没有后续记录时 pendingCheckSession == nil")
    func pendingCheckSessionNil() throws {
        let (_, _, line) = try f.makeLine()
        #expect(line.pendingCheckSession == nil)
        let a = f.store.newSession(for: line, date: f.daysAgo(5))
        a.reason = .body
        f.store.commitSession(a, line: line, fallLabel: nil)
        #expect(line.reminderText != nil)
        #expect(line.pendingCheckSession == nil)
    }

    @Test("answerCheck(.worked) → reminderVerified，之后不再追问；撤销恢复")
    func answerWorked() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        let undo = f.store.answerCheck(b, line: line, check: .worked)
        #expect(b.check == .worked)
        #expect(line.reminderVerified == true)
        #expect(line.pendingCheckSession == nil)
        undo()
        #expect(b.check == nil)
        #expect(line.reminderVerified == false)
        #expect(line.pendingCheckSession?.id == b.id)
    }

    @Test(".noChange / .notTested 不动提醒")
    func answerNeutral() throws {
        let (line, a, b) = try lineWithReminderAndFollowUp()
        _ = f.store.answerCheck(b, line: line, check: .noChange)
        #expect(line.reminderText == "掉在 ① · 脚 · xxx")
        #expect(line.reminderSessionID == a.id)
        #expect(line.reminderVerified == false)
        #expect(line.pendingCheckSession == nil)
    }

    @Test(".differentProblem 且新记录有内容 → 提醒被替换")
    func answerDifferentProblemReplaces() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        let ordered = HoldNumbering.ordered(line.holds)
        b.fallHoldID = ordered[2].id
        b.reason = .body
        _ = f.store.answerCheck(b, line: line, check: .differentProblem)
        #expect(line.reminderText == "掉在 ③ · 身体")
        #expect(line.reminderSessionID == b.id)
        #expect(line.reminderVerified == false)
    }

    @Test(".differentProblem 但新记录无内容 → 保留旧提醒")
    func answerDifferentProblemWithoutContent() throws {
        let (line, a, b) = try lineWithReminderAndFollowUp()
        _ = f.store.answerCheck(b, line: line, check: .differentProblem)
        #expect(line.reminderText == "掉在 ① · 脚 · xxx")
        #expect(line.reminderSessionID == a.id)
    }

    @Test(".differentProblem 的撤销应把被替换的提醒也恢复")
    func answerDifferentProblemUndoRestoresReminder() throws {
        let (line, a, b) = try lineWithReminderAndFollowUp()
        let ordered = HoldNumbering.ordered(line.holds)
        b.fallHoldID = ordered[2].id
        b.reason = .body
        let undo = f.store.answerCheck(b, line: line, check: .differentProblem)
        #expect(line.reminderText == "掉在 ③ · 身体")
        undo()
        #expect(b.check == nil)
        #expect(line.reminderText == "掉在 ① · 脚 · xxx")
        #expect(line.reminderSessionID == a.id)
    }

    @Test("记这一次里回答：新记录有内容时提醒换新，验证和旧提醒原文留在新记录上")
    func commitWithCheckKeepsProof() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        let old = try #require(line.reminderText)
        let ordered = HoldNumbering.ordered(line.holds)
        let draft = SessionDraft(attemptCount: 3, fallHoldID: ordered[2].id, reason: .body, note: "贴墙再翻", check: .noChange)
        f.store.commit(draft, to: b, line: line, date: b.date, checking: old)
        #expect(b.check == .noChange)
        #expect(b.reminderSnapshot == old)
        #expect(line.reminderText == "掉在 ③ · 身体 · 贴墙再翻")
        #expect(line.reminderSessionID == b.id)
        #expect(line.pendingCheckSession == nil)
    }

    @Test("记这一次里答“有用”且没写新内容：旧提醒保留并标 ✓")
    func commitWorkedWithoutContent() throws {
        let (line, a, b) = try lineWithReminderAndFollowUp()
        let old = try #require(line.reminderText)
        f.store.commit(SessionDraft(attemptCount: 2, sent: true, check: .worked), to: b, line: line, date: b.date, checking: old)
        #expect(b.check == .worked)
        #expect(b.reminderSnapshot == old)
        #expect(line.reminderText == old)
        #expect(line.reminderSessionID == a.id)
        #expect(line.reminderVerified)
        #expect(line.pendingCheckSession == nil)
    }

    @Test("问了但没回答：不写验证，提醒照常换新")
    func commitSkippedCheck() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        let old = try #require(line.reminderText)
        f.store.commit(SessionDraft(attemptCount: 1, reason: .fear), to: b, line: line, date: b.date, checking: old)
        #expect(b.check == nil)
        #expect(b.reminderSnapshot == nil)
        #expect(line.reminderText == "不敢")
        #expect(line.reminderSessionID == b.id)
    }

    @Test("表单没出现验证问句时，草稿里的回答不写进记录")
    func commitWithoutPromptIgnoresCheck() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        f.store.commit(SessionDraft(attemptCount: 1, check: .worked), to: b, line: line, date: b.date)
        #expect(b.check == nil)
        #expect(line.reminderVerified == false)
    }

    @Test("线路页兜底回答也记下被验证的提醒原文；撤销一起恢复")
    func answerCheckWritesSnapshot() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        let undo = f.store.answerCheck(b, line: line, check: .notTested)
        #expect(b.reminderSnapshot == "掉在 ① · 脚 · xxx")
        undo()
        #expect(b.reminderSnapshot == nil)
    }

    @Test("教练几句只在有新记录等回答时说“还没回答”")
    func coachNagsOnlyWhenPending() throws {
        let (line, _, b) = try lineWithReminderAndFollowUp()
        #expect(CoachSummary.sentences(for: line.digest()).contains { $0.contains("还没回答") })
        b.reason = .power
        f.store.commitSession(b, line: line, fallLabel: nil)
        #expect(line.reminderSessionID == b.id)
        #expect(!CoachSummary.sentences(for: line.digest()).contains { $0.contains("还没回答") })
    }

    @Test("首页卡片只画一个掉落点：提醒来源那次；没提醒时是上次掉的那次")
    func cardFallMarks() throws {
        let (line, a, b) = try lineWithReminderAndFollowUp()
        #expect(line.cardFallMarks.map(\.holdID) == [a.fallHoldID!])
        let ordered = HoldNumbering.ordered(line.holds)
        b.fallHoldID = ordered[3].id
        f.store.commitSession(b, line: line, fallLabel: line.label(for: b.fallHoldID))
        #expect(line.cardFallMarks.map(\.holdID) == [ordered[3].id])
        f.store.updateReminder(line, text: "")
        #expect(line.cardFallMarks.map(\.holdID) == [ordered[3].id])
        b.fallHoldID = nil
        b.reason = .power
        #expect(line.cardFallMarks.isEmpty)
    }

    @Test("updateReminder：改字、清空")
    func updateReminder() throws {
        let (line, _, _) = try lineWithReminderAndFollowUp()
        f.store.updateReminder(line, text: "  换成这句  ")
        #expect(line.reminderText == "换成这句")
        #expect(line.reminderSessionID != nil)
        f.store.updateReminder(line, text: "   ")
        #expect(line.reminderText == nil)
        #expect(line.reminderSessionID == nil)
    }
}

// MARK: - 状态

@MainActor
@Suite("Store · 状态")
struct StoreStatusTests {
    let f: StoreFixture
    init() throws { f = try StoreFixture() }

    @Test("markSent / newCycle 与撤销")
    func applyAndUndo() throws {
        let (_, _, line) = try f.makeLine()
        let undoSent = try #require(f.store.apply(.markSent, to: line))
        #expect(line.status == .sent)
        #expect(line.cycle == 1)
        let undoCycle = try #require(f.store.apply(.newCycle, to: line))
        #expect(line.status == .projecting)
        #expect(line.cycle == 2)
        undoCycle()
        #expect(line.status == .sent)
        #expect(line.cycle == 1)
        undoSent()
        #expect(line.status == .projecting)
        #expect(line.cycle == 1)
    }

    @Test("gone 之后任何动作都返回 nil")
    func goneIsTerminal() throws {
        let (_, _, line) = try f.makeLine()
        #expect(f.store.apply(.markGone, to: line) != nil)
        #expect(line.status == .gone)
        for action in LineAction.allCases {
            #expect(f.store.apply(action, to: line) == nil)
        }
        #expect(line.status == .gone)
    }

    @Test("不允许的动作返回 nil 且不改状态")
    func disallowedAction() throws {
        let (_, _, line) = try f.makeLine()
        #expect(f.store.apply(.newCycle, to: line) == nil)
        #expect(line.status == .projecting)
        #expect(line.cycle == 1)
    }

    @Test("resetWall 把墙上所有线置 gone，撤销恢复各自原状态")
    func resetWall() throws {
        let (_, wall, a) = try f.makeLine()
        let b = f.store.createLine(wall: wall, holds: a.holds, startHoldIDs: a.startHoldIDs, finishHoldID: a.finishHoldID,
                                   gradeText: "V5", gradeSource: .manual, name: "红")
        let c = f.store.createLine(wall: wall, holds: a.holds, startHoldIDs: a.startHoldIDs, finishHoldID: a.finishHoldID,
                                   gradeText: "V1", gradeSource: .manual, name: "绿")
        _ = f.store.apply(.markSent, to: b)
        _ = f.store.apply(.drop, to: c)
        #expect(wall.resetAt == nil)

        let undo = f.store.resetWall(wall)
        #expect(a.status == .gone)
        #expect(b.status == .gone)
        #expect(c.status == .gone)
        #expect(wall.resetAt != nil)

        undo()
        #expect(a.status == .projecting)
        #expect(b.status == .sent)
        #expect(c.status == .dropped)
        #expect(wall.resetAt == nil)
    }
}

// MARK: - 删除 / 合并

@MainActor
@Suite("Store · 删除与合并")
struct StoreDeleteMergeTests {
    let f: StoreFixture
    init() throws { f = try StoreFixture() }

    @Test("softDelete → deletedAt != nil；撤销恢复")
    func softDelete() throws {
        let (_, _, line) = try f.makeLine()
        let undo = f.store.softDelete(line)
        #expect(line.deletedAt != nil)
        #expect(line.isVisible == false)
        undo()
        #expect(line.deletedAt == nil)
        #expect(line.isVisible)
    }

    @Test("purgeDeleted 只清超过 24h 的")
    func purgeDeleted() throws {
        let (_, wall, old) = try f.makeLine()
        let fresh = f.store.createLine(wall: wall, holds: old.holds, startHoldIDs: old.startHoldIDs, finishHoldID: old.finishHoldID,
                                       gradeText: nil, gradeSource: nil, name: "刚删的")
        let alive = f.store.createLine(wall: wall, holds: old.holds, startHoldIDs: old.startHoldIDs, finishHoldID: old.finishHoldID,
                                       gradeText: nil, gradeSource: nil, name: "没删的")
        _ = f.store.incrementAttempt(old)
        old.deletedAt = Date.now.addingTimeInterval(-2 * 24 * 3600)
        fresh.deletedAt = .now
        f.store.save()

        f.store.purgeDeleted()
        let remaining = try f.fetchLines().map(\.id)
        #expect(remaining.contains(fresh.id))
        #expect(remaining.contains(alive.id))
        let sessionsLeft = try f.fetchSessions().count
        #expect(!remaining.contains(old.id))
        #expect(sessionsLeft == 0, "被清掉的线的记录也应级联删除")
    }

    @Test("purgeDeleted 想要的谓词写法（if-let）能被 SwiftData 执行")
    func purgePredicateWorkaround() throws {
        let (_, _, old) = try f.makeLine()
        old.deletedAt = Date.now.addingTimeInterval(-2 * 24 * 3600)
        f.store.save()
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        let d = FetchDescriptor<Line>(predicate: #Predicate { line in
            if let deletedAt = line.deletedAt { return deletedAt < cutoff } else { return false }
        })
        let matched = try f.context.fetch(d)
        #expect(matched.map(\.id) == [old.id])
    }

    @Test("merge(a, into: b)：记录搬家、mergedIntoLineID、继承提醒；撤销全部恢复")
    func mergeAndUndo() throws {
        let (_, wall, a) = try f.makeLine()
        let b = f.store.createLine(wall: wall, holds: a.holds, startHoldIDs: a.startHoldIDs, finishHoldID: a.finishHoldID,
                                   gradeText: "V3", gradeSource: .manual, name: "目标")
        let ordered = HoldNumbering.ordered(a.holds)
        let s1 = f.store.newSession(for: a, date: f.daysAgo(6))
        s1.attemptCount = 3
        s1.fallHoldID = ordered[1].id
        s1.reason = .reach
        f.store.commitSession(s1, line: a, fallLabel: a.label(for: s1.fallHoldID))
        let s2 = f.store.newSession(for: a, date: f.daysAgo(2))
        s2.attemptCount = 2
        f.store.commitSession(s2, line: a, fallLabel: nil)
        #expect(a.reminderText == "掉在 ② · 够不着")
        #expect(b.reminderText == nil)
        let movedIDs = Set(a.sessions.map(\.id))

        let undo = f.store.merge(a, into: b)
        #expect(a.sessions.isEmpty)
        #expect(Set(b.sessions.map(\.id)) == movedIDs)
        #expect(b.sessions.allSatisfy { $0.line?.id == b.id })
        #expect(a.mergedIntoLineID == b.id)
        #expect(a.isVisible == false)
        #expect(b.reminderText == "掉在 ② · 够不着")
        #expect(b.reminderSessionID == s1.id)
        #expect(b.visitCount == 2)
        #expect(b.totalAttempts == 5)
        #expect(try f.fetchSessions().count == 2)

        undo()
        #expect(Set(a.sessions.map(\.id)) == movedIDs)
        #expect(a.sessions.allSatisfy { $0.line?.id == a.id })
        #expect(b.sessions.isEmpty)
        #expect(a.mergedIntoLineID == nil)
        #expect(a.isVisible)
        #expect(b.reminderText == nil)
        #expect(b.reminderSessionID == nil)
        #expect(a.reminderText == "掉在 ② · 够不着")
    }

    @Test("merge 时目标已有提醒则不覆盖")
    func mergeKeepsTargetReminder() throws {
        let (_, wall, a) = try f.makeLine()
        let b = f.store.createLine(wall: wall, holds: a.holds, startHoldIDs: a.startHoldIDs, finishHoldID: a.finishHoldID,
                                   gradeText: nil, gradeSource: nil, name: "目标")
        let sa = f.store.newSession(for: a, date: f.daysAgo(3))
        sa.reason = .fear
        f.store.commitSession(sa, line: a, fallLabel: nil)
        let sb = f.store.newSession(for: b, date: f.daysAgo(1))
        sb.reason = .power
        f.store.commitSession(sb, line: b, fallLabel: nil)
        _ = f.store.merge(a, into: b)
        #expect(b.reminderText == "没力")
        #expect(b.reminderSessionID == sb.id)
        #expect(b.sessions.count == 2)
    }

    @Test("deleteEverything 清空后 ensureDefaultGym 重建")
    func deleteEverything() throws {
        _ = try f.makeLine()
        _ = f.store.addGym(name: "第二家")
        f.store.deleteEverything()
        #expect(f.store.gyms().isEmpty)
        #expect(try f.fetchLines().isEmpty)
        #expect(try f.fetchSessions().isEmpty)
        let gym = f.store.ensureDefaultGym()
        #expect(f.store.gyms().count == 1)
        #expect(gym.name == "我的岩馆")
    }
}

// MARK: - 导出

@MainActor
@Suite("导出")
struct ExportBundleTests {
    let f: StoreFixture
    init() throws { f = try StoreFixture() }

    @Test("makeBundle → JSON 编码再解码，数量与关键字段一致")
    func roundTrip() throws {
        let (gym, wall, line) = try f.makeLine()
        let other = f.store.addGym(name: "第二家")
        let wall2 = try f.store.createWall(gym: other, image: nil, areaName: "仰角墙", angle: .overhang)
        let line2 = f.store.createLine(wall: wall2, holds: [], startHoldIDs: [], finishHoldID: nil,
                                       gradeText: "紫色", gradeSource: .manual, name: "无照片那条")
        let ordered = HoldNumbering.ordered(line.holds)
        let s1 = f.store.newSession(for: line, date: f.daysAgo(3))
        s1.attemptCount = 4
        s1.fallHoldID = ordered[1].id
        s1.reason = .feet
        s1.note = "脚先踩高"
        s1.attempts = [AttemptRecord(sent: false, fallHoldID: ordered[1].id)]
        f.store.commitSession(s1, line: line, fallLabel: line.label(for: s1.fallHoldID))
        let s2 = f.store.newSession(for: line, date: .now)
        s2.sent = true
        s2.check = .worked
        f.store.commitSession(s2, line: line, fallLabel: nil)
        line.actualSequence = ClimbSequence(steps: [SequenceStep(limb: .leftHand, holdID: ordered[1].id)])
        line.feltGrade = .hard
        f.store.save()

        let bundle = ExportService.makeBundle(gyms: f.store.gyms())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportService.Bundle.self, from: data)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.gyms.count == 2)
        let g = try #require(decoded.gyms.first { $0.id == gym.id })
        #expect(g.name == gym.name)
        #expect(g.walls.count == 1)
        let w = try #require(g.walls.first)
        #expect(w.id == wall.id)
        #expect(w.areaName == "斜板墙")
        #expect(w.angle == WallAngle.slab.rawValue)
        #expect(w.photoFileName == nil)
        #expect(w.lines.count == 1)
        let l = try #require(w.lines.first)
        #expect(l.id == line.id)
        #expect(l.name == line.name)
        #expect(l.holds == line.holds)
        #expect(l.startHoldIDs == line.startHoldIDs)
        #expect(l.finishHoldID == line.finishHoldID)
        #expect(l.gradeText == "V3")
        #expect(l.gradeSource == "manual")
        #expect(l.feltGrade == "hard")
        #expect(l.status == LineStatus.sent.rawValue)
        #expect(l.cycle == 1)
        #expect(l.reminderText == "掉在 ② · 脚 · 脚先踩高")
        #expect(l.reminderSessionID == s1.id)
        #expect(l.actualSequence == line.actualSequence)
        #expect(l.planSequence == nil)
        #expect(l.sessions.count == 2)
        #expect(l.sessions.map(\.id) == [s1.id, s2.id], "按日期升序")
        let d1 = l.sessions[0]
        #expect(d1.attemptCount == 4)
        #expect(d1.fallHoldID == ordered[1].id)
        #expect(d1.reason == "feet")
        #expect(d1.note == "脚先踩高")
        #expect(d1.source == SessionSource.backfill.rawValue)
        #expect(d1.attempts == s1.attempts)
        #expect(abs(d1.date.timeIntervalSince(s1.date)) < 1)
        let d2 = l.sessions[1]
        #expect(d2.sent)
        #expect(d2.check == "worked")

        let g2 = try #require(decoded.gyms.first { $0.id == other.id })
        #expect(g2.walls.first?.lines.first?.id == line2.id)
        #expect(g2.walls.first?.lines.first?.holds.isEmpty == true)
        #expect(g2.walls.first?.lines.first?.gradeText == "紫色")
    }

    @Test("exportJSON 写出文件")
    func exportJSONWritesFile() throws {
        _ = try f.makeLine()
        let url = try ExportService.exportJSON(gyms: f.store.gyms())
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "json")
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportService.Bundle.self, from: data)
        #expect(decoded.gyms.count == 1)
    }
}
