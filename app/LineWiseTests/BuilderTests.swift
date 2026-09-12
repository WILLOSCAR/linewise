import CoreGraphics
import Foundation
import Testing
@testable import LineWise

// MARK: - 点亮几何

@Suite("点亮几何")
struct LightUpGeometryTests {
    /// 竖屏容器 390×700，照片 3:4（aspect 0.75）→ 照片矩形 390×520，上下留边 90。
    let size = CGSize(width: 390, height: 700)
    let aspect = 0.75

    private func near(_ a: CGPoint, _ b: CGPoint, tol: CGFloat = 0.001) -> Bool {
        abs(a.x - b.x) <= tol && abs(a.y - b.y) <= tol
    }

    @Test("照片矩形按 fit 居中")
    func photoRect() {
        let rect = LightUpGeometry.photoRect(size: size, aspect: aspect)
        #expect(rect == CGRect(x: 0, y: 90, width: 390, height: 520))
    }

    @Test("未缩放：触点直接映射为归一化坐标")
    func identityMapping() {
        let t = ZoomTransform.identity
        let center = LightUpGeometry.normalizedPoint(touch: CGPoint(x: 195, y: 350), size: size, aspect: aspect, transform: t)
        #expect(center != nil && near(center!, CGPoint(x: 0.5, y: 0.5)))
        let corner = LightUpGeometry.normalizedPoint(touch: CGPoint(x: 0, y: 90), size: size, aspect: aspect, transform: t)
        #expect(corner != nil && near(corner!, .zero))
        let quarter = LightUpGeometry.normalizedPoint(touch: CGPoint(x: 97.5, y: 220), size: size, aspect: aspect, transform: t)
        #expect(quarter != nil && near(quarter!, CGPoint(x: 0.25, y: 0.25)))
    }

    @Test("点在照片外（上下留边）返回 nil")
    func outsidePhoto() {
        let t = ZoomTransform.identity
        #expect(LightUpGeometry.normalizedPoint(touch: CGPoint(x: 100, y: 40), size: size, aspect: aspect, transform: t) == nil)
        #expect(LightUpGeometry.normalizedPoint(touch: CGPoint(x: 100, y: 680), size: size, aspect: aspect, transform: t) == nil)
    }

    @Test("缩放 2× 不平移：容器中心仍是照片中心，四分位点位移一半")
    func scaledMapping() {
        let t = ZoomTransform(scale: 2, offset: .zero)
        let center = LightUpGeometry.normalizedPoint(touch: CGPoint(x: 195, y: 350), size: size, aspect: aspect, transform: t)
        #expect(center != nil && near(center!, CGPoint(x: 0.5, y: 0.5)))
        // 未缩放时 (97.5, 220) 是归一化 (0.25, 0.25)；2× 后它出现在离中心两倍远的地方
        let local = CGPoint(x: 97.5, y: 220)
        let onScreen = t.containerPoint(from: local, in: size)
        #expect(near(onScreen, CGPoint(x: 0, y: 90)))
        let n = LightUpGeometry.normalizedPoint(touch: onScreen, size: size, aspect: aspect, transform: t)
        #expect(n != nil && near(n!, CGPoint(x: 0.25, y: 0.25)))
    }

    @Test("缩放 + 平移：往返换算一致")
    func roundTrip() {
        let t = ZoomTransform(scale: 3, offset: CGSize(width: -120, height: 80))
        for p in [CGPoint(x: 10, y: 10), CGPoint(x: 195, y: 350), CGPoint(x: 380, y: 690)] {
            let local = t.contentPoint(from: p, in: size)
            let back = t.containerPoint(from: local, in: size)
            #expect(near(back, p))
        }
    }

    @Test("以锚点缩放：锚点下方的内容不动")
    func anchoredZoomKeepsContentUnderFinger() {
        let anchor = CGPoint(x: 300, y: 500)
        let before = ZoomTransform.identity
        let localBefore = before.contentPoint(from: anchor, in: size)
        let after = before.scaled(to: 2.5, anchor: anchor, in: size)
        let localAfter = after.contentPoint(from: anchor, in: size)
        #expect(near(localBefore, localAfter))
        #expect(after.scale == 2.5)
    }

    @Test("缩放范围被夹在 1×…4×")
    func scaleClamped() {
        let t = ZoomTransform.identity
        #expect(t.scaled(to: 0.3, anchor: .zero, in: size).scale == 1)
        #expect(t.scaled(to: 9, anchor: .zero, in: size).scale == 4)
    }

    @Test("夹紧：1× 时不允许平移；放大后照片边缘不露底")
    func clamping() {
        let rect = LightUpGeometry.photoRect(size: size, aspect: aspect)
        let drifted = ZoomTransform(scale: 1, offset: CGSize(width: 50, height: -30)).clamped(contentRect: rect, in: size)
        #expect(drifted.offset == .zero)

        // 2× 时照片 780×1040，比容器大；往右拖太多会被拉回到左边缘贴齐
        let far = ZoomTransform(scale: 2, offset: CGSize(width: 900, height: 0)).clamped(contentRect: rect, in: size)
        let leftEdge = far.containerPoint(from: CGPoint(x: rect.minX, y: rect.minY), in: size)
        #expect(abs(leftEdge.x - 0) < 0.001)
        // 竖向：照片高 1040 > 700，顶部最多贴齐容器顶
        let top = ZoomTransform(scale: 2, offset: CGSize(width: 0, height: 900)).clamped(contentRect: rect, in: size)
        let topEdge = top.containerPoint(from: CGPoint(x: rect.minX, y: rect.minY), in: size)
        #expect(abs(topEdge.y - 0) < 0.001)
        // 反方向：底边贴齐容器底
        let bottom = ZoomTransform(scale: 2, offset: CGSize(width: 0, height: -900)).clamped(contentRect: rect, in: size)
        let bottomEdge = bottom.containerPoint(from: CGPoint(x: rect.minX, y: rect.maxY), in: size)
        #expect(abs(bottomEdge.y - size.height) < 0.001)
    }

    @Test("点一下：空白处新增、已有点熄灭、照片外忽略；缩放后同样成立")
    func tapOutcome() {
        let hold = Hold(x: 0.5, y: 0.5)
        let t1 = ZoomTransform.identity
        #expect(LightUpGeometry.tapOutcome(touch: CGPoint(x: 195, y: 350), holds: [hold], size: size, aspect: aspect, transform: t1) == .remove(hold.id))
        if case .add(let x, let y) = LightUpGeometry.tapOutcome(touch: CGPoint(x: 39, y: 142), holds: [hold], size: size, aspect: aspect, transform: t1) {
            #expect(abs(x - 0.1) < 0.001 && abs(y - 0.1) < 0.001)
        } else {
            Issue.record("应当新增")
        }
        #expect(LightUpGeometry.tapOutcome(touch: CGPoint(x: 39, y: 20), holds: [hold], size: size, aspect: aspect, transform: t1) == .ignore)

        // 放大 2× 并把照片左上角拖到容器左上角：屏幕 (39, 20) 对应归一化 (0.05, 0.02)
        let rect = LightUpGeometry.photoRect(size: size, aspect: aspect)
        let t2 = ZoomTransform(scale: 2, offset: CGSize(width: 900, height: 900)).clamped(contentRect: rect, in: size)
        if case .add(let x, let y) = LightUpGeometry.tapOutcome(touch: CGPoint(x: 39, y: 20.8), holds: [], size: size, aspect: aspect, transform: t2) {
            #expect(abs(x - 0.05) < 0.001 && abs(y - 0.02) < 0.001)
        } else {
            Issue.record("放大后应当新增")
        }
        // 放大后原来的点跑到了屏幕别处：按新位置能点灭它
        let onScreen = t2.containerPoint(from: CGPoint(x: 195, y: 350), in: size)
        #expect(LightUpGeometry.tapOutcome(touch: onScreen, holds: [hold], size: size, aspect: aspect, transform: t2) == .remove(hold.id))
    }

    @Test("命中判定：容差按缩放折算")
    func hitTesting() {
        let hold = Hold(x: 0.5, y: 0.5, r: 0.04) // 半径 0.04 × 390 = 15.6pt（1×）
        let t1 = ZoomTransform.identity
        #expect(LightUpGeometry.hold(at: CGPoint(x: 195 + 20, y: 350), holds: [hold], size: size, aspect: aspect, transform: t1)?.id == hold.id)
        #expect(LightUpGeometry.hold(at: CGPoint(x: 195 + 40, y: 350), holds: [hold], size: size, aspect: aspect, transform: t1) == nil)
        // 3× 时屏幕上圆半径 46.8pt；离圆心 55pt（屏幕）仍在 14pt 容差内
        let t3 = ZoomTransform(scale: 3, offset: .zero)
        #expect(LightUpGeometry.hold(at: CGPoint(x: 195 + 55, y: 350), holds: [hold], size: size, aspect: aspect, transform: t3)?.id == hold.id)
        #expect(LightUpGeometry.hold(at: CGPoint(x: 195 + 70, y: 350), holds: [hold], size: size, aspect: aspect, transform: t3) == nil)
    }
}

// MARK: - 触摸分类：轻点 / 长按 / 拖动 / 捏合

@Suite("触摸分类")
struct TouchClassifierTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }
    let p = CGPoint(x: 100, y: 200)

    @Test("落下即开始长按计时；很快抬起且没动 → 轻点")
    func tap() {
        var c = TouchClassifier()
        #expect(c.handle(.changed(location: p, start: p, time: at(0)), canPan: false) == [.startLongPressTimer(at: p)])
        let end = CGPoint(x: 103, y: 198)
        #expect(c.handle(.ended(location: end, time: at(0.12)), canPan: false) == [.cancelLongPressTimer, .tap(end)])
        #expect(c.track == nil)
    }

    @Test("按得太久不算轻点；长按到点后抬起也不算")
    func longPress() {
        var c = TouchClassifier()
        _ = c.handle(.changed(location: p, start: p, time: at(0)), canPan: false)
        let fired = c.longPressTimerFired()
        #expect(fired)
        #expect(c.handle(.ended(location: p, time: at(0.6)), canPan: false) == [.cancelLongPressTimer])

        var slow = TouchClassifier()
        _ = slow.handle(.changed(location: p, start: p, time: at(0)), canPan: false)
        #expect(slow.handle(.ended(location: p, time: at(0.8)), canPan: false) == [.cancelLongPressTimer])
    }

    @Test("移动超过容差：取消长按；放大后才平移，并按增量给出")
    func dragPans() {
        var c = TouchClassifier()
        _ = c.handle(.changed(location: p, start: p, time: at(0)), canPan: true)
        let p1 = CGPoint(x: 120, y: 200)
        #expect(c.handle(.changed(location: p1, start: p, time: at(0.05)), canPan: true) == [.cancelLongPressTimer, .pan(CGSize(width: 20, height: 0))])
        let p2 = CGPoint(x: 125, y: 210)
        #expect(c.handle(.changed(location: p2, start: p, time: at(0.1)), canPan: true) == [.pan(CGSize(width: 5, height: 10))])
        #expect(c.handle(.ended(location: p2, time: at(0.15)), canPan: true) == [.cancelLongPressTimer])
        let notFired = c.longPressTimerFired()
        #expect(!notFired)
    }

    @Test("1× 时移动不平移，也不算轻点")
    func dragWithoutZoom() {
        var c = TouchClassifier()
        _ = c.handle(.changed(location: p, start: p, time: at(0)), canPan: false)
        #expect(c.handle(.changed(location: CGPoint(x: 140, y: 200), start: p, time: at(0.05)), canPan: false) == [.cancelLongPressTimer])
        #expect(c.handle(.ended(location: CGPoint(x: 140, y: 200), time: at(0.1)), canPan: false) == [.cancelLongPressTimer])
    }

    @Test("长按成立后再拖动不平移")
    func noPanAfterLongPress() {
        var c = TouchClassifier()
        _ = c.handle(.changed(location: p, start: p, time: at(0)), canPan: true)
        let fired = c.longPressTimerFired()
        #expect(fired)
        #expect(c.handle(.changed(location: CGPoint(x: 130, y: 200), start: p, time: at(0.5)), canPan: true) == [.cancelLongPressTimer])
        #expect(c.handle(.changed(location: CGPoint(x: 150, y: 200), start: p, time: at(0.6)), canPan: true) == [])
    }

    @Test("捏合期间：取消长按、不平移、抬起不算轻点；捏合结束后平移重新起算")
    func pinch() {
        var c = TouchClassifier()
        _ = c.handle(.changed(location: p, start: p, time: at(0)), canPan: true)
        #expect(c.handle(.pinchChanged, canPan: true) == [.cancelLongPressTimer])
        let notFired = c.longPressTimerFired()
        #expect(!notFired)
        #expect(c.handle(.changed(location: CGPoint(x: 160, y: 200), start: p, time: at(0.1)), canPan: true) == [.cancelLongPressTimer])
        #expect(c.handle(.changed(location: CGPoint(x: 170, y: 200), start: p, time: at(0.15)), canPan: true) == [])
        #expect(c.handle(.pinchEnded(time: at(0.2)), canPan: true) == [])
        // 第一帧只重新起算，不平移
        #expect(c.handle(.changed(location: CGPoint(x: 180, y: 200), start: p, time: at(0.25)), canPan: true) == [])
        #expect(c.handle(.changed(location: CGPoint(x: 190, y: 205), start: p, time: at(0.3)), canPan: true) == [.pan(CGSize(width: 10, height: 5))])
        #expect(c.handle(.ended(location: CGPoint(x: 190, y: 205), time: at(0.35)), canPan: true) == [.cancelLongPressTimer])
    }

    @Test("捏合刚结束就落下的手指：不计时、不算轻点；过了冷却期恢复")
    func pinchCooldown() {
        var c = TouchClassifier()
        _ = c.handle(.pinchChanged, canPan: true)
        _ = c.handle(.pinchEnded(time: at(0)), canPan: true)
        #expect(c.handle(.changed(location: p, start: p, time: at(0.1)), canPan: true) == [])
        #expect(c.handle(.ended(location: p, time: at(0.15)), canPan: true) == [.cancelLongPressTimer])
        #expect(c.handle(.changed(location: p, start: p, time: at(0.5)), canPan: true) == [.startLongPressTimer(at: p)])
        #expect(c.handle(.ended(location: p, time: at(0.6)), canPan: true) == [.cancelLongPressTimer, .tap(p)])
    }
}

// MARK: - 起步 / 结束

@Suite("点亮草稿：起步与结束")
struct LightUpDraftTests {
    @Test("增删点时自动重算：最低为起步、最高为结束")
    func autoDefaults() {
        var d = LightUpDraft()
        let a = d.add(x: 0.5, y: 0.8)
        #expect(d.startHoldIDs == [a.id])
        #expect(d.finishHoldID == nil) // 只有一个点没有结束
        let b = d.add(x: 0.5, y: 0.3)
        #expect(d.startHoldIDs == [a.id])
        #expect(d.finishHoldID == b.id)
        let c = d.add(x: 0.5, y: 0.95) // 更低 → 变成起步
        #expect(d.startHoldIDs == [c.id])
        #expect(d.finishHoldID == b.id)
        d.remove(id: b.id) // 最高的删了 → 结束换成 a
        #expect(d.finishHoldID == a.id)
        #expect(d.startHoldIDs == [c.id])
    }

    @Test("手动设过起步后，增删点不再自动改起步；结束仍自动")
    func manualStartSticks() {
        var d = LightUpDraft()
        let low = d.add(x: 0.5, y: 0.9)
        let mid = d.add(x: 0.5, y: 0.5)
        let high = d.add(x: 0.5, y: 0.1)
        d.toggleStart(id: mid.id)
        #expect(d.startIsManual)
        #expect(d.startHoldIDs == [mid.id])
        // 再加一个更低的点：起步不变
        let lower = d.add(x: 0.5, y: 0.97)
        #expect(d.startHoldIDs == [mid.id])
        #expect(d.finishHoldID == high.id)
        // 删掉一个无关点：起步不变
        d.remove(id: lower.id)
        d.remove(id: low.id)
        #expect(d.startHoldIDs == [mid.id])
        // 结束仍跟随：加一个更高的点
        let higher = d.add(x: 0.5, y: 0.02)
        #expect(d.finishHoldID == higher.id)
    }

    @Test("删掉手动起步点后回到自动")
    func removingManualStartRevertsToAuto() {
        var d = LightUpDraft()
        let low = d.add(x: 0.5, y: 0.9)
        let mid = d.add(x: 0.5, y: 0.5)
        _ = d.add(x: 0.5, y: 0.1)
        d.toggleStart(id: mid.id)
        d.remove(id: mid.id)
        #expect(!d.startIsManual)
        #expect(d.startHoldIDs == [low.id])
    }

    @Test("起步最多 2 个，第三个替换最早的")
    func twoStartsMax() {
        var d = LightUpDraft()
        let a = d.add(x: 0.2, y: 0.9)
        let b = d.add(x: 0.6, y: 0.9)
        let c = d.add(x: 0.5, y: 0.5)
        _ = d.add(x: 0.5, y: 0.1)
        d.toggleStart(id: a.id)  // 已经是自动起步，手动 toggle → 取消
        #expect(d.startHoldIDs.isEmpty)
        d.toggleStart(id: a.id)
        d.toggleStart(id: b.id)
        #expect(Set(d.startHoldIDs) == Set([a.id, b.id]))
        d.toggleStart(id: c.id)
        #expect(d.startHoldIDs == [b.id, c.id])
    }

    @Test("手动设结束后不再自动改；把起步点设成结束会把它从起步里拿掉")
    func manualFinish() {
        var d = LightUpDraft()
        let low = d.add(x: 0.5, y: 0.9)
        let mid = d.add(x: 0.5, y: 0.5)
        let high = d.add(x: 0.5, y: 0.1)
        d.toggleFinish(id: mid.id)
        #expect(d.finishIsManual)
        #expect(d.finishHoldID == mid.id)
        _ = d.add(x: 0.5, y: 0.02) // 更高的点，结束不动
        #expect(d.finishHoldID == mid.id)
        // 把自动起步 low 设成结束：起步自动挪到下一个最低点
        d.toggleFinish(id: low.id)
        #expect(d.finishHoldID == low.id)
        #expect(!d.startHoldIDs.contains(low.id))
        #expect(d.startHoldIDs.count == 1)
        #expect(d.startHoldIDs.first != high.id || d.count == 2)
        // 取消结束 → 空着，不自动回填
        d.toggleFinish(id: low.id)
        #expect(d.finishHoldID == nil)
        #expect(d.finishIsManual)
    }

    @Test("同一个点不能同时是起步和结束")
    func startAndFinishExclusive() {
        var d = LightUpDraft()
        _ = d.add(x: 0.5, y: 0.9)
        let high = d.add(x: 0.5, y: 0.1)
        #expect(d.finishHoldID == high.id)
        d.toggleStart(id: high.id)
        #expect(d.startHoldIDs == [high.id])
        #expect(d.finishHoldID != high.id)
    }

    @Test("半径只能在允许范围内")
    func radius() {
        var d = LightUpDraft()
        let h = d.add(x: 0.5, y: 0.5)
        d.setRadius(id: h.id, r: 0.06)
        #expect(d.hold(id: h.id)?.r == 0.06)
        d.setRadius(id: h.id, r: 0.5)
        #expect(d.hold(id: h.id)?.r == Hold.maxRadius)
    }
}

// MARK: - 建线时长

@Suite("建线时长")
struct BuildMetricsTests {
    @Test("追加到 buildDurations 数组")
    func appends() {
        let defaults = UserDefaults(suiteName: "BuilderTests.\(UUID().uuidString)")!
        BuildMetrics.record(seconds: 12.34, defaults: defaults)
        BuildMetrics.record(seconds: 7, defaults: defaults)
        BuildMetrics.record(seconds: -1, defaults: defaults) // 非法值忽略
        let list = defaults.array(forKey: BuildMetrics.key) as? [Double]
        #expect(list == [12.3, 7])
    }
}

// MARK: - 揭示动画曲线

@Suite("揭示动画")
struct RevealCurveTests {
    @Test("easeInOut 端点与中点")
    func curve() {
        #expect(RevealView.easeInOut(0) == 0)
        #expect(RevealView.easeInOut(1) == 1)
        #expect(abs(RevealView.easeInOut(0.5) - 0.5) < 0.0001)
        #expect(RevealView.easeInOut(0.25) < 0.25)
        #expect(RevealView.easeInOut(0.75) > 0.75)
    }
}
