import Foundation
import Observation

@MainActor
@Observable
final class HoldModelManager {
    enum State: Equatable {
        case checking, notDownloaded, downloading(Double), cancelling, ready, failed
    }

    static let shared: HoldModelManager = {
        #if DEBUG
        if CommandLine.arguments.contains("-uiTesting") {
            // UI tests must not depend on or modify a developer's installed model cache.
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("UITestModels-" + UUID().uuidString)
            return HoldModelManager(downloader: SAMModelDownloader(root: root))
        }
        #endif
        return HoldModelManager()
    }()
    private(set) var state: State = .checking
    private(set) var directory: URL?
    @ObservationIgnored private let downloader: SAMModelDownloader
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    init(downloader: SAMModelDownloader = SAMModelDownloader()) {
        self.downloader = downloader
        Task { [weak self] in
            guard let self else { return }
            self.directory = try? await downloader.installedDirectory()
            self.state = self.directory == nil ? .notDownloaded : .ready
        }
    }

    func download() {
        guard downloadTask == nil, state != .ready, state != .checking else { return }
        state = .downloading(0)
        let request = UUID()
        requestID = request
        downloadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.downloadTask = nil }
            do {
                let directory = try await downloader.install { [weak self] progress in
                    Task { @MainActor in
                        guard let self, self.requestID == request, case .downloading = self.state else { return }
                        self.state = .downloading(progress)
                    }
                }
                try Task.checkCancellation()
                self.directory = directory
                self.state = .ready
            } catch {
                self.state = Task.isCancelled ? .notDownloaded : .failed
            }
        }
    }

    func cancel() {
        guard downloadTask != nil else { return }
        state = .cancelling
        downloadTask?.cancel()
    }
}
