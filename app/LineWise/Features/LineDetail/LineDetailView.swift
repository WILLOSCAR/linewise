import SwiftUI

// STUB — 由 LineDetail 负责人替换为完整实现。接口保持不变。
/// 线路页。`onOpenLine` 用于跳到另一条线（合并后、同墙其他线）。
struct LineDetailView: View {
    let line: Line
    var onOpenLine: (Line) -> Void

    var body: some View {
        VStack {
            LineSpotlight(line: line)
            Text(line.name)
        }
        .inkBackground()
    }
}
