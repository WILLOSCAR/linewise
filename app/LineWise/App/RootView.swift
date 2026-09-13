import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(UndoCenter.self) private var undoCenter

    @State private var path: [Line] = []
    @State private var showBuilder = false
    @State private var showSettings = false
    @State private var showIntro = false
    /// 从首页卡片点进去的那条线：线路页用缩放转场从卡片放大进来（iOS 18+）；其他入口普通 push。
    @State private var zoomSourceLineID: UUID?
    @Namespace private var homeZoom

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onOpen: { line in
                    zoomSourceLineID = line.id
                    path.append(line)
                },
                onAdd: { showBuilder = true },
                onSettings: { showSettings = true },
                zoomNamespace: homeZoom
            )
            .navigationDestination(for: Line.self) { line in
                LineDetailView(line: line, onOpenLine: { other in path.append(other) })
                    // 只有从卡片点进来的那条线做缩放；条件只看 id 是否相等，进了线路页之后不再变。
                    .homeZoomDestination(id: zoomSourceLineID == line.id ? line.id : nil, in: homeZoom)
            }
        }
        // 撤销条由 UndoToastWindow 挂在窗口级（见 LineWiseApp），这里不再叠一层。
        .fullScreenCover(isPresented: $showBuilder) {
            LineBuilderFlow { created in
                showBuilder = false
                if let created {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        path.append(created)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showIntro) {
            IntroView {
                appState.hasSeenIntro = true
                showIntro = false
                showBuilder = true
            } onSkip: {
                appState.hasSeenIntro = true
                showIntro = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear(perform: bootstrap)
    }

    private func bootstrap() {
        let store = Store(context)
        store.purgeDeleted()
        let gym = store.ensureDefaultGym()
        if appState.currentGymID == nil || store.gym(id: appState.currentGymID) == nil {
            appState.currentGymID = gym.id
        }
        if DemoSeed.isRequested {
            DemoSeed.seedIfNeeded(context: context, appState: appState)
            appState.hasSeenIntro = true
        }
        if !appState.hasSeenIntro {
            showIntro = true
        }
        applyDebugRoute(store: store)
    }

    /// 仅 DEBUG：用启动参数直达某个页面，方便模拟器截图。
    /// `-openFirstLine`（首页第一张卡对应的线）/ `-openLine <名字包含>` / `-openBuilder` / `-openSettings` / `-demoUndo`
    private func applyDebugRoute(store: Store) {
        #if DEBUG
        let args = CommandLine.arguments
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            let d = FetchDescriptor<Line>(predicate: #Predicate { $0.deletedAt == nil && $0.mergedIntoLineID == nil })
            let all = (try? context.fetch(d)) ?? []
            let homeOrder = all.sorted { ($0.latestSession?.date ?? $0.createdAt) > ($1.latestSession?.date ?? $1.createdAt) }
            if args.contains("-openFirstLine") {
                if let line = homeOrder.first { path = [line] }
            } else if let i = args.firstIndex(of: "-openLine"), i + 1 < args.count {
                let needle = args[i + 1]
                if let line = homeOrder.first(where: { $0.name.contains(needle) }) { path = [line] }
            } else if args.contains("-openBuilder") {
                showBuilder = true
            } else if args.contains("-openSettings") {
                showSettings = true
            }
            if args.contains("-demoUndo") {
                try? await Task.sleep(for: .milliseconds(800))
                undoCenter.offer("已删除 9 月 12 日的记录", seconds: 30) {}
            }
        }
        #endif
    }
}

// `IntroView`（首次引导）在 Features/Home/IntroView.swift。
