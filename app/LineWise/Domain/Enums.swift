import Foundation

/// 线的状态。见 PRD §4.5。
enum LineStatus: String, Codable, CaseIterable, Sendable {
    case projecting
    case sent
    case dropped
    case gone

    var title: String {
        switch self {
        case .projecting: "进行中"
        case .sent: "上了"
        case .dropped: "放弃"
        case .gone: "没了"
        }
    }

    var symbol: String {
        switch self {
        case .projecting: "circle.dotted"
        case .sent: "checkmark.circle.fill"
        case .dropped: "minus.circle"
        case .gone: "xmark.circle"
        }
    }
}

/// 状态行菜单里的动作。
enum LineAction: String, CaseIterable, Sendable {
    case markSent
    case drop
    case markGone
    case newCycle

    var title: String {
        switch self {
        case .markSent: "标上了"
        case .drop: "放弃"
        case .markGone: "没了"
        case .newCycle: "再磕一轮"
        }
    }

    var symbol: String {
        switch self {
        case .markSent: "checkmark.circle"
        case .drop: "minus.circle"
        case .markGone: "xmark.circle"
        case .newCycle: "arrow.counterclockwise.circle"
        }
    }
}

/// 掉下来的主要原因，8 选 1。
enum FailReason: String, Codable, CaseIterable, Sendable {
    case sequence
    case feet
    case body
    case timing
    case reach
    case fear
    case power
    case unknown

    var title: String {
        switch self {
        case .sequence: "顺序"
        case .feet: "脚"
        case .body: "身体"
        case .timing: "时机"
        case .reach: "够不着"
        case .fear: "不敢"
        case .power: "没力"
        case .unknown: "不知道"
        }
    }
}

/// 对上次提醒的回答。
enum ReminderCheck: String, Codable, CaseIterable, Sendable {
    case worked
    case noChange = "no_change"
    case differentProblem = "different_problem"
    case notTested = "not_tested"

    var title: String {
        switch self {
        case .worked: "有用"
        case .noChange: "没变化"
        case .differentProblem: "问题变了"
        case .notTested: "没试"
        }
    }
}

/// 一条记录是怎么来的。
enum SessionSource: String, Codable, Sendable {
    case inGym = "in_gym"
    case after
    case backfill
}

enum WallAngle: String, Codable, CaseIterable, Sendable {
    case unknown
    case slab
    case vertical
    case overhang
    case roof

    var title: String {
        switch self {
        case .unknown: "未选"
        case .slab: "斜板"
        case .vertical: "直壁"
        case .overhang: "仰角"
        case .roof: "屋顶"
        }
    }
}

enum FeltGrade: String, Codable, CaseIterable, Sendable {
    case soft
    case fair
    case hard

    var title: String {
        switch self {
        case .soft: "偏软"
        case .fair: "正常"
        case .hard: "偏硬"
        }
    }
}

enum GradeSource: String, Codable, Sendable {
    case ocr
    case manual
}

enum Limb: String, Codable, CaseIterable, Sendable, Hashable {
    case leftHand = "lh"
    case rightHand = "rh"
    case leftFoot = "lf"
    case rightFoot = "rf"

    var title: String {
        switch self {
        case .leftHand: "左手"
        case .rightHand: "右手"
        case .leftFoot: "左脚"
        case .rightFoot: "右脚"
        }
    }

    var shortTitle: String {
        switch self {
        case .leftHand: "左手"
        case .rightHand: "右手"
        case .leftFoot: "左脚"
        case .rightFoot: "右脚"
        }
    }

    var isHand: Bool { self == .leftHand || self == .rightHand }
    var isLeft: Bool { self == .leftHand || self == .leftFoot }

    var symbol: String { isHand ? "hand.raised.fill" : "shoeprints.fill" }
}
