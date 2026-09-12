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
    var visitCount: Int
    var totalAttempts: Int
    var reminderText: String?
    var reminderVerified: Bool
    var holds: [Hold]
    var startHoldIDs: [UUID]
    var finishHoldID: UUID?
    /// 墙照片宽高比（宽/高）。
    var aspect: Double
    var actualSequence: ClimbSequence?
    var createdAt: Date
    var lastVisit: Date?

    /// 第一行：墙区 · 难度；两者都没有时退回线名。
    var titleText: String {
        var parts: [String] = []
        if let areaName, !areaName.isEmpty { parts.append(areaName) }
        if let gradeText, !gradeText.isEmpty { parts.append(gradeText) }
        return parts.isEmpty ? name : parts.joined(separator: " · ")
    }

    /// 第二行：来了 N 次 · 共 M 次尝试。
    var visitText: String {
        visitCount == 0 ? "还没有记录" : "来了 \(visitCount) 次 · 共 \(totalAttempts) 次尝试"
    }

    /// 分享面板里的标题。
    var shareTitle: String { "\(titleText) · \(status.title) · 线感" }

    var hasReminder: Bool { reminderText?.isEmpty == false }
}

extension ShareCardModel {
    init(line: Line) {
        self.init(
            name: line.name,
            areaName: line.wall?.areaName,
            gradeText: line.gradeText,
            status: line.status,
            cycle: line.cycle,
            visitCount: line.visitCount,
            totalAttempts: line.totalAttempts,
            reminderText: line.reminderText,
            reminderVerified: line.reminderVerified,
            holds: line.holds,
            startHoldIDs: line.startHoldIDs,
            finishHoldID: line.finishHoldID,
            aspect: line.wall?.aspectRatio ?? 0.75,
            actualSequence: line.actualSequence,
            createdAt: line.createdAt,
            lastVisit: line.latestSession?.date
        )
    }
}

// MARK: - 分享图

/// 分享图：固定 9:16 竖图。以 540×960 pt 布局、2x 渲染，输出 1080×1920 px，
/// 这样 `SpotlightImage` 里按 pt 设计的编号字号、描边宽度在图里仍然清晰。
struct ShareCardView: View {
    /// 布局尺寸（pt）。
    static let size = CGSize(width: 540, height: 960)
    /// 输出尺寸（px）。
    static let pixelSize = CGSize(width: 1080, height: 1920)

    let model: ShareCardModel
    let image: UIImage?
    let profile: BodyProfile

    init(model: ShareCardModel, image: UIImage?, profile: BodyProfile) {
        self.model = model
        self.image = image
        self.profile = profile
    }

    init(line: Line, image: UIImage?, profile: BodyProfile) {
        self.init(model: ShareCardModel(line: line), image: image, profile: profile)
    }

    // 版式常量
    private let margin: CGFloat = 32
    private let cellSpacing: CGFloat = 6
    private let maxCellWidth: CGFloat = 84
    private let maxCellHeight: CGFloat = 112

    private var contentWidth: CGFloat { Self.size.width - margin * 2 }
    private var hasPhotoArtwork: Bool { !model.holds.isEmpty }

    private var snapshots: [ShareSnapshot] {
        guard hasPhotoArtwork else { return [] }
        return ShareSnapshotBuilder.snapshots(
            holds: model.holds, startHoldIDs: model.startHoldIDs, sequence: model.actualSequence,
            aspect: model.aspect, profile: profile
        )
    }

    var body: some View {
        let snaps = snapshots
        VStack(alignment: .leading, spacing: 0) {
            // 内容偏上：上方留白最多 140，其余给下方。
            Spacer(minLength: 0).frame(maxHeight: 140)
            kicker
            artwork(snapCount: snaps.count)
                .padding(.top, 14)
            textBlock
                .padding(.top, 26)
            if !snaps.isEmpty {
                strip(snaps)
                    .padding(.top, 26)
            }
            Spacer(minLength: 0)
            brandRow
        }
        .padding(margin)
        .frame(width: Self.size.width, height: Self.size.height)
        .background { backdrop }
        .environment(\.colorScheme, .dark)
    }

    // MARK: 背景

    private var backdrop: some View {
        ZStack {
            Color.ink
            RadialGradient(
                colors: [Color.accent.opacity(0.11), Color.accent.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.22), startRadius: 0, endRadius: 460
            )
        }
    }

    // MARK: 顶部小字：线名 · 日期

    private var kicker: some View {
        HStack(alignment: .firstTextBaseline) {
            if model.titleText != model.name {
                Text(model.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(dateText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.subtle)
                .monospacedDigit()
        }
    }

    private var dateText: String {
        if let last = model.lastVisit { return "最近 " + DateText.short(last) }
        return "建于 " + DateText.short(model.createdAt)
    }

    // MARK: 图区

    /// 文字与快照带之外留给图的最大高度。
    private func artworkMaxHeight(snapCount: Int) -> CGFloat {
        let brand: CGFloat = 20 + 12
        let kickerH: CGFloat = 20 + 14
        var text: CGFloat = 26 + 42 + 8 + 26
        if model.hasReminder { text += 10 + 56 }
        var strip: CGFloat = 0
        if snapCount > 0 { strip = 26 + 20 + 8 + cellSize(count: snapCount).height + 6 + 16 }
        return Self.size.height - margin * 2 - brand - kickerH - text - strip
    }

    private func artworkSize(snapCount: Int) -> CGSize {
        let maxH = max(200, artworkMaxHeight(snapCount: snapCount))
        guard hasPhotoArtwork else {
            return CGSize(width: contentWidth, height: min(maxH, 400))
        }
        let a = max(model.aspect, 0.2)
        let naturalH = contentWidth / a
        if naturalH <= maxH { return CGSize(width: contentWidth, height: naturalH) }
        return CGSize(width: maxH * a, height: maxH)
    }

    private func artwork(snapCount: Int) -> some View {
        let size = artworkSize(snapCount: snapCount)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack {
            Spacer(minLength: 0)
            Group {
                if hasPhotoArtwork {
                    SpotlightImage(
                        image: image,
                        aspect: model.aspect,
                        holds: model.holds,
                        startHoldIDs: model.startHoldIDs,
                        finishHoldID: model.finishHoldID,
                        fill: false,
                        showNumbers: true,
                        dim: 0.66
                    )
                } else {
                    noPhotoArtwork
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
            Spacer(minLength: 0)
        }
    }

    /// 无照片的线：暗底 + 线名大字 + 一束光。
    private var noPhotoArtwork: some View {
        ZStack {
            LinearGradient(colors: [Color.panelElevated, Color.ink], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [Color.accent.opacity(0.42), Color.accent.opacity(0)], center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .offset(y: -30)
            VStack(spacing: 12) {
                Text(model.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                if let grade = model.gradeText, !grade.isEmpty {
                    Text(grade)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.accent, in: Capsule())
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: 三行字

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text(model.titleText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                statusChip
                if model.cycle > 1 {
                    chip("第 \(model.cycle) 轮", prominent: false)
                }
            }
            Text(model.visitText)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color.subtle)
                .monospacedDigit()
            if let reminder = model.reminderText, !reminder.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: model.reminderVerified ? "checkmark.seal.fill" : "lightbulb.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .padding(.top, 3)
                    Text(reminder)
                        .font(.system(size: 21, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.accent)
                .padding(.top, 4)
            }
        }
    }

    private var statusChip: some View {
        chip(model.status.title, systemImage: model.status.symbol, prominent: model.status == .sent)
    }

    private func chip(_ title: String, systemImage: String? = nil, prominent: Bool) -> some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .bold)) }
            Text(title)
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(prominent ? Color.accent : Color.white.opacity(0.12), in: Capsule())
        .foregroundStyle(prominent ? Color.ink : Color.white.opacity(0.9))
        .lineLimit(1)
        .fixedSize()
    }

    // MARK: 快照带

    private func cellSize(count: Int) -> CGSize {
        let n = CGFloat(max(count, 1))
        let w = min(maxCellWidth, floor((contentWidth - cellSpacing * (n - 1)) / n))
        let h = min(maxCellHeight, floor(w / max(model.aspect, 0.2)))
        return CGSize(width: w, height: h)
    }

    private func strip(_ snaps: [ShareSnapshot]) -> some View {
        let total = model.actualSequence?.steps.count ?? snaps.count
        let cell = cellSize(count: snaps.count)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "figure.climbing")
                    .font(.system(size: 13, weight: .semibold))
                Text("实际顺序")
                    .font(.system(size: 14, weight: .semibold))
                Text(total > snaps.count ? "共 \(total) 步 · 抽 \(snaps.count) 步" : "\(total) 步")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .opacity(0.75)
            }
            .foregroundStyle(Color.subtle)
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(snaps) { snap in
                    snapshotCell(snap, size: cell)
                }
            }
        }
    }

    private func snapshotCell(_ snap: ShareSnapshot, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        let numbers = HoldNumbering.numbers(for: model.holds)
        let holdLabel = numbers[snap.step.holdID].map(HoldLabel.circled) ?? ""
        return VStack(spacing: 4) {
            SpotlightImage(
                image: image,
                aspect: model.aspect,
                holds: model.holds,
                highlightedHoldID: snap.step.holdID,
                pose: snap.pose,
                poseIsoAspect: model.aspect,
                fill: false,
                showNumbers: false,
                dim: 0.72,
                ringWidth: 1.5
            )
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 1))
            HStack(spacing: 2) {
                Text("\(snap.stepNumber)")
                    .foregroundStyle(Color.accent)
                Text(snap.step.limb.shortTitle + holdLabel)
                    .foregroundStyle(Color.subtle)
            }
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: size.width)
        }
    }

    // MARK: 品牌

    private var brandRow: some View {
        HStack {
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.accent.opacity(0.9), radius: 5)
                Text("线感 LineWise")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
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

    static func render(line: Line, image: UIImage?, profile: BodyProfile) -> UIImage? {
        render(ShareCardView(line: line, image: image, profile: profile))
    }

    static func render(model: ShareCardModel, image: UIImage?, profile: BodyProfile) -> UIImage? {
        render(ShareCardView(model: model, image: image, profile: profile))
    }
}

// MARK: - 预览

#if DEBUG
extension ShareCardModel {
    /// 预览/测试用的演示数据：一面 3:4 的墙、7 个点、3 次记录、一个 10 步的实际顺序。
    static func demo(withPhoto: Bool = true, withSequence: Bool = true, reminder: String? = "掉在 ⑤ · 脚 · 左手抓到就要顶髌") -> ShareCardModel {
        let holds = [
            Hold(x: 0.30, y: 0.90, r: 0.04), Hold(x: 0.42, y: 0.76, r: 0.038), Hold(x: 0.36, y: 0.63, r: 0.045),
            Hold(x: 0.55, y: 0.52, r: 0.04), Hold(x: 0.48, y: 0.40, r: 0.036), Hold(x: 0.62, y: 0.27, r: 0.04),
            Hold(x: 0.56, y: 0.12, r: 0.042),
        ]
        let ordered = HoldNumbering.ordered(holds)
        var seq: ClimbSequence?
        if withSequence {
            seq = ClimbSequence(steps: [
                SequenceStep(limb: .rightFoot, holdID: ordered[0].id),
                SequenceStep(limb: .leftHand, holdID: ordered[1].id),
                SequenceStep(limb: .leftFoot, holdID: ordered[0].id),
                SequenceStep(limb: .rightHand, holdID: ordered[2].id),
                SequenceStep(limb: .rightFoot, holdID: ordered[1].id),
                SequenceStep(limb: .leftHand, holdID: ordered[3].id),
                SequenceStep(limb: .leftFoot, holdID: ordered[2].id),
                SequenceStep(limb: .rightHand, holdID: ordered[4].id),
                SequenceStep(limb: .leftHand, holdID: ordered[5].id),
                SequenceStep(limb: .rightHand, holdID: ordered[6].id),
            ])
        }
        return ShareCardModel(
            name: withPhoto ? "斜板墙 · 蓝" : "角落那条黄的",
            areaName: withPhoto ? "斜板墙" : nil,
            gradeText: "V3",
            status: .projecting,
            cycle: 1,
            visitCount: 3,
            totalAttempts: 13,
            reminderText: reminder,
            reminderVerified: false,
            holds: withPhoto ? holds : [],
            startHoldIDs: [ordered[0].id],
            finishHoldID: ordered[6].id,
            aspect: 0.75,
            actualSequence: seq,
            createdAt: Calendar.current.date(byAdding: .day, value: -12, to: .now)!,
            lastVisit: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
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

#Preview("分享图 · 有照片 + 顺序") {
    let model = ShareCardModel.demo()
    ScrollView {
        ShareCardView(model: model, image: ShareCardModel.demoWallImage(holds: model.holds), profile: .default)
            .scaleEffect(0.7, anchor: .top)
            .frame(width: 540 * 0.7, height: 960 * 0.7)
    }
    .background(Color.black)
}

#Preview("分享图 · 无照片") {
    let model = ShareCardModel.demo(withPhoto: false, withSequence: false, reminder: nil)
    ShareCardView(model: model, image: nil, profile: .default)
        .scaleEffect(0.7, anchor: .top)
        .frame(width: 540 * 0.7, height: 960 * 0.7)
        .background(Color.black)
}
#endif
