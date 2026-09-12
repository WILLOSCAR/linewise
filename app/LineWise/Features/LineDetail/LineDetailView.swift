import SwiftData
import SwiftUI

/// 线路页（PRD §6.3）：上半屏聚光灯图，下半屏依次是状态、提醒、记录、教练几句、顺序、历史。
/// `onOpenLine` 用于跳到另一条线（合并后的目标线、同墙新建的线）。
struct LineDetailView: View {
    let line: Line
    var onOpenLine: (Line) -> Void

    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undoCenter
    @Environment(\.dismiss) private var dismiss

    @State private var filter = HistoryFilter()
    @State private var showViewer = false
    @State private var showNewSession = false
    @State private var editingSession: Session?
    @State private var showReminderEditor = false
    @State private var showInfoEditor = false
    @State private var showMergePicker = false
    @State private var showBuilder = false
    @State private var confirmResetWall = false

    private var store: Store { Store(context) }

    /// 筛选后的记录（升序，供掉落点着色）。
    private var visibleSessions: [Session] { filter.apply(line.orderedSessions) }
    /// 列表展示用：最近的在最上面。
    private var listedSessions: [Session] { visibleSessions.reversed() }
    private var fallMarks: [FallMark] { line.fallMarks(from: visibleSessions) }

    private var todaySession: Session? {
        let today = Calendar.current.startOfDay(for: .now)
        return line.sessions.first { $0.date == today && $0.cycle == line.cycle }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 14) {
                        hero(height: max(300, proxy.size.height * 0.5))
                        VStack(spacing: 14) {
                            if line.mergedIntoLineID != nil { mergedBanner }
                            statusRow.id("status")
                            reminderPanel.id("reminder")
                            recordPanel.id("record")
                            coachPanel.id("coach")
                            SequencePanel(line: line).id("sequence")
                            historyPanel.id("history")
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                .safeAreaPadding(.bottom, 72)
                .onAppear { debugScrollIfRequested(scroll) }
            }
        }
        .inkBackground()
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { GlassCircleLabel(systemImage: "chevron.left") }
                    .accessibilityLabel("返回")
            }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .swipeBackEnabled()
        .fullScreenCover(isPresented: $showViewer) {
            FullscreenSpotlightViewer(line: line, fallMarks: fallMarks)
        }
        .sheet(isPresented: $showNewSession) {
            SessionEditorView(line: line)
                .presentationDetents([.large])
        }
        .sheet(item: $editingSession) { session in
            SessionEditorView(line: line, session: session)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showReminderEditor) {
            ReminderEditSheet(line: line)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showInfoEditor) {
            LineInfoEditorSheet(line: line)
        }
        .sheet(isPresented: $showMergePicker) {
            MergeTargetPicker(line: line) { target in
                showMergePicker = false
                mergeInto(target)
            }
        }
        .fullScreenCover(isPresented: $showBuilder) {
            LineBuilderFlow(presetWall: line.wall) { created in
                showBuilder = false
                if let created {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        onOpenLine(created)
                    }
                }
            }
        }
        .confirmationDialog("这面墙换线了？", isPresented: $confirmResetWall, titleVisibility: .visible) {
            Button("把这面墙上的 \(wallActiveCount) 条线都标为没了", role: .destructive, action: resetWall)
        } message: {
            Text("历史记录会保留，5 秒内可以撤销。")
        }
    }

    /// 截图用：`-detailScrollTo history` 启动后自动滚到某个区块。只在 DEBUG 生效。
    private func debugScrollIfRequested(_ proxy: ScrollViewProxy) {
        #if DEBUG
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-detailScrollTo"), i + 1 < args.count else { return }
        let target = args[i + 1]
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.snappy) { proxy.scrollTo(target, anchor: .top) }
        }
        #endif
    }

    // MARK: 图

    private func hero(height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            LineSpotlight(line: line, fill: false, maxPixel: 1600, showNumbers: true, fallMarks: fallMarks)
                .saturation(line.status == .gone ? 0.6 : 1)
                .overlay {
                    if !line.hasPhoto {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 34, weight: .light))
                            Text("这条线没有照片")
                                .font(.footnote)
                        }
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.bottom, 20)
                    }
                }
                .padding(.top, 58)
                .padding(.bottom, 40)
            BottomScrim(height: 170)
            VStack(alignment: .leading, spacing: 4) {
                Text(line.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if !line.subtitle.isEmpty { Text(line.subtitle) }
                    if let felt = line.feltGrade { Text("· \(felt.title)") }
                    if let angle = line.wall?.angle, angle != .unknown { Text("· \(angle.title)") }
                    if !line.hasPhoto {
                        Text("· 无照片")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color.ink)
        .contentShape(Rectangle())
        .onTapGesture { if line.hasPhoto { showViewer = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.name) 的聚光灯图")
        .accessibilityHint(line.hasPhoto ? "点一下全屏查看" : "")
    }

    // MARK: 状态行

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                let actions = LineStatusMachine.actions(for: line.status)
                if !actions.isEmpty {
                    Menu {
                        ForEach(actions, id: \.self) { action in
                            Button { perform(action) } label: { Label(action.title, systemImage: action.symbol) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: line.status.symbol).font(.caption.weight(.semibold))
                            Text("改状态").font(.footnote.weight(.semibold))
                            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.1), in: Capsule())
                    }
                    .accessibilityLabel("改状态")
                }
            }
            if line.status == .gone {
                Label("这条线已经没了，历史留在这里。", systemImage: "xmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.subtle)
            }
        }
        .padding(.horizontal, 4)
    }

    private var statusText: String {
        var parts = [line.status.title]
        parts.append(line.visitCount == 0 ? "还没来过" : "来了 \(line.visitCount) 次")
        if line.totalAttempts > 0 { parts.append("共 \(line.totalAttempts) 次尝试") }
        if line.cycle > 1 { parts.append("第 \(line.cycle) 轮") }
        return parts.joined(separator: " · ")
    }

    private func perform(_ action: LineAction) {
        let previousCycle = line.cycle
        guard let undo = store.apply(action, to: line) else { return }
        Haptics.medium()
        let title: String
        switch action {
        case .markSent: title = "已标为上了"
        case .drop: title = "已放弃这条线"
        case .markGone: title = "已标为没了"
        case .newCycle: title = "开始第 \(previousCycle + 1) 轮"
        }
        undoCenter.offer(title, undo: undo)
    }

    // MARK: 提醒

    private var reminderPanel: some View {
        Panel("提醒") {
            if let text = line.reminderText {
                Button { showReminderEditor = true } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: line.reminderVerified ? "checkmark.seal.fill" : "lightbulb.fill")
                            .font(.body)
                            .foregroundStyle(Color.accent)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(Color.accent)
                                .multilineTextAlignment(.leading)
                            if line.reminderVerified {
                                Text("已验证有用").font(.caption).foregroundStyle(Color.subtle)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "pencil")
                            .font(.footnote)
                            .foregroundStyle(Color.subtle)
                            .padding(.top, 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("点一下修改提醒")

                if let pending = line.pendingCheckSession {
                    Divider().overlay(Color.white.opacity(0.08))
                    Text("上次这句有用吗？")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    ChipFlow {
                        ForEach(ReminderCheck.allCases, id: \.self) { check in
                            Chip(title: check.title, selected: false) { answer(pending, check) }
                        }
                    }
                }
            } else {
                Text("记一次之后这里会出现提醒")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtle)
            }
        }
    }

    private func answer(_ session: Session, _ check: ReminderCheck) {
        Haptics.selection()
        let undo = store.answerCheck(session, line: line, check: check)
        undoCenter.offer("已回答：\(check.title)", undo: undo)
    }

    // MARK: 记录

    private var recordPanel: some View {
        let todayCount = todaySession?.attemptCount ?? 0
        let sentToday = todaySession?.sent ?? false
        return Panel("记录") {
            HStack(spacing: 10) {
                Button(action: plusOne) {
                    Text("+1")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                .buttonStyle(BigButtonStyle())
                .overlay(alignment: .topTrailing) {
                    if todayCount > 0 {
                        Text("今天 \(todayCount) 次")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.ink, in: Capsule())
                            .offset(x: -8, y: -8)
                            .contentTransition(.numericText())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .accessibilityLabel(todayCount > 0 ? "再记一次尝试，今天已记 \(todayCount) 次" : "记一次尝试")

                Button(action: toggleSentToday) {
                    Label(sentToday ? "上了" : "上了？", systemImage: sentToday ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.titleAndIcon)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(BigButtonStyle(prominent: sentToday))
                .frame(width: 128)
                .accessibilityAddTraits(.isToggle)
                .accessibilityValue(sentToday ? "开" : "关")
            }
            .animation(.snappy, value: todayCount)
            .animation(.snappy, value: sentToday)

            SecondaryActionButton(title: "记这一次", systemImage: "arrow.right") { showNewSession = true }
        }
    }

    private func plusOne() {
        Haptics.medium()
        let undo = store.incrementAttempt(line)
        undoCenter.offer("+1 已记录", undo: undo)
    }

    private func toggleSentToday() {
        let next = !(todaySession?.sent ?? false)
        let undo = store.setSentToday(line, sent: next)
        if next { Haptics.success() } else { Haptics.light() }
        undoCenter.offer(next ? "已记为上了" : "已取消上了", undo: undo)
    }

    // MARK: 教练几句

    @ViewBuilder private var coachPanel: some View {
        let sentences = CoachSummary.sentences(for: line.digest())
        if !sentences.isEmpty {
            Panel("教练几句") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(Color.accent).frame(width: 6, height: 6).padding(.top, 7)
                            Text(sentence)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
            }
        }
    }

    // MARK: 历史

    private var historyPanel: some View {
        Panel("历史", trailing: Text(historyCountText).font(.footnote).foregroundStyle(Color.subtle).monospacedDigit()) {
            historyFilters
            if listedSessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(filter.isActive ? "这个范围里没有记录" : "还没有记录")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    if filter.isActive {
                        Button("看全部") { withAnimation(.snappy) { filter = HistoryFilter() } }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accent)
                    } else {
                        Text("爬完点上面的“记这一次”，或者在馆里直接 +1。")
                            .font(.footnote)
                            .foregroundStyle(Color.subtle)
                    }
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(listedSessions) { session in
                        SwipeToDelete(onDelete: { delete(session) }) {
                            SessionRow(line: line, session: session)
                                .contentShape(Rectangle())
                                .onTapGesture { editingSession = session }
                        }
                        .contextMenu {
                            Button { editingSession = session } label: { Label("编辑", systemImage: "pencil") }
                            Button(role: .destructive) { delete(session) } label: { Label("删除", systemImage: "trash") }
                        }
                        if session.id != listedSessions.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .animation(.snappy, value: listedSessions.map(\.id))
            }
        }
    }

    private var historyCountText: String {
        let total = line.visitCount
        let shown = listedSessions.count
        return filter.isActive ? "\(shown) / \(total) 次" : "\(total) 次"
    }

    @ViewBuilder private var historyFilters: some View {
        let cycles = HistoryFilter.cycleOptions(maxCycle: line.cycle)
        if !cycles.isEmpty || line.visitCount > 0 {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(cycles.enumerated()), id: \.offset) { _, option in
                        Chip(title: option.map { "第 \($0) 轮" } ?? "全部轮", selected: filter.cycle == option) {
                            Haptics.selection()
                            withAnimation(.snappy) { filter.cycle = option }
                        }
                    }
                    if !cycles.isEmpty {
                        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 18)
                    }
                    ForEach(HistoryRange.allCases) { range in
                        Chip(title: range.title, selected: filter.range == range) {
                            Haptics.selection()
                            withAnimation(.snappy) { filter.range = range }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func delete(_ session: Session) {
        let title = "已删除 \(DateText.short(session.date)) 的记录"
        withAnimation(.snappy) {
            let undo = store.deleteSession(session, from: line)
            undoCenter.offer(title, undo: undo)
        }
        Haptics.light()
    }

    // MARK: 合并提示

    private var mergedBanner: some View {
        Panel {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.merge").foregroundStyle(Color.accent)
                Text("这条线已经合并到另一条，记录都在那边。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if let id = line.mergedIntoLineID, let target = store.line(id: id) {
                    Button("打开") { onOpenLine(target) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }

    // MARK: 更多菜单

    private var wallActiveCount: Int { line.wall?.activeLines.filter { $0.status != .gone }.count ?? 0 }

    private var moreMenu: some View {
        Menu {
            Button { showInfoEditor = true } label: { Label("改名、难度、墙区…", systemImage: "pencil") }
            if line.wall != nil {
                Button { showBuilder = true } label: { Label("这面墙上再建一条", systemImage: "plus.viewfinder") }
                Button { confirmResetWall = true } label: { Label("这面墙换线了", systemImage: "arrow.triangle.2.circlepath") }
            }
            if line.isVisible {
                Button { showMergePicker = true } label: { Label("合并到另一条…", systemImage: "arrow.triangle.merge") }
            }
            ShareLineButton(line: line)
            Divider()
            Button(role: .destructive, action: deleteLine) { Label("删除这条线", systemImage: "trash") }
        } label: {
            GlassCircleLabel(systemImage: "ellipsis")
        }
        .accessibilityLabel("更多")
    }

    private func resetWall() {
        guard let wall = line.wall else { return }
        let count = wallActiveCount
        let undo = store.resetWall(wall)
        Haptics.warning()
        undoCenter.offer("这面墙的 \(count) 条线已标为没了", undo: undo)
    }

    private func mergeInto(_ target: Line) {
        let undo = store.merge(line, into: target)
        Haptics.success()
        undoCenter.offer("已合并到「\(target.name)」", undo: undo)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            onOpenLine(target)
        }
    }

    private func deleteLine() {
        let undo = store.softDelete(line)
        Haptics.warning()
        undoCenter.offer("已删除「\(line.name)」", undo: undo)
        dismiss()
    }
}

/// 材质圆形按钮的外观（返回、更多）。作为 Button / Menu 的 label 使用。
struct GlassCircleLabel: View {
    var systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.1)))
    }
}

#if DEBUG
#Preview("线路页") {
    let sample = LineDetailPreviewData.make()
    return NavigationStack {
        LineDetailView(line: sample.line, onOpenLine: { _ in })
    }
    .modelContainer(sample.container)
    .environment(UndoCenter())
    .environment(AppState())
    .preferredColorScheme(.dark)
    .tint(.accent)
}
#endif
