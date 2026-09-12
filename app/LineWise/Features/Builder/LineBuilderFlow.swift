import SwiftData
import SwiftUI

/// 建线流程（全屏）。`presetWall` 非空时表示“这面墙上再建一条”，跳过拍照直接认旧线 / 点亮。
/// 建好回传 Line；取消回传 nil。调用方负责关闭 fullScreenCover 并跳到线路页。
struct LineBuilderFlow: View {
    var presetWall: Wall? = nil
    var onFinish: (Line?) -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model = BuilderModel()
    @State private var gym: Gym?
    @State private var step: Step = .source
    @State private var forward = true
    @State private var preloadedWallImage: UIImage?
    @State private var errorMessage: String?
    @State private var didBootstrap = false

    /// 流程里的每一屏。
    enum Step: Equatable {
        case source
        case recognize(Wall)
        case lightUp(back: BackTarget)
        case noPhoto
        case reveal(Line)

        var key: String {
            switch self {
            case .source: "source"
            case .recognize(let w): "recognize-\(w.id)"
            case .lightUp: "lightUp"
            case .noPhoto: "noPhoto"
            case .reveal(let l): "reveal-\(l.id)"
            }
        }
    }

    /// 点亮屏“返回”去哪。
    enum BackTarget: Equatable {
        case source
        case recognize(Wall)
        case cancel
    }

    private var store: Store { Store(context) }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            if let gym {
                screen(for: gym)
                    .id(step.key)
                    .transition(stepTransition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.35), value: step)
        .preferredColorScheme(.dark)
        .alert("没保存成功", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: bootstrap)
    }

    // MARK: 屏幕

    @ViewBuilder
    private func screen(for gym: Gym) -> some View {
        switch step {
        case .source:
            BuilderSourceView(
                gymName: gym.name,
                walls: store.wallsWithPhoto(in: gym),
                onCancel: { onFinish(nil) },
                onImage: { image in
                    model.setNewPhoto(image)
                    go(.lightUp(back: .source))
                },
                onExistingWall: { wall in enter(wall: wall, back: .source) },
                onNoPhoto: { go(.noPhoto) }
            )

        case .recognize(let wall):
            RecognizeLinesView(
                wall: wall,
                backTitle: presetWall == nil ? "返回" : "取消",
                onPick: { line in onFinish(line) },
                onNew: { startLightUp(on: wall, back: .recognize(wall)) },
                onBack: {
                    if presetWall == nil { go(.source, forward: false) } else { onFinish(nil) }
                }
            )

        case .lightUp(let back):
            LightUpView(
                model: model,
                areaSuggestions: store.areaNames(in: gym),
                backTitle: model.existingWall == nil ? "重拍" : "返回",
                onBack: { leaveLightUp(to: back) },
                onDone: { commitPhotoLine(gym: gym) }
            )

        case .noPhoto:
            NoPhotoFormView(
                model: model,
                areaSuggestions: store.areaNames(in: gym),
                onBack: { go(.source, forward: false) },
                onDone: { commitNoPhotoLine(gym: gym) }
            )

        case .reveal(let line):
            RevealView(
                image: model.image,
                aspect: model.aspect,
                holds: line.holds,
                startHoldIDs: line.startHoldIDs,
                finishHoldID: line.finishHoldID,
                title: line.name,
                subtitle: line.gradeText,
                onFinished: { onFinish(line) }
            )
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: forward ? .trailing : .leading)),
            removal: .opacity.combined(with: .move(edge: forward ? .leading : .trailing))
        )
    }

    // MARK: 流转

    private func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        let store = self.store
        let gym = store.gym(id: appState.currentGymID) ?? store.ensureDefaultGym()
        self.gym = gym
        model = BuilderModel(areaName: appState.lastAreaName)

        if let presetWall {
            enter(wall: presetWall, back: .cancel, animated: false)
            return
        }
        #if DEBUG
        if BuilderDebug.wantsLightUpDemo, let wall = store.wallsWithPhoto(in: gym).first {
            startLightUp(on: wall, back: .source, animated: false)
            BuilderDebug.placeDemoHolds(in: model)
            return
        }
        #endif
        step = .source
    }

    private func go(_ next: Step, forward: Bool = true, animated: Bool = true) {
        self.forward = forward
        if animated {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.35)) { step = next }
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { step = next }
        }
    }

    /// 进入一面已有的墙：有线先认旧线，没有直接点亮。
    private func enter(wall: Wall, back: BackTarget, animated: Bool = true) {
        preloadedWallImage = nil
        if let name = wall.photoFileName {
            // 认旧线期间先把大图解出来，进点亮屏时不用等
            Task { @MainActor in
                preloadedWallImage = await ImageStore.loadAsync(fileName: name, maxPixel: Int(ImageStore.maxLongEdge))
            }
        }
        if wall.activeLines.isEmpty {
            startLightUp(on: wall, back: back, animated: animated)
        } else {
            go(.recognize(wall), animated: animated)
        }
    }

    private func startLightUp(on wall: Wall, back: BackTarget, animated: Bool = true) {
        let image = preloadedWallImage ?? wall.photoFileName.flatMap { ImageStore.load(fileName: $0, maxPixel: Int(ImageStore.maxLongEdge)) }
        model.useExistingWall(wall, image: image)
        go(.lightUp(back: back), animated: animated)
    }

    private func leaveLightUp(to back: BackTarget) {
        switch back {
        case .source:
            model.clearPhoto()
            go(.source, forward: false)
        case .recognize(let wall):
            model.clearPhoto()
            go(.recognize(wall), forward: false)
        case .cancel:
            onFinish(nil)
        }
    }

    // MARK: 写库

    private func commitPhotoLine(gym: Gym) {
        guard !model.draft.isEmpty else { return }
        do {
            let seconds = model.buildSeconds
            let line = try store.commitBuild(model, gym: gym)
            rememberArea()
            if let seconds { BuildMetrics.record(seconds: seconds) }
            go(.reveal(line))
        } catch {
            errorMessage = "照片没能写进本机存储：\(error.localizedDescription)"
        }
    }

    private func commitNoPhotoLine(gym: Gym) {
        do {
            let name = model.labelText.trimmingCharacters(in: .whitespaces)
            let line = try store.commitBuild(model, gym: gym, name: name.isEmpty ? nil : name)
            rememberArea()
            Haptics.success()
            onFinish(line)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rememberArea() {
        let area = model.areaName.trimmingCharacters(in: .whitespaces)
        if !area.isEmpty { appState.lastAreaName = area }
    }
}

#if DEBUG
/// 只在 DEBUG 下、由启动参数触发的演示入口（用于截图验证）。
/// 用法：xcrun simctl launch <udid> com.linewise.app -seedDemo -builderDemo
enum BuilderDebug {
    static var wantsLightUpDemo: Bool { CommandLine.arguments.contains("-builderDemo") }

    @MainActor
    static func placeDemoHolds(in model: BuilderModel) {
        model.draft = LightUpDraft(holds: [
            Hold(x: 0.22, y: 0.86), Hold(x: 0.31, y: 0.70), Hold(x: 0.27, y: 0.55),
            Hold(x: 0.38, y: 0.42), Hold(x: 0.34, y: 0.28), Hold(x: 0.42, y: 0.14),
        ])
        model.setGradeManually("V4")
    }
}
#endif

// MARK: - Preview

#if DEBUG
@MainActor
private func previewContainer() -> ModelContainer {
    let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let store = Store(container.mainContext)
    let gym = store.ensureDefaultGym(named: "预览岩馆")
    let wall = try! store.createWall(gym: gym, image: previewWallImage(), areaName: "斜板墙", angle: .slab)
    let holds = [Hold(x: 0.3, y: 0.85), Hold(x: 0.45, y: 0.6), Hold(x: 0.4, y: 0.35), Hold(x: 0.55, y: 0.15)]
    let sf = HoldNumbering.defaultStartAndFinish(holds)
    _ = store.createLine(wall: wall, holds: holds, startHoldIDs: sf.start, finishHoldID: sf.finish, gradeText: "V3", gradeSource: .manual, name: "斜板墙 · 蓝")
    return container
}

/// 预览用的合成墙照片。
private func previewWallImage() -> UIImage {
    let size = CGSize(width: 1200, height: 1600)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
        UIColor(red: 0.70, green: 0.68, blue: 0.64, alpha: 1).setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemRed, .systemYellow, .systemPurple]
        for i in 0..<28 {
            let x = CGFloat((i * 37) % 100) / 100 * size.width
            let y = CGFloat((i * 53) % 100) / 100 * size.height
            colors[i % colors.count].setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: x - 34, y: y - 28, width: 68, height: 56))
        }
    }
}

/// 预览宿主：内存库 + 环境。
private struct BuilderPreviewHost: View {
    enum Mode { case flow, preset, lightUp, reveal }
    let mode: Mode
    let container: ModelContainer
    let model: BuilderModel

    @MainActor
    init(_ mode: Mode) {
        self.mode = mode
        container = previewContainer()
        let m = BuilderModel(areaName: "斜板墙")
        m.setNewPhoto(previewWallImage())
        m.draft = LightUpDraft(holds: [Hold(x: 0.3, y: 0.85), Hold(x: 0.45, y: 0.6), Hold(x: 0.4, y: 0.35)])
        model = m
    }

    var body: some View {
        Group {
            switch mode {
            case .flow:
                LineBuilderFlow { _ in }
            case .preset:
                LineBuilderFlow(presetWall: try? container.mainContext.fetch(FetchDescriptor<Wall>()).first) { _ in }
            case .lightUp:
                LightUpView(model: model, areaSuggestions: ["斜板墙", "仰角墙"], onBack: {}, onDone: {})
            case .reveal:
                RevealView(
                    image: model.image, aspect: model.aspect, holds: model.draft.holds,
                    startHoldIDs: model.draft.startHoldIDs, finishHoldID: model.draft.finishHoldID,
                    title: "斜板墙 · 9月13日", subtitle: "V4", onFinished: {}
                )
            }
        }
        .modelContainer(container)
        .environment(AppState())
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
        .tint(.accent)
    }
}

#Preview("建线流程") { BuilderPreviewHost(.flow) }
#Preview("这面墙上再建一条") { BuilderPreviewHost(.preset) }
#Preview("点亮屏") { BuilderPreviewHost(.lightUp) }
#Preview("揭示动画") { BuilderPreviewHost(.reveal) }
#endif
