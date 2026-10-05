import SwiftData
import SwiftUI

@main
struct LineWiseApp: App {
    @State private var container: ModelContainer?
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
        _container = State(initialValue: try? LineWisePersistence.container(inMemory: uiTesting))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .background(UndoToastWindowInstaller(undoCenter: undoCenter))
                        .environment(undoCenter)
                        .environment(appState)
                        .modelContainer(container)
                } else {
                    ContentUnavailableView {
                        Label("本机记录暂时打不开", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("记录和照片仍保留在这台设备上。")
                    } actions: {
                        Button("重新打开") { container = try? LineWisePersistence.container() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .tint(.accent)
        }
    }
}
