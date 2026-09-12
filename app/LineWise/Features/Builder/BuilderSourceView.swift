import PhotosUI
import SwiftUI

/// 建线第一屏：照片从哪来。
struct BuilderSourceView: View {
    var gymName: String
    var walls: [Wall]
    var onCancel: () -> Void
    var onImage: (UIImage) -> Void
    var onExistingWall: (Wall) -> Void
    var onNoPhoto: () -> Void

    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var loadingLibrary = false
    @State private var alert: SourceAlert?

    private enum SourceAlert: Identifiable {
        case cameraDenied, noCamera, libraryFailed
        var id: Int { hashValue }
    }

    private var cameraAvailable: Bool { CameraPicker.isAvailable }

    var body: some View {
        VStack(spacing: 0) {
            BuilderTopBar(step: 0) {
                TopBarButton(title: "取消", action: onCancel)
            } trailing: {
                EmptyView()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("建一条线")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("一张照片就是一面墙。\(gymName)")
                            .font(.subheadline)
                            .foregroundStyle(Color.subtle)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        Button(action: tapCamera) {
                            SourceOptionRow(
                                title: "拍照",
                                detail: cameraAvailable ? "对着墙拍一张，横竖都行" : "模拟器没有相机，请在真机上试",
                                systemImage: "camera.fill",
                                prominent: cameraAvailable,
                                disabled: !cameraAvailable
                            )
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(!cameraAvailable)
                        .accessibilityLabel("拍照")

                        PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .automatic) {
                            SourceOptionRow(
                                title: loadingLibrary ? "正在读取…" : "从相册选",
                                detail: "已经拍过的墙照片",
                                systemImage: "photo.on.rectangle",
                                prominent: !cameraAvailable
                            )
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(loadingLibrary)

                        Button(action: onNoPhoto) {
                            SourceOptionRow(
                                title: "不拍照",
                                detail: "岩馆不让拍、光线太差，先用文字记一条",
                                systemImage: "square.and.pencil"
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }

                    if !walls.isEmpty {
                        existingWalls
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .inkBackground()
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onImage: { image in
                    showCamera = false
                    onImage(image)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            loadLibraryItem(item)
        }
        .alert(item: $alert) { kind in
            switch kind {
            case .cameraDenied:
                Alert(
                    title: Text("相机权限被拒"),
                    message: Text("可以到系统设置里打开相机权限，或者先不拍照建一条。"),
                    primaryButton: .default(Text("去设置")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("不拍照建线")) { onNoPhoto() }
                )
            case .noCamera:
                Alert(title: Text("没有可用的相机"), message: Text("可以从相册选一张，或者不拍照建线。"), dismissButton: .default(Text("好")))
            case .libraryFailed:
                Alert(title: Text("读取照片失败"), message: Text("这张照片没能读出来，换一张试试。"), dismissButton: .default(Text("好")))
            }
        }
    }

    // MARK: 已有的墙

    private var existingWalls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("选已有的墙").font(.headline).foregroundStyle(.white)
                Text("在同一面墙上再建一条").font(.footnote).foregroundStyle(Color.subtle)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(walls) { wall in
                        Button {
                            Haptics.selection()
                            onExistingWall(wall)
                        } label: {
                            WallThumbCard(wall: wall)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
        }
    }

    // MARK: 动作

    private func tapCamera() {
        Haptics.light()
        Task { @MainActor in
            switch await CameraAccess.request() {
            case .granted: showCamera = true
            case .denied: alert = .cameraDenied
            case .unavailable: alert = .noCamera
            }
        }
    }

    private func loadLibraryItem(_ item: PhotosPickerItem) {
        loadingLibrary = true
        Task { @MainActor in
            defer {
                loadingLibrary = false
                photoItem = nil
            }
            do {
                if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    onImage(image)
                } else {
                    alert = .libraryFailed
                }
            } catch {
                alert = .libraryFailed
            }
        }
    }
}

/// 已有墙的缩略卡：原图（不暗化）+ 墙区 + 几条线。
struct WallThumbCard: View {
    let wall: Wall
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.panelElevated)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .frame(width: 132, height: 176)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(wall.displayArea).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                Text(lineCountText).font(.caption).foregroundStyle(Color.subtle)
            }
        }
        .frame(width: 132)
        .task(id: wall.photoFileName) {
            guard let name = wall.photoFileName else { return }
            let loaded = await ImageStore.loadAsync(fileName: name, maxPixel: 600)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) { image = loaded }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wall.displayArea)，\(lineCountText)")
    }

    private var lineCountText: String {
        let n = wall.activeLines.count
        return n == 0 ? "还没有线" : "\(n) 条线 · \(DateText.short(wall.shotAt))"
    }
}
