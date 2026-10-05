import CoreGraphics
import Foundation
import Observation
import SwiftUI

/// A photo-bound queue shared by new-line building and explicit upgrades of saved circles.
@MainActor
@Observable
final class HoldSegmentationSession {
    enum Phase: Equatable { case idle, preparing(Double), processing(completed: Int, total: Int), failed }

    private(set) var phase: Phase = .idle
    private(set) var transitionHoldID: UUID?
    private(set) var contourTransition: Double = 1
    private(set) var encodingSeconds: Double?
    private(set) var pointSeconds: Double?
    @ObservationIgnored private let segmenter: any HoldPointSegmenting
    @ObservationIgnored private var image: CGImage?
    @ObservationIgnored private var photoID = UUID()
    @ObservationIgnored private var prepared = false
    @ObservationIgnored private var candidates: [Hold] = []
    @ObservationIgnored private var attempted: [UUID: Hold] = [:]
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var accept: ((Hold, HoldSegmentationResult) -> Bool)?
    @ObservationIgnored private var completed = 0

    init(segmenter: any HoldPointSegmenting = SAMPointSegmenter()) { self.segmenter = segmenter }

    func configure(image: CGImage?) {
        cancel()
        self.image = image
        photoID = UUID()
        prepared = false
        attempted = [:]
        completed = 0
        transitionHoldID = nil
        contourTransition = 1
        encodingSeconds = nil
        pointSeconds = nil
    }

    func submit(holds: [Hold], directory: URL, accept: @escaping (Hold, HoldSegmentationResult) -> Bool) {
        candidates = holds
        self.accept = accept
        guard task == nil, phase != .failed, let image else { return }
        if prepared && pending.isEmpty { return }
        let token = UUID(), photo = photoID
        generation = token
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == token {
                    task = nil
                    if phase != .failed { phase = .idle }
                }
            }
            do {
                if !prepared {
                    phase = .preparing(0)
                    let duration = try await segmenter.prepare(image: image, photoID: photo, directory: directory) { [weak self] value in
                        Task { @MainActor in
                            guard let self, self.generation == token, case .preparing = self.phase else { return }
                            self.phase = .preparing(value)
                        }
                    }
                    try Task.checkCancellation()
                    guard generation == token else { return }
                    encodingSeconds = duration
                    prepared = true
                }
                while let hold = pending.first {
                    try Task.checkCancellation()
                    guard generation == token else { return }
                    phase = .processing(completed: completed, total: completed + pending.count)
                    attempted[hold.id] = hold
                    let start = CFAbsoluteTimeGetCurrent()
                    let result = try await segmenter.segment(hold, photoID: photo)
                    try Task.checkCancellation()
                    guard generation == token else { return }
                    pointSeconds = CFAbsoluteTimeGetCurrent() - start
                    if let result, self.accept?(hold, result) == true {
                        transitionHoldID = hold.id
                        contourTransition = 0
                        try await Task.sleep(for: .milliseconds(16))
                        guard generation == token else { return }
                        withAnimation(.easeOut(duration: 0.25)) { self.contourTransition = 1 }
                    }
                    completed += 1
                }
            } catch {
                if generation == token && !Task.isCancelled { phase = .failed }
            }
        }
    }

    func retry(id: UUID? = nil) {
        if let id { attempted[id] = nil } else { attempted = [:] }
        if phase == .failed { phase = .idle }
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        candidates = []
        accept = nil
        phase = .idle
    }

    private var pending: [Hold] {
        candidates.filter { !$0.prefersCircle && $0.contour == nil && attempted[$0.id] != $0 }
    }
}
