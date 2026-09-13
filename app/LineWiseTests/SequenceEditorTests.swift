import Foundation
import SwiftData
import Testing
@testable import LineWise

@Suite("顺序持久化")
@MainActor
struct SequenceStoreTests {
    @Test("保存：空序列存 nil；复制为实际可撤销")
    func saveAndCopy() throws {
        let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let store = Store(container.mainContext)
        let gym = store.addGym(name: "测试馆")
        let wall = try store.createWall(gym: gym, image: nil, areaName: nil, angle: .unknown)
        let holds = [Hold(x: 0.5, y: 0.9), Hold(x: 0.5, y: 0.2)]
        let line = store.createLine(wall: wall, holds: holds, startHoldIDs: [holds[0].id], finishHoldID: holds[1].id,
                                    gradeText: nil, gradeSource: nil, name: "线")
        let before = line.updatedAt

        store.saveSequence(ClimbSequence(steps: [SequenceStep(limb: .leftHand, holdID: holds[1].id)]), kind: .plan, line: line)
        #expect(line.planSequence?.steps.count == 1)
        #expect(line.actualSequence == nil)
        #expect(line.sequenceDifferenceCount == nil)
        #expect(line.updatedAt >= before)

        let undo = store.copyPlanToActual(line)
        #expect(line.actualSequence == line.planSequence)
        #expect(line.sequenceDifferenceCount == 0)
        undo()
        #expect(line.actualSequence == nil)

        store.saveSequence(ClimbSequence(steps: [SequenceStep(limb: .rightHand, holdID: holds[1].id)]), kind: .actual, line: line)
        #expect(line.sequenceDifferenceCount == 1)

        store.saveSequence(ClimbSequence(), kind: .plan, line: line)
        #expect(line.planSequence == nil)
        store.saveSequence(nil, kind: .actual, line: line)
        #expect(line.actualSequence == nil)
    }
}

@Suite("顺序编辑器状态机")
struct SequenceEditorModelTests {
    let h1 = Hold(x: 0.3, y: 0.9)
    let h2 = Hold(x: 0.5, y: 0.6)
    let h3 = Hold(x: 0.4, y: 0.4)
    let h4 = Hold(x: 0.5, y: 0.2)

    var holds: [Hold] { [h1, h2, h3, h4] }

    func makeModel(_ sequence: ClimbSequence? = nil) -> SequenceEditorModel {
        let initial = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: holds)
        return SequenceEditorModel(sequence: sequence, initial: initial, finishHoldID: h4.id)
    }

    @Test("空序列从起步开始")
    func emptyStart() {
        let m = makeModel()
        #expect(m.currentIndex == -1)
        #expect(m.currentCell == 0)
        #expect(m.stepCount == 0)
        #expect(m.currentState[.leftHand] == h1.id)
        #expect(m.currentState[.rightHand] == h1.id)
        #expect(m.currentState[.leftFoot] == nil)
        #expect(!m.canUndo)
        #expect(!m.isRewound)
        #expect(!m.isComplete)
    }

    @Test("已有序列从最后一步开始")
    func startsAtLastStep() {
        let m = makeModel(ClimbSequence(steps: [
            SequenceStep(limb: .leftHand, holdID: h2.id),
            SequenceStep(limb: .rightHand, holdID: h3.id),
        ]))
        #expect(m.currentIndex == 1)
        #expect(m.currentCell == 2)
        #expect(m.currentState[.rightHand] == h3.id)
    }

    @Test("追加一步：序列增长、位置前移")
    func append() {
        var m = makeModel()
        let r = m.apply(limb: .leftFoot, holdID: h2.id)
        #expect(r != nil)
        #expect(r?.truncated.isEmpty == true)
        #expect(r?.justCompleted == false)
        #expect(m.stepCount == 1)
        #expect(m.currentIndex == 0)
        #expect(m.currentState[.leftFoot] == h2.id)
        #expect(m.canUndo)
    }

    @Test("拖到已在的点等于无操作")
    func noop() {
        var m = makeModel()
        #expect(m.apply(limb: .leftHand, holdID: h1.id) == nil)
        #expect(m.stepCount == 0)
        m.apply(limb: .leftHand, holdID: h2.id)
        #expect(m.apply(limb: .leftHand, holdID: h2.id) == nil)
        #expect(m.stepCount == 1)
    }

    @Test("回退后追加会替换后面的步骤")
    func rewindThenAppend() {
        var m = makeModel()
        m.apply(limb: .leftHand, holdID: h2.id)
        m.apply(limb: .rightHand, holdID: h2.id)
        m.apply(limb: .leftHand, holdID: h3.id)
        #expect(m.stepCount == 3)

        m.rewind(toCell: 1)
        #expect(m.currentIndex == 0)
        #expect(m.isRewound)
        #expect(m.currentState[.rightHand] == h1.id)

        let r = m.apply(limb: .rightFoot, holdID: h1.id)
        #expect(r?.truncated.count == 2)
        #expect(r?.truncated.first?.limb == .rightHand)
        #expect(m.stepCount == 2)
        #expect(m.currentIndex == 1)
        #expect(m.steps.last == SequenceStep(limb: .rightFoot, holdID: h1.id))
        #expect(!m.isRewound)
    }

    @Test("回到起步再追加会替换全部")
    func rewindToStart() {
        var m = makeModel()
        m.apply(limb: .leftHand, holdID: h2.id)
        m.apply(limb: .rightHand, holdID: h2.id)
        m.rewind(toCell: 0)
        #expect(m.currentIndex == -1)
        #expect(m.currentState == m.initial)
        let r = m.apply(limb: .leftFoot, holdID: h2.id)
        #expect(r?.truncated.count == 2)
        #expect(m.stepCount == 1)
    }

    @Test("回退索引夹在范围内")
    func rewindClamp() {
        var m = makeModel()
        m.apply(limb: .leftHand, holdID: h2.id)
        m.rewind(toCell: 99)
        #expect(m.currentIndex == 0)
        m.rewind(toCell: -5)
        #expect(m.currentIndex == -1)
    }

    @Test("撤销移除最后一步并修正位置")
    func undo() {
        var m = makeModel()
        m.apply(limb: .leftHand, holdID: h2.id)
        m.apply(limb: .rightHand, holdID: h3.id)
        m.undo()
        #expect(m.stepCount == 1)
        #expect(m.currentIndex == 0)
        #expect(m.currentState[.rightHand] == h1.id)

        // 停在中间时撤销：位置不变
        m.apply(limb: .rightHand, holdID: h3.id)
        m.rewind(toCell: 0)
        m.undo()
        #expect(m.stepCount == 1)
        #expect(m.currentIndex == -1)

        m.undo()
        #expect(m.stepCount == 0)
        #expect(m.currentIndex == -1)
        #expect(!m.canUndo)
        m.undo() // 空时无事发生
        #expect(m.stepCount == 0)
    }

    @Test("完成判定：双手都到结束点，且只在刚完成时触发")
    func completion() {
        var m = makeModel()
        let r1 = m.apply(limb: .leftHand, holdID: h4.id)
        #expect(r1?.justCompleted == false)
        #expect(!m.isComplete)
        let r2 = m.apply(limb: .rightHand, holdID: h4.id)
        #expect(r2?.justCompleted == true)
        #expect(m.isComplete)
        #expect(m.isSequenceComplete)
        // 完成后再动脚：仍完成，但不再“刚完成”
        let r3 = m.apply(limb: .leftFoot, holdID: h3.id)
        #expect(r3?.justCompleted == false)
        #expect(m.isComplete)
        // 回到中间：当前格未完成，整条仍完成
        m.rewind(toCell: 1)
        #expect(!m.isComplete)
        #expect(m.isSequenceComplete)
        #expect(!m.isComplete(atCell: 1))
        #expect(m.isComplete(atCell: 2))
    }

    @Test("没有结束点永远不完成")
    func noFinish() {
        let initial = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: holds)
        var m = SequenceEditorModel(sequence: nil, initial: initial, finishHoldID: nil)
        m.apply(limb: .leftHand, holdID: h4.id)
        let r = m.apply(limb: .rightHand, holdID: h4.id)
        #expect(r?.justCompleted == false)
        #expect(!m.isComplete)
    }

    @Test("整体替换回到最后一步")
    func replace() {
        var m = makeModel()
        m.apply(limb: .leftHand, holdID: h2.id)
        m.rewind(toCell: 0)
        m.replace(with: ClimbSequence(steps: [
            SequenceStep(limb: .rightHand, holdID: h2.id),
            SequenceStep(limb: .leftHand, holdID: h3.id),
        ]))
        #expect(m.stepCount == 2)
        #expect(m.currentIndex == 1)
        m.replace(with: nil)
        #expect(m.stepCount == 0)
        #expect(m.currentIndex == -1)
    }
}

@Suite("火柴人尺度与姿态")
struct SequencePoseTests {
    @Test("火柴人高度由点的竖直跨度推导并夹在 0.22…0.38")
    func figureHeight() {
        let mid = [Hold(x: 0.5, y: 0.9), Hold(x: 0.5, y: 0.2)] // 跨度 0.7 → 0.269
        #expect(abs(SequencePoseBuilder.figureHeight(holds: mid) - 0.7 / 2.6) < 0.001)
        let tiny = [Hold(x: 0.5, y: 0.6), Hold(x: 0.6, y: 0.5)] // 跨度 0.1 → 夹到下限
        #expect(SequencePoseBuilder.figureHeight(holds: tiny) == 0.22)
        let tall = [Hold(x: 0.5, y: 1.0), Hold(x: 0.5, y: 0.0)] // 跨度 1.0 → 夹到上限
        #expect(SequencePoseBuilder.figureHeight(holds: tall) == 0.38)
        #expect(SequencePoseBuilder.figureHeight(holds: []) == 0.30)
        #expect(SequencePoseBuilder.clampFigureHeight(0.1) == 0.22)
        #expect(SequencePoseBuilder.clampFigureHeight(0.9) == 0.38)
        #expect(SequencePoseBuilder.clampFigureHeight(0.3) == 0.3)
    }

    @Test("接触点转到等比空间：x 乘 aspect，地面为 nil，拖拽覆盖优先")
    func contacts() {
        let h1 = Hold(x: 0.4, y: 0.8)
        let h2 = Hold(x: 0.6, y: 0.5)
        var state = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: [h1, h2])
        state[.leftFoot] = h2.id
        let c = SequencePoseBuilder.contacts(state: state, holds: [h1, h2], aspect: 0.75)
        #expect(c.leftHand == CGPoint(x: 0.4 * 0.75, y: 0.8))
        #expect(c.rightHand == CGPoint(x: 0.4 * 0.75, y: 0.8))
        #expect(c.leftFoot == CGPoint(x: 0.6 * 0.75, y: 0.5))
        #expect(c.rightFoot == nil)

        let dragged = SequencePoseBuilder.contacts(state: state, holds: [h1, h2], aspect: 0.75,
                                                   override: .init(limb: .rightHand, point: CGPoint(x: 0.1, y: 0.2)))
        #expect(dragged.rightHand == CGPoint(x: 0.1, y: 0.2))
        #expect(dragged.leftHand == CGPoint(x: 0.4 * 0.75, y: 0.8))
    }

    @Test("求解出的姿态手脚落在接触点上")
    func poseFollowsContacts() {
        let h1 = Hold(x: 0.4, y: 0.8)
        let h2 = Hold(x: 0.6, y: 0.5)
        var state = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: [h1, h2])
        state[.rightHand] = h2.id
        let pose = SequencePoseBuilder.pose(state: state, holds: [h1, h2], aspect: 0.75, profile: .default)
        #expect(pose.leftHand == CGPoint(x: 0.4 * 0.75, y: 0.8))
        #expect(pose.rightHand == CGPoint(x: 0.6 * 0.75, y: 0.5))
        #expect(pose.leftFoot.y <= SequencePoseBuilder.groundY(holds: [h1, h2]))
    }

    @Test("按下命中最近末端；叠在同点的两只手按手指左右侧区分；太远不命中")
    func endpointHit() {
        let h1 = Hold(x: 0.5, y: 0.8)
        let holds = [h1, Hold(x: 0.5, y: 0.3)]
        let aspect = 0.75
        let geo = SpotlightGeometry(size: CGSize(width: 300, height: 400), aspect: aspect, fill: false)
        let state = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: holds) // 双手同点
        let pose = SequencePoseBuilder.pose(state: state, holds: holds, aspect: aspect, profile: .default)
        let handView = geo.point(h1)

        let left = SequenceHitTesting.nearestEndpoint(to: CGPoint(x: handView.x - 6, y: handView.y), pose: pose, geo: geo, aspect: aspect, threshold: 28)
        #expect(left?.limb == .leftHand)
        let right = SequenceHitTesting.nearestEndpoint(to: CGPoint(x: handView.x + 6, y: handView.y), pose: pose, geo: geo, aspect: aspect, threshold: 28)
        #expect(right?.limb == .rightHand)

        let footView = geo.fromIso(pose.rightFoot, aspect: aspect)
        let foot = SequenceHitTesting.nearestEndpoint(to: CGPoint(x: footView.x + 3, y: footView.y - 3), pose: pose, geo: geo, aspect: aspect, threshold: 28)
        #expect(foot?.limb == .rightFoot)

        let miss = SequenceHitTesting.nearestEndpoint(to: CGPoint(x: 5, y: 5), pose: pose, geo: geo, aspect: aspect, threshold: 28)
        #expect(miss == nil)
    }

    @Test("手脚叠在同一点：按下偏上取手、偏下取脚")
    func handFootOnSameHold() {
        let h1 = Hold(x: 0.5, y: 0.8)
        let holds = [h1, Hold(x: 0.5, y: 0.3)]
        let aspect = 0.75
        let geo = SpotlightGeometry(size: CGSize(width: 300, height: 400), aspect: aspect, fill: false)
        var state = SequenceReplay.initialState(startHoldIDs: [h1.id], holds: holds)
        state[.rightFoot] = h1.id // 右手、右脚、左手都在 ①
        let pose = SequencePoseBuilder.pose(state: state, holds: holds, aspect: aspect, profile: .default)
        let c = geo.point(h1)

        #expect(SequenceHitTesting.nearestEndpoint(to: CGPoint(x: c.x + 5, y: c.y + 5), pose: pose, geo: geo, aspect: aspect, threshold: 28)?.limb == .rightFoot)
        #expect(SequenceHitTesting.nearestEndpoint(to: CGPoint(x: c.x + 5, y: c.y - 5), pose: pose, geo: geo, aspect: aspect, threshold: 28)?.limb == .rightHand)
        #expect(SequenceHitTesting.nearestEndpoint(to: CGPoint(x: c.x - 5, y: c.y - 5), pose: pose, geo: geo, aspect: aspect, threshold: 28)?.limb == .leftHand)
    }

    @Test("吸附阈值 = max(半径 × 2, 最小值)，取最近的点")
    func snapHit() {
        let small = Hold(x: 0.3, y: 0.5, r: 0.02)   // 半径 6pt → 阈值 28
        let big = Hold(x: 0.7, y: 0.5, r: 0.08)     // 半径 24pt → 阈值 48
        let geo = SpotlightGeometry(size: CGSize(width: 300, height: 400), aspect: 0.75, fill: false)
        let smallC = geo.point(small)
        let bigC = geo.point(big)

        #expect(SequenceHitTesting.nearestSnapHold(to: CGPoint(x: smallC.x + 20, y: smallC.y), holds: [small, big], geo: geo, minThreshold: 28)?.id == small.id)
        #expect(SequenceHitTesting.nearestSnapHold(to: CGPoint(x: smallC.x + 35, y: smallC.y), holds: [small, big], geo: geo, minThreshold: 28) == nil)
        #expect(SequenceHitTesting.nearestSnapHold(to: CGPoint(x: bigC.x - 40, y: bigC.y), holds: [small, big], geo: geo, minThreshold: 28)?.id == big.id)
        #expect(SequenceHitTesting.nearestSnapHold(to: CGPoint(x: bigC.x - 60, y: bigC.y), holds: [small, big], geo: geo, minThreshold: 28) == nil)
    }

    @Test("姿态向量往返与插值")
    func poseVector() {
        let a = SequencePoseBuilder.pose(state: ContactState(contacts: [:]), holds: [], aspect: 0.75, profile: .default)
        let va = PoseVector(a)
        #expect(va.values.count == PoseVector.count)
        #expect(va.pose == a)

        var b = a
        b.leftHand = CGPoint(x: a.leftHand.x + 0.2, y: a.leftHand.y - 0.4)
        var half = PoseVector(b) - va
        half.scale(by: 0.5)
        let mid = (va + half).pose
        #expect(abs(mid.leftHand.x - (a.leftHand.x + 0.1)) < 1e-9)
        #expect(abs(mid.leftHand.y - (a.leftHand.y - 0.2)) < 1e-9)
        #expect(mid.head == a.head)
        #expect((PoseVector.zero + va).pose == a)
    }
}
