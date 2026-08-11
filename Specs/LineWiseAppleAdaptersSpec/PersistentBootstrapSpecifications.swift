import Foundation
import LineWiseAppleAdapters
import LineWiseApplication
import LineWiseDomain

func runPersistentBootstrapSpecifications() throws -> Int {
  try bootstrapReopensDurableState()
  try bootstrapRejectsInvalidDeviceIdentity()
  try bootstrapCreatesAStableRoleScopedDeviceIdentity()
  return 3
}

private func bootstrapCreatesAStableRoleScopedDeviceIdentity() throws {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("linewise-device-identity-\(UUID().uuidString)", isDirectory: true)
  defer { try? FileManager.default.removeItem(at: root) }

  let firstPhone = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: root,
    role: .iPhone
  )
  let reopenedPhone = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: root,
    role: .iPhone
  )
  let watch = try LineWiseAppBootstrap.makePersistentRuntime(
    storageDirectoryURL: root,
    role: .watch
  )

  try expect(
    firstPhone.deviceID == reopenedPhone.deviceID,
    "expected the device event origin to remain stable across relaunch"
  )
  try expect(
    firstPhone.deviceID != watch.deviceID,
    "expected Watch and iPhone to use distinct event origins"
  )
  try expect(
    firstPhone.deviceID.rawValue.hasPrefix("iphone-")
      && watch.deviceID.rawValue.hasPrefix("watch-"),
    "expected readable role-scoped identities"
  )
}

private func bootstrapReopensDurableState() throws {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("linewise-bootstrap-\(UUID().uuidString)", isDirectory: true)
  defer { try? FileManager.default.removeItem(at: root) }

  var first = try LineWiseAppBootstrap.makePersistentCoordinator(
    storageDirectoryURL: root,
    deviceID: DeviceID("iphone-bootstrap")
  )
  let visitID = GymVisitID("visit-bootstrap")
  try expect(
    first.handle(
      .startVisit(
        actionID: ActionID("action-bootstrap-start"),
        visitID: visitID,
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .iPhone
      )
    ).isSuccess,
    "expected bootstrap coordinator to persist accepted capture"
  )

  let reopened = try LineWiseAppBootstrap.makePersistentCoordinator(
    storageDirectoryURL: root,
    deviceID: DeviceID("iphone-bootstrap")
  )
  try expect(
    reopened.projection.activeVisit?.id == visitID,
    "expected the production bootstrap path to reopen the durable visit"
  )
  try expect(
    FileManager.default.fileExists(
      atPath: LineWiseAppBootstrap.visitJournalURL(in: root).path
    ),
    "expected a concrete journal file"
  )
}

private func bootstrapRejectsInvalidDeviceIdentity() throws {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("linewise-bootstrap-invalid", isDirectory: true)
  do {
    _ = try LineWiseAppBootstrap.makePersistentCoordinator(
      storageDirectoryURL: root,
      deviceID: DeviceID("")
    )
    throw AppleAdapterSpecFailure.expected("expected empty device ID rejection")
  } catch DeviceSyncError.emptyDeviceID {
    // Expected: never silently construct a non-durable fallback coordinator.
  }
}
