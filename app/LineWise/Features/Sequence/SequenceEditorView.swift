import SwiftData
import SwiftUI

enum SequenceKind: String, CaseIterable, Identifiable {
    case plan
    case actual

    var id: String { rawValue }
    var title: String { self == .plan ? "计划" : "实际" }
}

/// 火柴人顺序编辑器（全屏）：左边聚光灯画布拖手脚，右边一列快照。
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
    @State private var image: UIImage?
    @State private var thumbImage: UIImage?
    @State private var drag: DragPhase = .idle
    @State private var highlightedHoldID: UUID?
    @State private var showCompleteBadge = false
    @State private var badgeTask: Task<Void, Never>?
    /// 画布实际尺寸（手势与调试脚本共用同一套几何）。
    @State private var canvasFit: CGSize = .zero

    private let holds: [Hold]
    private let aspect: Double

    init(line: Line, kind: SequenceKind, onClose: @escaping () -> Void) {
        self.line = line
        self.kind = kind
        self.onClose = onClose
        let holds = line.holds
        self.holds = holds
        self.aspect = line.wall?.aspectRatio ?? 0.75
        _activeKind = State(initialValue: kind)
        let initial = SequenceReplay.initialState(startHoldIDs: line.startHoldIDs, holds: holds)
        _model = State(initialValue: SequenceEditorModel(sequence: line.sequence(for: kind), initial: initial, finishHoldID: line.finishHoldID))
    }

    // MARK: 拖拽状态

    private struct DragState: Equatable {
        var limb: Limb
        /// 末端相对手指的偏移（视图坐标），避免一按下去肢体就跳到指尖。
        var grabOffset: CGSize
        var isoPoint: CGPoint
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

    private static let grabThreshold: CGFloat = 28
    private static let snapMinThreshold: CGFloat = 28

    private var motion: Animation? { reduceMotion ? nil : .spring(duration: 0.35) }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
            GeometryReader { g in
                HStack(spacing: 12) {
                    canvasColumn(size: CGSize(width: floor(g.size.width * 0.6), height: g.size.height))
                    stepList(height: g.size.height)
                }
                .padding(.horizontal, 12)
            }
            Text(hint)
                .font(.footnote)
                .foregroundStyle(Color.subtle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .contentTransition(.opacity)
                .animation(.snappy, value: hint)
        }
        .inkBackground()
        .task(id: line.wall?.photoFileName) {
            guard let name = line.wall?.photoFileName else { return }
            let big = await ImageStore.loadAsync(fileName: name, maxPixel: 1600)
            if !Task.isCancelled { image = big }
            let small = await ImageStore.loadAsync(fileName: name, maxPixel: SequenceThumbnail.imageMaxPixel)
            if !Task.isCancelled { thumbImage = small }
        }
        #if DEBUG
        .onAppear(perform: runDebugScriptIfRequested)
        #endif
    }

    // MARK: 顶栏

    private var canCopyToActual: Bool {
        activeKind == .plan && line.actualSequence == nil && model.stepCount > 0
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("关闭")

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

            if canCopyToActual {
                Button(action: copyToActual) {
                    Text("复制为实际")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .foregroundStyle(Color.accent)
                .transition(.opacity)
            }

            Button(action: undoLast) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .foregroundStyle(model.canUndo ? .white : Color.white.opacity(0.3))
            .disabled(!model.canUndo)
            .accessibilityLabel("撤销最后一步")
        }
        .animation(.snappy, value: canCopyToActual)
    }

    private var hint: String {
        if model.isComplete && !model.isRewound { return "双手都到了结束点 · 完成" }
        if model.stepCount == 0 { return "把手或脚拖到第一个点" }
        if model.isRewound { return "从这一步继续拖，后面的会被替换" }
        return "把手或脚拖到下一个点"
    }

    // MARK: 画布

    private var displayPose: StickFigurePose {
        let override = drag.state.map { SequencePoseBuilder.Override(limb: $0.limb, point: $0.isoPoint) }
        return SequencePoseBuilder.pose(state: model.currentState, holds: holds, aspect: aspect, profile: appState.bodyProfile, override: override)
    }

    private func canvasColumn(size: CGSize) -> some View {
        let fit = SpotlightGeometry(size: size, aspect: aspect, fill: false).rect.size
        return ZStack(alignment: .top) {
            SequenceCanvas(
                image: image,
                aspect: aspect,
                holds: holds,
                startHoldIDs: line.startHoldIDs,
                finishHoldID: line.finishHoldID,
                highlightedHoldID: highlightedHoldID,
                pose: PoseVector(displayPose)
            )
            .frame(width: fit.width, height: fit.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
            .contentShape(Rectangle())
            .gesture(dragGesture(canvasSize: fit))
            .onChange(of: fit, initial: true) { _, new in canvasFit = new }

            if showCompleteBadge {
                Label("完成", systemImage: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accent, in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityLabel("顺序画布")
    }

    private func dragGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let geo = SpotlightGeometry(size: canvasSize, aspect: aspect, fill: false)
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
        let pose = SequencePoseBuilder.pose(state: model.currentState, holds: holds, aspect: aspect, profile: appState.bodyProfile)
        guard let hit = SequenceHitTesting.nearestEndpoint(to: point, pose: pose, geo: geo, aspect: aspect, threshold: Self.grabThreshold) else {
            drag = .ignored
            return
        }
        let offset = CGSize(width: hit.view.x - point.x, height: hit.view.y - point.y)
        let iso = geo.isoPoint(fromView: hit.view, aspect: aspect)
        drag = .active(DragState(limb: hit.limb, grabOffset: offset, isoPoint: iso))
        Haptics.selection()
    }

    private func updateDrag(to point: CGPoint, geo: SpotlightGeometry) {
        guard var state = drag.state else { return }
        let limbView = CGPoint(x: point.x + state.grabOffset.width, y: point.y + state.grabOffset.height)
        var iso = geo.isoPoint(fromView: limbView, aspect: aspect)
        iso.x = min(max(iso.x, 0), aspect)
        iso.y = min(max(iso.y, 0), 1)
        state.isoPoint = iso
        drag = .active(state)

        let newID = SequenceHitTesting.nearestSnapHold(to: limbView, holds: holds, geo: geo, minThreshold: Self.snapMinThreshold)?.id
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
        // 姿态变化放在动画事务里：命中 → 平滑吸附到新姿态；未命中 → 回弹。
        withAnimation(motion) {
            drag = .idle
            highlightedHoldID = nil
            if let target {
                result = model.apply(limb: state.limb, holdID: target)
            }
        }
        if let result {
            didApply(result, before: before)
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
        guard cell != model.currentCell else { return }
        withAnimation(motion) { model.rewind(toCell: cell) }
        Haptics.selection()
    }

    private func undoLast() {
        guard model.canUndo else { return }
        withAnimation(motion) { model.undo() }
        persist()
        Haptics.light()
    }

    private func copyToActual() {
        let undo = Store(context).copyPlanToActual(line)
        withAnimation(.snappy) { activeKind = .actual }
        Haptics.light()
        undoCenter.offer("已复制为实际") {
            undo()
            withAnimation(.snappy) { activeKind = .plan }
        }
    }

    private func persist() {
        Store(context).saveSequence(model.sequence, kind: activeKind, line: line)
    }

    private func flashCompleteBadge() {
        badgeTask?.cancel()
        withAnimation(.snappy) { showCompleteBadge = true }
        badgeTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { showCompleteBadge = false }
        }
    }

    #if DEBUG
    // MARK: 调试脚本（模拟器里没法真拖，用同一套手势函数回放）
    //
    //   -sequenceScript "rewind:3,rf:3,lh:7,rh:7,miss,undo"
    //   lh/rh/lf/rf:<编号> 拖到某个点；miss 拖到空处回弹；rewind:<格> 点某一格；undo 撤销；wait:<秒>

    private func runDebugScriptIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-sequenceScript"), i + 1 < args.count else { return }
        let commands = args[i + 1].split(separator: ",").map(String.init)
        let numbers = HoldNumbering.numbers(for: holds)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            for command in commands {
                let parts = command.split(separator: ":").map(String.init)
                guard let head = parts.first else { continue }
                switch head {
                case "lh", "rh", "lf", "rf":
                    guard parts.count == 2, let n = Int(parts[1]), let limb = Limb(rawValue: head),
                          let hold = holds.first(where: { numbers[$0.id] == n }) else { continue }
                    await debugDrag(limb: limb, toView: SpotlightGeometry(size: canvasFit, aspect: aspect, fill: false).point(hold))
                case "miss":
                    await debugDrag(limb: .rightHand, toView: CGPoint(x: canvasFit.width * 0.85, y: canvasFit.height * 0.5))
                case "rewind":
                    if parts.count == 2, let n = Int(parts[1]) { select(cell: n) }
                case "undo":
                    undoLast()
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

    private func debugDrag(limb: Limb, toView target: CGPoint) async {
        let geo = SpotlightGeometry(size: canvasFit, aspect: aspect, fill: false)
        let pose = SequencePoseBuilder.pose(state: model.currentState, holds: holds, aspect: aspect, profile: appState.bodyProfile)
        guard let end = SequencePoseBuilder.endpoints(of: pose).first(where: { $0.limb == limb }) else { return }
        let endView = geo.fromIso(end.point, aspect: aspect)
        // 按在末端稍偏一点（左/右、手偏上/脚偏下），和真手指一样，也让叠在同点的肢体能被区分。
        let start = CGPoint(x: endView.x + (limb.isLeft ? -4 : 4), y: endView.y + (limb.isHand ? -3 : 3))
        beginDrag(at: start, geo: geo)
        let frames = 24
        for k in 1...frames {
            let t = CGFloat(k) / CGFloat(frames)
            updateDrag(to: CGPoint(x: start.x + (target.x - start.x) * t, y: start.y + (target.y - start.y) * t), geo: geo)
            try? await Task.sleep(for: .milliseconds(40))
        }
        try? await Task.sleep(for: .milliseconds(900)) // 停一下，便于截到“高亮 + 身体跟随”
        endDrag()
        NSLog("[Sequence] script released %@ -> steps=%d cell=%d", limb.rawValue, model.stepCount, model.currentCell)
    }
    #endif

    // MARK: 右侧列表

    /// 与另一份顺序不同的步骤索引（两份都存在时）。
    private var differingSteps: Set<Int> {
        guard let plan = line.planSequence, let actual = line.actualSequence else { return [] }
        return SequenceReplay.differingStepIndices(plan: plan, actual: actual)
    }

    private func stepList(height: CGFloat) -> some View {
        let listHeight = height
        let numbers = HoldNumbering.numbers(for: holds)
        let differing = differingSteps
        let thumbSize = SequenceThumbnail.size(height: 48, aspect: aspect, maxWidth: 64)
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    // 列表短时和画布一样居中；长了正常滚动。
                    ForEach(0...model.stepCount, id: \.self) { cell in
                        StepCell(
                            cell: cell,
                            step: cell == 0 ? nil : model.steps[cell - 1],
                            holdLabel: cell == 0 ? nil : numbers[model.steps[cell - 1].holdID].map(HoldLabel.circled),
                            isCurrent: cell == model.currentCell,
                            isAfterCurrent: cell > model.currentCell,
                            isComplete: cell == model.stepCount && cell > 0 && model.isSequenceComplete,
                            differs: cell > 0 && differing.contains(cell - 1),
                            thumbnail: SequenceThumbnail(
                                line: line, image: thumbImage, sequence: model.sequence,
                                stepIndex: cell, size: thumbSize, profile: appState.bodyProfile
                            )
                        )
                        .id(cell)
                        .onTapGesture { select(cell: cell) }
                    }
                }
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, minHeight: listHeight, alignment: .center)
                .animation(.snappy, value: model.stepCount)
            }
            .onChange(of: model.currentCell) { _, cell in
                withAnimation(.snappy) { proxy.scrollTo(cell, anchor: .center) }
            }
            .onAppear {
                proxy.scrollTo(model.currentCell, anchor: .center)
            }
        }
    }
}

/// 右侧的一格：小图 + “左手 → ③”。
private struct StepCell: View {
    let cell: Int
    let step: SequenceStep?
    let holdLabel: String?
    let isCurrent: Bool
    let isAfterCurrent: Bool
    let isComplete: Bool
    let differs: Bool
    let thumbnail: SequenceThumbnail

    var body: some View {
        HStack(spacing: 8) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                if let step {
                    HStack(spacing: 3) {
                        Image(systemName: step.limb.symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(step.limb.isLeft ? Color.white.opacity(0.85) : Color.accent)
                        Text("\(step.limb.title) → \(holdLabel ?? "?")")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    HStack(spacing: 4) {
                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.accent)
                        }
                        Text(isComplete ? "完成" : "第 \(cell) 步")
                            .font(.caption2)
                            .foregroundStyle(isComplete ? Color.accent : Color.subtle)
                            .monospacedDigit()
                        if differs {
                            Circle().fill(Color.coral).frame(width: 5, height: 5)
                                .accessibilityLabel("与另一份不同")
                        }
                    }
                } else {
                    Text("起步")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                    Text("双手在起步点")
                        .font(.caption2)
                        .foregroundStyle(Color.subtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .frame(height: 60)
        .background(isCurrent ? Color.panelElevated : Color.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isCurrent ? Color.accent : Color.clear, lineWidth: 1.5)
        )
        .opacity(isAfterCurrent ? 0.45 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
    }
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

#Preview("编辑器 · 空") {
    let demo = SequencePreviewData.make(plan: false)
    return SequenceEditorView(line: demo.line, kind: .plan, onClose: {})
        .environment(AppState())
        .environment(UndoCenter())
        .modelContainer(demo.container)
        .preferredColorScheme(.dark)
        .tint(.accent)
}
#endif
