#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 调试入口：不改 RootView，用启动参数直接渲染分享图或打开分享预览，方便命令行验证。
///
///   xcrun simctl launch <udid> com.linewise.app -seedDemo -demoPhotosDir /tmp/linewise-demo-photos -renderShare 黄
///       → 把「名字包含“黄”」那条线的分享图写到 /tmp/share-黄.png（可用 -renderShareOut <路径> 改）
///   xcrun simctl launch <udid> com.linewise.app -seedDemo -demoPhotosDir /tmp/linewise-demo-photos -openLine 黄 -openShareSheet 黄
///       → 在线路页之上弹出分享预览 sheet
///
/// 由 `ShareDebugBoot.m` 的 `+load` 在应用启动完成后调用。
@objc(LWShareDebugLauncher)
final class ShareDebugLauncher: NSObject {
    @objc static func installIfRequested() {
        let args = CommandLine.arguments
        let renderNeedle = value(after: "-renderShare", in: args)
        let sheetNeedle = value(after: "-openShareSheet", in: args)
        guard renderNeedle != nil || sheetNeedle != nil else { return }
        Task { @MainActor in
            // 等 RootView 的 onAppear 把演示数据写完、`-openLine` 推完页面。
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(700))
                guard let (container, lines) = openStore(), !lines.isEmpty else { continue }
                if let renderNeedle {
                    render(needle: renderNeedle, lines: lines, out: value(after: "-renderShareOut", in: args))
                }
                if let sheetNeedle, let line = pick(needle: sheetNeedle, in: lines) {
                    try? await Task.sleep(for: .milliseconds(600))
                    ShareLineButton.presentPreview(for: line)
                }
                _ = container
                return
            }
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    @MainActor
    private static func openStore() -> (ModelContainer, [Line])? {
        let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
        let config = ModelConfiguration("LineWise", schema: schema, isStoredInMemoryOnly: false)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else { return nil }
        let context = container.mainContext
        let d = FetchDescriptor<Line>(predicate: #Predicate { $0.deletedAt == nil && $0.mergedIntoLineID == nil },
                                      sortBy: [SortDescriptor(\.createdAt)])
        let lines = (try? context.fetch(d)) ?? []
        return (container, lines)
    }

    private static func pick(needle: String, in lines: [Line]) -> Line? {
        if needle == "first" { return lines.first }
        if needle == "nophoto" { return lines.first(where: { !$0.hasPhoto }) ?? lines.first }
        return lines.first(where: { $0.name.contains(needle) })
    }

    @MainActor
    private static func render(needle: String, lines: [Line], out: String?) {
        guard let line = pick(needle: needle, in: lines) else {
            print("[ShareDebug] no line matches \(needle)")
            return
        }
        var photo: UIImage?
        if let name = line.wall?.photoFileName, line.hasPhoto {
            photo = ImageStore.load(fileName: name, maxPixel: SharePreviewSheet.fullPhotoPixel)
        }
        let started = CFAbsoluteTimeGetCurrent()
        guard let image = ShareCardRenderer.render(line: line, image: photo), let data = image.pngData() else {
            print("[ShareDebug] render failed for \(line.name)")
            return
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1000
        let path = out ?? "/tmp/share-\(needle).png"
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            print("[ShareDebug] wrote \(path) (\(Int(image.size.width * image.scale))×\(Int(image.size.height * image.scale)) px, \(Int(elapsed)) ms)")
        } catch {
            print("[ShareDebug] write failed: \(error)")
        }
    }
}
#endif
