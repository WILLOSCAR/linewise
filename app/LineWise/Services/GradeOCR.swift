import Foundation
import UIKit
import Vision

/// 本地文字识别，找难度标签。识别失败或找不到都返回 nil，不阻塞流程。
enum GradeOCR {
    static func recognizeGrade(in image: UIImage) async -> String? {
        let small = ImageStore.downsample(image, maxLongEdge: 1600)
        guard let cg = small.cgImage else { return nil }
        return await Task.detached(priority: .utility) { () -> String? in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return nil
            }
            let texts: [String] = (request.results ?? []).compactMap { obs in
                obs.topCandidates(1).first?.string
            }
            return GradeParser.candidates(from: texts).first
        }.value
    }
}
