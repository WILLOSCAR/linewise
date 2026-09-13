import SwiftData
import SwiftUI

enum SequenceKind: String, CaseIterable, Identifiable {
    case plan
    case actual

    var id: String { rawValue }
    var title: String { self == .plan ? "计划" : "实际" }
}

/// 火柴人顺序编辑器（全屏）：图占满上方（自动取景到这条线），底部一条胶片条。
/// 拖手脚到点上即记一步；点胶片格回退；播放键按步回放。
struct SequenceEditorView: View {
    let line: Line
    let kind: SequenceKind
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var activeKind: SequenceKind
    @State private var model: SequenceEditorModel
    /// 另一份顺序（计划 ↔ 实际），用来标差异；打开时读一次，复制后同步。
    @State private var otherSequence: ClimbSequence?
    @State private var image: UIImage?
    @State private var thumbImage: UIImage?
    @State private var drag: DragPhase = .idle
    @State private var highlightedHoldID: UUID?
    @State private var showCompleteBadge = false
    @State private var badgeTask: Task<Void, Never>?
    @State private var playback = SequencePlayback()
    @State private var playbackTask: Task<Void, Never>?
    /// 画布实际尺寸（手势与调试脚本共用同一套几何）。
    @State private var canvasSize: CGSize = .zero

    private let scene: SequenceScene

    init(line: Line, kind: SequenceKind, onClose: @escaping () -> Void) {
        self.line = line
        self.kind = kind
        self.onClose = onClose
        let scene = SequenceScene(line: line)
        self.scene = scene
        _activeKind = State(initialValue: kind)
        _model = State(initialValue: SequenceEditorModel(sequence: line.sequence(for: kind), initial: scene.initial, finishHoldID: line.finishHoldID))
        _otherSequence = State(initialValue: line.sequence(for: kind == .plan ? .actual : .plan))
    }

    // MARK: 拖拽状态

    private struct DragState: Equatable {
        var limb: Limb
        /// 末端相对手指的偏移（视图坐标），避免一按下去肢体就跳到指尖。
        var grabOffset: CGSize
        var isoPoint: CGPoint
        /// 手指在画布上的位置（浮动提示跟着它）。
        var finger: CGPoint
    }

    private enum DragPhase: Equatable {
        case idle
        /// 按下的位置不在任何末端附近：这次手势忽略。
        case ignored
        case active(DragState)

        var state: DragState? {
            if case .active(let s) = self { return s }
            return nil
        }
    }

    /// 按下命中末端的半径、吸附的最小半径（pt）。
    static let grabThreshold: CGFloat = 28
    static let snapMinThreshold: CGFloat = 28
    private static let canvasCorner: CGFloat = 22

    private var motion: Animation? { reduceMotion ? nil : .spring(duration: 0.35) }
    private var quick: Animation? { reduceMotion ? nil : .snappy(duration: 0.2) }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
            GeometryReader { g in
                canvas(size: g.size)
            }
            .padding(.horizontal, 10)
            SequenceFilmstrip(
                line: line, scene: scene, image: thumbImage, model: model, profile: appState.bodyProfile,
                differing: differingSteps, isPlaying: playback.isPlaying,
                onSelect: select(cell:), onTogglePlay: togglePlayback
            )
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 2)
        }
        .inkBackground()
        .task(id: line.wall?.photoFileName) {
            guard let name = line.wall?.photoFileName else { return }
            let big = await ImageStore.loadAsync(fileName: name, maxPixel: 1600)
            if !Task.isCancelled { image = big }
            let small = await ImageStore.loadAsync(fileName: name, maxPixel: SequenceThumbnail.imageMaxPixel)
            if !Task.isCancelled { thumbImage = small }
        }
        .onDisappear { stopPlayback() }
        #if DEBUG
        .onAppear(perform: runDebugScriptIfRequested)
        #endif
    }

    // MARK: 顶栏

    private var planExists: Bool {
        activeKind == .plan ? model.stepCount > 0 : (otherSequence?.isEmpty == false)
    }

    private var canCopyToActual: Bool { activeKind == .plan && model.stepCount > 0 }
    private var canCopyFromPlan: Bool { activeKind == .actual && otherSequence?.isEmpty == false }
    private var hasMoreActions: Bool { canCopyToActual || canCopyFromPlan || model.stepCount > 0 }

    private var topBar: some View {
        HStack(spacing: 12) {
            roundButton("xmark", label: "关闭", action: onClose)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(activeKind.title)顺序")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(line.name)
                    .font(.caption)
                    .foregroundStyle(Color.subtle)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if hasMoreActions {
                Menu {
                    if canCopyToActual {
                        Button("复制为实际", systemImage: "doc.on.doc", action: copyToActual)
                    }
                    if canCopyFromPlan {
                        Button("从计划复制", systemImage: "doc.on.doc", action: copyFromPlan)
                    }
                    if model.stepCount > 0 {
                        Button("清空\(activeKind.title)顺序", systemImage: "trash", role: .destructive, action: clearAll)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .foregroundStyle(.white)
                .accessibilityLabel("更多")
                .transition(.opacity)
            }

            roundButton("arrow.uturn.backward", label: "撤销最后一步", action: undoLast)
                .foregroundStyle(model.canUndo ? .white : Color.white.opacity(0.3))
                .disabled(!model.canUndo)
        }
        .animation(quick, value: hasMoreActions)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }

    // MARK: 画布

    private var displayPose: StickFigurePose {
        let override = drag.state.map { SequencePoseBuilder.Override(limb: $0.limb, point: $0.isoPoint) }
        return scene.pose(state: model.currentState, profile: appState.bodyProfile, override: override)
    }

    private func canvas(size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.canvasCorner, style: .continuous)
        return ZStack(alignment: .top) {
            SequenceCanvas(
                image: image,
                scene: scene,
                highlightedHoldID: highlightedHoldID,
                pose: PoseVector(displayPose),
                draggingLimb: drag.state?.limb,
                handleScale: drag.state == nil ? 1 : SequenceCanvas.dragHandleScale
            )
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.08)))
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size))
            .onChange(of: size, initial: true) { _, new in canvasSize = new }
            .accessibilityLabel("顺序画布")
            .accessibilityHint(hint)
            .accessibilityValue(canvasAccessibilityValue(size: size))

            if showCompleteBadge {
                Label("完成", systemImage: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accent, in: Capsule())
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            bottomOverlay
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 14)

            if let state = drag.state {
                dragHint(state, in: size)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// 画布底部：一句提示；“实际”为空且有计划时换成空态动作。
    @ViewBuilder
    private var bottomOverlay: some View {
        if drag.state != nil || playback.isPlaying {
            EmptyView()
        } else if canCopyFromPlan && model.stepCount == 0 {
            HStack(spacing: 10) {
                Text("还没有实际顺序")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                Button(action: copyFromPlan) {
                    Text("从计划复制")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.accent, in: Capsule())
                        .foregroundStyle(Color.ink)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.opacity)
        } else {
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .contentTransition(.opacity)
                .animation(quick, value: hint)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private var hint: String {
        if model.isComplete && !model.isRewound { return "双手都到了结束点 · 完成" }
        if model.stepCount == 0 { return scene.holds.isEmpty ? "这条线还没有点位" : "把手或脚拖到第一个点" }
        if model.isRewound { return "从这一步继续拖，后面的会被替换" }
        return "把手或脚拖到下一个点"
    }

    /// 拖动中跟着手指的“左手 → ④”。
    private func dragHint(_ state: DragState, in size: CGSize) -> some View {
        let label = highlightedHoldID.flatMap { scene.numbers[$0] }.map { "\(state.limb.title) → \(HoldLabel.circled($0))" } ?? state.limb.title
        let x = min(max(state.finger.x, 56), size.width - 56)
        let y = max(state.finger.y - 54, 22)
        return HStack(spacing: 5) {
            Image(systemName: state.limb.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(state.limb.isLeft ? .white : Color.accent)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        .position(x: x, y: y)
        .animation(quick, value: label)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .allowsHitTesting(false)
    }

    // MARK: 手势

    private func canvasAccessibilityValue(size: CGSize) -> String {
        #if DEBUG
        if CommandLine.arguments.contains("-uiTesting"), size.width > 0, size.height > 0,
           let top = scene.holds.min(by: { $0.y < $1.y }) {
            // UI 测试读取真实绘制坐标，再从系统触摸入口拖动；不直接调用手势处理函数。
            let geo = scene.geometry(for: size)
            let pose = scene.pose(state: model.currentState, profile: appState.bodyProfile)
            let hand = geo.fromIso(pose.leftHand, aspect: scene.aspect)
            let target = geo.point(top)
            return "\(model.stepCount),\(hand.x / size.width),\(hand.y / size.height),\(target.x / size.width),\(target.y / size.height)"
        }
        #endif
        return "第 \(model.currentCell) 步，共 \(model.stepCount) 步"
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let geo = scene.geometry(for: size)
                switch drag {
                case .ignored:
                    return
                case .idle:
                    beginDrag(at: value.startLocation, geo: geo)
                    if drag.state != nil { updateDrag(to: value.location, geo: geo) }
                case .active:
                    updateDrag(to: value.location, geo: geo)
                }
            }
            .onEnded { _ in
                endDrag()
            }
    }

    private func beginDrag(at point: CGPoint, geo: SpotlightGeometry) {
        let pose = scene.pose(state: model.currentState, profile: appState.bodyProfile)
        guard let hit = SequenceHitTesting.nearestEndpoint(to: point, pose: pose, geo: geo, aspect: scene.aspect, threshold: Self.grabThreshold) else {
            drag = .ignored
            return
        }
        stopPlayback()
        let offset = CGSize(width: hit.view.x - point.x, height: hit.view.y - point.y)
        let iso = geo.isoPoint(fromView: hit.view, aspect: scene.aspect)
        // 只有把手缩放在动画里；姿态本身跟手指同帧。
        withAnimation(quick) {
            drag = .active(DragState(limb: hit.limb, grabOffset: offset, isoPoint: iso, finger: point))
        }
        Haptics.selection()
    }

    private func updateDrag(to point: CGPoint, geo: SpotlightGeometry) {
        guard var state = drag.state else { return }
        let limbView = CGPoint(x: point.x + state.grabOffset.width, y: point.y + state.grabOffset.height)
        var iso = geo.isoPoint(fromView: limbView, aspect: scene.aspect)
        iso.x = min(max(iso.x, 0), scene.aspect)
        iso.y = min(max(iso.y, 0), 1)
        state.isoPoint = iso
        state.finger = point
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { drag = .active(state) }

        let newID = SequenceHitTesting.nearestSnapHold(to: limbView, holds: scene.holds, geo: geo, minThreshold: Self.snapMinThreshold)?.id
        if newID != highlightedHoldID {
            highlightedHoldID = newID
            if newID != nil { Haptics.selection() }
        }
    }

    private func endDrag() {
        guard let state = drag.state else {
            drag = .idle
            return
        }
        let target = highlightedHoldID
        let before = model
        var result: SequenceEditorModel.ApplyResult?
        // 姿态变化放在动画事务里：命中 → 平滑吸附到新姿态；未命中 → 回弹到原点。
        withAnimation(motion) {
            drag = .idle
            highlightedHoldID = nil
            if let target {
                result = model.apply(limb: state.limb, holdID: target)
            }
        }
        if let result {
            didApply(result, before: before)
        } else if target == nil {
            Haptics.warning()
        }
    }

    // MARK: 修改

    /// 一步落定之后的副作用：保存、触感、撤销条、完成提示。
    private func didApply(_ result: SequenceEditorModel.ApplyResult, before: SequenceEditorModel) {
        persist()
        Haptics.light()
        if !result.truncated.isEmpty {
            let kind = activeKind
            undoCenter.offer("已替换后面 \(result.truncated.count) 步") {
                restore(before, kind: kind)
            }
        }
        if result.justCompleted {
            Haptics.success()
            flashCompleteBadge()
        }
    }

    /// 撤销条可能在编辑器关掉之后才被点，所以直接用快照写库，不依赖视图状态。
    private func restore(_ snapshot: SequenceEditorModel, kind: SequenceKind) {
        withAnimation(motion) { model = snapshot }
        Store(context).saveSequence(snapshot.sequence, kind: kind, line: line)
    }

    private func select(cell: Int) {
        stopPlayback()
        guard cell != model.currentCell else { return }
        withAnimation(motion) { model.rewind(toCell: cell) }
        Haptics.selection()
    }

    private func undoLast() {
        guard model.canUndo else { return }
        stopPlayback()
        withAnimation(motion) { model.undo() }
        persist()
        Haptics.light()
    }

    private func copyToActual() {
        stopPlayback()
        let undo = Store(context).copyPlanToActual(line)
        let plan = model.sequence
        let previousOther = otherSequence
        withAnimation(quick) {
            activeKind = .actual
            otherSequence = plan
        }
        Haptics.light()
        undoCenter.offer("已复制为实际") {
            undo()
            withAnimation(.snappy) {
                activeKind = .plan
                otherSequence = previousOther
            }
        }
    }

    private func copyFromPlan() {
        stopPlayback()
        let before = model
        let undo = Store(context).copyPlanToActual(line)
        withAnimation(motion) { model.replace(with: otherSequence) }
        Haptics.light()
        undoCenter.offer("已从计划复制") {
            undo()
            withAnimation(motion) { model = before }
        }
    }

    private func clearAll() {
        stopPlayback()
        let before = model
        let kind = activeKind
        withAnimation(motion) { model.replace(with: nil) }
        persist()
        Haptics.warning()
        undoCenter.offer("已清空\(kind.title)顺序") {
            restore(before, kind: kind)
        }
    }

    private func persist() {
        Store(context).saveSequence(model.sequence, kind: activeKind, line: line)
    }

    private func flashCompleteBadge() {
        badgeTask?.cancel()
        withAnimation(quick) { showCompleteBadge = true }
        badgeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(quick) { showCompleteBadge = false }
        }
    }

    // MARK: 回放

    private func togglePlayback() {
        if playback.isPlaying {
            stopPlayback()
            Haptics.selection()
            return
        }
        guard let first = playback.start(currentCell: model.currentCell, stepCount: model.stepCount) else { return }
        Haptics.selection()
        withAnimation(motion) { model.rewind(toCell: first) }
        playbackTask = Task { @MainActor in
            while playback.isPlaying {
                try? await Task.sleep(for: SequencePlayback.stepInterval)
                guard !Task.isCancelled, playback.isPlaying else { return }
                guard let next = playback.advance(from: model.currentCell, stepCount: model.stepCount) else { return }
                withAnimation(motion) { model.rewind(toCell: next) }
            }
        }
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        guard playback.isPlaying else { return }
        withAnimation(quick) { playback.stop() }
    }

    /// 与另一份顺序不同的步骤索引（两份都存在时）。
    private var differingSteps: Set<Int> {
        guard let other = otherSequence, model.stepCount > 0 else { return [] }
        return activeKind == .plan
            ? SequenceReplay.differingStepIndices(plan: model.sequence, actual: other)
            : SequenceReplay.differingStepIndices(plan: other, actual: model.sequence)
    }

    #if DEBUG
    // MARK: 调试脚本（模拟器里没法真拖，用同一套手势函数回放）
    //
    //   -sequenceScript "rewind:3,rf:3,lh:7,rh:7,miss,undo"
    //   lh/rh/lf/rf:<编号> 拖到某个点并松手；drag:<lh|rh|lf|rf>:<编号> 拖到点上不松手（截“拖动中”）；release 松手；
    //   miss 拖到空处回弹；rewind:<格> 点某一格；undo 撤销；play 播放/停止；wait:<秒>；toast 弹撤销条

    private func runDebugScriptIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-sequenceScript"), i + 1 < args.count else { return }
        let commands = args[i + 1].split(separator: ",").map(String.init)
        let numbers = scene.numbers
        func hold(numbered text: String) -> Hold? {
            guard let n = Int(text) else { return nil }
            return scene.holds.first(where: { numbers[$0.id] == n })
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            for command in commands {
                let parts = command.split(separator: ":").map(String.init)
                guard let head = parts.first else { continue }
                switch head {
                case "lh", "rh", "lf", "rf":
                    guard parts.count == 2, let limb = Limb(rawValue: head), let hold = hold(numbered: parts[1]) else { continue }
                    await debugDrag(limb: limb, toView: scene.geometry(for: canvasSize).point(hold), release: true)
                case "drag":
                    guard parts.count == 3, let limb = Limb(rawValue: parts[1]), let hold = hold(numbered: parts[2]) else { continue }
                    await debugDrag(limb: limb, toView: scene.geometry(for: canvasSize).point(hold), release: false)
                case "release":
                    endDrag()
                case "miss":
                    await debugDrag(limb: .rightHand, toView: CGPoint(x: canvasSize.width * 0.88, y: canvasSize.height * 0.5), release: true)
                case "rewind":
                    if parts.count == 2, let n = Int(parts[1]) { select(cell: n) }
                case "undo":
                    undoLast()
                case "play":
                    togglePlayback()
                case "toast":
                    undoCenter.offer("测试撤销条") {}
                case "wait":
                    try? await Task.sleep(for: .seconds(Double(parts.count == 2 ? parts[1] : "1") ?? 1))
                default:
                    break
                }
                try? await Task.sleep(for: .seconds(1.0))
            }
        }
    }

    private func debugDrag(limb: Limb, toView target: CGPoint, release: Bool) async {
        let geo = scene.geometry(for: canvasSize)
        let pose = scene.pose(state: model.currentState, profile: appState.bodyProfile)
        guard let end = SequencePoseBuilder.endpoints(of: pose).first(where: { $0.limb == limb }) else { return }
        let endView = geo.fromIso(end.point, aspect: scene.aspect)
        // 按在末端稍偏一点（左/右、手偏上/脚偏下），和真手指一样，也让叠在同点的肢体能被区分。
        let start = CGPoint(x: endView.x + (limb.isLeft ? -5 : 5), y: endView.y + (limb.isHand ? -4 : 4))
        beginDrag(at: start, geo: geo)
        let frames = 24
        for k in 1...frames {
            let t = CGFloat(k) / CGFloat(frames)
            updateDrag(to: CGPoint(x: start.x + (target.x - start.x) * t, y: start.y + (target.y - start.y) * t), geo: geo)
            try? await Task.sleep(for: .milliseconds(40))
        }
        guard release else { return }
        try? await Task.sleep(for: .milliseconds(900)) // 停一下，便于截到“高亮 + 身体跟随”
        endDrag()
        NSLog("[Sequence] script released %@ -> steps=%d cell=%d", limb.rawValue, model.stepCount, model.currentCell)
    }
    #endif
}

#if DEBUG
#Preview("编辑器 · 计划") {
    let demo = SequencePreviewData.make()
    return SequenceEditorView(line: demo.line, kind: .plan, onClose: {})
        .environment(AppState())
        .environment(UndoCenter())
        .modelContainer(demo.container)
        .preferredColorScheme(.dark)
        .tint(.accent)
}

#Preview("编辑器 · 实际为空") {
    let demo = SequencePreviewData.make()
    return SequenceEditorView(line: demo.line, kind: .actual, onClose: {})
        .environment(AppState())
        .environment(UndoCenter())
        .modelContainer(demo.container)
        .preferredColorScheme(.dark)
        .tint(.accent)
}

#Preview("编辑器 · 无照片") {
    let demo = SequencePreviewData.make(withPhoto: false, plan: false)
    return SequenceEditorView(line: demo.line, kind: .plan, onClose: {})
        .environment(AppState())
        .environment(UndoCenter())
        .modelContainer(demo.container)
        .preferredColorScheme(.dark)
        .tint(.accent)
}
#endif
