import CoreGraphics
import Foundation

/// 点亮屏的缩放/平移变换。内容视图先以中心为锚点 `scaleEffect(scale)`，再 `offset(offset)`。
/// 所有换算都是纯函数，方便测试。
struct ZoomTransform: Equatable {
    var scale: CGFloat = 1
    /// 缩放之后的平移量（容器坐标点）。
    var offset: CGSize = .zero

    static let minScale: CGFloat = 1
    static let maxScale: CGFloat = 4
    static let identity = ZoomTransform()

    var isZoomed: Bool { scale > 1.001 }

    /// 容器坐标 → 内容局部坐标（未变换前）。
    func contentPoint(from p: CGPoint, in size: CGSize) -> CGPoint {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(
            x: (p.x - c.x - offset.width) / scale + c.x,
            y: (p.y - c.y - offset.height) / scale + c.y
        )
    }

    /// 内容局部坐标 → 容器坐标。
    func containerPoint(from local: CGPoint, in size: CGSize) -> CGPoint {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(
            x: c.x + (local.x - c.x) * scale + offset.width,
            y: c.y + (local.y - c.y) * scale + offset.height
        )
    }

    /// 以容器上的某一点为锚，把缩放改为 `newScale`，锚点下方的内容保持不动。
    func scaled(to newScale: CGFloat, anchor: CGPoint, in size: CGSize) -> ZoomTransform {
        let s1 = min(max(newScale, Self.minScale), Self.maxScale)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let k = s1 / scale
        var next = self
        next.scale = s1
        next.offset = CGSize(
            width: anchor.x - c.x - (anchor.x - c.x - offset.width) * k,
            height: anchor.y - c.y - (anchor.y - c.y - offset.height) * k
        )
        return next
    }

    func translated(by delta: CGSize) -> ZoomTransform {
        var next = self
        next.offset.width += delta.width
        next.offset.height += delta.height
        return next
    }

    /// 让照片矩形（内容局部坐标）不离开容器：比容器小的方向居中，比容器大的方向边缘不露底。
    func clamped(contentRect: CGRect, in size: CGSize) -> ZoomTransform {
        var next = self
        next.scale = min(max(scale, Self.minScale), Self.maxScale)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let scaledW = contentRect.width * next.scale
        let scaledH = contentRect.height * next.scale
        // 不带 offset 时照片在容器里的位置
        let baseMinX = c.x + (contentRect.minX - c.x) * next.scale
        let baseMinY = c.y + (contentRect.minY - c.y) * next.scale

        if scaledW <= size.width {
            next.offset.width = (size.width - scaledW) / 2 - baseMinX
        } else {
            let minOffset = size.width - (baseMinX + scaledW) // 右边缘贴齐
            let maxOffset = -baseMinX                          // 左边缘贴齐
            next.offset.width = min(max(next.offset.width, minOffset), maxOffset)
        }
        if scaledH <= size.height {
            next.offset.height = (size.height - scaledH) / 2 - baseMinY
        } else {
            let minOffset = size.height - (baseMinY + scaledH)
            let maxOffset = -baseMinY
            next.offset.height = min(max(next.offset.height, minOffset), maxOffset)
        }
        return next
    }
}

/// 点亮屏的几何换算：触点 → 归一化坐标 / 命中的点。
enum LightUpGeometry {
    /// 照片在容器里的矩形（内容局部坐标，`fill: false`）。
    static func photoRect(size: CGSize, aspect: Double) -> CGRect {
        SpotlightGeometry(size: size, aspect: aspect, fill: false).rect
    }

    /// 容器上的触点 → 照片归一化坐标；落在照片外返回 nil。
    static func normalizedPoint(touch: CGPoint, size: CGSize, aspect: Double, transform: ZoomTransform) -> CGPoint? {
        let local = transform.contentPoint(from: touch, in: size)
        return SpotlightGeometry(size: size, aspect: aspect, fill: false).normalized(local)
    }

    /// 屏幕上的最小命中半径（点）：再小的圆、再怎么缩放，指头落在这个范围内都算点到。
    static let minHitRadius: CGFloat = 22

    /// 容器上的触点命中了哪个点：取屏幕距离最近的那个，所以挨得很近的点也能分开点到。
    /// `slop` 是屏幕上的容差（点）；命中范围 = max(minHitRadius, 屏幕半径 + slop)。
    static func hold(at touch: CGPoint, holds: [Hold], size: CGSize, aspect: Double, transform: ZoomTransform, slop: CGFloat = 14) -> Hold? {
        let local = transform.contentPoint(from: touch, in: size)
        let geo = SpotlightGeometry(size: size, aspect: aspect, fill: false)
        let s = max(transform.scale, 0.01)
        var best: (Hold, CGFloat)?
        for h in holds {
            let c = geo.point(h)
            let onScreen = hypot(c.x - local.x, c.y - local.y) * s
            let insideReach = onScreen <= minHitRadius || geo.distance(to: h, from: local) * s <= slop
            if insideReach, best == nil || onScreen < best!.1 { best = (h, onScreen) }
        }
        return best?.0
    }

    /// 屏幕上的位移 → 归一化坐标位移（拖点用）。
    static func normalizedDelta(_ delta: CGSize, size: CGSize, aspect: Double, transform: ZoomTransform) -> CGSize {
        let rect = photoRect(size: size, aspect: aspect)
        let s = max(transform.scale, 0.01)
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGSize(width: delta.width / s / rect.width, height: delta.height / s / rect.height)
    }

    /// 照片此刻在屏幕上的尺寸（fit 矩形 × 缩放）。放大镜按它算倍率。
    static func photoOnScreen(size: CGSize, aspect: Double, transform: ZoomTransform) -> CGSize {
        let rect = photoRect(size: size, aspect: aspect)
        return CGSize(width: rect.width * transform.scale, height: rect.height * transform.scale)
    }

    /// 点一下的结果：点在已有点上 → 熄灭它；点在照片空白处 → 新增；点在照片外 → 无事。
    enum TapOutcome: Equatable {
        case add(x: Double, y: Double)
        case remove(UUID)
        case ignore
    }

    static func tapOutcome(touch: CGPoint, holds: [Hold], size: CGSize, aspect: Double, transform: ZoomTransform) -> TapOutcome {
        if let hit = hold(at: touch, holds: holds, size: size, aspect: aspect, transform: transform) {
            return .remove(hit.id)
        }
        if let n = normalizedPoint(touch: touch, size: size, aspect: aspect, transform: transform) {
            return .add(x: n.x, y: n.y)
        }
        return .ignore
    }
}

/// 单指触摸的分类器：把一串 DragGesture(minimumDistance: 0) 事件判定为 轻点 / 长按 / 拖动（平移或拖点），
/// 并和双指缩放协调（捏合期间和刚结束时不算轻点）。纯状态机，方便测试。
struct TouchClassifier: Equatable {
    /// 这根手指要是动起来会做什么：落下那一刻由调用方根据落点决定（在点上 → 拖点；放大了 → 平移；否则啥也不做）。
    enum DragIntent: Equatable {
        case none
        case pan
        case moveHold(UUID)
    }

    struct Track: Equatable {
        var start: CGPoint
        var startedAt: Date
        /// 上一次位置；双指结束后置 nil，平移重新起算
        var last: CGPoint?
        var moved = false
        var pinched = false
        var longPressFired = false
        var intent: DragIntent = .none
        /// 已经发出过拖点动作（抬起时要补一个 endMoveHold）
        var movingHold = false
    }

    enum Event: Equatable {
        case changed(location: CGPoint, start: CGPoint, time: Date)
        case ended(location: CGPoint, time: Date)
        case pinchChanged
        case pinchEnded(time: Date)
    }

    enum Action: Equatable {
        case startLongPressTimer(at: CGPoint)
        case cancelLongPressTimer
        case pan(CGSize)
        /// 拖点：屏幕坐标增量。第一次越过容差时把从落点到现在的整段位移一次补上。
        case moveHold(UUID, by: CGSize)
        case endMoveHold(UUID)
        case tap(CGPoint)
    }

    var tapSlop: CGFloat = 10
    var tapMaxDuration: TimeInterval = 0.5
    /// 双指刚结束后这段时间里落下的手指不算轻点
    var pinchCooldown: TimeInterval = 0.25

    private(set) var track: Track?
    private(set) var isPinching = false
    private(set) var pinchEndedAt: Date?

    /// `canPan`：当前是否放大了（1× 时不平移）。等价于 `intent: canPan ? .pan : .none`。
    mutating func handle(_ event: Event, canPan: Bool) -> [Action] {
        handle(event, intent: canPan ? .pan : .none)
    }

    /// `intent` 只在手指落下的第一个事件里生效，之后沿用。
    mutating func handle(_ event: Event, intent: DragIntent) -> [Action] {
        switch event {
        case .changed(let location, let start, let time):
            guard var t = track else {
                var fresh = Track(start: start, startedAt: time, last: location, intent: intent)
                let justPinched = pinchEndedAt.map { time.timeIntervalSince($0) < pinchCooldown } ?? false
                if isPinching || justPinched {
                    fresh.pinched = true
                    fresh.intent = .none
                    track = fresh
                    return []
                }
                track = fresh
                return [.startLongPressTimer(at: start)]
            }
            var actions: [Action] = []
            let dist = hypot(location.x - t.start.x, location.y - t.start.y)
            var justStartedMoving = false
            if dist > tapSlop, !t.moved {
                t.moved = true
                justStartedMoving = true
                actions.append(.cancelLongPressTimer)
            }
            if isPinching {
                t.pinched = true
            } else if t.moved, !t.longPressFired {
                switch t.intent {
                case .pan:
                    if let last = t.last {
                        actions.append(.pan(CGSize(width: location.x - last.x, height: location.y - last.y)))
                    }
                case .moveHold(let id):
                    // 越过容差的那一帧把整段位移补上，之后按增量走，点不会“跳一下再跟上”
                    let from = justStartedMoving ? t.start : (t.last ?? location)
                    actions.append(.moveHold(id, by: CGSize(width: location.x - from.x, height: location.y - from.y)))
                    t.movingHold = true
                case .none:
                    break
                }
            }
            t.last = location
            track = t
            return actions

        case .ended(let location, let time):
            var actions: [Action] = [.cancelLongPressTimer]
            guard let t = track else { return actions }
            track = nil
            if t.movingHold, case .moveHold(let id) = t.intent {
                actions.append(.endMoveHold(id))
                return actions
            }
            let dist = hypot(location.x - t.start.x, location.y - t.start.y)
            let duration = time.timeIntervalSince(t.startedAt)
            if !t.pinched, !t.longPressFired, !t.moved, dist <= tapSlop, duration < tapMaxDuration {
                actions.append(.tap(location))
            }
            return actions

        case .pinchChanged:
            isPinching = true
            track?.pinched = true
            // 第二根手指下来：正在拖的点就停在原地，不再跟着单指走
            if case .moveHold = track?.intent { track?.intent = .none }
            return [.cancelLongPressTimer]

        case .pinchEnded(let time):
            isPinching = false
            pinchEndedAt = time
            track?.last = nil
            return []
        }
    }

    /// 长按计时器到点：手指还按着、没动、没捏合 → 记为长按并返回 true。
    mutating func longPressTimerFired() -> Bool {
        guard var t = track, !t.moved, !t.pinched, !t.longPressFired else { return false }
        t.longPressFired = true
        track = t
        return true
    }
}

/// 点亮屏的草稿：点集合 + 起步/结束。
/// 用户没有手动改过之前，起步/结束跟随点的增删自动重算；手动改过之后就不再自动动它。
struct LightUpDraft: Equatable {
    private(set) var holds: [Hold] = []
    private(set) var startHoldIDs: [UUID] = []
    private(set) var finishHoldID: UUID?
    private(set) var startIsManual = false
    private(set) var finishIsManual = false

    static let radiusOptions: [(title: String, value: Double)] = [
        ("小", 0.028), ("中", 0.04), ("大", 0.06),
    ]

    init(holds: [Hold] = []) {
        self.holds = holds
        recomputeDefaults()
    }

    var count: Int { holds.count }
    var isEmpty: Bool { holds.isEmpty }

    func hold(id: UUID) -> Hold? { holds.first { $0.id == id } }
    func isStart(_ id: UUID) -> Bool { startHoldIDs.contains(id) }
    func isFinish(_ id: UUID) -> Bool { finishHoldID == id }

    // MARK: 增删

    @discardableResult
    mutating func add(x: Double, y: Double, r: Double = Hold.defaultRadius) -> Hold {
        let hold = Hold(x: x, y: y, r: r)
        holds.append(hold)
        recomputeDefaults()
        return hold
    }

    mutating func remove(id: UUID) {
        holds.removeAll { $0.id == id }
        if startHoldIDs.contains(id) {
            startHoldIDs.removeAll { $0 == id }
            if startHoldIDs.isEmpty { startIsManual = false }
        }
        if finishHoldID == id {
            finishHoldID = nil
            finishIsManual = false
        }
        recomputeDefaults()
    }

    mutating func setRadius(id: UUID, r: Double) {
        guard let i = holds.firstIndex(where: { $0.id == id }) else { return }
        holds[i].r = min(max(r, Hold.minRadius), Hold.maxRadius)
        holds[i].clearContour()
        holds[i].prefersCircle = true
    }

    /// 调大 / 调小一档（×1.25 / ÷1.25），夹在允许范围内。
    static let radiusStep: Double = 1.25

    mutating func grow(id: UUID) {
        guard let h = hold(id: id) else { return }
        setRadius(id: id, r: h.r * Self.radiusStep)
    }

    mutating func shrink(id: UUID) {
        guard let h = hold(id: id) else { return }
        setRadius(id: id, r: h.r / Self.radiusStep)
    }

    func canGrow(id: UUID) -> Bool { (hold(id: id)?.r ?? Hold.maxRadius) < Hold.maxRadius - 0.0001 }
    func canShrink(id: UUID) -> Bool { (hold(id: id)?.r ?? Hold.minRadius) > Hold.minRadius + 0.0001 }

    // MARK: 拖动

    /// 把某个点挪到新的归一化位置（夹在 0…1）。位置变了编号会变，起步 / 结束的自动值随之重算。
    mutating func move(id: UUID, to x: Double, y: Double) {
        guard let i = holds.firstIndex(where: { $0.id == id }) else { return }
        holds[i].x = min(max(x, 0), 1)
        holds[i].y = min(max(y, 0), 1)
        holds[i].clearContour()
        recomputeDefaults()
    }

    /// An asynchronous suggestion only applies to the unchanged tap it was requested for.
    @discardableResult
    mutating func applyContour(_ contour: HoldContour, anchor: NormalizedPoint?, version: String, to expected: Hold) -> Bool {
        guard let i = holds.firstIndex(where: { $0.id == expected.id }), holds[i] == expected,
              !holds[i].prefersCircle else { return false }
        holds[i].polygon = contour.points
        holds[i].anchor = anchor
        holds[i].segmentationVersion = version
        return true
    }

    mutating func preferCircle(id: UUID, _ preferred: Bool) {
        guard let i = holds.firstIndex(where: { $0.id == id }) else { return }
        holds[i].clearContour()
        holds[i].prefersCircle = preferred
    }

    /// 按归一化增量挪动。
    mutating func nudge(id: UUID, dx: Double, dy: Double) {
        guard let h = hold(id: id) else { return }
        move(id: id, to: h.x + dx, y: h.y + dy)
    }

    // MARK: 起步 / 结束（手动）

    /// 设为起步 / 取消起步。
    /// 第一次手动设起步会替换掉自动猜的那个；之后再设是追加，最多 2 个，多了替换最早设的那个。
    mutating func toggleStart(id: UUID) {
        guard holds.contains(where: { $0.id == id }) else { return }
        let wasAuto = !startIsManual
        startIsManual = true
        if let i = startHoldIDs.firstIndex(of: id) {
            startHoldIDs.remove(at: i)
        } else {
            if wasAuto {
                startHoldIDs = [id]
            } else {
                if startHoldIDs.count >= 2 { startHoldIDs.removeFirst() }
                startHoldIDs.append(id)
            }
            if finishHoldID == id {
                // 结束点被抢走：若结束是自动的就重算；手动设的就空着
                finishHoldID = nil
            }
        }
        recomputeDefaults()
    }

    /// 设为结束 / 取消结束。
    mutating func toggleFinish(id: UUID) {
        guard holds.contains(where: { $0.id == id }) else { return }
        finishIsManual = true
        if finishHoldID == id {
            finishHoldID = nil
        } else {
            finishHoldID = id
            if startHoldIDs.contains(id) {
                startHoldIDs.removeAll { $0 == id }
                if startHoldIDs.isEmpty { startIsManual = false }
            }
        }
        recomputeDefaults()
    }

    // MARK: 自动默认

    private mutating func recomputeDefaults() {
        let ordered = HoldNumbering.ordered(holds)
        if !startIsManual {
            // 最低的、且不是（手动）结束点的那个
            startHoldIDs = ordered.first(where: { !finishIsManual || $0.id != finishHoldID }).map { [$0.id] } ?? []
        }
        if !finishIsManual {
            // 最高的、且不是起步的那个；只有一个点时没有结束
            if ordered.count > 1, let top = ordered.last(where: { !startHoldIDs.contains($0.id) }) {
                finishHoldID = top.id
            } else {
                finishHoldID = nil
            }
        }
        // 兜底：引用的点必须存在
        let ids = Set(holds.map(\.id))
        startHoldIDs = startHoldIDs.filter { ids.contains($0) }
        if let f = finishHoldID, !ids.contains(f) { finishHoldID = nil }
    }
}
