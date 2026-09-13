import SwiftData
import SwiftUI

struct HomeView: View {
    var onOpen: (Line) -> Void
    var onAdd: () -> Void
    var onSettings: () -> Void
    /// 首页 → 线路页缩放转场用的命名空间（iOS 18+）；nil 时普通 push。
    var zoomNamespace: Namespace.ID? = nil

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(filter: #Predicate<Line> { $0.deletedAt == nil && $0.mergedIntoLineID == nil })
    private var allLines: [Line]
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    /// 排序结果缓存：只有线的“指纹”变了才重算，横滑时不会每帧再排一遍。
    @State private var ordering = HomeOrderingCache()
    @State private var showNewGym = false
    @State private var newGymName = ""

    private var currentGym: Gym? { gyms.first { $0.id == appState.currentGymID } }

    var body: some View {
        let lines = ordering.lines(from: allLines, filter: appState.filter, gymID: appState.currentGymID)
        ZStack {
            Color.ink.ignoresSafeArea()
            Group {
                if lines.isEmpty {
                    HomeEmptyState(
                        hasAnyLine: !allLines.isEmpty,
                        filter: appState.filter,
                        gymName: currentGym?.name,
                        onAdd: onAdd,
                        onShowAll: { withAnimation(.snappy(duration: 0.22)) { appState.filter = .all } }
                    )
                } else {
                    HomeDeck(lines: lines, zoomNamespace: zoomNamespace, onOpen: onOpen)
                }
            }
            // 切换筛选 / 岩馆时整组卡片淡入淡出；数据变化（+1、改状态）不重建，位置不丢。
            .id("\(appState.filter.rawValue)-\(appState.currentGymID?.uuidString ?? "all")")
            .transition(.opacity)
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.25), value: appState.filter)
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.25), value: appState.currentGymID)
            topBar
            addButton
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
    }

    // MARK: 顶栏

    private var topBar: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                gymMenu
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("设置")
            }
            HomeFilterBar(selection: $appState.filter)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 190)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var gymMenu: some View {
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
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel("岩馆：\(currentGym?.name ?? "全部岩馆")")
    }

    // MARK: 底部 “+”

    private var addButton: some View {
        GlowPlusButton(action: onAdd)
            .padding(.trailing, 20)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

/// 缓存首页排序结果：指纹不变就直接复用，避免 `lines` 计算属性在滚动 / 重绘时反复 filter + sort。
final class HomeOrderingCache {
    private var signature: Int?
    private var cached: [Line] = []

    func lines(from all: [Line], filter: HomeFilter, gymID: UUID?) -> [Line] {
        let today = Calendar.current.startOfDay(for: .now)
        let sig = HomeLineOrdering.signature(all, filter: filter, gymID: gymID, today: today)
        if sig != signature {
            signature = sig
            cached = HomeLineOrdering.ordered(all, filter: filter, gymID: gymID, today: today)
        }
        return cached
    }
}

// MARK: - 横滑卡组

/// 整页横滑的卡组 + 页码。`currentID` 只在这里，滚动不会让 `HomeView` 重算。
struct HomeDeck: View {
    let lines: [Line]
    var zoomNamespace: Namespace.ID?
    var onOpen: (Line) -> Void

    @State private var currentID: UUID?

    private var currentIndex: Int? { currentID.flatMap { id in lines.firstIndex { $0.id == id } } }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(lines) { line in
                    LineCard(line: line, zoomNamespace: zoomNamespace)
                        .containerRelativeFrame(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.light()
                            onOpen(line)
                        }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - abs(phase.value) * 0.06)
                                .opacity(1 - abs(phase.value) * 0.35)
                        }
                        .id(line.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("打开线路页")
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .overlay(alignment: .bottomLeading) {
            if let idx = currentIndex {
                PageLabel(index: idx, count: lines.count)
                    .padding(.leading, 18)
                    .padding(.bottom, 24)
                    .animation(.snappy(duration: 0.2), value: idx)
            }
        }
        .onAppear {
            if currentID == nil { currentID = lines.first?.id }
            preloadNeighbors()
        }
        .onChange(of: lines.map(\.id)) { _, ids in
            if currentID == nil || !ids.contains(currentID!) { currentID = ids.first }
        }
        .onChange(of: currentID) { _, _ in preloadNeighbors() }
    }

    /// 相邻两张卡的墙照片先解码进缓存，滑过去不会闪。
    private func preloadNeighbors() {
        guard let idx = currentIndex else { return }
        let names = [idx - 1, idx + 1]
            .filter { lines.indices.contains($0) }
            .compactMap { lines[$0].wall?.photoFileName }
        guard !names.isEmpty else { return }
        let maxPixel = LineCard.maxPixel
        Task.detached(priority: .utility) {
            for name in names { _ = ImageStore.load(fileName: name, maxPixel: maxPixel) }
        }
    }
}

// MARK: - 一张卡

/// 首页一张卡：聚光灯图 + 三行字。卡片即海报。
struct LineCard: View {
    let line: Line
    var zoomNamespace: Namespace.ID?

    static let maxPixel = 1400

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 自动取景：把这条线的包围盒（留 35% 余量）放大到卡片里，整条线完整可见；
            // 顶栏与底部文字区留白。随横滑做 15% 视差，让卡片有层次。已上的线亮一点。
            LineSpotlight(line: line, fill: false, maxPixel: Self.maxPixel, showNumbers: false,
                          dim: line.status == .sent ? 0.52 : 0.66,
                          focus: SpotlightGeometry.focusRect(for: line.holds, padding: 0.35, minSize: 0.45))
                .saturation(line.status == .gone ? 0.5 : 1)
                .padding(.top, 96)
                .padding(.bottom, 150)
                .visualEffect { content, proxy in
                    content.offset(x: proxy.frame(in: .scrollView(axis: .horizontal)).minX * -0.15)
                }
                .homeZoomSource(id: line.id, in: zoomNamespace)
            BottomScrim(height: 340)
            textLayer
        }
        .background(Color.ink)
    }

    private var textLayer: some View {
        VStack(alignment: .leading, spacing: 7) {
            if hasCapsules {
                HStack(spacing: 6) {
                    if line.status != .projecting {
                        StatusCapsule(title: line.status.title, systemImage: line.status.symbol,
                                      tint: line.status == .sent ? Color.accent : .white)
                    }
                    if line.cycle > 1 {
                        StatusCapsule(title: "第 \(line.cycle) 轮", systemImage: "arrow.counterclockwise")
                    }
                    if !line.hasPhoto {
                        StatusCapsule(title: "无照片", systemImage: "photo")
                    }
                }
                .padding(.bottom, 2)
            }
            Text(headline)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
            if let visit = HomeCardText.visitLine(visitCount: line.visitCount, lastFall: line.lastFallLine) {
                Text(visit)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let reminder = line.reminderText, !reminder.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: line.reminderVerified ? "checkmark.seal.fill" : "lightbulb.fill")
                        .font(.footnote.weight(.semibold))
                    Text(reminder)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .foregroundStyle(Color.accent)
                .padding(.top, 1)
                .accessibilityLabel(line.reminderVerified ? "已验证的提醒：\(reminder)" : "提醒：\(reminder)")
            } else if line.visitCount == 0 {
                Text("还没记录 · 爬完点进来记一次")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtle)
            }
        }
        .padding(.horizontal, 22)
        .padding(.trailing, 60)
        .padding(.bottom, 100)
    }

    private var hasCapsules: Bool { line.status != .projecting || line.cycle > 1 || !line.hasPhoto }

    private var headline: String {
        HomeCardText.headline(area: line.wall?.areaName, grade: line.gradeText, fallbackName: line.name)
    }
}

// MARK: - 空态

/// 空态 = 一句话 + 一个动作。图用一条示意线，和真正的卡片长得一样。
struct HomeEmptyState: View {
    var hasAnyLine: Bool
    var filter: HomeFilter
    var gymName: String?
    var onAdd: () -> Void
    var onShowAll: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            SpotlightImage(image: nil, aspect: 0.75, holds: HomeArt.sampleHolds,
                           startHoldIDs: [HomeArt.sampleHolds[0].id], finishHoldID: HomeArt.sampleHolds.last?.id,
                           showNumbers: false, dim: 0.35)
                .frame(width: 210, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.08)))
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.subtle)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            VStack(spacing: 14) {
                if primaryIsAdd {
                    Button("去建一条线", action: onAdd).buttonStyle(BigButtonStyle()).frame(width: 220)
                } else {
                    Button("看全部", action: onShowAll).buttonStyle(BigButtonStyle()).frame(width: 220)
                }
                if hasAnyLine && filter != .all && primaryIsAdd {
                    Button("看全部", action: onShowAll)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.subtle)
                }
            }
            Spacer()
            Spacer()
        }
        .padding(.top, 40)
    }

    /// 没有任何线 / 全部为空 / 今天为空 → 主动作是建线；进行中 / 上了 为空 → 主动作是看全部。
    private var primaryIsAdd: Bool {
        if !hasAnyLine { return true }
        switch filter {
        case .all, .today: return true
        case .projecting, .sent: return false
        }
    }

    private var title: String {
        if !hasAnyLine { return "还没有线" }
        switch filter {
        case .projecting: return "没有进行中的线"
        case .today: return "今天还没爬"
        case .sent: return "还没有上了的线"
        case .all: return gymName == nil ? "还没有线" : "\(gymName!) 还没有线"
        }
    }

    private var detail: String {
        if !hasAnyLine { return "拍一面墙，点亮你要爬的点。" }
        switch filter {
        case .today: return "爬完在线路页点 +1，这里就会出现。"
        case .projecting: return "所有线都上了或放下了，去看全部。"
        case .sent: return "上了一条就来这里收着。"
        case .all: return "拍一面墙，点亮你要爬的点。"
        }
    }
}

/// 首页示意用的一条“线”：无照片时画在渐变底上。
enum HomeArt {
    static let sampleHolds: [Hold] = [
        Hold(x: 0.36, y: 0.84, r: 0.05), Hold(x: 0.58, y: 0.70, r: 0.045), Hold(x: 0.42, y: 0.55, r: 0.05),
        Hold(x: 0.62, y: 0.40, r: 0.04), Hold(x: 0.46, y: 0.24, r: 0.05), Hold(x: 0.56, y: 0.10, r: 0.045),
    ]
}
