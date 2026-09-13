import SwiftData
import SwiftUI

// MARK: - 数据快照

/// 分享图需要的全部字段，从 `Line` 抽出来，让渲染与存储层解耦（也方便测试/预览）。
struct ShareCardModel: Hashable {
    var name: String
    var areaName: String?
    var gradeText: String?
    var status: LineStatus
    var cycle: Int
    var reminderText: String?
    var reminderVerified: Bool
    var holds: [Hold]
    var startHoldIDs: [UUID]
    var finishHoldID: UUID?
    /// 墙照片宽高比（宽/高）。
    var aspect: Double
    /// 全部有效记录，按日期升序。
    var visits: [ShareVisit]
    var createdAt: Date
    var actualSequence: ClimbSequence? = nil
    var profile: BodyProfile = .default

    var visitCount: Int { visits.count }
    var totalAttempts: Int { visits.reduce(0) { $0 + $1.attemptCount } }
    var lastVisit: Date? { visits.map(\.date).max() }
    var hasReminder: Bool { reminderText?.isEmpty == false }
    var hasHolds: Bool { !holds.isEmpty }

    /// 大字右侧的小字：墙区 · 难度。线名里已经包含墙区时不再重复。
    var subtitleText: String {
        var parts: [String] = []
        if let areaName, !areaName.isEmpty, !nameContains(areaName) { parts.append(areaName) }
        if let gradeText, !gradeText.isEmpty, !nameContains(gradeText) { parts.append(gradeText) }
        return parts.joined(separator: " · ")
    }

    /// 兼容旧文案：墙区 · 难度；两者都没有时退回线名。
    var titleText: String {
        var parts: [String] = []
        if let areaName, !areaName.isEmpty { parts.append(areaName) }
        if let gradeText, !gradeText.isEmpty { parts.append(gradeText) }
        return parts.isEmpty ? name : parts.joined(separator: " · ")
    }

    /// 第二行：来了 N 次 · 共 M 次尝试（状态另外拼在后面）。
    var visitText: String {
        visitCount == 0 ? "还没有记录" : "来了 \(visitCount) 次 · 共 \(totalAttempts) 次尝试"
    }

    /// 底部小字：建于 / 最近。
    var dateText: String {
        var parts = ["建于 " + DateText.short(createdAt)]
        if let last = lastVisit, !Calendar.current.isDate(last, inSameDayAs: createdAt) {
            parts.append("最近 " + DateText.short(last))
        }
        return parts.joined(separator: " · ")
    }

    /// 分享面板里的标题。
    var shareTitle: String { "\(titleText) · \(status.title) · 线感" }

    var fallMarks: [FallMark] { ShareSnapshotBuilder.fallMarks(visits: visits) }

    func label(for holdID: UUID?) -> String? {
        guard let holdID, let n = HoldNumbering.numbers(for: holds)[holdID] else { return nil }
        return HoldLabel.circled(n)
    }

    private func nameContains(_ s: String) -> Bool {
        let strip: (String) -> String = { $0.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "·", with: "") }
        return strip(name).contains(strip(s))
    }
}

extension ShareCardModel {
    init(line: Line, profile: BodyProfile = .default) {
        self.init(
            name: line.name,
            areaName: line.wall?.areaName,
            gradeText: line.gradeText,
            status: line.status,
            cycle: line.cycle,
            reminderText: line.reminderText,
            reminderVerified: line.reminderVerified,
            holds: line.holds,
            startHoldIDs: line.startHoldIDs,
            finishHoldID: line.finishHoldID,
            aspect: line.wall?.aspectRatio ?? 0.75,
            visits: line.orderedSessions.map(ShareVisit.init(session:)),
            createdAt: line.createdAt,
            actualSequence: line.actualSequence,
            profile: profile
        )
    }
}

// MARK: - 版式

/// 分享图的尺寸计算：图占多高、快照带每格多大。纯逻辑，可测。
struct ShareCardLayout: Equatable {
    static let size = CGSize(width: 540, height: 960)
    static let margin: CGFloat = 32
    static let cellSpacing: CGFloat = 6
    static let maxCellWidth: CGFloat = 72
    /// 图最矮/最高（pt）。默认内容下约 62%。
    static let minArtworkHeight: CGFloat = 520
    static let maxArtworkHeight: CGFloat = 700
    /// 一行提醒能放下的字数（22pt 半粗、476pt 宽）。
    static let reminderCharsPerLine = 21

    static var contentWidth: CGFloat { size.width - margin * 2 }

    let snapshotCount: Int
    let reminderLines: Int
    let cellSize: CGSize
    let textBlockHeight: CGFloat
    let artworkHeight: CGFloat

    init(snapshotCount: Int, reminder: String?) {
        self.snapshotCount = snapshotCount
        let trimmed = reminder?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        reminderLines = trimmed.isEmpty ? 0 : (trimmed.count > Self.reminderCharsPerLine ? 2 : 1)
        cellSize = Self.cellSize(count: snapshotCount)

        var h: CGFloat = 22 // 顶部留白
        h += 40 // 大字
        h += 8 + 26 // 次数行
        if reminderLines > 0 { h += 10 + 28 * CGFloat(reminderLines) }
        if snapshotCount > 0 { h += 18 + cellSize.height + 6 + 30 }
        h += 18 + 18 // 底部小字
        h += 28 // 底部留白
        textBlockHeight = h
        artworkHeight = min(Self.maxArtworkHeight, max(Self.minArtworkHeight, Self.size.height - h))
    }

    var artworkSize: CGSize { CGSize(width: Self.size.width, height: artworkHeight) }

    static func cellSize(count: Int) -> CGSize {
        guard count > 0 else { return .zero }
        let n = CGFloat(count)
        let w = min(maxCellWidth, floor((contentWidth - cellSpacing * (n - 1)) / n))
        return CGSize(width: w, height: floor(w * 4 / 3))
    }
}

// MARK: - 分享图

/// 分享图：固定 9:16 竖图。以 540×960 pt 布局、2x 渲染，输出 1080×1920 px。
/// 上 62% 左右是自动取景到这条线的聚光灯图（描边/编号按 `scale: 2` 放大），下面是文字与快照带。
struct ShareCardView: View {
    /// 布局尺寸（pt）。
    static let size = ShareCardLayout.size
    /// 输出尺寸（px）。
    static let pixelSize = CGSize(width: 1080, height: 1920)
    /// 大画布上描边/编号/掉落点的放大倍数。
    static let markerScale: CGFloat = 2

    let model: ShareCardModel
    let image: UIImage?
    var includesSnapshots = true

    init(model: ShareCardModel, image: UIImage?) {
        self.model = model
        self.image = image
    }

    init(line: Line, image: UIImage?) {
        self.init(model: ShareCardModel(line: line), image: image)
    }

    private var snapshots: [ShareSnapshot] { ShareSnapshotBuilder.snapshots(visits: model.visits) }
    private var sequenceSnapshots: [ShareSequenceSnapshot] {
        ShareSnapshotBuilder.sequenceSnapshots(holds: model.holds, startHoldIDs: model.startHoldIDs,
                                              sequence: model.actualSequence, aspect: model.aspect, profile: model.profile)
    }
    private var layout: ShareCardLayout { ShareCardLayout(snapshotCount: snapshots.count, reminder: model.reminderText) }

    var body: some View {
        let sequenceSnaps = includesSnapshots ? sequenceSnapshots : []
        let snaps = includesSnapshots && sequenceSnaps.isEmpty ? snapshots : []
        let layout = ShareCardLayout(snapshotCount: sequenceSnaps.count + snaps.count, reminder: model.reminderText)
        VStack(spacing: 0) {
            artwork(layout)
            VStack(alignment: .leading, spacing: 0) {
                headline
                visitLine
                    .padding(.top, 8)
                if let reminder = model.reminderText, !reminder.isEmpty {
                    reminderRow(reminder)
                        .padding(.top, 10)
                }
                if !sequenceSnaps.isEmpty {
                    sequenceStrip(sequenceSnaps, cell: layout.cellSize)
                        .padding(.top, 18)
                } else if !snaps.isEmpty {
                    strip(snaps, cell: layout.cellSize)
                        .padding(.top, 18)
                }
                Spacer(minLength: 18)
                footer
            }
            .padding(.horizontal, ShareCardLayout.margin)
            .padding(.top, 22)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.ink)
        .environment(\.colorScheme, .dark)
    }

    // MARK: 图区

    private func artwork(_ layout: ShareCardLayout) -> some View {
        let size = layout.artworkSize
        return ZStack {
            if model.hasHolds {
                SpotlightImage(
                    image: image,
                    aspect: model.aspect,
                    holds: model.holds,
                    startHoldIDs: model.startHoldIDs,
                    finishHoldID: model.finishHoldID,
                    fallMarks: model.fallMarks,
                    fill: true,
                    showNumbers: true,
                    dim: 0.66,
                    focus: SpotlightGeometry.fillingFocusRect(for: model.holds, aspect: model.aspect, viewSize: size, padding: 0.3, minSize: 0.5),
                    scale: Self.markerScale
                )
            } else {
                noHoldsArtwork
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(alignment: .bottom) {
            // 图的下沿融进底色，文字不压图
            LinearGradient(colors: [Color.ink.opacity(0), Color.ink.opacity(0.85), Color.ink], startPoint: .top, endPoint: .bottom)
                .frame(height: 64)
        }
    }

    /// 不拍照、也没点位的线：同款底板 + 一束光 + 难度。
    private var noHoldsArtwork: some View {
        ZStack {
            SpotlightImage(image: nil, aspect: model.aspect, holds: [], fill: true, showNumbers: false, dim: 0)
            Circle()
                .fill(RadialGradient(colors: [Color.accent.opacity(0.38), Color.accent.opacity(0)], center: .center, startRadius: 0, endRadius: 190))
                .frame(width: 380, height: 380)
                .offset(y: -40)
            VStack(spacing: 14) {
                Text(model.gradeText?.isEmpty == false ? model.gradeText! : "?")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("没拍照的线")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.subtle)
            }
            .offset(y: -30)
        }
    }

    // MARK: 文字

    /// 线名 + 墙区 · 难度，一行大字。
    private var headline: some View {
        let sub = model.subtitleText
        var text = Text(model.name)
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
        if !sub.isEmpty {
            text = text + Text("  " + sub)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(Color.subtle)
        }
        return text
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(height: 40, alignment: .leading)
    }

    /// 来了 N 次 · 共 M 次尝试 · 上了/进行中。
    private var visitLine: some View {
        let base = Text(model.visitText + " · ")
            .foregroundStyle(Color.subtle)
        let statusColor: Color = model.status == .sent ? .white : Color.subtle
        var status = Text("\(Image(systemName: model.status.symbol)) \(model.status.title)")
            .foregroundStyle(statusColor)
        if model.status == .sent { status = status.fontWeight(.semibold) }
        var text = base + status
        if model.cycle > 1 {
            text = text + Text(" · 第 \(model.cycle) 轮").foregroundStyle(Color.subtle)
        }
        return text
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: 26, alignment: .leading)
    }

    private func reminderRow(_ reminder: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: model.reminderVerified ? "checkmark.seal.fill" : "lightbulb.fill")
                .font(.system(size: 20, weight: .semibold))
            Text(reminder)
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.accent)
        .accessibilityLabel(model.reminderVerified ? "验证过的提醒：\(reminder)" : "提醒：\(reminder)")
    }

    // MARK: 快照带

    private func sequenceStrip(_ snaps: [ShareSequenceSnapshot], cell: CGSize) -> some View {
        HStack(alignment: .top, spacing: ShareCardLayout.cellSpacing) {
            ForEach(snaps) { snap in
                VStack(spacing: 6) {
                    SpotlightImage(image: image, aspect: model.aspect, holds: model.holds,
                                   startHoldIDs: model.startHoldIDs, finishHoldID: model.finishHoldID,
                                   pose: snap.pose, poseIsoAspect: model.aspect, showNumbers: false,
                                   dim: 0.7, ringWidth: 1, focus: SequenceScene.focusRect(for: model.holds))
                        .frame(width: cell.width, height: cell.height)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(spacing: 2) {
                        Text("第 \(snap.stepIndex + 1) 步")
                        Text(snap.step.limb.title + "→" + (model.label(for: snap.step.holdID) ?? "地面"))
                            .foregroundStyle(Color.subtle)
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: cell.width)
                }
            }
        }
        .accessibilityLabel("实际顺序，\(snaps.count) 个快照")
    }

    private func strip(_ snaps: [ShareSnapshot], cell: CGSize) -> some View {
        HStack(alignment: .top, spacing: ShareCardLayout.cellSpacing) {
            ForEach(snaps) { snap in
                snapshotCell(snap, size: cell)
            }
        }
    }

    private func snapshotCell(_ snap: ShareSnapshot, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        let visit = snap.visit
        let caption = ShareSnapshotBuilder.caption(for: visit, label: model.label(for:))
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if model.hasHolds {
                    SpotlightImage(
                        image: image,
                        aspect: model.aspect,
                        holds: model.holds,
                        fallMarks: visit.fallHoldID.map { [FallMark(holdID: $0, count: 1, recency: 1)] } ?? [],
                        highlightedHoldID: visit.fallHoldID,
                        fill: true,
                        showNumbers: false,
                        dim: visit.fallHoldID == nil ? 0.6 : 0.74,
                        ringWidth: 1.2,
                        focus: SpotlightGeometry.fillingFocusRect(for: model.holds, aspect: model.aspect, viewSize: size, padding: 0.22, minSize: 0.4)
                    )
                } else {
                    ZStack {
                        SpotlightImage(image: nil, aspect: 0.75, holds: [], fill: true, showNumbers: false, dim: 0)
                        Text(visit.attemptCount > 0 ? "\(visit.attemptCount)" : "·")
                            .font(.system(size: size.width * 0.42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .monospacedDigit()
                    }
                }
                if visit.sent {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .padding(4)
                        .background(Color.white, in: Circle())
                        .padding(4)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
            VStack(spacing: 2) {
                Text(DateText.short(visit.date))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text(caption.isEmpty ? " " : caption)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(visit.sent ? .white : Color.subtle)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size.width)
        }
    }

    // MARK: 底部

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.dateText)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.subtle.opacity(0.8))
                .monospacedDigit()
                .lineLimit(1)
            Spacer(minLength: 12)
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.accent.opacity(0.9), radius: 5)
                Text("线感 LineWise")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(height: 18)
    }
}

// MARK: - 渲染

/// 把分享图渲染成 1080×1920 px 的位图。必须在主线程调用（`ImageRenderer` 是 MainActor）。
@MainActor
enum ShareCardRenderer {
    static func render(_ card: ShareCardView) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = ShareCardView.pixelSize.width / ShareCardView.size.width
        renderer.proposedSize = ProposedViewSize(ShareCardView.size)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    static func render(line: Line, image: UIImage?) -> UIImage? {
        render(ShareCardView(line: line, image: image))
    }

    static func render(model: ShareCardModel, image: UIImage?, includesSnapshots: Bool = true) -> UIImage? {
        var card = ShareCardView(model: model, image: image)
        card.includesSnapshots = includesSnapshots
        return render(card)
    }
}

// MARK: - 预览

#if DEBUG
extension ShareCardModel {
    /// 预览/测试用的演示数据：一面 3:4 的墙、7 个点、3 次记录。
    static func demo(withPhoto: Bool = true, visitCount: Int = 3, reminder: String? = "掉在 ⑤ · 脚 · 左手抓到就要顶髌") -> ShareCardModel {
        let holds = [
            Hold(x: 0.30, y: 0.90, r: 0.04), Hold(x: 0.42, y: 0.76, r: 0.038), Hold(x: 0.36, y: 0.63, r: 0.045),
            Hold(x: 0.55, y: 0.52, r: 0.04), Hold(x: 0.48, y: 0.40, r: 0.036), Hold(x: 0.62, y: 0.27, r: 0.04),
            Hold(x: 0.56, y: 0.12, r: 0.042),
        ]
        let ordered = HoldNumbering.ordered(holds)
        let cal = Calendar.current
        let visits: [ShareVisit] = (0..<visitCount).map { i in
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -(visitCount - i) * 3, to: .now)!)
            let isLast = i == visitCount - 1
            return ShareVisit(
                date: date,
                attemptCount: 6 - min(i, 4),
                sent: false,
                fallHoldID: withPhoto ? ordered[min(2 + i / 2, ordered.count - 1)].id : nil,
                fallText: withPhoto ? nil : (isLast ? "第三个点" : nil)
            )
        }
        return ShareCardModel(
            name: withPhoto ? "斜板墙 · 蓝" : "角落那条黄的",
            areaName: withPhoto ? "斜板墙" : nil,
            gradeText: "V3",
            status: .projecting,
            cycle: 1,
            reminderText: reminder,
            reminderVerified: false,
            holds: withPhoto ? holds : [],
            startHoldIDs: [ordered[0].id],
            finishHoldID: ordered[6].id,
            aspect: 0.75,
            visits: visits,
            createdAt: cal.date(byAdding: .day, value: -(visitCount * 3 + 2), to: .now)!
        )
    }

    /// 合成一张 3:4 的“墙”照片，给预览和测试用。
    static func demoWallImage(holds: [Hold], size: CGSize = CGSize(width: 900, height: 1200)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.70, green: 0.68, blue: 0.64, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            for i in 0..<6 {
                UIColor(white: 0.6 + Double(i % 2) * 0.06, alpha: 0.5).setFill()
                cg.fill(CGRect(x: 0, y: CGFloat(i) * size.height / 6, width: size.width, height: size.height / 6 - 4))
            }
            UIColor(white: 0.45, alpha: 0.35).setFill()
            for y in stride(from: 30, to: Int(size.height), by: 70) {
                for x in stride(from: 30, to: Int(size.width), by: 70) {
                    cg.fillEllipse(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                }
            }
            let colors: [UIColor] = [
                UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1), UIColor(red: 0.92, green: 0.28, blue: 0.28, alpha: 1),
                UIColor(red: 0.25, green: 0.75, blue: 0.40, alpha: 1), UIColor(red: 0.62, green: 0.38, blue: 0.85, alpha: 1),
            ]
            var k = 0
            for y in stride(from: 0.08, through: 0.95, by: 0.11) {
                for x in stride(from: 0.08, through: 0.95, by: 0.16) {
                    colors[k % colors.count].setFill()
                    k += 1
                    let r = size.width * 0.022
                    cg.fillEllipse(in: CGRect(x: x * size.width - r, y: y * size.height - r * 0.8, width: r * 2, height: r * 1.6))
                }
            }
            colors[0].setFill()
            for h in holds {
                let r = h.r * size.width
                cg.setShadow(offset: CGSize(width: 0, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.35).cgColor)
                cg.fillEllipse(in: CGRect(x: h.x * size.width - r, y: h.y * size.height - r * 0.85, width: r * 2, height: r * 1.7))
            }
        }
    }
}

#Preview("分享图 · 有照片 + 3 次") {
    let model = ShareCardModel.demo()
    ScrollView {
        ShareCardView(model: model, image: ShareCardModel.demoWallImage(holds: model.holds))
            .scaleEffect(0.7, anchor: .top)
            .frame(width: 540 * 0.7, height: 960 * 0.7)
    }
    .background(Color.black)
}

#Preview("分享图 · 12 次 → 8 格") {
    var model = ShareCardModel.demo(visitCount: 12)
    model.status = .sent
    model.visits[model.visits.count - 1].sent = true
    model.visits[model.visits.count - 1].fallHoldID = nil
    return ShareCardView(model: model, image: ShareCardModel.demoWallImage(holds: model.holds))
        .scaleEffect(0.7, anchor: .top)
        .frame(width: 540 * 0.7, height: 960 * 0.7)
        .background(Color.black)
}

#Preview("分享图 · 无照片") {
    let model = ShareCardModel.demo(withPhoto: false, visitCount: 2, reminder: "掉在第三个点 · 没力")
    ShareCardView(model: model, image: nil)
        .scaleEffect(0.7, anchor: .top)
        .frame(width: 540 * 0.7, height: 960 * 0.7)
        .background(Color.black)
}
#endif
