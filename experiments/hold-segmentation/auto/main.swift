// Throwaway: tap one hold -> find every hold of the same colour (colour candidates + SAM 2.1 Tiny refine),
// score against the known line holds, and render a pop-in GIF. Usage: autoroute <cases.json> <outDir> <tinyDir>
import AppKit
import CoreImage
import CoreML
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Seeded: Codable { var name: String; var image: String; var seed: Int; var taps: [Tap] }

extension SAM {
    /// All three candidate masks for one point, each with its score (full-res, not filtered).
    func rawMasks(x: Double, y: Double, _ r: Raster, encoding: MLFeatureProvider) throws -> [(Mask, Double)] {
        let pts = try MLMultiArray(shape: [1, 1, 2], dataType: .float32)
        pts[[0, 0, 0]] = NSNumber(value: Float(x * 1024)); pts[[0, 0, 1]] = NSNumber(value: Float(y * 1024))
        let lbl = try MLMultiArray(shape: [1, 1], dataType: .int32)
        lbl[[0, 0]] = 1
        let p = try pro.prediction(from: MLDictionaryFeatureProvider(dictionary: ["points": pts, "labels": lbl]))
        let d = try dec.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "image_embedding": encoding.featureValue(for: "image_embedding")!,
            "feats_s0": encoding.featureValue(for: "feats_s0")!,
            "feats_s1": encoding.featureValue(for: "feats_s1")!,
            "sparse_embedding": p.featureValue(for: "sparse_embeddings")!,
            "dense_embedding": p.featureValue(for: "dense_embeddings")!,
        ]))
        let masks = d.featureValue(for: "low_res_masks")!.multiArrayValue!
        let scores = d.featureValue(for: "scores")!.multiArrayValue!
        let cx = Int(x * Double(r.w)), cy = Int(y * Double(r.h))
        return (0..<masks.shape[1].intValue).map { k in
            (upsample(masks, index: k, to: r).component(at: cx, cy), scores[[0, NSNumber(value: k)]].doubleValue)
        }
    }
}

typealias Lab = (Double, Double, Double)

func labAt(_ r: Raster, _ x: Int, _ y: Int) -> Lab { let i = (y * r.w + x) * 4; return lab(r.px[i], r.px[i + 1], r.px[i + 2]) }

/// Shading-tolerant colour distance: lightness counts half.
func dist(_ p: Lab, _ q: Lab) -> Double { sqrt(pow((p.0 - q.0) * 0.5, 2) + pow(p.1 - q.1, 2) + pow(p.2 - q.2, 2)) }

func signature(_ m: Mask, _ r: Raster) -> Lab {
    var ls: [Double] = [], as_: [Double] = [], bs: [Double] = []
    var i = 0
    for y in stride(from: 0, to: r.h, by: 2) { for x in stride(from: 0, to: r.w, by: 2) where m.v[y * r.w + x] == 1 {
        i += 1; let p = labAt(r, x, y); ls.append(p.0); as_.append(p.1); bs.append(p.2)
    } }
    func med(_ a: [Double]) -> Double { let s = a.sorted(); return s[s.count / 2] }
    return (med(ls), med(as_), med(bs))
}

struct Found { var mask: Mask; var point: (Int, Int); var isSeed: Bool }

func findSameColour(seedTap: Tap, _ r: Raster, sam: SAM, enc: MLFeatureProvider) throws -> (seed: Mask, found: [Found], sig: Lab) {
    guard case .shape(let seed) = try sam.segment(seedTap, r, encoding: enc) else { fatalError("seed did not segment") }
    let sig = signature(seed, r)
    let seedArea = Double(seed.area)
    let thr = 16.0

    // 1. colour candidate map at 1/4 resolution, 8-connected components
    let s = 4, gw = r.w / s, gh = r.h / s
    var cand = [UInt8](repeating: 0, count: gw * gh)
    for gy in 0..<gh { for gx in 0..<gw where dist(labAt(r, gx * s, gy * s), sig) < thr { cand[gy * gw + gx] = 1 } }
    var seen = [Bool](repeating: false, count: gw * gh)
    var blobs: [(pts: [(Int, Int)], cx: Double, cy: Double)] = []
    for start in 0..<(gw * gh) where cand[start] == 1 && !seen[start] {
        var stack = [start]; seen[start] = true; var pts: [(Int, Int)] = []
        while let i = stack.popLast() {
            let x = i % gw, y = i / gw; pts.append((x, y))
            for dy in -1...1 { for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, ny >= 0, nx < gw, ny < gh else { continue }
                let j = ny * gw + nx
                if cand[j] == 1 && !seen[j] { seen[j] = true; stack.append(j) }
            } }
        }
        let a = Double(pts.count * s * s)
        guard a > max(seedArea * 0.06, Double(r.w * r.h) * 0.00012), a < seedArea * 10 else { continue }
        blobs.append((pts, Double(pts.map(\.0).reduce(0, +)) / Double(pts.count), Double(pts.map(\.1).reduce(0, +)) / Double(pts.count)))
    }
    blobs.sort { $0.pts.count > $1.pts.count }

    // 2. refine each blob with SAM, keep masks whose own colour still matches
    var found = [Found(mask: seed, point: (Int(seedTap.x * Double(r.w)), Int(seedTap.y * Double(r.h))), isSeed: true)]
    var taken = seed
    for b in blobs.prefix(60) {
        let p = b.pts.min { pow(Double($0.0) - b.cx, 2) + pow(Double($0.1) - b.cy, 2) < pow(Double($1.0) - b.cx, 2) + pow(Double($1.1) - b.cy, 2) }!
        let px = p.0 * s, py = p.1 * s
        if taken.v[py * r.w + px] == 1 { continue }
        let cands = try sam.rawMasks(x: Double(px) / Double(r.w), y: Double(py) / Double(r.h), r, encoding: enc)
            .filter { $0.1 > 0.3 && Double($0.0.area) > seedArea * 0.06 && Double($0.0.area) < seedArea * 6 }
            .filter { dist(signature($0.0, r), sig) < thr * 1.3 }
            .sorted { $0.0.area < $1.0.area }
        guard let m = cands.first?.0 else { continue }
        var overlap = 0; for i in m.v.indices where m.v[i] == 1 && taken.v[i] == 1 { overlap += 1 }
        if Double(overlap) > Double(m.area) * 0.3 { continue }
        found.append(Found(mask: m, point: (px, py), isSeed: false)); taken.union(m)
    }
    return (seed, found, sig)
}

// MARK: - GIF

func writeGIF(_ frames: [(CGImage, Double)], to url: URL, maxWidth: Int = 540) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for (img, delay) in frames {
        let scale = min(1, Double(maxWidth) / Double(img.width))
        let w = Int(Double(img.width) * scale), h = Int(Double(img.height) * scale)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    }
    CGImageDestinationFinalize(dest)
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("Usage: \(args[0]) <cases.json> <outDir> <modelsDir> [mode]\n", stderr)
    exit(64)
}
let cases = try JSONDecoder().decode([Seeded].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let outDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let inputDir = URL(fileURLWithPath: args[1]).deletingLastPathComponent()
let tiny = try await SAM(name: "SAM 2.1 Tiny", dir: URL(fileURLWithPath: args[3]))

for c in cases {
    let cg = loadImage(inputDir.appendingPathComponent(c.image).path)
    let r = raster(cg)
    let t0 = CFAbsoluteTimeGetCurrent()
    let enc = try tiny.encode(cg)
    let (_, found, sig) = try findSameColour(seedTap: c.taps[c.seed], r, sam: tiny, enc: enc)
    let secs = CFAbsoluteTimeGetCurrent() - t0

    // score: known line holds covered, and found shapes not on any known hold
    let hits = c.taps.map { t in found.contains { $0.mask.v[Int(t.y * Double(r.h)) * r.w + Int(t.x * Double(r.w))] == 1 } }
    let extras = found.filter { f in !c.taps.contains { t in f.mask.v[Int(t.y * Double(r.h)) * r.w + Int(t.x * Double(r.w))] == 1 } }.count
    print(String(format: "%@: seed Lab(%.0f,%.0f,%.0f) found %d shapes, covers %d/%d known holds, %d not on the known line, %.1fs on Mac",
                 c.name, sig.0, sig.1, sig.2, found.count, hits.filter { $0 }.count, c.taps.count, extras, secs))

    // still: everything found, with known holds marked (green = found, red = missed)
    var all = Mask(w: r.w, h: r.h); for f in found { all.union(f.mask) }
    let crop = CGRect(x: 0, y: 0, width: r.w, height: r.h).insetBy(dx: CGFloat(r.w) * 0.04, dy: CGFloat(r.h) * 0.06)
    let still = spotlight(cg, all, crop: crop)
    let rep = NSBitmapImageRep(cgImage: still)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    for (i, t) in c.taps.enumerated() {
        let x = t.x * Double(r.w) - crop.minX, y = Double(still.height) - (t.y * Double(r.h) - crop.minY)
        (hits[i] ? NSColor.systemGreen : NSColor.systemRed).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - 7, y: y - 7, width: 14, height: 14)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let safe = c.name.replacingOccurrences(of: " ", with: "")
    try rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(safe)-找同色.png"))

    // GIF: dim wall, tap pulse on the seed, then holds pop in bottom -> top with a one-frame flash ring
    var frames: [(CGImage, Double)] = []
    let empty = Mask(w: r.w, h: r.h)
    let seedMask = found[0].mask
    frames.append((spotlight(cg, empty, crop: crop), 0.5))
    frames.append((spotlight(cg, seedMask, startMasks: [seedMask], crop: crop), 0.12))
    frames.append((spotlight(cg, seedMask, crop: crop), 0.35))
    var lit = seedMask
    for f in found.dropFirst().sorted(by: { $0.point.1 > $1.point.1 }) {
        lit.union(f.mask)
        frames.append((spotlight(cg, lit, startMasks: [f.mask], crop: crop), 0.07))
        frames.append((spotlight(cg, lit, crop: crop), 0.05))
    }
    frames.append((spotlight(cg, lit, crop: crop), 2.0))
    writeGIF(frames, to: outDir.appendingPathComponent("\(safe)-弹出.gif"))
}
