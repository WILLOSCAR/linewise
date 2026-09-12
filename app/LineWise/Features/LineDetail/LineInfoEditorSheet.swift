import SwiftUI

/// 改名 / 难度与主观难度 / 墙区与角度。
struct LineInfoEditorSheet: View {
    let line: Line

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var grade: String
    @State private var feltGrade: FeltGrade?
    @State private var areaName: String
    @State private var angle: WallAngle
    @FocusState private var focusedField: Field?

    private enum Field { case name, grade, area }

    init(line: Line) {
        self.line = line
        _name = State(initialValue: line.name)
        _grade = State(initialValue: line.gradeText ?? "")
        _feltGrade = State(initialValue: line.feltGrade)
        _areaName = State(initialValue: line.wall?.areaName ?? "")
        _angle = State(initialValue: line.wall?.angle ?? .unknown)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Panel("名字") {
                        TextField("线的名字", text: $name)
                            .font(.body)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .grade }
                        if name.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("名字不能为空").font(.caption).foregroundStyle(Color.coral)
                        }
                    }

                    Panel("难度") {
                        TextField("V4 / 5 / 紫色", text: $grade)
                            .font(.body)
                            .focused($focusedField, equals: .grade)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .area }
                        Text("感觉")
                            .font(.footnote)
                            .foregroundStyle(Color.subtle)
                        ChipFlow {
                            ForEach(FeltGrade.allCases, id: \.self) { g in
                                Chip(title: g.title, selected: feltGrade == g) {
                                    Haptics.selection()
                                    feltGrade = feltGrade == g ? nil : g
                                }
                            }
                        }
                    }

                    if let wall = line.wall {
                        Panel("墙区与角度") {
                            TextField("例如：斜板墙", text: $areaName)
                                .font(.body)
                                .focused($focusedField, equals: .area)
                                .submitLabel(.done)
                            ChipFlow {
                                ForEach(WallAngle.allCases, id: \.self) { a in
                                    Chip(title: a.title, selected: angle == a) {
                                        Haptics.selection()
                                        angle = a
                                    }
                                }
                            }
                            if wall.activeLines.count > 1 {
                                Label("这面墙上还有 \(wall.activeLines.count - 1) 条线，会一起改。", systemImage: "info.circle")
                                    .font(.footnote)
                                    .foregroundStyle(Color.subtle)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .inkBackground()
            .navigationTitle("这条线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let store = Store(context)
        var undos: [() -> Void] = []
        undos.append(store.updateLineDetails(line, name: name, gradeText: grade, feltGrade: feltGrade))
        if let wall = line.wall {
            let trimmedArea = areaName.trimmingCharacters(in: .whitespaces)
            if trimmedArea != (wall.areaName ?? "") || angle != wall.angle {
                undos.append(store.updateWallDetails(wall, areaName: trimmedArea, angle: angle))
                if !trimmedArea.isEmpty { appState.lastAreaName = trimmedArea }
            }
        }
        undoCenter.offer("已更新这条线的信息") {
            for undo in undos.reversed() { undo() }
        }
        Haptics.light()
        dismiss()
    }
}
