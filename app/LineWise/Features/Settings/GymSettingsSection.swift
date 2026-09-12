import SwiftData
import SwiftUI

/// 设置 · 岩馆：切换、添加、重命名、删除。
struct GymSettingsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @State private var renaming: Gym?
    @State private var renameText = ""
    @State private var deleting: Gym?
    @State private var showAdd = false
    @State private var newName = ""

    var body: some View {
        Section {
            ForEach(gyms) { gym in
                gymRow(gym)
            }
            allGymsRow
            addRow
        } header: {
            SettingsHeader("岩馆")
        } footer: {
            SettingsFooter("首页只显示当前岩馆的线。长按岩馆可以重命名或删除。")
        }
        .settingsRow()
    }

    // MARK: 行

    private func gymRow(_ gym: Gym) -> some View {
        let isCurrent = appState.currentGymID == gym.id
        return Button {
            guard !isCurrent else { return }
            Haptics.selection()
            appState.currentGymID = gym.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gym.name)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(summary(gym))
                        .font(.footnote)
                        .foregroundStyle(Color.subtle)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accent)
                        .accessibilityLabel("当前岩馆")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renameText = gym.name
                renaming = gym
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleting = gym
            } label: {
                Label("删除岩馆", systemImage: "trash")
            }
        }
    }

    // 弹层只挂在一行上（挂在每个岩馆行会同时触发多份）。
    private var allGymsRow: some View {
        allGymsRowContent
            .alert("重命名岩馆", isPresented: isPresented($renaming), presenting: renaming) { gym in
                TextField("岩馆名字", text: $renameText)
                Button("取消", role: .cancel) {}
                Button("保存") {
                    Store(context).renameGym(gym, to: renameText)
                }
            }
            .confirmationDialog(
                deleting.map { "删除「\($0.name)」？" } ?? "删除岩馆？",
                isPresented: isPresented($deleting),
                titleVisibility: .visible,
                presenting: deleting
            ) { gym in
                Button("删除岩馆和里面的全部内容", role: .destructive) { delete(gym) }
                Button("取消", role: .cancel) {}
            } message: { gym in
                Text(deleteMessage(gym))
            }
    }

    private var allGymsRowContent: some View {
        let isCurrent = appState.currentGymID == nil
        return Button {
            guard !isCurrent else { return }
            Haptics.selection()
            appState.currentGymID = nil
        } label: {
            HStack(spacing: 12) {
                Text("全部岩馆")
                    .foregroundStyle(.white)
                Text("首页不按岩馆筛选")
                    .font(.footnote)
                    .foregroundStyle(Color.subtle)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addRow: some View {
        Button {
            newName = ""
            showAdd = true
        } label: {
            Label("添加岩馆", systemImage: "plus.circle.fill")
                .foregroundStyle(Color.accent)
        }
        .alert("新岩馆", isPresented: $showAdd) {
            TextField("岩馆名字", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("添加") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let gym = Store(context).addGym(name: name)
                appState.currentGymID = gym.id
                Haptics.success()
                newName = ""
            }
        } message: {
            Text("只填名字就行，不用定位。")
        }
    }

    // MARK: 逻辑

    private func summary(_ gym: Gym) -> String {
        let walls = gym.walls.count
        let lines = Store(context).visibleLineCount(in: gym)
        if walls == 0 { return "还没有墙" }
        return "\(walls) 面墙 · \(lines) 条线"
    }

    private func deleteMessage(_ gym: Gym) -> String {
        let walls = gym.walls.count
        let lines = gym.walls.reduce(0) { $0 + $1.lines.count }
        let sessions = gym.walls.reduce(0) { sum, w in sum + w.lines.reduce(0) { $0 + $1.sessions.count } }
        if walls == 0 { return "这个岩馆还没有墙和线。删除后不能撤销。" }
        return "会一起删掉这个岩馆里的 \(walls) 面墙、\(lines) 条线、\(sessions) 条记录和墙照片，不能撤销。"
    }

    private func delete(_ gym: Gym) {
        let store = Store(context)
        let wasCurrent = appState.currentGymID == gym.id
        store.deleteGym(gym)
        let remaining = store.gyms()
        if remaining.isEmpty {
            let fresh = store.ensureDefaultGym()
            appState.currentGymID = fresh.id
        } else if wasCurrent {
            appState.currentGymID = remaining.first?.id
        }
        Haptics.warning()
    }

    /// 把 `Optional` 状态变成弹层用的 `isPresented`。
    private func isPresented<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }
}
