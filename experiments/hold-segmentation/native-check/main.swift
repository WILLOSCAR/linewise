import Foundation
import ImageIO

private struct Fixture: Decodable {
    let image: String
    let taps: [Tap]
    struct Tap: Decodable { let x: Double, y: Double, r: Double }
}

@main
struct NativeSAMCheck {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            throw NSError(domain: "NativeSAMCheck", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Usage: native-check <private-cases.json> <Tiny-models-directory>"])
        }
        let casesURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let models = URL(fileURLWithPath: CommandLine.arguments[2])
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: casesURL))
        guard !fixtures.isEmpty, fixtures.allSatisfy({ !$0.taps.isEmpty }) else {
            throw NSError(domain: "NativeSAMCheck", code: 2)
        }
        let segmenter = SAMPointSegmenter()
        var previousImage: String?, photoID = UUID()
        var total = 0, accepted = 0, times: [Double] = [], encodings: [Double] = []
        for fixture in fixtures {
            if previousImage != fixture.image {
                let sourceURL = casesURL.deletingLastPathComponent().appendingPathComponent(fixture.image)
                guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 2048
                      ] as CFDictionary) else { throw NSError(domain: "NativeSAMCheck", code: 3) }
                photoID = UUID()
                encodings.append(try await segmenter.prepare(image: image, photoID: photoID, directory: models) { _ in })
                previousImage = fixture.image
            }
            var count = 0
            for tap in fixture.taps {
                let hold = Hold(x: tap.x, y: tap.y, r: tap.r), start = CFAbsoluteTimeGetCurrent()
                if let result = try await segmenter.segment(hold, photoID: photoID) {
                    guard result.contour.points.count <= 64,
                          result.contour.contains(.init(x: hold.x, y: hold.y)), result.contour.contains(result.anchor) else {
                        throw NSError(domain: "NativeSAMCheck", code: 4)
                    }
                    count += 1; accepted += 1
                }
                times.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
                total += 1
            }
            guard count > 0 else { throw NSError(domain: "NativeSAMCheck", code: 5) }
        }
        let sorted = times.sorted()
        let summary: [String: Any] = [
            "platform": "macOS", "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "modelVersion": SAMModelCatalog.tiny.version, "prompts": total, "acceptedCandidates": accepted,
            "encodingSeconds": encodings, "pointMedianMs": sorted[sorted.count / 2], "pointMaxMs": sorted.last!
        ]
        let data = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
