// Shared raster, mask, Core ML and rendering helpers for the preserved Mac experiments.
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML
import Foundation
import ImageIO
import Vision

struct Tap: Codable { var x: Double; var y: Double; var r: Double }
struct Case: Codable { var name: String; var image: String; var taps: [Tap] }

let workLong = 1600

// MARK: - Raster & mask

struct Raster {
    let w: Int, h: Int
    var px: [UInt8]
    var short: Int { min(w, h) }
}

func loadImage(_ path: String) -> CGImage {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                 kCGImageSourceCreateThumbnailWithTransform: true,
                                 kCGImageSourceThumbnailMaxPixelSize: workLong]
    return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)!
}

func raster(_ cg: CGImage) -> Raster {
    let w = cg.width, h = cg.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    return Raster(w: w, h: h, px: px)
}

struct Mask {
    let w: Int, h: Int
    var v: [UInt8]
    init(w: Int, h: Int) { self.w = w; self.h = h; v = [UInt8](repeating: 0, count: w * h) }
    var area: Int { v.reduce(0) { $0 + Int($1) } }
    mutating func union(_ o: Mask) { for i in v.indices where o.v[i] == 1 { v[i] = 1 } }

    var bbox: CGRect? {
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h { for x in 0..<w where v[y * w + x] == 1 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } }
        return maxX < 0 ? nil : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func cgImage() -> CGImage {
        var bytes = v.map { $0 == 1 ? UInt8(255) : 0 }
        let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return ctx.makeImage()!
    }

    /// 4-connected component containing (cx, cy), interior holes filled.
    func component(at cx: Int, _ cy: Int) -> Mask {
        var out = Mask(w: w, h: h)
        guard cx >= 0, cy >= 0, cx < w, cy < h, v[cy * w + cx] == 1 else { return out }
        var stack = [(cx, cy)]
        out.v[cy * w + cx] = 1
        var minX = cx, maxX = cx, minY = cy, maxY = cy
        while let (x, y) = stack.popLast() {
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] where nx >= 0 && ny >= 0 && nx < w && ny < h {
                let i = ny * w + nx
                if v[i] == 1 && out.v[i] == 0 {
                    out.v[i] = 1; stack.append((nx, ny))
                    minX = min(minX, nx); maxX = max(maxX, nx); minY = min(minY, ny); maxY = max(maxY, ny)
                }
            }
        }
        let bx0 = max(minX - 1, 0), bx1 = min(maxX + 1, w - 1), by0 = max(minY - 1, 0), by1 = min(maxY + 1, h - 1)
        var outside = Set<Int>()
        var s: [(Int, Int)] = []
        for x in bx0...bx1 { s.append((x, by0)); s.append((x, by1)) }
        for y in by0...by1 { s.append((bx0, y)); s.append((bx1, y)) }
        while let (x, y) = s.popLast() {
            let i = y * w + x
            if out.v[i] == 1 || outside.contains(i) { continue }
            outside.insert(i)
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] where nx >= bx0 && ny >= by0 && nx <= bx1 && ny <= by1 {
                s.append((nx, ny))
            }
        }
        for y in by0...by1 { for x in bx0...bx1 { let i = y * w + x; if !outside.contains(i) { out.v[i] = 1 } } }
        return out
    }
}

func iou(_ a: Mask, _ b: Mask) -> Double {
    var inter = 0, uni = 0
    for i in a.v.indices { let p = a.v[i] == 1, q = b.v[i] == 1; if p && q { inter += 1 }; if p || q { uni += 1 } }
    return uni == 0 ? 1 : Double(inter) / Double(uni)
}

func circleMask(_ tap: Tap, _ r: Raster) -> Mask {
    var m = Mask(w: r.w, h: r.h)
    let cx = tap.x * Double(r.w), cy = tap.y * Double(r.h), rad = tap.r * Double(r.short)
    for y in max(0, Int(cy - rad))...min(r.h - 1, Int(cy + rad)) {
        for x in max(0, Int(cx - rad))...min(r.w - 1, Int(cx + rad)) {
            let dx = Double(x) - cx, dy = Double(y) - cy
            if dx * dx + dy * dy <= rad * rad { m.v[y * r.w + x] = 1 }
        }
    }
    return m
}

/// What the user would see for one tap: the shape, or the circle when the method gives up.
enum Outcome { case shape(Mask), fallback }

func shown(_ o: Outcome, _ tap: Tap, _ r: Raster) -> Mask {
    if case .shape(let m) = o { return m }
    return circleMask(tap, r)
}

/// Shared acceptance rule: the shape must contain the tap and be between 0.12x and 4x the circle's area.
func accept(_ m: Mask, _ tap: Tap, _ r: Raster) -> Mask? {
    let comp = m.component(at: Int(tap.x * Double(r.w)), Int(tap.y * Double(r.h)))
    let circle = Double.pi * pow(tap.r * Double(r.short), 2)
    let a = Double(comp.area)
    return a >= circle * 0.12 && a <= circle * 4 ? comp : nil
}

// MARK: - Method: colour flood fill

func lab(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> (Double, Double, Double) {
    func lin(_ c: UInt8) -> Double { let v = Double(c) / 255; return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    let (R, G, B) = (lin(r), lin(g), lin(b))
    let X = (0.4124 * R + 0.3576 * G + 0.1805 * B) / 0.95047
    let Y = 0.2126 * R + 0.7152 * G + 0.0722 * B
    let Z = (0.0193 * R + 0.1192 * G + 0.9505 * B) / 1.08883
    func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116 }
    return (116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z)))
}

func colourFill(_ tap: Tap, _ r: Raster, deltaE: Double = 20) -> Outcome {
    let cx = Int(tap.x * Double(r.w)), cy = Int(tap.y * Double(r.h))
    let circR = tap.r * Double(r.short)
    let seedR = max(2, Int(circR * 0.3))
    var samples: [(Double, Double, Double)] = []
    for y in max(0, cy - seedR)...min(r.h - 1, cy + seedR) {
        for x in max(0, cx - seedR)...min(r.w - 1, cx + seedR) {
            let i = (y * r.w + x) * 4
            samples.append(lab(r.px[i], r.px[i + 1], r.px[i + 2]))
        }
    }
    func med(_ k: KeyPath<(Double, Double, Double), Double>) -> Double { let s = samples.map { $0[keyPath: k] }.sorted(); return s[s.count / 2] }
    let seed = (med(\.0), med(\.1), med(\.2))
    let window = max(circR * 3, Double(r.short) * 0.12)
    var m = Mask(w: r.w, h: r.h)
    var stack = [(cx, cy)]
    var visited = Set<Int>([cy * r.w + cx])
    while let (x, y) = stack.popLast() {
        let i = y * r.w + x
        let p = lab(r.px[i * 4], r.px[i * 4 + 1], r.px[i * 4 + 2])
        guard sqrt(pow(p.0 - seed.0, 2) + pow(p.1 - seed.1, 2) + pow(p.2 - seed.2, 2)) < deltaE else { continue }
        m.v[i] = 1
        for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] where nx >= 0 && ny >= 0 && nx < r.w && ny < r.h {
            let ddx = Double(nx - cx), ddy = Double(ny - cy)
            if ddx * ddx + ddy * ddy > window * window { continue }
            let j = ny * r.w + nx
            if visited.insert(j).inserted { stack.append((nx, ny)) }
        }
    }
    return accept(m, tap, r).map(Outcome.shape) ?? .fallback
}

// MARK: - Method: SAM 2.1 (Core ML), point prompt + area limit

final class SAM {
    let name: String
    let enc: MLModel, pro: MLModel, dec: MLModel
    var encodeSeconds: [Double] = []
    var modelSeconds: [Double] = []
    var loadSeconds: Double = 0

    init(name: String, dir: URL) async throws {
        self.name = name
        let t0 = CFAbsoluteTimeGetCurrent()
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "mlpackage" }
        func load(_ key: String) async throws -> MLModel {
            let url = files.first { $0.lastPathComponent.contains(key) }!
            let cfg = MLModelConfiguration(); cfg.computeUnits = .all
            return try MLModel(contentsOf: try await MLModel.compileModel(at: url), configuration: cfg)
        }
        enc = try await load("ImageEncoder"); pro = try await load("PromptEncoder"); dec = try await load("MaskDecoder")
        loadSeconds = CFAbsoluteTimeGetCurrent() - t0
    }

    func encode(_ cg: CGImage) throws -> MLFeatureProvider {
        let (key, desc) = enc.modelDescription.inputDescriptionsByName.first { $0.value.type == .image }!
        let value = try MLFeatureValue(cgImage: cg, constraint: desc.imageConstraint!,
                                       options: [.cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue])
        let t0 = CFAbsoluteTimeGetCurrent()
        let out = try enc.prediction(from: MLDictionaryFeatureProvider(dictionary: [key: value]))
        encodeSeconds.append(CFAbsoluteTimeGetCurrent() - t0)
        return out
    }

    func segment(_ tap: Tap, _ r: Raster, encoding: MLFeatureProvider) throws -> Outcome {
        let pts = try MLMultiArray(shape: [1, 1, 2], dataType: .float32)
        pts[[0, 0, 0]] = NSNumber(value: Float(tap.x * 1024)); pts[[0, 0, 1]] = NSNumber(value: Float(tap.y * 1024))
        let lbl = try MLMultiArray(shape: [1, 1], dataType: .int32)
        lbl[[0, 0]] = 1
        let t0 = CFAbsoluteTimeGetCurrent()
        let p = try pro.prediction(from: MLDictionaryFeatureProvider(dictionary: ["points": pts, "labels": lbl]))
        let d = try dec.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "image_embedding": encoding.featureValue(for: "image_embedding")!,
            "feats_s0": encoding.featureValue(for: "feats_s0")!,
            "feats_s1": encoding.featureValue(for: "feats_s1")!,
            "sparse_embedding": p.featureValue(for: "sparse_embeddings")!,
            "dense_embedding": p.featureValue(for: "dense_embeddings")!,
        ]))
        modelSeconds.append(CFAbsoluteTimeGetCurrent() - t0)
        let masks = d.featureValue(for: "low_res_masks")!.multiArrayValue!
        let scores = d.featureValue(for: "scores")!.multiArrayValue!
        // SAM's three outputs run from part to whole; keep the smallest acceptable one.
        var best: Mask?
        for k in 0..<masks.shape[1].intValue where scores[[0, NSNumber(value: k)]].doubleValue > 0.3 {
            if let m = accept(upsample(masks, index: k, to: r), tap, r), best == nil || m.area < best!.area { best = m }
        }
        return best.map(Outcome.shape) ?? .fallback
    }
}

func upsample(_ logits: MLMultiArray, index k: Int, to r: Raster) -> Mask {
    let lh = logits.shape[2].intValue, lw = logits.shape[3].intValue
    var low = [Float](repeating: 0, count: lh * lw)
    for yy in 0..<lh { for xx in 0..<lw { low[yy * lw + xx] = logits[[0, NSNumber(value: k), NSNumber(value: yy), NSNumber(value: xx)]].floatValue } }
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

// MARK: - Method: Apple Vision foreground instance mask (built into iOS 17+ / macOS 14+)

var visionSeconds: [Double] = []

func visionSegment(_ tap: Tap, _ cg: CGImage, _ r: Raster) throws -> Outcome {
    let circR = tap.r * Double(r.short)
    let half = max(circR * 3.5, Double(r.short) * 0.1)
    let cx = tap.x * Double(r.w), cy = tap.y * Double(r.h)
    let rect = CGRect(x: cx - half, y: cy - half, width: half * 2, height: half * 2).integral
        .intersection(CGRect(x: 0, y: 0, width: r.w, height: r.h))
    guard let crop = cg.cropping(to: rect) else { return .fallback }
    let t0 = CFAbsoluteTimeGetCurrent()
    defer { visionSeconds.append(CFAbsoluteTimeGetCurrent() - t0) }
    let req = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: crop, options: [:])
    try handler.perform([req])
    guard let obs = req.results?.first else { return .fallback }

    let inst = obs.instanceMask
    CVPixelBufferLockBaseAddress(inst, .readOnly)
    let iw = CVPixelBufferGetWidth(inst), ih = CVPixelBufferGetHeight(inst), bpr = CVPixelBufferGetBytesPerRow(inst)
    let labels = CVPixelBufferGetBaseAddress(inst)!.assumingMemoryBound(to: UInt8.self)
    let tx = Int((cx - rect.minX) / rect.width * Double(iw)), ty = Int((cy - rect.minY) / rect.height * Double(ih))
    var counts: [UInt8: Int] = [:]
    let rad = max(1, Int(circR * 0.3 / rect.width * Double(iw)))
    for y in max(0, ty - rad)...min(ih - 1, ty + rad) { for x in max(0, tx - rad)...min(iw - 1, tx + rad) { let l = labels[y * bpr + x]; if l != 0 { counts[l, default: 0] += 1 } } }
    CVPixelBufferUnlockBaseAddress(inst, .readOnly)
    guard let label = counts.max(by: { $0.value < $1.value })?.key else { return .fallback }

    let scaled = try obs.generateScaledMaskForImage(forInstances: IndexSet(integer: Int(label)), from: handler)
    CVPixelBufferLockBaseAddress(scaled, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(scaled, .readOnly) }
    let sw = CVPixelBufferGetWidth(scaled), sh = CVPixelBufferGetHeight(scaled), sbpr = CVPixelBufferGetBytesPerRow(scaled)
    let fbase = CVPixelBufferGetBaseAddress(scaled)!
    var m = Mask(w: r.w, h: r.h)
    for y in 0..<Int(rect.height) {
        let sy = min(sh - 1, y * sh / Int(rect.height))
        let row = fbase.advanced(by: sy * sbpr).assumingMemoryBound(to: Float32.self)
        for x in 0..<Int(rect.width) {
            let sx = min(sw - 1, x * sw / Int(rect.width))
            if row[sx] > 0.5 { m.v[(Int(rect.minY) + y) * r.w + Int(rect.minX) + x] = 1 }
        }
    }
    return accept(m, tap, r).map(Outcome.shape) ?? .fallback
}

// MARK: - Rendering

let ci = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
let accent = CIColor(red: 1, green: 0.82, blue: 0.18)
let accentNS = NSColor(red: 1, green: 0.82, blue: 0.18, alpha: 1)

func ring(_ m: Mask, inner: CGFloat, outer: CGFloat) -> CIImage {
    let base = CIImage(cgImage: m.cgImage())
    let o = base.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": outer])
    let i = inner > 0 ? base.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": inner]) : base
    return i.applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: o]) // background − input
}

/// Spotlight with lit holes, glow and a thin accent edge. `startMasks` get a second outer ring.
func spotlight(_ base: CGImage, _ holes: Mask, startMasks: [Mask] = [], crop: CGRect) -> CGImage {
    let W = CGFloat(base.width), H = CGFloat(base.height), short = min(W, H)
    let img = CIImage(cgImage: base)
    let extent = img.extent
    let mask = CIImage(cgImage: holes.cgImage()).applyingGaussianBlur(sigma: 1.2).cropped(to: extent)
    let dimmed = CIImage(color: CIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 0.66)).cropped(to: extent)
        .composited(over: img.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.8]))
        .applyingFilter("CIVignette", parameters: ["inputIntensity": 0.6, "inputRadius": 2.0])
    let glowAlpha = CIImage(cgImage: holes.cgImage()).applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": short * 0.012])
        .applyingGaussianBlur(sigma: Double(short) * 0.018).cropped(to: extent)
        .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0.32, y: 0, z: 0, w: 0), "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
    let glow = CIImage(color: accent).cropped(to: extent).applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: glowAlpha])
    var out = img.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: glow.composited(over: dimmed), kCIInputMaskImageKey: mask])
    let edgeW = max(2, short * 0.0028)
    var edges = [ring(holes, inner: 0, outer: edgeW)]
    for s in startMasks { edges.append(ring(s, inner: edgeW * 2.6, outer: edgeW * 3.6)) }
    for e in edges {
        out = CIImage(color: accent).cropped(to: extent).applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: out, kCIInputMaskImageKey: e.applyingGaussianBlur(sigma: 0.8).cropped(to: extent)])
    }
    let ciCrop = CGRect(x: crop.minX, y: H - crop.maxY, width: crop.width, height: crop.height)
    return ci.createCGImage(out.cropped(to: ciCrop), from: ciCrop)!
}

/// Draw hold numbers and the finish flag on a cropped spotlight image.
func annotate(_ img: CGImage, crop: CGRect, boxes: [CGRect], numbers: [Int], finish: Int, short: CGFloat) -> CGImage {
    let w = img.width, h = img.height
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSImage(cgImage: img, size: NSSize(width: w, height: h)).draw(in: NSRect(x: 0, y: 0, width: w, height: h))
    let font = NSFont.systemFont(ofSize: short * 0.026, weight: .semibold)
    let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.9); shadow.shadowBlurRadius = 4; shadow.shadowOffset = .zero
    for (i, b) in boxes.enumerated() {
        let x = b.maxX - crop.minX, yTop = CGFloat(h) - (b.minY - crop.minY)
        let label = String(UnicodeScalar(0x2460 + UInt32(numbers[i] - 1))!)
        (label as NSString).draw(at: NSPoint(x: x - short * 0.004, y: yTop - short * 0.012), withAttributes: [.font: font, .foregroundColor: NSColor.white, .shadow: shadow])
        if i == finish {
            let fh = short * 0.04, bx = b.midX - crop.minX, by = yTop + short * 0.006
            let pole = NSBezierPath(); pole.move(to: NSPoint(x: bx, y: by)); pole.line(to: NSPoint(x: bx, y: by + fh)); pole.lineWidth = max(2, short * 0.003)
            accentNS.setStroke(); pole.stroke()
            let flag = NSBezierPath(); flag.move(to: NSPoint(x: bx, y: by + fh)); flag.line(to: NSPoint(x: bx + fh * 0.75, y: by + fh * 0.78)); flag.line(to: NSPoint(x: bx, y: by + fh * 0.52)); flag.close()
            accentNS.setFill(); flag.fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

func focusRect(_ taps: [Tap], _ r: Raster, aspect: CGFloat = 0.75) -> CGRect {
    let W = CGFloat(r.w), H = CGFloat(r.h), short = CGFloat(r.short)
    var minX = W, minY = H, maxX: CGFloat = 0, maxY: CGFloat = 0
    for t in taps {
        let x = CGFloat(t.x) * W, y = CGFloat(t.y) * H, rad = CGFloat(t.r) * short
        minX = min(minX, x - rad); maxX = max(maxX, x + rad); minY = min(minY, y - rad); maxY = max(maxY, y + rad)
    }
    var rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(dx: -(maxX - minX) * 0.3 - short * 0.04, dy: -(maxY - minY) * 0.12 - short * 0.06)
    if rect.width / rect.height < aspect { rect = rect.insetBy(dx: -(rect.height * aspect - rect.width) / 2, dy: 0) }
    else { rect = rect.insetBy(dx: 0, dy: -(rect.width / aspect - rect.height) / 2) }
    return rect.intersection(CGRect(x: 0, y: 0, width: W, height: H))
}

func sheet(title: String, panels: [(String, String, CGImage)], cols: Int, panelW: CGFloat = 520, to url: URL) {
    let pw = panelW, ph = panelW * 4 / 3, gap: CGFloat = 24, margin: CGFloat = 32, head: CGFloat = 64, cap: CGFloat = 76
    let rows = (panels.count + cols - 1) / cols
    let W = margin * 2 + CGFloat(cols) * pw + CGFloat(cols - 1) * gap
    let H = margin * 2 + head + CGFloat(rows) * (ph + cap) + CGFloat(rows - 1) * gap
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
    (title as NSString).draw(at: NSPoint(x: margin, y: H - margin - 38), withAttributes: [.font: NSFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: NSColor.white])
    for (i, p) in panels.enumerated() {
        let c = i % cols, rr = i / cols
        let x = margin + CGFloat(c) * (pw + gap)
        let top = H - margin - head - CGFloat(rr) * (ph + cap + gap)
        let rect = NSRect(x: x, y: top - ph, width: pw, height: ph)
        let path = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
        NSGraphicsContext.saveGraphicsState(); path.addClip()
        let s = max(pw / CGFloat(p.2.width), ph / CGFloat(p.2.height))
        let dw = CGFloat(p.2.width) * s, dh = CGFloat(p.2.height) * s
        NSImage(cgImage: p.2, size: .zero).draw(in: NSRect(x: x + (pw - dw) / 2, y: top - ph + (ph - dh) / 2, width: dw, height: dh))
        NSGraphicsContext.restoreGraphicsState()
        (p.0 as NSString).draw(at: NSPoint(x: x + 4, y: top - ph - 36), withAttributes: [.font: NSFont.systemFont(ofSize: 23, weight: .semibold), .foregroundColor: NSColor.white])
        (p.1 as NSString).draw(at: NSPoint(x: x + 4, y: top - ph - 64), withAttributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor(white: 1, alpha: 0.6)])
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}
