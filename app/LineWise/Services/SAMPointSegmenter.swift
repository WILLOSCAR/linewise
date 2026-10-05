import CoreML
import Foundation
import Vision

struct HoldSegmentationResult: Sendable {
    let contour: HoldContour
    let anchor: NormalizedPoint
    let modelVersion: String
    let seconds: Double
}

enum SAMInferenceError: Error { case modelInterface, photoNotPrepared }

/// Serial actor: model prediction and cached photo embeddings never run on the UI thread.
actor SAMPointSegmenter: HoldPointSegmenting {
    private struct Networks: @unchecked Sendable {
        // Owned and used only by this actor after the loading task completes.
        let image: MLModel, prompt: MLModel, mask: MLModel
    }
    private var networks: Networks?
    private var loading: Task<Networks, Error>?
    private var encoding: (photoID: UUID, features: any MLFeatureProvider, width: Int, height: Int)?
    private(set) var encodingSeconds: Double = 0

    func prepare(image: CGImage, photoID: UUID, directory: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> Double {
        if encoding?.photoID == photoID { progress(1); return encodingSeconds }
        if networks == nil {
            if loading == nil { loading = Task { try await Self.loadNetworks(directory: directory, progress: progress) } }
            do {
                networks = try await loading?.value
                loading = nil
            } catch { loading = nil; throw error }
        }
        try Task.checkCancellation()
        progress(0.75)
        guard let imageModel = networks?.image,
              let input = imageModel.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == .image }),
              let constraint = input.value.imageConstraint else { throw SAMInferenceError.modelInterface }
        let value = try MLFeatureValue(cgImage: image, constraint: constraint,
                                      options: [.cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue])
        let start = CFAbsoluteTimeGetCurrent()
        let features = try await imageModel.prediction(from: MLDictionaryFeatureProvider(dictionary: [input.key: value]))
        encodingSeconds = CFAbsoluteTimeGetCurrent() - start
        try Task.checkCancellation()
        let scale = min(1, 1024.0 / Double(max(image.width, image.height)))
        encoding = (photoID, features, max(1, Int(Double(image.width) * scale)), max(1, Int(Double(image.height) * scale)))
        progress(1)
        return encodingSeconds
    }

    func segment(_ hold: Hold, photoID: UUID) throws -> HoldSegmentationResult? {
        guard let networks, let encoding, encoding.photoID == photoID else { throw SAMInferenceError.photoNotPrepared }
        try Task.checkCancellation()
        let start = CFAbsoluteTimeGetCurrent()
        let points = try MLMultiArray(shape: [1, 1, 2], dataType: .float32)
        points[[0, 0, 0]] = NSNumber(value: Float(hold.x * 1024))
        points[[0, 0, 1]] = NSNumber(value: Float(hold.y * 1024))
        let labels = try MLMultiArray(shape: [1, 1], dataType: .int32)
        labels[[0, 0]] = 1
        let prompt = try networks.prompt.prediction(from: MLDictionaryFeatureProvider(dictionary: ["points": points, "labels": labels]))
        var inputs: [String: MLFeatureValue] = [:]
        for name in ["image_embedding", "feats_s0", "feats_s1"] {
            guard let feature = encoding.features.featureValue(for: name) else { throw SAMInferenceError.modelInterface }
            inputs[name] = feature
        }
        for (source, destination) in [("sparse_embeddings", "sparse_embedding"), ("dense_embeddings", "dense_embedding")] {
            guard let feature = prompt.featureValue(for: source) else { throw SAMInferenceError.modelInterface }
            inputs[destination] = feature
        }
        let output = try networks.mask.prediction(from: MLDictionaryFeatureProvider(dictionary: inputs))
        guard let masks = output.featureValue(for: "low_res_masks")?.multiArrayValue,
              let scores = output.featureValue(for: "scores")?.multiArrayValue, masks.shape.count == 4,
              scores.count >= masks.shape[1].intValue else { throw SAMInferenceError.modelInterface }
        let width = masks.shape[3].intValue, height = masks.shape[2].intValue
        var best: SAMMaskContour?
        var hasLogits = false
        for k in 0..<masks.shape[1].intValue {
            try Task.checkCancellation()
            let logits = Self.values(masks, index: k, width: width, height: height)
            if logits.contains(where: { $0.isFinite && $0 != 0 }) { hasLogits = true }
            guard scores[k].doubleValue > 0.3 else { continue }
            if let candidate = try SAMMaskContour.extract(logits: logits, logitsWidth: width, logitsHeight: height,
                                                         width: encoding.width, height: encoding.height, hold: hold),
               best == nil || candidate.pixelArea < best!.pixelArea { best = candidate }
        }
        // An all-zero decoder output indicates an unusable runtime, not a successful empty mask.
        guard hasLogits else { throw SAMInferenceError.modelInterface }
        guard let best else { return nil }
        return .init(contour: best.contour, anchor: best.anchor, modelVersion: SAMModelCatalog.tiny.version,
                     seconds: CFAbsoluteTimeGetCurrent() - start)
    }

    private static func loadNetworks(directory: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> Networks {
        let names = ["ImageEncoder", "PromptEncoder", "MaskDecoder"]
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HoldCompiledModels/" + SAMModelCatalog.tiny.version, isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        var loaded: [MLModel] = []
        for (i, name) in names.enumerated() {
            let package = directory.appendingPathComponent("SAM2_1Tiny\(name)FLOAT16.mlpackage")
            let compiled = cache.appendingPathComponent(name + ".mlmodelc", isDirectory: true)
            let configuration = MLModelConfiguration()
            // Matches the upstream iPhone implementation; avoids decoder specialization on ANE.
            configuration.computeUnits = .cpuAndGPU
            if let cached = try? MLModel(contentsOf: compiled, configuration: configuration) { loaded.append(cached) }
            else {
                let temporary = try await MLModel.compileModel(at: package)
                if FileManager.default.fileExists(atPath: compiled.path) { try FileManager.default.removeItem(at: compiled) }
                try FileManager.default.moveItem(at: temporary, to: compiled)
                loaded.append(try MLModel(contentsOf: compiled, configuration: configuration))
            }
            progress(Double(i + 1) / 4)
        }
        return .init(image: loaded[0], prompt: loaded[1], mask: loaded[2])
    }

    private static func values(_ masks: MLMultiArray, index: Int, width: Int, height: Int) -> [Float] {
        let stride = masks.strides.map(\.intValue), base = index * stride[1]
        return (0..<(width * height)).map { i in
            let offset = base + (i / width) * stride[2] + (i % width) * stride[3]
            switch masks.dataType {
            case .float32: return masks.dataPointer.assumingMemoryBound(to: Float.self)[offset]
            case .double: return Float(masks.dataPointer.assumingMemoryBound(to: Double.self)[offset])
            case .float16: return Float(Float16(bitPattern: masks.dataPointer.assumingMemoryBound(to: UInt16.self)[offset]))
            default: return masks[[0, NSNumber(value: index), NSNumber(value: i / width), NSNumber(value: i % width)]].floatValue
            }
        }
    }
}
