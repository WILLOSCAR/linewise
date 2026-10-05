import SwiftUI
import SwiftData

/// 改提醒那一句话。
struct ReminderEditSheet: View {
    let line: Line

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(line: Line) {
        self.line = line
        _text = State(initialValue: line.reminderText ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("下次进馆先看这一眼。写得越具体越好用。")
                    .font(.footnote)
                    .foregroundStyle(Color.subtle)
                TextField("例如：掉在 ⑤ · 脚 · 右脚先踩高再出手", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.body)
                    .foregroundStyle(Color.accent)
                    .padding(14)
                    .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused)
                    .submitLabel(.done)
                if line.reminderVerified {
                    Label("改动后会取消“已验证有用”的标记。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Color.subtle)
                }
                Spacer()
                Button("保存", action: save).buttonStyle(BigButtonStyle())
                if line.reminderText != nil {
                    Button("清空提醒", role: .destructive) {
                        text = ""
                        save()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.coral)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .inkBackground()
            .navigationTitle("提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .onAppear { focused = true }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let undo = Store(context).updateReminderUndoable(line, text: text)
        undoCenter.offer(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "已清空提醒" : "提醒已更新", undo: undo)
        Haptics.light()
        dismiss()
    }
}
