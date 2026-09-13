import SwiftData
import SwiftUI

@main
struct LineWiseApp: App {
    private let container: ModelContainer
    @State private var undoCenter = UndoCenter()
    @State private var appState = AppState()

    init() {
        var uiTesting = false
        #if DEBUG
        uiTesting = CommandLine.arguments.contains("-uiTesting")
        if uiTesting {
            let suite = "LineWise.UITests"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            _appState = State(initialValue: AppState(defaults: defaults))
        }
        #endif
        // 首次启动时 Application Support 可能不存在，SwiftData 不会自动创建。
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        }
        let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
        let config = ModelConfiguration("LineWise", schema: schema, isStoredInMemoryOnly: uiTesting)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 数据库无法打开时退回内存库，至少保证 App 能启动；导出/删除可在设置里处理。
            let fallback = ModelConfiguration("LineWise-memory", schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .background(UndoToastWindowInstaller(undoCenter: undoCenter))
                .environment(undoCenter)
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(.accent)
        }
        .modelContainer(container)
    }
}
