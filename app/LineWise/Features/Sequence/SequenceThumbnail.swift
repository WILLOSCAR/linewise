import SwiftUI

/// 某一步的小快照：小尺寸聚光灯图 + 该步姿态。列表格、线路页卡片、掉落步选择都用它。
/// `stepIndex`：0 = 起步，N = 第 N 步之后。图片可为 nil（暗底）。
struct SequenceThumbnail: View {
    let line: Line
    let image: UIImage?
    let sequence: ClimbSequence
    let stepIndex: Int
    let size: CGSize
    var profile: BodyProfile = .default
    var cornerRadius: CGFloat = 8

    var body: some View {
        let holds = line.holds
        let aspect = line.wall?.aspectRatio ?? 0.75
        let initial = SequenceReplay.initialState(startHoldIDs: line.startHoldIDs, holds: holds)
        let state = SequenceReplay.state(of: sequence, after: stepIndex, initial: initial)
        let pose = SequencePoseBuilder.pose(state: state, holds: holds, aspect: aspect, profile: profile)
        SpotlightImage(
            image: image,
            aspect: aspect,
            holds: holds,
            startHoldIDs: line.startHoldIDs,
            finishHoldID: line.finishHoldID,
            pose: pose,
            poseIsoAspect: aspect,
            showNumbers: false,
            dim: 0.7,
            ringWidth: 1
        )
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// 按墙的宽高比算出给定高度的缩略图尺寸（宽度夹在合理范围）。
    static func size(height: CGFloat, aspect: Double, maxWidth: CGFloat = .infinity) -> CGSize {
        let w = min(max(height * aspect, height * 0.5), min(height * 1.6, maxWidth))
        return CGSize(width: w, height: height)
    }

    /// 缩略图用的照片长边像素。
    static let imageMaxPixel = 400
}
