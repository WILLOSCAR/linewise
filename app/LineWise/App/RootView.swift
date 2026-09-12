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

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onOpen: { line in path.append(line) },
                onAdd: { showBuilder = true },
                onSettings: { showSettings = true }
            )
            .navigationDestination(for: Line.self) { line in
                LineDetailView(line: line, onOpenLine: { other in path.append(other) })
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

/// 首次引导：三句话，一个按钮。
struct IntroView: View {
    var onStart: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 28) {
                Text("线感")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                step(n: 1, title: "拍一面墙", detail: "一张照片就是一面墙，上面可以有好几条线。")
                step(n: 2, title: "点亮你的线", detail: "墙暗下去，只有你要爬的点亮着。")
                step(n: 3, title: "记下掉在哪", detail: "下次进馆先看这一眼：掉在哪、为什么、试什么。")
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 12) {
                Button("拍第一面墙", action: onStart).buttonStyle(BigButtonStyle())
                Button("先看看", action: onSkip).font(.subheadline).foregroundStyle(Color.subtle)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .inkBackground()
        .presentationDragIndicator(.hidden)
    }

    private func step(n: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(Color.accent.opacity(0.15)).frame(width: 40, height: 40)
                Circle().strokeBorder(Color.accent, lineWidth: 2).frame(width: 40, height: 40)
                Text("\(n)").font(.headline.weight(.bold)).foregroundStyle(Color.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(.white)
                Text(detail).font(.subheadline).foregroundStyle(Color.subtle)
            }
        }
    }
}
