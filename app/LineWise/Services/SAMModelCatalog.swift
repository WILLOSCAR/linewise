import Foundation

struct SAMModelFile: Sendable {
    let path: String
    let bytes: Int64
    let sha256: String
}

struct SAMModelCatalog: Sendable {
    let revision: String
    let files: [SAMModelFile]
    var totalBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
    var version: String { "sam2.1-tiny-" + revision }
    func sourceURL(for file: SAMModelFile) -> URL {
        URL(string: "https://huggingface.co/apple/coreml-sam2.1-tiny/resolve/\(revision)/\(file.path)")!
    }

    // Apple's FLOAT16 conversion, pinned by revision, byte count and SHA-256.
    // Source and Apache 2.0 attribution: docs/demo-a-implementation.md.
    static let tiny = SAMModelCatalog(
        revision: "39ae0a8a83e5e6cd196e804bf7cccc5f8171f306",
        files: [
            .init(path: "SAM2_1TinyImageEncoderFLOAT16.mlpackage/Data/com.apple.CoreML/model.mlmodel", bytes: 154372, sha256: "6cbc50301ee3ff4a9366083f9647e1f06762759542d8dd0fac394ebc3682cce7"),
            .init(path: "SAM2_1TinyImageEncoderFLOAT16.mlpackage/Data/com.apple.CoreML/weights/weight.bin", bytes: 67069504, sha256: "eab96eb8ff35720c79eedc0cac2a4ef32d685f9c994c39736027078528c48a97"),
            .init(path: "SAM2_1TinyImageEncoderFLOAT16.mlpackage/Manifest.json", bytes: 617, sha256: "dd72aa75e3f2f92d0653696bf4d8350d87690d92b116b34912fe640f2b116e08"),
            .init(path: "SAM2_1TinyMaskDecoderFLOAT16.mlpackage/Data/com.apple.CoreML/model.mlmodel", bytes: 75167, sha256: "4601f302d4c6936e15de3a22089c2afe1fa009ef703f82147ff829b4be677577"),
            .init(path: "SAM2_1TinyMaskDecoderFLOAT16.mlpackage/Data/com.apple.CoreML/weights/weight.bin", bytes: 10222400, sha256: "f5a8635981199fa1199007ed6798c61a326288548b74553b3c2ddb932fcdc8de"),
            .init(path: "SAM2_1TinyMaskDecoderFLOAT16.mlpackage/Manifest.json", bytes: 617, sha256: "dc6121b61ac560498080d55f9d5fb293cdb305f942a85adb5b71dc8e9d14a8aa"),
            .init(path: "SAM2_1TinyPromptEncoderFLOAT16.mlpackage/Data/com.apple.CoreML/model.mlmodel", bytes: 20618, sha256: "3a83c167d8bd63e80f86349a78c2ab0527ce97eca1f848a4ce57fe5351241fa3"),
            .init(path: "SAM2_1TinyPromptEncoderFLOAT16.mlpackage/Data/com.apple.CoreML/weights/weight.bin", bytes: 2101056, sha256: "af466cf28ef8838f409c2bfd8cc0049b9efbf9db335d60a57dbfc5160af883f2"),
            .init(path: "SAM2_1TinyPromptEncoderFLOAT16.mlpackage/Manifest.json", bytes: 617, sha256: "0c0f9b80f0445017dac52f81e93aeb50b9c2c9918708c882df4a65671fda2bd4")
        ]
    )
}
