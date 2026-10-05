import Foundation

/// 墙照片上的一个点。坐标归一化到 0...1（x 左→右，y 上→下）。
/// `r` 是相对于照片短边的半径比例。
struct Hold: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var x: Double
    var y: Double
    var r: Double
    var polygon: [NormalizedPoint]?
    var anchor: NormalizedPoint?
    var segmentationVersion: String?
    var prefersCircle: Bool

    static let defaultRadius: Double = 0.04
    static let minRadius: Double = 0.02
    static let maxRadius: Double = 0.09

    init(id: UUID = UUID(), x: Double, y: Double, r: Double = Hold.defaultRadius,
         polygon: [NormalizedPoint]? = nil, anchor: NormalizedPoint? = nil, segmentationVersion: String? = nil,
         prefersCircle: Bool = false) {
        self.id = id
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
        self.r = min(max(r, Hold.minRadius), Hold.maxRadius)
        self.polygon = HoldContour(points: polygon ?? [])?.points
        self.anchor = anchor
        self.segmentationVersion = self.polygon == nil ? nil : segmentationVersion
        self.prefersCircle = prefersCircle
    }

    var contour: HoldContour? { polygon.flatMap { HoldContour(points: $0) } }

    /// Hand/foot contact is independent of the contour's centre and the original tap.
    var contactPoint: NormalizedPoint {
        guard let contour else { return .init(x: x, y: y) }
        if let anchor, contour.contains(anchor) { return anchor }
        return contour.closestPoint(to: .init(x: x, y: y))
    }

    mutating func clearContour() { polygon = nil; anchor = nil; segmentationVersion = nil }

    private enum CodingKeys: String, CodingKey { case id, x, y, r, polygon, anchor, segmentationVersion, prefersCircle }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id), x: try c.decode(Double.self, forKey: .x),
                  y: try c.decode(Double.self, forKey: .y), r: try c.decode(Double.self, forKey: .r),
                  polygon: try? c.decodeIfPresent([NormalizedPoint].self, forKey: .polygon),
                  anchor: try? c.decodeIfPresent(NormalizedPoint.self, forKey: .anchor),
                  segmentationVersion: try? c.decodeIfPresent(String.self, forKey: .segmentationVersion),
                  prefersCircle: (try? c.decodeIfPresent(Bool.self, forKey: .prefersCircle)) ?? false)
    }
}

/// 点的自动编号：从下往上 1…N，同高从左往右。
enum HoldNumbering {
    /// 按编号顺序返回点。
    static func ordered(_ holds: [Hold]) -> [Hold] {
        holds.sorted { a, b in
            if abs(a.y - b.y) > 0.005 { return a.y > b.y } // y 大的在下面，先编号
            return a.x < b.x
        }
    }

    /// 返回 id → 编号（从 1 开始）。
    static func numbers(for holds: [Hold]) -> [UUID: Int] {
        var map: [UUID: Int] = [:]
        for (i, hold) in ordered(holds).enumerated() {
            map[hold.id] = i + 1
        }
        return map
    }

    /// 默认起步（最低）与结束（最高）。
    static func defaultStartAndFinish(_ holds: [Hold]) -> (start: [UUID], finish: UUID?) {
        let ordered = ordered(holds)
        guard let first = ordered.first else { return ([], nil) }
        guard ordered.count > 1, let last = ordered.last else { return ([first.id], nil) }
        return ([first.id], last.id)
    }
}

/// 编号显示：①…㊿，超过用 #n。
enum HoldLabel {
    static func circled(_ n: Int) -> String {
        switch n {
        case 1...20:
            return String(UnicodeScalar(0x2460 + UInt32(n - 1))!)
        case 21...35:
            return String(UnicodeScalar(0x3251 + UInt32(n - 21))!)
        case 36...50:
            return String(UnicodeScalar(0x32B1 + UInt32(n - 36))!)
        default:
            return "#\(n)"
        }
    }
}
