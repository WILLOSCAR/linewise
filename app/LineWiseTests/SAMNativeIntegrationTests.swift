import Foundation
import Testing
import UIKit
@testable import LineWise

/// Optional local fixture test: private images/coordinates/weights are never bundled or checked in.
@Suite("Demo A · 原生 Tiny 集成", .serialized)
struct SAMNativeIntegrationTests {
    private static var repository: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private static var support: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }
    private static var fixtures: URL {
        #if targetEnvironment(simulator)
        return repository.appendingPathComponent(".scratch/hold-seg-proto/input")
        #else
        return support.appendingPathComponent("HoldIntegrationFixtures")
        #endif
    }
    private static var models: URL {
        #if targetEnvironment(simulator)
        return repository.appendingPathComponent(".scratch/models/coreml-sam2.1-tiny")
        #else
        return support.appendingPathComponent("HoldModels/" + SAMModelCatalog.tiny.version)
        #endif
    }
    private static var supportsNativeFixture: Bool {
        #if targetEnvironment(simulator)
        // Actual runs on iOS Simulator 26.5 returned zero decoder masks. See the implementation log.
        return false
        #else
        return FileManager.default.fileExists(atPath: fixtures.appendingPathComponent("real-cases.json").path) &&
               FileManager.default.fileExists(atPath: models.path)
        #endif
    }
    private struct Fixture: Decodable {
        let image: String
        let taps: [Tap]
        struct Tap: Decodable { let x: Double, y: Double, r: Double }
    }

    @Test("私有墙照实际运行编码、点提示与轮廓；打印聚合时长",
          .enabled(if: supportsNativeFixture, "Requires private device fixtures; Simulator decoder compatibility is unresolved"))
    func realTinyInference() async throws {
        let cases = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: Self.fixtures.appendingPathComponent("real-cases.json")))
        let segmenter = SAMPointSegmenter()
        var previousImage: String?, photoID = UUID()
        var total = 0, accepted = 0, times: [Double] = [], encodings: [Double] = []
        for fixture in cases {
            if previousImage != fixture.image {
                let image = try #require(UIImage(contentsOfFile: Self.fixtures.appendingPathComponent(fixture.image).path)?.cgImage)
                photoID = UUID()
                encodings.append(try await segmenter.prepare(image: image, photoID: photoID, directory: Self.models) { _ in })
                previousImage = fixture.image
            }
            var caseAccepted = 0
            for tap in fixture.taps {
                let start = CFAbsoluteTimeGetCurrent()
                let hold = Hold(x: tap.x, y: tap.y, r: tap.r)
                if let result = try await segmenter.segment(hold, photoID: photoID) {
                    #expect(result.contour.points.count <= 64)
                    #expect(result.contour.contains(.init(x: hold.x, y: hold.y)))
                    #expect(result.contour.contains(result.anchor))
                    caseAccepted += 1; accepted += 1
                }
                times.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
                total += 1
            }
            #expect(caseAccepted > 0, "The fixture must produce a valid native contour")
        }
        let sorted = times.sorted()
        print("SAM_TINY_NATIVE total=\(total) accepted=\(accepted) encodingSeconds=\(encodings) pointMedianMs=\(sorted[sorted.count / 2]) pointMaxMs=\(sorted.last ?? 0)")
        // Candidate acceptance is a robustness check, not ground-truth accuracy or an iPhone performance gate.
    }
}
