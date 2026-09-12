import SwiftData
import SwiftUI

/// 设置 · 数据：占用、导出、删除全部。
struct DataSettingsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var photoBytes: Int64 = 0
    @State private var lineCount = 0
    @State private var sessionCount = 0
    @State private var isExportingArchive = false
    @State private var exportError: String?
    @State private var showDeleteAll = false
    @State private var deleteConfirmText = ""

    /// 删除全部时必须输入的字。
    static let deleteKeyword = "删除"

    var body: some View {
        Section {
            SettingsValueRow(title: "照片占用", value: bytesText, systemImage: "photo.stack")
                .onAppear(perform: refresh)
            SettingsValueRow(title: "线 · 记录", value: "\(lineCount) 条线 · \(sessionCount) 条记录", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            Button(action: exportJSON) {
                Label("导出 JSON", systemImage: "doc.text")
                    .foregroundStyle(.white)
            }
            Button(action: exportArchive) {
                HStack {
                    Label("导出含照片（zip）", systemImage: "photo.on.rectangle.angled")
                        .foregroundStyle(.white)
                    Spacer()
                    if isExportingArchive {
                        ProgressView().controlSize(.small).tint(.accent)
                    }
                }
            }
            .disabled(isExportingArchive)
            .alert("导出失败", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("好", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            Button(role: .destructive) {
                deleteConfirmText = ""
                showDeleteAll = true
            } label: {
                Label("删除全部数据", systemImage: "trash")
                    .foregroundStyle(Color.coral)
            }
            .alert("删除全部数据", isPresented: $showDeleteAll) {
                TextField("输入「\(Self.deleteKeyword)」确认", text: $deleteConfirmText)
                Button("取消", role: .cancel) { deleteConfirmText = "" }
                Button("删除", role: .destructive, action: deleteAll)
                    .disabled(!Self.isDeleteConfirmed(deleteConfirmText))
            } message: {
                Text("会删掉全部岩馆、墙、线、记录和照片，不能撤销。")
            }
        } header: {
            SettingsHeader("数据")
        } footer: {
            SettingsFooter("全部数据只在这台手机上。导出的文件由你选择发到哪里。")
        }
        .settingsRow()
    }

    // MARK: 逻辑

    static func isDeleteConfirmed(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == deleteKeyword
    }

    private var bytesText: String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f.string(fromByteCount: photoBytes)
    }

    private func refresh() {
        let store = Store(context)
        photoBytes = ImageStore.totalBytes()
        lineCount = store.visibleLineCount()
        sessionCount = store.sessionCount()
    }

    private func exportJSON() {
        do {
            let url = try ExportService.exportJSON(gyms: Store(context).gyms())
            Haptics.light()
            SharePresenter.present(activityItems: [url])
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportArchive() {
        guard !isExportingArchive else { return }
        isExportingArchive = true
        let gyms = Store(context).gyms()
        Task { @MainActor in
            do {
                let url = try await ExportService.exportArchive(gyms: gyms)
                isExportingArchive = false
                Haptics.success()
                SharePresenter.present(activityItems: [url])
            } catch {
                isExportingArchive = false
                exportError = error.localizedDescription
            }
        }
    }

    private func deleteAll() {
        let store = Store(context)
        store.deleteEverything()
        let gym = store.ensureDefaultGym()
        appState.currentGymID = gym.id
        appState.filter = .projecting
        UserDefaults.standard.removeObject(forKey: BuildDurationStats.defaultsKey)
        deleteConfirmText = ""
        Haptics.warning()
        refresh()
    }
}
