import SwiftUI

/// 顶部进度点：拍 → 点亮 → 完成。
struct BuilderProgressDots: View {
    /// 0 拍 / 1 点亮 / 2 完成
    var step: Int
    private let titles = ["拍", "点亮", "完成"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.accent : Color.white.opacity(0.22))
                    .frame(width: i == step ? 22 : 7, height: 7)
                    .animation(.snappy(duration: 0.3), value: step)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(step + 1) 步，\(titles[min(step, 2)])")
    }
}

/// 点亮屏底部的信息胶囊外观：主文字 + 可选小字。
struct MetaChipLabel: View {
    var title: String
    var caption: String?
    var systemImage: String
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(filled ? Color.accent : Color.subtle)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(filled ? .semibold : .regular))
                    .foregroundStyle(filled ? .white : Color.white.opacity(0.75))
                    .lineLimit(1)
                if let caption {
                    Text(caption)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.accent.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, caption == nil ? 9 : 6)
        .frame(minHeight: 38)
        .background(Color.white.opacity(filled ? 0.14 : 0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.06)))
        .contentShape(Capsule())
    }
}

/// 可点的 `MetaChipLabel`。
struct MetaChip: View {
    var title: String
    var caption: String?
    var systemImage: String
    var filled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MetaChipLabel(title: title, caption: caption, systemImage: systemImage, filled: filled)
        }
        .buttonStyle(.plain)
    }
}

/// 来源选择屏的一行大选项。
struct SourceOptionRow: View {
    var title: String
    var detail: String
    var systemImage: String
    var prominent: Bool = false
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? Color.accent : Color.white.opacity(0.08))
                    .frame(width: 52, height: 52)
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(prominent ? Color.ink : .white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.footnote).foregroundStyle(Color.subtle).lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(14)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(disabled ? 0.45 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// 一个透明的“轻触即触发”按钮样式：按下只轻微变暗。
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// 顶部一行：左按钮 + 进度点 + 右按钮（可选）。
struct BuilderTopBar<Leading: View, Trailing: View>: View {
    var step: Int
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            BuilderProgressDots(step: step)
            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}

/// 顶部栏文字按钮。
struct TopBarButton: View {
    var title: String
    var systemImage: String?
    var role: ButtonRole?
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).font(.subheadline.weight(.semibold)) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 小 sheet

/// 难度：文本框 + 快捷胶囊。
struct GradeSheet: View {
    @Bindable var model: BuilderModel
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("难度").font(.title3.weight(.bold)).foregroundStyle(.white)
                if model.gradeIsAuto {
                    Text("自动读取").font(.caption).foregroundStyle(Color.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accent.opacity(0.14), in: Capsule())
                }
                Spacer()
                Button("完成") { commit(text) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accent)
            }
            TextField("如 V4、6B+、紫色", text: $text)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { commit(text) }
                .focused($focused)
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            chipRows
            Spacer(minLength: 0)
        }
        .padding(20)
        .inkBackground()
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.ink)
        .onAppear {
            text = model.gradeText
            focused = model.gradeText.isEmpty
        }
    }

    private var chipRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(GradePresets.vScale, id: \.self) { g in
                        Chip(title: g, selected: text == g) { commit(g) }
                    }
                }
            }
            .scrollIndicators(.hidden)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(GradePresets.font, id: \.self) { g in
                        Chip(title: g, selected: text == g) { commit(g) }
                    }
                }
            }
            .scrollIndicators(.hidden)
            if !text.isEmpty {
                Button("清空难度") { commit("") }
                    .font(.footnote)
                    .foregroundStyle(Color.subtle)
            }
        }
    }

    private func commit(_ value: String) {
        Haptics.selection()
        model.setGradeManually(value)
        dismiss()
    }
}

/// 墙区：文本框 + 岩馆里用过的墙区名。
struct AreaSheet: View {
    @Bindable var model: BuilderModel
    var suggestions: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("墙区").font(.title3.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Button("完成") { commit(text) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accent)
            }
            TextField("如 斜板墙、A 区", text: $text)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .submitLabel(.done)
                .onSubmit { commit(text) }
                .focused($focused)
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !suggestions.isEmpty {
                Text("这个岩馆用过的").font(.footnote).foregroundStyle(Color.subtle)
                FlowChips(items: suggestions, selected: text) { commit($0) }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .inkBackground()
        .presentationDetents([.height(suggestions.isEmpty ? 220 : 320)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.ink)
        .onAppear {
            text = model.areaName
            focused = model.areaName.isEmpty
        }
    }

    private func commit(_ value: String) {
        Haptics.selection()
        model.areaName = value.trimmingCharacters(in: .whitespaces)
        dismiss()
    }
}

/// 自动换行的胶囊组。
struct FlowChips: View {
    var items: [String]
    var selected: String
    var onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Chip(title: item, selected: selected == item) { onPick(item) }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
