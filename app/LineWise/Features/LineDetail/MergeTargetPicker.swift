import SwiftUI

/// “合并到另一条…”：列出同岩馆其他可见的线，选一条作为目标。
struct MergeTargetPicker: View {
    let line: Line
    var onPick: (Line) -> Void

    @Environment(\.dismiss) private var dismiss

    private var candidates: [Line] {
        let walls = line.wall?.gym?.walls ?? (line.wall.map { [$0] } ?? [])
        return walls
            .flatMap(\.activeLines)
            .filter { $0.id != line.id }
            .sorted { a, b in
                // 同一面墙的排前面，然后按最近更新
                let sameA = a.wall?.id == line.wall?.id
                let sameB = b.wall?.id == line.wall?.id
                if sameA != sameB { return sameA }
                return a.updatedAt > b.updatedAt
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.accent)
                        Text("这个岩馆没有别的线可以并进去")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("合并是把这条线的记录挪到另一条同样的线上。")
                            .font(.footnote)
                            .foregroundStyle(Color.subtle)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            Text("「\(line.name)」的 \(line.visitCount) 条记录会挪到你选的那条线上，本条不再显示。5 秒内可以撤销。")
                                .font(.footnote)
                                .foregroundStyle(Color.subtle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 4)
                            // 选中即合并：这一步可撤销，不再弹确认框。
                            ForEach(candidates) { candidate in
                                Button {
                                    Haptics.selection()
                                    onPick(candidate)
                                } label: { row(candidate) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .inkBackground()
            .navigationTitle("合并到另一条")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ candidate: Line) -> some View {
        HStack(spacing: 14) {
            LineSpotlight(line: candidate, fill: true, maxPixel: 400, showNumbers: false)
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !candidate.subtitle.isEmpty { Text(candidate.subtitle) }
                    Text(candidate.visitCount == 0 ? "还没记录" : "来了 \(candidate.visitCount) 次")
                    if candidate.wall?.id == line.wall?.id {
                        Text("同一面墙").foregroundStyle(Color.accent)
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.subtle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}
