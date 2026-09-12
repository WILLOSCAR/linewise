import SwiftUI

/// 无照片建线：墙区、颜色 / 标签、难度、角度。
struct NoPhotoFormView: View {
    @Bindable var model: BuilderModel
    var areaSuggestions: [String] = []
    var onBack: () -> Void
    var onDone: () -> Void

    @FocusState private var focus: Field?
    private enum Field { case area, label, grade }

    var body: some View {
        VStack(spacing: 0) {
            BuilderTopBar(step: 1) {
                TopBarButton(title: "返回", systemImage: "chevron.left") {
                    Haptics.light()
                    onBack()
                }
            } trailing: {
                EmptyView()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("不拍照，先记一条")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("没有照片也能记录和复盘；顺序功能会不可用。")
                            .font(.subheadline)
                            .foregroundStyle(Color.subtle)
                    }
                    .padding(.top, 8)

                    field("墙区", placeholder: "如 斜板墙、A 区", text: $model.areaName, focus: .area) {
                        if !areaSuggestions.isEmpty {
                            FlowChips(items: areaSuggestions, selected: model.areaName) { pick in
                                Haptics.selection()
                                model.areaName = pick
                            }
                        }
                    }

                    field("颜色 / 标签", placeholder: "如 蓝色 · 3 号（作为线名）", text: $model.labelText, focus: .label) {
                        EmptyView()
                    }

                    field("难度", placeholder: "如 V4、6B+", text: gradeBinding, focus: .grade) {
                        VStack(alignment: .leading, spacing: 8) {
                            FlowChips(items: GradePresets.vScale, selected: model.gradeText) { pick in
                                Haptics.selection()
                                model.setGradeManually(pick)
                            }
                            FlowChips(items: GradePresets.font, selected: model.gradeText) { pick in
                                Haptics.selection()
                                model.setGradeManually(pick)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("角度").font(.footnote.weight(.semibold)).foregroundStyle(Color.subtle)
                        HStack(spacing: 8) {
                            ForEach(WallAngle.allCases.filter { $0 != .unknown }, id: \.self) { a in
                                Chip(title: a.title, selected: model.angle == a) {
                                    Haptics.selection()
                                    model.angle = model.angle == a ? .unknown : a
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .inkBackground()
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.medium()
                onDone()
            } label: {
                Text("建好")
            }
            .buttonStyle(BigButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(
                LinearGradient(colors: [Color.ink.opacity(0), Color.ink], startPoint: .top, endPoint: .bottom)
                    .frame(height: 96)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            )
        }
    }

    private var gradeBinding: Binding<String> {
        Binding(
            get: { model.gradeText },
            set: { model.setGradeManually($0) }
        )
    }

    private func field<Extra: View>(_ title: String, placeholder: String, text: Binding<String>, focus target: Field, @ViewBuilder extra: () -> Extra) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color.subtle)
            TextField(placeholder, text: text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .submitLabel(.next)
                .focused($focus, equals: target)
                .onSubmit { advance(from: target) }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            extra()
        }
    }

    private func advance(from field: Field) {
        switch field {
        case .area: focus = .label
        case .label: focus = .grade
        case .grade: focus = nil
        }
    }
}
