import SwiftUI

/// 认旧线：进入已有墙时先列出这面墙上已经建过的线。
struct RecognizeLinesView: View {
    let wall: Wall
    var backTitle: String = "返回"
    var onPick: (Line) -> Void
    var onNew: () -> Void
    var onBack: () -> Void

    private var lines: [Line] {
        wall.activeLines.sorted { $0.updatedAt > $1.updatedAt }
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            BuilderTopBar(step: 0) {
                TopBarButton(title: backTitle, systemImage: "chevron.left", action: onBack)
            } trailing: {
                EmptyView()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("是这几条里的一条吗？")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(wall.displayArea) · 已有 \(lines.count) 条线。点一下直接打开，不重复建卡。")
                            .font(.subheadline)
                            .foregroundStyle(Color.subtle)
                    }
                    .padding(.top, 8)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(lines) { line in
                            Button {
                                Haptics.selection()
                                onPick(line)
                            } label: {
                                LineThumbCard(line: line, aspect: wall.aspectRatio)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .inkBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    Haptics.light()
                    onNew()
                } label: {
                    Label("都不是，新建一条", systemImage: "plus")
                }
                .buttonStyle(BigButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(
                LinearGradient(colors: [Color.ink.opacity(0), Color.ink], startPoint: .top, endPoint: .bottom)
                    .frame(height: 96)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            )
        }
    }
}

/// 一条线的聚光灯缩略卡。
struct LineThumbCard: View {
    let line: Line
    var aspect: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LineSpotlight(line: line, fill: true, maxPixel: 600, showNumbers: false)
                .aspectRatio(max(aspect, 0.5), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(line.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 6) {
                    Text(line.gradeDisplay).font(.caption.weight(.semibold)).foregroundStyle(Color.accent)
                    HStack(spacing: 3) {
                        Image(systemName: line.status.symbol).font(.system(size: 9, weight: .semibold))
                        Text(line.status.title)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.subtle)
                    Text("\(line.holds.count) 个点").font(.caption).foregroundStyle(Color.subtle)
                }
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.name)，\(line.gradeDisplay)，\(line.status.title)")
    }
}
