import SwiftUI

/// 历史列表里的一行：`日期 · N 次 · 掉在 ⑤ · 原因`，下面一句话；右侧上了 / 验证徽标。
struct SessionRow: View {
    let line: Line
    let session: Session

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(headline)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                if let note = displayNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Color.subtle)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                if let check = session.check {
                    Text(check.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(check == .worked ? Color.ink : .white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(check == .worked ? Color.accent : Color.white.opacity(0.12), in: Capsule())
                        .accessibilityLabel("对上次提醒的回答：\(check.title)")
                }
                if session.sent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.accent)
                        .accessibilityLabel("上了")
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    var headline: String {
        var parts = [DateText.short(session.date)]
        parts.append(session.attemptCount == 1 ? "1 次" : "\(session.attemptCount) 次")
        if let label = line.label(for: session.fallHoldID) {
            parts.append("掉在 \(label)")
        } else if !session.reviewText.fall.isEmpty {
            parts.append("掉在 \(session.reviewText.fall)")
        } else if session.sent, session.fallHoldID == nil {
            parts.append("没掉")
        }
        if let reason = session.reason { parts.append(reason.title) }
        return parts.joined(separator: " · ")
    }

    private var displayNote: String? {
        let note = session.reviewText.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return nil }
        return note
    }
}

/// 在 ScrollView 里模拟“左滑删除”：向左拖出一个珊瑚红按钮；长按仍走 contextMenu。
struct SwipeToDelete<Content: View>: View {
    var onDelete: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var revealed = false
    @State private var horizontal: Bool?

    private let actionWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                close()
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.coral, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除这条记录")
            .opacity(offset < -4 ? 1 : 0)

            content
                .background(Color.panel)
                .overlay {
                    if revealed {
                        // 展开删除键时，点行只是收回，不进编辑。
                        Color.clear.contentShape(Rectangle()).onTapGesture { close() }
                    }
                }
                .offset(x: offset)
                .gesture(drag)
        }
        .clipped()
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                if horizontal == nil {
                    horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                }
                guard horizontal == true else { return }
                let base: CGFloat = revealed ? -actionWidth : 0
                offset = min(0, max(-actionWidth * 1.25, base + value.translation.width))
            }
            .onEnded { value in
                defer { horizontal = nil }
                guard horizontal == true else { return }
                let open = offset < -actionWidth / 2 || value.predictedEndTranslation.width < -actionWidth
                withAnimation(.snappy(duration: 0.25)) {
                    revealed = open
                    offset = open ? -actionWidth : 0
                }
            }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.25)) {
            revealed = false
            offset = 0
        }
    }
}
