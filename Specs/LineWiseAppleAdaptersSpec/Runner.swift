import Foundation
import LineWiseAppleAdapters
import LineWiseDomain

enum AppleAdapterSpecFailure: Error {
  case expected(String)
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw AppleAdapterSpecFailure.expected(message) }
}

@main
struct LineWiseAppleAdaptersSpecRunner {
  static func main() async throws {
    let recorder = NoHealthKitWorkoutRecorder()
    let capability = await recorder.capabilityState()
    try expect(
      capability == .unavailable,
      "expected the no-HealthKit path to be explicit"
    )
    try await recorder.start(at: Date(timeIntervalSince1970: 1))
    try await recorder.stop(at: Date(timeIntervalSince1970: 2))
    print("PASS: no HealthKit does not block the manual visit")

    let transport = InMemoryDevicePayloadTransport()
    await transport.activate()
    let first = try await transport.send(Data("first".utf8), mode: .reliableBackground)
    let second = try await transport.send(Data("second".utf8), mode: .immediateIfReachable)
    let payloads = await transport.receivedPayloads()
    try expect(first.acceptedLocally && second.acceptedLocally, "expected local enqueue receipts")
    try expect(
      payloads == [Data("first".utf8), Data("second".utf8)],
      "expected transport order to remain stable"
    )
    print("PASS: device transport accepts payloads locally before connectivity")

    let bridge = DeviceEnvelopeBridge(transport: InMemoryDevicePayloadTransport())
    let envelope = DeviceEventEnvelope(
      originDeviceID: DeviceID("watch"),
      sequence: 1,
      command: .startVisit(
        actionID: ActionID("action-bridge-start"),
        visitID: GymVisitID("visit-bridge-start"),
        occurredAt: Instant(millisecondsSince1970: 1_000),
        source: .watch
      )
    )
    let bridgeReceipt = try await bridge.send(envelope, mode: .reliableBackground)
    let receivedEnvelopes = try await bridge.receivedEnvelopes()
    try expect(bridgeReceipt.acceptedLocally, "expected envelope to enqueue")
    try expect(
      receivedEnvelopes == [envelope],
      "expected a lossless DeviceEventEnvelope round trip"
    )
    print("PASS: DeviceEventEnvelope crosses the payload bridge losslessly")
    let deviceSyncCount = try await runDeviceSyncServiceSpecifications()
    print("PASS: accepted transfers become acknowledgement candidates")
    print("PASS: rejected and failed transfers remain pending")
    let bootstrapCount = try runPersistentBootstrapSpecifications()
    print("PASS: app bootstrap reopens durable state")
    print("PASS: app bootstrap rejects an invalid device identity")
    print("PASS: app bootstrap keeps a stable role-scoped device identity")
    let appleRuntimeCount = try await runAppleRuntimeSpecifications()
    print("PASS: workout denial does not roll back the local Visit")
    print("PASS: workout failure does not roll back the local Visit")
    print("PASS: runtime acknowledges only transport-accepted events")
    print("PASS: runtime pull remains idempotent")
    print("PASS: completed workout exposes optional summary context")
    print("PASS: experience-backed Watch runtime reopens active Rest")
    let experienceSurfaceCount = try await runExperienceSurfaceSpecifications()
    print("PASS: iPhone review remains explicit and reopens the next-session cue")
    print("PASS: physiology and manual rehearsal remain available without AI")
    print("PASS: review branches and persistence failures remain visible")
    let learningSurfaceCount = try await runLearningExperienceSurfaceSpecifications()
    let mediaLibraryCount = try await runRouteMediaLibrarySpecifications()
    print(
      "LineWiseAppleAdaptersSpec: \(3 + deviceSyncCount + bootstrapCount + appleRuntimeCount + experienceSurfaceCount + learningSurfaceCount + mediaLibraryCount) passed"
    )
  }
}
