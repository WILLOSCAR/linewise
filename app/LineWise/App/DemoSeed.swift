import SwiftData
import SwiftUI

/// 演示数据：只在 DEBUG 且启动参数含 `-seedDemo` 时写入（数据库为空时）。
/// 用法：xcrun simctl launch <udid> com.linewise.app -seedDemo
enum DemoSeed {
    static var isRequested: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("-seedDemo")
        #else
        return false
        #endif
    }

    @MainActor
    static func seedIfNeeded(context: ModelContext, appState: AppState) {
        guard isRequested else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Line>())) ?? 0
        guard existing == 0 else { return }
        let store = Store(context)
        let gym = store.gyms().first ?? store.addGym(name: "岩时·望京")
        gym.name = "岩时·望京"
        appState.currentGymID = gym.id

        let calendar = Calendar.current
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: .now)! }

        // 墙 1：斜板墙，两条线
        let wall1 = makeWall(store: store, gym: gym, area: "斜板墙", angle: .slab, seed: 11)
        let lineA = makeLine(store: store, wall: wall1, color: 0, grade: "V3", name: "斜板墙 · 蓝")
        let lineB = makeLine(store: store, wall: wall1, color: 2, grade: "V5", name: "斜板墙 · 红")

        // 墙 2：仰角墙，一条线
        let wall2 = makeWall(store: store, gym: gym, area: "仰角墙", angle: .overhang, seed: 23)
        let lineC = makeLine(store: store, wall: wall2, color: 4, grade: "V4", name: "仰角墙 · 紫")

        // 墙 3：直壁，一条已上的线 + 一条新线
        let wall3 = makeWall(store: store, gym: gym, area: "直壁", angle: .vertical, seed: 37)
        let lineD = makeLine(store: store, wall: wall3, color: 1, grade: "V2", name: "直壁 · 绿")
        let lineE = makeLine(store: store, wall: wall3, color: 3, grade: "V6", name: "直壁 · 黄")
        lineE.createdAt = daysAgo(4)
        lineE.updatedAt = daysAgo(4)

        // 记录：lineA 三次馆访，掉在不同点
        let holdsA = HoldNumbering.ordered(lineA.holds)
        seedSession(store: store, line: lineA, date: daysAgo(9), attempts: 6, fall: holdsA[min(2, holdsA.count - 1)].id, reason: .feet, note: "右脚先踩高再出手")
        seedSession(store: store, line: lineA, date: daysAgo(5), attempts: 4, fall: holdsA[min(4, holdsA.count - 1)].id, reason: .feet, note: "左手抓到就要顶髌")
        seedSession(store: store, line: lineA, date: daysAgo(1), attempts: 3, fall: holdsA[min(4, holdsA.count - 1)].id, reason: .body, note: nil)

        // lineB 一次
        let holdsB = HoldNumbering.ordered(lineB.holds)
        seedSession(store: store, line: lineB, date: daysAgo(5), attempts: 2, fall: holdsB[min(1, holdsB.count - 1)].id, reason: .reach, note: "起步就够不着，试试侧身")

        // lineC 两次，今天有一次
        let holdsC = HoldNumbering.ordered(lineC.holds)
        seedSession(store: store, line: lineC, date: daysAgo(3), attempts: 5, fall: holdsC[min(3, holdsC.count - 1)].id, reason: .power, note: "翻身前先休息")
        let today = store.todaySession(for: lineC, source: .inGym)
        today.attemptCount = 2

        // lineD 上了
        seedSession(store: store, line: lineD, date: daysAgo(12), attempts: 3, fall: nil, reason: nil, note: "脚要踩准", sent: true)
        lineD.status = .sent
        // 一个计划顺序
        if holdsA.count >= 4 {
            lineA.planSequence = ClimbSequence(steps: [
                SequenceStep(limb: .rightFoot, holdID: holdsA[0].id),
                SequenceStep(limb: .leftHand, holdID: holdsA[1].id),
                SequenceStep(limb: .leftFoot, holdID: holdsA[1].id),
                SequenceStep(limb: .rightHand, holdID: holdsA[2].id),
                SequenceStep(limb: .leftHand, holdID: holdsA[3].id),
            ])
        }
        store.save()

        // 真实墙照片（只在开发机上，通过 `-demoPhotosDir <路径>` 传入；不进仓库）。
        // 放最后，让真实照片的线排在首页最前。
        if let dir = demoPhotosDirectory {
            seedRealWalls(store: store, gym: gym, dir: dir, daysAgo: daysAgo)
        }
    }

    // MARK: 真实照片

    static var demoPhotosDirectory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-demoPhotosDir"), i + 1 < args.count else { return nil }
        let url = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 已知照片的点位（归一化坐标，按文件名匹配）。
    private static let knownLines: [String: [(area: String, angle: WallAngle, lines: [(name: String, grade: String, holds: [(Double, Double, Double)])])]] = [
        "wall-yellow": [(area: "直壁·黄", angle: .vertical, lines: [
            (name: "直壁 · 黄", grade: "V3", holds: [
                (0.340, 0.680, 0.028), (0.416, 0.667, 0.028), (0.582, 0.672, 0.036),
                (0.618, 0.594, 0.024), (0.507, 0.557, 0.030), (0.615, 0.545, 0.026),
                (0.465, 0.496, 0.044), (0.371, 0.500, 0.028), (0.625, 0.390, 0.040),
            ]),
        ])],
        "wall-white": [(area: "大斜板", angle: .slab, lines: [
            (name: "大斜板 · 白", grade: "V4", holds: [
                (0.700, 0.790, 0.034), (0.575, 0.735, 0.040), (0.455, 0.600, 0.052),
                (0.555, 0.530, 0.028), (0.565, 0.480, 0.040), (0.505, 0.415, 0.050),
                (0.455, 0.370, 0.045), (0.585, 0.262, 0.045),
            ]),
            (name: "大斜板 · 紫", grade: "V2", holds: [
                (0.165, 0.775, 0.035), (0.245, 0.765, 0.025), (0.255, 0.670, 0.028),
                (0.155, 0.600, 0.036), (0.245, 0.495, 0.036), (0.215, 0.405, 0.045), (0.125, 0.325, 0.045),
            ]),
        ])],
    ]

    @MainActor
    private static func seedRealWalls(store: Store, gym: Gym, dir: URL, daysAgo: (Int) -> Date) {
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in files {
            guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { continue }
            let key = file.deletingPathExtension().lastPathComponent
            let spec = knownLines[key]?.first
            let wall = try! store.createWall(gym: gym, image: image, areaName: spec?.area ?? key, angle: spec?.angle ?? .unknown)
            guard let spec else { continue }
            for (idx, l) in spec.lines.enumerated() {
                let holds = l.holds.map { Hold(x: $0.0, y: $0.1, r: $0.2) }
                let sf = HoldNumbering.defaultStartAndFinish(holds)
                let line = store.createLine(wall: wall, holds: holds, startHoldIDs: sf.start, finishHoldID: sf.finish,
                                            gradeText: l.grade, gradeSource: .manual, name: l.name)
                let ordered = HoldNumbering.ordered(holds)
                if idx == 0 {
                    seedSession(store: store, line: line, date: daysAgo(6), attempts: 5, fall: ordered[min(3, ordered.count - 1)].id, reason: .feet, note: "右脚先踩高再出手")
                    seedSession(store: store, line: line, date: daysAgo(2), attempts: 3, fall: ordered[min(4, ordered.count - 1)].id, reason: .body, note: "贴墙再翻")
                    // 今天已经在馆内点过 +1，线路页会出现“上次这句有用吗？”
                    let today = store.todaySession(for: line, source: .inGym)
                    today.attemptCount = 2
                    if ordered.count >= 5 {
                        line.planSequence = ClimbSequence(steps: [
                            SequenceStep(limb: .rightFoot, holdID: ordered[0].id),
                            SequenceStep(limb: .leftHand, holdID: ordered[2].id),
                            SequenceStep(limb: .leftFoot, holdID: ordered[1].id),
                            SequenceStep(limb: .rightHand, holdID: ordered[3].id),
                            SequenceStep(limb: .leftHand, holdID: ordered[4].id),
                        ])
                    }
                } else {
                    seedSession(store: store, line: line, date: daysAgo(2), attempts: 2, fall: nil, reason: nil, note: "脚要踩准", sent: true)
                    line.status = .sent
                }
            }
        }
        store.save()
    }

    @MainActor
    private static func seedSession(store: Store, line: Line, date: Date, attempts: Int, fall: UUID?, reason: FailReason?, note: String?, sent: Bool = false) {
        let s = store.newSession(for: line, date: date)
        s.attemptCount = attempts
        s.sent = sent
        s.fallHoldID = fall
        s.reason = reason
        s.note = note
        s.createdAt = date
        store.commitSession(s, line: line, fallLabel: line.label(for: fall))
    }

    // MARK: 合成墙照片

    /// 六种线路颜色。
    private static let palette: [UIColor] = [
        UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1), // 蓝
        UIColor(red: 0.25, green: 0.75, blue: 0.40, alpha: 1), // 绿
        UIColor(red: 0.92, green: 0.28, blue: 0.28, alpha: 1), // 红
        UIColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1), // 黄
        UIColor(red: 0.62, green: 0.38, blue: 0.85, alpha: 1), // 紫
        UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1), // 黑
    ]

    private struct DrawnHold {
        var color: Int
        var x: Double
        var y: Double
        var r: Double
    }

    @MainActor
    private static func makeWall(store: Store, gym: Gym, area: String, angle: WallAngle, seed: UInt64) -> Wall {
        var rng = SeededGenerator(seed: seed)
        let size = CGSize(width: 1536, height: 2048)
        var drawn: [DrawnHold] = []
        // 每种颜色一条线：从下到上 7–9 个点，横向随机漂移
        for color in 0..<palette.count {
            let count = 7 + Int(rng.next() % 3)
            var x = 0.2 + Double(color) * 0.12 + Double(rng.next() % 80) / 1000
            for i in 0..<count {
                let t = Double(i) / Double(count - 1)
                let y = 0.9 - t * 0.78 + (Double(rng.next() % 60) - 30) / 1000
                x += (Double(rng.next() % 140) - 70) / 1000
                x = min(max(x, 0.12), 0.88)
                let r = 0.018 + Double(rng.next() % 14) / 1000
                drawn.append(DrawnHold(color: color, x: x, y: y, r: r))
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            // 墙面：暖灰木板
            let base = UIColor(red: 0.72, green: 0.70, blue: 0.66, alpha: 1)
            base.setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            for i in 0..<6 {
                let shade = UIColor(white: 0.62 + Double(rng.next() % 12) / 100, alpha: 0.5)
                shade.setFill()
                cg.fill(CGRect(x: 0, y: CGFloat(i) * size.height / 6, width: size.width, height: size.height / 6 - 6))
            }
            // T-nut 孔阵
            UIColor(white: 0.45, alpha: 0.35).setFill()
            var yy: CGFloat = 40
            while yy < size.height {
                var xx: CGFloat = 40
                while xx < size.width {
                    cg.fillEllipse(in: CGRect(x: xx - 3, y: yy - 3, width: 6, height: 6))
                    xx += 96
                }
                yy += 96
            }
            // 大体块
            UIColor(red: 0.85, green: 0.84, blue: 0.80, alpha: 1).setFill()
            let vol = UIBezierPath()
            vol.move(to: CGPoint(x: size.width * 0.55, y: size.height * 0.62))
            vol.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.58))
            vol.addLine(to: CGPoint(x: size.width * 0.70, y: size.height * 0.40))
            vol.close()
            vol.fill()
            // 点
            for h in drawn {
                let c = palette[h.color]
                let cx = h.x * size.width
                let cy = h.y * size.height
                let rr = h.r * size.width
                cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.35).cgColor)
                c.setFill()
                let shape = Int(rng.next() % 3)
                switch shape {
                case 0:
                    cg.fillEllipse(in: CGRect(x: cx - rr, y: cy - rr * 0.8, width: rr * 2, height: rr * 1.6))
                case 1:
                    let p = UIBezierPath(roundedRect: CGRect(x: cx - rr, y: cy - rr * 0.7, width: rr * 2, height: rr * 1.4), cornerRadius: rr * 0.5)
                    p.fill()
                default:
                    let p = UIBezierPath()
                    p.move(to: CGPoint(x: cx - rr, y: cy + rr * 0.7))
                    p.addLine(to: CGPoint(x: cx + rr, y: cy + rr * 0.6))
                    p.addLine(to: CGPoint(x: cx + rr * 0.2, y: cy - rr * 0.9))
                    p.close()
                    p.fill()
                }
                cg.setShadow(offset: .zero, blur: 0, color: nil)
            }
            // 难度标签贴纸
            UIColor.white.setFill()
            let tag = CGRect(x: size.width * 0.08, y: size.height * 0.955, width: 150, height: 64)
            UIBezierPath(roundedRect: tag, cornerRadius: 8).fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 44, weight: .bold), .foregroundColor: UIColor.black]
            ("V\(3 + Int(seed % 4))" as NSString).draw(at: CGPoint(x: tag.minX + 30, y: tag.minY + 6), withAttributes: attrs)
        }

        let wall = try! store.createWall(gym: gym, image: image, areaName: area, angle: angle)
        drawnByWall[wall.id] = drawn
        return wall
    }

    @MainActor private static var drawnByWall: [UUID: [DrawnHold]] = [:]

    @MainActor
    private static func makeLine(store: Store, wall: Wall, color: Int, grade: String, name: String) -> Line {
        let drawn = (drawnByWall[wall.id] ?? []).filter { $0.color == color }
        let holds = drawn.map { Hold(x: $0.x, y: $0.y, r: max(0.03, $0.r * 1.6)) }
        let sf = HoldNumbering.defaultStartAndFinish(holds)
        return store.createLine(wall: wall, holds: holds, startHoldIDs: sf.start, finishHoldID: sf.finish,
                                gradeText: grade, gradeSource: .manual, name: name)
    }
}

/// 可复现的伪随机数。
private struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
