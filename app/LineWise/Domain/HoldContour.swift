import Foundation

struct NormalizedPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
}

/// Validated, bounded polygon stored in normalized photo coordinates, never as a mask image.
struct HoldContour: Hashable, Sendable {
    static let maximumPoints = 64
    let points: [NormalizedPoint]

    init?(points: [NormalizedPoint]) {
        guard (3...Self.maximumPoints).contains(points.count),
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }),
              Set(points).count >= 3 else { return nil }
        self.points = points
        guard area > 0.0000001 else { return nil }
    }

    var area: Double {
        abs(edges.reduce(0) { $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y }) / 2
    }

    var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        (points.map(\.x).min()!, points.map(\.y).min()!, points.map(\.x).max()!, points.map(\.y).max()!)
    }

    func contains(_ p: NormalizedPoint) -> Bool {
        guard p.x.isFinite, p.y.isFinite else { return false }
        var inside = false
        for (a, b) in edges {
            if distanceSquared(p, projection(of: p, onto: a, b)) < 1e-16 { return true }
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
        }
        return inside
    }

    func closestPoint(to p: NormalizedPoint) -> NormalizedPoint {
        if contains(p) { return p }
        return edges.map { projection(of: p, onto: $0.0, $0.1) }
            .min { distanceSquared(p, $0) < distanceSquared(p, $1) }!
    }

    private var edges: [(NormalizedPoint, NormalizedPoint)] {
        points.indices.map { (points[$0], points[($0 + 1) % points.count]) }
    }

    private func projection(of p: NormalizedPoint, onto a: NormalizedPoint, _ b: NormalizedPoint) -> NormalizedPoint {
        let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
        let t = length > 0 ? min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length)) : 0
        return .init(x: a.x + dx * t, y: a.y + dy * t)
    }

    private func distanceSquared(_ a: NormalizedPoint, _ b: NormalizedPoint) -> Double {
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
    }
}
