import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LineWise

@Suite("分享图 · 快照抽样")
struct ShareSnapshotBuilderTests {
    @Test("实际顺序分享保留首尾和原始步号，末端对准最后一步岩点")
    func actualSequenceSnapshots() throws {
        let model = ShareCardModel.demo()
        let steps = (0..<12).map { i in SequenceStep(limb: .leftHand, holdID: model.holds[i % model.holds.count].id) }
        let sequence = ClimbSequence(steps: steps)
        let snaps = ShareSnapshotBuilder.sequenceSnapshots(holds: model.holds, startHoldIDs: model.startHoldIDs,
                                                          sequence: sequence, aspect: model.aspect, profile: .default)
        #expect(snaps.count == 8)
        #expect(snaps.first?.stepIndex == 0)
        let last = try #require(snaps.last)
        #expect(last.stepIndex == 11)
        let target = try #require(model.holds.first { $0.id == steps[11].holdID })
        #expect(abs(last.pose.leftHand.x - target.x * model.aspect) < 0.001)
        #expect(abs(last.pose.leftHand.y - target.y) < 0.001)
        #expect(ShareSnapshotBuilder.sequenceSnapshots(holds: [], startHoldIDs: [], sequence: sequence,
                                                     aspect: 0.75, profile: .default).isEmpty)
    }

    @Test("不超过上限时全部保留")
    func keepsAllWhenSmall() {
        #expect(ShareSnapshotBuilder.sampleIndices(count: 5, max: 8) == [0, 1, 2, 3, 4])
        #expect(ShareSnapshotBuilder.sampleIndices(count: 8, max: 8) == Array(0..<8))
        #expect(ShareSnapshotBuilder.sampleIndices(count: 0, max: 8).isEmpty)
    }

    @Test("超过上限时等距抽样，首尾保留，严格递增")
    func samplesEvenly() {
        let idx = ShareSnapshotBuilder.sampleIndices(count: 20, max: 8)
        #expect(idx.count == 8)
        #expect(idx.first == 0)
        #expect(idx.last == 19)
        #expect(zip(idx, idx.dropFirst()).allSatisfy { $0 < $1 })
        #expect(ShareSnapshotBuilder.sampleIndices(count: 9, max: 8).count == 8)
        #expect(ShareSnapshotBuilder.sampleIndices(count: 3, max: 1) == [2])
    }

    @Test("12 次记录 → 8 格，按日期升序，首尾保留")
    func snapshotsFromVisits() {
        let model = ShareCardModel.demo(visitCount: 12)
        let snaps = ShareSnapshotBuilder.snapshots(visits: model.visits.shuffled())
        #expect(snaps.count == 8)
        #expect(snaps.first?.visit.date == model.visits.first?.date)
        #expect(snaps.last?.visit.date == model.visits.last?.date)
        #expect(zip(snaps, snaps.dropFirst()).allSatisfy { $0.visit.date < $1.visit.date })
        #expect(snaps.first?.visitNumber == 1)
        #expect(snaps.last?.visitNumber == 12)
    }

    @Test("空记录会被过滤；没有记录为空")
    func filtersEmptyVisits() {
        let empty = ShareVisit(date: .now, attemptCount: 0)
        let real = ShareVisit(date: .now, attemptCount: 2)
        #expect(ShareSnapshotBuilder.snapshots(visits: [empty, real]).count == 1)
        #expect(ShareSnapshotBuilder.snapshots(visits: []).isEmpty)
    }

    @Test("每格小字：次数 · 掉在 / 上了")
    func captions() {
        let id = UUID()
        let label: (UUID?) -> String? = { $0 == id ? "⑤" : nil }
        #expect(ShareSnapshotBuilder.caption(for: ShareVisit(date: .now, attemptCount: 5, fallHoldID: id), label: label) == "5 次 · 掉在 ⑤")
        #expect(ShareSnapshotBuilder.caption(for: ShareVisit(date: .now, attemptCount: 2, sent: true), label: label) == "2 次 · 上了")
        #expect(ShareSnapshotBuilder.caption(for: ShareVisit(date: .now, attemptCount: 0, fallText: "第三个点"), label: label) == "掉在 第三个点")
        #expect(ShareSnapshotBuilder.caption(for: ShareVisit(date: .now, attemptCount: 0), label: label) == "")
    }

    @Test("掉落标记：同点累加，最近的 recency 为 1")
    func fallMarks() {
        let a = UUID(), b = UUID()
        let cal = Calendar.current
        let d0 = cal.startOfDay(for: .now)
        let visits = [
            ShareVisit(date: cal.date(byAdding: .day, value: -4, to: d0)!, attemptCount: 3, fallHoldID: a),
            ShareVisit(date: cal.date(byAdding: .day, value: -2, to: d0)!, attemptCount: 3, fallHoldID: a),
            ShareVisit(date: d0, attemptCount: 1, fallHoldID: b),
        ]
        let marks = ShareSnapshotBuilder.fallMarks(visits: visits)
        #expect(marks.count == 2)
        let ma = marks.first { $0.holdID == a }
        let mb = marks.first { $0.holdID == b }
        #expect(ma?.count == 2)
        #expect(mb?.count == 1)
        #expect(mb?.recency == 1)
        #expect((ma?.recency ?? 1) < 1)
    }
}

@Suite("分享图 · 取景与版式")
struct ShareCardLayoutTests {
    @Test("填满取景：关注区域宽高比与视图一致，且在 0…1 内")
    func fillingFocusMatchesView() throws {
        let holds = ShareCardModel.demo().holds
        let view = CGSize(width: 540, height: 600)
        let f = try #require(SpotlightGeometry.fillingFocusRect(for: holds, aspect: 0.75, viewSize: view))
        #expect(f.minX >= 0 && f.minY >= 0 && f.maxX <= 1.000001 && f.maxY <= 1.000001)
        let geo = SpotlightGeometry(size: view, aspect: 0.75, fill: true, focus: f)
        // 图至少盖满视图（允许照片本身不够大时露边）
        #expect(geo.rect.width >= view.width - 0.5 || f.width >= 0.999)
        #expect(geo.rect.height >= view.height - 0.5 || f.height >= 0.999)
        #expect(SpotlightGeometry.fillingFocusRect(for: [], aspect: 0.75, viewSize: view) == nil)
    }

    @Test("默认内容下图约占 62%；无内容时封顶；8 格时每格 54pt")
    func artworkHeights() {
        let typical = ShareCardLayout(snapshotCount: 3, reminder: "掉在 ⑤ · 脚 · 左手抓到就要顶髌")
        let ratio = typical.artworkHeight / ShareCardLayout.size.height
        #expect(ratio > 0.58 && ratio < 0.68)
        #expect(typical.reminderLines == 1)
        #expect(ShareCardLayout(snapshotCount: 3, reminder: String(repeating: "很", count: 30)).reminderLines == 2)
        #expect(typical.cellSize == CGSize(width: 72, height: 96))

        let bare = ShareCardLayout(snapshotCount: 0, reminder: nil)
        #expect(bare.artworkHeight == ShareCardLayout.maxArtworkHeight)
        #expect(bare.reminderLines == 0)

        let full = ShareCardLayout(snapshotCount: 8, reminder: "脚")
        #expect(full.cellSize.width == 54)
        #expect(full.reminderLines == 1)
        #expect(full.artworkHeight >= ShareCardLayout.minArtworkHeight)
        #expect(full.artworkHeight + full.textBlockHeight <= ShareCardLayout.size.height + 0.5 || full.artworkHeight == ShareCardLayout.minArtworkHeight)
    }
}

@Suite("分享图 · 文案")
struct ShareCardModelTests {
    @Test("标题、副标题与次数行")
    func texts() {
        var m = ShareCardModel.demo()
        #expect(m.titleText == "斜板墙 · V3")
        #expect(m.subtitleText == "V3") // 线名里已有“斜板墙”
        #expect(m.visitText == "来了 3 次 · 共 15 次尝试")
        #expect(m.shareTitle == "斜板墙 · V3 · 进行中 · 线感")
        m.name = "角落那条"
        #expect(m.subtitleText == "斜板墙 · V3")
        m.areaName = nil
        m.gradeText = nil
        #expect(m.titleText == m.name)
        #expect(m.subtitleText == "")
        m.visits = []
        #expect(m.visitText == "还没有记录")
        #expect(m.lastVisit == nil)
    }

    @Test("从 Line 抽出快照")
    @MainActor
    func fromLine() throws {
        let f = try StoreFixture()
        let (_, wall, line) = try f.makeLine(holdCount: 4)
        wall.imageWidth = 1536
        wall.imageHeight = 2048
        let s = f.store.newSession(for: line, date: f.daysAgo(2))
        s.attemptCount = 5
        s.reason = .feet
        s.fallHoldID = HoldNumbering.ordered(line.holds)[1].id
        f.store.commitSession(s, line: line, fallLabel: line.label(for: s.fallHoldID))
        _ = f.store.incrementAttempt(line)
        line.actualSequence = ClimbSequence(steps: [SequenceStep(limb: .leftHand, holdID: line.holds[2].id)])
        let m = ShareCardModel(line: line)
        #expect(m.actualSequence == line.actualSequence)
        #expect(m.areaName == "斜板墙")
        #expect(m.gradeText == "V3")
        #expect(m.visitCount == 2)
        #expect(m.totalAttempts == 6)
        #expect(m.reminderText == "掉在 ② · 脚")
        #expect(m.holds.count == 4)
        #expect(m.aspect == 0.75)
        #expect(m.lastVisit == Calendar.current.startOfDay(for: .now))
        #expect(m.fallMarks.count == 1)
        #expect(m.label(for: s.fallHoldID) == "②")
    }
}

@MainActor
@Suite("分享图 · 渲染")
struct ShareCardRenderTests {
    @Test("分享关闭实际顺序后重新渲染，恢复后位图与原图一致")
    func togglingSequenceSnapshots() throws {
        var model = ShareCardModel.demo()
        model.actualSequence = ClimbSequence(steps: [
            SequenceStep(limb: .leftHand, holdID: model.holds[2].id),
            SequenceStep(limb: .rightHand, holdID: model.holds[3].id)
        ])
        let photo = ShareCardModel.demoWallImage(holds: model.holds)
        let with = try #require(ShareCardRenderer.render(model: model, image: photo, includesSnapshots: true))
        let without = try #require(ShareCardRenderer.render(model: model, image: photo, includesSnapshots: false))
        let restored = try #require(ShareCardRenderer.render(model: model, image: photo, includesSnapshots: true))
        expect1080x1920(with)
        expect1080x1920(without)
        #expect(with.pngData() != without.pngData())
        #expect(with.pngData() == restored.pngData())
    }

    private func write(_ image: UIImage, to path: String) throws {
        let data = try #require(image.pngData())
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func expect1080x1920(_ image: UIImage) {
        #expect(Int(image.size.width * image.scale) == 1080)
        #expect(Int(image.size.height * image.scale) == 1920)
    }

    @Test("有照片 + 提醒 + 3 格 → 1080×1920，写到 /tmp/share-card.png")
    func renderFullCard() throws {
        let model = ShareCardModel.demo()
        let photo = ShareCardModel.demoWallImage(holds: model.holds)
        let image = try #require(ShareCardRenderer.render(model: model, image: photo))
        expect1080x1920(image)
        try write(image, to: "/tmp/share-card.png")
    }

    @Test("12 次 → 8 格 + 上了 → /tmp/share-card-8.png")
    func renderEightCells() throws {
        var model = ShareCardModel.demo(visitCount: 12)
        model.status = .sent
        model.visits[model.visits.count - 1].sent = true
        model.visits[model.visits.count - 1].fallHoldID = nil
        let photo = ShareCardModel.demoWallImage(holds: model.holds)
        let image = try #require(ShareCardRenderer.render(model: model, image: photo))
        expect1080x1920(image)
        try write(image, to: "/tmp/share-card-8.png")
    }

    @Test("在内存容器里造一条演示线并渲染 → /tmp/share-card-line.png")
    func renderFromStoredLine() throws {
        let f = try StoreFixture()
        let (_, wall, line) = try f.makeLine(holdCount: 7, area: "仰角墙", grade: "V4", name: "仰角墙 · 紫")
        wall.imageWidth = 900
        wall.imageHeight = 1200
        let ordered = HoldNumbering.ordered(line.holds)
        let s1 = f.store.newSession(for: line, date: f.daysAgo(6))
        s1.attemptCount = 5
        s1.fallHoldID = ordered[3].id
        s1.reason = .power
        s1.note = "翻身前先休息"
        f.store.commitSession(s1, line: line, fallLabel: line.label(for: s1.fallHoldID))
        let s2 = f.store.newSession(for: line, date: f.daysAgo(1))
        s2.attemptCount = 3
        f.store.commitSession(s2, line: line, fallLabel: nil)
        _ = f.store.apply(.markSent, to: line)
        _ = f.store.apply(.newCycle, to: line)
        f.store.save()

        let photo = ShareCardModel.demoWallImage(holds: line.holds)
        let image = try #require(ShareCardRenderer.render(line: line, image: photo))
        expect1080x1920(image)
        try write(image, to: "/tmp/share-card-line.png")
    }

    @Test("无照片、无点位的线 → 底板 + 难度，/tmp/share-card-nophoto.png")
    func renderNoPhoto() throws {
        let model = ShareCardModel.demo(withPhoto: false, visitCount: 2, reminder: "掉在第三个点 · 没力")
        let image = try #require(ShareCardRenderer.render(model: model, image: nil))
        expect1080x1920(image)
        try write(image, to: "/tmp/share-card-nophoto.png")
    }

    @Test("有点位但照片丢了 → 底板 + 点位示意，不崩")
    func renderHoldsWithoutPhoto() throws {
        let model = ShareCardModel.demo()
        let image = try #require(ShareCardRenderer.render(model: model, image: nil))
        expect1080x1920(image)
    }

    @Test("横向照片也能装下 → /tmp/share-card-landscape.png")
    func renderLandscape() throws {
        var model = ShareCardModel.demo(visitCount: 0, reminder: nil)
        model.aspect = 4.0 / 3.0
        model.status = .sent
        model.cycle = 2
        model.reminderVerified = true
        let photo = ShareCardModel.demoWallImage(holds: model.holds, size: CGSize(width: 1200, height: 900))
        let image = try #require(ShareCardRenderer.render(model: model, image: photo))
        expect1080x1920(image)
        try write(image, to: "/tmp/share-card-landscape.png")
    }

    @Test("预览缩放：宽优先，装进可用区域")
    func previewScale() {
        let s = SharePreviewSheet.cardScale(in: CGSize(width: 362, height: 700))
        #expect(abs(s - 362.0 / 540.0) < 1e-9)
        let tall = SharePreviewSheet.cardScale(in: CGSize(width: 362, height: 300))
        #expect(abs(tall - 300.0 / 960.0) < 1e-9)
    }
}
