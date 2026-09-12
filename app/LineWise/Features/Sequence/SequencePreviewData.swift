#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 预览 / 调试用的演示线：内存库 + 一面合成的墙照片 + 7 个点。
@MainActor
enum SequencePreviewData {
    struct Demo {
        let container: ModelContainer
        let line: Line
    }

    /// 从下到上 7 个点（归一化坐标）。
    static let demoPoints: [(x: Double, y: Double)] = [
        (0.30, 0.90), (0.44, 0.78), (0.28, 0.66), (0.52, 0.55), (0.38, 0.42), (0.60, 0.30), (0.46, 0.14),
    ]

    static func make(withPhoto: Bool = true, plan: Bool = true, actual: Bool = false) -> Demo {
        let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let store = Store(container.mainContext)
        let gym = store.addGym(name: "演示岩馆")
        let wall = try! store.createWall(gym: gym, image: withPhoto ? wallImage() : nil, areaName: "斜板墙", angle: .slab)
        let holds = demoPoints.map { Hold(x: $0.x, y: $0.y, r: 0.045) }
        let sf = HoldNumbering.defaultStartAndFinish(holds)
        let line = store.createLine(wall: wall, holds: holds, startHoldIDs: sf.start, finishHoldID: sf.finish,
                                    gradeText: "V3", gradeSource: .manual, name: "斜板墙 · 蓝")
        let ordered = HoldNumbering.ordered(holds)
        if plan {
            line.planSequence = ClimbSequence(steps: [
                SequenceStep(limb: .rightFoot, holdID: ordered[0].id),
                SequenceStep(limb: .leftHand, holdID: ordered[1].id),
                SequenceStep(limb: .leftFoot, holdID: ordered[1].id),
                SequenceStep(limb: .rightHand, holdID: ordered[3].id),
                SequenceStep(limb: .leftHand, holdID: ordered[4].id),
                SequenceStep(limb: .rightFoot, holdID: ordered[2].id),
                SequenceStep(limb: .rightHand, holdID: ordered[6].id),
                SequenceStep(limb: .leftHand, holdID: ordered[6].id),
            ])
        }
        if actual {
            line.actualSequence = ClimbSequence(steps: [
                SequenceStep(limb: .rightFoot, holdID: ordered[0].id),
                SequenceStep(limb: .leftHand, holdID: ordered[1].id),
                SequenceStep(limb: .leftFoot, holdID: ordered[0].id),
                SequenceStep(limb: .rightHand, holdID: ordered[3].id),
                SequenceStep(limb: .leftHand, holdID: ordered[5].id),
                SequenceStep(limb: .rightHand, holdID: ordered[6].id),
            ])
        }
        store.save()
        return Demo(container: container, line: line)
    }

    /// 合成一张 3:4 的“墙”：渐变木板 + 点的位置上画几个色块。
    static func wallImage() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(red: 0.74, green: 0.71, blue: 0.66, alpha: 1).cgColor,
                          UIColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            UIColor(white: 0.42, alpha: 0.3).setFill()
            for row in 0..<12 {
                for col in 0..<9 {
                    cg.fillEllipse(in: CGRect(x: 50 + col * 100 - 3, y: 50 + row * 100 - 3, width: 6, height: 6))
                }
            }
            for (i, p) in demoPoints.enumerated() {
                let c = CGPoint(x: p.x * size.width, y: p.y * size.height)
                let r: CGFloat = 26 + CGFloat(i % 3) * 6
                cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.35).cgColor)
                UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1).setFill()
                cg.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r * 0.8, width: r * 2, height: r * 1.6))
                cg.setShadow(offset: .zero, blur: 0, color: nil)
            }
        }
    }
}
#endif
