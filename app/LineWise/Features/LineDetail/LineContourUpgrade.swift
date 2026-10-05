import Observation
import UIKit

/// An explicit conversion of saved circles. Hold IDs and all climbing records stay intact.
@MainActor
@Observable
final class LineContourUpgrade {
    let segmentation: HoldSegmentationSession
    private(set) var loadingPhoto = false
    private(set) var photoUnavailable = false
    private(set) var convertedCount = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    init(segmenter: any HoldPointSegmenting = SAMPointSegmenter()) {
        segmentation = HoldSegmentationSession(segmenter: segmenter)
    }

    var isRunning: Bool {
        if loadingPhoto { return true }
        switch segmentation.phase {
        case .preparing, .processing: return true
        default: return false
        }
    }

    func start(line: Line, directory: URL, store: Store, undoCenter: UndoCenter) {
        cancel()
        guard let photo = line.wall?.photoFileName else { return }
        let token = UUID()
        requestID = token
        loadingPhoto = true
        photoUnavailable = false
        loadTask = Task { [weak self] in
            let image = await ImageStore.loadAsync(fileName: photo, maxPixel: 2048)
            guard let self, !Task.isCancelled, self.requestID == token else { return }
            self.loadingPhoto = false
            self.loadTask = nil
            guard line.wall?.photoFileName == photo, line.isVisible else { return }
            guard let image = image?.cgImage else { self.photoUnavailable = true; return }
            self.begin(line: line, image: image, directory: directory, store: store, undoCenter: undoCenter)
        }
    }

    func begin(line: Line, image: CGImage, directory: URL, store: Store, undoCenter: UndoCenter) {
        let photo = line.wall?.photoFileName
        let wallVersion = line.wall?.segmentationVersion
        var changes: [UUID: (before: Hold, after: Hold)] = [:]
        convertedCount = 0
        segmentation.configure(image: image)
        segmentation.submit(holds: line.holds, directory: directory) { [weak self] expected, result in
            guard let self, line.isVisible, line.wall?.photoFileName == photo,
                  let index = line.holds.firstIndex(where: { $0.id == expected.id }),
                  line.holds[index] == expected, !expected.prefersCircle else { return false }
            var updated = expected
            updated.polygon = result.contour.points
            updated.anchor = result.anchor
            updated.segmentationVersion = result.modelVersion
            var holds = line.holds
            holds[index] = updated
            line.holds = holds
            line.wall?.segmentationVersion = result.modelVersion
            store.touch(line)
            changes[expected.id] = (expected, updated)
            self.convertedCount = changes.count
            let snapshot = changes
            undoCenter.offer("已换成岩点轮廓") { [weak self] in
                self?.cancel()
                guard line.isVisible, line.wall?.photoFileName == photo else { return }
                var current = line.holds
                for (id, change) in snapshot {
                    if let i = current.firstIndex(where: { $0.id == id }), current[i] == change.after {
                        current[i] = change.before
                    }
                }
                line.holds = current
                if !(line.wall?.lines.contains { $0.holds.contains { $0.segmentationVersion != nil } } ?? false) {
                    line.wall?.segmentationVersion = wallVersion
                }
                self?.convertedCount = 0
                store.touch(line)
            }
            return true
        }
    }

    func cancel() {
        requestID = UUID()
        loadTask?.cancel()
        loadTask = nil
        loadingPhoto = false
        segmentation.cancel()
    }
}
