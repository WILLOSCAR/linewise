import CryptoKit
import Foundation
import SwiftData
import Testing
import UIKit
@testable import LineWise

private actor FixtureTransport: ModelDownloadTransport {
    let contents: [String: Data]
    var failure: String?
    var delayed: Bool
    private(set) var requests: [String] = []
    init(_ contents: [String: Data], failure: String? = nil, delayed: Bool = false) {
        self.contents = contents; self.failure = failure; self.delayed = delayed
    }
    func download(_ url: URL, progress: @escaping @Sendable (Int64) -> Void) async throws -> URL {
        let name = url.lastPathComponent
        requests.append(name)
        if failure == name { failure = nil; throw URLError(.networkConnectionLost) }
        if delayed { try await Task.sleep(for: .milliseconds(100)) }
        let data = contents[name] ?? Data()
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: temp)
        progress(Int64(data.count))
        return temp
    }
}

@Suite("Demo A · 下载完整性")
struct SAMDownloadTests {
    private func catalog(_ data: [String: Data]) -> SAMModelCatalog {
        SAMModelCatalog(revision: "fixture", files: data.keys.sorted().map { key in
            .init(path: key, bytes: Int64(data[key]!.count),
                  sha256: SHA256.hash(data: data[key]!).map { String(format: "%02x", $0) }.joined())
        })
    }
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    @Test("中断后重试复用已验证文件，完成后离线读取")
    func interruptedRetry() async throws {
        let data = ["a.bin": Data("encoder".utf8), "b.bin": Data("decoder".utf8)]
        let transport = FixtureTransport(data, failure: "b.bin"), root = root()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloader = SAMModelDownloader(catalog: catalog(data), root: root, transport: transport)
        do { _ = try await downloader.install { _ in }; Issue.record("Expected interrupted download") } catch {}
        #expect(try await downloader.installedDirectory() == nil)
        let installed = try await downloader.install { _ in }
        #expect(try await downloader.installedDirectory() == installed)
        #expect(await transport.requests == ["a.bin", "b.bin", "b.bin"])
        _ = try await downloader.install { _ in }
        #expect(await transport.requests.count == 3)
    }

    @Test("长度正确但校验失败也不能作为已下载模型")
    func corruptedDownload() async throws {
        let expected = ["a.bin": Data("model".utf8)], root = root()
        defer { try? FileManager.default.removeItem(at: root) }
        let downloader = SAMModelDownloader(catalog: catalog(expected), root: root,
                                             transport: FixtureTransport(["a.bin": Data("wrong".utf8)]))
        do { _ = try await downloader.install { _ in }; Issue.record("Expected integrity failure") } catch {}
        #expect(try await downloader.installedDirectory() == nil)
    }

    @Test("取消不会暴露部分模型；路径逃逸和超限目录被拒绝")
    func cancelledAndInvalid() async throws {
        let data = ["a.bin": Data("model".utf8)], root = root(), transport = FixtureTransport(data, delayed: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let downloader = SAMModelDownloader(catalog: catalog(data), root: root, transport: transport)
        let task = Task { try await downloader.install { _ in } }
        while await transport.requests.isEmpty { await Task.yield() }
        task.cancel()
        do { _ = try await task.value; Issue.record("Expected cancellation") } catch {}
        #expect(try await downloader.installedDirectory() == nil)
        for file in [SAMModelFile(path: "../escape", bytes: 5, sha256: String(repeating: "0", count: 64)),
                     SAMModelFile(path: "oversized", bytes: 100_000_001, sha256: String(repeating: "0", count: 64))] {
            let invalid = SAMModelDownloader(catalog: .init(revision: "fixture", files: [file]), root: root,
                                              transport: transport)
            do { _ = try await invalid.install { _ in }; Issue.record("Expected catalog rejection") } catch {}
        }
        #expect(await transport.requests.count == 1)
    }
}

private actor PausedSegmenter: HoldPointSegmenting {
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }
    private(set) var preparations = 0
    private(set) var calls = 0
    private var continuation: CheckedContinuation<HoldSegmentationResult?, Never>?
    func prepare(image: CGImage, photoID: UUID, directory: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> Double {
        preparations += 1; progress(1); return 0.1
    }
    func segment(_ hold: Hold, photoID: UUID) async throws -> HoldSegmentationResult? {
        calls += 1
        if fails { throw SAMInferenceError.modelInterface }
        return await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        let contour = HoldContour(points: [.init(x: 0.4, y: 0.4), .init(x: 0.6, y: 0.4),
                                            .init(x: 0.6, y: 0.6), .init(x: 0.4, y: 0.6)])!
        continuation?.resume(returning: .init(contour: contour, anchor: .init(x: 0.5, y: 0.5), modelVersion: "fixture", seconds: 0.01))
        continuation = nil
    }
}

@MainActor
@Suite("Demo A · 照片任务与旧线转换", .serialized)
struct HoldSegmentationSessionTests {
    private func image() -> CGImage {
        UIGraphicsImageRenderer(size: .init(width: 40, height: 40)).image { ctx in
            UIColor.yellow.setFill(); ctx.fill(.init(x: 0, y: 0, width: 40, height: 40))
        }.cgImage!
    }
    private func wait(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !(await condition()) {
            if Date() > deadline { throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    private var directory: URL { URL(fileURLWithPath: "/unused-fixture") }

    @Test("模型运行失败时保留手动点、结束标记和保存数据")
    func inferenceFailureKeepsDraft() async throws {
        let mock = PausedSegmenter(fails: true), session = HoldSegmentationSession(segmenter: mock)
        var draft = LightUpDraft()
        _ = draft.add(x: 0.5, y: 0.5)
        let original = draft
        session.configure(image: image())
        session.submit(holds: draft.holds, directory: directory) { expected, result in
            draft.applyContour(result.contour, anchor: result.anchor, version: result.modelVersion, to: expected)
        }
        try await wait { session.phase == .failed }
        #expect(draft == original)
        let f = try StoreFixture(), gym = f.store.ensureDefaultGym(), builder = BuilderModel()
        builder.draft = draft
        let line = try f.store.commitBuild(builder, gym: gym)
        #expect(line.holds == original.holds && line.startHoldIDs == original.startHoldIDs)
        session.retry()
        #expect(session.phase == .idle)
    }

    @Test("换照片后旧结果失效，手动圆圈不会被迟到结果覆盖")
    func staleAndManual() async throws {
        let mock = PausedSegmenter(), session = HoldSegmentationSession(segmenter: mock)
        var draft = LightUpDraft(), accepted = 0
        let hold = draft.add(x: 0.5, y: 0.5)
        session.configure(image: image())
        session.submit(holds: draft.holds, directory: directory) { expected, result in
            if draft.applyContour(result.contour, anchor: result.anchor, version: result.modelVersion, to: expected) {
                accepted += 1; return true
            }
            return false
        }
        try await wait { await mock.calls == 1 }
        session.configure(image: image())
        await mock.release()
        try await Task.sleep(for: .milliseconds(25))
        #expect(accepted == 0 && draft.hold(id: hold.id)?.polygon == nil)

        session.submit(holds: draft.holds, directory: directory) { expected, result in
            draft.applyContour(result.contour, anchor: result.anchor, version: result.modelVersion, to: expected)
        }
        try await wait { await mock.calls == 2 }
        draft.preferCircle(id: hold.id, true)
        await mock.release()
        try await wait { session.phase == .idle }
        #expect(draft.hold(id: hold.id)?.prefersCircle == true && draft.hold(id: hold.id)?.polygon == nil)
    }

    @Test("同一照片加点只编码一次；失败候选保留圆圈可再次抠形")
    func cachedPhoto() async throws {
        let mock = PausedSegmenter(), session = HoldSegmentationSession(segmenter: mock)
        session.configure(image: image())
        let first = Hold(x: 0.5, y: 0.5), second = Hold(x: 0.5, y: 0.5)
        session.submit(holds: [first], directory: directory) { _, _ in false }
        try await wait { await mock.calls == 1 }
        await mock.release()
        try await wait { session.phase == .idle }
        session.submit(holds: [first, second], directory: directory) { _, _ in true }
        try await wait { await mock.calls == 2 }
        await mock.release()
        try await wait { session.phase == .idle }
        #expect(await mock.preparations == 1)
        session.retry(id: first.id)
        session.submit(holds: [first], directory: directory) { _, _ in false }
        try await wait { await mock.calls == 3 }
        await mock.release()
        try await wait { session.phase == .idle }
        #expect(await mock.preparations == 1)
    }

    @Test("旧线转换只改几何，撤销恢复圆圈，起步、掉落和顺序仍指向同一 ID")
    func upgradeAndUndo() async throws {
        let f = try StoreFixture(), (_, wall, line) = try f.makeLine(holdCount: 1)
        let hold = Hold(id: line.holds[0].id, x: 0.5, y: 0.5)
        line.holds = [hold]; wall.photoFileName = "synthetic.jpg"
        line.planSequence = .init(steps: [.init(limb: .leftHand, holdID: hold.id)])
        let record = f.store.newSession(for: line, date: .now)
        record.fallHoldID = hold.id; record.reminderSnapshot = "保留原文"
        let originalPlan = line.planSequenceData, start = line.startHoldIDs
        let mock = PausedSegmenter(), upgrade = LineContourUpgrade(segmenter: mock), undo = UndoCenter()
        upgrade.begin(line: line, image: image(), directory: directory, store: f.store, undoCenter: undo)
        try await wait { await mock.calls == 1 }
        await mock.release()
        try await wait { upgrade.segmentation.phase == .idle }
        #expect(line.holds[0].polygon != nil && line.holds[0].id == hold.id)
        #expect(line.startHoldIDs == start && line.planSequenceData == originalPlan)
        #expect(record.fallHoldID == hold.id && record.reminderSnapshot == "保留原文")
        undo.performUndo()
        #expect(line.holds == [hold] && wall.segmentationVersion == nil)
        #expect(line.startHoldIDs == start && line.planSequenceData == originalPlan)
    }
}

@Suite("Demo A · 遮罩到轮廓")
struct SAMMaskContourTests {
    @Test("只取点击所在连通区域，远处同色区域不合并，轮廓保持 ≤64 顶点")
    func componentAndLimit() throws {
        var logits = [Float](repeating: -10, count: 100 * 100)
        for y in 45..<55 { for x in 45..<55 { logits[y * 100 + x] = 10 } }
        for y in 20..<30 { for x in 20..<30 { logits[y * 100 + x] = 10 } }
        let candidate = try SAMMaskContour.extract(logits: logits, logitsWidth: 100, logitsHeight: 100,
                                                   width: 100, height: 100, hold: .init(x: 0.5, y: 0.5, r: 0.05))
        let result = try #require(candidate)
        #expect(result.pixelArea == 100 && result.contour.points.count <= 64)
        #expect(result.contour.contains(.init(x: 0.5, y: 0.5)))
        #expect(!result.contour.contains(.init(x: 0.25, y: 0.25)))
        #expect(result.contour.contains(result.anchor))
    }

    @Test("背景点或占据全墙的遮罩降级为圆圈")
    func rejectedMasks() throws {
        for value: Float in [-10, 10] {
            #expect(try SAMMaskContour.extract(logits: Array(repeating: value, count: 10000),
                                               logitsWidth: 100, logitsHeight: 100, width: 100, height: 100,
                                               hold: .init(x: 0.5, y: 0.5)) == nil)
        }
    }
}
