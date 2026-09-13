import SwiftUI

/// 某一步的小快照：小尺寸聚光灯图（自动取景到这条线）+ 该步姿态。胶片条、线路页卡片、掉落步选择都用它。
/// `stepIndex`：0 = 起步，N = 第 N 步之后。图片可为 nil（暗底）。
/// `scene` 可以传入缓存好的场景（胶片条几十格时避免每格重新解码点位）；不传就从线上算。
struct SequenceThumbnail: View {
    let line: Line
    let image: UIImage?
    let sequence: ClimbSequence
    let stepIndex: Int
    let size: CGSize
    var profile: BodyProfile = .default
    var cornerRadius: CGFloat = 8
    var scene: SequenceScene? = nil

    var body: some View {
        let scene = scene ?? SequenceScene(line: line)
        let state = SequenceReplay.state(of: sequence, after: stepIndex, initial: scene.initial)
        let pose = scene.pose(state: state, profile: profile)
        SpotlightImage(
            image: image,
            aspect: scene.aspect,
            holds: scene.holds,
            startHoldIDs: scene.startHoldIDs,
            finishHoldID: scene.finishHoldID,
            pose: pose,
            poseIsoAspect: scene.aspect,
            showNumbers: false,
            dim: 0.7,
            ringWidth: 1,
            focus: scene.focus
        )
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// 按（取景后的）宽高比算出给定高度的缩略图尺寸（宽度夹在合理范围）。
    static func size(height: CGFloat, aspect: Double, maxWidth: CGFloat = .infinity) -> CGSize {
        let w = min(max(height * aspect, height * 0.5), min(height * 1.6, maxWidth))
        return CGSize(width: w, height: height)
    }

    /// 缩略图用的照片长边像素（取景会放大局部，所以比整图缩略图给得多一点）。
    static let imageMaxPixel = 640
}
