import SwiftUI

/// 聚光灯几何：把归一化坐标映射到视图坐标。
struct SpotlightGeometry {
    let rect: CGRect

    /// - Parameters:
    ///   - focus: 归一化的关注区域（0…1）。给出时把该区域适配进视图（放大局部），
    ///     视图外的部分由 Canvas 自然裁掉；为 nil 时整图 fit/fill。
    init(size: CGSize, aspect: Double, fill: Bool, focus: CGRect? = nil) {
        let a = max(aspect, 0.05)
        if let f = focus, f.width > 0.01, f.height > 0.01 {
            // 图的“单位尺寸”为 (a, 1)，关注区域在单位空间里是 (f.minX*a, f.minY, f.width*a, f.height)
            let s = min(size.width / (f.width * a), size.height / f.height)
            let w = a * s
            let h = s
            let focusCenterUnit = CGPoint(x: f.midX * a, y: f.midY)
            var origin = CGPoint(x: size.width / 2 - focusCenterUnit.x * s, y: size.height / 2 - focusCenterUnit.y * s)
            // 图比视图大的方向上，尽量不露出底板；图比视图小的方向上居中。
            if w >= size.width { origin.x = min(0, max(size.width - w, origin.x)) } else { origin.x = (size.width - w) / 2 }
            if h >= size.height { origin.y = min(0, max(size.height - h, origin.y)) } else { origin.y = (size.height - h) / 2 }
            rect = CGRect(origin: origin, size: CGSize(width: w, height: h))
            return
        }
        var w = size.width
        var h = w / a
        if fill ? (h < size.height) : (h > size.height) {
            h = size.height
            w = h * a
        }
        rect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// 一组点的关注区域：包围盒向外扩 `padding`（相对包围盒尺寸），并保证最小尺寸。
    static func focusRect(for holds: [Hold], padding: Double = 0.25, minSize: Double = 0.3, extraBottom: Double = 0) -> CGRect? {
        guard let first = holds.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for h in holds {
            if let contour = h.contour {
                let b = contour.bounds
                minX = min(minX, b.minX); maxX = max(maxX, b.maxX)
                minY = min(minY, b.minY); maxY = max(maxY, b.maxY)
            } else {
                minX = min(minX, h.x - h.r); maxX = max(maxX, h.x + h.r)
                minY = min(minY, h.y - h.r); maxY = max(maxY, h.y + h.r)
            }
        }
        var w = maxX - minX
        var h = maxY - minY
        let padX = max(w * padding, 0.06)
        let padY = max(h * padding, 0.06)
        minX -= padX; maxX += padX
        minY -= padY; maxY += padY + extraBottom
        w = maxX - minX
        h = maxY - minY
        if w < minSize { let d = (minSize - w) / 2; minX -= d; maxX += d; w = minSize }
        if h < minSize { let d = (minSize - h) / 2; minY -= d; maxY += d; h = minSize }
        // 夹在图内
        minX = max(0, minX); minY = max(0, minY)
        maxX = min(1, maxX); maxY = min(1, maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var shortSide: CGFloat { min(rect.width, rect.height) }

    func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }

    func point(_ hold: Hold) -> CGPoint { point(hold.x, hold.y) }

    func radius(_ hold: Hold) -> CGFloat { hold.r * shortSide }

    func contactPoint(_ hold: Hold) -> CGPoint { point(hold.contactPoint.x, hold.contactPoint.y) }

    func outline(_ hold: Hold, pop: CGFloat = 1, padding: CGFloat = 0) -> Path {
        guard let contour = hold.contour else {
            let c = point(hold), r = radius(hold) * pop + padding
            return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        let b = bounds(hold), c = CGPoint(x: b.midX, y: b.midY)
        let sx = pop + 2 * padding / max(b.width, 1), sy = pop + 2 * padding / max(b.height, 1)
        var path = Path()
        for (i, p) in contour.points.enumerated() {
            let v = point(p.x, p.y), expanded = CGPoint(x: c.x + (v.x - c.x) * sx, y: c.y + (v.y - c.y) * sy)
            if i == 0 { path.move(to: expanded) } else { path.addLine(to: expanded) }
        }
        path.closeSubpath()
        return path
    }

    func bounds(_ hold: Hold) -> CGRect {
        if let contour = hold.contour {
            let b = contour.bounds, a = point(b.minX, b.minY), z = point(b.maxX, b.maxY)
            return CGRect(x: a.x, y: a.y, width: z.x - a.x, height: z.y - a.y)
        }
        let c = point(hold), r = radius(hold)
        return CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
    }

    /// Distance to the visible shape; long contours stay tappable away from their centre.
    func distance(to hold: Hold, from p: CGPoint) -> CGFloat {
        guard let contour = hold.contour else { return max(0, hypot(point(hold).x - p.x, point(hold).y - p.y) - radius(hold)) }
        if outline(hold).contains(p) { return 0 }
        let vertices = contour.points.map { point($0.x, $0.y) }
        return vertices.indices.map { i in
            let a = vertices[i], b = vertices[(i + 1) % vertices.count]
            let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
            let t = length > 0 ? min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length)) : 0
            return hypot(p.x - a.x - dx * t, p.y - a.y - dy * t)
        }.min() ?? .infinity
    }

    func normalized(_ p: CGPoint) -> CGPoint? {
        guard rect.width > 0, rect.height > 0 else { return nil }
        let x = (p.x - rect.minX) / rect.width
        let y = (p.y - rect.minY) / rect.height
        guard (0...1).contains(x), (0...1).contains(y) else { return nil }
        return CGPoint(x: x, y: y)
    }

    func hold(at p: CGPoint, in holds: [Hold], slop: CGFloat = 14) -> Hold? {
        var best: (Hold, CGFloat)?
        for h in holds {
            let c = point(h)
            let d = hypot(c.x - p.x, c.y - p.y)
            if distance(to: h, from: p) <= slop, best == nil || d < best!.1 { best = (h, d) }
        }
        return best?.0
    }

    /// 等比空间（y ∈ 0…1，x ∈ 0…aspect）→ 视图坐标。用于火柴人。
    func fromIso(_ p: CGPoint, aspect: Double) -> CGPoint {
        point(p.x / aspect, p.y)
    }

    func toIso(_ hold: Hold, aspect: Double) -> CGPoint {
        CGPoint(x: hold.contactPoint.x * aspect, y: hold.contactPoint.y)
    }
}

/// 掉落标记：在某个点上掉过几次，最近一次的“新鲜度”。
struct FallMark: Hashable {
    var holdID: UUID
    var count: Int
    var recency: Double // 0…1，1 为最近
}

/// 聚光灯图：暗墙 + 亮点。所有屏幕共用。
struct SpotlightImage: View, Animatable {
    var image: UIImage?
    var aspect: Double
    var holds: [Hold]
    var startHoldIDs: [UUID] = []
    var finishHoldID: UUID?
    var fallMarks: [FallMark] = []
    var highlightedHoldID: UUID?
    var pose: StickFigurePose?
    var poseIsoAspect: Double = 1
    var fill: Bool = false
    var showNumbers: Bool = true
    var dim: Double = 0.66
    /// 0…1：扫描进度；1 为全部亮起。
    var reveal: Double = 1
    var ringWidth: CGFloat = 2
    /// 归一化关注区域；给出时只把这一块适配进视图（放大局部）。
    var focus: CGRect? = nil
    /// 点单位缩放：描边、编号、掉落点、旗子等以 pt 计的元素统一乘这个系数。
    /// 分享图等大画布（1080pt）用 2…3，屏幕上保持 1。
    var scale: CGFloat = 1
    /// 拖动肢体时突出吸附目标，其余点略暗；集中在同一个 Canvas 绘制。
    var dragEmphasis: CGFloat = 0

    /// Only the newly accepted hold crossfades from its immediate circle feedback.
    var transitionHoldID: UUID?
    var contourTransition: Double = 1
    var animatableData: Double {
        get { contourTransition }
        set { contourTransition = newValue }
    }

    private static let coral = Color(red: 1.0, green: 0.45, blue: 0.38)

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { ctx, size in
            let geo = SpotlightGeometry(size: size, aspect: aspect, fill: fill, focus: focus)
            let ringWidth = self.ringWidth * scale
            drawBase(ctx: &ctx, geo: geo, size: size)
            let numbers = HoldNumbering.numbers(for: holds)
            let bandY = geo.rect.maxY - geo.rect.height * reveal
            let revealed = holds.filter { reveal >= 1 || geo.point($0).y >= bandY }

            // Reveal each clipped shape over a dark wall. Overlapping holds stay bright.
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(red: 0.02, green: 0.02, blue: 0.04).opacity(dim)))
            for h in revealed {
                for (shape, alpha) in shapes(for: h, geo: geo, bandY: bandY) where alpha > 0 {
                    ctx.drawLayer { layer in
                        layer.opacity = alpha
                        layer.clip(to: shape)
                        drawBase(ctx: &layer, geo: geo, size: size)
                    }
                }
            }

            // 暗角：视线落到亮点上
            if image != nil {
                let vignette = Gradient(stops: [
                    .init(color: .black.opacity(0), location: 0.55),
                    .init(color: .black.opacity(0.38), location: 1),
                ])
                let center = CGPoint(x: geo.rect.midX, y: geo.rect.midY)
                let radius = hypot(geo.rect.width, geo.rect.height) / 2
                ctx.fill(Path(geo.rect), with: .radialGradient(vignette, center: center, startRadius: 0, endRadius: radius))
            }

            // The glow follows the same polygon used by the mask and sharp outline.
            for h in revealed {
                for (shape, alpha) in shapes(for: h, geo: geo, bandY: bandY) where alpha > 0 {
                    ctx.drawLayer { layer in
                        layer.opacity = alpha
                        layer.addFilter(.blur(radius: 5 * scale))
                        layer.stroke(shape, with: .color(.accent.opacity(0.30)), lineWidth: 9 * scale)
                    }
                }
            }

            if dragEmphasis > 0 {
                for h in revealed {
                    if h.id == highlightedHoldID {
                        ctx.stroke(geo.outline(h, padding: ringWidth + 12),
                                   with: .color(.white.opacity(0.35 * dragEmphasis)), lineWidth: 6)
                    } else {
                        ctx.fill(geo.outline(h, padding: ringWidth * 3),
                                 with: .color(.black.opacity(0.30 * dragEmphasis)))
                    }
                }
            }

            // 扫描光带
            if reveal > 0, reveal < 1 {
                drawBand(ctx: &ctx, geo: geo, y: bandY)
            }

            // Outlines and markers use the same contour across all feature screens.
            for h in revealed {
                let pop = popScale(for: h, geo: geo, bandY: bandY)
                let isHighlighted = highlightedHoldID == h.id
                for (shape, alpha) in shapes(for: h, geo: geo, bandY: bandY) where alpha > 0 {
                    var layer = ctx
                    layer.opacity = alpha
                    layer.stroke(shape, with: .color(.accent.opacity(0.45)), lineWidth: ringWidth * 2)
                    layer.stroke(shape, with: .color(isHighlighted ? .white : .accent),
                                 lineWidth: isHighlighted ? ringWidth + 1 : ringWidth * 0.75)
                }
                let flash = flashAlpha(for: h, geo: geo, bandY: bandY)
                if flash > 0 {
                    ctx.stroke(geo.outline(h, pop: pop, padding: ringWidth * 3),
                               with: .color(.white.opacity(0.6 * flash)), lineWidth: 2 * scale)
                }
                if isHighlighted || startHoldIDs.contains(h.id) {
                    ctx.stroke(geo.outline(h, pop: pop, padding: ringWidth + 5 * scale),
                               with: .color(isHighlighted ? .white.opacity(0.9) : .accent.opacity(0.95)), lineWidth: 1.5 * scale)
                }
                let bounds = geo.bounds(h)
                if finishHoldID == h.id {
                    drawFlag(ctx: &ctx, at: CGPoint(x: bounds.midX, y: bounds.minY - ringWidth - 4 * scale),
                             height: max(12 * scale, min(bounds.width, bounds.height) * 0.35))
                }
                if showNumbers, let n = numbers[h.id] {
                    let label = Text(HoldLabel.circled(n))
                        .font(.system(size: max(11, min(16, geo.shortSide * 0.045 / scale)) * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    let pos = CGPoint(x: bounds.maxX + 3 * scale, y: bounds.minY - 3 * scale)
                    ctx.drawLayer { layer in
                        layer.addFilter(.shadow(color: .black.opacity(0.9), radius: 2 * scale))
                        layer.draw(label, at: pos)
                    }
                }
            }

            // 掉落标记
            for mark in fallMarks {
                guard let h = holds.first(where: { $0.id == mark.holdID }), revealed.contains(h) else { continue }
                let b = geo.bounds(h)
                let p = CGPoint(x: b.maxX, y: b.maxY)
                let dotR: CGFloat = (mark.count > 1 ? 8 : 5.5) * scale
                let alpha = 0.45 + 0.55 * mark.recency
                ctx.fill(Path(ellipseIn: circleRect(p, dotR)), with: .color(Self.coral.opacity(alpha)))
                ctx.stroke(Path(ellipseIn: circleRect(p, dotR)), with: .color(.black.opacity(0.5)), lineWidth: 1 * scale)
                if mark.count > 1 {
                    ctx.draw(Text("\(mark.count)").font(.system(size: 10 * scale, weight: .bold, design: .rounded)).foregroundStyle(.white), at: p)
                }
            }

            // 火柴人
            if let pose {
                drawFigure(ctx: &ctx, pose: pose, geo: geo)
            }
        }
    }

    private func shapes(for hold: Hold, geo: SpotlightGeometry, bandY: CGFloat) -> [(Path, Double)] {
        let pop = popScale(for: hold, geo: geo, bandY: bandY)
        guard hold.contour != nil, hold.id == transitionHoldID, contourTransition < 1 else {
            return [(geo.outline(hold, pop: pop), 1)]
        }
        var circle = hold
        circle.clearContour()
        let mix = min(1, max(0, contourTransition))
        return [(geo.outline(circle, pop: pop), 1 - mix), (geo.outline(hold, pop: pop), mix)]
    }

    // MARK: 绘制细节

    private func drawBase(ctx: inout GraphicsContext, geo: SpotlightGeometry, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.05, green: 0.05, blue: 0.07)))
        if let image {
            ctx.draw(Image(uiImage: image), in: geo.rect)
        } else {
            let g = Gradient(colors: [Color(red: 0.16, green: 0.16, blue: 0.2), Color(red: 0.07, green: 0.07, blue: 0.09)])
            ctx.fill(Path(geo.rect), with: .linearGradient(g, startPoint: geo.rect.origin, endPoint: CGPoint(x: geo.rect.minX, y: geo.rect.maxY)))
        }
    }

    private func drawBand(ctx: inout GraphicsContext, geo: SpotlightGeometry, y: CGFloat) {
        let bandRect = CGRect(x: geo.rect.minX, y: y - 28 * scale, width: geo.rect.width, height: 56 * scale)
        let g = Gradient(stops: [
            .init(color: .accent.opacity(0), location: 0),
            .init(color: .accent.opacity(0.35), location: 0.5),
            .init(color: .accent.opacity(0), location: 1),
        ])
        ctx.fill(Path(bandRect), with: .linearGradient(g, startPoint: CGPoint(x: 0, y: bandRect.minY), endPoint: CGPoint(x: 0, y: bandRect.maxY)))
        var line = Path()
        line.move(to: CGPoint(x: geo.rect.minX, y: y))
        line.addLine(to: CGPoint(x: geo.rect.maxX, y: y))
        ctx.stroke(line, with: .color(.accent.opacity(0.9)), lineWidth: 1.5 * scale)
    }

    /// 刚被光带扫过的点略微放大再回落。
    private func popScale(for hold: Hold, geo: SpotlightGeometry, bandY: CGFloat) -> CGFloat {
        guard reveal < 1 else { return 1 }
        let dy = geo.point(hold).y - bandY
        let window = geo.rect.height * 0.12
        guard dy >= 0, dy < window else { return 1 }
        let t = 1 - dy / window
        return 1 + 0.22 * t
    }

    /// 刚被光带扫过的点闪一下（0…1）。
    private func flashAlpha(for hold: Hold, geo: SpotlightGeometry, bandY: CGFloat) -> CGFloat {
        guard reveal < 1 else { return 0 }
        let dy = geo.point(hold).y - bandY
        let window = geo.rect.height * 0.08
        guard dy >= 0, dy < window else { return 0 }
        return 1 - dy / window
    }

    private func drawFlag(ctx: inout GraphicsContext, at base: CGPoint, height: CGFloat) {
        var pole = Path()
        pole.move(to: base)
        pole.addLine(to: CGPoint(x: base.x, y: base.y - height))
        ctx.stroke(pole, with: .color(.accent), lineWidth: 1.5 * scale)
        var flag = Path()
        flag.move(to: CGPoint(x: base.x, y: base.y - height))
        flag.addLine(to: CGPoint(x: base.x + height * 0.75, y: base.y - height * 0.78))
        flag.addLine(to: CGPoint(x: base.x, y: base.y - height * 0.52))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(.accent))
    }

    private func drawFigure(ctx: inout GraphicsContext, pose: StickFigurePose, geo: SpotlightGeometry) {
        func v(_ p: CGPoint) -> CGPoint { geo.fromIso(p, aspect: poseIsoAspect) }
        // 线宽随画布尺寸缩放：缩略图 1pt，全屏约 3pt
        let lw: CGFloat = min(3.2, max(1.0, geo.shortSide * 0.008 / scale)) * scale
        var path = Path()
        // 躯干
        path.move(to: v(pose.neck)); path.addLine(to: v(pose.hipCenter))
        // 肩、髋横线
        path.move(to: v(pose.leftShoulder)); path.addLine(to: v(pose.rightShoulder))
        path.move(to: v(pose.leftHip)); path.addLine(to: v(pose.rightHip))
        // 四肢
        path.move(to: v(pose.leftShoulder)); path.addLine(to: v(pose.leftElbow)); path.addLine(to: v(pose.leftHand))
        path.move(to: v(pose.rightShoulder)); path.addLine(to: v(pose.rightElbow)); path.addLine(to: v(pose.rightHand))
        path.move(to: v(pose.leftHip)); path.addLine(to: v(pose.leftKnee)); path.addLine(to: v(pose.leftFoot))
        path.move(to: v(pose.rightHip)); path.addLine(to: v(pose.rightKnee)); path.addLine(to: v(pose.rightFoot))

        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.7), radius: 3 * scale))
            layer.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            let headR = pose.headRadius * geo.rect.height / 1.0
            layer.stroke(Path(ellipseIn: circleRect(v(pose.head), headR)), with: .color(.white), lineWidth: lw)
            layer.fill(Path(ellipseIn: circleRect(v(pose.head), headR)), with: .color(.white.opacity(0.15)))
            for j in [pose.leftElbow, pose.rightElbow, pose.leftKnee, pose.rightKnee, pose.leftShoulder, pose.rightShoulder, pose.leftHip, pose.rightHip] {
                layer.fill(Path(ellipseIn: circleRect(v(j), lw * 0.9)), with: .color(.white))
            }
            // 手脚末端：左白右黄区分
            for (p, isLeft) in [(pose.leftHand, true), (pose.rightHand, false), (pose.leftFoot, true), (pose.rightFoot, false)] {
                layer.fill(Path(ellipseIn: circleRect(v(p), lw * 1.6)), with: .color(isLeft ? .white : .accent))
            }
        }
    }

    private func circleRect(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    }
}
