#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 线路页 / 记这一次 的 Preview 数据：内存库 + 一条带 3 次记录的演示线。
enum LineDetailPreviewData {
    struct Sample {
        let container: ModelContainer
        let line: Line
    }

    @MainActor
    static func make(withPhoto: Bool = true, cycles: Int = 1) -> Sample {
        let schema = Schema([Gym.self, Wall.self, Line.self, Session.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let store = Store(context)

        let gym = store.addGym(name: "岩时·望京")
        let holds = withPhoto ? sampleHolds() : []
        let image = withPhoto ? wallImage(holds: holds) : nil
        let wall = try! store.createWall(gym: gym, image: image, areaName: "斜板墙", angle: .slab)
        let sf = HoldNumbering.defaultStartAndFinish(holds)
        let line = store.createLine(wall: wall, holds: holds, startHoldIDs: sf.start, finishHoldID: sf.finish,
                                    gradeText: "V4", gradeSource: .manual, name: withPhoto ? "斜板墙 · 蓝" : "斜板墙 · 无照片")
        // 同墙另一条，用于“合并到另一条…”
        _ = store.createLine(wall: wall, holds: holds.reversed(), startHoldIDs: sf.start, finishHoldID: sf.finish,
                             gradeText: "V5", gradeSource: .manual, name: "斜板墙 · 红")

        let ordered = HoldNumbering.ordered(holds)
        func hold(_ i: Int) -> UUID? { ordered.indices.contains(i) ? ordered[i].id : nil }
        func daysAgo(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: -n, to: .now)! }

        if cycles > 1 {
            seed(store, line, date: daysAgo(40), attempts: 5, fall: hold(1), reason: .reach, note: "起步够不着")
            line.status = .sent
            _ = store.apply(.newCycle, to: line)
        }
        seed(store, line, date: daysAgo(9), attempts: 6, fall: hold(2), reason: .feet, note: "右脚先踩高再出手")
        seed(store, line, date: daysAgo(5), attempts: 4, fall: hold(4), reason: .feet, note: "左手抓到就要顶髌")
        seed(store, line, date: daysAgo(1), attempts: 3, fall: hold(4), reason: .body, note: nil)

        if ordered.count >= 4 {
            line.planSequence = ClimbSequence(steps: [
                SequenceStep(limb: .rightFoot, holdID: ordered[0].id),
                SequenceStep(limb: .leftHand, holdID: ordered[1].id),
                SequenceStep(limb: .leftFoot, holdID: ordered[1].id),
                SequenceStep(limb: .rightHand, holdID: ordered[2].id),
                SequenceStep(limb: .leftHand, holdID: ordered[3].id),
            ])
        }
        store.save()
        return Sample(container: container, line: line)
    }

    @MainActor
    private static func seed(_ store: Store, _ line: Line, date: Date, attempts: Int, fall: UUID?, reason: FailReason?, note: String?) {
        let s = store.newSession(for: line, date: date)
        s.attemptCount = attempts
        s.fallHoldID = fall
        s.reason = reason
        s.note = note
        s.createdAt = date
        store.commitSession(s, line: line, fallLabel: line.label(for: fall))
    }

    private static func sampleHolds() -> [Hold] {
        let points: [(Double, Double)] = [
            (0.42, 0.90), (0.55, 0.78), (0.38, 0.66), (0.60, 0.55),
            (0.47, 0.44), (0.63, 0.33), (0.50, 0.22), (0.56, 0.10),
        ]
        return points.map { Hold(x: $0.0, y: $0.1, r: 0.04) }
    }

    /// 合成一张 3:4 的“墙”：暖灰底 + 彩色点。
    private static func wallImage(holds: [Hold]) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.70, green: 0.68, blue: 0.64, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            for i in 0..<8 {
                UIColor(white: 0.60 + Double(i % 3) * 0.05, alpha: 0.6).setFill()
                cg.fill(CGRect(x: 0, y: CGFloat(i) * size.height / 8, width: size.width, height: size.height / 8 - 4))
            }
            // 别的线的点（干扰项）
            let others: [(CGFloat, CGFloat, UIColor)] = [
                (0.15, 0.85, .systemGreen), (0.22, 0.60, .systemGreen), (0.18, 0.35, .systemGreen),
                (0.82, 0.80, .systemPurple), (0.78, 0.50, .systemPurple), (0.85, 0.25, .systemPurple),
            ]
            for (x, y, color) in others {
                color.setFill()
                cg.fillEllipse(in: CGRect(x: x * size.width - 26, y: y * size.height - 20, width: 52, height: 40))
            }
            UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1).setFill()
            for h in holds {
                let r = h.r * min(size.width, size.height) * 0.8
                cg.fillEllipse(in: CGRect(x: h.x * size.width - r, y: h.y * size.height - r * 0.8, width: r * 2, height: r * 1.6))
            }
        }
    }
}
#endif
