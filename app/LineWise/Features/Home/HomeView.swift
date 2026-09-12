import SwiftData
import SwiftUI

struct HomeView: View {
    var onOpen: (Line) -> Void
    var onAdd: () -> Void
    var onSettings: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Line> { $0.deletedAt == nil && $0.mergedIntoLineID == nil })
    private var allLines: [Line]
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @State private var currentID: UUID?
    @State private var showNewGym = false
    @State private var newGymName = ""

    private var currentGym: Gym? { gyms.first { $0.id == appState.currentGymID } }

    private var lines: [Line] {
        let gymID = appState.currentGymID
        let today = Calendar.current.startOfDay(for: .now)
        let filtered = allLines.filter { line in
            if let gymID, line.wall?.gym?.id != gymID { return false }
            switch appState.filter {
            case .projecting: return line.status == .projecting
            case .today: return line.sessions.contains { $0.date == today }
            case .sent: return line.status == .sent
            case .all: return true
            }
        }
        return filtered.sorted { a, b in
            let ka = a.latestSession?.date ?? a.createdAt
            let kb = b.latestSession?.date ?? b.createdAt
            if ka != kb { return ka > kb }
            return a.updatedAt > b.updatedAt
        }
    }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            if lines.isEmpty {
                emptyState
            } else {
                cards
            }
            topBar
            bottomBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("新岩馆", isPresented: $showNewGym) {
            TextField("岩馆名字", text: $newGymName)
            Button("取消", role: .cancel) { newGymName = "" }
            Button("添加") {
                let name = newGymName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let gym = Store(context).addGym(name: name)
                appState.currentGymID = gym.id
                newGymName = ""
            }
        }
        .onChange(of: lines.map(\.id)) { _, ids in
            if currentID == nil || !ids.contains(currentID!) { currentID = ids.first }
        }
        .onAppear { if currentID == nil { currentID = lines.first?.id } }
    }

    // MARK: 卡片

    private var cards: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(lines) { line in
                    LineCard(line: line)
                        .containerRelativeFrame(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(line) }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - abs(phase.value) * 0.06)
                                .opacity(1 - abs(phase.value) * 0.45)
                        }
                        .id(line.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
    }

    // MARK: 顶栏

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Menu {
                    ForEach(gyms) { gym in
                        Button {
                            appState.currentGymID = gym.id
                        } label: {
                            if gym.id == appState.currentGymID {
                                Label(gym.name, systemImage: "checkmark")
                            } else {
                                Text(gym.name)
                            }
                        }
                    }
                    Button {
                        appState.currentGymID = nil
                    } label: {
                        if appState.currentGymID == nil { Label("全部岩馆", systemImage: "checkmark") } else { Text("全部岩馆") }
                    }
                    Divider()
                    Button { showNewGym = true } label: { Label("新岩馆…", systemImage: "plus") }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentGym?.name ?? "全部岩馆")
                            .font(.headline)
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            HStack(spacing: 8) {
                ForEach(HomeFilter.allCases) { f in
                    Chip(title: f.title, selected: appState.filter == f) {
                        Haptics.selection()
                        appState.filter = f
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 170)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: 底栏

    private var bottomBar: some View {
        HStack(alignment: .bottom) {
            if let currentID, let idx = lines.firstIndex(where: { $0.id == currentID }), lines.count > 1 {
                Text("\(idx + 1) / \(lines.count)")
                    .font(.footnote.weight(.medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 58, height: 58)
                    .background(Color.accent, in: Circle())
                    .shadow(color: Color.accent.opacity(0.35), radius: 16, y: 2)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            }
            .accessibilityLabel("建一条线")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 8]))
                .foregroundStyle(.white.opacity(0.18))
                .frame(width: 220, height: 300)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: allLines.isEmpty ? "camera.viewfinder" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Color.accent)
                        Text(emptyTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(emptyDetail)
                            .font(.footnote)
                            .foregroundStyle(Color.subtle)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            if allLines.isEmpty || appState.filter == .all {
                Button("拍一面墙", action: onAdd).buttonStyle(BigButtonStyle()).frame(width: 220)
            } else {
                Button("看全部") { appState.filter = .all }.buttonStyle(BigButtonStyle(prominent: false)).frame(width: 220)
            }
            Spacer()
            Spacer()
        }
    }

    private var emptyTitle: String {
        if allLines.isEmpty { return "还没有线" }
        switch appState.filter {
        case .projecting: return "没有进行中的线"
        case .today: return "今天还没动过线"
        case .sent: return "还没有上了的线"
        case .all: return currentGym == nil ? "还没有线" : "这个岩馆还没有线"
        }
    }

    private var emptyDetail: String {
        if allLines.isEmpty { return "拍一面墙，把你的线点亮。" }
        switch appState.filter {
        case .today: return "在线路页点 +1，或爬完补记，这里就会出现。"
        default: return "换个筛选，或者拍一面新墙。"
        }
    }
}

/// 首页一张卡：聚光灯图 + 三行字。
struct LineCard: View {
    let line: Line

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 自动取景：把这条线的包围盒（留 35% 余量）放大到卡片里，整条线完整可见；
            // 顶栏与底部文字区留白。随横滑做 15% 视差，让卡片有层次。
            LineSpotlight(line: line, fill: false, maxPixel: 1400, showNumbers: false,
                          focus: SpotlightGeometry.focusRect(for: line.holds, padding: 0.35, minSize: 0.45))
                .padding(.top, 96)
                .padding(.bottom, 150)
                .visualEffect { content, proxy in
                    content.offset(x: proxy.frame(in: .scrollView(axis: .horizontal)).minX * -0.15)
                }
            BottomScrim(height: 320)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if line.status != .projecting {
                        Label(line.status.title, systemImage: line.status.symbol)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                    if line.cycle > 1 {
                        Text("第 \(line.cycle) 轮")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                }
                Text(headline)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                if let fall = line.lastFallLine {
                    Text(fall)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                }
                if let reminder = line.reminderText {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: line.reminderVerified ? "checkmark.seal.fill" : "lightbulb.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.accent)
                            .padding(.top, 2)
                        Text(reminder)
                            .font(.body)
                            .foregroundStyle(Color.accent)
                            .lineLimit(2)
                    }
                } else if line.visitCount == 0 {
                    Text("还没记录，爬完点进来记一次")
                        .font(.body)
                        .foregroundStyle(Color.subtle)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 92)
        }
        .background(Color.ink)
    }

    private var headline: String {
        var parts: [String] = []
        if let area = line.wall?.areaName, !area.isEmpty { parts.append(area) }
        if let g = line.gradeText, !g.isEmpty { parts.append(g) }
        parts.append(line.visitCount == 0 ? "新线" : "第 \(line.visitCount) 次来")
        return parts.joined(separator: " · ")
    }
}
