import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// 墙照片的本地存储：长边 ≤ 2048 的 JPEG，按需降采样加载并缓存。
enum ImageStore {
    struct Saved: Sendable {
        let fileName: String
        let width: Int
        let height: Int
    }

    nonisolated static let maxLongEdge: CGFloat = 2048

    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 180 * 1024 * 1024
        return c
    }()

    nonisolated static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    nonisolated static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// 保存：修正方向、降采样到长边 2048、JPEG 0.86。
    nonisolated static func save(_ image: UIImage) throws -> Saved {
        let normalized = downsample(image, maxLongEdge: maxLongEdge)
        guard let data = normalized.jpegData(compressionQuality: 0.86) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileName = UUID().uuidString + ".jpg"
        try data.write(to: url(for: fileName), options: .atomic)
        let w = Int(normalized.size.width * normalized.scale)
        let h = Int(normalized.size.height * normalized.scale)
        cache.setObject(normalized, forKey: cacheKey(fileName, Int(maxLongEdge)), cost: w * h * 4)
        return Saved(fileName: fileName, width: w, height: h)
    }

    nonisolated static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// 同步加载（先查缓存）。`maxPixel` 为长边像素上限。
    nonisolated static func load(fileName: String, maxPixel: Int) -> UIImage? {
        let key = cacheKey(fileName, maxPixel)
        if let hit = cache.object(forKey: key) { return hit }
        let fileURL = url(for: fileName)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key, cost: cg.width * cg.height * 4)
        return image
    }

    /// 异步加载（后台线程解码）。
    static func loadAsync(fileName: String, maxPixel: Int) async -> UIImage? {
        if let hit = cache.object(forKey: cacheKey(fileName, maxPixel)) { return hit }
        return await Task.detached(priority: .userInitiated) {
            load(fileName: fileName, maxPixel: maxPixel)
        }.value
    }

    nonisolated private static func cacheKey(_ fileName: String, _ maxPixel: Int) -> NSString {
        "\(fileName)#\(maxPixel)" as NSString
    }

    /// 方向归一化 + 降采样（返回 scale = 1 的图）。
    nonisolated static func downsample(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longEdge = max(pixelSize.width, pixelSize.height)
        let scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1
        let target = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// 全部照片总大小（设置页展示）。
    nonisolated static func totalBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}
