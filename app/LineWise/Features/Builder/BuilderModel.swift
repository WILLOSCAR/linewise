import Foundation
import SwiftUI
import UIKit

/// 建线流程里跨屏共享的草稿：照片、点、难度、墙区、角度。
@Observable
@MainActor
final class BuilderModel {
    /// 已降采样（长边 ≤ 2048）的照片，直接给 `SpotlightImage` 用。
    private(set) var image: UIImage?
    private(set) var aspect: Double = 0.75
    /// 非空表示复用已有墙的照片，不新建 Wall。
    private(set) var existingWall: Wall?
    /// 照片选定的时间；用于统计建线时长。
    private(set) var photoSelectedAt: Date?

    var draft = LightUpDraft() { didSet { resumeSegmentation() } }
    let segmentation: HoldSegmentationSession
    let modelManager: HoldModelManager
    var gradeText: String = ""
    var gradeSource: GradeSource?
    var areaName: String = ""
    var angle: WallAngle = .unknown
    /// 无照片建线时的“颜色 / 标签”文字，作为线名。
    var labelText: String = ""

    @ObservationIgnored private var ocrTask: Task<Void, Never>?

    init(areaName: String? = nil, segmenter: (any HoldPointSegmenting)? = nil, modelManager: HoldModelManager? = nil) {
        self.areaName = areaName ?? ""
        self.segmentation = HoldSegmentationSession(segmenter: segmenter ?? SAMPointSegmenter())
        self.modelManager = modelManager ?? .shared
    }

    var hasPhoto: Bool { image != nil }
    var gradeIsAuto: Bool { gradeSource == .ocr && !gradeText.isEmpty }

    // MARK: 照片

    /// 新照片（相机 / 相册）：降采样后作为新墙。
    func setNewPhoto(_ raw: UIImage) {
        let small = ImageStore.downsample(raw, maxLongEdge: ImageStore.maxLongEdge)
        apply(image: small, aspect: small.size.height > 0 ? Double(small.size.width / small.size.height) : 0.75, wall: nil)
        startOCR(on: small)
    }

    /// 复用已有墙：不新建 Wall，也不跑 OCR（难度来自用户）。
    func useExistingWall(_ wall: Wall, image: UIImage?) {
        apply(image: image, aspect: wall.aspectRatio, wall: wall)
        if let area = wall.areaName, !area.isEmpty { areaName = area }
        angle = wall.angle
    }

    func clearPhoto() {
        ocrTask?.cancel()
        ocrTask = nil
        image = nil
        existingWall = nil
        photoSelectedAt = nil
        segmentation.configure(image: nil)
        draft = LightUpDraft()
        if gradeSource == .ocr {
            gradeText = ""
            gradeSource = nil
        }
    }

    private func apply(image: UIImage?, aspect: Double, wall: Wall?) {
        ocrTask?.cancel()
        self.image = image
        self.aspect = max(aspect, 0.05)
        self.existingWall = wall
        self.photoSelectedAt = .now
        self.segmentation.configure(image: image?.cgImage)
        self.draft = LightUpDraft()
    }

    func resumeSegmentation() {
        guard modelManager.state == .ready, let directory = modelManager.directory else { return }
        segmentation.submit(holds: draft.holds, directory: directory) { [weak self] expected, suggestion in
            guard let self else { return false }
            return self.draft.applyContour(suggestion.contour, anchor: suggestion.anchor,
                                          version: suggestion.modelVersion, to: expected)
        }
    }

    func retrySegmentation(id: UUID? = nil) {
        segmentation.retry(id: id)
        if let id { draft.preferCircle(id: id, false) }
        resumeSegmentation()
    }

    func preferCircle(id: UUID) { draft.preferCircle(id: id, true) }

    // MARK: 难度

    private func startOCR(on image: UIImage) {
        ocrTask = Task { @MainActor [weak self] in
            let found = await GradeOCR.recognizeGrade(in: image)
            guard !Task.isCancelled, let self, let found else { return }
            // 用户已经手动填过就不覆盖
            guard self.gradeSource != .manual, self.gradeText.isEmpty else { return }
            withAnimation(.snappy) {
                self.gradeText = found
                self.gradeSource = .ocr
            }
        }
    }

    func setGradeManually(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        gradeText = trimmed
        gradeSource = trimmed.isEmpty ? nil : .manual
    }

    // MARK: 时长

    /// 从照片选定到“完成”的秒数；没有照片时为 nil。
    var buildSeconds: Double? {
        photoSelectedAt.map { Date.now.timeIntervalSince($0) }
    }
}

/// 建线时长统计：追加到 UserDefaults 的 `buildDurations`（设置页会读）。
enum BuildMetrics {
    static let key = "buildDurations"

    static func record(seconds: Double, defaults: UserDefaults = .standard) {
        guard seconds.isFinite, seconds >= 0 else { return }
        var list = defaults.array(forKey: key) as? [Double] ?? []
        list.append((seconds * 10).rounded() / 10)
        if list.count > 500 { list.removeFirst(list.count - 500) }
        defaults.set(list, forKey: key)
    }
}

/// 难度快捷选项。
enum GradePresets {
    static let vScale: [String] = (0...10).map { "V\($0)" }
    static let font: [String] = ["5", "5+", "6A", "6A+", "6B", "6B+", "6C", "6C+", "7A"]
}
