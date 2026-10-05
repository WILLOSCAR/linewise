import CoreGraphics
import Foundation
import Testing
import SwiftUI
import UIKit
@testable import LineWise

@Suite("Demo A · 轮廓与过期结果")
struct HoldContourTests {
    let points: [NormalizedPoint] = [.init(x: 0.2, y: 0.45), .init(x: 0.8, y: 0.45),
                                     .init(x: 0.8, y: 0.55), .init(x: 0.2, y: 0.55)]

    @Test("旧 JSON 没有轮廓仍可完整读取，接触点回退圆心")
    func legacyJSON() throws {
        let id = UUID(), data = Data("{\"id\":\"\(id)\",\"x\":0.3,\"y\":0.8,\"r\":0.04}".utf8)
        let h = try JSONDecoder().decode(Hold.self, from: data)
        #expect(h.id == id && h.x == 0.3 && h.y == 0.8 && h.r == 0.04)
        #expect(h.polygon == nil && h.contactPoint == .init(x: 0.3, y: 0.8))
    }

    @Test("非法或过长轮廓回退；凹形内部判定与锚点保持独立")
    func validation() throws {
        #expect(HoldContour(points: []) == nil)
        #expect(HoldContour(points: [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 2, y: 1)]) == nil)
        #expect(HoldContour(points: Array(repeating: points, count: 17).flatMap { $0 }) == nil)
        #expect(HoldContour(points: [.init(x: 0, y: 0), .init(x: 0.2, y: 0.2), .init(x: 0.5, y: 0.5)]) == nil)
        let concave = try #require(HoldContour(points: [.init(x: 0.1, y: 0.1), .init(x: 0.8, y: 0.1),
                                                      .init(x: 0.8, y: 0.3), .init(x: 0.3, y: 0.3),
                                                      .init(x: 0.3, y: 0.8), .init(x: 0.1, y: 0.8)]))
        #expect(concave.contains(.init(x: 0.2, y: 0.5)))
        #expect(!concave.contains(.init(x: 0.6, y: 0.6)))
        let h = Hold(x: 0.5, y: 0.5, polygon: points, anchor: .init(x: 0.7, y: 0.5), segmentationVersion: "test")
        #expect(h.contactPoint == .init(x: 0.7, y: 0.5))
        #expect(try JSONDecoder().decode(Hold.self, from: JSONEncoder().encode(h)) == h)
    }

    @Test("长轮廓远离圆心仍能点到；顺序落点使用 anchor")
    func contourHitAndAnchor() {
        let h = Hold(x: 0.5, y: 0.5, polygon: points, anchor: .init(x: 0.7, y: 0.5))
        let size = CGSize(width: 400, height: 400), geo = SpotlightGeometry(size: size, aspect: 1, fill: false)
        #expect(geo.hold(at: CGPoint(x: 305, y: 200), in: [h], slop: 0)?.id == h.id)
        #expect(LightUpGeometry.hold(at: CGPoint(x: 305, y: 200), holds: [h], size: size,
                                     aspect: 1, transform: .identity, slop: 0)?.id == h.id)
        #expect(geo.contactPoint(h) == CGPoint(x: 280, y: 200))
        let contact = SpotlightGeometry.isoPoint(of: h, aspect: 0.75)
        #expect(abs(contact.x - 0.525) < 1e-10 && contact.y == 0.5)
        #expect(geo.outline(h).contains(CGPoint(x: 300, y: 200)))
        #expect(!geo.outline(h).contains(CGPoint(x: 200, y: 235)))
    }

    @Test("移动、改半径、删除或重建的点不会被旧推理结果覆盖")
    func staleSuggestions() throws {
        var draft = LightUpDraft()
        let h = draft.add(x: 0.5, y: 0.5), contour = try #require(HoldContour(points: points))
        draft.move(id: h.id, to: 0.6, y: 0.5)
        let staleMoved = draft.applyContour(contour, anchor: nil, version: "old", to: h)
        #expect(!staleMoved)
        let moved = try #require(draft.hold(id: h.id))
        let accepted = draft.applyContour(contour, anchor: nil, version: "new", to: moved)
        #expect(accepted)
        draft.grow(id: h.id)
        #expect(draft.hold(id: h.id)?.polygon == nil)
        let staleSized = draft.applyContour(contour, anchor: nil, version: "old", to: moved)
        #expect(!staleSized)
        draft.remove(id: h.id)
        let staleDeleted = draft.applyContour(contour, anchor: nil, version: "old", to: moved)
        #expect(!staleDeleted)
    }

    @Test("长岩点边缘可吸附到独立落点，不要求手指靠近圆心或 anchor")
    func snapLongContour() {
        let h = Hold(x: 0.5, y: 0.5, polygon: points, anchor: .init(x: 0.3, y: 0.5))
        let geo = SpotlightGeometry(size: .init(width: 400, height: 400), aspect: 1, fill: false)
        #expect(SequenceHitTesting.nearestSnapHold(to: .init(x: 315, y: 200), holds: [h], geo: geo, minThreshold: 14)?.id == h.id)
        #expect(geo.contactPoint(h) == .init(x: 120, y: 200))
    }
}
