import SwiftUI

// STUB — 由 Share/Settings 负责人替换为完整实现。接口保持不变。
/// 分享按钮：生成分享图并弹出系统分享面板。
struct ShareLineButton: View {
    let line: Line
    var label: String = "分享"

    var body: some View {
        Button {
            // 待实现
        } label: {
            Label(label, systemImage: "square.and.arrow.up")
        }
    }
}
