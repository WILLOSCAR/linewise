import CoreGraphics
import Foundation

protocol HoldPointSegmenting: Sendable {
    func prepare(image: CGImage, photoID: UUID, directory: URL,
                 progress: @escaping @Sendable (Double) -> Void) async throws -> Double
    func segment(_ hold: Hold, photoID: UUID) async throws -> HoldSegmentationResult?
}
