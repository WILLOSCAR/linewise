import SwiftUI

/// 设置 · 体型：只影响火柴人比例。
struct BodySettingsSection: View {
    @Environment(AppState.self) private var appState

    static let heightRange: ClosedRange<Double> = 140...210
    static let armSpanRange: ClosedRange<Double> = 140...220

    var body: some View {
        Section {
            HStack(spacing: 16) {
                figurePreview
                VStack(alignment: .leading, spacing: 14) {
                    stepper("身高", value: heightBinding, range: Self.heightRange)
                    stepper("臂展", value: armSpanBinding, range: Self.armSpanRange)
                }
            }
            .padding(.vertical, 4)
            HStack {
                Text("臂展比")
                    .foregroundStyle(.white)
                Text(String(format: "%.2f", appState.bodyProfile.apeIndex))
                    .foregroundStyle(Color.subtle)
                    .monospacedDigit()
                Spacer()
                Button("恢复默认") {
                    Haptics.light()
                    appState.bodyProfile = .default
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(appState.bodyProfile == .default ? Color.subtle : Color.accent)
                .disabled(appState.bodyProfile == .default)
            }
        } header: {
            SettingsHeader("体型")
        } footer: {
            SettingsFooter("只用于画火柴人，不做任何能力判断。")
        }
        .settingsRow()
    }

    // MARK: 控件

    private func stepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            HStack {
                Text(title).foregroundStyle(.white)
                Spacer()
                Text("\(Int(value.wrappedValue)) cm")
                    .foregroundStyle(Color.subtle)
                    .monospacedDigit()
            }
        }
        .tint(.accent)
    }

    private var heightBinding: Binding<Double> {
        Binding(
            get: { appState.bodyProfile.heightCm },
            set: { appState.bodyProfile.heightCm = $0; Haptics.selection() }
        )
    }

    private var armSpanBinding: Binding<Double> {
        Binding(
            get: { appState.bodyProfile.armSpanCm },
            set: { appState.bodyProfile.armSpanCm = $0; Haptics.selection() }
        )
    }

    /// 小预览：站着的火柴人，臂展变化立刻能看到。
    private var figurePreview: some View {
        let aspect = 0.8
        let proportions = StickFigureSolver.Proportions.make(profile: appState.bodyProfile, figureHeight: 0.78)
        let pose = StickFigureSolver.solve(
            contacts: StickFigureSolver.Contacts(),
            proportions: proportions,
            groundY: 0.96,
            bounds: CGRect(x: 0, y: 0, width: aspect, height: 1)
        )
        return SpotlightImage(
            image: nil, aspect: aspect, holds: [],
            pose: pose, poseIsoAspect: aspect,
            fill: true, showNumbers: false, dim: 0
        )
        .frame(width: 64, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .animation(.snappy(duration: 0.25), value: appState.bodyProfile)
        .accessibilityHidden(true)
    }
}
