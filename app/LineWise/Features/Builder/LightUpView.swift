import SwiftUI

/// 点亮屏：全屏照片 + 蒙版，点一下亮、再点一下灭；双指缩放平移；长按某点弹出操作卡。
struct LightUpView: View {
    @Bindable var model: BuilderModel
    var areaSuggestions: [String] = []
    var backTitle: String = "重拍"
    var onBack: () -> Void
    var onDone: () -> Void

    // 缩放 / 平移
    @State private var transform = ZoomTransform.identity
    @State private var pinchBase: ZoomTransform?

    // 单指触摸：统一判定 轻点 / 长按 / 拖动
    @State private var touches = TouchClassifier()
    @State private var longPressTask: Task<Void, Never>?
    @State private var menuHoldID: UUID?

    // 表单
    @State private var showGradeSheet = false
    @State private var showAreaSheet = false
    @State private var hintDismissed = false

    private let longPressDuration: Duration = .milliseconds(420)

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                photoArea
                bottomBar
            }
            holdMenu
        }
        .inkBackground()
        .sheet(isPresented: $showGradeSheet) { GradeSheet(model: model) }
        .sheet(isPresented: $showAreaSheet) { AreaSheet(model: model, suggestions: areaSuggestions) }
        .onDisappear { longPressTask?.cancel() }
    }

    // MARK: 顶栏

    private var topBar: some View {
        BuilderTopBar(step: 1) {
            TopBarButton(title: backTitle, systemImage: "chevron.left") {
                Haptics.light()
                onBack()
            }
        } trailing: {
            if transform.isZoomed {
                TopBarButton(title: "1×", systemImage: "arrow.down.right.and.arrow.up.left") {
                    Haptics.selection()
                    withAnimation(.snappy) { transform = .identity }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.snappy(duration: 0.25), value: transform.isZoomed)
    }

    // MARK: 照片区

    private var photoArea: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.ink
                SpotlightImage(
                    image: model.image,
                    aspect: model.aspect,
                    holds: model.draft.holds,
                    startHoldIDs: model.draft.startHoldIDs,
                    finishHoldID: model.draft.finishHoldID,
                    highlightedHoldID: menuHoldID,
                    fill: false,
                    showNumbers: true
                )
                .scaleEffect(transform.scale, anchor: .center)
                .offset(transform.offset)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(touchGesture(size: size))
            .simultaneousGesture(magnifyGesture(size: size))
            .overlay { hint }
            .accessibilityLabel("墙照片，已点 \(model.draft.count) 个点")
            .accessibilityHint("轻点空白处点亮一个点，再点一下熄灭；长按某个点可以设为起步或结束")
        }
    }

    @ViewBuilder
    private var hint: some View {
        if model.draft.isEmpty && !hintDismissed {
            VStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.accent)
                Text("点亮你的线")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("点一下亮，再点一下灭\n双指缩放看细节")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    // MARK: 底栏

    private var bottomBar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    MetaChip(
                        title: model.gradeText.isEmpty ? "难度？" : model.gradeText,
                        caption: model.gradeIsAuto ? "自动读取" : nil,
                        systemImage: "tag.fill",
                        filled: !model.gradeText.isEmpty
                    ) {
                        Haptics.selection()
                        showGradeSheet = true
                    }
                    .accessibilityLabel(model.gradeText.isEmpty ? "难度，未填" : "难度 \(model.gradeText)")
                    MetaChip(
                        title: model.areaName.isEmpty ? "墙区" : model.areaName,
                        systemImage: "square.split.bottomrightquarter",
                        filled: !model.areaName.isEmpty
                    ) {
                        Haptics.selection()
                        showAreaSheet = true
                    }
                    .accessibilityLabel(model.areaName.isEmpty ? "墙区，未填" : "墙区 \(model.areaName)")
                    Menu {
                        Picker("角度", selection: $model.angle) {
                            ForEach(WallAngle.allCases, id: \.self) { a in
                                Text(a == .unknown ? "不选" : a.title).tag(a)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        MetaChipLabel(
                            title: model.angle == .unknown ? "角度" : model.angle.title,
                            systemImage: "angle",
                            filled: model.angle != .unknown
                        )
                    }
                    .menuOrder(.fixed)
                    .onChange(of: model.angle) { _, _ in Haptics.selection() }
                    .accessibilityLabel(model.angle == .unknown ? "角度，未选" : "角度 \(model.angle.title)")
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已点 \(model.draft.count) 个")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: model.draft.count)
                    Text(model.draft.isEmpty ? "至少点亮 1 个点" : "长按某点可改起步 / 结束")
                        .font(.caption)
                        .foregroundStyle(Color.subtle)
                }
                Spacer()
                Button {
                    Haptics.medium()
                    onDone()
                } label: {
                    Text("完成")
                }
                .buttonStyle(BigButtonStyle())
                .frame(width: 132)
                .disabled(model.draft.isEmpty)
                .opacity(model.draft.isEmpty ? 0.4 : 1)
                .animation(.snappy(duration: 0.2), value: model.draft.isEmpty)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Color.ink)
    }

    // MARK: 长按操作卡

    @ViewBuilder
    private var holdMenu: some View {
        if let id = menuHoldID, let hold = model.draft.hold(id: id) {
            HoldMenuCard(
                hold: hold,
                number: HoldNumbering.numbers(for: model.draft.holds)[id] ?? 0,
                isStart: model.draft.isStart(id),
                isFinish: model.draft.isFinish(id),
                onToggleStart: {
                    Haptics.selection()
                    withAnimation(.snappy) { model.draft.toggleStart(id: id) }
                },
                onToggleFinish: {
                    Haptics.selection()
                    withAnimation(.snappy) { model.draft.toggleFinish(id: id) }
                },
                onRadius: { r in
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.2)) { model.draft.setRadius(id: id, r: r) }
                },
                onDelete: {
                    Haptics.light()
                    withAnimation(.snappy) {
                        model.draft.remove(id: id)
                        menuHoldID = nil
                    }
                },
                onClose: { withAnimation(.snappy) { menuHoldID = nil } }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 118)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: 手势

    /// 单指：落下即开始计时（长按），移动就拖（放大后），抬起且没动、没久按 → 轻点。
    /// 用 `minimumDistance: 0` 的 DragGesture 统一处理，避免多个手势识别器互相等待，轻点不会有延迟。
    private func touchGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                perform(touches.handle(.changed(location: value.location, start: value.startLocation, time: .now), canPan: transform.isZoomed), size: size)
            }
            .onEnded { value in
                perform(touches.handle(.ended(location: value.location, time: .now), canPan: transform.isZoomed), size: size)
            }
    }

    private func magnifyGesture(size: CGSize) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                if pinchBase == nil {
                    pinchBase = transform
                    perform(touches.handle(.pinchChanged, canPan: true), size: size)
                }
                guard let base = pinchBase else { return }
                transform = base
                    .scaled(to: base.scale * value.magnification, anchor: value.startLocation, in: size)
                    .clamped(contentRect: LightUpGeometry.photoRect(size: size, aspect: model.aspect), in: size)
            }
            .onEnded { _ in
                pinchBase = nil
                perform(touches.handle(.pinchEnded(time: .now), canPan: true), size: size)
                let rect = LightUpGeometry.photoRect(size: size, aspect: model.aspect)
                withAnimation(.snappy(duration: 0.25)) {
                    transform = transform.clamped(contentRect: rect, in: size)
                }
            }
    }

    private func perform(_ actions: [TouchClassifier.Action], size: CGSize) {
        for action in actions {
            switch action {
            case .startLongPressTimer(let point):
                startLongPress(at: point, size: size)
            case .cancelLongPressTimer:
                cancelLongPress()
            case .pan(let delta):
                transform = transform
                    .translated(by: delta)
                    .clamped(contentRect: LightUpGeometry.photoRect(size: size, aspect: model.aspect), in: size)
            case .tap(let point):
                handleTap(at: point, size: size)
            }
        }
    }

    private func handleTap(at point: CGPoint, size: CGSize) {
        if menuHoldID != nil {
            withAnimation(.snappy) { menuHoldID = nil }
            return
        }
        switch LightUpGeometry.tapOutcome(touch: point, holds: model.draft.holds, size: size, aspect: model.aspect, transform: transform) {
        case .remove(let id):
            Haptics.light()
            model.draft.remove(id: id)
        case .add(let x, let y):
            Haptics.light()
            if hintDismissed {
                model.draft.add(x: x, y: y)
            } else {
                // 第一个点：提示卡淡出；Canvas 本身不参与动画，点会立刻亮起
                withAnimation(.easeOut(duration: 0.25)) {
                    model.draft.add(x: x, y: y)
                    hintDismissed = true
                }
            }
        case .ignore:
            break
        }
    }

    private func startLongPress(at point: CGPoint, size: CGSize) {
        longPressTask?.cancel()
        guard menuHoldID == nil else { return }
        let holds = model.draft.holds
        let aspect = model.aspect
        let transform = transform
        longPressTask = Task { @MainActor in
            try? await Task.sleep(for: longPressDuration)
            guard !Task.isCancelled else { return }
            guard let hit = LightUpGeometry.hold(at: point, holds: holds, size: size, aspect: aspect, transform: transform, slop: 18) else { return }
            guard touches.longPressTimerFired() else { return }
            Haptics.medium()
            withAnimation(.snappy) { menuHoldID = hit.id }
        }
    }

    private func cancelLongPress() {
        longPressTask?.cancel()
        longPressTask = nil
    }
}

/// 长按某点后的操作卡：起步 / 结束 / 半径 / 删除。
struct HoldMenuCard: View {
    let hold: Hold
    let number: Int
    let isStart: Bool
    let isFinish: Bool
    var onToggleStart: () -> Void
    var onToggleFinish: () -> Void
    var onRadius: (Double) -> Void
    var onDelete: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(HoldLabel.circled(number))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accent)
                Text(roleText)
                    .font(.subheadline)
                    .foregroundStyle(Color.subtle)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            HStack(spacing: 8) {
                Chip(title: isStart ? "取消起步" : "设为起步", selected: isStart, systemImage: "circle.circle", action: onToggleStart)
                Chip(title: isFinish ? "取消结束" : "设为结束", selected: isFinish, systemImage: "flag.fill", action: onToggleFinish)
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Text("半径").font(.footnote).foregroundStyle(Color.subtle)
                ForEach(LightUpDraft.radiusOptions, id: \.value) { option in
                    Chip(title: option.title, selected: nearest == option.value) { onRadius(option.value) }
                }
                Spacer(minLength: 0)
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.coral)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.coral.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.panelElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    private var roleText: String {
        switch (isStart, isFinish) {
        case (true, _): "起步点"
        case (_, true): "结束点"
        default: "普通点"
        }
    }

    /// 当前半径最接近哪个档。
    private var nearest: Double {
        LightUpDraft.radiusOptions.min { abs($0.value - hold.r) < abs($1.value - hold.r) }?.value ?? Hold.defaultRadius
    }
}
