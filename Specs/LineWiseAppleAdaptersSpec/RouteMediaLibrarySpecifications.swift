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

private func missingBytesStillCompleteDeletionAndConsentRevocation() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let imported = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-byteless-revoke"),
        routeCardID: RouteCardID("route-byteless"),
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
    let authorized = try await library.grantModelProcessingConsent(
      for: imported.id,
      at: Instant(millisecondsSince1970: 200)
    )
    try expect(
      authorized.consent.scope == .explicitModelProcessing,
      "expected the separate model-processing grant to be recorded"
    )

    // The bytes disappear underneath the manifest: an interrupted earlier
    // delete, a purged non-backed-up file, or external tampering.
    try FileManager.default.removeItem(
      at: rootDirectory.appendingPathComponent(imported.localReference.sandboxRelativePath)
    )

    let tombstone = try await library.revokeConsentAndDelete(
      for: imported.id,
      at: Instant(millisecondsSince1970: 300)
    )
    try expect(
      tombstone.reason == .consentRevoked,
      "revoking consent for absent bytes must still record why the asset went away"
    )
    let activeAfterRevoke = await library.assets()
    try expect(
      activeAfterRevoke.isEmpty,
      "a revoked asset must not stay active just because its bytes were already gone"
    )

    let reopened = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let reopenedAsset = await reopened.asset(id: imported.id)
    let exported = await reopened.exportManifest(createdAt: Instant(millisecondsSince1970: 400))
    try expect(reopenedAsset == nil, "expected the revocation to survive reopen")
    try expect(
      exported.activeAssets.isEmpty && exported.deletionTombstones == [tombstone],
      "an exported manifest must not keep advertising a withdrawn model-processing grant"
    )

    let userRequested = try await reopened.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-byteless-delete"),
        routeCardID: RouteCardID("route-byteless"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 500)
        ),
        capturedAt: Instant(millisecondsSince1970: 490),
        captureDeviceClass: .phone,
        captureMethod: .cameraCapture,
        retention: .keepUntilUserDeletes
      )
    )
    try FileManager.default.removeItem(
      at: rootDirectory.appendingPathComponent(userRequested.localReference.sandboxRelativePath)
    )
    let userTombstone = try await reopened.deleteAsset(
      userRequested.id,
      at: Instant(millisecondsSince1970: 600),
      reason: .userRequested
    )
    try expect(
      userTombstone.assetID == userRequested.id,
      "an explicit delete must succeed when the bytes are already absent"
    )
    let stillActive = await reopened.assets()
    try expect(stillActive.isEmpty, "expected no undeletable byte-less asset to remain")
  }
}

private func retentionSweepContinuesPastOneUnreadableAsset() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let expiringRequest: (String) -> RouteMediaImportRequest = { identifier in
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID(identifier),
        routeCardID: RouteCardID("route-sweep"),
        data: onePixelPNG,
        kind: .routePhoto,
        mimeType: "image/png",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 1)
        ),
        capturedAt: Instant(millisecondsSince1970: 1),
        captureDeviceClass: .phone,
        captureMethod: .fileImport,
        retention: .expiresAt(Instant(millisecondsSince1970: 10))
      )
    }
    let byteless = try await library.importSource(expiringRequest("asset-sweep-a-byteless"))
    let tampered = try await library.importSource(expiringRequest("asset-sweep-b-tampered"))
    let intact = try await library.importSource(expiringRequest("asset-sweep-c-intact"))

    // Three ways one entry can be unusable while its expired siblings are fine.
    try FileManager.default.removeItem(
      at: rootDirectory.appendingPathComponent(byteless.localReference.sandboxRelativePath)
    )
    let tamperedURL = rootDirectory.appendingPathComponent(
      tampered.localReference.sandboxRelativePath
    )
    let outsideURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "linewise-sweep-outside-\(UUID().uuidString)"
    )
    defer { try? FileManager.default.removeItem(at: outsideURL) }
    try onePixelPNG.write(to: outsideURL)
    try FileManager.default.removeItem(at: tamperedURL)
    try FileManager.default.createSymbolicLink(at: tamperedURL, withDestinationURL: outsideURL)

    var sweepError: RouteMediaLibraryError?
    do {
      _ = try await library.enforceRetention(at: Instant(millisecondsSince1970: 20))
    } catch let error as RouteMediaLibraryError {
      sweepError = error
    }
    try expect(
      sweepError == .unsafeLocalReference,
      "a tampered reference must remain a visible retention failure"
    )

    let remaining = await library.assets()
    try expect(
      remaining.map(\.id) == [tampered.id],
      "every other expired asset must still be swept past one unusable entry"
    )
    let intactFile = rootDirectory.appendingPathComponent(
      intact.localReference.sandboxRelativePath
    )
    try expect(
      !FileManager.default.fileExists(atPath: intactFile.path),
      "expected the expired bytes of the intact asset to be physically removed"
    )
    let exported = await library.exportManifest(createdAt: Instant(millisecondsSince1970: 30))
    try expect(
      Set(exported.deletionTombstones.map(\.assetID)) == [byteless.id, intact.id],
      "the sweep must record why each asset it could remove went away"
    )
    try expect(
      exported.deletionTombstones.allSatisfy { $0.reason == .retentionExpired },
      "expected retention provenance on every swept asset"
    )
    try expect(
      FileManager.default.fileExists(atPath: outsideURL.path),
      "a retention sweep must never follow a tampered reference outside the library"
    )
  }
}

private func sourceAwaitingItsFirstDerivedAssetSurvivesRetention() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let source = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-pending-derivation"),
        routeCardID: RouteCardID("route-pending-derivation"),
        data: onePixelPNG,
        kind: .actualVideo,
        mimeType: "video/quicktime",
        purpose: .routeReference,
        consent: MediaConsent(
          status: .granted,
          scope: .storageOnly,
          recordedAt: Instant(millisecondsSince1970: 10)
        ),
        capturedAt: Instant(millisecondsSince1970: 5),
        captureDeviceClass: .phone,
        captureMethod: .cameraCapture,
        retention: .deleteAfterDerivedAssetsRemoved
      )
    )

    // The intended flow is import source -> extract frames -> importDerived. A
    // retention sweep in that window must not destroy the user's only copy.
    let beforeDerivation = try await library.enforceRetention(
      at: Instant(millisecondsSince1970: 20)
    )
    try expect(
      beforeDerivation.isEmpty,
      "a source whose derived assets were never created must not be swept"
    )
    let stillActive = await library.assets()
    try expect(
      stillActive.map(\.id) == [source.id],
      "the pending source must remain available for its derivation step"
    )

    let derived = try await library.importDerived(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-pending-derived"),
        routeCardID: RouteCardID("route-pending-derivation"),
        data: Data("extracted frame".utf8),
        kind: .poseOverlay,
        mimeType: "application/octet-stream",
        purpose: .stickFigureCue,
        consent: MediaConsent(
          status: .granted,
          scope: .onDevicePersonalAnalysis,
          recordedAt: Instant(millisecondsSince1970: 30)
        ),
        capturedAt: Instant(millisecondsSince1970: 30),
        captureDeviceClass: .phone,
        captureMethod: .derivedLocally,
        retention: .keepUntilUserDeletes
      ),
      sourceAssetIDs: [source.id],
      transform: MediaDerivation(
        kind: .poseOverlay,
        implementationIdentifier: "linewise-frame-extract",
        version: "1"
      )
    )
    let whileDerivedExists = try await library.enforceRetention(
      at: Instant(millisecondsSince1970: 40)
    )
    try expect(
      whileDerivedExists.isEmpty,
      "a source still used by a derived asset must not be swept"
    )

    _ = try await library.deleteAsset(
      derived.id,
      at: Instant(millisecondsSince1970: 50),
      reason: .userRequested
    )
    let afterDerivedRemoval = try await library.enforceRetention(
      at: Instant(millisecondsSince1970: 60)
    )
    try expect(
      afterDerivedRemoval.map(\.assetID) == [source.id],
      "once its derived assets are gone the source must be swept as its policy asks"
    )
  }
}

private func reopeningReclaimsMediaBytesOrphanedByAnInterruptedCommit() async throws {
  try await withTemporaryMediaLibrary { rootDirectory in
    let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    _ = try await library.importSource(
      RouteMediaImportRequest(
        assetID: RouteMediaAssetID("asset-staging-survivor"),
        routeCardID: RouteCardID("route-staging"),
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
        retention: .keepUntilUserDeletes
      )
    )

    // Simulate the two ways a process death strands full-resolution media in
    // staging: an import killed between write and move, and a delete killed
    // between staging the bytes and persisting the manifest.
    let stagingDirectory = rootDirectory.appendingPathComponent("staging", isDirectory: true)
    let strandedImport = stagingDirectory.appendingPathComponent(
      "\(UUID().uuidString).stage",
      isDirectory: false
    )
    let strandedDelete = stagingDirectory.appendingPathComponent(
      "delete-\(UUID().uuidString).stage",
      isDirectory: false
    )
    try onePixelPNG.write(to: strandedImport)
    try onePixelPNG.write(to: strandedDelete)

    let reopened = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
    let survivingAssets = await reopened.assets()
    try expect(
      survivingAssets.map(\.id) == [RouteMediaAssetID("asset-staging-survivor")],
      "reopening must not disturb registered media while reclaiming orphans"
    )
    let stagedAfterReopen = try FileManager.default.contentsOfDirectory(
      atPath: stagingDirectory.path
    )
    try expect(
      stagedAfterReopen.isEmpty,
      "media bytes stranded outside the manifest must not survive a relaunch unreachable"
    )
    try expect(
      !FileManager.default.fileExists(atPath: strandedImport.path)
        && !FileManager.default.fileExists(atPath: strandedDelete.path),
      "expected both interrupted-commit orphans to be physically reclaimed"
    )
    let registeredFile = rootDirectory.appendingPathComponent(
      survivingAssets[0].localReference.sandboxRelativePath
    )
    try expect(
      FileManager.default.fileExists(atPath: registeredFile.path),
      "the staging sweep must never touch bytes the manifest still references"
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

@MainActor
private func routeReadActionRequiresConsentThenDeliversSuggestedCallback() async throws {
  let rootDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("linewise-media-surface-\(UUID().uuidString)", isDirectory: true)
  defer { try? FileManager.default.removeItem(at: rootDirectory) }
  let library = try FoundationRouteMediaLibrary(rootDirectory: rootDirectory)
  let stored = try await library.importSource(
    RouteMediaImportRequest(
      assetID: RouteMediaAssetID("surface-route-read"),
      routeCardID: RouteCardID("surface-route"),
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
  let suggested = routeMediaSurfaceResult()
  let provider = LoadingRouteMediaProvider(loader: library, result: suggested)
  var callbackResult: RouteReadResult?
  let controller = RouteMediaReadSurfaceController(provider: provider) { result in
    callbackResult = result
  }
  let routeRead = routeMediaSurfaceRequest()

  try expect(!controller.canRun(with: stored), "storage consent must not expose Run route read")
  let gated = await controller.run(asset: stored, routeRead: routeRead)
  try expect(
    gated == .rejected(.consentScopeMismatch(actual: .storageOnly)),
    "storage consent should remain separate from model processing"
  )
  let gatedCallCount = await provider.callCount
  try expect(gatedCallCount == 0, "consent gating must happen before provider or bytes")

  let authorized = try await library.grantModelProcessingConsent(
    for: stored.id,
    at: Instant(millisecondsSince1970: 200)
  )
  try expect(controller.canRun(with: authorized), "separate model consent should unlock Run")
  let consentOnlyCallCount = await provider.callCount
  try expect(consentOnlyCallCount == 0, "granting consent alone must not call or upload")

  let outcome = await controller.run(asset: authorized, routeRead: routeRead)
  try expect(outcome == .accepted(suggested), "explicit Run should return the provider result")
  let completedCallCount = await provider.callCount
  let loadedBytes = await provider.loadedBytes
  try expect(completedCallCount == 1, "explicit Run should invoke the provider once")
  try expect(loadedBytes == onePixelPNG, "provider should load registered library bytes")
  try expect(callbackResult == suggested, "suggested scene should cross the surface callback")
  try expect(
    controller.lastResult?.provenance.authorship == .suggested
      && controller.lastResult?.provenance.automation == .modelAdapter,
    "surface should expose honest suggested model provenance"
  )
  try expect(controller.errorMessage == nil, "successful route read should clear error state")
}

@MainActor
private func routeReadActionSurfacesProviderFailureWithoutCallback() async throws {
  let asset = routeMediaSurfaceAsset()
  var callbackCount = 0
  let controller = RouteMediaReadSurfaceController(
    provider: FailingRouteMediaProvider()
  ) { _ in
    callbackCount += 1
  }

  let outcome = await controller.run(asset: asset, routeRead: routeMediaSurfaceRequest())

  guard case .rejected(.providerFailed(let message)) = outcome else {
    throw AppleAdapterSpecFailure.expected("expected explicit provider failure")
  }
  try expect(message.contains("fixture model unavailable"), "provider failure should be visible")
  try expect(callbackCount == 0, "failed provider must not emit a route-read callback")
  try expect(controller.lastResult == nil, "failed provider must not retain a result")
  try expect(
    controller.errorMessage?.contains("fixture model unavailable") == true,
    "surface should retain a visible error message"
  )
}

private actor LoadingRouteMediaProvider: RouteMediaReadProviding {
  nonisolated let identifier = "loading-route-media-fixture"
  private let loader: any RouteMediaDataLoader
  private let result: RouteReadResult
  private(set) var callCount = 0
  private(set) var loadedBytes: Data?

  init(loader: any RouteMediaDataLoader, result: RouteReadResult) {
    self.loader = loader
    self.result = result
  }

  func read(_ request: RouteMediaReadRequest) async throws -> RouteReadResult {
    callCount += 1
    guard let asset = request.assets.first else {
      throw AppleAdapterSpecFailure.expected("missing route media")
    }
    loadedBytes = try await loader.loadData(for: asset.localReference)
    return result
  }
}

private struct FailingRouteMediaProvider: RouteMediaReadProviding {
  let identifier = "failing-route-media-fixture"

  func read(_ request: RouteMediaReadRequest) async throws -> RouteReadResult {
    throw RouteMediaSurfaceFixtureError.unavailable
  }
}

private enum RouteMediaSurfaceFixtureError: Error, LocalizedError {
  case unavailable

  var errorDescription: String? { "fixture model unavailable" }
}

private func routeMediaSurfaceRequest() -> RouteReadRequest {
  RouteReadRequest(
    sceneID: RouteSceneID("surface-scene"),
    name: "Surface route",
    size: SceneSize(width: 1, height: 1),
    metersPerSceneUnit: nil,
    candidateHolds: []
  )
}

private func routeMediaSurfaceResult() -> RouteReadResult {
  RouteReadResult(
    scene: RouteScene(
      id: RouteSceneID("surface-scene"),
      name: "Suggested surface route",
      size: SceneSize(width: 1, height: 1),
      metersPerSceneUnit: nil,
      holds: [
        Hold(
          id: HoldID("suggested-start"),
          center: Point2D(x: 0.5, y: 0.8),
          radius: 0.1,
          routeRole: .start
        )
      ]
    ),
    provenance: RehearsalProvenance(
      authorship: .suggested,
      automation: .modelAdapter,
      providerIdentifier: "fixture-model",
      version: "1"
    )
  )
}

private func routeMediaSurfaceAsset() -> RouteMediaAsset {
  RouteMediaAsset(
    id: RouteMediaAssetID("failure-asset"),
    routeCardID: RouteCardID("surface-route"),
    localReference: LocalMediaReference(
      fileIdentifier: "failure-file",
      sandboxRelativePath: "media/source/failure-file.png"
    ),
    kind: .routePhoto,
    mimeType: "image/png",
    byteCount: 1,
    dimensions: MediaDimensions(pixelWidth: 1, pixelHeight: 1),
    contentDigest: MediaContentDigest(algorithm: .sha256, hexValue: "fixture"),
    purpose: .routeReference,
    consent: MediaConsent(
      status: .granted,
      scope: .explicitModelProcessing,
      recordedAt: Instant(millisecondsSince1970: 200)
    ),
    captureProvenance: MediaCaptureProvenance(
      capturedAt: Instant(millisecondsSince1970: 100),
      deviceClass: .phone,
      method: .photoLibraryImport,
      importedByUser: true
    ),
    origin: .source,
    quality: .unreviewed,
    retention: .keepUntilUserDeletes
  )
}

func routeMediaLibrarySpecifications() -> [(String, () async throws -> Void)] {
  [
    (
      "imported media reopens and loads only registered bytes",
      importedMediaReopensAndLoadsOnlyRegisteredBytes
    ),
    (
      "source and derived media remain separate with lineage",
      sourceAndDerivedMediaRemainSeparateWithLineage
    ),
    (
      "deletion removes bytes and persists a tombstone",
      deletionRemovesBytesAndPersistsATombstone
    ),
    (
      "model consent is separate and revocation deletes local bytes",
      modelConsentIsSeparateAndRevocationDeletesLocalBytes
    ),
    (
      "expired retention deletes bytes and records why",
      expiredRetentionDeletesBytesAndRecordsWhy
    ),
    (
      "missing bytes still complete deletion and consent revocation",
      missingBytesStillCompleteDeletionAndConsentRevocation
    ),
    (
      "retention sweep continues past one unreadable asset",
      retentionSweepContinuesPastOneUnreadableAsset
    ),
    (
      "a source awaiting its first derived asset survives retention",
      sourceAwaitingItsFirstDerivedAssetSurvivesRetention
    ),
    (
      "reopening reclaims media bytes orphaned by an interrupted commit",
      reopeningReclaimsMediaBytesOrphanedByAnInterruptedCommit
    ),
    (
      "exported manifest carries metadata without raw bytes or absolute paths",
      exportedManifestContainsMetadataWithoutRawBytesOrAbsolutePaths
    ),
    (
      "corrupt and future manifests fail explicitly",
      corruptAndFutureManifestsFailExplicitly
    ),
    (
      "loader rejects traversal and symlink escapes",
      loaderRejectsTraversalAndSymlinkEscapes
    ),
    (
      "failed manifest write leaves no registered asset or staged bytes",
      failedManifestWriteLeavesNoRegisteredAssetOrStagedBytes
    ),
    (
      "import cannot bundle model consent or use revoked storage consent",
      importCannotBundleModelConsentOrUseRevokedStorageConsent
    ),
    (
      "route read action requires consent then delivers a suggested callback",
      routeReadActionRequiresConsentThenDeliversSuggestedCallback
    ),
    (
      "route read action surfaces provider failure without a callback",
      routeReadActionSurfacesProviderFailureWithoutCallback
    ),
  ]
}
