import CoreGraphics
import Foundation
import Vision

struct SAMMaskContour: Sendable {
    let contour: HoldContour
    let anchor: NormalizedPoint
    let pixelArea: Int

    /// Flood only the component under the tap. Sampling logits on demand avoids three full-size masks.
    static func extract(logits: [Float], logitsWidth: Int, logitsHeight: Int,
                        width: Int, height: Int, hold: Hold) throws -> SAMMaskContour? {
        guard logitsWidth > 0, logitsHeight > 0, logits.count == logitsWidth * logitsHeight,
              width > 0, height > 0 else { return nil }
        let x = min(width - 1, max(0, Int(hold.x * Double(width))))
        let y = min(height - 1, max(0, Int(hold.y * Double(height))))
        func foreground(_ x: Int, _ y: Int) -> Bool {
            let fx = (Double(x) + 0.5) / Double(width) * Double(logitsWidth) - 0.5
            let fy = (Double(y) + 0.5) / Double(height) * Double(logitsHeight) - 0.5
            let x0 = max(0, min(logitsWidth - 1, Int(floor(fx)))), x1 = min(logitsWidth - 1, x0 + 1)
            let y0 = max(0, min(logitsHeight - 1, Int(floor(fy)))), y1 = min(logitsHeight - 1, y0 + 1)
            let tx = Float(max(0, min(1, fx - Double(x0)))), ty = Float(max(0, min(1, fy - Double(y0))))
            let a = logits[y0 * logitsWidth + x0] * (1 - tx) + logits[y0 * logitsWidth + x1] * tx
            let b = logits[y1 * logitsWidth + x0] * (1 - tx) + logits[y1 * logitsWidth + x1] * tx
            return a * (1 - ty) + b * ty > 0
        }
        guard foreground(x, y) else { return nil }
        let circleArea = Double.pi * pow(hold.r * Double(min(width, height)), 2)
        let maxArea = Int(circleArea * 4)
        var visited = [UInt8](repeating: 0, count: width * height)
        var component = [y * width + x], cursor = 0
        visited[component[0]] = 1
        while cursor < component.count {
            if cursor % 256 == 0 { try Task.checkCancellation() }
            let i = component[cursor], cx = i % width, cy = i / width
            cursor += 1
            for (nx, ny) in [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]
                where nx >= 0 && nx < width && ny >= 0 && ny < height {
                let next = ny * width + nx
                guard visited[next] == 0 else { continue }
                visited[next] = 1
                if foreground(nx, ny) {
                    component.append(next)
                    if component.count > maxArea { return nil }
                }
            }
        }
        guard Double(component.count) >= circleArea * 0.12 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height)
        var sumX = 0, sumY = 0
        for i in component { pixels[i] = 255; sumX += i % width; sumY += i / width }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                                  bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let request = VNDetectContoursRequest()
        request.detectsDarkOnLight = false
        request.contrastAdjustment = 1
        request.maximumImageDimension = max(width, height)
        try VNImageRequestHandler(cgImage: image).perform([request])
        guard let original = request.results?.first?.topLevelContours.max(by: { $0.pointCount < $1.pointCount }) else { return nil }
        var epsilon: Float = 0.0008
        let tap = NormalizedPoint(x: hold.x, y: hold.y)
        while epsilon <= 0.05 {
            let approximation = try original.polygonApproximation(epsilon: epsilon)
            let points = approximation.normalizedPoints.map { NormalizedPoint(x: Double($0.x), y: 1 - Double($0.y)) }
            if points.count <= HoldContour.maximumPoints, let contour = HoldContour(points: points), contour.contains(tap),
               contour.area * Double(width * height) <= circleArea * 4 {
                let centre = NormalizedPoint(x: (Double(sumX) / Double(component.count) + 0.5) / Double(width),
                                             y: (Double(sumY) / Double(component.count) + 0.5) / Double(height))
                return .init(contour: contour, anchor: contour.closestPoint(to: centre), pixelArea: component.count)
            }
            epsilon *= 1.5
        }
        return nil
    }
}
