// Throwaway: segment every hold on a wall with SAM 2.1 Tiny, export polygons + colour for the UI prototype.
// Usage: wallseg <cases.json> <outDir> <tinyDir> [grid|saliency]
import AppKit
import CoreImage
import CoreML
import Foundation
import Vision

struct DetectedHold: Codable {
    var id: Int
    var poly: [[Double]]      // normalised, y down
    var cx: Double, cy: Double // centroid
    var ax: Double, ay: Double // hand/foot anchor inside the shape
    var area: Double           // fraction of image
    var lab: [Double]
    var chroma: Double
    var score: Double
}
struct KnownLine: Codable { var name: String; var taps: [[Double]] }
struct WallOut: Codable { var image: String; var w: Int; var h: Int; var holds: [DetectedHold]; var lines: [KnownLine]; var seconds: Double; var prompts: Int }

// MARK: low-res logits

func lowRes(_ a: MLMultiArray, _ k: Int) -> [Float] {
    let h = a.shape[2].intValue, w = a.shape[3].intValue
    let s = a.strides.map(\.intValue)
    var out = [Float](repeating: 0, count: h * w)
    switch a.dataType {
    case .float16:
        a.withUnsafeBufferPointer(ofType: Float16.self) { p in
            for y in 0..<h { for x in 0..<w { out[y * w + x] = Float(p[k * s[1] + y * s[2] + x * s[3]]) } }
        }
    default:
        a.withUnsafeBufferPointer(ofType: Float.self) { p in
            for y in 0..<h { for x in 0..<w { out[y * w + x] = p[k * s[1] + y * s[2] + x * s[3]] } }
        }
    }
    return out
}

func upsampleLow(_ low: [Float], lw: Int, lh: Int, to r: Raster) -> Mask {
    var m = Mask(w: r.w, h: r.h)
    for y in 0..<r.h {
        let fy = (Double(y) + 0.5) / Double(r.h) * Double(lh) - 0.5
        let y0 = max(0, min(lh - 1, Int(floor(fy)))), y1 = min(lh - 1, y0 + 1), ty = Float(max(0, min(1, fy - Double(y0))))
        for x in 0..<r.w {
            let fx = (Double(x) + 0.5) / Double(r.w) * Double(lw) - 0.5
            let x0 = max(0, min(lw - 1, Int(floor(fx)))), x1 = min(lw - 1, x0 + 1), tx = Float(max(0, min(1, fx - Double(x0))))
            let a = low[y0 * lw + x0] * (1 - tx) + low[y0 * lw + x1] * tx
            let b = low[y1 * lw + x0] * (1 - tx) + low[y1 * lw + x1] * tx
            if a * (1 - ty) + b * ty > 0 { m.v[y * r.w + x] = 1 }
        }
    }
    return m
}

// MARK: person mask (Vision, on-device)

func personMask(_ cg: CGImage, _ r: Raster) throws -> Mask {
    let req = VNGeneratePersonSegmentationRequest()
    req.qualityLevel = .balanced
    try VNImageRequestHandler(cgImage: cg).perform([req])
    var m = Mask(w: r.w, h: r.h)
    guard let pb = req.results?.first?.pixelBuffer else { return m }
    CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let pw = CVPixelBufferGetWidth(pb), ph = CVPixelBufferGetHeight(pb), bpr = CVPixelBufferGetBytesPerRow(pb)
    let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
    for y in 0..<r.h { for x in 0..<r.w {
        if base[(y * ph / r.h) * bpr + x * pw / r.w] > 127 { m.v[y * r.w + x] = 1 }
    } }
    return m
}

// MARK: prompts

func gridPrompts(_ r: Raster, step: Int) -> [(Int, Int)] {
    var p: [(Int, Int)] = []
    for y in stride(from: r.h - step / 2, through: 0, by: -step) { for x in stride(from: step / 2, to: r.w, by: step) { p.append((x, y)) } }
    return p
}

/// Points where the colour differs from the local background (box-blurred) — cheap hold proposals.
func saliencyPrompts(_ r: Raster) -> [(Int, Int)] {
    let s = 4, gw = r.w / s, gh = r.h / s
    var L = [[Double]](repeating: [0, 0, 0], count: gw * gh)
    for gy in 0..<gh { for gx in 0..<gw { let p = lab(r.px[((gy * s) * r.w + gx * s) * 4], r.px[((gy * s) * r.w + gx * s) * 4 + 1], r.px[((gy * s) * r.w + gx * s) * 4 + 2]); L[gy * gw + gx] = [p.0, p.1, p.2] } }
    // integral images for a big box blur
    func blur(_ c: Int, rad: Int) -> [Double] {
        var I = [Double](repeating: 0, count: (gw + 1) * (gh + 1))
        for y in 0..<gh { var row = 0.0; for x in 0..<gw { row += L[y * gw + x][c]; I[(y + 1) * (gw + 1) + x + 1] = I[y * (gw + 1) + x + 1] + row } }
        var out = [Double](repeating: 0, count: gw * gh)
        for y in 0..<gh { for x in 0..<gw {
            let x0 = max(0, x - rad), x1 = min(gw, x + rad + 1), y0 = max(0, y - rad), y1 = min(gh, y + rad + 1)
            let sum = I[y1 * (gw + 1) + x1] - I[y0 * (gw + 1) + x1] - I[y1 * (gw + 1) + x0] + I[y0 * (gw + 1) + x0]
            out[y * gw + x] = sum / Double((x1 - x0) * (y1 - y0))
        } }
        return out
    }
    let bg = (0..<3).map { blur($0, rad: 14) }
    var fg = [UInt8](repeating: 0, count: gw * gh)
    for i in 0..<(gw * gh) {
        let d = sqrt(pow((L[i][0] - bg[0][i]) * 0.5, 2) + pow(L[i][1] - bg[1][i], 2) + pow(L[i][2] - bg[2][i], 2))
        if d > 14 { fg[i] = 1 }
    }
    var seen = [Bool](repeating: false, count: gw * gh)
    var pts: [(Int, Int)] = []
    for start in 0..<(gw * gh) where fg[start] == 1 && !seen[start] {
        var st = [start]; seen[start] = true; var cells: [(Int, Int)] = []
        while let i = st.popLast() {
            let x = i % gw, y = i / gw; cells.append((x, y))
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] where nx >= 0 && ny >= 0 && nx < gw && ny < gh {
                let j = ny * gw + nx; if fg[j] == 1 && !seen[j] { seen[j] = true; st.append(j) }
            }
        }
        guard cells.count >= 4 else { continue }
        // one prompt per ~12x12-cell chunk of the blob, at the cell nearest each chunk's mean
        var buckets: [Int: [(Int, Int)]] = [:]
        for c in cells { buckets[(c.1 / 12) * 1000 + c.0 / 12, default: []].append(c) }
        for (_, b) in buckets where b.count >= 3 {
            let mx = Double(b.map(\.0).reduce(0, +)) / Double(b.count), my = Double(b.map(\.1).reduce(0, +)) / Double(b.count)
            let c = b.min { pow(Double($0.0) - mx, 2) + pow(Double($0.1) - my, 2) < pow(Double($1.0) - mx, 2) + pow(Double($1.1) - my, 2) }!
            pts.append((c.0 * s + s / 2, c.1 * s + s / 2))
        }
    }
    return pts.sorted { $0.1 > $1.1 } // bottom → top, like the scan band
}

// MARK: polygon

func polygon(_ m: Mask) throws -> [[Double]] {
    let req = VNDetectContoursRequest()
    req.detectsDarkOnLight = false
    req.contrastAdjustment = 1
    req.maximumImageDimension = 512
    try VNImageRequestHandler(cgImage: m.cgImage()).perform([req])
    guard let obs = req.results?.first else { return [] }
    let best = obs.topLevelContours.max { $0.normalizedPoints.count < $1.normalizedPoints.count }
    guard var c = best else { return [] }
    var eps: Float = 0.0015
    while true {
        let a = try c.polygonApproximation(epsilon: eps)
        if a.pointCount <= 64 || eps > 0.05 { c = a; break }
        eps *= 1.6
    }
    return c.normalizedPoints.map { [Double($0.x), 1 - Double($0.y)] }
}

// MARK: main

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("Usage: \(args[0]) <cases.json> <outDir> <modelsDir> [mode]\n", stderr)
    exit(64)
}
let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let outDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let inputDir = URL(fileURLWithPath: args[1]).deletingLastPathComponent()
let mode = args.count > 4 ? args[4] : "saliency"
let tiny = try await SAM(name: "tiny", dir: URL(fileURLWithPath: args[3]))

var byImage: [String: [Case]] = [:]
for c in cases { byImage[c.image, default: []].append(c) }

for (image, wallCases) in byImage.sorted(by: { $0.key < $1.key }) {
    let cg = loadImage(inputDir.appendingPathComponent(image).path)
    let r = raster(cg)
    let t0 = CFAbsoluteTimeGetCurrent()
    let enc = try tiny.encode(cg)
    let person = try personMask(cg, r)
    let prompts: [(Int, Int)] = {
        switch mode {
        case "grid": return gridPrompts(r, step: 22)
        case "hybrid": return (saliencyPrompts(r) + gridPrompts(r, step: 40)).sorted { $0.1 > $1.1 }
        case "taps": return wallCases.flatMap { $0.taps.map { (Int($0.x * Double(r.w)), Int($0.y * Double(r.h))) } }
        default: return saliencyPrompts(r)
        }
    }()
    let imgArea = Double(r.w * r.h)
    var taken = Mask(w: r.w, h: r.h)      // pixels of hold-sized shapes: prompts here are skipped
    var claimed = [Int32](repeating: -1, count: r.w * r.h) // which accepted shape owns a pixel
    var holds: [(Mask, Double)] = []
    let volumeArea = imgArea * 0.006
    var decoded = 0
    for (px, py) in prompts {
        let i = py * r.w + px
        if taken.v[i] == 1 || person.v[i] == 1 { continue }
        let pts = try MLMultiArray(shape: [1, 1, 2], dataType: .float32)
        pts[[0, 0, 0]] = NSNumber(value: Float(Double(px) / Double(r.w) * 1024)); pts[[0, 0, 1]] = NSNumber(value: Float(Double(py) / Double(r.h) * 1024))
        let lbl = try MLMultiArray(shape: [1, 1], dataType: .int32); lbl[[0, 0]] = 1
        let p = try tiny.pro.prediction(from: MLDictionaryFeatureProvider(dictionary: ["points": pts, "labels": lbl]))
        let d = try tiny.dec.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "image_embedding": enc.featureValue(for: "image_embedding")!, "feats_s0": enc.featureValue(for: "feats_s0")!,
            "feats_s1": enc.featureValue(for: "feats_s1")!, "sparse_embedding": p.featureValue(for: "sparse_embeddings")!,
            "dense_embedding": p.featureValue(for: "dense_embeddings")!]))
        decoded += 1
        let masks = d.featureValue(for: "low_res_masks")!.multiArrayValue!
        let scores = d.featureValue(for: "scores")!.multiArrayValue!
        let lh = masks.shape[2].intValue, lw = masks.shape[3].intValue
        var best: (Mask, Double)?
        for k in 0..<masks.shape[1].intValue {
            let score = scores[[0, NSNumber(value: k)]].doubleValue
            let low = lowRes(masks, k)
            let frac = Double(low.filter { $0 > 0 }.count) / Double(lw * lh)
            if mode == "taps" { print(String(format: "    tap(%.3f,%.3f) k%d score %.2f frac %.4f", Double(px)/Double(r.w), Double(py)/Double(r.h), k, score, frac)) }
            guard score > 0.6 else { continue }
            guard frac > 0.00025, frac < 0.03 else { continue }
            let comp = upsampleLow(low, lw: lw, lh: lh, to: r).component(at: px, py)
            let a = Double(comp.area)
            guard a / imgArea > 0.00025, let bb = comp.bbox else { continue }
            let fill = a / Double(bb.width * bb.height)
            let aspect = max(bb.width, bb.height) / max(1, min(bb.width, bb.height))
            if mode == "taps" { print(String(format: "      k%d area %.4f fill %.2f aspect %.1f bb %@", k, a / imgArea, fill, aspect, NSStringFromRect(bb))) }
            guard fill > 0.25, aspect < 8, bb.minX > 1, bb.minY > 1, bb.maxX < CGFloat(r.w - 1), bb.maxY < CGFloat(r.h - 1) else { continue }
            var pv = 0
            var owners: [Int32: Int] = [:]
            for j in comp.v.indices where comp.v[j] == 1 {
                if person.v[j] == 1 { pv += 1 }
                if claimed[j] >= 0 { owners[claimed[j], default: 0] += 1 }
            }
            guard Double(pv) < a * 0.3 else { continue }
            // overlap is fine only when this is a small hold sitting on a much larger volume
            let clash = owners.contains { (o, n) in
                let other = Double(holds[Int(o)].0.area)
                let nested = Double(n) > a * 0.6 && a < other * 0.35 && other > volumeArea
                return Double(n) > a * 0.2 && !nested
            }
            if mode == "taps" { print("      k\(k) person \(pv) clash \(clash) owners \(owners)") }
            guard !clash else { continue }
            if best == nil || score > best!.1 + 0.02 || (abs(score - best!.1) <= 0.02 && comp.area < best!.0.area) { best = (comp, score) }
        }
        if let b = best {
            let idx = Int32(holds.count)
            holds.append(b)
            let small = Double(b.0.area) <= volumeArea
            for j in b.0.v.indices where b.0.v[j] == 1 { claimed[j] = idx; if small { taken.v[j] = 1 } }
        }
    }
    let secs = CFAbsoluteTimeGetCurrent() - t0

    var out: [DetectedHold] = []
    for (i, (m, score)) in holds.enumerated() {
        let poly = try polygon(m)
        guard poly.count >= 3 else { continue }
        var sx = 0.0, sy = 0.0, n = 0.0
        var ls: [Double] = [], as_: [Double] = [], bs: [Double] = []
        for y in stride(from: 0, to: r.h, by: 1) { for x in stride(from: 0, to: r.w, by: 1) where m.v[y * r.w + x] == 1 {
            sx += Double(x); sy += Double(y); n += 1
            if (x + y) % 2 == 0 { let q = lab(r.px[(y * r.w + x) * 4], r.px[(y * r.w + x) * 4 + 1], r.px[(y * r.w + x) * 4 + 2]); ls.append(q.0); as_.append(q.1); bs.append(q.2) }
        } }
        func med(_ a: [Double]) -> Double { let s = a.sorted(); return s[s.count / 2] }
        let cx = sx / n, cy = sy / n
        var ax = cx, ay = cy
        if m.v[Int(cy) * r.w + Int(cx)] == 0 {
            var bestD = Double.infinity
            for y in 0..<r.h { for x in 0..<r.w where m.v[y * r.w + x] == 1 { let d = pow(Double(x) - cx, 2) + pow(Double(y) - cy, 2); if d < bestD { bestD = d; ax = Double(x); ay = Double(y) } } }
        }
        let L = [med(ls), med(as_), med(bs)]
        out.append(DetectedHold(id: i, poly: poly.map { [($0[0] * 10000).rounded() / 10000, ($0[1] * 10000).rounded() / 10000] },
                                cx: cx / Double(r.w), cy: cy / Double(r.h), ax: ax / Double(r.w), ay: ay / Double(r.h),
                                area: n / imgArea, lab: L.map { ($0 * 10).rounded() / 10 }, chroma: sqrt(L[1] * L[1] + L[2] * L[2]), score: score))
    }

    // coverage of the known (hand-placed) holds
    var all = Mask(w: r.w, h: r.h); for (m, _) in holds { all.union(m) }
    for c in wallCases {
        let hit = c.taps.filter { all.v[Int($0.y * Double(r.h)) * r.w + Int($0.x * Double(r.w))] == 1 }.count
        print("  \(c.name): known holds covered \(hit)/\(c.taps.count)")
    }
    print(String(format: "%@ [%@]: %d prompts, %d decoded, %d holds, %.1fs on Mac", image, mode, prompts.count, decoded, out.count, secs))

    let wall = WallOut(image: image, w: r.w, h: r.h, holds: out,
                       lines: wallCases.map { KnownLine(name: $0.name, taps: $0.taps.map { [$0.x, $0.y] }) }, seconds: secs, prompts: decoded)
    let stem = (image as NSString).deletingPathExtension
    let enc2 = JSONEncoder(); enc2.outputFormatting = [.sortedKeys]
    try enc2.encode(wall).write(to: outDir.appendingPathComponent("\(stem)-\(mode).json"))
    let full = CGRect(x: 0, y: 0, width: r.w, height: r.h)
    let img = spotlight(cg, all, crop: full)
    try NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(stem)-\(mode).png"))
}
