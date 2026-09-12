import SwiftUI

/// 给一条线渲染聚光灯图：异步加载墙照片并缓存。
struct LineSpotlight: View {
    let line: Line
    var fill: Bool = false
    var maxPixel: Int = 1400
    var showNumbers: Bool = true
    var fallMarks: [FallMark] = []
    var highlightedHoldID: UUID?
    var pose: StickFigurePose?
    var reveal: Double = 1
    var dim: Double = 0.66

    @State private var image: UIImage?

    var body: some View {
        let aspect = line.wall?.aspectRatio ?? 0.75
        SpotlightImage(
            image: image,
            aspect: aspect,
            holds: line.holds,
            startHoldIDs: line.startHoldIDs,
            finishHoldID: line.finishHoldID,
            fallMarks: fallMarks,
            highlightedHoldID: highlightedHoldID,
            pose: pose,
            poseIsoAspect: aspect,
            fill: fill,
            showNumbers: showNumbers,
            dim: dim,
            reveal: reveal
        )
        .task(id: "\(line.wall?.photoFileName ?? "")#\(maxPixel)") {
            guard let name = line.wall?.photoFileName else { image = nil; return }
            if let cached = ImageStore.load(fileName: name, maxPixel: maxPixel), image == nil {
                image = cached
                return
            }
            let loaded = await ImageStore.loadAsync(fileName: name, maxPixel: maxPixel)
            if !Task.isCancelled { image = loaded }
        }
    }
}

extension Line {
    /// 历史掉落点 → 标记。`sessions` 允许传入筛选后的子集。
    func fallMarks(from sessions: [Session]? = nil) -> [FallMark] {
        let list = (sessions ?? orderedSessions).filter { $0.fallHoldID != nil }
        guard !list.isEmpty else { return [] }
        let dates = Array(Set(list.map(\.date))).sorted()
        var grouped: [UUID: (count: Int, latest: Date)] = [:]
        for s in list {
            let id = s.fallHoldID!
            let cur = grouped[id]
            grouped[id] = (count: (cur?.count ?? 0) + 1, latest: max(cur?.latest ?? .distantPast, s.date))
        }
        return grouped.map { id, v in
            let rank = dates.firstIndex(of: v.latest) ?? 0
            let recency = dates.count > 1 ? Double(rank) / Double(dates.count - 1) : 1
            return FallMark(holdID: id, count: v.count, recency: recency)
        }
    }
}
