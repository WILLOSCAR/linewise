import Foundation
import Testing
@testable import LineWise

@Suite("编号")
struct HoldNumberingTests {
    @Test("从下往上编号，同高从左往右")
    func ordering() {
        let a = Hold(x: 0.5, y: 0.9)   // 最低 → 1
        let b = Hold(x: 0.2, y: 0.5)   // 同高偏左 → 2
        let c = Hold(x: 0.8, y: 0.5)   // 同高偏右 → 3
        let d = Hold(x: 0.5, y: 0.1)   // 最高 → 4
        let numbers = HoldNumbering.numbers(for: [d, c, a, b])
        #expect(numbers[a.id] == 1)
        #expect(numbers[b.id] == 2)
        #expect(numbers[c.id] == 3)
        #expect(numbers[d.id] == 4)
    }

    @Test("默认起步最低、结束最高")
    func defaults() {
        let low = Hold(x: 0.5, y: 0.9)
        let high = Hold(x: 0.5, y: 0.1)
        let sf = HoldNumbering.defaultStartAndFinish([high, low])
        #expect(sf.start == [low.id])
        #expect(sf.finish == high.id)
        let single = HoldNumbering.defaultStartAndFinish([low])
        #expect(single.start == [low.id])
        #expect(single.finish == nil)
    }

    @Test("带圈数字")
    func labels() {
        #expect(HoldLabel.circled(1) == "①")
        #expect(HoldLabel.circled(20) == "⑳")
        #expect(HoldLabel.circled(21) == "㉑")
        #expect(HoldLabel.circled(36) == "㊱")
        #expect(HoldLabel.circled(51) == "#51")
    }
}

@Suite("提醒")
struct ReminderTests {
    @Test func composeAll() {
        #expect(ReminderComposer.compose(fallLabel: "⑤", reason: .feet, note: " 右脚先踩高 ") == "掉在 ⑤ · 脚 · 右脚先踩高")
    }

    @Test func composePartial() {
        #expect(ReminderComposer.compose(fallLabel: nil, reason: .body, note: nil) == "身体")
        #expect(ReminderComposer.compose(fallLabel: nil, reason: nil, note: "  ") == nil)
    }
}

@Suite("记这一次 · 要不要问上次提醒")
struct ReminderCheckPromptTests {
    private let today = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
    private let source = UUID()

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: today)!
    }

    private func ask(reminder: String? = "掉在 ① · 脚", sourceDate: Date?, editing: [UUID] = [], target: Date) -> Bool {
        ReminderCheckPrompt.shouldAsk(reminder: reminder, reminderSessionID: source, reminderSessionDate: sourceDate,
                                      editingSessionIDs: editing, targetDate: target)
    }

    @Test("更早记录留下的提醒：新建或改之后的记录时问")
    func asksForLaterSession() {
        #expect(ask(sourceDate: day(-3), target: today))
        #expect(ask(sourceDate: day(-3), editing: [UUID()], target: today))
    }

    @Test("同一天（比如新一轮）按日期比较，不看时刻")
    func sameDay() {
        #expect(ask(sourceDate: today.addingTimeInterval(20 * 3600), target: today))
    }

    @Test("改的就是提醒来源、日期早于来源、没有提醒或找不到来源：不问")
    func skips() {
        #expect(!ask(sourceDate: day(-3), editing: [source], target: today))
        #expect(!ask(sourceDate: day(-3), target: day(-5)))
        #expect(!ask(reminder: "  ", sourceDate: day(-3), target: today))
        #expect(!ask(reminder: nil, sourceDate: day(-3), target: today))
        #expect(!ask(sourceDate: nil, target: today))
        #expect(!ReminderCheckPrompt.shouldAsk(reminder: "x", reminderSessionID: nil, reminderSessionDate: day(-3),
                                               editingSessionIDs: [], targetDate: today))
    }
}

@Suite("状态机")
struct StatusMachineTests {
    @Test func transitions() {
        #expect(LineStatusMachine.apply(.markSent, status: .projecting, cycle: 1)! == (.sent, 1))
        #expect(LineStatusMachine.apply(.newCycle, status: .sent, cycle: 1)! == (.projecting, 2))
        #expect(LineStatusMachine.apply(.newCycle, status: .dropped, cycle: 3)! == (.projecting, 4))
        #expect(LineStatusMachine.apply(.markGone, status: .projecting, cycle: 1)! == (.gone, 1))
        #expect(LineStatusMachine.apply(.markSent, status: .gone, cycle: 1) == nil)
        #expect(LineStatusMachine.apply(.markSent, status: .sent, cycle: 1) == nil)
    }
}

@Suite("顺序")
struct SequenceTests {
    let h1 = Hold(x: 0.3, y: 0.9)
    let h2 = Hold(x: 0.5, y: 0.6)
    let h3 = Hold(x: 0.5, y: 0.2)

    @Test("初始：双手起步、双脚地面")
    func initial() {
        let s = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: [h1, h2, h3])
        #expect(s[.leftHand] == h1.id)
        #expect(s[.rightHand] == h1.id)
        #expect(s[.leftFoot] == nil)
        #expect(s[.rightFoot] == nil)
    }

    @Test("追加会截断后面的步骤")
    func appendTruncates() {
        var seq = ClimbSequence()
        seq = seq.appending(SequenceStep(limb: .leftHand, holdID: h2.id), after: -1)
        seq = seq.appending(SequenceStep(limb: .rightHand, holdID: h2.id), after: 0)
        seq = seq.appending(SequenceStep(limb: .leftHand, holdID: h3.id), after: 1)
        #expect(seq.steps.count == 3)
        let rewound = seq.appending(SequenceStep(limb: .rightFoot, holdID: h1.id), after: 0)
        #expect(rewound.steps.count == 2)
        #expect(rewound.steps[1].limb == .rightFoot)
    }

    @Test("完成：双手到结束点")
    func completion() {
        let initial = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: [h1, h2, h3])
        var seq = ClimbSequence()
        seq = seq.appending(SequenceStep(limb: .leftHand, holdID: h3.id), after: -1)
        #expect(!SequenceReplay.isComplete(SequenceReplay.state(of: seq, after: 1, initial: initial), finishHoldID: h3.id))
        seq = seq.appending(SequenceStep(limb: .rightHand, holdID: h3.id), after: 0)
        #expect(SequenceReplay.isComplete(SequenceReplay.state(of: seq, after: 2, initial: initial), finishHoldID: h3.id))
    }

    @Test("计划与实际差异")
    func diff() {
        let plan = ClimbSequence(steps: [SequenceStep(limb: .leftHand, holdID: h2.id), SequenceStep(limb: .rightHand, holdID: h3.id)])
        let actual = ClimbSequence(steps: [SequenceStep(limb: .leftHand, holdID: h2.id), SequenceStep(limb: .rightHand, holdID: h2.id), SequenceStep(limb: .rightHand, holdID: h3.id)])
        #expect(SequenceReplay.differingStepIndices(plan: plan, actual: actual) == [1, 2])
    }
}

@Suite("火柴人")
struct StickFigureTests {
    @Test("双手在高处、脚够不到地面时，脚下垂而不拉扯肩手")
    func hangingPose() {
        let p = StickFigureSolver.Proportions.make(profile: .default, figureHeight: 0.3)
        let contacts = StickFigureSolver.Contacts(leftHand: CGPoint(x: 0.4, y: 0.5), rightHand: CGPoint(x: 0.6, y: 0.5), leftFoot: nil, rightFoot: nil)
        let pose = StickFigureSolver.solve(contacts: contacts, proportions: p, groundY: 0.98, bounds: CGRect(x: 0, y: 0, width: 0.75, height: 1))
        #expect(pose.hipCenter.y < pose.leftFoot.y)
        #expect(pose.leftFoot.y <= 0.98)
        let d = hypot(pose.leftShoulder.x - pose.leftHand.x, pose.leftShoulder.y - pose.leftHand.y)
        #expect(d <= p.armLength * 1.25)
    }

    @Test("站在地面：脚在地面、髋在脚上方一条腿长")
    func standingPose() {
        let p = StickFigureSolver.Proportions.make(profile: .default, figureHeight: 0.3)
        let contacts = StickFigureSolver.Contacts(leftHand: nil, rightHand: nil, leftFoot: nil, rightFoot: nil)
        let pose = StickFigureSolver.solve(contacts: contacts, proportions: p, groundY: 0.98, bounds: CGRect(x: 0, y: 0, width: 0.75, height: 1))
        #expect(pose.leftFoot.y == 0.98)
        #expect(abs((pose.leftFoot.y - pose.hipCenter.y) - p.legLength * 0.95) < 0.01)
    }

    @Test("双骨 IK 关节在两端之间")
    func ik() {
        let root = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 0.2, y: 0.2)
        let joint = StickFigureSolver.twoBoneJoint(root: root, end: end, l1: 0.2, l2: 0.2, bendLeft: true)
        let d1 = hypot(joint.x - root.x, joint.y - root.y)
        let d2 = hypot(joint.x - end.x, joint.y - end.y)
        #expect(abs(d1 - 0.2) < 0.001)
        #expect(abs(d2 - 0.2) < 0.001)
    }
}

@Suite("难度识别")
struct GradeParserTests {
    @Test func vGrades() {
        #expect(GradeParser.candidates(from: ["V4", "hello"]).first == "V4")
        #expect(GradeParser.candidates(from: ["v7+"]).first == "V7+")
        #expect(GradeParser.candidates(from: ["VB"]).first == "VB")
    }

    @Test func fontGrades() {
        #expect(GradeParser.candidates(from: ["6B+"]).first == "6B+")
        #expect(GradeParser.candidates(from: ["7a"]).first == "7A")
    }

    @Test func bareDigitOnlyWhenAlone() {
        #expect(GradeParser.candidates(from: [" 5 "]).first == "5")
        #expect(GradeParser.candidates(from: ["room 5"]).isEmpty)
    }
}

@Suite("教练几句")
struct CoachTests {
    private func session(daysAgo: Int, attempts: Int, fall: Int?, reason: FailReason?, sent: Bool = false, check: ReminderCheck? = nil) -> SessionDigest {
        SessionDigest(date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!, attemptCount: attempts, sent: sent, fallNumber: fall, reason: reason, note: nil, check: check, cycle: 1)
    }

    @Test("反复掉在同一点")
    func concentration() {
        let digest = LineDigest(sessions: [session(daysAgo: 9, attempts: 6, fall: 5, reason: .feet), session(daysAgo: 5, attempts: 4, fall: 5, reason: .feet), session(daysAgo: 1, attempts: 3, fall: 5, reason: .body)], reminder: "掉在 ⑤ · 脚", reminderVerified: false, reminderAnswered: false, status: .projecting, cycle: 1)
        let s = CoachSummary.sentences(for: digest)
        #expect(s.first?.contains("你在 ⑤ 掉了 3 次") == true)
        #expect(s.first?.contains("其中 2 次说是脚") == true)
        #expect(s.contains { $0.contains("还没回答") })
        #expect(s.count <= 3)
    }

    @Test("上了")
    func sent() {
        let digest = LineDigest(sessions: [session(daysAgo: 9, attempts: 6, fall: 3, reason: .feet), session(daysAgo: 1, attempts: 2, fall: nil, reason: nil, sent: true)], reminder: nil, reminderVerified: false, reminderAnswered: false, status: .sent, cycle: 1)
        let s = CoachSummary.sentences(for: digest)
        #expect(s.contains { $0.contains("2 次馆访、共 8 次尝试上的") })
    }

    @Test("没有记录不说话")
    func empty() {
        let digest = LineDigest(sessions: [], reminder: nil, reminderVerified: false, reminderAnswered: false, status: .projecting, cycle: 1)
        #expect(CoachSummary.sentences(for: digest).isEmpty)
    }
}
