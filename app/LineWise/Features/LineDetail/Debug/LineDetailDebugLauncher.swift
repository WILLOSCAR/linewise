#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 调试入口：不改 RootView，用启动参数把线路页 / 记这一次 / 全屏查看器直接盖到窗口上，方便命令行截图。
///
///   -openNoPhotoLine                  线路页 · 无照片线（没有就在当前库里造一条，带一条旧编码记录 + 一条新字段记录）
///   -openSessionEditor <名字包含>      记这一次（"无照片" 会先确保无照片线存在）；可加 -sessionDemoSaved 停在提醒卡那一帧
///   -openViewer <名字包含> [focus]     全屏查看器；带 focus 则一进来就取景到线
///   -detailScrollTo <status|reminder|record|coach|sequence|history|more>  线路页自动滚到某区块（RootView 的 -openLine 也认）
///
/// 由 `LineDetailDebugBoot.m` 的 `+load` 在应用启动完成后调用。
@objc(LWLineDetailDebugLauncher)
final class LineDetailDebugLauncher: NSObject {
    enum Mode {
        case noPhotoDetail
        case sessionEditor(needle: String)
        case viewer(needle: String, focused: Bool)
    }

    static let noPhotoLineName = "训练区 · 无照片"

    @objc static func installIfRequested() {
        let args = CommandLine.arguments
        let mode: Mode?
        if args.contains("-openNoPhotoLine") {
            mode = .noPhotoDetail
        } else if let i = args.firstIndex(of: "-openSessionEditor"), i + 1 < args.count {
            mode = .sessionEditor(needle: args[i + 1])
        } else if let i = args.firstIndex(of: "-openViewer"), i + 1 < args.count {
            let focused = i + 2 < args.count && args[i + 2] == "focus"
            mode = .viewer(needle: args[i + 1], focused: focused)
        } else {
            mode = nil
        }
        guard let mode else { return }
        Task { @MainActor in
            // 等 RootView 的 onAppear 把演示数据写完。
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(600))
                if present(mode) { return }
            }
        }
    }

    @MainActor
    @discardableResult
    private static func present(_ mode: Mode) -> Bool {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
              var top = window.rootViewController else { return false }
        while let presented = top.presentedViewController { top = presented }

        let schema = LineWisePersistence.schema
        let config = ModelConfiguration("LineWise", schema: schema, isStoredInMemoryOnly: false)
        guard let container = try? ModelContainer(for: schema, migrationPlan: LineWiseMigrationPlan.self, configurations: [config]) else { return false }
        let context = container.mainContext
        let store = Store(context)
        let lines = (try? context.fetch(FetchDescriptor<Line>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        guard !lines.isEmpty else { return false } // 演示数据还没写完

        let line: Line?
        switch mode {
        case .noPhotoDetail:
            line = ensureNoPhotoLine(store: store, lines: lines)
        case .sessionEditor(let needle), .viewer(let needle, _):
            line = needle.contains("无照片")
                ? ensureNoPhotoLine(store: store, lines: lines)
                : lines.first { $0.isVisible && $0.name.contains(needle) }
        }
        guard let line else { return false }

        let root = LineDetailDebugScreen(line: line, mode: mode)
            .environment(AppState())
            .environment(UndoCenter())
            .modelContainer(container)
            .preferredColorScheme(.dark)
            .tint(.accent)
        let host = UIHostingController(rootView: root)
        host.modalPresentationStyle = .fullScreen
        top.present(host, animated: false)
        return true
    }

    /// 无照片线：一条旧编码记录（“掉在 大球 · …” 写在一句话里）+ 一条新字段记录（fallText）。
    @MainActor
    private static func ensureNoPhotoLine(store: Store, lines: [Line]) -> Line? {
        if let existing = lines.first(where: { $0.name == noPhotoLineName }) { return existing }
        guard let gym = store.gyms().first else { return nil }
        guard let wall = try? store.createWall(gym: gym, image: nil, areaName: "训练区", angle: .unknown) else { return nil }
        let line = store.createLine(wall: wall, holds: [], startHoldIDs: [], finishHoldID: nil,
                                    gradeText: "V2", gradeSource: .manual, name: noPhotoLineName)
        func daysAgo(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: -n, to: .now)! }

        let legacy = store.newSession(for: line, date: daysAgo(6))
        legacy.attemptCount = 4
        legacy.reason = .power
        legacy.note = "掉在 大球 · 出手前先休息"
        legacy.createdAt = daysAgo(6)
        store.commitSession(legacy, line: line, fallLabel: "大球")

        let fresh = store.newSession(for: line, date: daysAgo(2))
        fresh.attemptCount = 3
        fresh.reason = .feet
        fresh.fallText = "第三个点"
        fresh.note = "左脚先上"
        fresh.createdAt = daysAgo(2)
        store.commitSession(fresh, line: line, fallLabel: fresh.fallText)
        store.save()
        return line
    }
}

private struct LineDetailDebugScreen: View {
    let line: Line
    let mode: LineDetailDebugLauncher.Mode

    var body: some View {
        switch mode {
        case .noPhotoDetail:
            NavigationStack {
                LineDetailView(line: line, onOpenLine: { _ in })
            }
        case .sessionEditor:
            SessionEditorView(line: line)
        case .viewer(_, let focused):
            FullscreenSpotlightViewer(line: line, fallMarks: line.fallMarks(), startFocused: focused)
        }
    }
}
#endif
