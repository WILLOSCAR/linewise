import SwiftData
import SwiftUI

/// 设置：岩馆、体型、数据、诊断、关于。以 sheet 呈现，自带导航栏与“完成”。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                GymSettingsSection()
                BodySettingsSection()
                DataSettingsSection()
                DiagnosticsSettingsSection()
                AboutSettingsSection()
            }
            .scrollContentBackground(.hidden)
            .inkBackground()
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .tint(.accent)
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
    }
}

#if DEBUG
/// 预览用：内存容器 + 两个岩馆 + 一条线 + 几条建线时长。
@MainActor
private func makeSettingsPreviewContainer() -> (ModelContainer, AppState) {
    let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
    let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let appState = AppState()
    let store = Store(container.mainContext)
    let gym = store.ensureDefaultGym(named: "岩时·望京")
    _ = store.addGym(name: "岩舞空间")
    let wall = try! store.createWall(gym: gym, image: nil, areaName: "斜板墙", angle: .slab)
    let holds = [Hold(x: 0.3, y: 0.9), Hold(x: 0.5, y: 0.5), Hold(x: 0.6, y: 0.1)]
    let line = store.createLine(wall: wall, holds: holds, startHoldIDs: [holds[0].id], finishHoldID: holds[2].id,
                                gradeText: "V3", gradeSource: .manual, name: nil)
    _ = store.incrementAttempt(line)
    appState.currentGymID = gym.id
    UserDefaults.standard.set([12.0, 18.5, 9.2, 31.0, 14.7], forKey: BuildDurationStats.defaultsKey)
    return (container, appState)
}

#Preview("设置") {
    let (container, appState) = makeSettingsPreviewContainer()
    Color.ink
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            SettingsView()
                .modelContainer(container)
                .environment(appState)
                .environment(UndoCenter())
        }
        .preferredColorScheme(.dark)
}
#endif
