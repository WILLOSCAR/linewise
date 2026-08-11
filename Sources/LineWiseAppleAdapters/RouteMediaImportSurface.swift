import Foundation
import LineWiseDomain

public enum RouteMediaReadSurfaceRejection: Equatable, Sendable {
  case providerUnavailable
  case consentNotGranted(status: MediaConsentStatus)
  case consentScopeMismatch(actual: MediaConsentScope)
  case cancelled
  case providerFailed(String)
}

public enum RouteMediaReadSurfaceOutcome: Equatable, Sendable {
  case accepted(RouteReadResult)
  case rejected(RouteMediaReadSurfaceRejection)
}

/// Platform-neutral state/controller behind the iPhone route-media action. Recording consent never
/// calls the provider; only `run` crosses the injected provider seam and emits the result callback.
@MainActor
public final class RouteMediaReadSurfaceController {
  public private(set) var lastResult: RouteReadResult?
  public private(set) var errorMessage: String?

  private let provider: (any RouteMediaReadProviding)?
  private let onResult: @MainActor (RouteReadResult) -> Void

  public init(
    provider: (any RouteMediaReadProviding)?,
    onResult: @escaping @MainActor (RouteReadResult) -> Void = { _ in }
  ) {
    self.provider = provider
    self.onResult = onResult
  }

  public func canRun(with asset: RouteMediaAsset?) -> Bool {
    guard let asset, provider != nil else { return false }
    return asset.consent.status == .granted
      && asset.consent.scope == .explicitModelProcessing
  }

  @discardableResult
  public func run(
    asset: RouteMediaAsset,
    routeRead: RouteReadRequest
  ) async -> RouteMediaReadSurfaceOutcome {
    guard let provider else {
      return reject(.providerUnavailable, message: "No route-reading provider is configured.")
    }
    guard asset.consent.status == .granted else {
      return reject(
        .consentNotGranted(status: asset.consent.status),
        message: "This photo is not currently authorized for model processing."
      )
    }
    guard asset.consent.scope == .explicitModelProcessing else {
      return reject(
        .consentScopeMismatch(actual: asset.consent.scope),
        message: "Grant separate AI route-reading permission before running the model."
      )
    }

    do {
      let result = try await provider.read(
        RouteMediaReadRequest(routeRead: routeRead, assets: [asset])
      )
      lastResult = result
      errorMessage = nil
      onResult(result)
      return .accepted(result)
    } catch is CancellationError {
      return reject(.cancelled, message: "Route reading was cancelled.")
    } catch {
      return reject(
        .providerFailed(error.localizedDescription), message: error.localizedDescription)
    }
  }

  private func reject(
    _ rejection: RouteMediaReadSurfaceRejection,
    message: String
  ) -> RouteMediaReadSurfaceOutcome {
    lastResult = nil
    errorMessage = message
    return .rejected(rejection)
  }
}

#if os(iOS) && canImport(PhotosUI) && canImport(SwiftUI) && canImport(UIKit)
  import Foundation
  import LineWiseDomain
  import PhotosUI
  import SwiftUI
  import UniformTypeIdentifiers
  import UIKit

  @MainActor
  public final class RouteMediaImportViewModel: ObservableObject {
    @Published public var localStorageConsentGranted = false
    @Published public private(set) var lastImportedAsset: RouteMediaAsset?
    @Published public private(set) var statusMessage =
      "Choose a route photo only after confirming private local storage."
    @Published public private(set) var lastRouteReadResult: RouteReadResult?
    @Published public var presentsFileImporter = false
    @Published public var presentsPhotoLibrary = false
    @Published public var presentsCamera = false

    public var isCameraAvailable: Bool {
      UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private let library: FoundationRouteMediaLibrary
    private let routeCardID: RouteCardID
    private let routeReadController: RouteMediaReadSurfaceController
    private let configuredRouteReadRequest: RouteReadRequest?

    public init(
      library: FoundationRouteMediaLibrary,
      routeCardID: RouteCardID,
      routeReadProvider: (any RouteMediaReadProviding)? = nil,
      routeReadRequest: RouteReadRequest? = nil,
      onRouteRead: @escaping @MainActor (RouteReadResult) -> Void = { _ in }
    ) {
      self.library = library
      self.routeCardID = routeCardID
      routeReadController = RouteMediaReadSurfaceController(
        provider: routeReadProvider,
        onResult: onRouteRead
      )
      configuredRouteReadRequest = routeReadRequest
    }

    public var canRunRouteRead: Bool {
      routeReadController.canRun(with: lastImportedAsset)
    }

    public func importFile(_ result: Result<URL, Error>) async {
      do {
        let url = try result.get()
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let bytes = try Data(contentsOf: url)
        let type = UTType(filenameExtension: url.pathExtension)
        guard type?.conforms(to: .image) == true else {
          throw RouteMediaLibraryError.invalidMIMEType(
            type?.preferredMIMEType ?? url.lastPathComponent
          )
        }
        try await importBytes(
          bytes,
          mimeType: type?.preferredMIMEType ?? "image/jpeg",
          method: .fileImport
        )
      } catch {
        statusMessage = "File import did not complete: \(error.localizedDescription)"
      }
    }

    public func importPickedMedia(
      data: Data,
      mimeType: String,
      method: MediaCaptureMethod
    ) async {
      do {
        try await importBytes(data, mimeType: mimeType, method: method)
      } catch {
        statusMessage = "Photo import did not complete: \(error.localizedDescription)"
      }
    }

    /// This records explicit permission for a later model action. It does not upload or invoke AI.
    public func grantModelProcessingConsent() async {
      guard let asset = lastImportedAsset else {
        statusMessage = "Import a local route photo before granting model access."
        return
      }
      do {
        lastImportedAsset = try await library.grantModelProcessingConsent(
          for: asset.id,
          at: Self.now()
        )
        statusMessage =
          "AI processing permission recorded. No upload has occurred; route reading is a separate action."
      } catch {
        statusMessage = "AI permission was not recorded: \(error.localizedDescription)"
      }
    }

    /// This is the separate, explicit model action. Consent recording above never calls it.
    public func runRouteRead() async {
      guard let asset = lastImportedAsset else {
        statusMessage = "Import a local route photo before running route reading."
        return
      }
      let routeRead = configuredRouteReadRequest ?? Self.routeReadRequest(for: asset)
      let outcome = await routeReadController.run(asset: asset, routeRead: routeRead)
      switch outcome {
      case .accepted(let result):
        lastRouteReadResult = result
        statusMessage =
          "Suggested route read ready from \(result.provenance.providerIdentifier). Review and edit it before use."
      case .rejected:
        lastRouteReadResult = nil
        statusMessage =
          "Route reading did not complete: \(routeReadController.errorMessage ?? "unknown error")"
      }
    }

    public func deleteLastImportedMedia() async {
      guard let asset = lastImportedAsset else { return }
      do {
        _ = try await library.deleteAsset(asset.id, at: Self.now(), reason: .userRequested)
        lastImportedAsset = nil
        lastRouteReadResult = nil
        statusMessage = "The local media bytes were deleted."
      } catch {
        statusMessage = "Local deletion did not complete: \(error.localizedDescription)"
      }
    }

    private func importBytes(
      _ bytes: Data,
      mimeType: String,
      method: MediaCaptureMethod
    ) async throws {
      guard localStorageConsentGranted else {
        statusMessage = "Confirm private local storage before importing."
        return
      }
      let capturedAt = Self.now()
      lastImportedAsset = try await library.importSource(
        RouteMediaImportRequest(
          assetID: RouteMediaAssetID(UUID().uuidString.lowercased()),
          routeCardID: routeCardID,
          data: bytes,
          kind: .routePhoto,
          mimeType: mimeType,
          purpose: .routeReference,
          consent: MediaConsent(
            status: .granted,
            scope: .storageOnly,
            recordedAt: capturedAt
          ),
          capturedAt: capturedAt,
          captureDeviceClass: .phone,
          captureMethod: method,
          retention: .keepUntilUserDeletes
        )
      )
      lastRouteReadResult = nil
      statusMessage = "Route photo saved privately on this device. It has not been uploaded."
    }

    private static func now() -> Instant {
      Instant(millisecondsSince1970: Int64(Date().timeIntervalSince1970 * 1_000))
    }

    private static func routeReadRequest(for asset: RouteMediaAsset) -> RouteReadRequest {
      RouteReadRequest(
        sceneID: RouteSceneID("route-media/\(asset.id.rawValue)"),
        name: "Suggested route from photo",
        size: SceneSize(
          width: Double(max(asset.dimensions.pixelWidth, 1)),
          height: Double(max(asset.dimensions.pixelHeight, 1))
        ),
        metersPerSceneUnit: nil,
        candidateHolds: []
      )
    }
  }

  @available(iOS 15.0, *)
  public struct RouteMediaImportSurface: View {
    @StateObject private var viewModel: RouteMediaImportViewModel

    public init(
      library: FoundationRouteMediaLibrary,
      routeCardID: RouteCardID,
      routeReadProvider: (any RouteMediaReadProviding)? = nil,
      routeReadRequest: RouteReadRequest? = nil,
      onRouteRead: @escaping @MainActor (RouteReadResult) -> Void = { _ in }
    ) {
      _viewModel = StateObject(
        wrappedValue: RouteMediaImportViewModel(
          library: library,
          routeCardID: routeCardID,
          routeReadProvider: routeReadProvider,
          routeReadRequest: routeReadRequest,
          onRouteRead: onRouteRead
        )
      )
    }

    public var body: some View {
      Form {
        Section("Private route media") {
          Toggle(
            "I consent to storing this selected photo privately on this device",
            isOn: $viewModel.localStorageConsentGranted
          )
          Button("Choose from Photo Library") {
            viewModel.presentsPhotoLibrary = true
          }
          .disabled(!viewModel.localStorageConsentGranted)
          Button("Import a File") {
            viewModel.presentsFileImporter = true
          }
          .disabled(!viewModel.localStorageConsentGranted)
          if viewModel.isCameraAvailable {
            Button("Take a Route Photo") {
              viewModel.presentsCamera = true
            }
            .disabled(!viewModel.localStorageConsentGranted)
          } else {
            Text("Camera capture is unavailable on this device.")
              .foregroundStyle(.secondary)
          }
        }

        if viewModel.lastImportedAsset != nil {
          Section("Separate optional actions") {
            Button("Allow This Photo for AI Route Reading") {
              Task { await viewModel.grantModelProcessingConsent() }
            }
            Text(
              "This records permission only. AI route reading and any upload remain separate actions."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            if viewModel.canRunRouteRead {
              Button("Run route read") {
                Task { await viewModel.runRouteRead() }
              }
              if let result = viewModel.lastRouteReadResult {
                Text(
                  "\(result.provenance.displayLabel) · \(result.provenance.providerIdentifier) v\(result.provenance.version)"
                )
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
              }
            }
            Button("Delete Local Photo", role: .destructive) {
              Task { await viewModel.deleteLastImportedMedia() }
            }
          }
        }

        Section("Status") {
          Text(viewModel.statusMessage)
        }
      }
      .fileImporter(
        isPresented: $viewModel.presentsFileImporter,
        allowedContentTypes: [.image],
        allowsMultipleSelection: false
      ) { result in
        Task {
          switch result {
          case .success(let urls):
            guard let url = urls.first else { return }
            await viewModel.importFile(.success(url))
          case .failure(let error):
            await viewModel.importFile(.failure(error))
          }
        }
      }
      .sheet(isPresented: $viewModel.presentsPhotoLibrary) {
        RoutePhotoLibraryPicker { data, mimeType in
          Task {
            await viewModel.importPickedMedia(
              data: data,
              mimeType: mimeType,
              method: .photoLibraryImport
            )
          }
        }
      }
      .sheet(isPresented: $viewModel.presentsCamera) {
        RouteCameraPicker { data, mimeType in
          Task {
            await viewModel.importPickedMedia(
              data: data,
              mimeType: mimeType,
              method: .cameraCapture
            )
          }
        }
      }
    }
  }

  @available(iOS 15.0, *)
  private struct RoutePhotoLibraryPicker: UIViewControllerRepresentable {
    let onSelection: @MainActor (Data, String) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(onSelection: onSelection)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
      var configuration = PHPickerConfiguration(photoLibrary: .shared())
      configuration.filter = .images
      configuration.selectionLimit = 1
      let picker = PHPickerViewController(configuration: configuration)
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
      let onSelection: @MainActor (Data, String) -> Void

      init(onSelection: @escaping @MainActor (Data, String) -> Void) {
        self.onSelection = onSelection
      }

      func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
          let identifier = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
          })
        else { return }
        provider.loadDataRepresentation(forTypeIdentifier: identifier) { [onSelection] data, _ in
          guard let data else { return }
          let mimeType = UTType(identifier)?.preferredMIMEType ?? "image/jpeg"
          Task { @MainActor in onSelection(data, mimeType) }
        }
      }
    }
  }

  @available(iOS 15.0, *)
  private struct RouteCameraPicker: UIViewControllerRepresentable {
    let onCapture: @MainActor (Data, String) -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(onCapture: onCapture)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.mediaTypes = [UTType.image.identifier]
      picker.delegate = context.coordinator
      return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate,
      UIImagePickerControllerDelegate
    {
      let onCapture: @MainActor (Data, String) -> Void

      init(onCapture: @escaping @MainActor (Data, String) -> Void) {
        self.onCapture = onCapture
      }

      func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
      }

      func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
      ) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
          let data = image.jpegData(compressionQuality: 0.92)
        else { return }
        onCapture(data, "image/jpeg")
      }
    }
  }
#endif
