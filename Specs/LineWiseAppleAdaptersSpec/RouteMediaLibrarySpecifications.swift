import Foundation
import LineWiseAppleAdapters
import LineWiseDomain

private let onePixelPNG = Data(
  base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)!

private func withTemporaryMediaLibrary<T>(
  _ operation: (URL) async throws -> T
) async throws -> T {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("linewise-media-spec-\(UUID().uuidString)", isDirectory: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  return try await operation(directory)
}

private func importedMediaReopensAndLoadsOnlyRegisteredBytes() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let imported = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-source-1"),
        routeCardID: RouteCardID("route-1"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 100)
        ),
        capturedAt: Instant(millisecondsSince1970: 90),
        captureDeviceClass: .phone,
        captureMethod: .fileImport,
        retention: .keepUntilUserDeletes
      )
    )

    try expect(imported.byteCount == 68, "expected the persisted byte count")
    try expect(
      imported.contentDigest.hexValue
        == "431ced6916a2a21a156e38701afe55bbd7f88969fbbfc56d7fe099d47f265460",
      "expected the independently verified SHA-256 digest"
    )
    try expect(
      imported.dimensions == MediaDimensions(pixelWidth: 1, pixelHeight: 1),
      "expected image dimensions to be inspected from the imported bytes"
    )
    try expect(
      !imported.localReference.sandboxRelativePath.hasPrefix("/"),
      "expected an app-relative media reference"
    )

    let reopened = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let reopenedAsset = await reopened.asset(id: imported.id)
    let loaded = try await reopened.loadData(for: imported.localReference)
    try expect(reopenedAsset == imported, "expected the PersonalDataset manifest to reopen")
    try expect(loaded == onePixelPNG, "expected the registered reference to load exact bytes")
  }
}

private func sourceAndDerivedMediaRemainSeparateWithLineage() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let source = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-source-lineage"),
        routeCardID: RouteCardID("route-lineage"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 100)
        ),
        capturedAt: Instant(millisecondsSince1970: 90),
        captureDeviceClass: .phone,
        captureMethod: .photoLibraryImport,
        retention: .keepUntilUserDeletes
      )
    )
    let derivedBytes = Data("local pose overlay".utf8)
    let derived = try await library.importDerived(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-derived-lineage"),
        routeCardID: RouteCardID("route-lineage"),
        data: derivedBytes,
        kind: .poseOverlay,
        mimeType: "application/octet-stream",
        purpose: .stickFigureCue,
        consent: MediaConsent(
          status: .granted,
          scope: .onDevicePersonalAnalysis,
          recordedAt: Instant(millisecondsSince1970: 200)
        ),
        capturedAt: Instant(millisecondsSince1970: 200),
        captureDeviceClass: .phone,
        captureMethod: .derivedLocally,
        retention: .deleteAfterDerivedAssetsRemoved
      ),
      sourceAssetIDs: [source.id],
      transform: MediaDerivation(
        kind: .poseOverlay,
        implementationIdentifier: "linewise-local-overlay",
        version: "1"
      )
    )

    try expect(source.isSource, "expected the imported route photo to remain a source")
    try expect(!derived.isSource, "expected an overlay to remain derived")
    try expect(derived.sourceAssetIDs == [source.id], "expected durable source lineage")
    try expect(
      source.localReference.sandboxRelativePath.contains("media/source/"),
      "expected source bytes in the source namespace"
    )
    try expect(
      derived.localReference.sandboxRelativePath.contains("media/derived/"),
      "expected derived bytes in the derived namespace"
    )
    let loadedDerivedBytes = try await library.loadData(for: derived.localReference)
    try expect(
      loadedDerivedBytes == derivedBytes,
      "expected the independently registered derived bytes"
    )
  }
}

private func deletionRemovesBytesAndPersistsATombstone() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let imported = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-delete"),
        routeCardID: RouteCardID("route-delete"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 100)
        ),
        capturedAt: Instant(millisecondsSince1970: 90),
        captureDeviceClass: .phone,
        captureMethod: .cameraCapture,
        retention: .keepUntilUserDeletes
      )
    )
    let storedFile = rootDirectory.appendingPathComponent(
      imported.localReference.sandboxRelativePath
    )
    try expect(
      FileManager.default.fileExists(atPath: storedFile.path),
      "expected bytes to exist before deletion"
    )

    let tombstone = try await library.deleteAsset(
      imported.id,
      at: Instant(millisecondsSince1970: 300),
      reason: .userRequested
    )
    try expect(tombstone.assetID == imported.id, "expected an exact deletion tombstone")
    try expect(
      !FileManager.default.fileExists(atPath: storedFile.path),
      "expected the registered bytes to be physically removed"
    )

    let reopened = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let reopenedAsset = await reopened.asset(id: imported.id)
    let exported = await reopened.exportManifest(
      createdAt: Instant(millisecondsSince1970: 400)
    )
    try expect(reopenedAsset == nil, "expected deletion to survive reopen")
    try expect(
      exported.deletionTombstones == [tombstone],
      "expected the tombstone to survive reopen"
    )
  }
}

private func modelConsentIsSeparateAndRevocationDeletesLocalBytes() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let imported = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-consent"),
        routeCardID: RouteCardID("route-consent"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 100)
        ),
        capturedAt: Instant(millisecondsSince1970: 90),
        captureDeviceClass: .phone,
        captureMethod: .photoLibraryImport,
        retention: .keepUntilUserDeletes
      )
    )
    try expect(
      imported.consent.scope == .storageOnly,
      "expected import to authorize local storage only"
    )

    let authorized = try await library.grantModelProcessingConsent(
      for: imported.id,
      at: Instant(millisecondsSince1970: 200)
    )
    try expect(
      authorized.consent.scope == .explicitModelProcessing,
      "expected model processing to require its own explicit action"
    )
    let reopened = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let reopenedAsset = await reopened.asset(id: imported.id)
    try expect(
      reopenedAsset?.consent == authorized.consent,
      "expected model consent to survive reopen without changing the bytes"
    )

    let fileURL = rootDirectory.appendingPathComponent(
      imported.localReference.sandboxRelativePath
    )
    let tombstone = try await reopened.revokeConsentAndDelete(
      for: imported.id,
      at: Instant(millisecondsSince1970: 300)
    )
    try expect(
      tombstone.reason == .consentRevoked,
      "expected consent revocation provenance"
    )
    try expect(
      !FileManager.default.fileExists(atPath: fileURL.path),
      "expected consent revocation to delete the protected bytes"
    )
  }
}

private func expiredRetentionDeletesBytesAndRecordsWhy() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let imported = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-expiring"),
        routeCardID: RouteCardID("route-expiring"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 10)
        ),
        capturedAt: Instant(millisecondsSince1970: 5),
        captureDeviceClass: .phone,
        captureMethod: .cameraCapture,
        retention: .expiresAt(Instant(millisecondsSince1970: 100))
      )
    )
    let retained = try await library.enforceRetention(
      at: Instant(millisecondsSince1970: 99)
    )
    try expect(retained.isEmpty, "expected bytes to remain before expiration")

    let expired = try await library.enforceRetention(
      at: Instant(millisecondsSince1970: 100)
    )
    try expect(expired.count == 1, "expected one expired asset deletion")
    try expect(expired.first?.assetID == imported.id, "expected exact retention target")
    try expect(
      expired.first?.reason == .retentionExpired,
      "expected retention deletion provenance"
    )
    let fileURL = rootDirectory.appendingPathComponent(
      imported.localReference.sandboxRelativePath
    )
    try expect(
      !FileManager.default.fileExists(atPath: fileURL.path),
      "expected expired bytes to be physically removed"
    )
  }
}

private func exportedManifestContainsMetadataWithoutRawBytesOrAbsolutePaths() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let imported = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-export"),
        routeCardID: RouteCardID("route-export"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 10)
        ),
        capturedAt: Instant(millisecondsSince1970: 5),
        captureDeviceClass: .phone,
        captureMethod: .fileImport,
        retention: .keepUntilUserDeletes
      )
    )
    let exportedData = try await library.exportManifestData(
      createdAt: Instant(millisecondsSince1970: 50)
    )
    let exportedText = String(decoding: exportedData, as: UTF8.self)
    try expect(
      !exportedText.contains(onePixelPNG.base64EncodedString()),
      "expected no raw media bytes in a metadata export"
    )
    try expect(
      !exportedText.contains(rootDirectory.path),
      "expected no absolute sandbox path in a metadata export"
    )
    let decoded = try JSONDecoder().decode(DatasetExportManifest.self, from: exportedData)
    try expect(decoded.activeAssets == [imported], "expected registered metadata in the export")
  }
}

private func corruptAndFutureManifestsFailExplicitly() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let corruptRoot = rootDirectory.appendingPathComponent("corrupt", isDirectory: true)
    try FileManager.default.createDirectory(at: corruptRoot, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(
      to: corruptRoot.appendingPathComponent(FoundationRouteMediaLibrary.manifestFileName)
    )
    do {
      _ = try FoundationRouteMediaLibrary(rootDirectory: corruptRoot)
      throw AppleAdapterSpecFailure.expected("expected corrupt media manifest rejection")
    } catch let error as RouteMediaLibraryError {
      guard case .corruptManifest = error else {
        throw AppleAdapterSpecFailure.expected("expected an explicit corrupt-manifest error")
      }
    }

    let futureRoot = rootDirectory.appendingPathComponent("future", isDirectory: true)
    try FileManager.default.createDirectory(at: futureRoot, withIntermediateDirectories: true)
    try Data("{\"schemaVersion\":999}".utf8).write(
      to: futureRoot.appendingPathComponent(FoundationRouteMediaLibrary.manifestFileName)
    )
    do {
      _ = try FoundationRouteMediaLibrary(rootDirectory: futureRoot)
      throw AppleAdapterSpecFailure.expected("expected future media manifest rejection")
    } catch let error as RouteMediaLibraryError {
      try expect(
        error == .unsupportedSchemaVersion(999),
        "expected the future schema version to remain visible"
      )
    }
  }
}

private func loaderRejectsTraversalAndSymlinkEscapes() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    do {
      _ = try await library.loadData(
        for: LocalMediaReference(
          fileIdentifier: "outside",
          sandboxRelativePath: "../outside"
        )
      )
      throw AppleAdapterSpecFailure.expected("expected an unregistered traversal rejection")
    } catch let error as RouteMediaLibraryError {
      try expect(
        error == .unregisteredReference,
        "expected the loader to require exact manifest registration first"
      )
    }

    let imported = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-symlink"),
        routeCardID: RouteCardID("route-symlink"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 10)
        ),
        capturedAt: Instant(millisecondsSince1970: 5),
        captureDeviceClass: .phone,
        captureMethod: .fileImport,
        retention: .keepUntilUserDeletes
      )
    )
    let registeredURL = rootDirectory.appendingPathComponent(
      imported.localReference.sandboxRelativePath
    )
    let outsideURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "linewise-outside-\(UUID().uuidString)"
    )
    defer { try? FileManager.default.removeItem(at: outsideURL) }
    try Data("outside secret".utf8).write(to: outsideURL)
    try FileManager.default.removeItem(at: registeredURL)
    try FileManager.default.createSymbolicLink(at: registeredURL, withDestinationURL: outsideURL)

    do {
      _ = try await library.loadData(for: imported.localReference)
      throw AppleAdapterSpecFailure.expected("expected a registered symlink escape rejection")
    } catch let error as RouteMediaLibraryError {
      try expect(
        error == .unsafeLocalReference,
        "expected canonical path enforcement for a registered reference"
      )
    }
  }
}

private func failedManifestWriteLeavesNoRegisteredAssetOrStagedBytes() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let manifestURL = rootDirectory.appendingPathComponent(
      FoundationRouteMediaLibrary.manifestFileName,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: true)

    do {
      _ = try await library.importSource(
        RouteMediaImportRequest(
          assetID: RouteMediaAssetID("asset-write-failure"),
          routeCardID: RouteCardID("route-write-failure"),
          data: onePixelPNG,
          kind: .routePhoto,
          mimeType: "image/png",
          purpose: .routeReference,
          consent: MediaConsent(
            status: .granted,
            scope: .storageOnly,
            recordedAt: Instant(millisecondsSince1970: 10)
          ),
          capturedAt: Instant(millisecondsSince1970: 5),
          captureDeviceClass: .phone,
          captureMethod: .fileImport,
          retention: .keepUntilUserDeletes
        )
      )
      throw AppleAdapterSpecFailure.expected("expected manifest persistence failure")
    } catch let error as RouteMediaLibraryError {
      guard case .ioFailure = error else {
        throw AppleAdapterSpecFailure.expected("expected an explicit atomic write failure")
      }
    }

    let activeAssets = await library.assets()
    try expect(activeAssets.isEmpty, "expected no in-memory half-registration")
    let mediaFiles = try FileManager.default.subpathsOfDirectory(
      atPath: rootDirectory.appendingPathComponent("media").path
    )
    try expect(
      mediaFiles.allSatisfy { $0 == "source" || $0 == "derived" },
      "expected failed import bytes to be cleaned from source and derived storage"
    )
    let stagingFiles = try FileManager.default.contentsOfDirectory(
      atPath: rootDirectory.appendingPathComponent("staging").path
    )
    try expect(stagingFiles.isEmpty, "expected failed import staging to be cleaned")

    try FileManager.default.removeItem(at: manifestURL)
    let reopened = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let reopenedAssets = await reopened.assets()
    try expect(reopenedAssets.isEmpty, "expected no durable half-registration")
  }
}

private func importCannotBundleModelConsentOrUseRevokedStorageConsent() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let baseRequest: (RouteMediaAssetID, MediaConsent) -> RouteMediaImportRequest = {
      assetID,
      consent in
      RouteMediaImportRequest(
        assetID: assetID,
        routeCardID: RouteCardID("route-invalid-consent"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: consent,
        capturedAt: Instant(millisecondsSince1970: 5),
        captureDeviceClass: .phone,
        captureMethod: .fileImport,
        retention: .keepUntilUserDeletes
      )
    }

    do {
      _ = try await library.importSource(
        baseRequest(
          RouteMediaAssetID("asset-bundled-model-consent"),
          MediaConsent(
            status: .granted,
            scope: .explicitModelProcessing,
            recordedAt: Instant(millisecondsSince1970: 10)
          )
        )
      )
      throw AppleAdapterSpecFailure.expected("expected bundled model consent rejection")
    } catch let error as RouteMediaLibraryError {
      try expect(
        error == .modelProcessingConsentRequiresSeparateAction,
        "expected model permission to remain a separate action"
      )
    }

    do {
      _ = try await library.importSource(
        baseRequest(
          RouteMediaAssetID("asset-revoked-storage-consent"),
          MediaConsent(
            status: .revoked,
            scope: .storageOnly,
            recordedAt: Instant(millisecondsSince1970: 20)
          )
        )
      )
      throw AppleAdapterSpecFailure.expected("expected revoked storage consent rejection")
    } catch let error as RouteMediaLibraryError {
      try expect(
        error == .storageConsentRequired,
        "expected current explicit storage consent"
      )
    }
    let assets = await library.assets()
    try expect(assets.isEmpty, "expected invalid consent to persist no media")
  }
}

func runRouteMediaLibrarySpecifications() async throws -> Int {
  try await importedMediaReopensAndLoadsOnlyRegisteredBytes()
  try await sourceAndDerivedMediaRemainSeparateWithLineage()
  try await deletionRemovesBytesAndPersistsATombstone()
  try await modelConsentIsSeparateAndRevocationDeletesLocalBytes()
  try await expiredRetentionDeletesBytesAndRecordsWhy()
  try await exportedManifestContainsMetadataWithoutRawBytesOrAbsolutePaths()
  try await corruptAndFutureManifestsFailExplicitly()
  try await loaderRejectsTraversalAndSymlinkEscapes()
  try await failedManifestWriteLeavesNoRegisteredAssetOrStagedBytes()
  try await importCannotBundleModelConsentOrUseRevokedStorageConsent()
  return 10
}
