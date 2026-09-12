import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import LineWise

@Suite("分享图 · 快照抽样")
struct ShareSnapshotBuilderTests {
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

    @Test("按步生成姿态：手脚落在对应点的等比坐标上")
    func posesFollowContacts() {
        let model = ShareCardModel.demo()
        let snaps = ShareSnapshotBuilder.snapshots(
            holds: model.holds, startHoldIDs: model.startHoldIDs, sequence: model.actualSequence,
            aspect: model.aspect, profile: .default
        )
        #expect(snaps.count == 8)
        #expect(snaps.first?.stepNumber == 1)
        #expect(snaps.last?.stepNumber == model.actualSequence!.steps.count)
        // 最后一步：右手到结束点
        let last = snaps.last!
        let finish = model.holds.first { $0.id == model.finishHoldID }!
        #expect(abs(last.pose.rightHand.x - finish.x * model.aspect) < 1e-6)
        #expect(abs(last.pose.rightHand.y - finish.y) < 1e-6)
        // 姿态都在等比空间内
        for s in snaps {
            #expect(s.pose.head.y >= -0.2 && s.pose.head.y <= 1.2)
            #expect(s.pose.leftFoot.y <= ShareSnapshotBuilder.groundY + 1e-6)
        }
    }

    @Test("没有顺序或没有点时为空")
    func emptyCases() {
        let model = ShareCardModel.demo(withSequence: false)
        #expect(ShareSnapshotBuilder.snapshots(holds: model.holds, startHoldIDs: model.startHoldIDs, sequence: nil,
                                               aspect: 0.75, profile: .default).isEmpty)
        #expect(ShareSnapshotBuilder.snapshots(holds: [], startHoldIDs: [], sequence: ClimbSequence(steps: []),
                                               aspect: 0.75, profile: .default).isEmpty)
    }
}

@Suite("分享图 · 文案")
struct ShareCardModelTests {
    @Test("标题与次数行")
    func texts() {
        var m = ShareCardModel.demo()
        #expect(m.titleText == "斜板墙 · V3")
        #expect(m.visitText == "来了 3 次 · 共 13 次尝试")
        #expect(m.shareTitle == "斜板墙 · V3 · 进行中 · 线感")
        m.areaName = nil
        m.gradeText = nil
        #expect(m.titleText == m.name)
        m.visitCount = 0
        #expect(m.visitText == "还没有记录")
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
        f.store.commitSession(s, line: line, fallLabel: nil)
        _ = f.store.incrementAttempt(line)
        let m = ShareCardModel(line: line)
        #expect(m.areaName == "斜板墙")
        #expect(m.gradeText == "V3")
        #expect(m.visitCount == 2)
        #expect(m.totalAttempts == 6)
        #expect(m.reminderText == "脚")
        #expect(m.holds.count == 4)
        #expect(m.aspect == 0.75)
        #expect(m.lastVisit == Calendar.current.startOfDay(for: .now))
    }
}

@MainActor
@Suite("分享图 · 渲染")
struct ShareCardRenderTests {
    private func write(_ image: UIImage, to path: String) throws {
        let data = try #require(image.pngData())
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    @Test("有照片 + 提醒 + 快照带 → 1080×1920，写到 /tmp/share-card.png")
    func renderFullCard() throws {
        let model = ShareCardModel.demo()
        let photo = ShareCardModel.demoWallImage(holds: model.holds)
        let image = try #require(ShareCardRenderer.render(model: model, image: photo, profile: .default))
        #expect(Int(image.size.width * image.scale) == 1080)
        #expect(Int(image.size.height * image.scale) == 1920)
        try write(image, to: "/tmp/share-card.png")
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
        line.actualSequence = ClimbSequence(steps: [
            SequenceStep(limb: .rightFoot, holdID: ordered[0].id),
            SequenceStep(limb: .leftHand, holdID: ordered[1].id),
            SequenceStep(limb: .rightHand, holdID: ordered[2].id),
            SequenceStep(limb: .leftFoot, holdID: ordered[1].id),
            SequenceStep(limb: .leftHand, holdID: ordered[4].id),
        ])
        f.store.save()

        let photo = ShareCardModel.demoWallImage(holds: line.holds)
        let image = try #require(ShareCardRenderer.render(line: line, image: photo, profile: BodyProfile(heightCm: 180, armSpanCm: 190)))
        #expect(Int(image.size.width * image.scale) == 1080)
        #expect(Int(image.size.height * image.scale) == 1920)
        try write(image, to: "/tmp/share-card-line.png")
    }

    @Test("无照片的线 → 暗底 + 线名大字，/tmp/share-card-nophoto.png")
    func renderNoPhoto() throws {
        let model = ShareCardModel.demo(withPhoto: false, withSequence: false, reminder: nil)
        let image = try #require(ShareCardRenderer.render(model: model, image: nil, profile: .default))
        #expect(Int(image.size.width * image.scale) == 1080)
        #expect(Int(image.size.height * image.scale) == 1920)
        try write(image, to: "/tmp/share-card-nophoto.png")
    }

    @Test("横向照片也能装下 → /tmp/share-card-landscape.png")
    func renderLandscape() throws {
        var model = ShareCardModel.demo(withSequence: false)
        model.aspect = 4.0 / 3.0
        model.status = .sent
        model.cycle = 2
        model.reminderVerified = true
        let photo = ShareCardModel.demoWallImage(holds: model.holds, size: CGSize(width: 1200, height: 900))
        let image = try #require(ShareCardRenderer.render(model: model, image: photo, profile: .default))
        #expect(Int(image.size.height * image.scale) == 1920)
        try write(image, to: "/tmp/share-card-landscape.png")
    }
}
