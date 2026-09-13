import SwiftUI

/// 顺序画布的静态场景：这条线的点、墙比例、自动取景区域与起步状态。
/// 编辑器、胶片条缩略图、命中测试都从这里拿**同一套**几何，保证绘制与手势不错位。
struct SequenceScene: Equatable {
    /// 取景参数（规范 §4.7：线路页 hero 与顺序编辑器 padding 0.30 / minSize 0.5）。
    /// `extraBottom` 给站在垫子上的脚留空间。
    static let focusPadding = 0.30
    static let focusMinSize = 0.50
    static let focusExtraBottom = 0.12

    let holds: [Hold]
    let aspect: Double
    let startHoldIDs: [UUID]
    let finishHoldID: UUID?
    /// 归一化的取景区域；没有点时为 nil（整图 fit）。
    let focus: CGRect?
    /// 起步状态：双手在起步点，双脚在地面。
    let initial: ContactState

    init(holds: [Hold], aspect: Double, startHoldIDs: [UUID] = [], finishHoldID: UUID? = nil) {
        self.holds = holds
        self.aspect = max(aspect, 0.05)
        self.startHoldIDs = startHoldIDs
        self.finishHoldID = finishHoldID
        self.focus = Self.focusRect(for: holds)
        self.initial = SequenceReplay.initialState(startHoldIDs: startHoldIDs, holds: holds)
    }

    init(line: Line) {
        self.init(holds: line.holds, aspect: line.wall?.aspectRatio ?? 0.75,
                  startHoldIDs: line.startHoldIDs, finishHoldID: line.finishHoldID)
    }

    static func focusRect(for holds: [Hold]) -> CGRect? {
        SpotlightGeometry.focusRect(for: holds, padding: focusPadding, minSize: focusMinSize, extraBottom: focusExtraBottom)
    }

    /// 取景区域的宽高比（宽/高）；用来决定缩略图的形状。没有取景时就是墙的比例。
    var focusAspect: Double {
        guard let focus, focus.height > 0.001 else { return aspect }
        return focus.width * aspect / focus.height
    }

    /// 给定画布尺寸下的几何。**所有**绘制与命中都必须用它，不要自己 `SpotlightGeometry(...)`。
    func geometry(for size: CGSize) -> SpotlightGeometry {
        SpotlightGeometry(size: size, aspect: aspect, fill: false, focus: focus)
    }

    func pose(state: ContactState, profile: BodyProfile, override: SequencePoseBuilder.Override? = nil) -> StickFigurePose {
        SequencePoseBuilder.pose(state: state, holds: holds, aspect: aspect, profile: profile, override: override)
    }

    var numbers: [UUID: Int] { HoldNumbering.numbers(for: holds) }
}
