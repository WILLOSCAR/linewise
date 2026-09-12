import SwiftUI

// STUB — 由 Builder 负责人替换为完整实现。接口保持不变。
/// 建线流程（全屏）。`presetWall` 非空时表示“这面墙上再建一条”，跳过拍照直接点亮。
struct LineBuilderFlow: View {
    var presetWall: Wall? = nil
    var onFinish: (Line?) -> Void

    var body: some View {
        VStack {
            Text("建线流程（待实现）")
            Button("关闭") { onFinish(nil) }
        }
        .inkBackground()
    }
}
