import SwiftData
import SwiftUI

/// 记这一次（PRD §6.4）：上半屏点“掉在哪”，下半屏五行表单，保存后展示拼好的提醒。
/// 传入 `session` 时为编辑已有记录；否则新建（今天已有记录时预填）。
struct SessionEditorView: View {
    let line: Line
    var session: Session?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft: SessionDraft
    @State private var date: Date
    @State private var trackEach: Bool
    @State private var fallMode: FallMode
    @State private var selectedStep: Int?
    @State private var fallText: String
    /// 新建时从“今天已有的记录”预填；只在日期仍是今天时视为编辑它。
    private let prefillID: UUID?

    @State private var dictation = SpeechDictation()
    @State private var noteBeforeDictation = ""
    @State private var saved: SavedState?
    @State private var reminderDraft = ""
    @State private var editingReminder = false
    @State private var autoDismiss: Task<Void, Never>?
    @FocusState private var noteFocused: Bool

    private enum FallMode: Hashable {
        case tap
        case step
    }

    private struct SavedState {
        var reminder: String?
        var notice: String?
    }

    init(line: Line, session: Session? = nil) {
        self.line = line
        self.session = session
        let today = Calendar.current.startOfDay(for: .now)
        let base = session ?? line.sessions.first { $0.date == today && $0.cycle == line.cycle }
        var draft = base.map(SessionDraft.init(session:)) ?? SessionDraft()
        var fallText = ""
        if !line.hasPhoto {
            let decoded = NoPhotoFall.decode(base?.note)
            fallText = decoded.fall
            draft.note = decoded.note
        }
        _draft = State(initialValue: draft)
        _date = State(initialValue: base?.date ?? today)
        _trackEach = State(initialValue: !draft.attempts.isEmpty)
        _fallMode = State(initialValue: draft.fallStepIndex != nil ? .step : .tap)
        _selectedStep = State(initialValue: draft.fallStepIndex)
        _fallText = State(initialValue: fallText)
        prefillID = session == nil ? base?.id : nil
    }

    private var plan: ClimbSequence? {
        guard line.hasPhoto, let p = line.planSequence, !p.isEmpty else { return nil }
        return p
    }

    private var effectiveBaseID: UUID? {
        if let session { return session.id }
        return Calendar.current.isDateInToday(date) ? prefillID : nil
    }

    private var savePlan: SessionSavePlan {
        SessionSavePlan.resolve(baseID: effectiveBaseID, day: date, cycle: line.cycle, sessions: line.sessions)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    if line.hasPhoto {
                        fallPicker(height: proxy.size.height * (fallMode == .step && plan != nil ? 0.30 : 0.40))
                        if fallMode == .step, let plan {
                            StepPicker(line: line, sequence: plan, selectedStep: $selectedStep)
                                .frame(height: 96)
                                .padding(.horizontal, 12)
                                .padding(.top, 6)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    } else {
                        noPhotoFallSection
                    }
                    ScrollView {
                        VStack(spacing: 12) {
                            dateRow
                            countRow
                            sentRow
                            reasonRow
                            noteRow
                            attemptsSection
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollIndicators(.hidden)
                }
                .animation(reduceMotion ? nil : .snappy, value: fallMode)
            }
            .safeAreaInset(edge: .bottom) {
                if saved == nil { saveBar }
            }
            .inkBackground()
            .navigationTitle(session == nil ? "记这一次" : "改这一次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                }
            }
            .overlay {
                if let saved { savedOverlay(saved) }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(saved != nil || dictation.isRecording)
        .onChange(of: dictation.transcript) { _, transcript in
            guard dictation.isRecording || !transcript.isEmpty else { return }
            let base = noteBeforeDictation.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.note = base.isEmpty ? transcript : (transcript.isEmpty ? base : base + " " + transcript)
        }
        .onChange(of: selectedStep) { _, step in applyStep(step) }
        .onChange(of: draft.attemptCount) { _, count in
            if trackEach { draft.attempts = AttemptSync.resized(draft.attempts, to: count) }
        }
        .onDisappear {
            autoDismiss?.cancel()
            if dictation.isRecording { dictation.stop() }
        }
    }

    // MARK: 掉在哪：点图

    private func fallPicker(height: CGFloat) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                LineSpotlight(line: line, fill: false, maxPixel: 1400, showNumbers: true, highlightedHoldID: draft.fallHoldID)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { location in tapImage(at: location, size: geo.size) }
                    .accessibilityLabel("聚光灯图，点一下选掉在哪个点")
            }
            HStack(spacing: 10) {
                if let label = line.label(for: draft.fallHoldID) {
                    HStack(spacing: 6) {
                        Text("掉在 \(label)")
                        if let step = draft.fallStepIndex { Text("· 第 \(step + 1) 步") }
                        Button { clearFall() } label: {
                            Image(systemName: "xmark.circle.fill").font(.subheadline)
                        }
                        .accessibilityLabel("清除掉在哪")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.coral, in: Capsule())
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    Text(fallMode == .tap ? "点一下掉下来的点，可跳过" : "在下面选掉在第几步")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                if plan != nil {
                    Picker("掉在哪的方式", selection: $fallMode) {
                        Text("点图").tag(FallMode.tap)
                        Text("第几步").tag(FallMode.step)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: height)
        .background(Color.ink)
        .animation(reduceMotion ? nil : .snappy, value: draft.fallHoldID)
    }

    private func tapImage(at point: CGPoint, size: CGSize) {
        let geo = SpotlightGeometry(size: size, aspect: line.wall?.aspectRatio ?? 0.75, fill: false)
        guard let hold = geo.hold(at: point, in: line.holds, slop: 18) else { return }
        Haptics.selection()
        if draft.fallHoldID == hold.id {
            draft.fallHoldID = nil
        } else {
            draft.fallHoldID = hold.id
        }
        draft.fallStepIndex = nil
        if fallMode == .tap { selectedStep = nil }
    }

    private func clearFall() {
        Haptics.light()
        draft.fallHoldID = nil
        draft.fallStepIndex = nil
        selectedStep = nil
    }

    private func applyStep(_ index: Int?) {
        guard let plan else { return }
        if let index, plan.steps.indices.contains(index) {
            let initial = SequenceReplay.initialState(startHoldIDs: line.startHoldIDs, holds: line.holds)
            let state = SequenceReplay.state(of: plan, after: index + 1, initial: initial)
            let step = plan.steps[index]
            draft.fallStepIndex = index
            draft.fallHoldID = state[step.limb] ?? step.holdID
            Haptics.selection()
        } else if index == nil, fallMode == .step, draft.fallStepIndex != nil {
            draft.fallStepIndex = nil
            draft.fallHoldID = nil
        }
    }

    // MARK: 掉在哪：无照片

    private var noPhotoFallSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(line.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("这条线没有照片，掉在哪用文字写一下。")
                .font(.footnote)
                .foregroundStyle(Color.subtle)
            TextField("掉在哪（例如：大球、第三个点）", text: $fallText)
                .font(.body)
                .padding(12)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.panelElevated.opacity(0.9), Color.ink], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: 五行

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            formRow("日期") {
                DatePicker("日期", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .tint(.accent)
            }
            if let notice = dateNotice {
                Label(notice, systemImage: "arrow.triangle.merge")
                    .font(.caption)
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, 6)
            }
        }
    }

    private var dateNotice: String? {
        guard case let .mergeInto(id, removing) = savePlan,
              let other = line.sessions.first(where: { $0.id == id }) else { return nil }
        var text = "\(DateText.short(other.date)) 已有一条记录（\(other.attemptCount) 次），保存时会并进去"
        if removing != nil { text += "，这条记录会合到那边" }
        return text
    }

    private var countRow: some View {
        formRow("试了几次") {
            HStack(spacing: 6) {
                stepButton(systemImage: "minus", enabled: draft.attemptCount > 0) {
                    draft.attemptCount = max(0, draft.attemptCount - 1)
                }
                Text("\(draft.attemptCount)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 36)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: draft.attemptCount)
                stepButton(systemImage: "plus", enabled: draft.attemptCount < 99) {
                    draft.attemptCount += 1
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("试了 \(draft.attemptCount) 次")
        }
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? .white : .white.opacity(0.3))
                .frame(width: 40, height: 36)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(systemImage == "plus" ? "加一次" : "减一次")
    }

    private var sentRow: some View {
        formRow("上了吗") {
            Toggle("上了吗", isOn: $draft.sent)
                .labelsHidden()
                .tint(.accent)
                .onChange(of: draft.sent) { _, sent in
                    if sent { Haptics.success() } else { Haptics.light() }
                }
        }
    }

    @ViewBuilder private var reasonRow: some View {
        let skipReason = draft.sent && draft.fallHoldID == nil && draft.reason == nil && fallText.isEmpty
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("为什么掉")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if let reason = draft.reason {
                    Text(reason.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accent)
                }
            }
            if skipReason {
                Text("上了也没掉，原因可以不填。")
                    .font(.footnote)
                    .foregroundStyle(Color.subtle)
            } else {
                ChipFlow {
                    ForEach(FailReason.allCases, id: \.self) { reason in
                        Chip(title: reason.title, selected: draft.reason == reason) {
                            Haptics.selection()
                            draft.reason = draft.reason == reason ? nil : reason
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(reduceMotion ? nil : .snappy, value: skipReason)
    }

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("一句话")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                micButton
            }
            TextField("下次要试什么？", text: $draft.note, axis: .vertical)
                .lineLimit(2...4)
                .font(.body)
                .foregroundStyle(.white)
                .focused($noteFocused)
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if dictation.isRecording {
                Label("正在听，说完再点一下停止。", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(Color.coral)
            } else if let error = dictation.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.subtle)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var micButton: some View {
        Button(action: toggleDictation) {
            Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(dictation.isRecording ? .white : Color.accent)
                .frame(width: 36, height: 36)
                .background(dictation.isRecording ? Color.coral : Color.white.opacity(0.08), in: Circle())
                .symbolEffect(.pulse, options: .repeating, isActive: dictation.isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dictation.isRecording ? "停止录音" : "语音输入")
    }

    private func toggleDictation() {
        if dictation.isRecording {
            dictation.stop()
            Haptics.light()
        } else {
            noteBeforeDictation = draft.note
            noteFocused = false
            Haptics.medium()
            dictation.toggle()
        }
    }

    // MARK: 记每一次

    private var attemptsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .snappy) {
                    trackEach.toggle()
                    if trackEach {
                        if draft.attemptCount == 0 { draft.attemptCount = 1 }
                        draft.attempts = AttemptSync.resized(draft.attempts, to: draft.attemptCount)
                    } else {
                        draft.attempts = []
                    }
                }
            } label: {
                HStack {
                    Text("记每一次")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    if !trackEach {
                        Text("每次一行：上了 / 掉 · 掉在哪")
                            .font(.caption)
                            .foregroundStyle(Color.subtle)
                    }
                    Spacer()
                    Image(systemName: trackEach ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.subtle)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(trackEach ? "收起每次记录" : "展开每次记录")

            if trackEach {
                VStack(spacing: 6) {
                    ForEach(Array(draft.attempts.enumerated()), id: \.element.id) { index, attempt in
                        attemptRow(index: index, attempt: attempt)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func attemptRow(index: Int, attempt: AttemptRecord) -> some View {
        HStack(spacing: 10) {
            Text("#\(index + 1)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.subtle)
                .frame(width: 30, alignment: .leading)
            HStack(spacing: 6) {
                Chip(title: "掉", selected: !attempt.sent) { updateAttempt(index) { $0.sent = false } }
                Chip(title: "上了", selected: attempt.sent) {
                    updateAttempt(index) { a in
                        a.sent = true
                        a.fallHoldID = nil
                    }
                }
            }
            Spacer()
            if !attempt.sent, line.hasPhoto {
                Menu {
                    Button("没记") { updateAttempt(index) { $0.fallHoldID = nil } }
                    ForEach(HoldNumbering.ordered(line.holds)) { hold in
                        Button(line.label(for: hold.id) ?? "") { updateAttempt(index) { $0.fallHoldID = hold.id } }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(line.label(for: attempt.fallHoldID).map { "掉在 \($0)" } ?? "掉在哪")
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(attempt.fallHoldID == nil ? Color.subtle : Color.coral)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func updateAttempt(_ index: Int, _ change: (inout AttemptRecord) -> Void) {
        guard draft.attempts.indices.contains(index) else { return }
        Haptics.selection()
        change(&draft.attempts[index])
        let summary = AttemptSync.summary(draft.attempts)
        if summary.sent { draft.sent = true }
        if draft.fallHoldID == nil, let fall = summary.lastFallHoldID {
            draft.fallHoldID = fall
            draft.fallStepIndex = nil
        }
    }

    // MARK: 保存

    private var saveBar: some View {
        VStack(spacing: 6) {
            Button("保存", action: save)
                .buttonStyle(BigButtonStyle())
            Text(saveHint)
                .font(.caption)
                .foregroundStyle(Color.subtle)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color.ink.opacity(0.96))
    }

    private var saveHint: String {
        switch savePlan {
        case .create: return Calendar.current.isDateInToday(date) ? "存为今天的记录" : "补记到 \(DateText.short(date))"
        case .overwrite: return "更新 \(DateText.short(date)) 的记录"
        case .mergeInto: return "并入 \(DateText.short(date)) 的记录"
        }
    }

    private func save() {
        if dictation.isRecording { dictation.stop() }
        let store = Store(context)
        let day = Calendar.current.startOfDay(for: date)
        var final = draft
        if !trackEach { final.attempts = [] }
        let pureFallText = fallText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.hasPhoto {
            final.fallHoldID = nil
            final.fallStepIndex = nil
            final.note = NoPhotoFall.encode(fall: pureFallText, note: draft.note)
        }

        let target: Session
        var notice: String?
        switch savePlan {
        case .overwrite(let id):
            guard let existing = line.sessions.first(where: { $0.id == id }) else { return }
            target = existing
        case .mergeInto(let id, let removing):
            guard let other = line.sessions.first(where: { $0.id == id }) else { return }
            final = final.merged(into: SessionDraft(session: other))
            if let removing, let old = line.sessions.first(where: { $0.id == removing }) {
                store.removeSession(old, from: line)
            }
            target = other
            notice = "已并入 \(DateText.short(day)) 的记录"
        case .create:
            target = store.newSession(for: line, date: day)
        }

        store.write(final, to: target, date: day)
        store.commitSession(target, line: line, fallLabel: line.hasPhoto ? line.label(for: target.fallHoldID) : nil)
        if !line.hasPhoto, !pureFallText.isEmpty, target.hasContent,
           let text = ReminderComposer.compose(fallLabel: pureFallText, reason: target.reason, note: draft.trimmedNote) {
            // 无照片线：提醒里把文字版“掉在哪”放到最前面
            store.updateReminder(line, text: text)
        }
        Haptics.success()

        let reminder = target.hasContent ? line.reminderText : nil
        guard reminder != nil || notice != nil else {
            dismiss()
            return
        }
        withAnimation(reduceMotion ? nil : .snappy) {
            saved = SavedState(reminder: reminder, notice: notice)
        }
        autoDismiss = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func savedOverlay(_ state: SavedState) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { if !editingReminder { finish() } }
            VStack(alignment: .leading, spacing: 12) {
                Label(state.notice ?? "已保存", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accent)
                if let reminder = state.reminder {
                    Text("下次进馆先看这句")
                        .font(.footnote)
                        .foregroundStyle(Color.subtle)
                    if editingReminder {
                        TextField("提醒", text: $reminderDraft, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.body)
                            .foregroundStyle(Color.accent)
                            .padding(12)
                            .background(Color.panelElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button("完成") {
                            Store(context).updateReminder(line, text: reminderDraft)
                            Haptics.light()
                            finish()
                        }
                        .buttonStyle(BigButtonStyle())
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill").foregroundStyle(Color.accent).padding(.top, 2)
                            Text(reminder)
                                .font(.body)
                                .foregroundStyle(Color.accent)
                        }
                        HStack {
                            Button("改一下") {
                                autoDismiss?.cancel()
                                reminderDraft = reminder
                                withAnimation(reduceMotion ? nil : .snappy) { editingReminder = true }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            Spacer()
                            Button("好", action: finish)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.accent)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08)))
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func finish() {
        autoDismiss?.cancel()
        dismiss()
    }

    private func cancel() {
        autoDismiss?.cancel()
        if dictation.isRecording { dictation.stop() }
        dismiss()
    }

    // MARK: 布局小件

    private func formRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#if DEBUG
#Preview("记这一次 · 新建") {
    let sample = LineDetailPreviewData.make()
    return SessionEditorView(line: sample.line)
        .modelContainer(sample.container)
        .environment(UndoCenter())
        .environment(AppState())
        .preferredColorScheme(.dark)
        .tint(.accent)
}

#Preview("记这一次 · 编辑") {
    let sample = LineDetailPreviewData.make()
    return SessionEditorView(line: sample.line, session: sample.line.orderedSessions.first)
        .modelContainer(sample.container)
        .environment(UndoCenter())
        .environment(AppState())
        .preferredColorScheme(.dark)
        .tint(.accent)
}
#endif
