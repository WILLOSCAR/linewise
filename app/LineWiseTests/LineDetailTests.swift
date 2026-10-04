import Foundation
import Testing
@testable import LineWise

/// 测试替身：只带筛选/保存判定需要的字段。
private struct FakeSession: SessionLike {
    var id = UUID()
    var date: Date
    var cycle: Int
}

private let calendar = Calendar.current
private let now = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000)) // 固定“今天”

private func daysAgo(_ n: Int) -> Date {
    calendar.date(byAdding: .day, value: -n, to: now)!
}

@Suite("历史筛选")
struct HistoryFilterTests {
    fileprivate let sessions: [FakeSession] = [
        FakeSession(date: daysAgo(120), cycle: 1),
        FakeSession(date: daysAgo(60), cycle: 1),
        FakeSession(date: daysAgo(20), cycle: 2),
        FakeSession(date: daysAgo(0), cycle: 2),
    ]

    @Test("默认不筛")
    func none() {
        let f = HistoryFilter()
        #expect(!f.isActive)
        #expect(f.apply(sessions, now: now).count == 4)
    }

    @Test("按轮次")
    func byCycle() {
        let f = HistoryFilter(cycle: 2)
        let out = f.apply(sessions, now: now)
        #expect(out.count == 2)
        #expect(out.allSatisfy { $0.cycle == 2 })
    }

    @Test("按时间范围：30 天 / 90 天，边界含当天")
    func byRange() {
        #expect(HistoryFilter(range: .days30).apply(sessions, now: now).count == 2)
        #expect(HistoryFilter(range: .days90).apply(sessions, now: now).count == 3)
        // 正好 30 天前的记录仍在范围内
        let edge = [FakeSession(date: daysAgo(30), cycle: 1), FakeSession(date: daysAgo(31), cycle: 1)]
        #expect(HistoryFilter(range: .days30).apply(edge, now: now).count == 1)
    }

    @Test("轮次与时间同时生效")
    func combined() {
        let f = HistoryFilter(cycle: 1, range: .days90)
        let out = f.apply(sessions, now: now)
        #expect(out.count == 1)
        #expect(out.first?.cycle == 1)
    }

    @Test("轮次选项只有多轮时才出现")
    func cycleOptions() {
        #expect(HistoryFilter.cycleOptions(maxCycle: 1).isEmpty)
        #expect(HistoryFilter.cycleOptions(maxCycle: 3) == [nil, 1, 2, 3])
    }
}

@Suite("记每一次：行数与次数同步")
struct AttemptSyncTests {
    @Test("增加次数补空行，已有行保留")
    func grow() {
        let hold = UUID()
        let rows = [AttemptRecord(sent: false, fallHoldID: hold)]
        let out = AttemptSync.resized(rows, to: 3)
        #expect(out.count == 3)
        #expect(out[0].fallHoldID == hold)
        #expect(out[1].fallHoldID == nil && out[2].fallHoldID == nil)
    }

    @Test("减少次数从尾部截掉")
    func shrink() {
        let rows = (0..<4).map { i in AttemptRecord(sent: i == 3) }
        let out = AttemptSync.resized(rows, to: 2)
        #expect(out.count == 2)
        #expect(out.allSatisfy { !$0.sent })
        #expect(AttemptSync.resized(rows, to: -1).isEmpty)
    }

    @Test("汇总：任一次上了即上了；掉哪取最后一次掉的点")
    func summary() {
        let a = UUID(), b = UUID()
        let rows = [
            AttemptRecord(sent: false, fallHoldID: a),
            AttemptRecord(sent: false, fallHoldID: b),
            AttemptRecord(sent: true, fallHoldID: nil),
        ]
        let s = AttemptSync.summary(rows)
        #expect(s.sent)
        #expect(s.lastFallHoldID == b)
        #expect(AttemptSync.summary([]).sent == false)
    }
}

@Suite("保存到哪条记录")
struct SessionSavePlanTests {
    @Test("目标日期没有记录：编辑中的直接写回，否则新建")
    func plain() {
        let base = FakeSession(date: daysAgo(3), cycle: 1)
        let sessions = [base]
        #expect(SessionSavePlan.resolve(baseID: base.id, day: daysAgo(3), cycle: 1, sessions: sessions) == .overwrite(base.id))
        #expect(SessionSavePlan.resolve(baseID: base.id, day: daysAgo(5), cycle: 1, sessions: sessions) == .overwrite(base.id))
        #expect(SessionSavePlan.resolve(baseID: nil, day: daysAgo(5), cycle: 1, sessions: sessions) == .create)
    }

    @Test("改日期到已有记录的那天：并进去并删掉原记录")
    func mergeOnDateChange() {
        let base = FakeSession(date: daysAgo(3), cycle: 1)
        let other = FakeSession(date: daysAgo(1), cycle: 1)
        let plan = SessionSavePlan.resolve(baseID: base.id, day: daysAgo(1), cycle: 1, sessions: [base, other])
        #expect(plan == .mergeInto(other.id, removing: base.id))
    }

    @Test("新建时选到已有记录的日期：并进去，不删任何东西")
    func mergeOnCreate() {
        let other = FakeSession(date: daysAgo(1), cycle: 1)
        let plan = SessionSavePlan.resolve(baseID: nil, day: daysAgo(1), cycle: 1, sessions: [other])
        #expect(plan == .mergeInto(other.id, removing: nil))
    }

    @Test("targetSessionID：写回或并入的那条；新建为 nil")
    func targetSessionID() {
        let a = UUID(), b = UUID()
        #expect(SessionSavePlan.overwrite(a).targetSessionID == a)
        #expect(SessionSavePlan.mergeInto(b, removing: a).targetSessionID == b)
        #expect(SessionSavePlan.create.targetSessionID == nil)
    }

    @Test("不同轮次的同一天不算冲突；日期按本地零点比较")
    func cycleAndDayNormalization() {
        let oldCycle = FakeSession(date: daysAgo(1), cycle: 1)
        #expect(SessionSavePlan.resolve(baseID: nil, day: daysAgo(1), cycle: 2, sessions: [oldCycle]) == .create)
        let noon = daysAgo(1).addingTimeInterval(12 * 3600)
        #expect(SessionSavePlan.resolve(baseID: nil, day: noon, cycle: 1, sessions: [oldCycle]) == .mergeInto(oldCycle.id, removing: nil))
    }
}

@Suite("草稿合并")
struct SessionDraftMergeTests {
    @Test("验证以草稿为先；草稿没答时保留原记录的回答")
    func mergeKeepsCheck() {
        #expect(SessionDraft(attemptCount: 1, check: .worked).merged(into: SessionDraft(check: .noChange)).check == .worked)
        #expect(SessionDraft(attemptCount: 1).merged(into: SessionDraft(check: .noChange)).check == .noChange)
    }

    @Test("次数相加、上了取或、掉哪与原因以草稿为先、一句话拼接")
    func merge() {
        let holdA = UUID(), holdB = UUID()
        let existing = SessionDraft(attemptCount: 3, sent: false, fallHoldID: holdA, fallStepIndex: 1, reason: .feet, note: "右脚先踩高")
        let draft = SessionDraft(attemptCount: 2, sent: true, fallHoldID: holdB, fallStepIndex: nil, reason: nil, note: "  出手要快 ")
        let out = draft.merged(into: existing)
        #expect(out.attemptCount == 5)
        #expect(out.sent)
        #expect(out.fallHoldID == holdB)
        #expect(out.fallStepIndex == nil)
        #expect(out.reason == .feet)
        #expect(out.note == "右脚先踩高；出手要快")
        #expect(out.attempts.isEmpty)
    }

    @Test("草稿没填掉哪时保留原来的")
    func keepsExistingFall() {
        let hold = UUID()
        let existing = SessionDraft(attemptCount: 1, fallHoldID: hold, fallStepIndex: 2)
        let out = SessionDraft(attemptCount: 1).merged(into: existing)
        #expect(out.fallHoldID == hold)
        #expect(out.fallStepIndex == 2)
    }

    @Test("任一方展开过逐次记录，合并后行数等于总次数")
    func attemptsConcat() {
        let existing = SessionDraft(attemptCount: 2, attempts: [AttemptRecord(), AttemptRecord(sent: true)])
        let draft = SessionDraft(attemptCount: 3)
        let out = draft.merged(into: existing)
        #expect(out.attempts.count == 5)
        #expect(out.attempts[1].sent)
    }
}

@Suite("无照片线的“掉在哪”：旧编码只读，新数据走 fallText")
struct NoPhotoFallTests {
    @Test("新旧无照片掉落位置贯穿历史、分享、问题变更和撤销")
    @MainActor
    func noPhotoReviewSurfaces() throws {
        let f = try StoreFixture()
        let (_, wall, line) = try f.makeLine(holdCount: 0)
        wall.photoFileName = nil
        let session = f.store.newSession(for: line, date: f.daysAgo(0))
        session.note = "掉在 大球 · 右脚踩高"
        #expect(SessionRow(line: line, session: session).headline.contains("掉在 大球"))
        #expect(ShareVisit(session: session).fallText == "大球")
        session.fallText = "第三个点"
        session.note = nil
        session.sent = true
        let headline = SessionRow(line: line, session: session).headline
        #expect(headline.contains("掉在 第三个点"))
        #expect(!headline.contains("没掉"))
        line.reminderText = "上次的提醒"
        let undo = f.store.answerCheck(session, line: line, check: .differentProblem)
        #expect(line.reminderText == "掉在 第三个点")
        undo()
        #expect(line.reminderText == "上次的提醒")
        #expect(session.check == nil)
    }

    @Test("旧编码解码")
    func decodeLegacy() {
        let decoded = NoPhotoFall.decode("掉在 大球 · 右脚踩高")
        #expect(decoded.fall == "大球")
        #expect(decoded.note == "右脚踩高")
        #expect(NoPhotoFall.decode("掉在 第三个点").fall == "第三个点")
        #expect(NoPhotoFall.decode("普通备注").note == "普通备注")
        #expect(NoPhotoFall.decode(nil).note == "")
    }

    @Test("新字段优先；没有新字段时才拆旧前缀")
    func resolve() {
        let fresh = NoPhotoFall.resolve(fallText: "第三个点", note: "掉在 大球 · 别拆我")
        #expect(fresh.fall == "第三个点")
        #expect(fresh.note == "掉在 大球 · 别拆我")
        let legacy = NoPhotoFall.resolve(fallText: nil, note: "掉在 大球 · 出手前先休息")
        #expect(legacy.fall == "大球")
        #expect(legacy.note == "出手前先休息")
    }

    @Test("草稿合并时文字版掉在哪以草稿为先，空则保留")
    func mergeFallText() {
        let existing = SessionDraft(attemptCount: 1, fallText: "大球")
        #expect(SessionDraft(attemptCount: 1, fallText: " 小球 ").merged(into: existing).fallText == "小球")
        #expect(SessionDraft(attemptCount: 1).merged(into: existing).fallText == "大球")
    }
}

@Suite("头图副标题去重")
struct LineHeroSubtitleTests {
    @Test("线名已含墙区与角度时不再重复")
    func dedupe() {
        #expect(LineHeroSubtitle.make(name: "直壁 · 黄", area: "直壁·黄", grade: "V3", felt: nil, angle: "直壁") == "V3")
        #expect(LineHeroSubtitle.make(name: "大斜板 · 白", area: "大斜板", grade: "V4", felt: nil, angle: "斜板") == "V4")
    }

    @Test("不重复的部分按 墙区 · 难度 · 感觉 · 角度 排列；无照片补一句")
    func order() {
        #expect(LineHeroSubtitle.make(name: "小红", area: "仰角墙", grade: "V5", felt: "感觉偏硬", angle: "仰角") == "仰角墙 · V5 · 感觉偏硬")
        #expect(LineHeroSubtitle.make(name: "训练区 · 无照片", area: "训练区", grade: nil, felt: nil, angle: nil, hasPhoto: false) == "无照片")
    }
}
