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
        .overlay(alignment: .bottom) {
            UndoToast().padding(.bottom, 8)
        }
        .fullScreenCover(isPresented: $showBuilder) {
            LineBuilderFlow { created in
                showBuilder = false
                if let created {
                    Task {
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
