import Foundation
import SwiftUI

/// 5 秒撤销条。同一时间只有一条；新的到来时旧的视为已确认。
@Observable
final class UndoCenter {
    struct Offer: Identifiable {
        let id = UUID()
        let title: String
        let undo: () -> Void
    }

    private(set) var current: Offer?
    private var dismissTask: Task<Void, Never>?

    func offer(_ title: String, seconds: Double = 5, undo: @escaping () -> Void) {
        dismissTask?.cancel()
        let offer = Offer(title: title, undo: undo)
        withAnimation(.snappy) { current = offer }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            guard let self, self.current?.id == offer.id else { return }
            withAnimation(.snappy) { self.current = nil }
        }
    }

    func performUndo() {
        guard let offer = current else { return }
        dismissTask?.cancel()
        withAnimation(.snappy) { current = nil }
        offer.undo()
        Haptics.light()
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.snappy) { current = nil }
    }
}

/// 撤销条视图，挂在根视图底部。
struct UndoToast: View {
    @Environment(UndoCenter.self) private var undoCenter

    var body: some View {
        if let offer = undoCenter.current {
            HStack(spacing: 12) {
                Text(offer.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("撤销") { undoCenter.performUndo() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(offer.id)
        }
    }
}
