import Foundation

/// 状态流转（PRD §4.5）。
enum LineStatusMachine {
    static func actions(for status: LineStatus) -> [LineAction] {
        switch status {
        case .projecting: [.markSent, .drop, .markGone]
        case .sent: [.newCycle, .markGone]
        case .dropped: [.newCycle, .markGone]
        case .gone: []
        }
    }

    /// 返回新的状态与轮次；不允许的动作返回 nil。
    static func apply(_ action: LineAction, status: LineStatus, cycle: Int) -> (status: LineStatus, cycle: Int)? {
        guard actions(for: status).contains(action) else { return nil }
        switch action {
        case .markSent: return (.sent, cycle)
        case .drop: return (.dropped, cycle)
        case .markGone: return (.gone, cycle)
        case .newCycle: return (.projecting, cycle + 1)
        }
    }
}
