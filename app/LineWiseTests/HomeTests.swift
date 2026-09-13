import CoreGraphics
import Foundation
import Testing
@testable import LineWise

@Suite("首页文字")
struct HomeCardTextTests {
    @Test("第一行：墙区 · 难度；都没有时用线名")
    func headline() {
        #expect(HomeCardText.headline(area: "直壁", grade: "V3", fallbackName: "x") == "直壁 · V3")
        #expect(HomeCardText.headline(area: nil, grade: "V3", fallbackName: "x") == "V3")
        #expect(HomeCardText.headline(area: "", grade: nil, fallbackName: "斜板墙 · 蓝") == "斜板墙 · 蓝")
    }

    @Test("第二行：第 N 次来 · 上次掉在；没来过为 nil")
    func visitLine() {
        #expect(HomeCardText.visitLine(visitCount: 0, lastFall: "上次掉在 ⑤") == nil)
        #expect(HomeCardText.visitLine(visitCount: 3, lastFall: "上次掉在 ⑤ · 身体") == "第 3 次来 · 上次掉在 ⑤ · 身体")
        #expect(HomeCardText.visitLine(visitCount: 1, lastFall: nil) == "第 1 次来")
    }

    @Test("页码只在多于一张时显示")
    func pageLabel() {
        #expect(HomeCardText.pageLabel(index: 0, count: 1) == nil)
        #expect(HomeCardText.pageLabel(index: 2, count: 6) == "3 / 6")
        #expect(HomeCardText.pageLabel(index: 6, count: 6) == nil)
    }
}

@MainActor
@Suite("首页排序缓存")
struct HomeOrderingTests {
    let f: StoreFixture
    init() throws { f = try StoreFixture() }

    @Test("有记录的按记录日期优先；新线按创建时间排在其后")
    func newLinesDoNotDisplaceRevisitedLines() throws {
        let (_, _, recent) = try f.makeLine(name: "最近爬过")
        let (_, _, older) = try f.makeLine(name: "更早爬过")
        let (_, _, fresh) = try f.makeLine(name: "新线")
        let (_, _, empty) = try f.makeLine(name: "旧空线")
        fresh.createdAt = f.daysAgo(0)
        empty.createdAt = f.daysAgo(4)
        _ = f.store.newSession(for: recent, date: f.daysAgo(1))
        _ = f.store.newSession(for: older, date: f.daysAgo(3))
        let ordered = HomeLineOrdering.ordered([fresh, older, empty, recent], filter: .all, gymID: nil)
        #expect(ordered.map(\.name) == ["最近爬过", "更早爬过", "新线", "旧空线"])
    }

    @Test("最近动过的在前；筛选 已上 / 进行中；指纹随记录变化")
    func orderingAndSignature() throws {
        let (_, _, a) = try f.makeLine(name: "A")
        let (_, _, b) = try f.makeLine(name: "B")
        let today = Calendar.current.startOfDay(for: .now)
        let s = f.store.newSession(for: a, date: f.daysAgo(1))
        s.attemptCount = 2
        f.store.commitSession(s, line: a, fallLabel: nil)
        let all = try f.fetchLines()
        let sig1 = HomeLineOrdering.signature(all, filter: .all, gymID: nil, today: today)
        #expect(HomeLineOrdering.ordered(all, filter: .all, gymID: nil, today: today).map(\.name) == ["A", "B"])
        #expect(HomeLineOrdering.ordered(all, filter: .sent, gymID: nil, today: today).isEmpty)
        b.status = .sent
        #expect(HomeLineOrdering.ordered(all, filter: .sent, gymID: nil, today: today).map(\.name) == ["B"])
        #expect(HomeLineOrdering.ordered(all, filter: .projecting, gymID: nil, today: today).map(\.name) == ["A"])
        let sig2 = HomeLineOrdering.signature(all, filter: .all, gymID: nil, today: today)
        #expect(sig1 != sig2)
        #expect(HomeLineOrdering.signature(all, filter: .all, gymID: nil, today: today) == sig2)
    }
}

@Suite("点亮几何 · 拖点")
struct LightUpDragTests {
    let size = CGSize(width: 390, height: 700)
    let aspect = 0.75

    @Test("拖动只重算自动端点，保留用户手动指定的结束点")
    func movingPreservesManualFinish() {
        var draft = LightUpDraft()
        let low = draft.add(x: 0.5, y: 0.9)
        let middle = draft.add(x: 0.5, y: 0.5)
        let top = draft.add(x: 0.5, y: 0.1)
        draft.toggleFinish(id: middle.id)
        draft.move(id: middle.id, to: 0.5, y: 0.98)
        #expect(draft.finishHoldID == middle.id)
        #expect(draft.startHoldIDs == [low.id])
        draft.move(id: low.id, to: 0.5, y: 0.01)
        #expect(draft.startHoldIDs == [top.id])
        #expect(draft.finishHoldID == middle.id)
    }

    @Test("命中半径至少 22pt，且取最近的点")
    func minHitRadius() {
        let tiny = Hold(x: 0.5, y: 0.5, r: 0.02) // 7.8pt
        let t = ZoomTransform.identity
        #expect(LightUpGeometry.hold(at: CGPoint(x: 195 + 21, y: 350), holds: [tiny], size: size, aspect: aspect, transform: t)?.id == tiny.id)
        #expect(LightUpGeometry.hold(at: CGPoint(x: 195 + 30, y: 350), holds: [tiny], size: size, aspect: aspect, transform: t) == nil)
        let near = Hold(x: 0.55, y: 0.5, r: 0.02) // 19.5pt 右边
        #expect(LightUpGeometry.hold(at: CGPoint(x: 195 + 14, y: 350), holds: [tiny, near], size: size, aspect: aspect, transform: t)?.id == near.id)
    }

    @Test("落在点上再拖动：越过容差补整段位移，之后按增量；抬起给 endMoveHold，不算轻点")
    func dragMovesHold() {
        var c = TouchClassifier()
        let id = UUID()
        let p = CGPoint(x: 100, y: 200)
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        #expect(c.handle(.changed(location: p, start: p, time: t0), intent: .moveHold(id)) == [.startLongPressTimer(at: p)])
        #expect(c.handle(.changed(location: CGPoint(x: 115, y: 200), start: p, time: t0 + 0.05), intent: .moveHold(id)) == [.cancelLongPressTimer, .moveHold(id, by: CGSize(width: 15, height: 0))])
        #expect(c.handle(.changed(location: CGPoint(x: 120, y: 210), start: p, time: t0 + 0.1), intent: .moveHold(id)) == [.moveHold(id, by: CGSize(width: 5, height: 10))])
        #expect(c.handle(.ended(location: CGPoint(x: 120, y: 210), time: t0 + 0.15), intent: .moveHold(id)) == [.cancelLongPressTimer, .endMoveHold(id)])
    }

    @Test("屏幕增量 → 归一化增量按缩放折算；移动后编号与起步重算")
    func nudge() {
        let d = LightUpGeometry.normalizedDelta(CGSize(width: 39, height: 52), size: size, aspect: aspect, transform: ZoomTransform(scale: 2, offset: .zero))
        #expect(abs(d.width - 0.05) < 0.001 && abs(d.height - 0.05) < 0.001)
        var draft = LightUpDraft()
        let low = draft.add(x: 0.5, y: 0.9)
        let high = draft.add(x: 0.5, y: 0.2)
        #expect(draft.startHoldIDs == [low.id])
        draft.move(id: low.id, to: 0.5, y: 0.1)
        #expect(draft.startHoldIDs == [high.id])
        #expect(draft.finishHoldID == low.id)
        draft.grow(id: low.id)
        #expect(abs((draft.hold(id: low.id)?.r ?? 0) - Hold.defaultRadius * 1.25) < 0.0001)
    }
}
