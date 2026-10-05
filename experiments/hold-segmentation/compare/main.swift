import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML
import Foundation
import ImageIO
import Vision
// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("Usage: \(args[0]) <cases.json> <outDir> <modelsDir> [mode]\n", stderr)
    exit(64)
}
let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let outDir = URL(fileURLWithPath: args[2])
let modelsDir = URL(fileURLWithPath: args[3])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let inputDir = URL(fileURLWithPath: args[1]).deletingLastPathComponent()

let tiny = try await SAM(name: "SAM 2.1 Tiny", dir: modelsDir.appendingPathComponent("coreml-sam2.1-tiny"))
let small = try await SAM(name: "SAM 2.1 Small", dir: modelsDir.appendingPathComponent("coreml-sam2.1-small"))
print(String(format: "load+compile: tiny %.1fs, small %.1fs", tiny.loadSeconds, small.loadSeconds))

struct Score { var shapes = 0; var total = 0; var iouSum = 0.0; var iouN = 0 }
var scores: [String: Score] = [:]
let methodNames = ["圆圈", "颜色扩散", "SAM Tiny", "SAM Small", "Apple Vision"]

for c in cases {
    let cg = loadImage(inputDir.appendingPathComponent(c.image).path)
    let r = raster(cg)
    let crop = focusRect(c.taps, r)
    let encT = try tiny.encode(cg), encS = try small.encode(cg)

    func run(_ name: String, _ tap: Tap) throws -> Outcome {
        switch name {
        case "圆圈": return .shape(circleMask(tap, r))
        case "颜色扩散": return colourFill(tap, r)
        case "SAM Tiny": return try tiny.segment(tap, r, encoding: encT)
        case "SAM Small": return try small.segment(tap, r, encoding: encS)
        default: return try visionSegment(tap, cg, r)
        }
    }

    var perMethod: [String: [Mask]] = [:]
    var fallbacks: [String: Int] = [:]
    for name in methodNames {
        var masks: [Mask] = []
        for tap in c.taps {
            let o = try run(name, tap)
            if case .fallback = o { fallbacks[name, default: 0] += 1 }
            masks.append(shown(o, tap, r))
            // jitter: a finger lands ±40% of the radius off centre
            var s = scores[name] ?? Score()
            s.total += 1
            if case .shape = o, name != "圆圈" { s.shapes += 1 }
            let d = tap.r * 0.4 * Double(r.short)
            for (dx, dy) in [(d, 0.0), (-d, 0.0), (0.0, d), (0.0, -d)] {
                let jt = Tap(x: tap.x + dx / Double(r.w), y: tap.y + dy / Double(r.h), r: tap.r)
                s.iouSum += iou(shown(o, tap, r), shown(try run(name, jt), jt, r)); s.iouN += 1
            }
            scores[name] = s
        }
        perMethod[name] = masks
    }

    func union(_ ms: [Mask]) -> Mask { var u = Mask(w: r.w, h: r.h); for m in ms { u.union(m) }; return u }
    let order = c.taps.indices.sorted { abs(c.taps[$0].y - c.taps[$1].y) > 0.005 ? c.taps[$0].y > c.taps[$1].y : c.taps[$0].x < c.taps[$1].x }
    var numbers = [Int](repeating: 0, count: c.taps.count)
    for (n, i) in order.enumerated() { numbers[i] = n + 1 }
    let startIdx = order.first!, finishIdx = order.last!

    var panels: [(String, String, CGImage)] = []
    for name in methodNames {
        let ms = perMethod[name]!
        let sub = name == "圆圈" ? "现在 App 的样子" : "\(c.taps.count - fallbacks[name, default: 0])/\(c.taps.count) 贴合轮廓，其余退回圆圈"
        panels.append((name, sub, spotlight(cg, union(ms), crop: crop)))
    }
    // final: best method with start ring, finish flag, numbers — vs the circle version with the same markers
    func marked(_ ms: [Mask]) -> CGImage {
        let img = spotlight(cg, union(ms), startMasks: [ms[startIdx]], crop: crop)
        return annotate(img, crop: crop, boxes: ms.map { $0.bbox ?? .zero }, numbers: numbers, finish: finishIdx, short: CGFloat(r.short))
    }
    panels.append(("SAM Tiny + 起步双环 / 结束小旗 / 编号", "进 App 后线路页的样子", marked(perMethod["SAM Tiny"]!)))
    let safe = c.name.replacingOccurrences(of: " ", with: "")
    sheet(title: c.name, panels: panels, cols: 3, panelW: 480, to: outDir.appendingPathComponent("\(safe)-全部.png"))
    sheet(title: c.name + " · 前后对比", panels: [
        ("现在：圆圈", "起步双环、结束小旗、编号", marked(perMethod["圆圈"]!)),
        ("之后：SAM 2.1 Tiny 轮廓", "同样的标记，跟着岩点形状走", marked(perMethod["SAM Tiny"]!)),
    ], cols: 2, panelW: 620, to: outDir.appendingPathComponent("\(safe)-前后.png"))
    print("done \(c.name)")
}

func med(_ a: [Double]) -> Double { let s = a.sorted(); return s.isEmpty ? 0 : s[s.count / 2] }
print("\n方法 | 贴合轮廓 | 点歪 40% 半径后形状重合度(IoU)")
for name in methodNames {
    let s = scores[name]!
    print(String(format: "%@ | %d/%d | %.2f", name, name == "圆圈" ? 0 : s.shapes, s.total, s.iouSum / Double(s.iouN)))
}
print(String(format: "\n耗时(Mac, 中位)：Tiny 编码 %.0fms 每点 %.0fms；Small 编码 %.0fms 每点 %.0fms；Vision 每点 %.0fms",
             med(tiny.encodeSeconds) * 1000, med(tiny.modelSeconds) * 1000, med(small.encodeSeconds) * 1000, med(small.modelSeconds) * 1000, med(visionSeconds) * 1000))
